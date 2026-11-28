import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/dialogs.dart';

/// What the in-app camera ended with.
sealed class CameraOutcome {
  const CameraOutcome();
}

/// Photos taken (paths of CAP*.jpg files in the app cache, in order).
class CameraCaptured extends CameraOutcome {
  const CameraCaptured(this.paths);
  final List<String> paths;
}

/// The in-app camera can't be used (no permission, no camera, error):
/// the caller may fall back to the phone's camera app.
class CameraUseSystem extends CameraOutcome {
  const CameraUseSystem();
}

/// Closed without photos.
class CameraCancelled extends CameraOutcome {
  const CameraCancelled();
}

typedef CameraLauncher = Future<CameraOutcome> Function(
  BuildContext context,
  int maxPhotos,
);

/// Opens the in-app camera. Overridden in tests (no camera on the host).
final cameraLauncherProvider = Provider<CameraLauncher>(
  (ref) =>
      (context, maxPhotos) async =>
          await Navigator.of(context).push<CameraOutcome>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => CameraCaptureScreen(maxPhotos: maxPhotos),
            ),
          ) ??
          const CameraCancelled(),
);

/// Takes document photos inside the app.
///
/// The phone's camera app would put this app in the background, where
/// Android may end it to free memory: the vault then locks and asks for the
/// PIN again, and the photo is lost. Here the app stays in front. Several
/// photos can be taken in a row; they stay in the app's private cache until
/// they are turned into pages (and wiped) or discarded.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
    required this.maxPhotos,
    this.findCameras = availableCameras,
  });
  final int maxPhotos;

  /// Lists the cameras (replaced in tests, which have none).
  final Future<List<CameraDescription>> Function() findCameras;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final _taken = <String>[];
  bool _busy = false;
  bool _failed = false;
  bool _denied = false;
  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // The camera must be released while the app is not in front.
      _controller = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && c == null && !_failed) {
      _open();
    }
  }

  Future<void> _open() async {
    try {
      final cameras = await widget.findCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final c = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await c.initialize();
      await c.setFlashMode(_flash).catchError((_) {});
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _failed = false;
        _denied = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _denied =
            e.code.contains('AccessDenied') || e.code.contains('ermission');
      });
    } catch (_) {
      // Plugin missing or another failure: offer the phone's camera app.
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null || _busy || _taken.length >= widget.maxPhotos) return;
    setState(() => _busy = true);
    try {
      final file = await c.takePicture();
      unawaited(HapticFeedback.mediumImpact());
      _taken.add(file.path);
    } on CameraException {
      // A missed shot: the user simply tries again.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (_taken.length >= widget.maxPhotos && mounted) _done();
  }

  void _done() => Navigator.of(context).pop(CameraCaptured(List.of(_taken)));

  Future<void> _close() async {
    if (_taken.isEmpty) {
      Navigator.of(context).pop(const CameraCancelled());
      return;
    }
    final l = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l.cameraDiscardTitle(_taken.length),
      message: l.cameraDiscardBody,
      confirmLabel: l.scanDiscard,
      destructive: true,
    );
    if (!ok || !mounted) return;
    for (final p in _taken) {
      try {
        File(p).deleteSync();
      } catch (_) {
        // Wiped by the app on lock and start in any case.
      }
    }
    Navigator.of(context).pop(const CameraCancelled());
  }

  void _toggleFlash() {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    setState(() => _flash = next);
    _controller?.setFlashMode(next).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = _controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            key: const Key('camera-close'),
            tooltip: l.cancel,
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
          title: Text(l.photosTakePhoto),
          actions: [
            if (c != null)
              IconButton(
                key: const Key('camera-flash'),
                tooltip: l.cameraFlash,
                icon: Icon(switch (_flash) {
                  FlashMode.off => Icons.flash_off,
                  FlashMode.auto => Icons.flash_auto,
                  _ => Icons.flash_on,
                }),
                onPressed: _toggleFlash,
              ),
          ],
        ),
        body: _failed
            ? _Unavailable(
                denied: _denied,
                onSystemCamera: () =>
                    Navigator.of(context).pop(const CameraUseSystem()),
              )
            : c == null || !c.value.isInitialized
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1 / c.value.aspectRatio,
                        child: CameraPreview(c),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.cameraCount(_taken.length),
                              key: const Key('camera-count'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: l.cameraShutter,
                            child: GestureDetector(
                              key: const Key('camera-shutter'),
                              onTap: _shoot,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                ),
                                padding: const EdgeInsets.all(5),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _busy
                                        ? Colors.white54
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                key: const Key('camera-done'),
                                onPressed: _taken.isEmpty || _busy
                                    ? null
                                    : _done,
                                child: Text(l.cameraDone),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.denied, required this.onSystemCamera});
  final bool denied;
  final VoidCallback onSystemCamera;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              denied ? l.cameraDenied : l.cameraUnavailable,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('camera-use-system'),
              onPressed: onSystemCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l.cameraUseSystem),
            ),
          ],
        ),
      ),
    );
  }
}
