import NoteItCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NoteSidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 290, max: 420)
        } detail: {
            DetailView()
        }
        .toolbar { toolbarContent }
        .onChange(of: model.searchFocusRequest) {
            // The search lives in the toolbar; make sure the list is visible too.
            if columnVisibility == .detailOnly { columnVisibility = .all }
        }
        .confirmationDialog(
            L10n.tr(.confirmTrashFormat, model.deleteTarget?.title ?? ""),
            isPresented: Binding(
                get: { model.deleteTarget != nil },
                set: { if !$0 { model.deleteTarget = nil } }
            ),
            presenting: model.deleteTarget
        ) { note in
            Button(L10n.tr(.moveToTrashButton), role: .destructive) { model.delete(note) }
            Button(L10n.tr(.cancel), role: .cancel) {}
        }
        .alert(
            L10n.tr(.error),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button(L10n.tr(.ok)) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            OmniSearchField(
                text: $model.query,
                focusRequest: model.searchFocusRequest,
                onSubmit: { model.submitSearch() },
                onMove: { model.moveSelection(by: $0) },
                onCancel: { model.cancelSearch() }
            )
            .frame(minWidth: 220, idealWidth: 400, maxWidth: 480)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.newNote()
            } label: {
                Label(L10n.tr(.newNote), systemImage: "square.and.pencil")
            }
            .help(L10n.tr(.newNoteHelp))

            Picker(L10n.tr(.view), selection: $model.viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .help(L10n.tr(.viewModeHelp))

            if model.simplenoteAccount != nil {
                Button {
                    model.syncNow()
                } label: {
                    Label(L10n.tr(.sync), systemImage: "arrow.triangle.2.circlepath")
                        .symbolEffect(.pulse, isActive: model.isSyncing)
                }
                .disabled(model.isSyncing || !model.isSimplenoteConnected)
                .help(model.syncStatus.isEmpty ? L10n.tr(.syncHelp) : model.syncStatus)
            }
        }
    }
}

// MARK: - Sidebar

struct NoteSidebar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selectedID) {
            ForEach(model.visibleNotes) { note in
                NoteRow(note: note)
                    .tag(note.id)
                    .contextMenu {
                        Button(L10n.tr(.rename)) {
                            model.selectedID = note.id
                            model.requestTitleEditing()
                        }
                        Button(L10n.tr(.showInFinder)) {
                            model.selectedID = note.id
                            model.revealSelectedInFinder()
                        }
                        Divider()
                        Button(L10n.tr(.moveToTrash), role: .destructive) { model.deleteTarget = note }
                    }
            }
        }
        .listStyle(.sidebar)
        .onDeleteCommand { model.beginDelete() }
        .overlay { emptyState }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.visibleNotes.isEmpty {
            if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView {
                    Label(L10n.tr(.noNotesTitle), systemImage: "note.text")
                } description: {
                    Text(L10n.tr(.noNotesDescription))
                } actions: {
                    Button(L10n.tr(.newNote)) { model.newNote() }
                }
            } else {
                ContentUnavailableView {
                    Label(L10n.tr(.noMatchesTitle), systemImage: "magnifyingglass")
                } description: {
                    Text(L10n.tr(.noMatchesDescriptionFormat, model.query))
                } actions: {
                    Button(L10n.tr(.createFormat, model.query)) { model.submitSearch() }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(countLabel)
            Spacer()
            if model.isSyncing {
                ProgressView().controlSize(.mini)
            } else if model.simplenoteAccount != nil {
                Image(systemName: "checkmark.icloud")
                    .help(model.syncStatus)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private var countLabel: String {
        let total = model.notes.count
        if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
            return total == 1 ? L10n.tr(.noteCountOne) : L10n.tr(.noteCountOther, total)
        }
        return L10n.tr(.filteredCountFormat, model.visibleNotes.count, total)
    }
}

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(note.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(ShortDate.string(for: note.modificationDate))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Text(note.snippet.isEmpty ? L10n.tr(.noAdditionalText) : note.snippet)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .font(.system(size: 12))
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 2)
    }
}

// MARK: - Detail

