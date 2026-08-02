import 'dart:typed_data';

/// Non-web: no MediaStream camera UI.
bool get liveCameraCaptureSupported => false;

bool get liveBarcodeScannerSupported => false;

Future<Uint8List?> captureLiveCameraFrame({
  required dynamic context,
  required String title,
  required String captureLabel,
  required String closeLabel,
}) async {
  return null;
}

Future<String?> scanLiveBarcode({
  required dynamic context,
  required String title,
  required String body,
  required String closeLabel,
  required String unavailableBody,
}) async {
  return null;
}
