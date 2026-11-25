// PDF text editing on PDFium's edit API (pure functions over a PDFium handle).
//
// Must run where PDFium may be called: the pdfrx PDFium worker in the app
// (see pdf_text_engine.dart), or the test isolate on the host. Every call
// opens the document from bytes, so edits are replayed on an untouched copy
// (simple undo, nothing kept between calls).
import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart';

import 'font_file_info.dart';
import 'font_matching.dart';
import 'text_model.dart';

class PdfTextUnreadable implements Exception {
  const PdfTextUnreadable();
}

class _Doc {
  _Doc(this.p, Uint8List bytes)
    : mem = malloc<Uint8>(math.max(bytes.length, 1)) {
    mem.asTypedList(bytes.length).setAll(0, bytes);
    handle = p.FPDF_LoadMemDocument64(mem.cast(), bytes.length, nullptr);
    if (handle.address == 0) {
      malloc.free(mem);
      throw const PdfTextUnreadable();
    }
  }

  final PDFium p;
  final Pointer<Uint8> mem;
  late final FPDF_DOCUMENT handle;
  final _fonts = <String, FPDF_FONT>{};

  FPDF_FONT font(String id, Uint8List bytes) => _fonts.putIfAbsent(id, () {
    final buf = malloc<Uint8>(bytes.length);
    buf.asTypedList(bytes.length).setAll(0, bytes);
    // cid = 1: Identity-H CID font, so any character in the font can be used.
    // PDFium copies the font data.
    final f = p.FPDFText_LoadFont(
      handle,
      buf,
      bytes.length,
      FPDF_FONT_TRUETYPE,
      1,
    );
    malloc.free(buf);
    if (f.address == 0) throw ArgumentError('Font $id could not be loaded');
    return f;
  });

  void close() {
    for (final f in _fonts.values) {
      p.FPDFFont_Close(f);
    }
    p.FPDF_CloseDocument(handle);
    malloc.free(mem);
  }
}

String _objText(PDFium p, FPDF_PAGEOBJECT o, FPDF_TEXTPAGE tp) {
  final n = p.FPDFTextObj_GetText(o, tp, nullptr, 0);
  if (n <= 2) return '';
  final buf = calloc<Uint16>(n ~/ 2);
  try {
    p.FPDFTextObj_GetText(o, tp, buf.cast(), n);
    return String.fromCharCodes(buf.asTypedList(n ~/ 2 - 1));
  } finally {
    calloc.free(buf);
  }
}

String _fontString(
  int Function(FPDF_FONT, Pointer<Char>, int) getter,
  FPDF_FONT f,
) {
  final n = getter(f, nullptr, 0);
  if (n <= 1) return '';
  final b = calloc<Char>(n);
  try {
    getter(f, b, n);
    return b.cast<Utf8>().toDartString();
  } finally {
    calloc.free(b);
  }
}

Pointer<Uint16> _wide(String s) {
  final units = s.codeUnits;
  final u = calloc<Uint16>(units.length + 1);
  for (var i = 0; i < units.length; i++) {
    u[i] = units[i];
  }
  return u;
}

({double l, double b, double r, double t}) _bounds(
  PDFium p,
  FPDF_PAGEOBJECT o,
) {
  final v = calloc<Float>(4);
  try {
    p.FPDFPageObj_GetBounds(o, v, v + 1, v + 2, v + 3);
    return (l: v[0], b: v[1], r: v[2], t: v[3]);
  } finally {
    calloc.free(v);
  }
}

/// A 2D affine matrix in PDF order (x' = a*x + c*y + e, y' = b*x + d*y + f).
typedef _M = ({double a, double b, double c, double d, double e, double f});

const _M _identity = (a: 1, b: 0, c: 0, d: 1, e: 0, f: 0);

/// [m] applied first, then [n].
_M _concat(_M m, _M n) => (
  a: m.a * n.a + m.b * n.c,
  b: m.a * n.b + m.b * n.d,
  c: m.c * n.a + m.d * n.c,
  d: m.c * n.b + m.d * n.d,
  e: m.e * n.a + m.f * n.c + n.e,
  f: m.e * n.b + m.f * n.d + n.f,
);

