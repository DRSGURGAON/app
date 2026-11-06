import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/lock_controller.dart';
import '../../core/security/security_service.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/document_repository.dart';

/// One scanned page under review. [rotation] is clockwise, in degrees.
class ScanPageState {
  const ScanPageState({
    required this.path,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  final String path;
  final int width;
  final int height;
  final int rotation;

  ScanPageState rotated() => ScanPageState(
    path: path,
    width: width,
    height: height,
    rotation: (rotation + 90) % 360,
  );

  int get quarterTurns => rotation ~/ 90;
}

class ScanState {
  const ScanState({this.pages = const [], this.scanning = false});
  final List<ScanPageState> pages;
  final bool scanning;
}

/// Maximum pages per document.
const scanPageLimit = 50;

/// Review session for scanned pages. Pages are plaintext JPEGs in app-private
/// cache until saved (encrypted) or discarded; the native layer also wipes them
/// on lock and app start. Leaving the review without saving discards them.
final scanControllerProvider =
    NotifierProvider.autoDispose<ScanController, ScanState>(ScanController.new);

class ScanController extends Notifier<ScanState> {
  /// Mirror of the current page paths: Riverpod forbids reading `state`
  /// inside onDispose.
  List<String> _paths = const [];

  @override
  ScanState build() {
    final service = ref.read(securityServiceProvider);
    listenSelf((_, next) => _paths = [for (final p in next.pages) p.path]);
    ref.onDispose(() {
      final left = _paths;
      if (left.isNotEmpty) {
        // Fire and forget: the screen is gone; native also sweeps on lock/start.
        service.discardScan(left).catchError((_) {});
      }
    });
    return const ScanState();
  }

  SecurityService get _service => ref.read(securityServiceProvider);

  /// Opens the ML Kit scanner and appends its pages. Returns false if the user
  /// cancelled. Throws [SecurityFailure] (e.g. scanner unavailable).
  Future<bool> scan() async {
    final remaining = scanPageLimit - state.pages.length;
    if (remaining <= 0) return false;
    state = ScanState(pages: state.pages, scanning: true);
    try {
      final pages = await ref
          .read(lockControllerProvider.notifier)
          .runWithoutAutoLock(
            () => _service.startScan(
              pageLimit: remaining,
              allowGalleryImport: true,
            ),
          );
      if (!ref.mounted) return false;
      final added = [
        for (final p in pages ?? const <ScannedPage>[])
          ScanPageState(path: p.path, width: p.width, height: p.height),
      ];
      state = ScanState(pages: [...state.pages, ...added]);
      return added.isNotEmpty;
    } catch (_) {
      if (ref.mounted) state = ScanState(pages: state.pages);
      rethrow;
    }
  }

  void rotate(int index) {
    final pages = [...state.pages];
    pages[index] = pages[index].rotated();
    state = ScanState(pages: pages);
  }

  void move(int from, int to) {
    if (from == to || to < 0 || to >= state.pages.length) return;
    final pages = [...state.pages];
    final p = pages.removeAt(from);
    pages.insert(to, p);
    state = ScanState(pages: pages);
  }

  /// Removes a page and wipes its file right away.
  Future<void> remove(int index) async {
    final pages = [...state.pages];
    final removed = pages.removeAt(index);
    state = ScanState(pages: pages);
    await _service.discardScan([removed.path]);
  }

  Future<void> discardAll() async {
    final paths = state.pages.map((p) => p.path).toList();
    state = const ScanState();
    if (paths.isNotEmpty) await _service.discardScan(paths);
  }

  /// Encrypts and records the pages; on success the session is emptied (the
  /// repository has already discarded the page files).
  Future<List<VaultDocument>> save({
    required String title,
    required ScanSaveFormat format,
    int? folderId,
    int? categoryId,
    List<String> tags = const [],
  }) async {
    final repo = await ref.read(documentRepositoryProvider.future);
    final docs = await repo.saveScan(
      pages: [
        for (final p in state.pages)
          ScanPageSpec(path: p.path, rotation: p.rotation),
      ],
      format: format,
      title: title,
      folderId: folderId,
      categoryId: categoryId,
      tags: tags,
    );
    if (ref.mounted) state = const ScanState();
    return docs;
  }
}
