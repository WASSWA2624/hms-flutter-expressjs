import 'dart:typed_data';

/// Non-web platforms have no dedicated capture input; callers fall back to
/// the shared file picker.
bool get ephemeralCameraCaptureSupported => false;

Future<({Uint8List bytes, String fileName, String? mimeType})?>
pickEphemeralCameraImageBytes() async {
  return null;
}
