import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart' show noRetry;
import '../../core/pdf/text_edit/font_library.dart';
import '../../core/pdf/text_edit/font_matching.dart';
import '../../core/pdf/text_edit/font_matching.dart' as fonts show chooseFont;
import '../../core/pdf/text_edit/pdf_text_engine.dart';
import '../../core/pdf/text_edit/text_model.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../core/security/security_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/vault_document.dart';
import '../repositories/document_repository.dart';
import 'pdf_tools_service.dart' show annotationBlockedCategoryKey;

/// PDFs above this size are not edited (the file is held in memory).
const maxTextEditPdfBytes = 50 * 1024 * 1024;

class TextEditNotAllowed implements Exception {
  const TextEditNotAllowed();
}

/// One change the user made, with the font it will be drawn in.
class PendingTextEdit {
  const PendingTextEdit(this.run, this.text, this.choice, {this.fit = true});
  final TextRun run;
  final String text;
  final FontChoice choice;
  final bool fit;

  TextEdit toEdit() =>
      TextEdit.of(run, text, fontId: choice.font?.id, fit: fit);
}

/// An open document in the editor: its bytes stay in memory only.
class TextEditSession {
  TextEditSession(this.doc, this.pdf, this.model);
  final VaultDocument doc;
  final Uint8List pdf;
  final PdfTextModel model;
}

/// "Edit text" for English PDFs: changes the real text in the file, keeping
/// the document's own font whenever it has every character.
class PdfTextEditService {
  PdfTextEditService(
    this._repo,
    this._security,
    this._engine,
    this._fonts, {
    Future<Uint8List> Function(String path)? readFile,
  }) : _readFile = readFile ?? ((p) => File(p).readAsBytes());

  final DocumentRepository _repo;
  final SecurityService _security;
  final PdfTextEngine _engine;
  final PdfFontLibrary _fonts;
  final Future<Uint8List> Function(String path) _readFile;

  Future<bool> canEdit(VaultDocument doc) async =>
      doc.isPdf &&
      await _repo.categoryKeyOf(doc) != annotationBlockedCategoryKey;

  Future<TextEditSession> open(VaultDocument doc) async {
    if (!await canEdit(doc)) throw const TextEditNotAllowed();
    if (doc.sizeBytes > maxTextEditPdfBytes) {
      throw const SecurityFailure(SecurityErrorCode.tooLarge);
    }
    final path = await _repo.openForPreview(doc);
    Uint8List pdf;
    try {
      pdf = await _readFile(path);
    } finally {
      try {
        await _repo.closePreview(path);
      } catch (_) {
        // Wiped on lock / next start anyway.
      }
    }
    final model = await _engine.analyze(pdf);
    return TextEditSession(doc, pdf, model);
  }

  /// The most faithful font for [text] in [run]; [FontChoice.font] is null
  /// (with a non-original kind) when no available font has every character.
  Future<FontChoice> chooseFont(
    TextEditSession s,
    TextRun run,
    String text,
  ) async {
    final font = s.model.fonts[run.fontKey]!;
    return fonts.chooseFont(
      font,
      text,
      await _fonts.candidatesFor(font.family),
    );
  }

  EditFonts _fontBytes(Iterable<PendingTextEdit> edits) => {
    for (final e in edits)
      if (e.choice.font case final f?) f.id: _fonts.bytesOf(f.id),
  };

  Future<RenderedPage> render(
    TextEditSession s,
    List<PendingTextEdit> edits,
    int page,
    int width,
  ) => _engine.render(
    s.pdf,
    [for (final e in edits) e.toEdit()],
    _fontBytes(edits),
    page,
    width,
  );

  /// Writes the edited PDF. With [replaceOriginal] the document keeps its
  /// title, category, folder, tags, dates and reminders and the previous
  /// version goes to Recently deleted as [previousTitle]; otherwise a new
  /// document [copyTitle] is created next to it.
  Future<VaultDocument> save(
    TextEditSession s,
    List<PendingTextEdit> edits, {
    required bool replaceOriginal,
    required String copyTitle,
    required String previousTitle,
  }) async {
    if (edits.isEmpty) throw ArgumentError('No edits');
    final result = await _engine.apply(s.pdf, [
      for (final e in edits) e.toEdit(),
    ], _fontBytes(edits));
    final file = await _security.importPdfBytes(result.bytes);
    final VaultDocument out;
    if (replaceOriginal) {
      out = await _repo.replaceContent(
        s.doc,
        file,
        previousTitle: previousTitle,
      );
    } else {
      out = (await _repo.recordGenerated(
        [file],
        titles: [copyTitle],
        folderId: s.doc.folderId,
        categoryId: s.doc.categoryId,
      )).single;
    }
    AppLogger.event('pdf_text_edit');
    return out;
  }
}

final pdfTextEditServiceProvider = FutureProvider<PdfTextEditService>(
  retry: noRetry,
  (ref) async => PdfTextEditService(
    await ref.watch(documentRepositoryProvider.future),
    ref.read(securityServiceProvider),
    ref.read(pdfTextEngineProvider),
    ref.read(pdfFontLibraryProvider),
  ),
);
