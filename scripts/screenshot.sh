#!/usr/bin/env bash
# Launches build/NoteIt.app with a few demo notes and saves screenshots to build/screenshots.
# Used by CI; also handy locally after scripts/build-app.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

DEMO="$(mktemp -d)/Notes"
mkdir -p "$DEMO" build/screenshots

cat > "$DEMO/Project ideas.md" <<'MD'
# Project ideas for the autumn

A few thoughts I don't want to forget. Related: [[Shopping list]] and [[Reading list]].

## This week

- [x] Set up NoteIt
- [ ] Move the notes folder to **Dropbox**
- [ ] Connect *Simplenote*

> The best notes app is the one you can open in two seconds.

```swift
let note = try store.create(title: "Idea")
```

| Idea | Effort |
|------|--------|
| Garden log | small |
| Photo book | medium |
MD
printf -- '- Oat milk\n- Apples\n- Coffee\n- Bread from the bakery\n' > "$DEMO/Shopping list.md"
printf 'Appointment on Tuesday at 10 am, bring the documents.\n' > "$DEMO/Dentist.txt"
printf 'Hotel: Lakeview, room 12\nArrival on Friday\n' > "$DEMO/Holiday Lake Garda.md"
printf 'Ideas for the talk: short slides, lots of pictures.\n' > "$DEMO/Talk notes.md"
touch -t 202609240930 "$DEMO/Dentist.txt"
touch -t 202609201200 "$DEMO/Holiday Lake Garda.md"

APP_BIN="build/NoteIt.app/Contents/MacOS/NoteIt"
shoot() {
  local mode="$1" language="$2" name="$3"
  defaults write io.github.gummipunkt.NoteIt viewMode "$mode"
  defaults write io.github.gummipunkt.NoteIt appLanguage "$language"
  NOTEIT_NOTES_DIR="$DEMO" NOTEIT_SELECT="Project ideas" "$APP_BIN" &
  local pid=$!
  sleep 8
  screencapture -x "build/screenshots/$name.png" || true
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}
shoot edit en editor-en
shoot split en split-en
for language in de fr it es; do
  shoot split "$language" "split-$language"
done
defaults delete io.github.gummipunkt.NoteIt appLanguage 2>/dev/null || true
ls -la build/screenshots
