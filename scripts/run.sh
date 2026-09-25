#!/usr/bin/env bash
# Builds and starts NoteIt for development – like `swift run NoteIt`, but signed with
# your Apple Development certificate, so the Keychain prompt appears only once.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing.sh

swift build --product NoteIt
BIN="$(swift build --show-bin-path)/NoteIt"

IDENTITY="$(find_signing_identity)"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --sign "$IDENTITY" --identifier io.github.gummipunkt.NoteIt "$BIN"
else
  warn_ad_hoc
fi
exec "$BIN" "$@"
