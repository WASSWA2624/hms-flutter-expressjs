/// Pure dosing helpers for prescription line sync and validation.
///
/// Core relationship when units are compatible:
/// `quantity ≈ dosesPerDay × durationInDays × (doseAmount / strengthAmount)`
library;

enum ClinicalPrescriptionDosingField {
  doseAmount,
  doseUnit,
  frequency,
  durationValue,
  durationUnit,
  quantity,
}

class ClinicalParsedStrength {
  const ClinicalParsedStrength({required this.amount, required this.unit});

  final num amount;
  final String unit;
}

enum ClinicalPrescriptionDosingInconsistency {
  unitMismatch,
  quantityMismatch,
}

class ClinicalPrescriptionDosingSyncResult {
  const ClinicalPrescriptionDosingSyncResult({
    this.quantity,
    this.durationValue,
    this.durationUnit,
    this.inconsistency,
  });

  final int? quantity;
  final int? durationValue;
  final String? durationUnit;
  final ClinicalPrescriptionDosingInconsistency? inconsistency;

  bool get isConsistent => inconsistency == null;
}

/// Parses strings like `500 mg`, `400mg`, `1.5 g`, `1 mg/mL`, `400 mg/5 mL`.
///
/// For concentrations, uses the first amount/unit pair (e.g. `1` + `mg` from
/// `1 mg/mL`) so dose fields can always be seeded.
ClinicalParsedStrength? clinicalParseDrugStrength(String? raw) {
  final String? normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final Match? exact = RegExp(
    r'^\s*(\d+(?:\.\d+)?)\s*([A-Za-zµu]+)\s*$',
  ).firstMatch(normalized);
  if (exact != null) {
    return _parsedStrength(exact.group(1)!, exact.group(2)!);
  }
  final Match? concentration = RegExp(
    r'(\d+(?:\.\d+)?)\s*([A-Za-zµu]+)\s*/',
  ).firstMatch(normalized);
  if (concentration != null) {
    return _parsedStrength(concentration.group(1)!, concentration.group(2)!);
  }
  final Match? loose = RegExp(
    r'(\d+(?:\.\d+)?)\s*([A-Za-zµu]+)',
  ).firstMatch(normalized);
  if (loose != null) {
    return _parsedStrength(loose.group(1)!, loose.group(2)!);
  }
  return null;
}

ClinicalParsedStrength? _parsedStrength(String amountRaw, String unitRaw) {
  final num? amount = num.tryParse(amountRaw);
  final String unit = _normalizeUnit(unitRaw);
  if (amount == null || amount <= 0 || unit.isEmpty) {
    return null;
  }
  return ClinicalParsedStrength(amount: amount, unit: unit);
}

/// Returns doses per day for auto-quantity math. `null` means do not auto-drive
/// (PRN / CUSTOM / unknown).
num? clinicalPrescriptionDosesPerDay(String? frequency) {
  final String key = (frequency ?? '').trim().toUpperCase();
  if (key.isEmpty) {
    return null;
  }
  return switch (key) {
    'ONCE' || 'STAT' => 1,
    'OD' || 'QHS' => 1,
    'BID' || 'Q12H' => 2,
    'TID' || 'Q8H' => 3,
    'QID' || 'Q6H' => 4,
    'Q4H' => 6,
    'WEEKLY' => 1 / 7,
    'PRN' || 'CUSTOM' => null,
    _ => null,
  };
}

bool clinicalPrescriptionDurationOptional(String? frequency) {
  final String key = (frequency ?? '').trim().toUpperCase();
  return key == 'ONCE' || key == 'STAT';
}

/// Default course length seeded when a medicine is added (days).
const int clinicalPrescriptionDefaultDurationDays = 7;

