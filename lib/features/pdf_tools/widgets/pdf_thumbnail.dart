import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

/// Renders page [index] (0-based) of the decrypted temp PDF at [path].
typedef PdfThumbnailBuilder = Widget Function(String path, int index);

/// PDFium thumbnails in the app; host widget tests override this (no PDFium).
final pdfThumbnailBuilderProvider = Provider<PdfThumbnailBuilder>(
  (ref) =>
      (path, index) => PdfDocumentViewBuilder.file(
        path,
        builder: (context, document) => document == null
            ? const Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : PdfPageView(document: document, pageNumber: index + 1),
      ),
);
