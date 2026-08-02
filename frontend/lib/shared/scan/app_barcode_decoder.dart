import 'dart:typed_data';

/// Normalized barcode capture result (camera, upload decode, or typed entry).
final class AppBarcodeCaptureResult {
  const AppBarcodeCaptureResult({
    required this.code,
    this.format,
    this.source = AppBarcodeCaptureSource.manual,
  });

  final String code;
  final String? format;
  final AppBarcodeCaptureSource source;
}

enum AppBarcodeCaptureSource { manual, imageDecode, camera }

/// Decodes a barcode from in-memory image bytes when possible.
abstract class AppBarcodeDecoder {
  Future<AppBarcodeCaptureResult?> decodeFromImage(
    Uint8List bytes, {
    String? mimeType,
  });
}

/// Heuristic decoder: extracts EAN/UPC/GTIN-like digit runs from raw bytes
/// when OCR or pack text already embeds the code. Pure-Dart; no paid APIs.
final class AppHeuristicBarcodeDecoder implements AppBarcodeDecoder {
  const AppHeuristicBarcodeDecoder();

  static final RegExp _digitRun = RegExp(r'\b(\d{8}|\d{12,14})\b');

  @override
  Future<AppBarcodeCaptureResult?> decodeFromImage(
    Uint8List bytes, {
    String? mimeType,
  }) async {
    // Image binary decode of symbologies needs a barcode engine; without one,
    // attempt ASCII extraction from embedded text chunks (rare but free).
    final String asLatin = String.fromCharCodes(
      bytes.where((int b) => b >= 32 && b < 127),
    );
    final Match? match = _digitRun.firstMatch(asLatin);
    if (match == null) {
      return null;
    }
    return AppBarcodeCaptureResult(
      code: match.group(1)!,
      format: 'digit_run',
      source: AppBarcodeCaptureSource.imageDecode,
    );
  }

  /// Decode from already-recognized text (OCR or pasted pack text).
  AppBarcodeCaptureResult? decodeFromText(String text) {
    final Match? match = _digitRun.firstMatch(text);
    if (match == null) {
      return null;
    }
    return AppBarcodeCaptureResult(
      code: match.group(1)!,
      format: 'digit_run',
      source: AppBarcodeCaptureSource.imageDecode,
    );
  }
}
