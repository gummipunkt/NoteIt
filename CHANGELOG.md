# Changelog

All notable changes to NoteIt. Version numbers follow [Semantic Versioning](https://semver.org/).

## [0.3.0] – 2026-09-25

### Added
- NoteIt is now available in English, German, French, Italian and Spanish. It follows the system language; another language can be chosen in Settings → General.
- The welcome note is written in the app language.
- Disk image (`NoteIt-<version>.dmg`) with drag-and-drop installation; `scripts/make-dmg.sh`.
- Version tags automatically publish a GitHub release with the DMG.
- `scripts/run.sh` and `scripts/build-app.sh` sign with your Apple Development certificate when available, so the Keychain stops asking after every rebuild.

### Changed
- The repository (README, changelog, CI, scripts) is now in English; the German README is `README.de.md`.
- Sidebar previews no longer show Markdown syntax and skip a first line that repeats the title.
- Slightly tighter paragraph spacing in the editor; smaller default window.

### Fixed
- Task list checkboxes in the preview are shown on the same line as their text.
- CI artifact no longer contains a zip inside a zip.

## [0.2.1] – 2026-09-25

### Fixed
- 0.2.0 did not compile: code for the welcome note had accidentally been duplicated in `AppModel.swift`.

## [0.2.0] – 2026-09-25

> Note: this version does not build – use 0.2.1 or later.

### Added
- Modern design: sidebar with the note list (title, date, preview text), search field in the toolbar, large directly editable title above the text, centered text column.
- “New Note” button in the toolbar and ⌘N. The search text becomes the title if present; otherwise a “New Note” is created with its title selected.
- Markdown highlighting in the editor (headings, bold, italic, code, lists, tasks, quotes, links, wiki links).
- Three views: Write, Split, Preview (⌘1 · ⌘2 · ⌘3).
- Font choice: SF Pro, New York (serif) or SF Mono.
- Redesigned preview that picks up the macOS accent color.
- Empty states with hints, welcome note on first launch.
- App icon.
- “About NoteIt” with version, copyright, contact and a link to the source code.
- License: GNU GPL 3.0.

### Changed
- “Rename” edits the title in place instead of opening a separate window.
- The “list above / beside” setting was removed; the list always lives in the sidebar.

## [0.1.0] – 2026-09-25

### Added
- First version: nvALT-style search field to search and create, note list, editor with autosave.
- Notes as `.md` and `.txt` files; sync via a Dropbox or Google Drive folder.
- Markdown preview with wiki links (`[[Note]]`).
- Two-way sync with Simplenote.

[0.3.0]: https://github.com/gummipunkt/NoteIt/releases/tag/v0.3.0
[0.2.1]: https://github.com/gummipunkt/NoteIt/releases/tag/v0.2.1
[0.2.0]: https://github.com/gummipunkt/NoteIt/releases/tag/v0.2.0
[0.1.0]: https://github.com/gummipunkt/NoteIt/releases/tag/v0.1.0
