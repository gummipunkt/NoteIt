import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Abstraction over the network so the sync logic can be tested without a server.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let response = response as? HTTPURLResponse {
                    continuation.resume(returning: (data ?? Data(), response))
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }.resume()
        }
    }
}

public enum SimplenoteError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case unauthorized
    case http(status: Int, message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Anmeldung bei Simplenote fehlgeschlagen. Bitte E-Mail und Passwort prüfen."
        case .unauthorized:
            return "Die Simplenote-Sitzung ist abgelaufen. Bitte erneut anmelden."
        case .http(let status, let message):
            return "Simplenote-Serverfehler (\(status))\(message.isEmpty ? "" : ": \(message)")"
        case .invalidResponse:
            return "Unerwartete Antwort vom Simplenote-Server."
        }
    }
}

/// Minimal client for the Simperium HTTP API that backs Simplenote.
///
/// See https://simperium.com/docs/reference/http/
public struct SimperiumClient: Sendable {
    /// App ID and API key of the Simplenote Simperium app, as used by open source
    /// Simplenote clients (e.g. simplenote.py / sncli). Can be overridden in the settings.
    public static let defaultAppID = "chalk-bump-f49"
    public static let defaultAPIKey = "c8c2b86337154cdabc989b23e30c6bf4"

    public var appID: String
    public var apiKey: String
    public var token: String
    public var bucket: String
    private let transport: HTTPTransport

    public init(
        token: String,
        appID: String = SimperiumClient.defaultAppID,
        apiKey: String = SimperiumClient.defaultAPIKey,
        bucket: String = "note",
        transport: HTTPTransport = URLSessionTransport()
    ) {
        self.token = token
        self.appID = appID
        self.apiKey = apiKey
        self.bucket = bucket
        self.transport = transport
    }

    // MARK: - Authentication

    /// Logs in with Simplenote e-mail and password and returns an access token.
    /// The password is not stored anywhere; only the token is kept (in the Keychain).
    public static func authenticate(
        username: String,
        password: String,
        appID: String = defaultAppID,
        apiKey: String = defaultAPIKey,
        transport: HTTPTransport = URLSessionTransport()
    ) async throws -> String {
        var request = URLRequest(url: URL(string: "https://auth.simperium.com/1/\(appID)/authorize/")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Simperium-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["username": username, "password": password])

        let (data, response) = try await transport.send(request)
        switch response.statusCode {
        case 200:
            break
        case 400, 401, 403:
            throw SimplenoteError.invalidCredentials
        default:
            throw SimplenoteError.http(status: response.statusCode, message: String(decoding: data, as: UTF8.self))
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = object["access_token"] as? String else {
            throw SimplenoteError.invalidResponse
        }
        return token
    }

    // MARK: - Notes

    private struct IndexResponse: Decodable {
        struct Entry: Decodable {
            let id: String
            let v: Int
            let d: SimplenoteNote?
        }
        let index: [Entry]
        let mark: String?
        let current: String?
    }

    /// Loads all notes (including the ones in Simplenote's trash) with their data.
    public func fetchAllNotes(pageSize: Int = 100) async throws -> [RemoteNote] {
        var result: [RemoteNote] = []
        var mark: String?
        repeat {
            var query = [URLQueryItem(name: "data", value: "true"), URLQueryItem(name: "limit", value: String(pageSize))]
            if let mark { query.append(URLQueryItem(name: "mark", value: mark)) }
            let data = try await perform(method: "GET", path: "index", query: query).0
            let page = try JSONDecoder().decode(IndexResponse.self, from: data)
            for entry in page.index {
                if let note = entry.d {
                    result.append(RemoteNote(key: entry.id, version: entry.v, note: note))
                } else {
                    result.append(try await fetchNote(key: entry.id))
                }
            }
            mark = page.mark
        } while mark != nil
        return result
    }

    public func fetchNote(key: String) async throws -> RemoteNote {
        let (data, response) = try await perform(method: "GET", path: "i/\(encode(key))")
        let note = try JSONDecoder().decode(SimplenoteNote.self, from: data)
        return RemoteNote(key: key, version: version(from: response) ?? 0, note: note)
    }

    /// Creates or updates a note.
    ///
    /// When `baseVersion` is given, Simperium computes the changes relative to that
    /// version and merges them into the current server version, so concurrent edits
    /// from other devices are not lost. The merged note is returned.
    public func saveNote(key: String, note: SimplenoteNote, baseVersion: Int?) async throws -> RemoteNote {
        var path = "i/\(encode(key))"
        if let baseVersion { path += "/v/\(baseVersion)" }
        let body = try JSONEncoder().encode(note)
        let (data, response) = try await perform(
            method: "POST",
            path: path,
            query: [URLQueryItem(name: "response", value: "1")],
            body: body
        )
        let savedVersion = version(from: response)
        if !data.isEmpty, let saved = try? JSONDecoder().decode(SimplenoteNote.self, from: data), let savedVersion {
            return RemoteNote(key: key, version: savedVersion, note: saved)
        }
        // Some responses carry no body (e.g. nothing changed); ask for the current state.
        return try await fetchNote(key: key)
    }

    // MARK: - Plumbing

    private func perform(method: String, path: String, query: [URLQueryItem] = [], body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents(string: "https://api.simperium.com/1/\(appID)/\(bucket)/\(path)")!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: "X-Simperium-Token")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport.send(request)
        switch response.statusCode {
        case 200..<300:
            return (data, response)
        case 401:
            throw SimplenoteError.unauthorized
        default:
            throw SimplenoteError.http(status: response.statusCode, message: String(decoding: data.prefix(300), as: UTF8.self))
        }
    }

    private func version(from response: HTTPURLResponse) -> Int? {
        (response.value(forHTTPHeaderField: "X-Simperium-Version")).flatMap { Int($0) }
    }

    private func encode(_ key: String) -> String {
        key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? key
    }
}
