/// A document as shown in the vault UI. Contains metadata only — never content.
class VaultDocument {
  const VaultDocument({
    required this.id,
    required this.title,
    required this.mimeType,
    required this.fileId,
    required this.sizeBytes,
    required this.createdAt,
    this.updatedAt,
    this.isFavourite = false,
    this.categoryId,
    this.folderId,
    this.expiryDate,
    this.deletedAt,
  });

  final int id;
  final String title;
  final String mimeType;
  final String fileId;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isFavourite;
  final int? categoryId;
  final int? folderId;

  /// ISO calendar date `yyyy-MM-dd`, if the user entered one.
  final String? expiryDate;

  /// Set only for documents in Recently Deleted.
  final DateTime? deletedAt;

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

/// Everything the details screen shows for one document.
class DocumentDetails {
  const DocumentDetails({
    required this.document,
    required this.tags,
    this.issueDate,
    this.expiryDate,
    this.notes,
  });

  final VaultDocument document;
  final List<String> tags;
  final String? issueDate;
  final String? expiryDate;
  final String? notes;
}

enum ImportKind {
  pdf(['application/pdf']),
  image(['image/jpeg', 'image/png']),
  any(['application/pdf', 'image/jpeg', 'image/png']);

  const ImportKind(this.mimeTypes);
  final List<String> mimeTypes;
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

enum DocumentSort { newest, oldest, titleAsc, titleDesc, largest }

/// Filter for document lists. Trash is always excluded.
class DocumentQuery {
  const DocumentQuery({
    this.folderId,
    this.categoryId,
    this.favouritesOnly = false,
    this.text,
    this.matchingCategoryIds = const {},
    this.includeRecognizedText = false,
    this.sort = DocumentSort.newest,
    this.limit,
  });

  final int? folderId;
  final int? categoryId;
  final bool favouritesOnly;

  /// Free-text search over title and tags (case-insensitive substring).
  final String? text;

  /// Categories whose localised display name matches [text]; computed by the
  /// UI because default category names are localised.
  final Set<int> matchingCategoryIds;

  /// Also match text recognised by OCR (Premium).
  final bool includeRecognizedText;
  final DocumentSort sort;
  final int? limit;

  @override
  bool operator ==(Object other) =>
      other is DocumentQuery &&
      other.folderId == folderId &&
      other.categoryId == categoryId &&
      other.favouritesOnly == favouritesOnly &&
      other.text == text &&
      other.includeRecognizedText == includeRecognizedText &&
      other.sort == sort &&
      other.limit == limit &&
      other.matchingCategoryIds.length == matchingCategoryIds.length &&
      other.matchingCategoryIds.containsAll(matchingCategoryIds);

  @override
  int get hashCode => Object.hash(
    folderId,
    categoryId,
    favouritesOnly,
    text,
    includeRecognizedText,
    sort,
    limit,
    Object.hashAllUnordered(matchingCategoryIds),
  );
}

class FolderSummary {
  const FolderSummary({
    required this.id,
    required this.name,
    required this.documentCount,
  });
  final int id;
  final String name;
  final int documentCount;
}

class CategorySummary {
  const CategorySummary({
    required this.id,
    required this.key,
    required this.customName,
    required this.isDefault,
    required this.documentCount,
  });
  final int id;

  /// Stable key of a default category (localised in the UI); null for custom ones.
  final String? key;
  final String? customName;
  final bool isDefault;
  final int documentCount;
}

class VaultStats {
  const VaultStats({
    required this.documentCount,
    required this.totalBytes,
    required this.trashCount,
  });
  final int documentCount;
  final int totalBytes;
  final int trashCount;
}
