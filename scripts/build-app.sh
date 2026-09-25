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

# Version comes from AppInfo.swift; the build number is the number of commits.
VERSION="$(sed -n 's/.*static let version = "\(.*\)".*/\1/p' Sources/NoteIt/AppInfo.swift)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
YEAR="$(sed -n 's/.*static let copyrightYear = "\(.*\)".*/\1/p' Sources/NoteIt/AppInfo.swift)"
AUTHOR="$(sed -n 's/.*static let author = "\(.*\)".*/\1/p' Sources/NoteIt/AppInfo.swift)"

APP="build/NoteIt.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NoteIt" "$APP/Contents/MacOS/NoteIt"

# App icon: Assets/AppIcon.png → AppIcon.icns
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size Assets/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Assets/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
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
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHumanReadableCopyright</key>
    <string>© ${YEAR} ${AUTHOR} · GPL-3.0</string>
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

# Sign with a stable identity if available (see scripts/signing.sh), otherwise ad hoc.
source scripts/signing.sh
IDENTITY="$(find_signing_identity)"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --sign "$IDENTITY" "$APP"
  echo "Signiert mit: $IDENTITY"
else
  codesign --force --sign - "$APP"
  warn_ad_hoc
fi
echo "Fertig: $APP (Version $VERSION, Build $BUILD)"
