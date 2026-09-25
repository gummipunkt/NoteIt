# Changelog

Alle nennenswerten Änderungen an NoteIt. Die Versionsnummern folgen [Semantic Versioning](https://semver.org/lang/de/).

## [0.2.1] – 2026-09-25

### Behoben
- 0.2.0 ließ sich nicht kompilieren: Code für die Willkommens-Notiz war versehentlich doppelt in `AppModel.swift` gelandet.

## [0.2.0] – 2026-09-25

> Hinweis: Diese Version lässt sich nicht bauen, bitte 0.2.1 verwenden.

### Neu
- Modernes Design: Seitenleiste mit Notizliste (Titel, Datum, Vorschautext), Suchfeld in der Symbolleiste, großer, direkt bearbeitbarer Titel über dem Text, zentrierte Textspalte.
- Knopf „Neue Notiz“ in der Symbolleiste und ⌘N. Mit Suchtext wird dieser zum Titel, sonst entsteht „Neue Notiz“ mit markiertem Titel.
- Markdown-Hervorhebung direkt im Editor (Überschriften, fett, kursiv, Code, Listen, Aufgaben, Zitate, Links, Wiki-Links).
- Drei Ansichten: Schreiben, Geteilt, Vorschau (⌘1 · ⌘2 · ⌘3).
- Schriftwahl: SF Pro, New York (Serif) oder SF Mono.
- Überarbeitete Vorschau, die die Akzentfarbe von macOS übernimmt.
- Leere Zustände mit Hinweisen, Willkommens-Notiz beim ersten Start.
- App-Icon.
- „Über NoteIt“ mit Version, Copyright, Kontakt und Link zum Quellcode.
- Lizenz: GNU GPL 3.0.

### Geändert
- „Umbenennen“ bearbeitet jetzt den Titel direkt, statt ein eigenes Fenster zu öffnen.
- Die Einstellung „Liste oben / links“ entfällt, die Liste steht immer in der Seitenleiste.

## [0.1.0] – 2026-09-25

### Neu
- Erste Version: nvALT-Suchfeld zum Suchen und Anlegen, Notizliste, Editor mit automatischem Speichern.
- Notizen als `.md`- und `.txt`-Dateien, Sync über Dropbox- oder Google-Drive-Ordner.
- Markdown-Vorschau mit Wiki-Links (`[[Notiz]]`).
- Zwei-Wege-Sync mit Simplenote.

[0.2.1]: https://github.com/gummipunkt/NoteIt/releases/tag/v0.2.1
[0.2.0]: https://github.com/gummipunkt/NoteIt/releases/tag/v0.2.0
[0.1.0]: https://github.com/gummipunkt/NoteIt/releases/tag/v0.1.0
