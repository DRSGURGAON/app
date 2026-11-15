import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/lock_controller.dart';
import '../../security/security_service.dart';
import 'builtin_fonts.dart';
import 'font_file_info.dart';
import 'font_matching.dart';

/// Fonts available for edited PDF text: the user's own fonts, the phone's
/// fonts (only files whose name matches the family asked for, so the whole
/// system folder is never read), and DocSafe's built-in fallback fonts.
class PdfFontLibrary {
  PdfFontLibrary(
    this._security, {
    AssetBundle? bundle,
    this.systemFontsDir = '/system/fonts',
  }) : _bundle = bundle ?? rootBundle;

  final SecurityService _security;
  final AssetBundle _bundle;
  final String systemFontsDir;

  final _bytes = <String, Uint8List>{};
  final _info = <String, LibraryFont>{};
  List<LibraryFont>? _builtIns;

  Future<List<LibraryFont>> _loadBuiltIns() async {
    final cached = _builtIns;
    if (cached != null) return cached;
    final out = <LibraryFont>[];
    for (final e in builtInPdfFonts.entries) {
      final f = await _load(
        'asset:${e.key}',
        () async =>
            (await _bundle.load('assets/pdf_fonts/${e.key}')).buffer
                .asUint8List(),
        FontSource.builtIn,
        e.value,
      );
      if (f != null) out.add(f);
    }
    return _builtIns = out;
  }

  Future<LibraryFont?> _load(
    String id,
    Future<Uint8List> Function() read,
    FontSource source, [
    List<String> twinOf = const [],
  ]) async {
    final cached = _info[id];
    if (cached != null) return cached;
    try {
      final bytes = await read();
      final info = FontFileInfo.parse(bytes);
      if (info == null) return null;
      _bytes[id] = bytes;
      return _info[id] = LibraryFont(
        id: id,
        info: info,
        source: source,
        twinOf: twinOf,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fonts the user added (Settings of the editor), newest list each time.
  Future<List<LibraryFont>> userFonts() async {
    final dir = Directory(await _security.userFontsDirectory());
    if (!dir.existsSync()) return const [];
    final out = <LibraryFont>[];
    for (final f in dir.listSync().whereType<File>()) {
      final font = await _load(
        'user:${f.uri.pathSegments.last}',
        () async => f.readAsBytesSync(),
        FontSource.user,
      );
      if (font != null) out.add(font);
    }
    out.sort((a, b) => a.info.family.compareTo(b.info.family));
    return out;
  }

  Future<void> deleteUserFont(LibraryFont font) async {
    final name = font.id.substring('user:'.length);
    final f = File('${await _security.userFontsDirectory()}/$name');
    if (f.existsSync()) f.deleteSync();
    _info.remove(font.id);
    _bytes.remove(font.id);
  }

  Future<List<LibraryFont>> _systemFontsFor(String family) async {
    final want = normaliseFamily(family);
    final dir = Directory(systemFontsDir);
    if (want.isEmpty || !dir.existsSync()) return const [];
    final out = <LibraryFont>[];
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      final lower = name.toLowerCase();
      if (!(lower.endsWith('.ttf') || lower.endsWith('.otf'))) continue;
      if (!normaliseFamily(name).startsWith(want)) continue;
      final font = await _load(
        'system:$name',
        () async => f.readAsBytesSync(),
        FontSource.system,
      );
      if (font != null) out.add(font);
    }
    return out;
  }

  /// Every font worth considering for text set in [family].
  Future<List<LibraryFont>> candidatesFor(String family) async => [
    ...await userFonts(),
    ...await _systemFontsFor(family),
    ...await _loadBuiltIns(),
  ];

  /// Bytes of a font returned by [candidatesFor] / [userFonts].
  Uint8List bytesOf(String id) => _bytes[id]!;
}

final pdfFontLibraryProvider = Provider<PdfFontLibrary>(
  (ref) => PdfFontLibrary(ref.read(securityServiceProvider)),
);
