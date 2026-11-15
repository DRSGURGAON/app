import 'dart:convert';
import 'dart:typed_data';

/// What DocSafe needs to know about a TrueType/OpenType font file: its family
/// and style names, weight, italic flag and which characters it can draw.
class FontFileInfo {
  const FontFileInfo({
    required this.family,
    required this.subfamily,
    required this.postScriptName,
    required this.weight,
    required this.italic,
    required this.monospace,
    required this.runes,
  });

  final String family;
  final String subfamily;
  final String postScriptName;
  final int weight;
  final bool italic;
  final bool monospace;

  /// Unicode code points with a glyph (from the font's cmap).
  final Set<int> runes;

  bool get bold => weight >= 600;

  /// Parses [bytes]; returns null for anything that is not a single
  /// TrueType/OpenType font (collections are not supported).
  static FontFileInfo? parse(Uint8List bytes) {
    try {
      return _Parser(bytes).run();
    } catch (_) {
      return null;
    }
  }
}

class _Parser {
  _Parser(Uint8List bytes) : d = ByteData.sublistView(bytes), b = bytes;
  final ByteData d;
  final Uint8List b;
  final tables = <String, (int, int)>{};

  int u16(int o) => d.getUint16(o);
  int u32(int o) => d.getUint32(o);

  FontFileInfo? run() {
    final tag = u32(0);
    // 0x00010000 TrueType, 'OTTO' CFF, 'true' Apple TrueType.
    if (tag != 0x00010000 && tag != 0x4F54544F && tag != 0x74727565) {
      return null;
    }
    final n = u16(4);
    for (var i = 0; i < n; i++) {
      final r = 12 + i * 16;
      final name = String.fromCharCodes(b.sublist(r, r + 4));
      tables[name] = (u32(r + 8), u32(r + 12));
    }
    final names = _names();
    final family = names[16] ?? names[1];
    if (family == null || family.isEmpty) return null;
    var weight = 400;
    var italic = false;
    if (tables['OS/2'] case (final o, final len) when len >= 64) {
      weight = u16(o + 4);
      italic = (u16(o + 62) & 0x01) != 0;
    }
    var mono = false;
    if (tables['post'] case (final o, final len) when len >= 16) {
      mono = u32(o + 12) != 0;
    }
    final sub = names[17] ?? names[2] ?? 'Regular';
    if (sub.toLowerCase().contains('italic') ||
        sub.toLowerCase().contains('oblique')) {
      italic = true;
    }
    return FontFileInfo(
      family: family,
      subfamily: sub,
      postScriptName: names[6] ?? family,
      weight: weight,
      italic: italic,
      monospace: mono,
      runes: _cmap(),
    );
  }

  Map<int, String> _names() {
    final out = <int, String>{};
    final t = tables['name'];
    if (t == null) return out;
    final (o, _) = t;
    final count = u16(o + 2);
    final strings = o + u16(o + 4);
    for (var i = 0; i < count; i++) {
      final r = o + 6 + i * 12;
      final platform = u16(r), encoding = u16(r + 2), language = u16(r + 4);
      final id = u16(r + 6), len = u16(r + 8), off = u16(r + 10);
      if (![1, 2, 4, 6, 16, 17].contains(id)) continue;
      final raw = b.sublist(strings + off, strings + off + len);
      String? s;
      if (platform == 3 && (encoding == 1 || encoding == 0 || encoding == 10)) {
        if (language != 0x409 && out.containsKey(id)) continue;
        final units = [
          for (var k = 0; k + 1 < raw.length; k += 2)
            (raw[k] << 8) | raw[k + 1],
        ];
        s = String.fromCharCodes(units);
      } else if (platform == 1 && encoding == 0 && !out.containsKey(id)) {
        s = latin1.decode(raw);
      }
      if (s != null) out[id] = s;
    }
    return out;
  }

  Set<int> _cmap() {
    final runes = <int>{};
    final t = tables['cmap'];
    if (t == null) return runes;
    final (o, _) = t;
    final n = u16(o + 2);
    int? best4, best12;
    for (var i = 0; i < n; i++) {
      final r = o + 4 + i * 8;
      final platform = u16(r), encoding = u16(r + 2);
      final sub = o + u32(r + 4);
      final format = u16(sub);
      final unicode =
          platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
      if (!unicode) continue;
      if (format == 12) best12 ??= sub;
      if (format == 4) best4 ??= sub;
    }
    if (best12 != null) {
      final groups = u32(best12 + 12);
      for (var g = 0; g < groups; g++) {
        final r = best12 + 16 + g * 12;
        final start = u32(r), end = u32(r + 4), glyph = u32(r + 8);
        if (end - start > 0x10000) continue;
        for (var c = start; c <= end; c++) {
          if (glyph + (c - start) != 0) runes.add(c);
        }
      }
      return runes;
    }
    if (best4 != null) {
      final segX2 = u16(best4 + 6);
      final ends = best4 + 14;
      final starts = ends + segX2 + 2;
      final deltas = starts + segX2;
      final offsets = deltas + segX2;
      for (var s = 0; s < segX2 ~/ 2; s++) {
        final end = u16(ends + s * 2), start = u16(starts + s * 2);
        final delta = d.getInt16(deltas + s * 2);
        final roff = u16(offsets + s * 2);
        if (start == 0xFFFF) continue;
        for (var c = start; c <= end; c++) {
          int glyph;
          if (roff == 0) {
            glyph = (c + delta) & 0xFFFF;
          } else {
            final at = offsets + s * 2 + roff + (c - start) * 2;
            if (at + 1 >= b.length) continue;
            glyph = u16(at);
            if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
          }
          if (glyph != 0) runes.add(c);
        }
      }
    }
    return runes;
  }
}
