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
