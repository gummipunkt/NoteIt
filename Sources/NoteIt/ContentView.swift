import NoteItCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("listLayout") private var layout: ListLayout = .above

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if layout == .above {
                VSplitView {
                    NoteListView()
                        .frame(minHeight: 80, idealHeight: 200)
                    EditorArea()
                        .frame(minHeight: 150)
                }
            } else {
                HSplitView {
                    NoteListView()
                        .frame(minWidth: 180, idealWidth: 260, maxWidth: 420)
                    EditorArea()
                        .frame(minWidth: 300)
                }
            }
            Divider()
            statusBar
        }
        .sheet(item: $model.renameTarget) { note in
            RenameSheet(note: note)
        }
        .confirmationDialog(
            "„\(model.deleteTarget?.title ?? "")“ in den Papierkorb legen?",
            isPresented: Binding(
                get: { model.deleteTarget != nil },
                set: { if !$0 { model.deleteTarget = nil } }
            ),
            presenting: model.deleteTarget
        ) { note in
            Button("In den Papierkorb", role: .destructive) { model.delete(note) }
            Button("Abbrechen", role: .cancel) {}
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var searchBar: some View {
        OmniSearchField(
            text: $model.query,
            focusRequest: model.searchFocusRequest,
            onSubmit: { model.submitSearch() },
            onMove: { model.moveSelection(by: $0) },
            onCancel: { model.cancelSearch() }
        )
        .frame(height: 28)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Text(countLabel)
            Spacer()
            if model.isSyncing {
                ProgressView().controlSize(.small)
            }
            Text(model.syncStatus)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var countLabel: String {
        let total = model.notes.count
        let visible = model.visibleNotes.count
        if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
            return total == 1 ? "1 Notiz" : "\(total) Notizen"
        }
        return "\(visible) von \(total) Notizen"
    }
}

struct NoteListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selectedID) {
            ForEach(model.visibleNotes) { note in
                NoteRow(note: note)
                    .tag(note.id)
                    .contextMenu {
                        Button("Umbenennen …") { model.renameTarget = note }
                        Button("Im Finder zeigen") {
                            model.selectedID = note.id
                            model.revealSelectedInFinder()
                        }
                        Divider()
                        Button("In den Papierkorb legen …") { model.deleteTarget = note }
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .onDeleteCommand { model.beginDelete() }
        .overlay {
            if model.visibleNotes.isEmpty {
                Text(model.query.isEmpty ? "Noch keine Notizen.\nOben tippen und ⏎ drücken, um eine zu erstellen." : "Keine Treffer – ⏎ erstellt „\(model.query)“")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
}

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(note.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(note.modificationDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            if !note.snippet.isEmpty {
                Text(note.snippet)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct EditorArea: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("editorFontSize") private var fontSize = 14.0
    @AppStorage("editorMonospaced") private var monospaced = true

    var body: some View {
        if let note = model.editedNote {
            if model.showPreview {
                HSplitView {
                    editor(for: note)
                        .frame(minWidth: 200)
                    MarkdownPreview(
                        note: note,
                        baseURL: model.folderURL,
                        noteExists: { model.noteExists(title: $0) },
                        onWikiLink: { model.openWikiLink($0) }
                    )
                    .frame(minWidth: 200)
                }
            } else {
                editor(for: note)
            }
        } else {
            Text("Keine Notiz ausgewählt")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private func editor(for note: Note) -> some View {
        PlainTextEditor(
            text: $model.editorText,
            noteID: note.id,
            fontSize: fontSize,
            monospaced: monospaced,
            focusRequest: model.editorFocusRequest,
            onEscape: { model.cancelSearch() }
        )
    }
}

struct RenameSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let note: Note
    @State private var title = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notiz umbenennen").font(.headline)
            TextField("Titel", text: $title)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 320)
                .onSubmit(commit)
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Umbenennen", action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .onAppear { title = note.title }
    }

    private func commit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        dismiss()
        model.rename(note, to: trimmed)
    }
}
