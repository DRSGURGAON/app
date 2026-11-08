import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/locale_controller.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/vault_document.dart';
import '../services/ocr_analysis.dart';

/// Pages read per OCR run (keeps time and memory bounded on large PDFs).
const ocrMaxPages = 20;

/// Result of reading a document, before the user decides what to keep.
class OcrReading {
  const OcrReading({
    required this.maskedText,
    required this.pagesRead,
    required this.pageCount,
    this.suggestedCategoryKey,
    this.suggestedExpiry,
  });

  /// Recognised text with Aadhaar / PAN numbers masked (what would be stored).
  final String maskedText;
  final int pagesRead;
  final int pageCount;
  final String? suggestedCategoryKey;

  /// ISO `yyyy-MM-dd`.
  final String? suggestedExpiry;

  bool get isEmpty => maskedText.trim().isEmpty;
}

/// On-device OCR plus the confirmed, masked text kept for search.
class DocumentTextRepository {
  DocumentTextRepository(
    this._db,
    this._security, {
    DateTime Function()? clock,
    this.monthFirstDates = false,
  }) : _clock = clock ?? DateTime.now;

  /// US phones: read 08/14/2031 as August 14.
  final bool monthFirstDates;

  final AppDatabase _db;
  final SecurityService _security;
  final DateTime Function() _clock;

  /// Runs OCR. Nothing is stored here: suggestions are computed from the
  /// unmasked text in memory, the returned text is already masked.
  Future<OcrReading> read(VaultDocument doc) async {
    final r = await _security.recognizeText(
      doc.fileId,
      doc.mimeType,
      ocrMaxPages,
    );
    AppLogger.event('ocr_done');
    return OcrReading(
      maskedText: OcrAnalysis.maskSensitiveNumbers(r.text).trim(),
      pagesRead: r.pagesRead,
      pageCount: r.pageCount,
      suggestedCategoryKey: OcrAnalysis.suggestCategory(r.text),
      suggestedExpiry: OcrAnalysis.suggestExpiry(
        r.text,
        monthFirst: monthFirstDates,
      ),
    );
  }

  /// Stores (replaces) the text the user confirmed. Masks again defensively.
  Future<void> save(int documentId, OcrReading reading) => _db
      .into(_db.documentTexts)
      .insertOnConflictUpdate(
        DocumentTextsCompanion.insert(
          documentId: Value(documentId),
          body: OcrAnalysis.maskSensitiveNumbers(reading.maskedText),
          pagesRead: reading.pagesRead,
          pageCount: reading.pageCount,
          recognizedAt: _clock(),
        ),
      );

  Future<void> delete(int documentId) => (_db.delete(
    _db.documentTexts,
  )..where((t) => t.documentId.equals(documentId))).go();

  Stream<DocumentText?> watch(int documentId) => (_db.select(
    _db.documentTexts,
  )..where((t) => t.documentId.equals(documentId))).watchSingleOrNull();
}

final documentTextRepositoryProvider = FutureProvider<DocumentTextRepository>(
  retry: noRetry,
  (ref) async => DocumentTextRepository(
    await ref.watch(databaseProvider.future),
    ref.read(securityServiceProvider),
    monthFirstDates: ref.read(deviceLocaleProvider).countryCode == 'US',
  ),
);

final documentTextProvider = StreamProvider.autoDispose
    .family<DocumentText?, int>(retry: noRetry, (ref, id) async* {
      final repo = await ref.watch(documentTextRepositoryProvider.future);
      yield* repo.watch(id);
    });
