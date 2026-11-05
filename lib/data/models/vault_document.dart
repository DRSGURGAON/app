/// A document as shown in the vault UI. Contains metadata only — never content.
class VaultDocument {
  const VaultDocument({
    required this.id,
    required this.title,
    required this.mimeType,
    required this.fileId,
    required this.sizeBytes,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String mimeType;
  final String fileId;
  final int sizeBytes;
  final DateTime createdAt;

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');

  /// Extension used for the short-lived decrypted preview file.
  String get previewExtension => switch (mimeType) {
    'application/pdf' => 'pdf',
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    _ => 'bin',
  };
}

/// Outcome of a user-initiated import.
sealed class ImportOutcome {
  const ImportOutcome();
}

class ImportCancelled extends ImportOutcome {
  const ImportCancelled();
}

class ImportSucceeded extends ImportOutcome {
  const ImportSucceeded(this.document, {required this.isDuplicate});
  final VaultDocument document;

  /// True if an identical file (same keyed fingerprint) was already stored.
  final bool isDuplicate;
}
