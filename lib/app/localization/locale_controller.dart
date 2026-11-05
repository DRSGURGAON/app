import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/lock_controller.dart';

/// UI language. Hindi is the default; the choice is stored natively as a
/// non-sensitive preference so it is available before unlock.
final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  static const supported = [Locale('hi'), Locale('en')];

  @override
  Locale build() {
    Future.microtask(_load);
    return const Locale('hi');
  }

  Future<void> _load() async {
    try {
      final code = await ref.read(securityServiceProvider).getLanguage();
      if (code == 'en' || code == 'hi') state = Locale(code!);
    } catch (_) {
      // Keep the default.
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
