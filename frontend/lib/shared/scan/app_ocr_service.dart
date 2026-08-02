import 'dart:typed_data';

import 'app_ocr_service_stub.dart'
    if (dart.library.html) 'app_ocr_service_web.dart'
    as ocr_impl;

/// OCR result over ephemeral image bytes. Never persisted by this layer.
final class AppOcrResult {
  const AppOcrResult({
    required this.text,
    this.lines = const <String>[],
  });

  final String text;
  final List<String> lines;

  bool get hasText => text.trim().isNotEmpty;
}

/// Free OCR over in-memory bytes (web: Tesseract.js WASM; else graceful empty).
abstract class AppOcrService {
  Future<AppOcrResult> recognize(
    Uint8List bytes, {
    String? mimeType,
    String language = 'eng',
  });
}

AppOcrService createAppOcrService() => ocr_impl.createPlatformOcrService();

/// No-op OCR used in tests or when the platform engine is unavailable.
final class AppNoOpOcrService implements AppOcrService {
  const AppNoOpOcrService();

  @override
  Future<AppOcrResult> recognize(
    Uint8List bytes, {
    String? mimeType,
    String language = 'eng',
  }) async {
    return const AppOcrResult(text: '');
  }
}

/// Test/injected OCR that returns a fixed string.
final class AppFixedOcrService implements AppOcrService {
  const AppFixedOcrService(this.text);

  final String text;

  @override
  Future<AppOcrResult> recognize(
    Uint8List bytes, {
    String? mimeType,
    String language = 'eng',
  }) async {
    final List<String> lines = text
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    return AppOcrResult(text: text, lines: lines);
  }
}
