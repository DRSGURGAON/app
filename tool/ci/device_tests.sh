#!/usr/bin/env bash
# On-device test sequence (Android emulator in CI, or a USB phone: DEVICE=<serial>).
# Includes a TRUE process restart (force-stop + new process) and a device reboot.
set -euo pipefail
APP=in.docsafe.app
DEVICE="${DEVICE:-emulator-5554}"
adb_() { adb -s "$DEVICE" "$@"; }
wait_boot() {
  adb_ wait-for-device
  until [ "$(adb_ shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
  adb_ shell input keyevent 82 || true
  sleep 5
}

echo "== 1. Android instrumented tests (real Keystore, vault, scan save path)"
(cd android && ./gradlew :app:connectedDebugAndroidTest --console=plain)

echo "== 2. Security flow (fresh install; ends with erase-all; app uninstalled after)"
flutter test integration_test/security_foundation_test.dart -d "$DEVICE"

echo "== 3. Preview robustness (fresh install)"
flutter test integration_test/preview_test.dart -d "$DEVICE"

echo "== 3b. PDF tools (real PDFium + native image/compress)"
flutter test integration_test/pdf_tools_test.dart -d "$DEVICE"

echo "== 3c. Annotate & Sign (real overlay render + native flatten + PDFium)"
flutter test integration_test/annotate_test.dart -d "$DEVICE"

echo "== 4. True process restart"
adb_ uninstall "$APP" >/dev/null 2>&1 || true
flutter test integration_test/restart/stage_a_test.dart -d "$DEVICE" --no-uninstall
adb_ shell am force-stop "$APP"
if adb_ shell pidof "$APP" >/dev/null 2>&1; then
  echo "::error::$APP still running after force-stop"; exit 1
fi
echo "process stopped: OK"
flutter test integration_test/restart/stage_b_test.dart -d "$DEVICE" --no-uninstall

echo "== 5. Device reboot, then verify again"
adb_ reboot
wait_boot
if adb_ shell pidof "$APP" >/dev/null 2>&1; then echo "note: app process started after boot"; fi
flutter test integration_test/restart/stage_b_test.dart -d "$DEVICE" --no-uninstall

adb_ uninstall "$APP" >/dev/null 2>&1 || true
echo "== all device tests passed"
