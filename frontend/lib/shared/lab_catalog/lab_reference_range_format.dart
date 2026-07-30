import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';

/// Canonical lab reference-range display text.
///
/// Matches backend `buildLabReferenceRangeRowSummary`:
/// `label | Method … | gender | age | <bounds|text> <unit>`
/// without a mid-string `Unit …` fragment.
String? formatLabReferenceRangeDisplay({
  String? label,
  String? unit,
  String? method,
  String? gender,
  num? ageMinValue,
  String? ageMinUnit,
  num? ageMaxValue,
  String? ageMaxUnit,
  String? normalMinValue,
  String? normalMaxValue,
  String? referenceText,
  String? summary,
}) {
  final String? trimmedUnit = _trimOrNull(unit);
  final String? trimmedText = _trimOrNull(referenceText);
  final String? bounds = formatLabReferenceRangeBounds(
    normalMinValue: normalMinValue,
    normalMaxValue: normalMaxValue,
  );
  final bool hasStructuredRange =
      trimmedText != null || (bounds != null && bounds.isNotEmpty);

  if (hasStructuredRange) {
    final List<String> parts = <String>[];

    final String? trimmedLabel = _trimOrNull(label);
    if (trimmedLabel != null) {
      parts.add(trimmedLabel);
    }

    final String? trimmedMethod = _trimOrNull(method);
    if (trimmedMethod != null) {
      parts.add('Method $trimmedMethod');
    }

    final String? trimmedGender = _trimOrNull(gender);
    if (trimmedGender != null) {
      parts.add(trimmedGender);
    }

    final String? ageSummary = formatLabReferenceRangeAgeSummary(
      ageMinValue: ageMinValue,
      ageMinUnit: ageMinUnit,
      ageMaxValue: ageMaxValue,
      ageMaxUnit: ageMaxUnit,
    );
    if (ageSummary != null) {
      parts.add(ageSummary);
    }

    final String rangeCore = trimmedText ?? bounds!;
    parts.add(_appendUnitIfNeeded(rangeCore, trimmedUnit));
    return parts.join(' | ');
  }

  final String? trimmedSummary = _trimOrNull(summary);
  if (trimmedSummary != null) {
    return rewriteLegacyLabReferenceRangeUnitSummary(trimmedSummary);
  }

  final String? trimmedLabel = _trimOrNull(label);
  if (trimmedLabel != null) {
    return trimmedLabel;
  }
  return trimmedUnit;
}

String? formatLabReferenceRange(LabReferenceRange range) {
  return formatLabReferenceRangeDisplay(
    label: range.label,
    unit: range.unit,
    method: range.method,
    gender: range.gender,
    ageMinValue: range.ageMinValue,
    ageMinUnit: range.ageMinUnit,
    ageMaxValue: range.ageMaxValue,
    ageMaxUnit: range.ageMaxUnit,
    normalMinValue: range.normalMinValue,
    normalMaxValue: range.normalMaxValue,
    referenceText: range.referenceText,
    summary: range.summary,
  );
}

/// Formats an applied-range snapshot map from API payloads.
String? formatLabReferenceRangeFromMap(Map<String, Object?>? applied) {
  if (applied == null || applied.isEmpty) {
    return null;
  }
  final String? summary = applied['summary']?.toString();
  String? unit = applied['unit']?.toString();
  if (_trimOrNull(unit) == null && summary != null) {
    unit = _extractLegacyUnitFragment(summary);
  }
  return formatLabReferenceRangeDisplay(
    label: applied['label']?.toString(),
    unit: unit,
    method: applied['method']?.toString(),
    gender: applied['gender']?.toString(),
    ageMinValue: _asNum(applied['age_min_value']),
    ageMinUnit: applied['age_min_unit']?.toString(),
    ageMaxValue: _asNum(applied['age_max_value']),
    ageMaxUnit: applied['age_max_unit']?.toString(),
    normalMinValue: applied['normal_min_value']?.toString(),
    normalMaxValue: applied['normal_max_value']?.toString(),
    referenceText: applied['reference_text']?.toString(),
    summary: summary,
  );
}

String? formatLabReferenceRangeBounds({
  String? normalMinValue,
  String? normalMaxValue,
}) {
  final String? min = _trimOrNull(normalMinValue);
  final String? max = _trimOrNull(normalMaxValue);
  if (min == null && max == null) {
    return null;
  }
  if (min != null && max != null) {
    return '$min - $max';
  }
  if (min != null) {
    return '≥ $min';
  }
  return '≤ $max';
}

String? formatLabReferenceRangeAgeSummary({
  num? ageMinValue,
  String? ageMinUnit,
  num? ageMaxValue,
  String? ageMaxUnit,
}) {
  final String? ageMin = _formatReferenceAge(ageMinValue, ageMinUnit);
  final String? ageMax = _formatReferenceAge(ageMaxValue, ageMaxUnit);
  if (ageMin != null && ageMax != null) {
    return '$ageMin to $ageMax';
  }
  if (ageMin != null) {
    return '$ageMin+';
  }
  if (ageMax != null) {
    return 'up to $ageMax';
  }
  return null;
}