_M _matrixOf(PDFium p, FPDF_PAGEOBJECT o, Pointer<FS_MATRIX> m) {
  if (p.FPDFPageObj_GetMatrix(o, m) != 1) return _identity;
  final r = m.ref;
  return (a: r.a, b: r.b, c: r.c, d: r.d, e: r.e, f: r.f);
}

/// A page object, possibly inside one or more Form XObjects.
class _Node {
  const _Node(this.obj, this.parent, this.toPage);
  final FPDF_PAGEOBJECT obj;

  /// The form object holding [obj]; null for an object directly on the page.
  final FPDF_PAGEOBJECT? parent;

  /// Maps the coordinates [obj] is drawn in to page coordinates.
  final _M toPage;
}

/// Forms nested deeper than this are not searched for text.
const _maxFormDepth = 6;

/// Every object of [page] in a fixed depth-first order, including objects
/// inside Form XObjects. Design tools (Canva and others) put all of a page's
/// text into one or more forms, so looking only at the page's own objects
/// finds nothing. The position in this list is the object index used by
/// [TextRun.objectIndices], so reading and editing must both use it.
List<_Node> _flatten(PDFium p, FPDF_PAGE page) {
  final out = <_Node>[];
  final m = calloc<FS_MATRIX>();
  void visit(FPDF_PAGEOBJECT o, FPDF_PAGEOBJECT? parent, _M toPage, int d) {
    out.add(_Node(o, parent, toPage));
    if (d >= _maxFormDepth || p.FPDFPageObj_GetType(o) != FPDF_PAGEOBJ_FORM) {
      return;
    }
    final inner = _concat(_matrixOf(p, o, m), toPage);
    final n = p.FPDFFormObj_CountObjects(o);
    for (var i = 0; i < n; i++) {
      visit(p.FPDFFormObj_GetObject(o, i), o, inner, d + 1);
    }
  }

  try {
    final n = p.FPDFPage_CountObjects(page);
    for (var i = 0; i < n; i++) {
      visit(p.FPDFPage_GetObject(page, i), null, _identity, 0);
    }
  } finally {
    calloc.free(m);
  }
  return out;
}

/// Bounds of [o] (in its own drawing coordinates) mapped to the page.
({double l, double b, double r, double t}) _pageBounds(
  PDFium p,
  FPDF_PAGEOBJECT o,
  _M toPage,
) {
  final bb = _bounds(p, o);
  if (identical(toPage, _identity)) return bb;
  final xs = <double>[], ys = <double>[];
  for (final (x, y) in [
    (bb.l, bb.b),
    (bb.r, bb.b),
    (bb.l, bb.t),
    (bb.r, bb.t),
  ]) {
    xs.add(toPage.a * x + toPage.c * y + toPage.e);
    ys.add(toPage.b * x + toPage.d * y + toPage.f);
  }
  return (
    l: xs.reduce(math.min),
    b: ys.reduce(math.min),
    r: xs.reduce(math.max),
    t: ys.reduce(math.max),
  );
}

bool _formHasText(PDFium p, FPDF_PAGEOBJECT form, int depth) {
  final n = p.FPDFFormObj_CountObjects(form);
  for (var i = 0; i < n; i++) {
    final o = p.FPDFFormObj_GetObject(form, i);
    final type = p.FPDFPageObj_GetType(o);
    if (type == FPDF_PAGEOBJ_TEXT) return true;
    if (type == FPDF_PAGEOBJ_FORM &&
        depth < _maxFormDepth &&
        _formHasText(p, o, depth + 1)) {
      return true;
    }
  }
  return false;
}

