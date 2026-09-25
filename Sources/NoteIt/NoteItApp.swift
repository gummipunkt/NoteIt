import AppKit
import NoteItCore
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
        .defaultSize(width: 1000, height: 680)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.tr(.menuAbout)) { AppInfo.showAboutPanel() }
            }
            CommandGroup(replacing: .newItem) {
                Button(L10n.tr(.newNote)) { model.newNote() }
                    .keyboardShortcut("n")
                Button(L10n.tr(.search)) { model.requestSearchFocus() }
                    .keyboardShortcut("l")
            }
            CommandGroup(replacing: .printItem) {}
            CommandMenu(L10n.tr(.menuNote)) {
                Button(L10n.tr(.rename)) { model.requestTitleEditing() }
                    .keyboardShortcut("r")
                    .disabled(model.selectedNote == nil)
                Button(L10n.tr(.moveToTrash)) { model.beginDelete() }
                    .disabled(model.selectedNote == nil)
                Button(L10n.tr(.showInFinder)) { model.revealSelectedInFinder() }
                    .disabled(model.selectedNote == nil)
                Divider()
                Button(L10n.tr(.syncWithSimplenote)) { model.syncNow() }
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
                Button(L10n.tr(.menuWebsite)) { NSWorkspace.shared.open(AppInfo.website) }
                Button(L10n.tr(.sourceCodeOnGitHub)) { NSWorkspace.shared.open(AppInfo.repository) }
                Button(L10n.tr(.contactFormat, AppInfo.email)) {
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
