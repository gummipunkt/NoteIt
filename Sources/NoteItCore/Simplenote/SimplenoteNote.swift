import Foundation

/// A note object as stored by Simplenote (Simperium bucket `note`).
///
/// All fields are kept in `fields` so unknown ones survive a round trip.
public struct SimplenoteNote: Codable, Equatable, Sendable {
    public var fields: [String: JSONValue]

    public init(fields: [String: JSONValue]) {
        self.fields = fields
    }

    /// A fresh note with the defaults Simplenote clients use.
    public init(content: String, creationDate: Date, modificationDate: Date, markdown: Bool) {
        fields = [
            "content": .string(content),
            "tags": .array([]),
            "systemTags": .array(markdown ? [.string("markdown")] : []),
            "deleted": .bool(false),
            "shareURL": .string(""),
            "publishURL": .string(""),
            "creationDate": .number(creationDate.timeIntervalSince1970),
            "modificationDate": .number(modificationDate.timeIntervalSince1970),
        ]
    }

    public init(from decoder: Decoder) throws {
        fields = try decoder.singleValueContainer().decode([String: JSONValue].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(fields)
    }

    public var content: String {
        get { fields["content"]?.stringValue ?? "" }
        set { fields["content"] = .string(newValue) }
    }

    public var isDeleted: Bool {
        get { fields["deleted"]?.boolValue ?? false }
        set { fields["deleted"] = .bool(newValue) }
    }

    public var tags: [String] {
        fields["tags"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    public var systemTags: [String] {
        get { fields["systemTags"]?.arrayValue?.compactMap(\.stringValue) ?? [] }
        set { fields["systemTags"] = .array(newValue.map { .string($0) }) }
    }

    public var isMarkdown: Bool {
        get { systemTags.contains("markdown") }
        set {
            var tags = systemTags.filter { $0 != "markdown" }
            if newValue { tags.append("markdown") }
            systemTags = tags
        }
    }

    public var modificationDate: Date? {
        get { fields["modificationDate"]?.doubleValue.map(Date.init(timeIntervalSince1970:)) }
        set { fields["modificationDate"] = newValue.map { .number($0.timeIntervalSince1970) } ?? .null }
    }

    public var creationDate: Date? {
        fields["creationDate"]?.doubleValue.map(Date.init(timeIntervalSince1970:))
    }
}

/// A versioned note as returned by the Simperium API.
public struct RemoteNote: Equatable, Sendable {
    public var key: String
    public var version: Int
    public var note: SimplenoteNote

    public init(key: String, version: Int, note: SimplenoteNote) {
        self.key = key
        self.version = version
        self.note = note
    }
}
