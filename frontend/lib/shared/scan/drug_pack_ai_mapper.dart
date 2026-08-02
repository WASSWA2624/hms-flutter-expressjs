import 'package:hosspi_hms/shared/scan/drug_pack_field_parser.dart';

/// Result of an AI (or local structured-assist) map into drug candidates.
final class DrugPackAiMapResult {
  const DrugPackAiMapResult({
    this.candidates,
    this.unavailable = false,
    this.message,
  });

  const DrugPackAiMapResult.unavailable({String? message})
    : candidates = null,
      unavailable = true,
      message = message;

  final DrugPackFieldCandidates? candidates;
  final bool unavailable;
  final String? message;

  bool get hasCandidates =>
      candidates != null && candidates!.hasAnyIdentityField;
}

/// Maps pack OCR / raw text into structured drug create candidates.
/// Implementations must not persist pack images.
abstract class DrugPackAiMapper {
  Future<DrugPackAiMapResult> map({
    required String rawText,
    String? barcode,
    List<String> ocrLines = const <String>[],
  });
}

/// Always unavailable — used when remote AI is not configured.
final class DrugPackUnavailableAiMapper implements DrugPackAiMapper {
  const DrugPackUnavailableAiMapper({this.message});

  final String? message;

  @override
  Future<DrugPackAiMapResult> map({
    required String rawText,
    String? barcode,
    List<String> ocrLines = const <String>[],
  }) async {
    return DrugPackAiMapResult.unavailable(message: message);
  }
}

/// Local structured assist (no network): cleans OCR noise, then runs the
/// shared [DrugPackFieldParser]. Used as the default AI path until a remote
/// endpoint is configured.
final class DrugPackLocalAiMapper implements DrugPackAiMapper {
  const DrugPackLocalAiMapper({
    this.parser = const DrugPackFieldParser(),
  });

  final DrugPackFieldParser parser;

  static final RegExp _mostlyGarbage = RegExp(
    r'^[^A-Za-z0-9]*$|[\|\\\/\*\#\@\~\^]{2,}|"\d|"[^\w]|siege|owerase|'
    r'[A-Za-z]+\d+[A-Za-z]+\d+|[\W_]{3,}',
    caseSensitive: false,
  );

  @override
  Future<DrugPackAiMapResult> map({
    required String rawText,
    String? barcode,
    List<String> ocrLines = const <String>[],
  }) async {
    final List<String> sourceLines = ocrLines.isNotEmpty
        ? ocrLines
        : rawText
              .split(RegExp(r'\r?\n'))
              .map((String line) => line.trim())
              .where((String line) => line.isNotEmpty)
              .toList(growable: false);

    final List<String> cleaned = sourceLines
        .map(_normalizeLine)
        .where((String line) => line.isNotEmpty)
        .where((String line) => !_mostlyGarbage.hasMatch(line))
        .where((String line) => RegExp(r'[A-Za-z]').hasMatch(line))
        .where((String line) => !_isLowSignalLine(line))
        .toList(growable: false);

    final String cleanedText = cleaned.isEmpty
        ? rawText.trim()
        : cleaned.join('\n');

    final DrugPackFieldCandidates candidates = parser.parse(
      barcode: barcode,
      ocrText: cleanedText,
      ocrLines: cleaned,
    );

    if (!candidates.hasAnyIdentityField) {
      return const DrugPackAiMapResult(
        unavailable: false,
        candidates: null,
      );
    }
    return DrugPackAiMapResult(candidates: candidates);
  }

  static String _normalizeLine(String line) {
    return line
        .replaceAll(RegExp(r'[^\S\r\n]+'), ' ')
        .replaceAll(RegExp(r'[“”"]+'), '"')
        .replaceAll(RegExp(r'[|]{2,}'), ' ')
        .trim();
  }

  static bool _isLowSignalLine(String line) {
    final int letters = RegExp(r'[A-Za-z]').allMatches(line).length;
    final int digits = RegExp(r'\d').allMatches(line).length;
    final int weird =
        RegExp(r'''[^A-Za-z0-9\s\-\.:/#']''').allMatches(line).length;
    if (letters < 3 && !RegExp(r'\d+\s?(?:mg|mcg|ml)\b', caseSensitive: false)
        .hasMatch(line)) {
      return true;
    }
    if (weird > letters && letters < 8) {
      return true;
    }
    // Pure digit soup that is not a strength / GTIN-looking run.
    if (letters == 0 && digits > 0 && digits < 8) {
      return true;
    }
    return false;
  }
}

DrugPackAiMapper createDefaultDrugPackAiMapper() =>
    const DrugPackLocalAiMapper();
