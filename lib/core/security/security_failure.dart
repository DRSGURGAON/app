import 'package:flutter/services.dart';

/// Error codes raised by the native security bridge
/// (see SecurityHostApiImpl.kt). Messages never contain secrets or paths.
enum SecurityErrorCode {
  locked,
  integrity,
  lowStorage,
  keyUnavailable,
  invalidInput,
  io,
  noActivity,
  busy,
  databaseKey,
  scannerUnavailable,
  pdfUnreadable,
  tooLarge,
  unknown;

  static SecurityErrorCode fromNative(String code) => switch (code) {
    'LOCKED' => locked,
    'INTEGRITY' => integrity,
    'LOW_STORAGE' => lowStorage,
    'KEY_UNAVAILABLE' => keyUnavailable,
    'INVALID_INPUT' => invalidInput,
    'IO' => io,
    'NO_ACTIVITY' => noActivity,
    'BUSY' => busy,
    'SCANNER_UNAVAILABLE' => scannerUnavailable,
    'PDF_UNREADABLE' => pdfUnreadable,
    _ => unknown,
  };
}

/// Typed failure surfaced to repositories and UI.
class SecurityFailure implements Exception {
  const SecurityFailure(this.code);

  factory SecurityFailure.fromPlatform(PlatformException e) =>
      SecurityFailure(SecurityErrorCode.fromNative(e.code));

  final SecurityErrorCode code;

  @override
  String toString() => 'SecurityFailure(${code.name})';
}
