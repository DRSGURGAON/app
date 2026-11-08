import 'package:flutter/material.dart';

import 'brand.dart';

/// DocSafe theme: an immersive royal-blue → navy gradient on every screen,
/// glass cards, white pill buttons, Sora headings over Plus Jakarta Sans text
/// (Noto Sans Devanagari for Hindi). Accents: amber = attention, teal =
/// protected, soft red = expired. One brand look in light and dark system
/// modes.
abstract final class AppTheme {
  static const brandNavy = Brand.navy900;

  static ThemeData light() => brand();
  static ThemeData dark() => brand();

  static const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Colors.white,
    onPrimary: Brand.navy900,
    primaryContainer: Color(0x29FFFFFF),
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFF4FD1B8),
    onSecondary: Color(0xFF00382F),
    secondaryContainer: Color(0x334FD1B8),
    onSecondaryContainer: Color(0xFFC9F4EA),
    tertiary: Color(0xFFF7BE4B),
    onTertiary: Color(0xFF3D2600),
    tertiaryContainer: Color(0x33F7BE4B),
    onTertiaryContainer: Color(0xFFFFE2B0),
    error: Color(0xFFFF8A94),
    onError: Color(0xFF5C0A14),
    errorContainer: Color(0x33FF6B78),
    onErrorContainer: Color(0xFFFFD9DC),
    surface: Color(0xFF09195A),
    onSurface: Colors.white,
    onSurfaceVariant: Brand.textMuted,
    surfaceContainerLowest: Brand.glass,
    surfaceContainerLow: Brand.glass,
    surfaceContainer: Brand.glass,
    surfaceContainerHigh: Brand.glassStrong,
    surfaceContainerHighest: Color(0x29FFFFFF),
    outline: Color(0x66FFFFFF),
    outlineVariant: Brand.glassBorder,
    inverseSurface: Colors.white,
    onInverseSurface: Brand.navy900,
    inversePrimary: Brand.navy700,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static ThemeData brand() {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: Brand.fontFamily,
      fontFamilyFallback: const ['NotoSansDevanagari'],
    );
    // ThemeData.textTheme carries colours/family but no sizes (geometry is
    // applied later); styles used directly (app bar titles) need sizes.
    final t = Typography.englishLike2021.merge(base.textTheme);
    TextStyle? display(TextStyle? s, FontWeight w, [double spacing = -.3]) =>
        s?.copyWith(
          fontFamily: Brand.displayFamily,
          fontFamilyFallback: Brand.fontFallback,
          fontWeight: w,
          letterSpacing: spacing,
        );
    final text = t.copyWith(
      displaySmall: display(t.displaySmall, FontWeight.w800, -.6),
      headlineMedium: display(t.headlineMedium, FontWeight.w800, -.5),
      headlineSmall: display(t.headlineSmall, FontWeight.w700, -.4),
      titleLarge: display(t.titleLarge, FontWeight.w700),
      titleMedium: display(t.titleMedium, FontWeight.w600, -.1),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
      bodySmall: t.bodySmall?.copyWith(height: 1.4, color: Brand.textMuted),
    );
    const pill = StadiumBorder();
    return base.copyWith(
      textTheme: text,
      // Each route paints the gradient (see _GradientPageTransitionsBuilder),
      // so screens themselves are transparent.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _GradientPageTransitionsBuilder(),
          TargetPlatform.iOS: _GradientPageTransitionsBuilder(),
          TargetPlatform.linux: _GradientPageTransitionsBuilder(),
          TargetPlatform.macOS: _GradientPageTransitionsBuilder(),
          TargetPlatform.windows: _GradientPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _GradientPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Brand.glass,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Brand.glassBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Brand.navy900,
          disabledBackgroundColor: const Color(0x26FFFFFF),
          disabledForegroundColor: const Color(0x80FFFFFF),
          minimumSize: const Size.fromHeight(56),
          shape: pill,
          textStyle: text.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: Color(0x4DFFFFFF), width: 1.5),
          shape: pill,
          textStyle: text.titleMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFB9C4FF),
          textStyle: text.labelLarge,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: const BorderSide(color: Brand.glassBorder),
        backgroundColor: Brand.glass,
        selectedColor: const Color(0x33FFFFFF),
        labelStyle: text.labelLarge?.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Brand.glass,
        labelStyle: const TextStyle(color: Brand.textMuted),
        hintStyle: const TextStyle(color: Brand.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Brand.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Brand.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: const Color(0xFF060E33),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0x29FFFFFF),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFF8E9AC7),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFF8E9AC7),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Brand.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Brand.dialog,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: Color(0x66FFFFFF),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Brand.dialog,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: Brand.dialog,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        contentTextStyle: text.bodyMedium?.copyWith(color: Brand.navy900),
        actionTextColor: Brand.navy700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: text.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        subtitleTextStyle: text.bodyMedium?.copyWith(color: Brand.textMuted),
        iconColor: Brand.textMuted,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Brand.navy900
              : const Color(0xFF8E9AC7),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFF4FD1B8)
              : const Color(0x1FFFFFFF),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        checkColor: const WidgetStatePropertyAll(Brand.navy900),
        side: const BorderSide(color: Color(0x99FFFFFF), width: 1.5),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: Brand.glassBorder, space: 1),
    );
  }
}

/// Paints the brand gradient behind every route, so transparent screens never
/// show the previous page during a transition.
class _GradientPageTransitionsBuilder extends PageTransitionsBuilder {
  const _GradientPageTransitionsBuilder();

  static const _inner = ZoomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _inner.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    DecoratedBox(
      decoration: const BoxDecoration(gradient: Brand.backgroundGradient),
      child: child,
    ),
  );
}