/// Moves everything inside the page's text-holding forms onto the page
/// itself, in the same drawing order and position.
///
/// PDFium can change an object inside a form in memory, but when the file is
/// saved it rewrites only the page's own content, not the form's, so an edit
/// there would be lost. Each object keeps its handle, so the nodes found by
/// [_flatten] stay valid; they are page objects afterwards.
void _liftTextForms(PDFium p, FPDF_PAGE page) {
  final m = calloc<FS_MATRIX>();
  try {
    for (var guard = 0; guard < 256; guard++) {
      final n = p.FPDFPage_CountObjects(page);
      var index = -1;
      for (var i = 0; i < n; i++) {
        final o = p.FPDFPage_GetObject(page, i);
        if (p.FPDFPageObj_GetType(o) == FPDF_PAGEOBJ_FORM &&
            _formHasText(p, o, 1)) {
          index = i;
          break;
        }
      }
      if (index < 0) return;
      final form = p.FPDFPage_GetObject(page, index);
      final fm = _matrixOf(p, form, m);
      final kids = [
        for (var i = 0; i < p.FPDFFormObj_CountObjects(form); i++)
          p.FPDFFormObj_GetObject(form, i),
      ];
      var at = index + 1;
      for (final kid in kids) {
        if (p.FPDFFormObj_RemoveObject(form, kid) != 1) continue;
        p.FPDFPageObj_Transform(kid, fm.a, fm.b, fm.c, fm.d, fm.e, fm.f);
        p.FPDFPageObj_TransformClipPath(
          kid,
          fm.a,
          fm.b,
          fm.c,
          fm.d,
          fm.e,
          fm.f,
        );
        p.FPDFPage_InsertObjectAtIndex(page, kid, at++);
      }
      if (p.FPDFPage_RemoveObject(page, form) == 1) {
        p.FPDFPageObj_Destroy(form);
      }
    }
  } finally {
    calloc.free(m);
  }
}

class _Obj {
  _Obj(
    this.index,
    this.text,
    this.font,
    this.fontKey,
    this.size,
    this.color,
    this.baseline,
    this.rotated,
    this.l,
    this.b,
    this.r,
    this.t,
  );
  final int index;
  final String text;
  final FPDF_FONT font;
  final String fontKey;
  final double size;
  final int color;
  final double baseline;
  final bool rotated;
  final double l, b, r, t;
}

/// False for text that is only spaces or icon glyphs (Private Use Area
/// characters, as design tools use for phone / mail icons): nothing to edit.
bool _readable(String text) => text.runes.any(
  (r) =>
      !(r >= 0xE000 && r <= 0xF8FF) &&
      r < 0xF0000 &&
      String.fromCharCode(r).trim().isNotEmpty,
);

List<_Obj> _textObjects(PDFium p, FPDF_PAGE page, FPDF_TEXTPAGE tp) {
  final out = <_Obj>[];
  final nodes = _flatten(p, page);
  final m = calloc<FS_MATRIX>();
  final sz = calloc<Float>();
  final rgba = calloc<UnsignedInt>(4);
  try {
    for (var i = 0; i < nodes.length; i++) {
      final o = nodes[i].obj;
      if (p.FPDFPageObj_GetType(o) != FPDF_PAGEOBJ_TEXT) continue;
      final text = _objText(p, o, tp);
      if (!_readable(text)) continue;
      final f = p.FPDFTextObj_GetFont(o);
      p.FPDFTextObj_GetFontSize(o, sz);
      p.FPDFPageObj_GetFillColor(o, rgba, rgba + 1, rgba + 2, rgba + 3);
      // Text matrix in page coordinates (forms add their own transform).
      final mm = _concat(_matrixOf(p, o, m), nodes[i].toPage);
      final scale = math.sqrt(mm.c * mm.c + mm.d * mm.d);
      final bb = _pageBounds(p, o, nodes[i].toPage);
      out.add(
        _Obj(
          i,
          text,
          f,
          _fontString(p.FPDFFont_GetBaseFontName, f),
          sz.value * (scale == 0 ? 1 : scale),
          (rgba[3] << 24) | (rgba[0] << 16) | (rgba[1] << 8) | rgba[2],
          mm.f,
          mm.b.abs() > 0.01 || mm.c.abs() > 0.01 || mm.a <= 0 || mm.d <= 0,
          bb.l,
          bb.b,
          bb.r,
          bb.t,
        ),
      );
    }
  } finally {
    calloc.free(m);
    calloc.free(sz);
    calloc.free(rgba);
  }
  return out;
}

