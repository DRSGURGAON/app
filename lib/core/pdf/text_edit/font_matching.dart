import 'font_file_info.dart';
import 'text_model.dart';

/// Characters DocSafe lets users type when editing PDF text: printable ASCII,
/// Latin-1, dashes, quotes, bullet, ellipsis, euro, rupee and trade mark.
bool isEditableEnglish(String text) => text.runes.every(_allowedRune);

bool _allowedRune(int r) =>
    (r >= 0x20 && r < 0x7F) ||
    (r >= 0xA0 && r <= 0xFF) ||
    (r >= 0x2010 && r <= 0x2027) ||
    r == 0x2030 ||
    r == 0x20AC ||
    r == 0x20B9 ||
    r == 0x2122;

/// Characters every PDF viewer can show with a non-embedded standard font
/// (WinAnsiEncoding).
final Set<int> winAnsiRunes = {
  for (var r = 0x20; r < 0x7F; r++) r,
  for (var r = 0xA0; r <= 0xFF; r++) r,
  0x2013, 0x2014, 0x2018, 0x2019, 0x201A, 0x201C, 0x201D, 0x201E, //
  0x2020, 0x2021, 0x2022, 0x2026, 0x2030, 0x2039, 0x203A, 0x20AC, 0x2122,
};

/// How faithfully an edit keeps the document's look.
enum FontMatchKind {
  /// The document's own font: identical.
  original,

  /// The same font family from another source (your fonts, the phone's
  /// fonts, or DocSafe's built-in copy of that family): identical design.
  sameFamily,

  /// A different font with the same character widths (e.g. a Calibri
  /// twin): the line keeps its length; letter shapes differ slightly.
  metricMatch,

  /// Only a similar style (sans, serif or mono) was available.
  similar,
}

/// A font DocSafe can embed into a PDF.
class LibraryFont {
  const LibraryFont({
    required this.id,
    required this.info,
    required this.source,
    this.twinOf = const [],
  });

  /// Stable id, e.g. "asset:DocSafeSans-Regular" or "user:Calibri.ttf".
  final String id;
  final FontFileInfo info;
  final FontSource source;

  /// Normalised family names this font copies glyph-for-glyph (for DocSafe's
  /// renamed built-in fonts: their original family) — counts as sameFamily.
  final List<String> twinOf;
}

enum FontSource { user, system, builtIn }

class FontChoice {
  const FontChoice(this.kind, {this.font});
  final FontMatchKind kind;

  /// Null when the document's own font is kept.
  final LibraryFont? font;
}

/// "ABCDEF+Calibri-Bold" / "TimesNewRomanPS-BoldMT" -> "calibri" / "timesnewroman".
String normaliseFamily(String name) {
  var s = name.contains('+') ? name.substring(name.indexOf('+') + 1) : name;
  s = s.split(RegExp('[-,]')).first;
  s = s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  for (final suffix in ['psmt', 'mt', 'ps', 'regular', 'roman']) {
    if (s.length > suffix.length + 3 && s.endsWith(suffix)) {
      s = s.substring(0, s.length - suffix.length);
    }
  }
  return s;
}

/// Metric-compatible twins (same character widths), by normalised family.
const metricTwins = <String, String>{
  'arial': 'DocSafe Sans',
  'helvetica': 'DocSafe Sans',
  'arimo': 'DocSafe Sans',
  'liberationsans': 'DocSafe Sans',
  'timesnew': 'DocSafe Serif',
  'times': 'DocSafe Serif',
  'tinos': 'DocSafe Serif',
  'liberationserif': 'DocSafe Serif',
  'couriernew': 'DocSafe Mono',
  'courier': 'DocSafe Mono',
  'cousine': 'DocSafe Mono',
  'liberationmono': 'DocSafe Mono',
  'calibri': 'DocSafe Office Sans',
  'carlito': 'DocSafe Office Sans',
  'cambria': 'DocSafe Office Serif',
  'caladea': 'DocSafe Office Serif',
};

/// Picks the most faithful font for [text] in a run set in [font].
///
/// Order: the document's own font when it has every character; then the
/// same family from the user's fonts, the phone's fonts or DocSafe's copy;
/// then a metric twin; then a similar style. Every candidate must have all
/// the characters.
FontChoice chooseFont(
  PdfFontInfo font,
  String text,
  List<LibraryFont> library,
) {
  final needed = text.runes.where((r) => r != 0x20).toSet();
  if (font.runes.containsAll(needed)) {
    return const FontChoice(FontMatchKind.original);
  }
  final family = normaliseFamily(font.family);
  bool covers(LibraryFont f) => f.info.runes.containsAll(needed);
  int styleDistance(LibraryFont f) =>
      (f.info.bold == font.bold ? 0 : 2) +
      (f.info.italic == font.italic ? 0 : 1);
  LibraryFont? best(Iterable<LibraryFont> fonts) {
    final ok = fonts.where(covers).toList()
      ..sort((a, b) {
        final s = styleDistance(a).compareTo(styleDistance(b));
        return s != 0 ? s : a.source.index.compareTo(b.source.index);
      });
    return ok.isEmpty ? null : ok.first;
  }

  final same = best(
    library.where(
      (f) =>
          normaliseFamily(f.info.family) == family || f.twinOf.contains(family),
    ),
  );
  if (same != null) return FontChoice(FontMatchKind.sameFamily, font: same);

  final twin = metricTwins[family];
  if (twin != null) {
    final t = best(library.where((f) => f.info.family == twin));
    if (t != null) return FontChoice(FontMatchKind.metricMatch, font: t);
  }

  final generic = font.monospace
      ? 'DocSafe Mono'
      : font.serif
      ? 'DocSafe Serif'
      : 'DocSafe Sans';
  final g = best(library.where((f) => f.info.family == generic));
  if (g != null) return FontChoice(FontMatchKind.similar, font: g);
  // Last resort: any font that has every character; null when none does
  // (the editor then asks for a font or different characters).
  return FontChoice(FontMatchKind.similar, font: best(library));
}
