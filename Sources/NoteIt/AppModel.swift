import AppKit
import Combine
import NoteItCore
import SwiftUI

/// What the detail area shows.
enum ViewMode: String, CaseIterable, Identifiable {
    case edit
    case split
    case preview

    var id: String { rawValue }

    var label: String {
        switch self {
        case .edit: return "Schreiben"
        case .split: return "Geteilt"
        case .preview: return "Vorschau"
        }
    }

    var symbol: String {
        switch self {
        case .edit: return "square.and.pencil"
        case .split: return "rectangle.split.2x1"
        case .preview: return "eye"
        }
    }
}

/// Central state of the app: notes on disk, search, selection, autosave and sync.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    private enum Keys {
        static let folderPath = "notesFolderPath"
        static let defaultExtension = "defaultExtension"
        static let viewMode = "viewMode"
        static let didOfferWelcomeNote = "didOfferWelcomeNote"
        static let simplenoteEmail = "simplenoteEmail"
        static let autoSync = "simplenoteAutoSync"
    }

    // MARK: Published state

    @Published private(set) var notes: [Note] = [] { didSet { updateVisibleNotes() } }
    @Published private(set) var visibleNotes: [Note] = []
    @Published var query = "" { didSet { if query != oldValue { queryChanged() } } }
    @Published var selectedID: Note.ID? { didSet { if selectedID != oldValue { selectionChanged() } } }
    @Published var editorText = "" { didSet { if editorText != oldValue { editorTextChanged() } } }
    @Published var viewMode: ViewMode { didSet { defaults.set(viewMode.rawValue, forKey: Keys.viewMode) } }
    @Published private(set) var folderURL: URL
    @Published var defaultExtension: String {
        didSet {
            defaults.set(defaultExtension, forKey: Keys.defaultExtension)
            store.defaultExtension = defaultExtension
        }
    }

    @Published var errorMessage: String?
    @Published var deleteTarget: Note?

    /// Incremented to ask the views to move keyboard focus.
    @Published private(set) var searchFocusRequest = 0
    @Published private(set) var editorFocusRequest = 0
    /// Set when the title field should take focus (e.g. after ⌘N); the title view clears it.
    @Published var titleFocusPending = false

    // Simplenote
    @Published private(set) var simplenoteAccount: String?
    @Published private(set) var isSyncing = false
    @Published private(set) var syncStatus = ""
    @Published var autoSync: Bool {
        didSet {
            defaults.set(autoSync, forKey: Keys.autoSync)
            configureSyncTimer()
        }
    }

    // MARK: Private state

    private let defaults = UserDefaults.standard
    private var store: NoteFileStore
    /// File name of the note currently shown in the editor.
    private var editingFileName: String?
    private var hasUnsavedChanges = false
    private var autosaveTask: Task<Void, Never>?
    private var folderMonitor: FolderMonitor?
    private var syncEngine: SimplenoteSyncEngine?
    private var syncTimer: Timer?
    private var syncSoonTask: Task<Void, Never>?
    private var knownTitles: Set<String> = []

    private init() {
        let defaults = UserDefaults.standard
        // NOTEIT_NOTES_DIR overrides the folder for one run (used for demos and CI screenshots).
        let environment = ProcessInfo.processInfo.environment
        let path = environment["NOTEIT_NOTES_DIR"] ?? defaults.string(forKey: Keys.folderPath)
        let folder = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultFolder
        let fileExtension = defaults.string(forKey: Keys.defaultExtension) ?? "md"
        folderURL = folder
        defaultExtension = fileExtension
        viewMode = defaults.string(forKey: Keys.viewMode).flatMap(ViewMode.init(rawValue:)) ?? .edit
        autoSync = defaults.object(forKey: Keys.autoSync) as? Bool ?? true
        store = NoteFileStore(folder: folder, defaultExtension: fileExtension)
        simplenoteAccount = defaults.string(forKey: Keys.simplenoteEmail)

        reloadFromDisk()
        createWelcomeNoteIfNeeded()
        startMonitoring()
        configureSyncEngine()
        if isSimplenoteConnected { syncNow() }
        if let title = environment["NOTEIT_SELECT"],
           let note = NoteSearch.exactTitleMatch(in: notes, query: title) {
            selectedID = note.id
        }
    }

    /// On the very first launch with an empty folder, leave a short guide as the first note.
    private func createWelcomeNoteIfNeeded() {
        guard notes.isEmpty, !defaults.bool(forKey: Keys.didOfferWelcomeNote) else { return }
        defaults.set(true, forKey: Keys.didOfferWelcomeNote)
        if let note = try? store.create(title: "Willkommen bei NoteIt", body: WelcomeNote.body, fileExtension: "md") {
            notes.append(note)
        }
    }

    static var defaultFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NoteIt", isDirectory: true)
    }

    // MARK: - Derived values

    var selectedNote: Note? {
        guard let selectedID else { return nil }
        return notes.first { $0.id == selectedID }
    }

    /// The selected note with the text currently in the editor (may not be saved yet).
    var editedNote: Note? {
        guard var note = selectedNote else { return nil }
        note.body = editorText
        return note
    }

    func noteExists(title: String) -> Bool {
        knownTitles.contains(NoteFileStore.sanitizedTitle(title).lowercased())
    }

    private func updateVisibleNotes() {
        visibleNotes = NoteSearch.filter(notes, query: query)
        knownTitles = Set(notes.map { $0.title.lowercased() })
    }

    // MARK: - Search (nvALT-style omni bar)

    private func queryChanged() {
        updateVisibleNotes()
        selectedID = NoteSearch.autoSelection(in: notes, query: query)?.id
    }

    /// Enter in the search field: open the note with exactly this title, or create it.
    func submitSearch() {
        let title = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = NoteSearch.exactTitleMatch(in: notes, query: title) {
            selectedID = match.id
        } else if !title.isEmpty {
            createNote(title: title)
        } else if let selected = selectedNote {
            selectedID = selected.id
        } else {
            return
        }
        editorFocusRequest += 1
    }

    /// ⌘N / the "new note" button: use the search text as title if there is one,
    /// otherwise create "Neue Notiz" and put the cursor into its title.
    func newNote() {
        let title = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            submitSearch()
            return
        }
        if createNote(title: "Neue Notiz") != nil {
            titleFocusPending = true
        }
    }

    func requestTitleEditing() {
        guard selectedNote != nil else { return }
        titleFocusPending = true
    }

    func moveSelection(by offset: Int) {
        guard !visibleNotes.isEmpty else { return }
        let currentIndex = selectedID.flatMap { id in visibleNotes.firstIndex { $0.id == id } }
        let newIndex: Int
        if let currentIndex {
            newIndex = min(max(currentIndex + offset, 0), visibleNotes.count - 1)
        } else {
            newIndex = offset > 0 ? 0 : visibleNotes.count - 1
        }
        selectedID = visibleNotes[newIndex].id
    }

    /// Escape: clear the search and go back to the search field.
    func cancelSearch() {
        saveNow()
        query = ""
        searchFocusRequest += 1
    }

    func requestSearchFocus() {
        searchFocusRequest += 1
    }

    func focusEditor() {
        editorFocusRequest += 1
    }

    // MARK: - Editing and autosave

    private func selectionChanged() {
        guard selectedID != editingFileName else { return }
        saveNow()
        editingFileName = selectedID
        hasUnsavedChanges = false
        // Set the text without triggering autosave.
        let newText = selectedNote?.body ?? ""
        if editorText != newText {
            loadingEditorText = true
            editorText = newText
            loadingEditorText = false
        }
    }

    private var loadingEditorText = false

    private func editorTextChanged() {
        guard !loadingEditorText, editingFileName != nil else { return }
        hasUnsavedChanges = true
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// Writes pending editor changes to disk immediately.
    func saveNow() {
        autosaveTask?.cancel()
        guard hasUnsavedChanges, let fileName = editingFileName,
              let index = notes.firstIndex(where: { $0.fileName == fileName }) else { return }
        var note = notes[index]
        note.body = editorText
        do {
            notes[index] = try store.save(note)
            hasUnsavedChanges = false
            scheduleSyncSoon()
        } catch {
            show(error)
        }
    }

    // MARK: - Note operations

    @discardableResult
    func createNote(title: String, body: String = "") -> Note? {
        saveNow()
        do {
            let note = try store.create(title: title, body: body)
            notes.append(note)
            selectedID = note.id
            scheduleSyncSoon()
            return note
        } catch {
            show(error)
            return nil
        }
    }

    func rename(_ note: Note, to newTitle: String) {
        rename(noteID: note.id, to: newTitle)
    }

    func rename(noteID: Note.ID, to newTitle: String) {
        saveNow()
        guard let current = notes.first(where: { $0.id == noteID }) else { return }
        do {
            let renamed = try store.rename(current, to: newTitle)
            guard renamed.fileName != current.fileName else { return }
            if let index = notes.firstIndex(where: { $0.id == current.id }) {
                notes[index] = renamed
            }
            if editingFileName == current.fileName {
                editingFileName = renamed.fileName
                selectedID = renamed.id
            }
            if let engine = syncEngine {
                let oldName = current.fileName, newName = renamed.fileName
                Task { await engine.noteRenamed(from: oldName, to: newName) }
            }
            scheduleSyncSoon()
        } catch {
            show(error)
        }
    }

    func beginDelete() {
        deleteTarget = selectedNote
    }

    func delete(_ note: Note) {
        if note.id == editingFileName {
            hasUnsavedChanges = false
            autosaveTask?.cancel()
        }
        do {
            try store.delete(note)
            let nextSelection = neighbour(of: note)
            notes.removeAll { $0.id == note.id }
            if selectedID == note.id {
                selectedID = nextSelection?.id
            }
            scheduleSyncSoon()
        } catch {
            show(error)
        }
    }

    private func neighbour(of note: Note) -> Note? {
        guard let index = visibleNotes.firstIndex(where: { $0.id == note.id }) else { return nil }
        if index + 1 < visibleNotes.count { return visibleNotes[index + 1] }
        return index > 0 ? visibleNotes[index - 1] : nil
    }

    func revealSelectedInFinder() {
        guard let note = selectedNote else { return }
        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL(for: note.fileName)])
    }

    /// A `[[Wiki Link]]` in the preview was clicked.
    func openWikiLink(_ title: String) {
        saveNow()
        let sanitized = NoteFileStore.sanitizedTitle(title)
        if let note = NoteSearch.exactTitleMatch(in: notes, query: sanitized) {
            query = ""
            selectedID = note.id
        } else {
            query = ""
            createNote(title: title)
            focusEditor()
        }
    }

    // MARK: - Folder

    func changeFolder(to url: URL) {
        saveNow()
        query = ""
        selectedID = nil
        folderURL = url
        defaults.set(url.path, forKey: Keys.folderPath)
        store = NoteFileStore(folder: url, defaultExtension: defaultExtension)
        reloadFromDisk()
        createWelcomeNoteIfNeeded()
        startMonitoring()
        configureSyncEngine()
        if isSimplenoteConnected { syncNow() }
        if let title = environment["NOTEIT_SELECT"],
           let note = NoteSearch.exactTitleMatch(in: notes, query: title) {
            selectedID = note.id
        }
    }

    /// On the very first launch with an empty folder, leave a short guide as the first note.
    private func createWelcomeNoteIfNeeded() {
        guard notes.isEmpty, !defaults.bool(forKey: Keys.didOfferWelcomeNote) else { return }
        defaults.set(true, forKey: Keys.didOfferWelcomeNote)
        if let note = try? store.create(title: "Willkommen bei NoteIt", body: WelcomeNote.body, fileExtension: "md") {
            notes.append(note)
        }
    }

    func reloadFromDisk() {
        do {
            let loaded = try store.loadAll()
            notes = loaded
            guard let fileName = editingFileName else { return }
            if let current = loaded.first(where: { $0.fileName == fileName }) {
                // Pick up external changes (Dropbox, Google Drive, other editors) unless we are mid-edit.
                if !hasUnsavedChanges, current.body != editorText {
                    loadingEditorText = true
                    editorText = current.body
                    loadingEditorText = false
                }
            } else if !hasUnsavedChanges {
                // Deleted or renamed outside the app.
                selectedID = nil
            } else {
                // The file disappeared while we still have unsaved text: recreate it.
                notes.append(Note(fileName: fileName, body: editorText))
                saveNow()
            }
        } catch {
            show(error)
        }
    }

    private func startMonitoring() {
        folderMonitor = FolderMonitor(url: folderURL) { [weak self] in
            self?.reloadFromDisk()
        }
    }

    // MARK: - Simplenote

    var isSimplenoteConnected: Bool { simplenoteAccount != nil && syncEngine != nil }

    private var syncStateURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folderKey = StableHash.fnv1a64(folderURL.standardizedFileURL.path)
        return support
            .appendingPathComponent("NoteIt", isDirectory: true)
            .appendingPathComponent("simplenote-\(folderKey).json")
    }

    private func configureSyncEngine() {
        syncEngine = nil
        if let account = simplenoteAccount, let token = Keychain.token(for: account) {
            let client = SimperiumClient(token: token)
            syncEngine = SimplenoteSyncEngine(store: store, client: client, stateURL: syncStateURL)
        }
        configureSyncTimer()
    }

    private func configureSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
        guard autoSync, syncEngine != nil else { return }
        syncTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { _ in
            Task { @MainActor in AppModel.shared.syncNow() }
        }
    }

    /// After local edits, sync a little later so changes reach Simplenote without a manual sync.
    private func scheduleSyncSoon() {
        guard autoSync, syncEngine != nil else { return }
        syncSoonTask?.cancel()
        syncSoonTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            self?.syncNow()
        }
    }

    func signInToSimplenote(email: String, password: String) async throws {
        let token = try await SimperiumClient.authenticate(username: email, password: password)
        try Keychain.setToken(token, for: email)
        defaults.set(email, forKey: Keys.simplenoteEmail)
        simplenoteAccount = email
        configureSyncEngine()
        syncNow()
    }

    func signOutOfSimplenote() {
        if let account = simplenoteAccount { Keychain.deleteToken(for: account) }
        defaults.removeObject(forKey: Keys.simplenoteEmail)
        simplenoteAccount = nil
        if let engine = syncEngine {
            Task { await engine.reset() }
        }
        syncEngine = nil
        configureSyncTimer()
        syncStatus = ""
    }

    func syncNow() {
        guard let engine = syncEngine, !isSyncing else { return }
        saveNow()
        syncSoonTask?.cancel()
        isSyncing = true
        syncStatus = "Synchronisiere …"
        Task {
            do {
                let report = try await engine.sync()
                syncStatus = "Simplenote: \(report.summary) · \(Date().formatted(date: .omitted, time: .shortened))"
                if !report.failures.isEmpty {
                    NSLog("NoteIt sync failures: %@", report.failures.joined(separator: "\n"))
                }
            } catch SimplenoteError.unauthorized {
                syncStatus = "Simplenote: Sitzung abgelaufen – bitte in den Einstellungen neu anmelden"
            } catch {
                syncStatus = "Simplenote: \(error.localizedDescription)"
            }
            isSyncing = false
            reloadFromDisk()
        }
    }

    // MARK: - Errors

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
