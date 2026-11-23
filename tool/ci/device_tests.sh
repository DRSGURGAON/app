#!/usr/bin/env bash
# On-device test sequence (Android emulator in CI, or a USB phone: DEVICE=<serial>).
# Includes a TRUE process restart (force-stop + new process) and a device reboot.
set -euo pipefail
APP=in.docsafe.app
DEVICE="${DEVICE:-emulator-5554}"
adb_() { adb -s "$DEVICE" "$@"; }
# Every stage runs even if an earlier one failed, so one CI run reports ALL
# failures (not only the first); the script still fails at the end.
FAILED=()
stage() {
  local name="$1"; shift
  echo "== $name"
  if ! "$@"; then
    echo "::error::stage failed: $name"
    FAILED+=("$name")
  fi
}
wait_boot() {
  adb_ wait-for-device
  until [ "$(adb_ shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
  adb_ shell input keyevent 82 || true
  sleep 5
}

stage "1. Android instrumented tests (real Keystore, vault, scan save path)" \
  bash -c 'cd android && ./gradlew :app:connectedDebugAndroidTest --console=plain'

stage "2. Security flow (fresh install; ends with erase-all)" \
  flutter test integration_test/security_foundation_test.dart -d "$DEVICE"

stage "3. Preview robustness" flutter test integration_test/preview_test.dart -d "$DEVICE"

stage "3b. PDF tools" flutter test integration_test/pdf_tools_test.dart -d "$DEVICE"

stage "3c. Annotate & Sign" flutter test integration_test/annotate_test.dart -d "$DEVICE"

stage "3d. OCR and reminders" flutter test integration_test/ocr_reminders_test.dart -d "$DEVICE"

stage "3d2. Edit text" flutter test integration_test/edit_text_test.dart -d "$DEVICE"

stage "3e. Google Play Billing bridge" flutter test integration_test/billing_test.dart -d "$DEVICE"

stage "3f. Large vault performance" flutter test integration_test/perf_test.dart -d "$DEVICE"

restart_check() {
  adb_ uninstall "$APP" >/dev/null 2>&1 || true
  flutter test integration_test/restart/stage_a_test.dart -d "$DEVICE" --no-uninstall || return 1
  adb_ shell am force-stop "$APP"
  if adb_ shell pidof "$APP" >/dev/null 2>&1; then
    echo "$APP still running after force-stop"; return 1
  fi
  echo "process stopped: OK"
  flutter test integration_test/restart/stage_b_test.dart -d "$DEVICE" --no-uninstall
}
stage "4. True process restart" restart_check

reboot_check() {
  adb_ reboot
  wait_boot
  if adb_ shell pidof "$APP" >/dev/null 2>&1; then echo "note: app process started after boot"; fi
  flutter test integration_test/restart/stage_b_test.dart -d "$DEVICE" --no-uninstall
}
stage "5. Device reboot, then verify again" reboot_check

echo "== 6. Cold start of the release build (am start -W, 5 runs; first launch shows onboarding)"
adb_ uninstall "$APP" >/dev/null 2>&1 || true
ABI=$(adb_ shell getprop ro.product.cpu.abi | tr -d '\r')
case "$ABI" in x86_64) PLATFORM=android-x64 ;; arm64-v8a) PLATFORM=android-arm64 ;; *) PLATFORM=android-arm ;; esac
flutter build apk --release --target-platform "$PLATFORM" >/dev/null
adb_ install -r build/app/outputs/flutter-apk/app-release.apk >/dev/null
for i in 1 2 3 4 5; do
  adb_ shell am force-stop "$APP"
  sleep 2
  adb_ shell am start -W -n "$APP/.MainActivity" | grep -E "TotalTime" | sed "s/^/COLDSTART run $i: /"
done
adb_ shell am force-stop "$APP"

adb_ uninstall "$APP" >/dev/null 2>&1 || true
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "::error::${#FAILED[@]} device stage(s) failed:"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi
echo "== all device tests passed"
