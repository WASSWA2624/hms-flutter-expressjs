import 'package:flutter/foundation.dart';

/// Candidate drug fields parsed from barcode + OCR / pack text.
/// Assistive only — staff must confirm before save.
@immutable
final class DrugPackFieldCandidates {
  const DrugPackFieldCandidates({
    this.brandName,
    this.genericName,
    this.form,
    this.strength,
    this.code,
    this.batchNumber,
    this.expiryDate,
    this.manufacturedAt,
    this.barcode,
    this.rawText,
  });

  final String? brandName;
  final String? genericName;
  final String? form;
  final String? strength;
  final String? code;
  final String? batchNumber;
  final DateTime? expiryDate;
  final DateTime? manufacturedAt;
  final String? barcode;
  final String? rawText;

  bool get hasAnyIdentityField =>
      (brandName ?? '').trim().isNotEmpty ||
      (genericName ?? '').trim().isNotEmpty ||
      (form ?? '').trim().isNotEmpty ||
      (strength ?? '').trim().isNotEmpty ||
      (code ?? '').trim().isNotEmpty ||
      (batchNumber ?? '').trim().isNotEmpty ||
      expiryDate != null ||
      manufacturedAt != null;

  factory DrugPackFieldCandidates.fromAiOutput(Map<String, Object?> json) {
    return DrugPackFieldCandidates(
      brandName: _aiString(json['brand_name']),
      genericName: _aiString(json['generic_name']),
      form: _aiString(json['form']),
      strength: _aiString(json['strength']),
      code: _aiString(json['code']),
      batchNumber: _aiString(json['batch_number']),
      expiryDate: DateTime.tryParse(_aiString(json['expiry_date']) ?? ''),
      manufacturedAt: DateTime.tryParse(
        _aiString(json['manufactured_at']) ?? '',
      ),
      barcode: _aiString(json['barcode']),
      rawText: _aiString(json['raw_text']),
    );
  }

  static String? _aiString(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final String lower = trimmed.toLowerCase();
    if (lower == 'null' ||
        lower == 'unknown' ||
        lower == 'n/a' ||
        lower == 'none' ||
        lower == '-') {
      return null;
    }
    return trimmed;
  }

  DrugPackFieldCandidates merge(DrugPackFieldCandidates other) {
    return DrugPackFieldCandidates(
      brandName: _prefer(brandName, other.brandName),
      genericName: _prefer(genericName, other.genericName),
      form: _prefer(form, other.form),
      strength: _prefer(strength, other.strength),
      code: _prefer(code, other.code),
      batchNumber: _prefer(batchNumber, other.batchNumber),
      expiryDate: expiryDate ?? other.expiryDate,
      manufacturedAt: manufacturedAt ?? other.manufacturedAt,
      barcode: _prefer(barcode, other.barcode),
      rawText: _prefer(rawText, other.rawText),
    );
  }

  static String? _prefer(String? primary, String? fallback) {
    final String left = (primary ?? '').trim();
    if (left.isNotEmpty) {
      return left;
    }
    final String right = (fallback ?? '').trim();
    return right.isEmpty ? null : right;
  }
}

/// Maps barcode + OCR text into drug create field candidates.
/// Free heuristics only — no paid drug-data subscription.
final class DrugPackFieldParser {
  const DrugPackFieldParser({
    this.knownForms = _defaultForms,
  });

  final List<String> knownForms;

  static const List<String> _defaultForms = <String>[
    'Chewable Tablet',
    'Tablet',
    'Capsule',
    'Syrup',
    'Suspension',
    'Injection',
    'Ampoule',
    'Vial',
    'Cream',
    'Ointment',
    'Gel',
    'Drops',
    'Inhaler',
    'Suppository',
    'Patch',
    'Powder',
    'Solution',
    'Lotion',
    'Spray',
  ];