/// Reads every page's text runs and fonts.
PdfTextModel analyzePdf(PDFium p, Uint8List bytes) {
  final doc = _Doc(p, bytes);
  try {
    final pages = <PdfPageSize>[];
    final runs = <TextRun>[];
    final fonts = <String, PdfFontInfo>{};
    final usedRunes = <String, Set<int>>{};
    final firstUse = <String, (int, int)>{};
    final pageCount = p.FPDF_GetPageCount(doc.handle);
    for (var pi = 0; pi < pageCount; pi++) {
      final page = p.FPDF_LoadPage(doc.handle, pi);
      final width = p.FPDF_GetPageWidthF(page);
      pages.add(PdfPageSize(width, p.FPDF_GetPageHeightF(page)));
      final tp = p.FPDFText_LoadPage(page);
      final objs = _textObjects(p, page, tp);
      for (final o in objs) {
        usedRunes.putIfAbsent(o.fontKey, () => {}).addAll(o.text.runes);
        firstUse.putIfAbsent(o.fontKey, () => (pi, o.index));
        if (!fonts.containsKey(o.fontKey)) {
          fonts[o.fontKey] = _fontInfo(p, o.font, o.fontKey);
        }
      }
      runs.addAll(_group(pi, objs, width));
      p.FPDFText_ClosePage(tp);
      p.FPDF_ClosePage(page);
    }
    final withUsed = {
      for (final e in fonts.entries)
        e.key: PdfFontInfo(
          key: e.value.key,
          family: e.value.family,
          embedded: e.value.embedded,
          bold: e.value.bold,
          italic: e.value.italic,
          serif: e.value.serif,
          monospace: e.value.monospace,
          runes: _encodableRunes(p, doc.handle, firstUse[e.key], {
            ...e.value.runes,
            ...?usedRunes[e.key],
          }),
        ),
    };
    return PdfTextModel(
      pages: pages,
      runs: runs,
      fonts: withUsed,
      signatureCount: p.FPDF_GetSignatureCount(doc.handle),
    );
  } finally {
    doc.close();
  }
}

/// Keeps only the characters the font can really write back.
///
/// A font's character list can promise more than its encoding delivers (a
/// simple font with a custom encoding, a subset whose cmap lists missing
/// glyphs). Write every candidate character into one of the font's own text
/// objects of this throwaway copy and read it back: a character that does not
/// come back unchanged is dropped, so the original font is never offered for
/// it and DocSafe's own font is used instead.
Set<int> _encodableRunes(
  PDFium p,
  FPDF_DOCUMENT doc,
  (int, int)? at,
  Set<int> runes,
) {
  if (at == null) return const {};
  final probe = [
    for (final r in runes.toList()..sort())
      if (r > 0x20 && r != 0xA0 && String.fromCharCode(r).trim().isNotEmpty) r,
  ];
  if (probe.isEmpty) return runes;
  final page = p.FPDF_LoadPage(doc, at.$1);
  if (page.address == 0) return const {};
  try {
    final nodes = _flatten(p, page);
    if (at.$2 >= nodes.length) return const {};
    final o = nodes[at.$2].obj;
    final text = String.fromCharCodes(probe);
    final wide = _wide(text);
    try {
      if (p.FPDFText_SetText(o, wide.cast()) != 1) return const {};
    } finally {
      calloc.free(wide);
    }
    final tp = p.FPDFText_LoadPage(page);
    final back = _objText(
      p,
      o,
      tp,
    ).replaceAll(RegExp(r'\s'), '').runes.toList();
    p.FPDFText_ClosePage(tp);
    if (back.length != probe.length) return const {};
    return {
      for (final r in runes)
        if (!probe.contains(r)) r,
      for (var i = 0; i < probe.length; i++)
        if (back[i] == probe[i]) probe[i],
    };
  } finally {
    p.FPDF_ClosePage(page);
  }
}

