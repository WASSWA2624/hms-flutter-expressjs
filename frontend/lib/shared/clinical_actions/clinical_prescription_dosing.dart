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

/// Parses strings like `500 mg`, `400mg`, `1.5 g`.
ClinicalParsedStrength? clinicalParseDrugStrength(String? raw) {
  final String? normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final Match? match = RegExp(
    r'^\s*(\d+(?:\.\d+)?)\s*([A-Za-zµu]+)\s*$',
  ).firstMatch(normalized);
  if (match == null) {
    return null;
  }
  final num? amount = num.tryParse(match.group(1)!);
  final String unit = _normalizeUnit(match.group(2)!);
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
