# NoteIt

Eine schnelle Notiz-App für macOS im Stil von **nvALT** / Notational Velocity, geschrieben in Swift (SwiftUI + AppKit).

## Funktionen

- **Ein Feld für Suchen und Erstellen**: Beim Tippen wird die Liste live gefiltert. ⏎ öffnet die Notiz mit genau diesem Titel oder legt sie neu an.
- **Liste und Editor**: Die Liste steht wahlweise über oder neben dem Editor. Mit ↑/↓ blätterst du direkt aus dem Suchfeld durch die Notizen.
- **Automatisches Speichern**: Es gibt keinen Speichern-Knopf. Änderungen landen nach kurzer Tipp-Pause auf der Platte, außerdem beim Wechsel der Notiz und beim Beenden.
- **Klartextdateien**: Jede Notiz ist eine `.md`- oder `.txt`-Datei, der Dateiname ist der Titel. Vorhandene Dateien im Ordner werden einfach mitgelesen.
- **Markdown-Vorschau**: Die Vorschau aktualisiert sich live, unterstützt GitHub-Markdown (Tabellen, Durchstreichen, Code) und folgt dem hellen bzw. dunklen Modus.
- **Wiki-Links**: `[[Andere Notiz]]` oder `[[Andere Notiz|Anzeigetext]]` sind in der Vorschau anklickbar. Links auf noch nicht vorhandene Notizen erscheinen rot gestrichelt und legen die Notiz beim Klick an.
- **Sync mit Dropbox und Google Drive**: Leg den Notizordner in den Dropbox- oder Google-Drive-Ordner. Die Einstellungen erkennen beide automatisch. Änderungen von außen erscheinen sofort (über FSEvents).
- **Sync mit Simplenote**: Beidseitige Synchronisation über die Simperium-API. Sie läuft automatisch alle 3 Minuten und kurz nach Änderungen.

## Tastenkürzel

| Kürzel | Aktion |
|---|---|
| ⌘L / ⌘N | Zum Suchfeld (suchen oder neue Notiz) |
| ⏎ im Suchfeld | Notiz öffnen oder erstellen, danach weiter im Editor |
| ↑ / ↓ im Suchfeld | Vorherige / nächste Notiz |
| Esc | Suche leeren, zurück ins Suchfeld |
| ⌘R | Notiz umbenennen |
| ⌫ in der Liste | Notiz in den Papierkorb legen |
| ⌘⇧P | Vorschau ein- oder ausblenden |
| ⌘⇧S | Mit Simplenote synchronisieren |
| ⌘, | Einstellungen |

## Bauen und Starten

Voraussetzung ist macOS 14 oder neuer mit Xcode (bzw. den Xcode Command Line Tools).

```bash
# direkt starten
swift run NoteIt

# oder ein richtiges App-Bundle nach build/NoteIt.app bauen
scripts/build-app.sh            # für diesen Mac
scripts/build-app.sh universal  # Apple Silicon + Intel
```

Alternativ öffnest du `Package.swift` in Xcode, wählst das Schema **NoteIt** und drückst ⌘R.

Jeder Push baut die App außerdem per GitHub Actions. Das fertige `NoteIt.zip` liegt dann als Artefakt am jeweiligen Workflow-Lauf.

Beim ersten Start liegen die Notizen in `~/Documents/NoteIt`. Unter **Einstellungen → Speicherort** kannst du das ändern.

## Simplenote

Unter **Einstellungen → Simplenote** meldest du dich mit E-Mail und Passwort an. Gespeichert wird nur ein Zugriffstoken im macOS-Schlüsselbund, nicht das Passwort.

So werden die Notizen abgebildet:

- Die erste Zeile einer Simplenote-Notiz wird zum Titel und damit zum Dateinamen. Ein führendes `# ` wird dabei entfernt, bleibt in Simplenote aber erhalten.
- Der Rest wird zum Dateiinhalt.
- In Simplenote als Markdown markierte Notizen werden zu `.md`-Dateien. Umgekehrt werden `.md`-Dateien in Simplenote als Markdown markiert.

So werden Konflikte und Löschungen behandelt:

- Wurde eine Notiz auf beiden Seiten geändert, schickt NoteIt die lokale Fassung relativ zur zuletzt synchronisierten Version. Simperium führt dann beide Änderungen zusammen. Klappt das nicht, bleibt deine lokale Fassung als „Titel (Konflikt)“ erhalten.
- Löschst du eine Notiz lokal, landet sie im Simplenote-Papierkorb.
- Wird eine Notiz in Simplenote gelöscht, wandert die Datei in den macOS-Papierkorb.
- Bei Änderung auf der einen und Löschung auf der anderen Seite gewinnt immer die Änderung.

Welche Notiz zu welcher Datei gehört, merkt sich NoteIt unter `~/Library/Application Support/NoteIt/`, und zwar getrennt pro Notizordner.

## Aufbau

```
Sources/NoteItCore/        plattformunabhängige Logik (läuft und testet auch unter Linux)
  Note.swift               Datenmodell
  NoteFileStore.swift      .md/.txt-Dateien lesen, schreiben, umbenennen, löschen
  NoteSearch.swift         nvALT-Suche und Sortierung
  WikiLinks.swift          [[Wiki-Links]] finden und in Markdown-Links umwandeln
  MarkdownRenderer.swift   Markdown → HTML (swift-markdown / cmark-gfm)
  Simplenote/              Simperium-Client und Sync-Engine
Sources/NoteIt/            die macOS-App (SwiftUI + AppKit)
Tests/NoteItCoreTests/     Tests, u. a. für den Sync mit einem simulierten Simperium-Server
```

Tests:

```bash
swift test                # auf dem Mac
scripts/test-linux.sh     # Kern-Tests in Docker unter Linux
```