/// Maps catalog drug form text onto a dispense quantity unit when possible.
String? clinicalPrescriptionQuantityUnitFromForm(String? form) {
  final String normalized = (form ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  const List<String> known = <String>[
    'tablet',
    'capsule',
    'vial',
    'ampoule',
    'bottle',
    'tube',
    'sachet',
    'patch',
    'drop',
    'mL',
    'dose',
    'pack',
  ];
  for (final String unit in known) {
    if (normalized == unit.toLowerCase()) {
      return unit;
    }
  }
  if (normalized.contains('capsule') ||
      RegExp(r'\bcaps?\b').hasMatch(normalized)) {
    return 'capsule';
  }
  if (normalized.contains('tablet') ||
      RegExp(r'\btabs?\b').hasMatch(normalized)) {
    return 'tablet';
  }
  if (normalized.contains('vial')) {
    return 'vial';
  }
  if (normalized.contains('ampoule') ||
      normalized.contains('ampule') ||
      RegExp(r'\bamps?\b').hasMatch(normalized)) {
    return 'ampoule';
  }
  if (normalized.contains('injection') ||
      normalized.contains('injectable') ||
      RegExp(r'\binj\b').hasMatch(normalized)) {
    return 'ampoule';
  }
  if (normalized.contains('syrup') ||
      normalized.contains('suspension') ||
      normalized.contains('solution') ||
      normalized.contains('liquid') ||
      normalized.contains('elixir')) {
    return 'bottle';
  }
  if (normalized.contains('cream') ||
      normalized.contains('ointment') ||
      normalized.contains('gel') ||
      normalized.contains('lotion')) {
    return 'tube';
  }
  if (normalized.contains('inhaler') ||
      normalized.contains('spray') ||
      normalized.contains('puff')) {
    return 'dose';
  }
  if (normalized.contains('bottle')) {
    return 'bottle';
  }
  if (normalized.contains('sachet') || normalized.contains('powder')) {
    return 'sachet';
  }
  if (normalized.contains('patch')) {
    return 'patch';
  }
  if (normalized.contains('drop')) {
    return 'drop';
  }
  if (normalized == 'ml' || normalized.contains('millilit')) {
    return 'mL';
  }
  return null;
}

/// Resolves a dispense quantity unit from catalog form/strength metadata.
///
/// Always returns a known unit so the prescribe card can prefill quantity unit.
String clinicalPrescriptionResolveQuantityUnit({
  String? form,
  String? strength,
  String? secondaryText,
}) {
  return clinicalPrescriptionQuantityUnitFromForm(form) ??
      clinicalPrescriptionQuantityUnitFromForm(secondaryText) ??
      clinicalPrescriptionQuantityUnitFromStrength(strength) ??
      'dose';
}

/// Infers quantity unit from strength text when form is missing.
String? clinicalPrescriptionQuantityUnitFromStrength(String? strength) {
  final String normalized = (strength ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized.contains('/ml') ||
      normalized.contains('/ ml') ||
      normalized.contains('mg/ml') ||
      normalized.contains('iu/ml')) {
    return 'ampoule';
  }
  if (RegExp(r'\bml\b').hasMatch(normalized) &&
      !normalized.contains('mg') &&
      !normalized.contains('mcg')) {
    return 'mL';
  }
  if (normalized.contains('puff')) {
    return 'dose';
  }
  if (normalized.contains('drop')) {
    return 'drop';
  }
  if (normalized.contains('patch')) {
    return 'patch';
  }
  if (normalized.contains('mg') ||
      normalized.contains('mcg') ||
      normalized.contains('µg') ||
      RegExp(r'\bg\b').hasMatch(normalized)) {
    return 'tablet';
  }
  return null;
}

/// Canonicalizes a dose unit onto known prescribe dose-unit tokens.
String? clinicalPrescriptionCanonicalDoseUnit(String? unit) {
  final String normalized = (unit ?? '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  final String key = normalized.toLowerCase();
  const List<String> known = <String>[
    'mg',
    'g',
    'mcg',
    'mL',
    'IU',
    'unit',
    'tablet',
    'capsule',
    'drop',
    'puff',
    'sachet',
    'patch',
  ];
  for (final String candidate in known) {
    if (candidate.toLowerCase() == key) {
      return candidate;
    }
  }
  if (key == 'µg' || key == 'ug') {
    return 'mcg';
  }
  if (key == 'iu') {
    return 'IU';
  }
  if (key == 'ml') {
    return 'mL';
  }
  return null;
}

num? clinicalPrescriptionDurationInDays(num? value, String? unit) {
  if (value == null || value <= 0) {
    return null;
  }
  final String key = (unit ?? 'days').trim().toLowerCase();
  return switch (key) {
    'hour' || 'hours' => value / 24,
    'day' || 'days' => value,
    'week' || 'weeks' => value * 7,
    'month' || 'months' => value * 30,
    _ => null,
  };
}

bool clinicalPrescriptionUnitsCompatible(String? left, String? right) {
  final String a = _normalizeUnit(left ?? '');
  final String b = _normalizeUnit(right ?? '');
  if (a.isEmpty || b.isEmpty) {
    return false;
  }
  return a == b;
}

/// Derives whole dispense quantity (ceiling) when inputs are complete.
int? clinicalDerivePrescriptionQuantity({
  required num? doseAmount,
  required String? doseUnit,
  required String? frequency,
  required num? durationValue,
  required String? durationUnit,
  required num? strengthAmount,
  required String? strengthUnit,
}) {
  if (doseAmount == null ||
      doseAmount <= 0 ||
      strengthAmount == null ||
      strengthAmount <= 0) {
    return null;
  }
  if (!clinicalPrescriptionUnitsCompatible(doseUnit, strengthUnit)) {
    return null;
  }
  final num? dosesPerDay = clinicalPrescriptionDosesPerDay(frequency);
  final num? days = clinicalPrescriptionDurationInDays(
    durationValue,
    durationUnit,
  );
  if (dosesPerDay == null || days == null || days <= 0) {
    return null;
  }
  final num unitsPerDose = doseAmount / strengthAmount;
  if (unitsPerDose <= 0) {
    return null;
  }
  final num raw = dosesPerDay * days * unitsPerDose;
  if (!raw.isFinite || raw <= 0) {
    return null;
  }
  final int quantity = raw.ceil();
  return quantity <= 0 ? null : quantity;
}

/// Derives duration in whole days when quantity is the independent variable.
({int value, String unit})? clinicalDerivePrescriptionDurationDays({
  required num? doseAmount,
  required String? doseUnit,
  required String? frequency,
  required int? quantity,
  required num? strengthAmount,
  required String? strengthUnit,
}) {
  if (doseAmount == null ||
      doseAmount <= 0 ||
      strengthAmount == null ||
      strengthAmount <= 0 ||
      quantity == null ||
      quantity <= 0) {
    return null;
  }
  if (!clinicalPrescriptionUnitsCompatible(doseUnit, strengthUnit)) {
    return null;
  }
  final num? dosesPerDay = clinicalPrescriptionDosesPerDay(frequency);
  if (dosesPerDay == null || dosesPerDay <= 0) {
    return null;
  }
  final num unitsPerDose = doseAmount / strengthAmount;
  if (unitsPerDose <= 0) {
    return null;
  }
  final num dosesNeeded = quantity / unitsPerDose;
  final num days = dosesNeeded / dosesPerDay;
  if (!days.isFinite || days <= 0) {
    return null;
  }
  final int wholeDays = days.round().clamp(1, 3650);
  return (value: wholeDays, unit: 'days');
}

/// Applies last-edited-wins sync for compatible solid/oral dosing.
ClinicalPrescriptionDosingSyncResult clinicalSyncPrescriptionDosing({
  required ClinicalPrescriptionDosingField lastEdited,
  required num? doseAmount,
  required String? doseUnit,
  required String? frequency,
  required num? durationValue,
  required String? durationUnit,
  required int? quantity,
  required num? strengthAmount,
  required String? strengthUnit,
  bool quantityWasAutoDerived = true,
}) {
  final bool hasStrength =
      strengthAmount != null &&
      strengthAmount > 0 &&
      (strengthUnit ?? '').trim().isNotEmpty;
  final bool hasDoseUnit = (doseUnit ?? '').trim().isNotEmpty;

  if (hasStrength &&
      hasDoseUnit &&
      !clinicalPrescriptionUnitsCompatible(doseUnit, strengthUnit)) {
    return const ClinicalPrescriptionDosingSyncResult(
      inconsistency: ClinicalPrescriptionDosingInconsistency.unitMismatch,
    );
  }

  if (lastEdited == ClinicalPrescriptionDosingField.quantity) {
    final ({int value, String unit})? derivedDuration =
        clinicalDerivePrescriptionDurationDays(
          doseAmount: doseAmount,
          doseUnit: doseUnit,
          frequency: frequency,
          quantity: quantity,
          strengthAmount: strengthAmount,
          strengthUnit: strengthUnit,
        );
    if (derivedDuration == null) {
      return ClinicalPrescriptionDosingSyncResult(quantity: quantity);
    }
    return ClinicalPrescriptionDosingSyncResult(
      quantity: quantity,
      durationValue: derivedDuration.value,
      durationUnit: derivedDuration.unit,
    );
  }

  final int? derivedQuantity = clinicalDerivePrescriptionQuantity(
    doseAmount: doseAmount,
    doseUnit: doseUnit,
    frequency: frequency,
    durationValue: durationValue,
    durationUnit: durationUnit,
    strengthAmount: strengthAmount,
    strengthUnit: strengthUnit,
  );

  if (derivedQuantity == null) {
    return ClinicalPrescriptionDosingSyncResult(
      quantity: quantity,
      durationValue: durationValue?.round(),
      durationUnit: durationUnit,
    );
  }

  if (quantityWasAutoDerived ||
      quantity == null ||
      quantity == derivedQuantity) {
    return ClinicalPrescriptionDosingSyncResult(
      quantity: derivedQuantity,
      durationValue: durationValue?.round(),
      durationUnit: durationUnit,
    );
  }

  return ClinicalPrescriptionDosingSyncResult(
    quantity: quantity,
    durationValue: durationValue?.round(),
    durationUnit: durationUnit,
    inconsistency: ClinicalPrescriptionDosingInconsistency.quantityMismatch,
  );
}

String _normalizeUnit(String unit) {
  final String trimmed = unit.trim().toLowerCase();
  return switch (trimmed) {
    'mcg' || 'µg' || 'ug' => 'mcg',
    'iu' => 'IU',
    _ => trimmed,
  };
}
