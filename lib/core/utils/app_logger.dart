import 'package:flutter/foundation.dart';

/// Minimal logger that never prints in release builds.
///
/// Rules: log event names and error codes only — never document titles,
/// file names, paths, PINs, keys or document contents.
abstract final class AppLogger {
  static void event(String name, [String? code]) {
    if (kReleaseMode) return;
    debugPrint('[DocSafe] $name${code == null ? '' : ' ($code)'}');
  }
}