PdfFontInfo _fontInfo(PDFium p, FPDF_FONT f, String key) {
  final embedded = p.FPDFFont_GetIsEmbedded(f) == 1;
  final flags = p.FPDFFont_GetFlags(f);
  final weight = p.FPDFFont_GetWeight(f);
  final lower = key.toLowerCase();
  // The base font name is what the PDF says; PDFium's family name for a
  // non-embedded font is the substitute it renders with, so use it last.
  var family = key.contains('+') ? key.substring(key.indexOf('+') + 1) : key;
  family = family.split(RegExp('[-,]')).first;
  if (family.isEmpty && embedded) {
    family = _fontString(p.FPDFFont_GetFamilyName, f);
  }
  final runes = <int>{};
  if (!embedded) {
    runes.addAll(winAnsiRunes);
  } else {
    final len = calloc<Size>();
    try {
      if (p.FPDFFont_GetFontData(f, nullptr, 0, len) == 1 && len.value > 0) {
        final buf = calloc<Uint8>(len.value);
        try {
          p.FPDFFont_GetFontData(f, buf, len.value, len);
          final info = FontFileInfo.parse(
            Uint8List.fromList(buf.asTypedList(len.value)),
          );
          if (info != null) runes.addAll(info.runes);
        } finally {
          calloc.free(buf);
        }
      }
    } finally {
      calloc.free(len);
    }
  }
  return PdfFontInfo(
    key: key,
    family: family,
    embedded: embedded,
    bold: weight >= 600 || lower.contains('bold') || (flags & 0x40000) != 0,
    italic:
        lower.contains('italic') ||
        lower.contains('oblique') ||
        (flags & 0x40) != 0,
    serif:
        (flags & 0x2) != 0 ||
        lower.contains('times') ||
        lower.contains('serif'),
    monospace:
        (flags & 0x1) != 0 ||
        lower.contains('courier') ||
        lower.contains('mono'),
    runes: runes,
  );
}

/// Joins neighbouring objects on one baseline with the same style.
List<TextRun> _group(int page, List<_Obj> objs, double pageWidth) {
  final usable = objs.where((o) => !o.rotated).toList()
    ..sort((a, b) {
      final dy = b.baseline.compareTo(a.baseline);
      return (a.baseline - b.baseline).abs() > 0.5 ? dy : a.l.compareTo(b.l);
    });
  final runs = <List<_Obj>>[];
  for (final o in usable) {
    final last = runs.isEmpty ? null : runs.last.last;
    final same =
        last != null &&
        (last.baseline - o.baseline).abs() <= math.max(0.5, o.size * 0.2) &&
        last.fontKey == o.fontKey &&
        (last.size - o.size).abs() < 0.2 &&
        last.color == o.color &&
        o.l >= last.l &&
        o.l - last.r < o.size * 1.2;
    if (same) {
      runs.last.add(o);
    } else {
      runs.add([o]);
    }
  }
  final result = <TextRun>[];
  for (final group in runs) {
    result.add(_run(page, group, objs, pageWidth));
  }
  return result;
}

/// Text of a group of objects on one line, with spaces where words break.
String _joinText(List<_Obj> group) {
  final lengths = [for (final o in group) o.text.trim().length]..sort();
  final perLetter = group.length >= 3 && lengths[lengths.length ~/ 2] <= 2;
  if (!perLetter) {
    final buf = StringBuffer(group.first.text);
    for (var i = 1; i < group.length; i++) {
      final gap = group[i].l - group[i - 1].r;
      if (gap > group[i].size * 0.15 &&
          !buf.toString().endsWith(' ') &&
          !group[i].text.startsWith(' ')) {
        buf.write(' ');
      }
      buf.write(group[i].text);
    }
    return buf.toString().trimRight();
  }
  // One object per letter with letter spacing (Canva and other design tools).
  // A space after a letter may be real or added by PDFium's text reader, so
  // decide by the gap: the usual gap between letters is the baseline, a word
  // break is clearly wider.
  final gaps = [
    for (var i = 1; i < group.length; i++) group[i].l - group[i - 1].r,
  ];
  final plain = [
    for (var i = 1; i < group.length; i++)
      if (!group[i - 1].text.endsWith(' ')) gaps[i - 1],
  ];
  final sample = (plain.length >= 3 ? plain : gaps).toList()..sort();
  final usual = math.max(0.0, sample[sample.length ~/ 2]);
  final buf = StringBuffer(group.first.text.trim());
  for (var i = 1; i < group.length; i++) {
    final size = group[i].size;
    final gap = gaps[i - 1];
    final spaced = group[i - 1].text.endsWith(' ');
    if ((spaced && gap > usual + size * 0.08) || gap > usual + size * 0.3) {
      buf.write(' ');
    }
    buf.write(group[i].text.trim());
  }
  return buf.toString();
}

