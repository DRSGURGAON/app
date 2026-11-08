// Renders the logo to the legacy launcher PNGs and a 512 px store icon.
// Run: flutter test tool/screenshots/icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:docsafe/app/theme/brand.dart';
import 'package:docsafe/app/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> render(WidgetTester tester, double px, String path, {bool square = false}) async {
  final key = GlobalKey();
  tester.view.physicalSize = Size(px, px);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: square
            // Full-bleed square (stores apply their own mask).
            ? DecoratedBox(
                decoration: const BoxDecoration(gradient: Brand.heroGradient),
                child: Center(child: LogoMark(size: px * .9)),
              )
            : LogoMark(size: px),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('icons', (tester) async {
    const res = 'android/app/src/main/res';
    for (final (dir, px) in [('mdpi', 48.0), ('hdpi', 72.0), ('xhdpi', 96.0), ('xxhdpi', 144.0), ('xxxhdpi', 192.0)]) {
      await render(tester, px, '$res/mipmap-$dir/ic_launcher.png');
    }
    await render(tester, 512, 'docs/brand/icon-512.png', square: true);
    addTearDown(tester.view.reset);
  });
}
