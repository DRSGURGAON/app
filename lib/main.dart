import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // PDFium is used directly by the PDF tools (not only through widgets).
  pdfrxFlutterInitialize();
  // Bundled fonts (Plus Jakarta Sans, Sora, Noto Sans Devanagari) are SIL OFL 1.1.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Plus Jakarta Sans',
      'Sora',
      'Noto Sans Devanagari',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    // Fallback fonts for edited PDF text (subset, renamed Liberation 2,
    // Carlito and Caladea).
    yield LicenseEntryWithLineBreaks(
      const ['Scanner Pro Sans, Serif, Mono, Office Sans, Office Serif'],
      '${await rootBundle.loadString('assets/pdf_fonts/NOTICE.txt')}\n'
      '${await rootBundle.loadString('assets/pdf_fonts/OFL.txt')}',
    );
  });
  runApp(const ProviderScope(child: DocSafeApp()));
}
