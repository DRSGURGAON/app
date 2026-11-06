import 'package:intl/intl.dart';

import '../../data/models/vault_document.dart';
import '../../data/repositories/text_rules.dart';
import 'gen/app_localizations.dart';

extension DisplayNames on AppLocalizations {
  String categoryName(CategorySummary c) =>
      c.customName ?? defaultCategoryName(c.key) ?? categoryOther;

  String? defaultCategoryName(String? key) => switch (key) {
    'identity' => categoryIdentity,
    'education' => categoryEducation,
    'vehicle' => categoryVehicle,
    'finance' => categoryFinance,
    'insurance' => categoryInsurance,
    'medical' => categoryMedical,
    'property' => categoryProperty,
    'work' => categoryWork,
    'bills' => categoryBills,
    'personal' => categoryPersonal,
    'other' => categoryOther,
    _ => null,
  };

  String documentTypeLabel(VaultDocument d) =>
      d.isPdf ? documentPdf : documentImage;

  String sortLabelFor(DocumentSort s) => switch (s) {
    DocumentSort.newest => sortNewest,
    DocumentSort.oldest => sortOldest,
    DocumentSort.titleAsc => sortTitleAsc,
    DocumentSort.titleDesc => sortTitleDesc,
    DocumentSort.largest => sortLargest,
  };
}

String formatBytes(int bytes, String locale) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  final f = NumberFormat(u == 0 ? '0' : '0.0', locale);
  return '${f.format(v)} ${units[u]}';
}

String formatDate(DateTime d, String locale) =>
    DateFormat.yMMMd(locale).format(d);

String formatIsoDate(String iso, String locale) =>
    formatDate(parseIsoDate(iso), locale);
