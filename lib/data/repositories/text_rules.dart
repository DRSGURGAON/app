/// Validation and normalisation of user-entered text. Pure functions, unit-tested.
library;

const maxTitleLength = 200;
const maxTagLength = 40;
const maxTagsPerDocument = 20;
const maxFolderNameLength = 80;

/// Strips the extension and control characters; falls back to a neutral title.
String titleFromFileName(String name) {
  var t = name.trim();
  final dot = t.lastIndexOf('.');
  if (dot > 0) t = t.substring(0, dot);
  t = _stripControl(t).trim();
  if (t.isEmpty) t = 'Document';
  return t.length > maxTitleLength ? t.substring(0, maxTitleLength) : t;
}

/// Title typed by the user. Throws [ArgumentError] if empty.
String cleanTitle(String title) => _requiredName(title, maxTitleLength);

String cleanFolderName(String name) => _requiredName(name, maxFolderNameLength);

String _requiredName(String raw, int max) {
  final t = _stripControl(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) throw ArgumentError('Name is empty');
  return t.length > max ? t.substring(0, max).trimRight() : t;
}

/// Null when blank; otherwise trimmed and capped.
String? cleanOptionalText(String? raw, {required int maxLength}) {
  if (raw == null) return null;
  final t = raw
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
      .trim();
  if (t.isEmpty) return null;
  return t.length > maxLength ? t.substring(0, maxLength) : t;
}

/// Trims, collapses spaces, drops empties and case-insensitive duplicates,
/// caps each tag's length and the number of tags.
List<String> normalizeTags(Iterable<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final r in raw) {
    var t = _stripControl(r).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.startsWith('#')) t = t.substring(1).trim();
    if (t.isEmpty) continue;
    if (t.length > maxTagLength) t = t.substring(0, maxTagLength).trimRight();
    if (seen.add(t.toLowerCase())) out.add(t);
    if (out.length == maxTagsPerDocument) break;
  }
  return out;
}

/// Escapes `%`, `_` and `\` for a LIKE pattern using `\` as escape character.
String escapeLike(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

/// Calendar date as ISO `yyyy-MM-dd` (local date, no time zone).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

bool isValidIsoDate(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return false;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  if (y < 1900 || y > 2200) return false;
  final dt = DateTime(y, mo, d);
  return dt.year == y && dt.month == mo && dt.day == d;
}

DateTime parseIsoDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String _stripControl(String s) =>
    s.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
