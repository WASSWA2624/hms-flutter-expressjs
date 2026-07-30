/// Converts lab quantity values between common equivalent units.
///
/// Supports mass/volume aliases such as `g/dL` ↔ `g/L` (×10). Returns `null`
/// when units are unknown, identical after normalization, or not convertible.
num? convertLabQuantity(
  num value, {
  required String? fromUnit,
  required String? toUnit,
}) {
  final String? from = normalizeLabUnitToken(fromUnit);
  final String? to = normalizeLabUnitToken(toUnit);
  if (from == null || to == null || from == to) {
    return from == to && from != null ? value : null;
  }

  final num? fromToBase = _factorToBasePerLiter(from);
  final num? toToBase = _factorToBasePerLiter(to);
  if (fromToBase == null || toToBase == null) {
    return null;
  }
  return value * fromToBase / toToBase;
}

/// Formats a converted bound for display (strips trailing zeros).
String formatLabConvertedBound(num value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  final String fixed = value.toStringAsFixed(6);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Normalizes unit strings / UCUM-ish tokens for comparison.
String? normalizeLabUnitToken(String? unit) {
  final String trimmed = (unit ?? '').trim();
  if (trimmed.isEmpty) {
    return null;
  }

  // Prefer the trailing token when values look like "Grams per liter | g/L".
  String candidate = trimmed;
  final int pipeIndex = candidate.lastIndexOf('|');
  if (pipeIndex >= 0 && pipeIndex < candidate.length - 1) {
    final String afterPipe = candidate.substring(pipeIndex + 1).trim();
    if (afterPipe.isNotEmpty) {
      candidate = afterPipe;
    }
  }

  String normalized = candidate
      .replaceAll('µ', 'u')
      .replaceAll('μ', 'u')
      .replaceAll(' ', '')
      .toLowerCase();

  normalized = normalized
      .replaceAll('gramsperliter', 'g/l')
      .replaceAll('gramsperdeciliter', 'g/dl')
      .replaceAll('milligramsperliter', 'mg/l')
      .replaceAll('milligramsperdeciliter', 'mg/dl')
      .replaceAll('microgramsperliter', 'ug/l')
      .replaceAll('microgramsperdeciliter', 'ug/dl')
      .replaceAll('nanogramspermilliliter', 'ng/ml');

  // UCUM-style codes often use `.` as a separator (`g.dL-1`).
  normalized = normalized
      .replaceAll(RegExp(r'g\.?dl-?1'), 'g/dl')
      .replaceAll(RegExp(r'g\.?l-?1'), 'g/l')
      .replaceAll(RegExp(r'mg\.?dl-?1'), 'mg/dl')
      .replaceAll(RegExp(r'mg\.?l-?1'), 'mg/l')
      .replaceAll(RegExp(r'ug\.?dl-?1'), 'ug/dl')
      .replaceAll(RegExp(r'ug\.?l-?1'), 'ug/l')
      .replaceAll(RegExp(r'ng\.?ml-?1'), 'ng/ml');

  return switch (normalized) {
    'g/dl' || 'gm/dl' || 'gram/dl' || 'grams/dl' => 'g/dl',
    'g/l' || 'gm/l' || 'gram/l' || 'grams/l' => 'g/l',
    'mg/dl' || 'milligram/dl' || 'milligrams/dl' => 'mg/dl',
    'mg/l' || 'milligram/l' || 'milligrams/l' => 'mg/l',
    'ug/dl' || 'mcg/dl' => 'ug/dl',
    'ug/l' || 'mcg/l' => 'ug/l',
    'ng/ml' => 'ng/ml', // ≡ µg/L in factor table
    'ng/l' => 'ng/l',
    'ug/ml' || 'mcg/ml' => 'ug/ml',
    '%' || 'percent' || 'pct' => '%',
    'x10^12/l' || '10^12/l' || '10e12/l' => 'x10^12/l',
    'x10^9/l' || '10^9/l' || '10e9/l' => 'x10^9/l',
    'fl' => 'fl',
    'pg' => 'pg',
    _ => normalized,
  };
}

bool labUnitsAreCompatible(String? left, String? right) {
  final String? a = normalizeLabUnitToken(left);
  final String? b = normalizeLabUnitToken(right);
  if (a == null || b == null) {
    return false;
  }
  if (a == b) {
    return true;
  }
  return _factorToBasePerLiter(a) != null && _factorToBasePerLiter(b) != null;
}

/// Factor that converts [unit] into a shared "per liter" mass base (mg/L-ish).
///
/// Relative scale only — used to convert between compatible mass/volume units.
num? _factorToBasePerLiter(String unit) {
  return switch (unit) {
    'g/l' => 1000,
    'g/dl' => 10000, // 1 g/dL = 10 g/L = 10000 mg/L
    'mg/l' => 1,
    'mg/dl' => 10,
    'ug/l' || 'ng/ml' => 0.001,
    'ug/dl' => 0.01,
    'ng/l' => 0.000001,
    'ug/ml' => 1, // 1 µg/mL = 1 mg/L
    _ => null,
  };
}

/// Converts a numeric string bound; returns the original text when not numeric
/// or when conversion is impossible.
String? convertLabBoundText(
  String? bound, {
  required String? fromUnit,
  required String? toUnit,
}) {
  final String? trimmed = bound?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return bound;
  }
  final num? value = num.tryParse(trimmed);
  if (value == null) {
    return bound;
  }
  final String? from = normalizeLabUnitToken(fromUnit);
  final String? to = normalizeLabUnitToken(toUnit);
  if (from == null || to == null || from == to) {
    return trimmed;
  }
  final num? converted = convertLabQuantity(
    value,
    fromUnit: from,
    toUnit: to,
  );
  if (converted == null) {
    return null;
  }
  return formatLabConvertedBound(converted);
}
