import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

bool get liveCameraCaptureSupported {
  try {
    // Probe mediaDevices without tearing off getUserMedia (disallowed for
    // external extension-type interop members).
    final web.MediaDevices devices = web.window.navigator.mediaDevices;
    return (devices as JSObject).has('getUserMedia');
  } catch (_) {
    return false;
  }
}

bool get liveBarcodeScannerSupported {
  if (!liveCameraCaptureSupported) {
    return false;
  }
  try {
    return globalContext.has('BarcodeDetector');
  } catch (_) {
    return false;
  }
}

final Map<String, _LiveSession> _sessions = <String, _LiveSession>{};

final class _LiveSession {
  _LiveSession({required this.video, required this.viewType});

  final web.HTMLVideoElement video;
  final String viewType;
  web.MediaStream? stream;
  bool factoryRegistered = false;
  Object? detector;
}

Future<Uint8List?> captureLiveCameraFrame({
  required BuildContext context,
  required String title,
  required String captureLabel,
  required String closeLabel,
}) {
  if (!liveCameraCaptureSupported) {
    return Future<Uint8List?>.value();
  }
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext _) => _LiveCameraCaptureDialog(
      title: title,
      captureLabel: captureLabel,
      closeLabel: closeLabel,
    ),
  );
}

Future<String?> scanLiveBarcode({
  required BuildContext context,
  required String title,
  required String body,
  required String closeLabel,
  required String unavailableBody,
}) {
  if (!liveCameraCaptureSupported) {
    return Future<String?>.value();
  }
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext _) => _LiveBarcodeScannerDialog(
      title: title,
      body: body,
      closeLabel: closeLabel,
      unavailableBody: unavailableBody,
    ),
  );
}

Future<void> _startSession(
  _LiveSession session, {
  required void Function(Object error) onError,
  required void Function() onReady,
}) async {
  try {
    final JSAny constraints = <String, Object?>{
      'audio': false,
      'video': <String, Object>{'facingMode': 'environment'},
    }.jsify()!;
    final web.MediaDevices devices = web.window.navigator.mediaDevices;
    final JSPromise<web.MediaStream> promise =
        devices.callMethodVarArgs('getUserMedia'.toJS, <JSAny?>[constraints])
            as JSPromise<web.MediaStream>;
    final web.MediaStream stream = await promise.toDart;
    session.stream = stream;
    session.video.srcObject = stream;
    await session.video.play().toDart;
    onReady();
  } catch (error) {
    onError(error);
  }
}

Future<void> _stopSession(String viewType) async {
  final _LiveSession? session = _sessions.remove(viewType);
  if (session == null) {
    return;
  }
  final web.MediaStream? stream = session.stream;
  if (stream != null) {
    final JSArray tracks =
        stream.callMethod('getTracks'.toJS) as JSArray? ?? <JSAny>[].toJS as JSArray;
    for (final JSAny? track in tracks.toDart) {
      if (track != null) {
        (track as JSObject).callMethod('stop'.toJS);
      }
    }
  }
  session.video.srcObject = null;
}

Future<Uint8List?> _snap(String viewType) async {
  final _LiveSession? session = _sessions[viewType];
  if (session == null) {
    return null;
  }
  final web.HTMLVideoElement video = session.video;
  final int width = video.videoWidth;
  final int height = video.videoHeight;
  if (width <= 0 || height <= 0) {
    return null;
  }
  final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()
    ..width = width
    ..height = height;
  final web.CanvasRenderingContext2D? ctx =
      canvas.getContext('2d') as web.CanvasRenderingContext2D?;
  if (ctx == null) {
    return null;
  }
  ctx.drawImage(video, 0, 0, width.toDouble(), height.toDouble());
  final Completer<Uint8List?> completer = Completer<Uint8List?>();
  canvas.toBlob(
    ((web.Blob? blob) {
      if (blob == null) {
        completer.complete(null);
        return;
      }
      final web.FileReader reader = web.FileReader();
      reader.onloadend = (web.Event _) {
        final JSAny? result = reader.result;
        if (result == null || !result.isA<JSArrayBuffer>()) {
          completer.complete(null);
          return;
        }
        completer.complete((result as JSArrayBuffer).toDart.asUint8List());
      }.toJS;
      reader.onerror = (web.Event _) {
        completer.complete(null);
      }.toJS;
      reader.readAsArrayBuffer(blob);
    }).toJS,
    'image/jpeg',
    0.92.toJS,
  );
  return completer.future;
}

