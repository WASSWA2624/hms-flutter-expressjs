import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'app_live_camera_stub.dart'
    if (dart.library.html) 'app_live_camera_web.dart'
    as live_camera;

/// True when the platform can open a MediaStream camera viewfinder.
bool get liveCameraCaptureSupported => live_camera.liveCameraCaptureSupported;

/// True when live barcode detection (BarcodeDetector + camera) is available.
bool get liveBarcodeScannerSupported =>
    live_camera.liveBarcodeScannerSupported;

/// Opens a live camera dialog and returns a JPEG frame, or null on cancel /
/// unsupported platforms. Frames stay in memory only.
Future<Uint8List?> captureLiveCameraFrame({
  required BuildContext context,
  required String title,
  required String captureLabel,
  required String closeLabel,
}) {
  return live_camera.captureLiveCameraFrame(
    context: context,
    title: title,
    captureLabel: captureLabel,
    closeLabel: closeLabel,
  );
}

/// Opens a live barcode scanner dialog. Returns the decoded code, or null on
/// cancel / unsupported platforms. Frames stay in memory only.
Future<String?> scanLiveBarcode({
  required BuildContext context,
  required String title,
  required String body,
  required String closeLabel,
  required String unavailableBody,
}) {
  return live_camera.scanLiveBarcode(
    context: context,
    title: title,
    body: body,
    closeLabel: closeLabel,
    unavailableBody: unavailableBody,
  );
}
