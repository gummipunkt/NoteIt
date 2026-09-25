import AppKit
import NoteItCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
            StorageSettings()
                .tabItem { Label("Speicherort", systemImage: "folder") }
            SimplenoteSettings()
                .tabItem { Label("Simplenote", systemImage: "arrow.triangle.2.circlepath") }
            AboutSettings()
                .tabItem { Label("Über", systemImage: "info.circle") }
        }
        .frame(width: 520)
        .padding(20)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("editorFont") private var fontStyle: EditorFontStyle = .system
    @AppStorage("editorFontSize") private var fontSize = 15.0
    @AppStorage("editorNarrowColumn") private var narrowColumn = true

    var body: some View {
        Form {
            Picker("Neue Notizen als:", selection: $model.defaultExtension) {
                Text("Markdown (.md)").tag("md")
                Text("Text (.txt)").tag("txt")
            }
            Picker("Ansicht:", selection: $model.viewMode) {
                ForEach(ViewMode.allCases) { Text($0.label).tag($0) }
            }
            Picker("Schrift:", selection: $fontStyle) {
                ForEach(EditorFontStyle.allCases) { Text($0.label).tag($0) }
            }
            Stepper("Schriftgröße: \(Int(fontSize)) pt", value: $fontSize, in: 10...32)
            Toggle("Schmale Textspalte (angenehmer zu lesen)", isOn: $narrowColumn)
        }
    }
}

private struct StorageSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notizordner").font(.headline)
            HStack {
                Text(model.folderURL.path)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer()
                Button("Im Finder zeigen") {
                    NSWorkspace.shared.activateFileViewerSelecting([model.folderURL])
                }
            }
            HStack {
                Button("Anderen Ordner wählen …", action: chooseFolder)
                ForEach(CloudFolders.detected()) { cloud in
                    Button("In \(cloud.name) speichern") {
                        model.changeFolder(to: cloud.url.appendingPathComponent("NoteIt", isDirectory: true))
                    }
                    .help(cloud.url.path)
                }
            }

            Divider()

            Text("Sync mit Dropbox und Google Drive").font(.headline)
            Text("""
            Jede Notiz ist eine normale .md- oder .txt-Datei. Legst du den Notizordner in deinen \
            Dropbox- oder Google-Drive-Ordner, synchronisiert die jeweilige Desktop-App die Notizen \
            automatisch mit deinen anderen Geräten. NoteIt erkennt Änderungen von außen sofort.
            """)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            if CloudFolders.detected().isEmpty {
                Text("Kein Dropbox- oder Google-Drive-Ordner gefunden. Installiere die Desktop-App des Dienstes und wähle dann den Ordner aus.")
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
        panel.prompt = "Auswählen"
        panel.message = "Ordner für deine Notizen wählen"
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
                LabeledContent("Angemeldet als", value: account)
                Toggle("Automatisch synchronisieren (alle 3 Minuten und nach Änderungen)", isOn: $model.autoSync)
                if !model.syncStatus.isEmpty {
                    Text(model.syncStatus)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Jetzt synchronisieren") { model.syncNow() }
                        .disabled(model.isSyncing || !model.isSimplenoteConnected)
                    if model.isSyncing { ProgressView().controlSize(.small) }
                    Spacer()
                    Button("Abmelden", role: .destructive) { model.signOutOfSimplenote() }
                }
            } else {
                Text("Mit Simplenote verbinden").font(.headline)
                TextField("E-Mail", text: $email)
                    .textFieldStyle(.roundedBorder)
                SecureField("Passwort", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(signIn)
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button("Anmelden", action: signIn)
                        .keyboardShortcut(.defaultAction)
                        .disabled(email.isEmpty || password.isEmpty || isSigningIn)
                    if isSigningIn { ProgressView().controlSize(.small) }
                }
            }

            Divider()

            Text("""
            Die erste Zeile einer Simplenote-Notiz wird zum Titel (Dateiname), der Rest zum Inhalt. \
            Das Passwort wird nicht gespeichert, nur ein Zugriffstoken im Schlüsselbund. \
            In Simplenote gelöschte Notizen landen hier im Papierkorb von macOS.
            """)
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
                Link("Quellcode auf GitHub", destination: AppInfo.repository)
            }
            Text("Freie Software unter der GNU General Public License v3.0.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Link("Lizenztext lesen", destination: AppInfo.licenseURL)
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
