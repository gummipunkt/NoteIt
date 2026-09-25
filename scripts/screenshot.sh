#!/usr/bin/env bash
# Launches build/NoteIt.app with a few demo notes and saves screenshots to build/screenshots.
# Used by CI; also handy locally after scripts/build-app.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

DEMO="$(mktemp -d)/Notizen"
mkdir -p "$DEMO" build/screenshots

cat > "$DEMO/Projektideen.md" <<'MD'
# Projektideen für den Herbst

Ein paar Gedanken, die ich nicht vergessen will. Verwandt: [[Einkaufsliste]] und [[Leseliste]].

## Diese Woche

- [x] NoteIt einrichten
- [ ] Notizordner in **Dropbox** verschieben
- [ ] Mit *Simplenote* verbinden

> Die beste Notiz-App ist die, die man in zwei Sekunden geöffnet hat.

```swift
let note = try store.create(title: "Idee")
```

| Idee | Aufwand |
|------|---------|
| Garten-Log | klein |
| Fotobuch | mittel |
MD
printf -- '- Hafermilch\n- Äpfel\n- Kaffee\n- Brot vom Bäcker\n' > "$DEMO/Einkaufsliste.md"
printf 'Termin am Dienstag um 10 Uhr, Unterlagen mitbringen.\n' > "$DEMO/Zahnarzt.txt"
printf 'Hotel: Seeblick, Zimmer 12\nAnreise Freitag\n' > "$DEMO/Urlaub Gardasee.md"
printf 'Ideen für den Vortrag: kurze Folien, viele Bilder.\n' > "$DEMO/Vortrag Notizen.md"
touch -t 202609240930 "$DEMO/Zahnarzt.txt"
touch -t 202609201200 "$DEMO/Urlaub Gardasee.md"

APP_BIN="build/NoteIt.app/Contents/MacOS/NoteIt"
shoot() {
  local mode="$1" name="$2"
  defaults write io.github.gummipunkt.NoteIt viewMode "$mode"
  NOTEIT_NOTES_DIR="$DEMO" NOTEIT_SELECT="Projektideen" "$APP_BIN" &
  local pid=$!
  sleep 8
  screencapture -x "build/screenshots/$name.png" || true
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}
shoot edit editor
shoot split split
ls -la build/screenshots
