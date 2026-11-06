import '../../core/security/security_failure.dart';
import 'gen/app_localizations.dart';

extension SecurityErrorText on AppLocalizations {
  String errorFor(SecurityErrorCode code) => switch (code) {
    SecurityErrorCode.lowStorage => errorLowStorage,
    SecurityErrorCode.integrity => errorIntegrity,
    SecurityErrorCode.invalidInput => errorUnsupported,
    SecurityErrorCode.io => errorIo,
    SecurityErrorCode.keyUnavailable => errorKeyUnavailable,
    SecurityErrorCode.locked => errorLocked,
    SecurityErrorCode.busy => errorBusy,
    SecurityErrorCode.databaseKey => errorDatabaseKey,
    SecurityErrorCode.scannerUnavailable => scanUnavailable,
    SecurityErrorCode.pdfUnreadable => errorPdfUnreadable,
    SecurityErrorCode.tooLarge => errorTooLarge,
    SecurityErrorCode.noActivity || SecurityErrorCode.unknown => errorGeneric,
  };

  /// "m:ss" countdown text, locale-neutral digits.
  String formatCountdown(Duration d) {
    final s = d.inSeconds < 1 ? 1 : d.inSeconds;
    final m = s ~/ 60;
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }
}
