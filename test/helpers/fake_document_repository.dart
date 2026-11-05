import 'dart:async';

import 'package:docsafe/core/security/security_service.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';

/// In-memory repository for widget tests (the real one is covered with a real
/// SQLCipher database in test/data/document_repository_test.dart).
class FakeDocumentRepository implements DocumentRepository {
  FakeDocumentRepository(this._security);

  final SecurityService _security;
  final List<VaultDocument> _docs = [];
  final _controller = StreamController<List<VaultDocument>>.broadcast();

  @override
  Stream<List<VaultDocument>> watchAll() async* {
    yield List.of(_docs);
    yield* _controller.stream;
  }

  @override
  Future<VaultDocument?> byId(int id) async =>
      _docs.where((d) => d.id == id).firstOrNull;

  @override
  Future<ImportOutcome> importFromPicker() async {
    final f = await _security.pickAndImportDocument(supportedImportTypes);
    if (f == null) return const ImportCancelled();
    final doc = VaultDocument(
      id: _docs.length + 1,
      title: titleFromFileName(f.displayName),
      mimeType: f.mimeType,
      fileId: f.fileId,
      sizeBytes: f.plaintextBytes,
      createdAt: DateTime(2026, 1, 1),
    );
    _docs.insert(0, doc);
    _controller.add(List.of(_docs));
    return ImportSucceeded(doc, isDuplicate: false);
  }

  @override
  Future<String> openForPreview(VaultDocument doc) =>
      _security.decryptToTemp(doc.fileId, doc.previewExtension);

  @override
  Future<void> closePreview(String path) async {
    await _security.deleteTemp(path);
  }

  @override
  Future<int> removeOrphanedFiles() async => 0;

  Future<void> dispose() => _controller.close();
}
