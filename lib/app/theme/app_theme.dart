import 'package:flutter/material.dart';

import 'brand.dart';

/// DocSafe Material 3 theme built from explicit brand colours (not a seed),
/// so every accent is intentional: indigo actions, teal = protected,
/// amber = attention, red = expired/danger.
abstract final class AppTheme {
  /// Kept for existing callers.
  static const brandNavy = Brand.navy900;
  static const _radius = 16.0;
  static const _cardRadius = 20.0;

  static ThemeData light() => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: Brand.indigo,
      onPrimary: Colors.white,
      primaryContainer: Brand.indigoTint,
      onPrimaryContainer: Brand.navy900,
      secondary: Brand.teal,
      onSecondary: Colors.white,
      secondaryContainer: Brand.tealTint,
      onSecondaryContainer: Color(0xFF053D34),
      tertiary: Brand.amber,
      onTertiary: Colors.white,
      tertiaryContainer: Brand.amberTint,
      onTertiaryContainer: Color(0xFF4A2C00),
      error: Brand.red,
      onError: Colors.white,
      errorContainer: Brand.redTint,
      onErrorContainer: Color(0xFF5C0A14),
      surface: Brand.canvas,
      onSurface: Brand.ink,
      onSurfaceVariant: Brand.inkMuted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Brand.card,
      surfaceContainer: Color(0xFFEFF1F7),
      surfaceContainerHigh: Color(0xFFE9EBF3),
      surfaceContainerHighest: Color(0xFFE2E5EF),
      outline: Color(0xFFB9BDD0),
      outlineVariant: Brand.line,
      inverseSurface: Brand.navy900,
      onInverseSurface: Colors.white,
      inversePrimary: Brand.indigoLight,
      shadow: Color(0xFF0B1437),
      scrim: Colors.black,
    ),
  );

  static ThemeData dark() => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Brand.indigoLight,
      onPrimary: Brand.navy950,
      primaryContainer: Color(0xFF26337F),
      onPrimaryContainer: Color(0xFFE3E7FF),
      secondary: Color(0xFF4FD1B8),
      onSecondary: Color(0xFF00382F),
      secondaryContainer: Color(0xFF0D4B41),
      onSecondaryContainer: Color(0xFFC9F4EA),
      tertiary: Color(0xFFFFC266),
      onTertiary: Color(0xFF462A00),
      tertiaryContainer: Color(0xFF5C3B00),
      onTertiaryContainer: Color(0xFFFFE2B8),
      error: Color(0xFFFF8A94),
      onError: Color(0xFF5C0A14),
      errorContainer: Color(0xFF7A1A26),
      onErrorContainer: Color(0xFFFFDADD),
      surface: Color(0xFF080D24),
      onSurface: Color(0xFFE7E9F5),
      onSurfaceVariant: Color(0xFFA9AECB),
      surfaceContainerLowest: Color(0xFF050919),
      surfaceContainerLow: Color(0xFF111834),
      surfaceContainer: Color(0xFF151D3D),
      surfaceContainerHigh: Color(0xFF1B2448),
      surfaceContainerHighest: Color(0xFF222C54),
      outline: Color(0xFF545B7E),
      outlineVariant: Color(0xFF262F57),
      inverseSurface: Color(0xFFE7E9F5),
      onInverseSurface: Brand.navy900,
      inversePrimary: Brand.indigo,
      shadow: Colors.black,
      scrim: Colors.black,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: Brand.fontFamily,
      fontFamilyFallback: Brand.fontFallback,
    );
    // ThemeData.textTheme carries colours/family but no sizes (geometry is
    // applied later); styles used directly (app bar titles) need sizes.
    final t = Typography.englishLike2021.merge(base.textTheme);
    final text = t.copyWith(
      displaySmall: t.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -.4,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.2,
      ),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.4),
      bodySmall: t.bodySmall?.copyWith(height: 1.35),
    );
    final dark = scheme.brightness == Brightness.dark;
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: text.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: text.titleMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: text.labelLarge),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLow,
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: dark ? scheme.surfaceContainerLow : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? scheme.surfaceContainerHighest : Brand.navy900,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: text.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
