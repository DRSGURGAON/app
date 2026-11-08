import 'package:flutter/material.dart';

/// DocSafe brand tokens. Deep navy conveys security; a clear indigo is the
/// action colour; teal means "protected / OK", amber "attention", red
/// "expired / danger". Gold is reserved for Premium.
abstract final class Brand {
  static const fontFamily = 'PlusJakartaSans';
  static const fontFallback = ['NotoSansDevanagari'];

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
    'identity': CategoryStyle(Color(0xFF3446D4), Icons.badge_outlined),
    'education': CategoryStyle(Color(0xFF7B4DDB), Icons.school_outlined),
    'vehicle': CategoryStyle(Color(0xFF1D86C9), Icons.directions_car_outlined),
    'finance': CategoryStyle(Color(0xFF138A5A), Icons.account_balance_outlined),
    'insurance': CategoryStyle(
      Color(0xFF0E9F87),
      Icons.health_and_safety_outlined,
    ),
    'medical': CategoryStyle(
      Color(0xFFD63B6B),
      Icons.medical_services_outlined,
    ),
    'property': CategoryStyle(Color(0xFFB8690B), Icons.home_work_outlined),
    'work': CategoryStyle(Color(0xFF4B5675), Icons.work_outline),
    'bills': CategoryStyle(Color(0xFFDB6A1F), Icons.receipt_long_outlined),
    'personal': CategoryStyle(Color(0xFFC2459A), Icons.person_outline),
    'other': CategoryStyle(Color(0xFF6B7088), Icons.category_outlined),
  };

  /// Custom categories share a neutral style.
  static const custom = CategoryStyle(Color(0xFF5B6180), Icons.label_outline);

  static CategoryStyle of(String? key) => _styles[key] ?? custom;
}
