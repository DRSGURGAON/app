import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // PDFium is used directly by the PDF tools (not only through widgets).
  pdfrxFlutterInitialize();
  runApp(const ProviderScope(child: DocSafeApp()));
}
