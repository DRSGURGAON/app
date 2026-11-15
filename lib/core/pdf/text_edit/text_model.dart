import 'dart:typed_data';

/// A font used by text in the PDF.
class PdfFontInfo {
  const PdfFontInfo({
    required this.key,
    required this.family,
    required this.embedded,
    required this.bold,
    required this.italic,
    required this.serif,
    required this.monospace,
    required this.runes,
  });

  /// The PDF's base font name, e.g. "ABCDEF+Calibri-Bold".
  final String key;

  /// Family name, e.g. "Calibri".
  final String family;
  final bool embedded;
  final bool bold;
  final bool italic;
  final bool serif;
  final bool monospace;

  /// Characters this font can draw in this document: for an embedded subset
  /// exactly the ones the document already uses (plus its cmap if it has
  /// one); for a non-embedded standard font every WinAnsi character.
  final Set<int> runes;
}

/// One editable piece of text: neighbouring text objects on one baseline
/// with the same font, size and colour.
class TextRun {
  const TextRun({
    required this.page,
    required this.objectIndices,
    required this.text,
    required this.left,
    required this.bottom,
    required this.right,
    required this.top,
    required this.fontKey,
    required this.fontSize,
    required this.color,
    required this.maxRight,
  });

  final int page;

  /// Indices of the page objects that make up the run (load order).
  final List<int> objectIndices;
  final String text;

  /// Bounds in PDF points (origin bottom-left).
  final double left, bottom, right, top;
  final String fontKey;

  /// Font size as drawn (font size x text matrix scale).
  final double fontSize;

  /// 0xAARRGGBB.
  final int color;

  /// How far right the run may grow before it meets other text on the same
  /// line or the page margin.
  final double maxRight;

  String get id => '$page:${objectIndices.join(',')}';
}

class PdfPageSize {
  const PdfPageSize(this.width, this.height);
  final double width, height;
}

class PdfTextModel {
  const PdfTextModel({
    required this.pages,
    required this.runs,
    required this.fonts,
    required this.signatureCount,
  });

  final List<PdfPageSize> pages;
  final List<TextRun> runs;
  final Map<String, PdfFontInfo> fonts;

  /// Digital signatures in the file; editing invalidates them.
  final int signatureCount;

  Iterable<TextRun> runsOn(int page) => runs.where((r) => r.page == page);
}

/// A requested change to one run.
class TextEdit {
  const TextEdit({
    required this.page,
    required this.objectIndices,
    required this.text,
    required this.maxRight,
    this.fontId,
    this.fit = true,
  });

  factory TextEdit.of(
    TextRun run,
    String text, {
    String? fontId,
    bool fit = true,
  }) => TextEdit(
    page: run.page,
    objectIndices: run.objectIndices,
    text: text,
    maxRight: run.maxRight,
    fontId: fontId,
    fit: fit,
  );

  final int page;
  final List<int> objectIndices;
  final String text;
  final double maxRight;

  /// Null keeps the document's own font; otherwise a font from [EditFonts].
  final String? fontId;

  /// Narrow the text slightly (down to 80 %) if it would run into the next
  /// text on the line.
  final bool fit;
}

/// Font files to embed, by id.
typedef EditFonts = Map<String, Uint8List>;

class ApplyResult {
  const ApplyResult(this.bytes, this.overflow);
  final Uint8List bytes;

  /// Per edit (same order): true when the new text still runs past
  /// [TextEdit.maxRight] after fitting.
  final List<bool> overflow;
}

class RenderedPage {
  const RenderedPage(
    this.width,
    this.height,
    this.bgra, {
    this.overflow = const [],
  });
  final int width, height;
  final Uint8List bgra;

  /// For the edits on this page (in the order given): true when the text
  /// still runs past its line after fitting.
  final List<bool> overflow;
}
