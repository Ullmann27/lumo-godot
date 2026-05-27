#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# setup_android_keystore.sh - erzeugt einen Debug-Keystore fuer Godot
#   Android-Exports (Debug-Variante). Idempotent: falls bereits ein
#   Keystore existiert, wird er NICHT ueberschrieben - exit 0 mit Hinweis.
#
# Pfad: ~/.android/debug.keystore (Standard fuer Android-Toolchain)
#
# Inhalt: RSA 2048, gueltig 9999 Tage, alias=androiddebugkey,
#   storepass=keypass=android, dname=CN=Android Debug,O=Android,C=US
#   (entspricht 1:1 dem was Android Studio bei Erst-Setup generiert).
# ────────────────────────────────────────────────────────────────────────
set -euo pipefail

KS="${HOME}/.android/debug.keystore"
KS_DIR="${HOME}/.android"

if ! command -v keytool >/dev/null 2>&1; then
    echo "[setup-keystore] FAIL: keytool nicht gefunden."
    echo "  Installiere JDK: apt install -y openjdk-17-jdk-headless"
    exit 1
fi

if [[ -f "$KS" ]]; then
    echo "[setup-keystore] EXISTS: $KS"
    echo "  -> nichts zu tun (idempotent)."
    keytool -list -keystore "$KS" -storepass android 2>&1 | tail -5 || true
    exit 0
fi

mkdir -p "$KS_DIR"

echo "[setup-keystore] Erzeuge Debug-Keystore: $KS"
keytool -keyalg RSA -genkeypair \
    -alias androiddebugkey \
    -keypass android \
    -keystore "$KS" \
    -storepass android \
    -dname "CN=Android Debug,O=Android,C=US" \
    -validity 9999 \
    -deststoretype pkcs12

if [[ ! -f "$KS" ]]; then
    echo "[setup-keystore] FAIL: Keystore wurde nicht erzeugt."
    exit 1
fi

echo "[setup-keystore] DONE: $KS"
ls -la "$KS"
keytool -list -keystore "$KS" -storepass android 2>&1 | tail -5
