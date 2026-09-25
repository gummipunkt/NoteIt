import AppKit
import SwiftUI

@main
struct NoteItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        Window("NoteIt", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 640, minHeight: 400)
        }
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Über NoteIt") { AppInfo.showAboutPanel() }
            }
            CommandGroup(replacing: .newItem) {
                Button("Neue Notiz") { model.newNote() }
                    .keyboardShortcut("n")
                Button("Suchen") { model.requestSearchFocus() }
                    .keyboardShortcut("l")
            }
            CommandGroup(replacing: .printItem) {}
            CommandMenu("Notiz") {
                Button("Umbenennen") { model.requestTitleEditing() }
                    .keyboardShortcut("r")
                    .disabled(model.selectedNote == nil)
                Button("In den Papierkorb legen …") { model.beginDelete() }
                    .disabled(model.selectedNote == nil)
                Button("Im Finder zeigen") { model.revealSelectedInFinder() }
                    .disabled(model.selectedNote == nil)
                Divider()
                Button("Mit Simplenote synchronisieren") { model.syncNow() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(!model.isSimplenoteConnected || model.isSyncing)
            }
            CommandGroup(before: .sidebar) {
                ForEach(Array(ViewMode.allCases.enumerated()), id: \.element) { index, mode in
                    Button(mode.label) { model.viewMode = mode }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
                }
                Divider()
            }
            CommandGroup(replacing: .help) {
                Button("NoteIt-Website") { NSWorkspace.shared.open(AppInfo.website) }
                Button("Quellcode auf GitHub") { NSWorkspace.shared.open(AppInfo.repository) }
                Button("Kontakt: \(AppInfo.email)") {
                    NSWorkspace.shared.open(URL(string: "mailto:\(AppInfo.email)")!)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when started via `swift run` (no app bundle): show in Dock and take focus.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillResignActive(_ notification: Notification) {
        AppModel.shared.saveNow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.saveNow()
    }
}
