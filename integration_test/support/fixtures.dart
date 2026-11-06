// On-device test support. Talks to the DEBUG-ONLY fixture channel
// (android/app/src/debug/.../TestFixtures.kt); release builds do not contain it.

import 'package:docsafe/core/security/security_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('docsafe.debug/fixtures');

class FixtureFile {
  FixtureFile(this.file, this.sha256);
  final ImportedFile file;

  /// SHA-256 of the plaintext as generated (to compare after decryption).
  final String sha256;
}

abstract final class Fixtures {
  static Future<int> pid() async => (await _channel.invokeMethod<int>('pid'))!;

  static FixtureFile _toFile(
    Map<Object?, Object?> m,
    String name,
    String mime,
  ) => FixtureFile(
    ImportedFile(
      fileId: m['fileId']! as String,
      displayName: name,
      mimeType: mime,
      plaintextBytes: m['plaintextBytes']! as int,
      ciphertextBytes: m['ciphertextBytes']! as int,
      fingerprint: m['fingerprint'] as String?,
    ),
    m['sha256']! as String,
  );

  static Future<FixtureFile> importBytes(
    Uint8List bytes,
    String name,
    String mime,
  ) async => _toFile(
    (await _channel.invokeMapMethod<Object?, Object?>('importBytes', {
      'bytes': bytes,
    }))!,
    name,
    mime,
  );

  static Future<FixtureFile> generatedPdf(
    String name, {
    required int pages,
    int width = 1240,
    int height = 1754,
    bool noise = false,
  }) async => _toFile(
    (await _channel.invokeMapMethod<Object?, Object?>('importGeneratedPdf', {
      'pages': pages,
      'width': width,
      'height': height,
      'noise': noise,
    }))!,
    name,
    'application/pdf',
  );

  static Future<FixtureFile> generatedJpeg(
    String name, {
    required int width,
    required int height,
  }) async => _toFile(
    (await _channel.invokeMapMethod<Object?, Object?>('importGeneratedJpeg', {
      'width': width,
      'height': height,
    }))!,
    name,
    'image/jpeg',
  );

  static Future<void> corruptContainer(String fileId) =>
      _channel.invokeMethod('corruptContainer', {'fileId': fileId});

  static Future<String> sha256OfFile(String path) async =>
      (await _channel.invokeMethod<String>('sha256OfFile', {'path': path}))!;

  static Future<List<String>> cacheFiles() async =>
      (await _channel.invokeListMethod<String>('listCacheFiles'))!;

  /// Decrypted preview files still on disk (must be none when no viewer is open).
  static Future<List<String>> plaintextPreviews() async =>
      (await cacheFiles()).where((p) => p.contains('/vault_tmp/')).toList();
}

/// Production security service, except "pick a file" returns the next fixture
/// (already encrypted by the real native vault) instead of opening the picker.
class FixtureSecurityService extends PigeonSecurityService {
  Future<FixtureFile> Function()? next;
  FixtureFile? last;

  @override
  Future<ImportedFile?> pickAndImportDocument(List<String> mimeTypes) async {
    final n = next;
    next = null;
    if (n == null) return null;
    last = await n();
    return last!.file;
  }
}

Future<void> settleFor(WidgetTester tester, {int seconds = 5}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> enterPinOnPad(WidgetTester tester, String pin) async {
  for (final ch in pin.split('')) {
    await tester.tap(find.text(ch).last);
    await tester.pump(const Duration(milliseconds: 50));
  }
  await settleFor(tester, seconds: 3);
}

/// Polls (in real time) until [condition] holds or [timeout] passes.
Future<bool> waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) return true;
  }
  return condition();
}