  static final RegExp _strengthPattern = RegExp(
    r'\b(\d+(?:[.,]\d+)?\s?(?:mg|mcg|µg|g|ml|mL|%|IU|units?))\b',
    caseSensitive: false,
  );
  static final RegExp _batchPattern = RegExp(
    r'\b(?:batch(?:\s*(?:no\.?|number|#))?|lot(?:\s*(?:no\.?|number|#))?|b\.?\s*no\.?)[:\s#-]*([A-Za-z0-9][A-Za-z0-9\-\/]{1,24})\b',
    caseSensitive: false,
  );
  static final RegExp _expiryPattern = RegExp(
    r'\b(?:exp(?:iry)?|exp\.?\s*date|use\s*by|best\s*before)[:\s#-]*'
    r'(\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}|\d{1,2}[\/\-.]\d{4}|[A-Za-z]{3,9}\s+\d{4}|\d{4}[\/\-.]\d{1,2})\b',
    caseSensitive: false,
  );
  static final RegExp _mfgPattern = RegExp(
    r'\b(?:mfg|mfd|manufactur(?:ed|ing)?(?:\s*date)?|manuf)[:\s#-]*'
    r'(\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}|\d{1,2}[\/\-.]\d{4}|[A-Za-z]{3,9}\s+\d{4}|\d{4}[\/\-.]\d{1,2})\b',
    caseSensitive: false,
  );
  static final RegExp _genericHint = RegExp(
    r'\b(?:generic(?:\s*name)?|active\s*ingredient|contains)[:\s]+([A-Za-z][A-Za-z0-9\s\-]{2,60})',
    caseSensitive: false,
  );
  static final RegExp _brandHint = RegExp(
    r'\b(?:brand(?:\s*name)?|trade\s*name)[:\s]+([A-Za-z][A-Za-z0-9\s\-]{2,60})',
    caseSensitive: false,
  );
  static final RegExp _codeHint = RegExp(
    r'\b(?:ndc|sku|code|item\s*#?)[:\s#-]*([A-Za-z0-9][A-Za-z0-9\-]{2,30})\b',
    caseSensitive: false,
  );
  static final RegExp _gtin = RegExp(r'\b(\d{8}|\d{12,14})\b');

  /// e.g. "Paracetamol Tablets B.P. 500mg" / "Amoxicillin Capsules USP"
  /// Uses spaces/tabs only (not newlines) so a trailing word on one line cannot
  /// pair with "Tablet" on the next line.
  static final RegExp _drugFormLine = RegExp(
    r'\b([A-Za-z][A-Za-z][A-Za-z\-]{1,40})[ \t]+'
    r'(?:chewable[ \t]+)?'
    r'(tabs?|tablets?|caps?|capsules?|syrup|suspension|injection|cream|ointment|gel|drops|powder|solution|lotion|spray|inhaler|patch|suppository)'
    r'(?:[ \t]*(?:b\.?[ \t]*p\.?|u\.?[ \t]*s\.?[ \t]*p\.?|bp|usp))?'
    r'(?:[ \t]+(\d+(?:[.,]\d+)?[ \t]?(?:mg|mcg|µg|g|ml|mL|%|IU|units?)))?',
    caseSensitive: false,
  );

  /// Short trade/brand marks often printed in ALL CAPS.
  static final RegExp _allCapsBrand = RegExp(r'^[A-Z][A-Z0-9]{2,14}$');

