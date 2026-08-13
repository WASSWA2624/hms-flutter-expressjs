import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Rotates and/or flips encoded image bytes. Returns PNG bytes, or the
/// original input when decode fails.
Uint8List transformAppImageBytes(
  Uint8List bytes, {
  int quarterTurns = 0,
  bool flipHorizontal = false,
  bool flipVertical = false,
}) {
  final int turns = quarterTurns % 4;
  if (turns == 0 && !flipHorizontal && !flipVertical) {
    return bytes;
  }

  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }

  img.Image next = decoded;
  if (turns != 0) {
    next = img.copyRotate(next, angle: turns * 90);
  }
  if (flipHorizontal) {
    next = img.flipHorizontal(next);
  }
  if (flipVertical) {
    next = img.flipVertical(next);
  }
  return Uint8List.fromList(img.encodePng(next));
}

/// Downscales and JPEG-encodes bytes for a vision AI request.
/// Returns the original bytes when decode fails.
Uint8List encodeAppImageForAi(
  Uint8List bytes, {
  int maxEdge = 768,
  int quality = 70,
}) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }

  img.Image next = decoded;
  if (maxEdge > 0 && (next.width > maxEdge || next.height > maxEdge)) {
    if (next.width >= next.height) {
      next = img.copyResize(next, width: maxEdge);
    } else {
      next = img.copyResize(next, height: maxEdge);
    }
  }
  return Uint8List.fromList(img.encodeJpg(next, quality: quality.clamp(40, 95)));
}
