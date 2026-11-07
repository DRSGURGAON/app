import 'dart:ui' as ui;

import 'package:docsafe/core/database/database_opener.dart';
import 'package:docsafe/data/repositories/signature_store.dart';
import 'package:docsafe/features/annotate/annotation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Color> pixel(ui.Image image, double x, double y) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final px = (x * image.width).toInt();
  final py = (y * image.height).toInt();
  final o = (py * image.width + px) * 4;
  return Color.fromARGB(
    data.getUint8(o + 3),
    data.getUint8(o),
    data.getUint8(o + 1),
    data.getUint8(o + 2),
  );
}

void main() {
  test('overlay size matches the native 200 dpi render, capped at 3500', () {
    expect(overlayPixelSize(const Size(595, 842)), const Size(1653, 2339));
    final big = overlayPixelSize(const Size(2384, 3370)); // A0
    expect(big.height, 3500);
    expect(big.width, closeTo(3500 * 2384 / 3370, 1));
  });

  test(
    'cover is opaque white, highlight translucent, rest transparent',
    () async {
      final image = await renderOverlayImage(const [
        RectMark(rect: Rect.fromLTRB(0.1, 0.1, 0.4, 0.2), kind: RectKind.cover),
        RectMark(
          rect: Rect.fromLTRB(0.5, 0.5, 0.9, 0.6),
          kind: RectKind.highlight,
        ),
      ], const Size(200, 300));
      final cover = await pixel(image, 0.25, 0.15);
      expect(cover.toARGB32(), 0xFFFFFFFF);
      final hl = await pixel(image, 0.7, 0.55);
      expect((hl.a * 255).round(), closeTo(0x66, 2));
      final empty = await pixel(image, 0.05, 0.9);
      expect(empty.a, 0);
      image.dispose();
    },
  );

  test('marks scale with the page: same normalised spot at any size', () async {
    const ink = InkMark(
      strokes: [
        [Offset(0.2, 0.5), Offset(0.8, 0.5)],
      ],
      color: Color(0xFFC62828),
      width: 0.02,
    );
    for (final size in const [Size(100, 140), Size(400, 560)]) {
      final image = await renderOverlayImage(const [ink], size);
      final c = await pixel(image, 0.5, 0.5);
      expect(c.a, 1.0, reason: '$size');
      expect((c.r * 255).round(), closeTo(0xC6, 3));
      image.dispose();
    }
  });

  test('signature placement keeps the pad aspect and stays on the page', () {
    final sig = placeSignature(
      const [
        [Offset(0, 0), Offset(1, 1)],
      ],
      center: const Offset(0.95, 0.99),
      page: const Size(600, 800),
      color: const Color(0xFF000000),
    );
    final b = sig.bounds(const Size(600, 800)).deflate(8);
    expect(b.right, lessThanOrEqualTo(600.5));
    expect(b.bottom, lessThanOrEqualTo(800.5));
    expect(b.width / b.height, closeTo(signaturePadAspect, 0.01));
    expect(b.width, closeTo(0.3 * 600, 0.5));
    expect(sig.isSignature, isTrue);
  });

  test('saved signature round-trips through the encrypted database', () async {
    final db = openEncryptedMemoryDatabase('d' * 64);
    addTearDown(db.close);
    final store = SignatureStore(db);
    expect(await store.load(), isNull);
    await store.save(const [
      [Offset(0.1, 0.2), Offset(0.3, 0.4)],
      [Offset(0.5, 0.5)],
    ]);
    expect(await store.load(), const [
      [Offset(0.1, 0.2), Offset(0.3, 0.4)],
      [Offset(0.5, 0.5)],
    ]);
    await store.clear();
    expect(await store.load(), isNull);
  });
}
