# Shared by run.sh and build-app.sh (source it, don't execute it).
#
# Finds a stable code signing identity. With a real certificate the Keychain
# remembers "Always Allow" across rebuilds; with an ad-hoc signature ("-") every
# build looks like a different app to macOS and the Keychain asks again.
#
# Override with: CODESIGN_IDENTITY="Apple Development: Name (TEAMID)"
find_signing_identity() {
  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    echo "$CODESIGN_IDENTITY"
    return
  fi
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p;s/.*"\(Developer ID Application: [^"]*\)".*/\1/p' \
    | head -1
}

warn_ad_hoc() {
  cat >&2 <<'MSG'
Note: no Apple Development certificate found, signing ad hoc only.
The Keychain will then ask for the Simplenote token again after every rebuild.
Fix (free): Xcode → Settings → Accounts → add your Apple ID →
"Manage Certificates…" → "+" → "Apple Development". Then run this script again.
MSG
}