struct DetailView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("editorFont") private var fontStyle: EditorFontStyle = .system
    @AppStorage("editorFontSize") private var fontSize = 15.0
    @AppStorage("editorNarrowColumn") private var narrowColumn = true

    var body: some View {
        if let note = model.editedNote {
            VStack(spacing: 0) {
                TitleHeader(note: note, narrowColumn: narrowColumn)
                content(for: note)
            }
            .background(Color(nsColor: .textBackgroundColor))
        } else {
            ContentUnavailableView {
                Label(L10n.tr(.noSelectionTitle), systemImage: "square.and.pencil")
            } description: {
                Text(L10n.tr(.noSelectionDescription))
            } actions: {
                Button(L10n.tr(.newNote)) { model.newNote() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    @ViewBuilder
    private func content(for note: Note) -> some View {
        switch model.viewMode {
        case .edit:
            editor(for: note)
        case .split:
            HSplitView {
                editor(for: note)
                    .frame(minWidth: 180, maxWidth: .infinity)
                preview(for: note)
                    .frame(minWidth: 180, maxWidth: .infinity)
            }
        case .preview:
            preview(for: note)
        }
    }

    private func editor(for note: Note) -> some View {
        PlainTextEditor(
            text: $model.editorText,
            noteID: note.id,
            isMarkdown: note.isMarkdown,
            fontStyle: fontStyle,
            fontSize: fontSize,
            maxTextWidth: narrowColumn && model.viewMode == .edit ? 720 : nil,
            focusRequest: model.editorFocusRequest,
            onEscape: { model.cancelSearch() }
        )
    }

    private func preview(for note: Note) -> some View {
        MarkdownPreview(
            note: note,
            baseURL: model.folderURL,
            noteExists: { model.noteExists(title: $0) },
            onWikiLink: { model.openWikiLink($0) }
        )
    }
}

/// The large, directly editable note title above the text.
struct TitleHeader: View {
    @EnvironmentObject private var model: AppModel
    let note: Note
    let narrowColumn: Bool

    @State private var draft = ""
    /// The note the draft belongs to, so a pending rename never hits the wrong note.
    @State private var draftNoteID: Note.ID?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(L10n.tr(.titlePlaceholder), text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .bold))
                .focused($isFocused)
                .onSubmit {
                    commit()
                    model.focusEditor()
                }
                .onExitCommand {
                    draft = note.title
                    model.focusEditor()
                }
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: narrowColumn && model.viewMode == .edit ? 720 : .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .onAppear {
            loadDraft()
            focusTitleIfPending()
        }
        .onChange(of: note.id) {
            commit()
            loadDraft()
        }
        .onChange(of: isFocused) {
            if !isFocused { commit() }
        }
        .onChange(of: model.titleFocusPending) {
            focusTitleIfPending()
        }
    }

    private var subtitle: String {
        let words = MarkdownSyntax.wordCount(of: note.body)
        let wordLabel = words == 1 ? L10n.tr(.wordCountOne) : L10n.tr(.wordCountOther, words)
        return "\(ShortDate.long(for: note.modificationDate)) · \(wordLabel) · \(note.fileExtension.uppercased())"
    }

    private func focusTitleIfPending() {
        guard model.titleFocusPending else { return }
        model.titleFocusPending = false
        // Let the view settle first so the focus change is not lost.
        DispatchQueue.main.async { isFocused = true }
    }

    private func loadDraft() {
        draft = note.title
        draftNoteID = note.id
    }

    private func commit() {
        guard let id = draftNoteID, let current = model.notes.first(where: { $0.id == id }) else { return }
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title != current.title else {
            if id == note.id { draft = current.title }
            return
        }
        model.rename(noteID: id, to: title)
        if let renamed = model.selectedNote, model.selectedID != id, renamed.title == NoteFileStore.sanitizedTitle(title) {
            draftNoteID = renamed.id
            draft = renamed.title
        } else if model.notes.contains(where: { $0.id == id }) {
            // Rename failed (e.g. title taken): show the real title again.
            draft = current.title
        }
    }
}

// MARK: - Dates

/// Compact dates in the app language: "08:40", "Yesterday", "Tuesday", "12/03/25".
enum ShortDate {
    private static var cache: [String: DateFormatter] = [:]

    private static func formatter(_ key: String, configure: (DateFormatter) -> Void) -> DateFormatter {
        let cacheKey = "\(L10n.language.rawValue)-\(key)"
        if let formatter = cache[cacheKey] { return formatter }
        let formatter = DateFormatter()
        formatter.locale = L10n.language.locale
        configure(formatter)
        cache[cacheKey] = formatter
        return formatter
    }

    private static var time: DateFormatter {
        formatter("time") { $0.dateStyle = .none; $0.timeStyle = .short }
    }

    private static var weekday: DateFormatter {
        formatter("weekday") { $0.setLocalizedDateFormatFromTemplate("EEEE") }
    }

    private static var date: DateFormatter {
        formatter("date") { $0.dateStyle = .short; $0.timeStyle = .none }
    }

    private static var longDate: DateFormatter {
        formatter("long") { $0.dateStyle = .long; $0.timeStyle = .short }
    }

    static func string(for value: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(value) { return time.string(from: value) }
        if calendar.isDateInYesterday(value) { return L10n.tr(.yesterday) }
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: value), to: calendar.startOfDay(for: now)).day,
           days < 7, days > 0 {
            return weekday.string(from: value).capitalized(with: L10n.language.locale)
        }
        return date.string(from: value)
    }

    static func long(for value: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(value) { return L10n.tr(.todayAtFormat, time.string(from: value)) }
        if calendar.isDateInYesterday(value) { return L10n.tr(.yesterdayAtFormat, time.string(from: value)) }
        return longDate.string(from: value)
    }
}
