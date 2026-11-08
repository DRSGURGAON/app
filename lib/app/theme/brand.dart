import 'package:flutter/material.dart';

/// DocSafe brand tokens. Deep navy conveys security; a clear indigo is the
/// action colour; teal means "protected / OK", amber "attention", red
/// "expired / danger". Gold is reserved for Premium.
abstract final class Brand {
  /// Body text.
  static const fontFamily = 'PlusJakartaSans';

  /// Headings: geometric display face.
  static const displayFamily = 'Sora';
  static const fontFallback = ['PlusJakartaSans', 'NotoSansDevanagari'];

  static const navy950 = Color(0xFF060B26);
  static const navy900 = Color(0xFF0B1437);
  static const navy800 = Color(0xFF15215C);
  static const navy700 = Color(0xFF1F2E7A);
  static const indigo = Color(0xFF3446D4);
  static const indigoLight = Color(0xFF8E9BFF);
  static const indigoTint = Color(0xFFE9ECFF);
  static const teal = Color(0xFF0E9F87);
  static const tealTint = Color(0xFFDDF5F0);
  static const amber = Color(0xFFC77700);
  static const amberTint = Color(0xFFFFF1D6);
  static const red = Color(0xFFD63B4A);
  static const redTint = Color(0xFFFDE4E7);
  static const gold = Color(0xFFF2B53A);
  static const goldDeep = Color(0xFFD48A0A);

  static const canvas = Color(0xFFF4F5FA);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE6E8F0);
  static const ink = Color(0xFF111633);
  static const inkMuted = Color(0xFF5B6180);

  /// App-wide background: royal blue at the top fading into deep navy.
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D2A7A), Color(0xFF09195A), Color(0xFF050B26)],
    stops: [0, .45, 1],
  );

  /// Glass surfaces on the gradient.
  static const glass = Color(0x12FFFFFF);
  static const glassStrong = Color(0x1FFFFFFF);
  static const glassBorder = Color(0x21FFFFFF);
  static const textMuted = Color(0xFFA7B2D8);
  static const dialog = Color(0xFF111C4D);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy900, navy700],
  );

  static const premiumGradient = LinearGradient(colors: [gold, goldDeep]);
}

/// Colour + icon per default category, so documents are recognisable at a glance.
class CategoryStyle {
  const CategoryStyle(this.color, this.icon);
  final Color color;
  final IconData icon;

  static const _styles = <String, CategoryStyle>{
    'identity': CategoryStyle(Color(0xFF8C9BFF), Icons.badge_outlined),
    'education': CategoryStyle(Color(0xFFB892FF), Icons.school_outlined),
    'vehicle': CategoryStyle(Color(0xFF5DBBF7), Icons.directions_car_outlined),
    'finance': CategoryStyle(Color(0xFF4FD99E), Icons.account_balance_outlined),
    'insurance': CategoryStyle(
      Color(0xFF4FD1B8),
      Icons.health_and_safety_outlined,
    ),
    'medical': CategoryStyle(
      Color(0xFFFF82A9),
      Icons.medical_services_outlined,
    ),
    'property': CategoryStyle(Color(0xFFF6B64E), Icons.home_work_outlined),
    'work': CategoryStyle(Color(0xFFA9B4D6), Icons.work_outline),
    'bills': CategoryStyle(Color(0xFFFF9C5E), Icons.receipt_long_outlined),
    'personal': CategoryStyle(Color(0xFFF58BD0), Icons.person_outline),
    'other': CategoryStyle(Color(0xFFB1B6CC), Icons.category_outlined),
  };

  /// Custom categories share a neutral style.
  static const custom = CategoryStyle(Color(0xFFB1B6CC), Icons.label_outline);

  static CategoryStyle of(String? key) => _styles[key] ?? custom;
}
