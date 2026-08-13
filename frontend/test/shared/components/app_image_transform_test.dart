import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_image_transform.dart';
import 'package:image/image.dart' as img;

void main() {
  group('transformAppImageBytes', () {
    Uint8List buildSample() {
      final img.Image source = img.Image(width: 4, height: 2);
      for (int x = 0; x < 4; x++) {
        source.setPixelRgb(x, 0, 255, 0, 0);
        source.setPixelRgb(x, 1, 0, 255, 0);
      }
      return Uint8List.fromList(img.encodePng(source));
    }

    test('rotates 90 degrees clockwise', () {
      final Uint8List rotated = transformAppImageBytes(
        buildSample(),
        quarterTurns: 1,
      );
      final img.Image? decoded = img.decodeImage(rotated);
      expect(decoded, isNotNull);
      expect(decoded!.width, 2);
      expect(decoded.height, 4);
    });

    test('flip horizontal returns valid png', () {
      final Uint8List flipped = transformAppImageBytes(
        buildSample(),
        flipHorizontal: true,
      );
      expect(img.decodeImage(flipped), isNotNull);
    });
  });

  test('encodeAppImageForAi downscales to jpeg', () {
    final img.Image source = img.Image(width: 1200, height: 800);
    for (int x = 0; x < 1200; x++) {
      source.setPixelRgb(x, 0, 255, 0, 0);
    }
    final Uint8List png = Uint8List.fromList(img.encodePng(source));
    final Uint8List encoded = encodeAppImageForAi(png, maxEdge: 320, quality: 60);
    final img.Image? decoded = img.decodeImage(encoded);
    expect(decoded, isNotNull);
    expect(decoded!.width, 320);
    expect(decoded.height, 213);
  });
}
