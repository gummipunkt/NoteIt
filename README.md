<p align="center"><img src="Assets/AppIcon.png" width="128" alt="NoteIt icon"></p>

# NoteIt

A fast note-taking app for macOS in the spirit of **nvALT** / Notational Velocity, written in Swift (SwiftUI + AppKit).

**Version 0.3.0** · © 2026 Patrick Walter · [www.gummipunkt.eu](https://www.gummipunkt.eu) · [noteit@gummipunkt.eu](mailto:noteit@gummipunkt.eu) · License: [GPL 3.0](LICENSE)

Available in English, German, French, Italian and Spanish. · [Deutsche Anleitung](README.de.md)

## Download

Get the latest `NoteIt-<version>.dmg` from the [Releases](https://github.com/gummipunkt/NoteIt/releases) page, open it and drag **NoteIt** into **Applications**.

NoteIt is not notarized by Apple yet. On first launch macOS may refuse to open it: open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** (or remove the quarantine flag with `xattr -dr com.apple.quarantine /Applications/NoteIt.app`).

## Creating a note

- **Fastest way (like nvALT):** click the search field at the top (or press ⌘L), type a title and press ⏎. If no note with that title exists, it is created and you keep typing in the editor.
- **Button or ⌘N:** the “New Note” button (pencil icon) in the toolbar creates a “New Note”. Just type over the selected title and confirm with ⏎.
- You can rename a note at any time via the large title above the text (or ⌘R).

## Features

- **One field to search and create**: the list filters as you type. ⏎ opens the note with exactly that title or creates it.
- **Modern macOS design**: sidebar with the note list (title, date, preview text), search in the toolbar, large editable title, centered text column, light and dark mode. ↑/↓ move through the notes right from the search field.
- **Markdown highlighting while writing**: headings, **bold**, *italic*, code, lists, tasks and links are recognizable in the editor. Fonts: SF Pro, New York (serif) or SF Mono.
- **Three views**: Write, Split (editor + preview) and Preview (⌘1 · ⌘2 · ⌘3).
- **Autosave**: there is no save button. Changes are written after a short pause in typing, when switching notes and when quitting.
- **Plain text files**: every note is a `.md` or `.txt` file whose file name is the title. Existing files in the folder simply show up.
- **Markdown preview**: updates live, supports GitHub Flavored Markdown (tables, strikethrough, task lists, code) and follows light/dark mode.
- **Wiki links**: `[[Other note]]` or `[[Other note|label]]` are clickable in the preview. Links to notes that don’t exist yet are shown dashed in red and create the note when clicked.
- **Sync via Dropbox and Google Drive**: put the notes folder inside your Dropbox or Google Drive folder; Settings detects both. Outside changes appear immediately (FSEvents).
- **Sync with Simplenote**: two-way sync via the Simperium API, automatically every 3 minutes and shortly after changes.
- **Five languages**: English, Deutsch, Français, Italiano, Español. NoteIt follows the system language; you can pick another one in Settings → General.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘N | New note (uses the search text as title, if any) |
| ⌘L | Go to the search field |
| ⏎ in the search field | Open or create the note, then continue in the editor |
| ↑ / ↓ in the search field | Previous / next note |
| Esc | Clear the search and go back to the search field |
| ⌘R | Edit the title (rename) |
| ⌫ in the list | Move the note to the Trash |
| ⌘1 · ⌘2 · ⌘3 | Write · Split · Preview |
| ⌘⇧S | Sync with Simplenote |
| ⌘, | Settings |

## Building and running

Requires macOS 14 or later with Xcode (or the Xcode Command Line Tools).

```bash
# run for development (builds, signs and launches)
scripts/run.sh

# or build a proper app bundle into build/NoteIt.app …
scripts/build-app.sh            # for this Mac
scripts/build-app.sh universal  # Apple Silicon + Intel
# … and pack it into build/NoteIt-<version>.dmg
scripts/make-dmg.sh
```

**Keychain prompt on every launch?** macOS remembers “Always Allow” by code signature. `swift run NoteIt` signs every build ad hoc, so each build looks like a new app. `scripts/run.sh` and `scripts/build-app.sh` automatically use your Apple Development certificate if you have one; then a single “Always Allow” is enough. The certificate is free: Xcode → Settings → Accounts → add your Apple ID → “Manage Certificates…” → “+” → “Apple Development”. To force a specific identity use `CODESIGN_IDENTITY="Apple Development: …" scripts/run.sh`.

Alternatively open `Package.swift` in Xcode, choose the **NoteIt** scheme and press ⌘R.

On first launch the notes live in `~/Documents/NoteIt`, together with a short welcome note. Change the location under **Settings → Storage**.

## Versions and releases

- The version number lives in exactly one place: `Sources/NoteIt/AppInfo.swift`. The build script copies it into the app bundle; the build number is the commit count.
- Changes are listed in the [CHANGELOG](CHANGELOG.md).
- Every push is built by GitHub Actions; the disk image and screenshots (one per language) are attached to the workflow run as artifacts.
- Pushing a version tag (`git tag -a v0.3.0 -m "NoteIt 0.3.0" && git push origin v0.3.0`) additionally publishes a GitHub release with the DMG and the matching CHANGELOG section.

## Simplenote

Sign in under **Settings → Simplenote** with your email and password. Only an access token is stored (in the macOS Keychain), never the password.

How notes are mapped:

- The first line of a Simplenote note becomes the title and thus the file name. A leading `# ` is removed for the file name but kept in Simplenote.
- The rest becomes the file content.
- Notes marked as Markdown in Simplenote become `.md` files; `.md` files are marked as Markdown in Simplenote.

Conflicts and deletions:

- If a note changed on both sides, NoteIt sends the local version relative to the last synced version and Simperium merges both edits. If that fails, your local version is kept as “Title (Conflict)”.
- Deleting a note locally moves it to the Simplenote trash.
- Deleting a note in Simplenote moves the file to the macOS Trash.
- An edit on one side always wins over a deletion on the other.

NoteIt remembers which note belongs to which file in `~/Library/Application Support/NoteIt/`, separately for each notes folder.

## Project layout

```
Sources/NoteItCore/        platform-independent logic (also builds and tests on Linux)
  Note.swift               data model
  NoteFileStore.swift      read, write, rename and delete .md/.txt files
  NoteSearch.swift         nvALT-style search and ranking
  WikiLinks.swift          find [[wiki links]] and turn them into Markdown links
  MarkdownSyntax.swift     tokenizer for editor highlighting
  MarkdownRenderer.swift   Markdown → HTML (swift-markdown / cmark-gfm)
  L10n.swift               all UI texts in five languages
  Simplenote/              Simperium client and sync engine
Sources/NoteIt/            the macOS app (SwiftUI + AppKit)
Tests/NoteItCoreTests/     tests, including sync against a simulated Simperium server
```

Translations live in `Sources/NoteItCore/L10n.swift`. Every text is a case of `L10nKey`; the compiler rejects a key that is missing a language, and a test checks that all languages use the same placeholders.

The app icon is drawn by `scripts/make-icon.py` (requires Pillow).

Tests:

```bash
swift test                # on the Mac
scripts/test-linux.sh     # core tests in Docker on Linux
```

## License

Copyright © 2026 Patrick Walter · [www.gummipunkt.eu](https://www.gummipunkt.eu) · [noteit@gummipunkt.eu](mailto:noteit@gummipunkt.eu)

NoteIt is free software: you can redistribute it and/or modify it under the terms of the **GNU General Public License, version 3**, as published by the Free Software Foundation.

NoteIt is distributed in the hope that it will be useful, but **without any warranty**; without even the implied warranty of merchantability or fitness for a particular purpose. See the [LICENSE](LICENSE) file for details.
