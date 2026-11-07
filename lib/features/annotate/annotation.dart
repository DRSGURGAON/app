import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A mark on one page. Positions are normalised to the page as displayed
/// (x: 0..1 of the width, y: 0..1 of the height); sizes are fractions of the
/// page width, so the same mark paints identically on screen and in the
/// full-resolution overlay that is flattened into the PDF.
sealed class Annotation {
  const Annotation();

  void paint(Canvas canvas, Size page);

  /// Bounds in page pixels for [page], used for long-press hit testing.
  Rect bounds(Size page);
}

class TextMark extends Annotation {
  const TextMark({
    required this.at,
    required this.text,
    required this.color,
    required this.size,
  });

  /// Top-left corner.
  final Offset at;
  final String text;
  final Color color;

  /// Font size as a fraction of the page width.
  final double size;

  TextPainter _layout(Size page) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: size * page.width, height: 1.2),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: math.max(1, (1 - at.dx) * page.width));

  @override
  void paint(Canvas canvas, Size page) {
    final tp = _layout(page);
    tp.paint(canvas, Offset(at.dx * page.width, at.dy * page.height));
    tp.dispose();
  }

  @override
  Rect bounds(Size page) {
    final tp = _layout(page);
    final r = Offset(at.dx * page.width, at.dy * page.height) & tp.size;
    tp.dispose();
    return r;
  }
}

/// Freehand drawing or a placed signature (one or more strokes).
class InkMark extends Annotation {
  const InkMark({
    required this.strokes,
    required this.color,
    required this.width,
    this.isSignature = false,
  });

  final List<List<Offset>> strokes;
  final Color color;

  /// Stroke width as a fraction of the page width.
  final double width;
  final bool isSignature;

  @override
  void paint(Canvas canvas, Size page) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width * page.width
      ..isAntiAlias = true;
    for (final s in strokes) {
      if (s.isEmpty) continue;
      final pts = [
        for (final p in s) Offset(p.dx * page.width, p.dy * page.height),
      ];
      if (pts.length == 1) {
        canvas.drawCircle(
          pts.first,
          paint.strokeWidth / 2,
          Paint()..color = color,
        );
        continue;
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  Rect bounds(Size page) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final s in strokes) {
      for (final p in s) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }
    }
    if (minX == double.infinity) return Rect.zero;
    return Rect.fromLTRB(
      minX * page.width,
      minY * page.height,
      maxX * page.width,
      maxY * page.height,
    ).inflate(math.max(8, width * page.width));
  }
}

enum RectKind { highlight, cover }

/// Highlight (translucent yellow) or cover (opaque white: once flattened,
/// whatever was underneath is no longer in the copy).
class RectMark extends Annotation {
  const RectMark({required this.rect, required this.kind});

  final Rect rect;
  final RectKind kind;

  static const highlightColor = Color(0x66FFEB3B);
  static const coverColor = Color(0xFFFFFFFF);

  Rect _px(Size page) => Rect.fromLTRB(
    rect.left * page.width,
    rect.top * page.height,
    rect.right * page.width,
    rect.bottom * page.height,
  );

  @override
  void paint(Canvas canvas, Size page) => canvas.drawRect(
    _px(page),
    Paint()
      ..color = kind == RectKind.cover ? coverColor : highlightColor
      ..style = PaintingStyle.fill,
  );

  @override
  Rect bounds(Size page) => _px(page);
}

/// Places [pad] strokes (normalised to a [padAspect]:1 signature pad) centred
/// on [center], [widthFraction] of the page width wide.
InkMark placeSignature(
  List<List<Offset>> pad, {
  required Offset center,
  required Size page,
  required Color color,
  double padAspect = signaturePadAspect,
  double widthFraction = 0.3,
}) {
  final w = widthFraction;
  final h = w * page.width / padAspect / page.height;
  final left = (center.dx - w / 2).clamp(0.0, 1 - w);
  final top = (center.dy - h / 2).clamp(0.0, math.max(0.0, 1 - h));
  return InkMark(
    strokes: [
      for (final s in pad)
        [for (final p in s) Offset(left + p.dx * w, top + p.dy * h)],
    ],
    color: color,
    width: 0.004,
    isSignature: true,
  );
}

const signaturePadAspect = 3.0;

/// Same resolution the native flattener renders pages at (200 dpi, longest
/// side at most 3500 px), so the overlay is drawn without upscaling.
Size overlayPixelSize(Size pagePoints) {
  var w = pagePoints.width * 200 / 72;
  var h = pagePoints.height * 200 / 72;
  final longest = math.max(w, h);
  if (longest > 3500) {
    w = w * 3500 / longest;
    h = h * 3500 / longest;
  }
  return Size(math.max(1, w.roundToDouble()), math.max(1, h.roundToDouble()));
}

/// Draws [marks] on a transparent image of [pixels].
Future<ui.Image> renderOverlayImage(List<Annotation> marks, Size pixels) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (final m in marks) {
    m.paint(canvas, pixels);
  }
  final picture = recorder.endRecording();
  return picture
      .toImage(pixels.width.toInt(), pixels.height.toInt())
      .whenComplete(picture.dispose);
}

/// Transparent PNG overlay for one page of [pagePoints] (PDF points).
typedef OverlayRenderer = Future<Uint8List> Function(
  List<Annotation> marks,
  Size pagePoints,
);

Future<Uint8List> renderOverlayPng(
  List<Annotation> marks,
  Size pagePoints,
) async {
  final image = await renderOverlayImage(marks, overlayPixelSize(pagePoints));
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