/// Moves legacy `Unit g/dL` fragments after the numeric range and drops "Unit".
String rewriteLegacyLabReferenceRangeUnitSummary(String summary) {
  final List<String> fragments = summary
      .split(' | ')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList();
  String? unit;
  final List<String> kept = <String>[];
  for (final String fragment in fragments) {
    final String lower = fragment.toLowerCase();
    if (lower.startsWith('unit ')) {
      final String extracted = fragment.substring(5).trim();
      if (extracted.isNotEmpty) {
        unit = extracted;
      }
      continue;
    }
    kept.add(fragment);
  }
  if (unit == null || unit.isEmpty || kept.isEmpty) {
    return kept.isEmpty ? summary : kept.join(' | ');
  }
  final String last = kept.last;
  if (!last.contains(unit)) {
    kept[kept.length - 1] = '$last $unit';
  }
  return kept.join(' | ');
}

String? _extractLegacyUnitFragment(String summary) {
  for (final String fragment in summary.split(' | ')) {
    final String trimmed = fragment.trim();
    if (trimmed.toLowerCase().startsWith('unit ')) {
      final String extracted = trimmed.substring(5).trim();
      if (extracted.isNotEmpty) {
        return extracted;
      }
    }
  }
  return null;
}

/// Gender-aware range pick + formatted display for an order item.
String? resolveLabOrderItemDisplayReferenceRange(
  LabOrderItem item, {
  String? patientGender,
}) {
  if (item.interpretationOverride) {
    final String? overrideText = _trimOrNull(item.referenceRangeOverride);
    if (overrideText != null) {
      return overrideText;
    }
  }

  final LabReferenceRange? chosen = resolveLabReferenceRangeForPatient(
    item.referenceRanges,
    patientGender: patientGender,
  );
  if (chosen != null) {
    final String? built = formatLabReferenceRange(chosen);
    if (built != null) {
      return built;
    }
  }

  final String? applied = formatLabReferenceRangeFromMap(
    item.appliedReferenceRange,
  );
  if (applied != null) {
    return applied;
  }

  final String? fallback = _firstNonEmpty(<String?>[
    item.referenceRangeSummary,
    item.referenceRangeLabel,
    item.referenceRange,
  ]);
  if (fallback == null) {
    return null;
  }
  return rewriteLegacyLabReferenceRangeUnitSummary(fallback);
}

LabReferenceRange? resolveLabReferenceRangeForPatient(
  Iterable<LabReferenceRange> ranges, {
  String? patientGender,
}) {
  final String? normalizedGender = normalizeLabGenderToken(patientGender);
  LabReferenceRange? exactMatch;
  LabReferenceRange? unspecifiedMatch;
  for (final LabReferenceRange range in ranges) {
    final String? rangeGender = normalizeLabGenderToken(range.gender);
    if (normalizedGender != null &&
        rangeGender != null &&
        rangeGender == normalizedGender) {
      exactMatch ??= range;
      continue;
    }
    if (rangeGender == null ||
        rangeGender == 'ANY' ||
        rangeGender == 'ALL' ||
        rangeGender.isEmpty) {
      unspecifiedMatch ??= range;
    }
  }
  return exactMatch ?? unspecifiedMatch;
}

String? normalizeLabGenderToken(String? value) {
  final String normalized = (value ?? '').trim().toUpperCase();
  if (normalized.isEmpty) {
    return null;
  }
  return switch (normalized) {
    'M' || 'MALE' || 'MAN' => 'MALE',
    'F' || 'FEMALE' || 'WOMAN' => 'FEMALE',
    'OTHER' || 'O' || 'UNKNOWN' || 'U' || 'ANY' || 'ALL' => normalized,
    _ => normalized,
  };
}

String? _formatReferenceAge(num? value, String? unit) {
  if (value == null) {
    return null;
  }
  final String unitLabel = (unit ?? '').trim().toLowerCase();
  final String amount = value % 1 == 0
      ? value.toInt().toString()
      : value.toString();
  if (unitLabel.isEmpty) {
    return amount;
  }
  final String plural = value == 1 ? unitLabel : '${unitLabel}s';
  return '$amount $plural';
}

String _appendUnitIfNeeded(String rangeCore, String? unit) {
  if (unit == null || unit.isEmpty || rangeCore.contains(unit)) {
    return rangeCore;
  }
  return '$rangeCore $unit';
}

String? _trimOrNull(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String? trimmed = _trimOrNull(value);
    if (trimmed != null) {
      return trimmed;
    }
  }
  return null;
}

num? _asNum(Object? value) {
  if (value is num) {
    return value;
  }
  if (value == null) {
    return null;
  }
  return num.tryParse(value.toString().trim());
}
