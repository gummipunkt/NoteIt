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
                .frame(minWidth: 520, minHeight: 360)
        }
        .defaultSize(width: 900, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Suchen / Neue Notiz") { model.requestSearchFocus() }
                    .keyboardShortcut("l")
                Button("Neue Notiz") { model.requestSearchFocus() }
                    .keyboardShortcut("n")
            }
            CommandGroup(replacing: .printItem) {}
            CommandMenu("Notiz") {
                Button("Umbenennen …") { model.beginRename() }
                    .keyboardShortcut("r")
                    .disabled(model.selectedNote == nil)
                Button("In den Papierkorb legen …") { model.beginDelete() }
                    .disabled(model.selectedNote == nil)
                Button("Im Finder zeigen") { model.revealSelectedInFinder() }
                    .disabled(model.selectedNote == nil)
                Divider()
                Button(model.showPreview ? "Vorschau ausblenden" : "Vorschau einblenden") {
                    model.showPreview.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                Divider()
                Button("Mit Simplenote synchronisieren") { model.syncNow() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(!model.isSimplenoteConnected || model.isSyncing)
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