TextRun _run(int page, List<_Obj> group, List<_Obj> objs, double pageWidth) {
  final first = group.first;
  final left = group.map((o) => o.l).reduce(math.min);
  final right = group.map((o) => o.r).reduce(math.max);
  // Next text to the right on the same line limits how far it may grow.
  var maxRight = pageWidth - 18;
  for (final o in objs) {
    if (group.contains(o)) continue;
    final sameLine =
        o.b < group.map((g) => g.t).reduce(math.max) &&
        o.t > group.map((g) => g.b).reduce(math.min);
    if (sameLine && o.l >= right - 0.5 && o.l < maxRight) maxRight = o.l - 1;
  }
  return TextRun(
    page: page,
    objectIndices: [for (final o in group) o.index],
    text: _joinText(group),
    left: left,
    bottom: group.map((o) => o.b).reduce(math.min),
    right: right,
    top: group.map((o) => o.t).reduce(math.max),
    fontKey: first.fontKey,
    fontSize: first.size,
    color: first.color,
    maxRight: math.max(maxRight, right),
  );
}

/// Applies [edits] in memory and returns per-edit overflow flags.
List<bool> _applyTo(_Doc doc, List<TextEdit> edits, EditFonts fonts) {
  final p = doc.p;
  final overflow = List.filled(edits.length, false);
  final byPage = <int, List<int>>{};
  for (var i = 0; i < edits.length; i++) {
    byPage.putIfAbsent(edits[i].page, () => []).add(i);
  }
  final m = calloc<FS_MATRIX>();
  final sz = calloc<Float>();
  final rgba = calloc<UnsignedInt>(4);
  try {
    for (final entry in byPage.entries) {
      final page = p.FPDF_LoadPage(doc.handle, entry.key);
      var handles = _flatten(p, page);
      final inForms = entry.value.any(
        (ei) => edits[ei].objectIndices.any(
          (i) => i < handles.length && handles[i].parent != null,
        ),
      );
      if (inForms) {
        _liftTextForms(p, page);
        // Same objects, now directly on the page in page coordinates.
        handles = [for (final h in handles) _Node(h.obj, null, _identity)];
      }
      void remove(_Node n) {
        final parent = n.parent;
        final ok = parent == null
            ? p.FPDFPage_RemoveObject(page, n.obj)
            : p.FPDFFormObj_RemoveObject(parent, n.obj);
        if (ok == 1) p.FPDFPageObj_Destroy(n.obj);
      }

      for (final ei in entry.value) {
        final e = edits[ei];
        final nodes = [
          for (final i in e.objectIndices)
            if (i < handles.length) handles[i],
        ];
        if (nodes.isEmpty) continue;
        final first = nodes.first.obj;
        FPDF_PAGEOBJECT target;
        var targetToPage = nodes.first.toPage;
        final wide = _wide(e.text);
        try {
          if (e.fontId == null) {
            p.FPDFText_SetText(first, wide.cast());
            target = first;
            nodes.skip(1).forEach(remove);
          } else {
            final font = doc.font(e.fontId!, fonts[e.fontId!]!);
            p.FPDFTextObj_GetFontSize(first, sz);
            // The new object goes directly on the page (PDFium cannot add
            // objects to a form), so carry the form's transform over.
            final pm = _concat(_matrixOf(p, first, m), nodes.first.toPage);
            m.ref
              ..a = pm.a
              ..b = pm.b
              ..c = pm.c
              ..d = pm.d
              ..e = pm.e
              ..f = pm.f;
            p.FPDFPageObj_GetFillColor(
              first,
              rgba,
              rgba + 1,
              rgba + 2,
              rgba + 3,
            );
            final mode = p.FPDFTextObj_GetTextRenderMode(first);
            target = p.FPDFPageObj_CreateTextObj(doc.handle, font, sz.value);
            p.FPDFText_SetText(target, wide.cast());
            p.FPDFPageObj_SetMatrix(target, m);
            p.FPDFPageObj_SetFillColor(
              target,
              rgba[0],
              rgba[1],
              rgba[2],
              rgba[3],
            );
            if (mode != FPDF_TEXT_RENDERMODE.FPDF_TEXTRENDERMODE_UNKNOWN) {
              p.FPDFTextObj_SetTextRenderMode(target, mode);
            }
            nodes.forEach(remove);
            p.FPDFPage_InsertObject(page, target);
            targetToPage = _identity;
          }
        } finally {
          calloc.free(wide);
        }
        var b = _pageBounds(p, target, targetToPage);
        if (b.r > e.maxRight + 0.5 && e.fit && b.r > b.l) {
          final s = (e.maxRight - b.l) / (b.r - b.l);
          if (s >= 0.8) {
            p.FPDFPageObj_GetMatrix(target, m);
            m.ref.a = m.ref.a * s;
            p.FPDFPageObj_SetMatrix(target, m);
            b = _pageBounds(p, target, targetToPage);
          }
        }
        overflow[ei] = b.r > e.maxRight + 0.5;
      }
      p.FPDFPage_GenerateContent(page);
      p.FPDF_ClosePage(page);
    }
  } finally {
    calloc.free(m);
    calloc.free(sz);
    calloc.free(rgba);
  }
  return overflow;
}

