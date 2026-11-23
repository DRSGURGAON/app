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
    // Document Scanner Pro mark (same shapes as tool/brand/make_icon.py, which
    // writes the Android launcher, splash and notification drawables): a page
    // with a folded corner and text lines, gold scan-frame corners and a gold
    // scan line.
    Offset p(double x, double y) => Offset(x * s, y * s);
    Rect r(double x0, double y0, double x1, double y1) =>
        Rect.fromPoints(p(x0, y0), p(x1, y1));
    const pl = .33, pt = .25, pr = .67, pb = .77, fold = .10, rad = .03;
    final page = Path()
      ..moveTo(p(pl + rad, pt).dx, p(pl + rad, pt).dy)
      ..lineTo(p(pr - fold, pt).dx, p(pr - fold, pt).dy)
      ..lineTo(p(pr, pt + fold).dx, p(pr, pt + fold).dy)
      ..lineTo(p(pr, pb - rad).dx, p(pr, pb - rad).dy)
      ..quadraticBezierTo(
        p(pr, pb).dx,
        p(pr, pb).dy,
        p(pr - rad, pb).dx,
        p(pr - rad, pb).dy,
      )
      ..lineTo(p(pl + rad, pb).dx, p(pl + rad, pb).dy)
      ..quadraticBezierTo(
        p(pl, pb).dx,
        p(pl, pb).dy,
        p(pl, pb - rad).dx,
        p(pl, pb - rad).dy,
      )
      ..lineTo(p(pl, pt + rad).dx, p(pl, pt + rad).dy)
      ..quadraticBezierTo(
        p(pl, pt).dx,
        p(pl, pt).dy,
        p(pl + rad, pt).dx,
        p(pl + rad, pt).dy,
      )
      ..close();
    canvas.drawPath(page, Paint()..color = Colors.white);
    canvas.drawPath(
      Path()
        ..moveTo(p(pr - fold, pt).dx, p(pr - fold, pt).dy)
        ..lineTo(p(pr - fold, pt + fold).dx, p(pr - fold, pt + fold).dy)
        ..lineTo(p(pr, pt + fold).dx, p(pr, pt + fold).dy)
        ..close(),
      Paint()..color = const Color(0xFFB9C1FF),
    );
    final lines = Paint()..color = const Color(0xFFC5CCF2);
    canvas
      ..drawRect(r(.39, .40, .61, .43), lines)
      ..drawRect(r(.39, .62, .61, .65), lines)
      ..drawRect(r(.39, .69, .53, .72), lines);
    final gold = Paint()..color = Brand.gold;
    canvas.drawRect(r(.24, .505, .76, .54), gold);
    const l = .20, t = .16, rt = .80, b = .86, arm = .12, th = .045;
    for (final (cx, cy, dx, dy) in [
      (l, t, 1.0, 1.0),
      (rt, t, -1.0, 1.0),
      (l, b, 1.0, -1.0),
      (rt, b, -1.0, -1.0),
    ]) {
      canvas
        ..drawRect(r(cx, cy, cx + dx * arm, cy + dy * th), gold)
        ..drawRect(r(cx, cy, cx + dx * th, cy + dy * arm), gold);
    }
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