Future<String?> _detectOnce(String viewType) async {
  if (!liveBarcodeScannerSupported) {
    return null;
  }
  final _LiveSession? session = _sessions[viewType];
  if (session == null) {
    return null;
  }
  try {
    final JSAny? detectorCtor = globalContext.getProperty(
      'BarcodeDetector'.toJS,
    );
    if (detectorCtor == null) {
      return null;
    }
    session.detector ??= (detectorCtor as JSFunction).callAsConstructorVarArgs(
      <JSAny?>[
        <String, Object>{
          'formats': <String>[
            'ean_13',
            'ean_8',
            'upc_a',
            'upc_e',
            'code_128',
            'qr_code',
            'code_39',
          ],
        }.jsify(),
      ],
    );
    final JSObject detector = session.detector! as JSObject;
    final JSPromise<JSAny?> promise =
        detector.callMethodVarArgs('detect'.toJS, <JSAny?>[session.video])
            as JSPromise<JSAny?>;
    final JSAny? result = await promise.toDart;
    if (result == null || !result.isA<JSArray>()) {
      return null;
    }
    final JSArray barcodes = result as JSArray;
    if (barcodes.length == 0) {
      return null;
    }
    final JSAny? first = barcodes.getProperty(0.toJS);
    if (first == null || !first.isA<JSObject>()) {
      return null;
    }
    final JSAny? rawValue = (first as JSObject).getProperty('rawValue'.toJS);
    if (rawValue != null && rawValue.isA<JSString>()) {
      final String code = (rawValue as JSString).toDart.trim();
      return code.isEmpty ? null : code;
    }
  } catch (_) {
    return null;
  }
  return null;
}

Widget _preview({
  required String viewType,
  required void Function(Object error) onError,
  required void Function() onReady,
}) {
  final _LiveSession session = _sessions.putIfAbsent(
    viewType,
    () => _LiveSession(
      video: web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = '#111827',
      viewType: viewType,
    ),
  );

  if (!session.factoryRegistered) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      return session.video;
    });
    session.factoryRegistered = true;
    scheduleMicrotask(
      () => _startSession(session, onError: onError, onReady: onReady),
    );
  }

  return HtmlElementView(viewType: viewType);
}

class _LiveCameraCaptureDialog extends StatefulWidget {
  const _LiveCameraCaptureDialog({
    required this.title,
    required this.captureLabel,
    required this.closeLabel,
  });

  final String title;
  final String captureLabel;
  final String closeLabel;

  @override
  State<_LiveCameraCaptureDialog> createState() =>
      _LiveCameraCaptureDialogState();
}

class _LiveCameraCaptureDialogState extends State<_LiveCameraCaptureDialog> {
  late final String _viewType;
  bool _ready = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viewType = 'hosspi-live-cam-${identityHashCode(this)}';
  }

  @override
  void dispose() {
    unawaited(_stopSession(_viewType));
    super.dispose();
  }

  Future<void> _capture() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final Uint8List? bytes = await _snap(_viewType);
    if (!mounted) {
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: _preview(
                    viewType: _viewType,
                    onError: (Object error) {
                      if (mounted) {
                        setState(() => _error = error.toString());
                      }
                    },
                    onReady: () {
                      if (mounted) {
                        setState(() => _ready = true);
                      }
                    },
                  ),
                ),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(widget.closeLabel),
        ),
        FilledButton(
          onPressed: _ready && !_busy && _error == null ? _capture : null,
          child: Text(widget.captureLabel),
        ),
      ],
    );
  }
}

class _LiveBarcodeScannerDialog extends StatefulWidget {
  const _LiveBarcodeScannerDialog({
    required this.title,
    required this.body,
    required this.closeLabel,
    required this.unavailableBody,
  });

  final String title;
  final String body;
  final String closeLabel;
  final String unavailableBody;

  @override
  State<_LiveBarcodeScannerDialog> createState() =>
      _LiveBarcodeScannerDialogState();
}

class _LiveBarcodeScannerDialogState extends State<_LiveBarcodeScannerDialog> {
  late final String _viewType;
  Timer? _poll;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viewType = 'hosspi-live-scan-${identityHashCode(this)}';
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_stopSession(_viewType));
    super.dispose();
  }

  void _startPolling() {
    if (!liveBarcodeScannerSupported) {
      setState(() => _error = widget.unavailableBody);
      return;
    }
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      final String? code = await _detectOnce(_viewType);
      if (code == null || !mounted) {
        return;
      }
      _poll?.cancel();
      Navigator.of(context).pop(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.body, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: _preview(
                    viewType: _viewType,
                    onError: (Object error) {
                      if (mounted) {
                        setState(() => _error = error.toString());
                      }
                    },
                    onReady: () {
                      if (mounted) {
                        setState(() => _ready = true);
                        _startPolling();
                      }
                    },
                  ),
                ),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ] else if (!_ready) ...<Widget>[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.closeLabel),
        ),
      ],
    );
  }
}
