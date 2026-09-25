#!/usr/bin/env bash
# Builds NoteIt.app into ./build (macOS only).
#   scripts/build-app.sh            → for this Mac's architecture
#   scripts/build-app.sh universal  → Apple Silicon + Intel
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH_FLAGS=()
if [[ "${1:-}" == "universal" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

# ${arr[@]+...} keeps macOS' bash 3.2 happy with an empty array under `set -u`.
swift build -c release --product NoteIt ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release --show-bin-path ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"})"

APP="build/NoteIt.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NoteIt" "$APP/Contents/MacOS/NoteIt"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>NoteIt</string>
    <key>CFBundleDisplayName</key>
    <string>NoteIt</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.gummipunkt.NoteIt</string>
    <key>CFBundleExecutable</key>
    <string>NoteIt</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>de</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS (and the Keychain) accept the app locally.
codesign --force --sign - "$APP"
echo "Fertig: $APP"
