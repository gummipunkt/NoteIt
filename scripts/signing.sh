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
Hinweis: Kein Apple-Development-Zertifikat gefunden, die App wird nur ad hoc signiert.
Dann fragt der Schlüsselbund nach jedem Neubau erneut nach dem Simplenote-Zugang.
Abhilfe (kostenlos): Xcode → Einstellungen → Accounts → Apple-ID hinzufügen →
„Manage Certificates…“ → „+“ → „Apple Development“. Danach dieses Skript erneut starten.
MSG
}
