import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../core/security/security_failure.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/document_repository.dart';

/// Decrypts a document to a short-lived temp file, shows it, and wipes the
/// temp file when the screen closes (and on lock, natively).
class DocumentPreviewScreen extends ConsumerStatefulWidget {
  const DocumentPreviewScreen({super.key, required this.documentId});

  final int documentId;

  @override
  ConsumerState<DocumentPreviewScreen> createState() =>
      _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends ConsumerState<DocumentPreviewScreen> {
  DocumentRepository? _repo;
  VaultDocument? _doc;
  String? _path;
  SecurityErrorCode? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final repo = await ref.read(documentRepositoryProvider.future);
      _repo = repo;
      final doc = await repo.byId(widget.documentId);
      if (doc == null) throw const SecurityFailure(SecurityErrorCode.io);
      final path = await repo.openForPreview(doc);
      if (!mounted) {
        await repo.closePreview(path);
        return;
      }
      setState(() {
        _doc = doc;
        _path = path;
      });
    } on SecurityFailure catch (e) {
      if (mounted) setState(() => _error = e.code);
    } catch (_) {
      if (mounted) setState(() => _error = SecurityErrorCode.unknown);
    }
  }

  @override
  void dispose() {
    final path = _path;
    if (path != null) {
      if (_doc?.isImage ?? false) {
        // Drop the decoded pixels from the image cache as well.
        PaintingBinding.instance.imageCache.clear();
      }
      _repo?.closePreview(path).catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final doc = _doc;
    final path = _path;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          doc?.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _error != null
          ? _PreviewError(message: l.errorFor(_error!))
          : path == null || doc == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l.previewOpening),
                ],
              ),
            )
          : doc.isPdf
          ? PdfViewer.file(
              path,
              params: PdfViewerParams(
                // A damaged PDF that still decrypted (authentic but not
                // renderable) shows DocSafe's own message, not a raw error.
                errorBannerBuilder: (_, _, _, _) =>
                    _PreviewError(message: l.errorIntegrity),
              ),
            )
          : InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: Image(
                  // Decode at screen size (x3 for zoom) instead of full
                  // resolution: a 48 MP photo would otherwise need ~190 MB.
                  image: ResizeImage(
                    FileImage(File(path)),
                    width: previewDecodeWidth(context),
                    policy: ResizeImagePolicy.fit,
                  ),
                  errorBuilder: (_, _, _) =>
                      _PreviewError(message: l.errorIntegrity),
                ),
              ),
            ),
    );
  }
}

/// Key of the preview error widget (used by on-device tests).
const previewErrorKey = ValueKey('preview-error');

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message}) : super(key: previewErrorKey);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.gpp_bad_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

/// Pixel width used to decode image previews.
int previewDecodeWidth(BuildContext context) {
  final mq = MediaQuery.of(context);
  return (mq.size.width * mq.devicePixelRatio * 3).round().clamp(1024, 4096);
}
