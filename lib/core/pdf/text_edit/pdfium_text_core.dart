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

List<_Obj> _textObjects(PDFium p, FPDF_PAGE page, FPDF_TEXTPAGE tp) {
  final out = <_Obj>[];
  final n = p.FPDFPage_CountObjects(page);
  final m = calloc<FS_MATRIX>();
  final sz = calloc<Float>();
  final rgba = calloc<UnsignedInt>(4);
  try {
    for (var i = 0; i < n; i++) {
      final o = p.FPDFPage_GetObject(page, i);
      if (p.FPDFPageObj_GetType(o) != FPDF_PAGEOBJ_TEXT) continue;
      final text = _objText(p, o, tp);
      if (text.trim().isEmpty) continue;
      final f = p.FPDFTextObj_GetFont(o);
      p.FPDFTextObj_GetFontSize(o, sz);
      p.FPDFPageObj_GetMatrix(o, m);
      p.FPDFPageObj_GetFillColor(o, rgba, rgba + 1, rgba + 2, rgba + 3);
      final mm = m.ref;
      final scale = math.sqrt(mm.c * mm.c + mm.d * mm.d);
      final bb = _bounds(p, o);
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
    final pageCount = p.FPDF_GetPageCount(doc.handle);
    for (var pi = 0; pi < pageCount; pi++) {
      final page = p.FPDF_LoadPage(doc.handle, pi);
      final width = p.FPDF_GetPageWidthF(page);
      pages.add(PdfPageSize(width, p.FPDF_GetPageHeightF(page)));
      final tp = p.FPDFText_LoadPage(page);
      final objs = _textObjects(p, page, tp);
      for (final o in objs) {
        usedRunes.putIfAbsent(o.fontKey, () => {}).addAll(o.text.runes);
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
          runes: {...e.value.runes, ...?usedRunes[e.key]},
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
    final buf = StringBuffer(group.first.text);
    for (var i = 1; i < group.length; i++) {
      final gap = group[i].l - group[i - 1].r;
      final joined = buf.toString();
      if (gap > group[i].size * 0.15 &&
          !joined.endsWith(' ') &&
          !group[i].text.startsWith(' ')) {
        buf.write(' ');
      }
      buf.write(group[i].text);
    }
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
    result.add(
      TextRun(
        page: page,
        objectIndices: [for (final o in group) o.index],
        text: buf.toString().trimRight(),
        left: left,
        bottom: group.map((o) => o.b).reduce(math.min),
        right: right,
        top: group.map((o) => o.t).reduce(math.max),
        fontKey: first.fontKey,
        fontSize: first.size,
        color: first.color,
        maxRight: math.max(maxRight, right),
      ),
    );
  }
  return result;
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
      final count = p.FPDFPage_CountObjects(page);
      final handles = [
        for (var i = 0; i < count; i++) p.FPDFPage_GetObject(page, i),
      ];
      for (final ei in entry.value) {
        final e = edits[ei];
        final objs = [
          for (final i in e.objectIndices)
            if (i < handles.length) handles[i],
        ];
        if (objs.isEmpty) continue;
        final first = objs.first;
        FPDF_PAGEOBJECT target;
        final wide = _wide(e.text);
        try {
          if (e.fontId == null) {
            p.FPDFText_SetText(first, wide.cast());
            target = first;
            for (final o in objs.skip(1)) {
              p.FPDFPage_RemoveObject(page, o);
              p.FPDFPageObj_Destroy(o);
            }
          } else {
            final font = doc.font(e.fontId!, fonts[e.fontId!]!);
            p.FPDFTextObj_GetFontSize(first, sz);
            p.FPDFPageObj_GetMatrix(first, m);
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
            for (final o in objs) {
              p.FPDFPage_RemoveObject(page, o);
              p.FPDFPageObj_Destroy(o);
            }
            p.FPDFPage_InsertObject(page, target);
          }
        } finally {
          calloc.free(wide);
        }
        var b = _bounds(p, target);
        if (b.r > e.maxRight + 0.5 && e.fit && b.r > b.l) {
          final s = (e.maxRight - b.l) / (b.r - b.l);
          if (s >= 0.8) {
            p.FPDFPageObj_GetMatrix(target, m);
            m.ref.a = m.ref.a * s;
            p.FPDFPageObj_SetMatrix(target, m);
            b = _bounds(p, target);
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
