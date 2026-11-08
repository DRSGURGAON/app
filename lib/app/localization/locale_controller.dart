import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/lock_controller.dart';

/// The phone's preferred locale (overridden in tests).
final deviceLocaleProvider = Provider<Locale>(
  (ref) => PlatformDispatcher.instance.locale,
);

/// Language used until the user picks one: Hindi on a Hindi phone, otherwise
/// English (the only other UI language so far).
Locale defaultLocaleFor(Locale device) =>
    device.languageCode == 'hi' ? const Locale('hi') : const Locale('en');

/// UI language. Follows the phone until the user chooses in Settings; the
/// choice is stored natively as a non-sensitive preference so it is available
/// before unlock.
final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  static const supported = [Locale('hi'), Locale('en')];

  @override
  Locale build() {
    Future.microtask(_load);
    return defaultLocaleFor(ref.read(deviceLocaleProvider));
  }

  Future<void> _load() async {
    try {
      final code = await ref.read(securityServiceProvider).getLanguage();
      if (code == 'en' || code == 'hi') state = Locale(code!);
    } catch (_) {
      // Keep the phone-based default.
    }
  }

  Future<void> setLanguage(String code) async {
    state = Locale(code);
    try {
      await ref.read(securityServiceProvider).setLanguage(code);
    } catch (_) {
      // Preference is cosmetic; the in-memory choice still applies.
    }
  }
}
