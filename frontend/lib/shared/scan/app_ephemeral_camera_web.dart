import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web supports a camera-preferring file input (`capture=environment`).
bool get ephemeralCameraCaptureSupported => true;

/// Opens a camera-preferring file input and returns in-memory bytes.
/// Never uploads to media APIs. Returns null when the user cancels.
Future<({Uint8List bytes, String fileName, String? mimeType})?>
pickEphemeralCameraImageBytes() async {
  final web.HTMLInputElement input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';
  input.setAttribute('capture', 'environment');

  final Completer<({Uint8List bytes, String fileName, String? mimeType})?>
  completer =
      Completer<({Uint8List bytes, String fileName, String? mimeType})?>();

  void finish(({Uint8List bytes, String fileName, String? mimeType})? value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  input.onchange = (web.Event _) {
    final web.FileList? files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final web.File file = files.item(0)!;
    final web.FileReader reader = web.FileReader();
    reader.onloadend = (web.Event _) {
      final JSAny? result = reader.result;
      if (result == null || !result.isA<JSArrayBuffer>()) {
        finish(null);
        return;
      }
      final ByteBuffer buffer = (result as JSArrayBuffer).toDart;
      finish((
        bytes: buffer.asUint8List(),
        fileName: file.name.isEmpty ? 'pack-photo.jpg' : file.name,
        mimeType: file.type.isEmpty ? 'image/jpeg' : file.type,
      ));
    }.toJS;
    reader.onerror = (web.Event _) {
      finish(null);
    }.toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  input.oncancel = (web.Event _) {
    finish(null);
  }.toJS;

  input.click();
  return completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () => null,
  );
}