  DrugPackFieldCandidates parse({
    String? barcode,
    String? ocrText,
    List<String> ocrLines = const <String>[],
  }) {
    final String text = (ocrText ?? '').trim();
    final List<String> lines = ocrLines.isNotEmpty
        ? ocrLines
        : text
              .split(RegExp(r'\r?\n'))
              .map((String line) => line.trim())
              .where((String line) => line.isNotEmpty)
              .toList(growable: false);

    final String? normalizedBarcode = _emptyToNull(barcode) ??
        _firstMatch(_gtin, text) ??
        _firstMatchAcross(_gtin, lines);

    final String? form = _matchForm(text, lines);
    String? strength =
        _firstMatch(_strengthPattern, text) ??
        _firstMatchAcross(_strengthPattern, lines);
    final String? batchNumber =
        _firstMatch(_batchPattern, text) ??
        _firstMatchAcross(_batchPattern, lines);
    final DateTime? expiryDate = _parseDate(
      _firstMatch(_expiryPattern, text) ??
          _firstMatchAcross(_expiryPattern, lines),
    );
    final DateTime? manufacturedAt = _parseDate(
      _firstMatch(_mfgPattern, text) ?? _firstMatchAcross(_mfgPattern, lines),
    );
    final String? hintedGeneric =
        _cleanName(_firstMatch(_genericHint, text)) ??
        _cleanName(_firstMatchAcross(_genericHint, lines));
    final String? hintedBrand =
        _cleanName(_firstMatch(_brandHint, text)) ??
        _cleanName(_firstMatchAcross(_brandHint, lines));
    final String? code =
        _emptyToNull(normalizedBarcode) ??
        _firstMatch(_codeHint, text) ??
        _firstMatchAcross(_codeHint, lines);

    String? brandName = hintedBrand;
    String? genericName = hintedGeneric;

    final ({String? generic, String? strengthFromLine}) fromFormLine =
        _extractFromDrugFormLine(text, lines);
    genericName ??= fromFormLine.generic;
    strength ??= fromFormLine.strengthFromLine;
    brandName ??= _extractAllCapsBrand(lines, genericName: genericName);

    if (brandName == null || genericName == null) {
      final List<String> nameLines = lines
          .where((String line) => !_looksLikeMeta(line))
          .where((String line) => !_looksLikeGarbageName(line))
          .take(6)
          .toList(growable: false);
      if (brandName == null && nameLines.isNotEmpty) {
        brandName = _cleanName(nameLines.first);
      }
      if (genericName == null && nameLines.length > 1) {
        genericName = _cleanName(nameLines[1]);
      } else if (genericName == null &&
          brandName != null &&
          strength != null &&
          brandName.toLowerCase().contains(strength.toLowerCase())) {
        // Keep brand; leave generic empty for staff.
      }
    }

    brandName = _rejectGarbageName(brandName);
    genericName = _rejectGarbageName(genericName);

    // When barcode is the only signal, still surface it as code.
    return DrugPackFieldCandidates(
      brandName: brandName,
      genericName: genericName,
      form: form,
      strength: strength == null
          ? null
          : strength.replaceAll(',', '.').replaceAllMapped(
              RegExp(r'(\d+(?:\.\d+)?)\s*(mg|mcg|µg|g|ml|mL|%|IU|units?)', caseSensitive: false),
              (Match m) => '${m.group(1)} ${m.group(2)}',
            ),
      code: code,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      manufacturedAt: manufacturedAt,
      barcode: normalizedBarcode,
      rawText: text.isEmpty ? null : text,
    );
  }

  ({String? generic, String? strengthFromLine}) _extractFromDrugFormLine(
    String text,
    List<String> lines,
  ) {
    Match? match = _drugFormLine.firstMatch(text);
    if (match == null) {
      for (final String line in lines) {
        match = _drugFormLine.firstMatch(line);
        if (match != null) {
          break;
        }
      }
    }
    if (match == null) {
      return (generic: null, strengthFromLine: null);
    }
    return (
      generic: _cleanName(match.group(1)),
      strengthFromLine: match.group(3)?.trim(),
    );
  }

  String? _extractAllCapsBrand(
    List<String> lines, {
    String? genericName,
  }) {
    for (final String line in lines) {
      final String token = line.trim();
      if (!_allCapsBrand.hasMatch(token)) {
        continue;
      }
      if (_looksLikeMeta(token) || _looksLikeGarbageName(token)) {
        continue;
      }
      final String lower = token.toLowerCase();
      if (genericName != null &&
          lower == genericName.trim().toLowerCase()) {
        continue;
      }
      if (knownForms.any((String form) => form.toLowerCase() == lower)) {
        continue;
      }
      return token;
    }
    return null;
  }

  static String? _rejectGarbageName(String? value) {
    if (value == null) {
      return null;
    }
    return _looksLikeGarbageName(value) ? null : value;
  }

