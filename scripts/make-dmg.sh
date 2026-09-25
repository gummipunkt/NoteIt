#!/usr/bin/env bash
# Packs build/NoteIt.app into build/NoteIt-<version>.dmg (with an Applications shortcut
# for drag-and-drop installation). Run scripts/build-app.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/NoteIt.app"
[[ -d "$APP" ]] || { echo "Missing $APP – run scripts/build-app.sh first." >&2; exit 1; }
VERSION="$(sed -n 's/.*static let version = "\(.*\)".*/\1/p' Sources/NoteIt/AppInfo.swift)"
DMG="build/NoteIt-$VERSION.dmg"

STAGING="$(mktemp -d)/NoteIt"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "NoteIt $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
echo "Done: $DMG"