final _out = BytesBuilder(copy: false);
int _write(Pointer<FPDF_FILEWRITE_> self, Pointer<Void> data, int size) {
  _out.add(Uint8List.fromList(data.cast<Uint8>().asTypedList(size)));
  return 1;
}

Uint8List _save(_Doc doc) {
  _out.clear();
  final cb =
      NativeCallable<
        Int Function(Pointer<FPDF_FILEWRITE_>, Pointer<Void>, UnsignedLong)
      >.isolateLocal(_write, exceptionalReturn: 0);
  final fw = calloc<FPDF_FILEWRITE_>();
  try {
    fw.ref.version = 1;
    fw.ref.WriteBlock = cb.nativeFunction;
    if (doc.p.FPDF_SaveAsCopy(doc.handle, fw.cast(), FPDF_NO_INCREMENTAL) !=
        1) {
      throw StateError('PDF could not be saved');
    }
    return _out.takeBytes();
  } finally {
    calloc.free(fw);
    cb.close();
  }
}

/// Applies [edits] to the PDF in [bytes] and returns the new file.
ApplyResult applyEdits(
  PDFium p,
  Uint8List bytes,
  List<TextEdit> edits,
  EditFonts fonts,
) {
  final doc = _Doc(p, bytes);
  try {
    final overflow = _applyTo(doc, edits, fonts);
    return ApplyResult(_save(doc), overflow);
  } finally {
    doc.close();
  }
}

/// Renders [pageIndex] with [edits] applied, [width] pixels wide (BGRA).
RenderedPage renderPage(
  PDFium p,
  Uint8List bytes,
  List<TextEdit> edits,
  EditFonts fonts,
  int pageIndex,
  int width,
) {
  final doc = _Doc(p, bytes);
  try {
    final overflow = _applyTo(
      doc,
      edits.where((e) => e.page == pageIndex).toList(),
      fonts,
    );
    final page = p.FPDF_LoadPage(doc.handle, pageIndex);
    final pw = p.FPDF_GetPageWidthF(page);
    final ph = p.FPDF_GetPageHeightF(page);
    final w = width;
    final h = math.max(1, (width * ph / pw).round());
    final bmp = p.FPDFBitmap_Create(w, h, 1);
    p.FPDFBitmap_FillRect(bmp, 0, 0, w, h, 0xFFFFFFFF);
    p.FPDF_RenderPageBitmap(bmp, page, 0, 0, w, h, 0, FPDF_ANNOT);
    final stride = p.FPDFBitmap_GetStride(bmp);
    final src = p.FPDFBitmap_GetBuffer(bmp)
        .cast<Uint8>()
        .asTypedList(stride * h);
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      out.setRange(y * w * 4, (y + 1) * w * 4, src, y * stride);
    }
    p.FPDFBitmap_Destroy(bmp);
    p.FPDF_ClosePage(page);
    return RenderedPage(w, h, out, overflow: overflow);
  } finally {
    doc.close();
  }
}