  static bool _looksLikeGarbageName(String value) {
    final String trimmed = value.trim();
    if (trimmed.length < 2) {
      return true;
    }
    final int letters = RegExp(r'[A-Za-z]').allMatches(trimmed).length;
    final int weird =
        RegExp(r'''[^A-Za-z0-9\s\-\.']''').allMatches(trimmed).length;
    if (letters < 3) {
      return true;
    }
    if (weird > (letters / 3).ceil()) {
      return true;
    }
    if (trimmed.contains(']') ||
        trimmed.contains('[') ||
        trimmed.contains('|') ||
        trimmed.contains('{') ||
        trimmed.contains('}') ||
        trimmed.contains('<') ||
        trimmed.contains('>')) {
      return true;
    }
    final int quoteCount = "'".allMatches(trimmed).length +
        '"'.allMatches(trimmed).length +
        '`'.allMatches(trimmed).length;
    if (quoteCount >= 2) {
      return true;
    }
    if (RegExp(r'\d{5,}').hasMatch(trimmed)) {
      return true;
    }
    // Digits embedded in a multi-token "name" that is not a strength phrase.
    if (RegExp(r'\d').hasMatch(trimmed) &&
        !RegExp(
          r'\b\d+(?:[.,]\d+)?\s?(?:mg|mcg|µg|g|ml|mL|%|IU|units?)\b',
          caseSensitive: false,
        ).hasMatch(trimmed) &&
        trimmed.split(RegExp(r'\s+')).length >= 2) {
      return true;
    }
    // OCR noise often mixes digits into letter soup without spaces.
    if (RegExp(r'[A-Za-z]+\d+[A-Za-z]+\d+').hasMatch(trimmed) &&
        !RegExp(r'\b\d+\s?(?:mg|mcg|ml)\b', caseSensitive: false)
            .hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  String? _matchForm(String text, List<String> lines) {
    final String haystack = '$text\n${lines.join('\n')}'.toLowerCase();
    for (final String form in knownForms) {
      if (haystack.contains(form.toLowerCase())) {
        return form;
      }
    }
    // Common abbreviations
    if (RegExp(r'\b(?:tabs?|tablets?)\b', caseSensitive: false).hasMatch(haystack)) {
      return 'Tablet';
    }
    if (RegExp(r'\b(?:caps?|capsules?)\b', caseSensitive: false).hasMatch(haystack)) {
      return 'Capsule';
    }
    if (RegExp(r'\b(?:inj|injection)\b', caseSensitive: false).hasMatch(haystack)) {
      return 'Injection';
    }
    return null;
  }

  bool _looksLikeMeta(String line) {
    final String lower = line.toLowerCase();
    if (_strengthPattern.hasMatch(line)) {
      return true;
    }
    if (_batchPattern.hasMatch(line) ||
        _expiryPattern.hasMatch(line) ||
        _mfgPattern.hasMatch(line)) {
      return true;
    }
    if (_gtin.hasMatch(line) && RegExp(r'^\d+$').hasMatch(line.trim())) {
      return true;
    }
    if (knownForms.any((String form) => form.toLowerCase() == lower.trim())) {
      return true;
    }
    if (RegExp(r'^(?:tabs?|caps?|inj)$', caseSensitive: false)
        .hasMatch(lower.trim())) {
      return true;
    }
    if (lower.contains('manufacturer') ||
        lower.contains('keep out') ||
        lower.contains('store ') ||
        lower.contains('warning')) {
      return true;
    }
    return false;
  }

  static String? _firstMatch(RegExp pattern, String text) {
    if (text.trim().isEmpty) {
      return null;
    }
    final Match? match = pattern.firstMatch(text);
    if (match == null) {
      return null;
    }
    return match.groupCount >= 1 ? match.group(1) : match.group(0);
  }

  static String? _firstMatchAcross(RegExp pattern, List<String> lines) {
    for (final String line in lines) {
      final String? value = _firstMatch(pattern, line);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static String? _cleanName(String? value) {
    if (value == null) {
      return null;
    }
    String cleaned = value.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[|:]+$'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    if (cleaned.length < 2 || cleaned.length > 80) {
      return null;
    }
    return cleaned;
  }

  static String? _emptyToNull(String? value) {
    final String trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final String value = raw.trim();

    final Match? yyyyMm = RegExp(r'^(\d{4})[\/\-.](\d{1,2})$').firstMatch(value);
    if (yyyyMm != null) {
      final int year = int.parse(yyyyMm.group(1)!);
      final int month = int.parse(yyyyMm.group(2)!);
      return DateTime(year, month, 1);
    }

    final Match? mmYyyy = RegExp(r'^(\d{1,2})[\/\-.](\d{4})$').firstMatch(value);
    if (mmYyyy != null) {
      final int month = int.parse(mmYyyy.group(1)!);
      final int year = int.parse(mmYyyy.group(2)!);
      if (month >= 1 && month <= 12) {
        return DateTime(year, month, 1);
      }
    }

    final Match? dmy = RegExp(
      r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$',
    ).firstMatch(value);
    if (dmy != null) {
      final int day = int.parse(dmy.group(1)!);
      final int month = int.parse(dmy.group(2)!);
      int year = int.parse(dmy.group(3)!);
      if (year < 100) {
        year += 2000;
      }
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    final Match? monYear = RegExp(
      r'^([A-Za-z]{3,9})\s+(\d{4})$',
    ).firstMatch(value);
    if (monYear != null) {
      final int? month = _monthNumber(monYear.group(1)!);
      final int year = int.parse(monYear.group(2)!);
      if (month != null) {
        return DateTime(year, month, 1);
      }
    }

    return DateTime.tryParse(value);
  }

  static int? _monthNumber(String token) {
    const Map<String, int> months = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    return months[token.trim().toLowerCase()];
  }
}
