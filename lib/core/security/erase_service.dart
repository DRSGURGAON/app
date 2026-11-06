import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import '../utils/app_logger.dart';
import 'lock_controller.dart';

/// Wording the user must type to confirm erasing everything (not localised on
/// purpose: one fixed, unambiguous word in both languages).
const eraseConfirmationWord = 'ERASE';

/// Orchestrates "erase everything": close the encrypted database, then let the
/// native layer wipe files, database, PIN, biometric enrolment and Keystore keys.
class EraseService {
  EraseService(this._ref);
  final Ref _ref;

  Future<void> eraseEverything() async {
    final ctl = _ref.read(lockControllerProvider.notifier);
    ctl.beginErase();
    // Dispose the database provider now (its onDispose closes the database)
    // and wait for the close before the native layer deletes the file.
    _ref.invalidate(databaseProvider);
    // Drift finishes closing once its stream queries are released (data
    // providers are autoDispose, so leaving the vault releases them). Never
    // wait forever: the native wipe unlinks the file and destroys its key,
    // so a lingering connection cannot expose anything.
    try {
      await databaseClosed().timeout(const Duration(seconds: 3));
    } catch (_) {
      AppLogger.event('erase_db_close_timeout');
    }
    AppLogger.event('erase_all');
    await ctl.eraseAll();
  }
}

final eraseServiceProvider = Provider<EraseService>(EraseService.new);
