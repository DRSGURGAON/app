import 'package:flutter/material.dart';

import '../localization/gen/app_localizations.dart';
import '../theme/brand.dart';

/// The DocSafe logo: a shield whose top corner is folded like a document
/// page, with a keyhole — "your documents, locked". Drawn in code so the
/// same mark renders crisply at every size (and matches the app icon).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 40, this.onDark = false});

  final double size;

  /// On a navy background: a light tile instead of the navy gradient tile.
  final bool onDark;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LogoPainter(onDark: onDark)),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.onDark});
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final tile = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(s * .28),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = onDark
            ? const LinearGradient(
                colors: [Color(0x33FFFFFF), Color(0x1AFFFFFF)],
              ).createShader(Offset.zero & size)
            : Brand.heroGradient.createShader(Offset.zero & size),
    );
    Offset p(double x, double y) => Offset(x * s, y * s);
    final shield = Path()
      ..moveTo(p(.24, .22).dx, p(.24, .22).dy)
      ..lineTo(p(.60, .22).dx, p(.60, .22).dy)
      ..lineTo(p(.76, .38).dx, p(.76, .38).dy)
      ..lineTo(p(.76, .52).dx, p(.76, .52).dy)
      ..cubicTo(
        p(.76, .69).dx,
        p(.76, .69).dy,
        p(.64, .79).dx,
        p(.64, .79).dy,
        p(.50, .84).dx,
        p(.50, .84).dy,
      )
      ..cubicTo(
        p(.36, .79).dx,
        p(.36, .79).dy,
        p(.24, .69).dx,
        p(.24, .69).dy,
        p(.24, .52).dx,
        p(.24, .52).dy,
      )
      ..close();
    canvas.drawPath(shield, Paint()..color = Colors.white);
    final fold = Path()
      ..moveTo(p(.60, .22).dx, p(.60, .22).dy)
      ..lineTo(p(.60, .38).dx, p(.60, .38).dy)
      ..lineTo(p(.76, .38).dx, p(.76, .38).dy)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0xFFB9C1FF));
    final key = Paint()..color = Brand.navy800;
    canvas.drawCircle(p(.50, .50), s * .066, key);
    canvas.drawPath(
      Path()
        ..moveTo(p(.468, .54).dx, p(.468, .54).dy)
        ..lineTo(p(.532, .54).dx, p(.532, .54).dy)
        ..lineTo(p(.548, .67).dx, p(.548, .67).dy)
        ..lineTo(p(.452, .67).dx, p(.452, .67).dy)
        ..close(),
      key,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.onDark != onDark;
}

/// App logo mark + name. Decorative mark is excluded from semantics.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 72,
    this.showTagline = false,
    this.onDark = false,
  });

  final double size;
  final bool showTagline;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final fg = onDark ? Colors.white : scheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoMark(size: size, onDark: onDark),
        const SizedBox(height: 16),
        Text(
          l.appName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: fg),
        ),
        if (showTagline) ...[
          const SizedBox(height: 8),
          Text(
            l.tagline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: onDark ? Colors.white70 : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact logo for app bars and headers.
class BrandMarkSmall extends StatelessWidget {
  const BrandMarkSmall({super.key, this.size = 36, this.onDark = false});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => LogoMark(size: size, onDark: onDark);
}

/// Gold "Premium" pill used wherever a feature needs Premium.
class PremiumPill extends StatelessWidget {
  const PremiumPill({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: Brand.premiumGradient,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium,
            size: 13,
            color: Color(0xFF3D2600),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF3D2600),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}
