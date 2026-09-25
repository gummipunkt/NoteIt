import AppKit
import NoteItCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label(L10n.tr(.settingsGeneral), systemImage: "gearshape") }
            StorageSettings()
                .tabItem { Label(L10n.tr(.settingsStorage), systemImage: "folder") }
            SimplenoteSettings()
                .tabItem { Label("Simplenote", systemImage: "arrow.triangle.2.circlepath") }
            AboutSettings()
                .tabItem { Label(L10n.tr(.settingsAbout), systemImage: "info.circle") }
        }
        .frame(width: 520)
        .padding(20)
        // Rebuild all texts when the language changes.
        .id(L10n.language)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("editorFont") private var fontStyle: EditorFontStyle = .system
    @AppStorage("editorFontSize") private var fontSize = 15.0
    @AppStorage("editorNarrowColumn") private var narrowColumn = true

    var body: some View {
        Form {
            Picker(L10n.tr(.languageLabel), selection: Binding(
                get: { model.languageCode },
                set: { model.languageCode = $0 }
            )) {
                Text(L10n.tr(.languageSystem)).tag("")
                Divider()
                ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0.rawValue) }
            }
            Text(L10n.tr(.languageRestartHint))
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(L10n.tr(.newNotesAs), selection: $model.defaultExtension) {
                Text(L10n.tr(.formatMarkdown)).tag("md")
                Text(L10n.tr(.formatText)).tag("txt")
            }
            Picker(L10n.tr(.viewLabel), selection: $model.viewMode) {
                ForEach(ViewMode.allCases) { Text($0.label).tag($0) }
            }
            Picker(L10n.tr(.fontLabel), selection: $fontStyle) {
                ForEach(EditorFontStyle.allCases) { Text($0.label).tag($0) }
            }
            Stepper(L10n.tr(.fontSizeFormat, Int(fontSize)), value: $fontSize, in: 10...32)
            Toggle(L10n.tr(.narrowColumn), isOn: $narrowColumn)
        }
    }
}

private struct StorageSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr(.notesFolder)).font(.headline)
            HStack {
                Text(model.folderURL.path)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer()
                Button(L10n.tr(.showInFinder)) {
                    NSWorkspace.shared.activateFileViewerSelecting([model.folderURL])
                }
            }
            HStack {
                Button(L10n.tr(.chooseOtherFolder), action: chooseFolder)
                ForEach(CloudFolders.detected()) { cloud in
                    Button(L10n.tr(.storeInFormat, cloud.name)) {
                        model.changeFolder(to: cloud.url.appendingPathComponent("NoteIt", isDirectory: true))
                    }
                    .help(cloud.url.path)
                }
            }

            Divider()

            Text(L10n.tr(.cloudSyncTitle)).font(.headline)
            Text(L10n.tr(.cloudSyncExplanation))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if CloudFolders.detected().isEmpty {
                Text(L10n.tr(.noCloudFolderFound))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = model.folderURL
        panel.prompt = L10n.tr(.choose)
        panel.message = L10n.tr(.chooseFolderMessage)
        if panel.runModal() == .OK, let url = panel.url {
            model.changeFolder(to: url)
        }
    }
}

private struct SimplenoteSettings: View {
    @EnvironmentObject private var model: AppModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let account = model.simplenoteAccount {
                LabeledContent(L10n.tr(.signedInAs), value: account)
                Toggle(L10n.tr(.autoSync), isOn: $model.autoSync)
                if !model.syncStatus.isEmpty {
                    Text(model.syncStatus)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button(L10n.tr(.syncNow)) { model.syncNow() }
                        .disabled(model.isSyncing || !model.isSimplenoteConnected)
                    if model.isSyncing { ProgressView().controlSize(.small) }
                    Spacer()
                    Button(L10n.tr(.signOut), role: .destructive) { model.signOutOfSimplenote() }
                }
            } else {
                Text(L10n.tr(.connectSimplenote)).font(.headline)
                TextField(L10n.tr(.email), text: $email)
                    .textFieldStyle(.roundedBorder)
                SecureField(L10n.tr(.password), text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(signIn)
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button(L10n.tr(.signIn), action: signIn)
                        .keyboardShortcut(.defaultAction)
                        .disabled(email.isEmpty || password.isEmpty || isSigningIn)
                    if isSigningIn { ProgressView().controlSize(.small) }
                }
            }

            Divider()

            Text(L10n.tr(.simplenoteExplanation))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else { return }
        isSigningIn = true
        error = nil
        Task {
            do {
                try await model.signInToSimplenote(email: email, password: password)
                password = ""
            } catch {
                self.error = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 10) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
            }
            Text(AppInfo.name)
                .font(.title2.bold())
            Text(AppInfo.versionLabel)
                .foregroundStyle(.secondary)
            Text(AppInfo.copyright)
            HStack(spacing: 16) {
                Link("www.gummipunkt.eu", destination: AppInfo.website)
                Link(AppInfo.email, destination: URL(string: "mailto:\(AppInfo.email)")!)
                Link(L10n.tr(.sourceCodeOnGitHub), destination: AppInfo.repository)
            }
            Text(L10n.tr(.freeSoftwareGPL))
                .font(.callout)
                .foregroundStyle(.secondary)
            Link(L10n.tr(.readLicense), destination: AppInfo.licenseURL)
                .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// Locally synced cloud folders (Dropbox, Google Drive) that can hold the notes.
struct CloudFolders {
    struct Folder: Identifiable {
        let name: String
        let url: URL
        var id: String { url.path }
    }

    static func detected() -> [Folder] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let cloudStorage = home.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        var result: [Folder] = []

        let entries = (try? fileManager.contentsOfDirectory(at: cloudStorage, includingPropertiesForKeys: nil)) ?? []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = entry.lastPathComponent
            if name.hasPrefix("Dropbox") {
                result.append(Folder(name: "Dropbox", url: entry))
            } else if name.hasPrefix("GoogleDrive") {
                // Google Drive for desktop exposes "My Drive" (localized, e.g. "Meine Ablage").
                let myDrive = ["My Drive", "Meine Ablage"]
                    .map { entry.appendingPathComponent($0, isDirectory: true) }
                    .first { fileManager.fileExists(atPath: $0.path) }
                result.append(Folder(name: "Google Drive", url: myDrive ?? entry))
            }
        }
        // Older Dropbox installations use ~/Dropbox.
        let legacyDropbox = home.appendingPathComponent("Dropbox", isDirectory: true)
        if !result.contains(where: { $0.name == "Dropbox" }), fileManager.fileExists(atPath: legacyDropbox.path) {
            result.append(Folder(name: "Dropbox", url: legacyDropbox))
        }
        return result
    }
}
