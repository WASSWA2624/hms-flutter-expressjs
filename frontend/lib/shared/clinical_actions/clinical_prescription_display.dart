import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';

String clinicalPrescriptionReadableSummary({
  String? drugName,
  Object? quantity,
  String? quantityUnit,
  Object? doseAmount,
  String? doseUnit,
  String? dosage,
  String? route,
  String? frequency,
  Object? durationValue,
  String? durationUnit,
  String? instructions,
}) {
  final String name = clinicalActionTrimmedOrNull(drugName) ?? 'Medication';
  final String dose = clinicalActionJoinDisplay(<String?>[
    clinicalActionTrimmedOrNull(doseAmount?.toString()),
    clinicalActionTrimmedOrNull(doseUnit),
    if (doseAmount == null) clinicalActionTrimmedOrNull(dosage),
  ], separator: ' ');
  final String qty = clinicalActionJoinDisplay(<String?>[
    clinicalActionTrimmedOrNull(quantity?.toString()),
    clinicalActionTrimmedOrNull(quantityUnit),
  ], separator: ' ');
  final String sig = clinicalPrescriptionSigReadable(
    doseAmount: doseAmount,
    doseUnit: doseUnit,
    dosage: dosage,
    route: route,
    frequency: frequency,
    durationValue: durationValue,
    durationUnit: durationUnit,
    instructions: instructions,
    includeInstructions: false,
  );
  final List<String> parts = <String>[
    if (dose.isNotEmpty) '$name $dose' else name,
    if (sig.isNotEmpty) '— $sig',
    if (qty.isNotEmpty) '(Qty: $qty)',
  ];
  final String summary = parts.join(' ');
  final String? note = clinicalActionTrimmedOrNull(instructions);
  if (note == null) {
    return summary;
  }
  return '$summary. $note';
}

/// Paper-style drug heading: generic name + strength (e.g. "Amoxicillin 500 mg").
String clinicalPrescriptionDrugHeading(ClinicalActionCatalogOption? option) {
  if (option == null) {
    return '';
  }
  final String generic = clinicalPrescriptionDrugGenericName(option);
  final String strength = clinicalPrescriptionDrugStrength(option);
  if (generic.isEmpty) {
    return strength;
  }
  if (strength.isEmpty) {
    return generic;
  }
  if (generic.toLowerCase().contains(strength.toLowerCase())) {
    return generic;
  }
  return clinicalActionJoinDisplay(<String?>[generic, strength], separator: ' ');
}

String clinicalPrescriptionDrugGenericName(ClinicalActionCatalogOption? option) {
  if (option == null) {
    return '';
  }
  return clinicalActionTrimmedOrNull(
        option.metadata['generic_name']?.toString(),
      ) ??
      clinicalActionTrimmedOrNull(option.name) ??
      option.displayTitle;
}

String clinicalPrescriptionDrugStrength(ClinicalActionCatalogOption? option) {
  if (option == null) {
    return '';
  }
  final String? fromMeta = clinicalActionTrimmedOrNull(
    option.metadata['strength']?.toString(),
  );
  if (fromMeta != null) {
    return fromMeta;
  }
  final String? secondary = clinicalActionTrimmedOrNull(option.secondaryText);
  if (secondary != null && RegExp(r'\d').hasMatch(secondary)) {
    return secondary;
  }
  return '';
}

/// Doctor-style directions, e.g. "Take 500 mg by mouth twice daily for 5 days".
String clinicalPrescriptionPaperDirections({
  Object? doseAmount,
  String? doseUnit,
  String? dosage,
  String? route,
  String? frequency,
  Object? durationValue,
  String? durationUnit,
}) {
  final String dose = clinicalActionJoinDisplay(<String?>[
    clinicalActionTrimmedOrNull(doseAmount?.toString()),
    clinicalActionTrimmedOrNull(doseUnit),
    if (doseAmount == null) clinicalActionTrimmedOrNull(dosage),
  ], separator: ' ');
  final String duration = clinicalActionJoinDisplay(<String?>[
    clinicalActionTrimmedOrNull(durationValue?.toString()),
    clinicalActionTrimmedOrNull(durationUnit),
  ], separator: ' ');
  final String body = clinicalActionJoinDisplay(<String?>[
    if (dose.isNotEmpty) dose,
    if (route != null && route.trim().isNotEmpty)
      clinicalPrescriptionRouteReadable(route.trim()),
    if (frequency != null && frequency.trim().isNotEmpty)
      clinicalFrequencyReadable(frequency.trim()),
    if (duration.isNotEmpty) 'for $duration',
  ], separator: ' ');
  if (body.isEmpty) {
    return '';
  }
  return 'Take $body';
}

String clinicalPrescriptionPaperQuantityLabel({
  Object? quantity,
  String? quantityUnit,
}) {
  final String qty = clinicalActionJoinDisplay(<String?>[
    clinicalActionTrimmedOrNull(quantity?.toString()),
    clinicalActionTrimmedOrNull(quantityUnit),
  ], separator: ' ');
  if (qty.isEmpty) {
    return '';
  }
  return 'Qty $qty';
}

/// Compact header meta for medication cards, e.g. "Oral · BID · Qty 1".
///
/// Uses short catalog labels (not prose directions) so the header does not
/// duplicate the wording of the editable prescription fields.
String clinicalPrescriptionCompactHeaderMeta({
  String? route,
  String? frequency,
  Object? quantity,
  String? quantityUnit,
}) {
  final String? routeLabel = clinicalActionTrimmedOrNull(route) == null
      ? null
      : clinicalActionApiLabel(route!.trim());
  final String? frequencyLabel = clinicalActionTrimmedOrNull(frequency);
  final String qty = clinicalPrescriptionPaperQuantityLabel(
    quantity: quantity,
    quantityUnit: quantityUnit,
  );
  return clinicalActionJoinDisplay(<String?>[
    routeLabel,
    frequencyLabel?.toUpperCase(),
    if (qty.isNotEmpty) qty,
  ], separator: ' · ');
}

String clinicalPrescriptionPaperSummary({
  required ClinicalActionCatalogOption? drug,
  Object? quantity,
  String? quantityUnit,
  Object? doseAmount,
  String? doseUnit,
  String? dosage,
  String? route,
  String? frequency,
  Object? durationValue,
  String? durationUnit,
  String? instructions,
  String fallbackDrugName = 'Medication',
}) {
  final String heading = clinicalPrescriptionDrugHeading(drug);
  final String name = heading.isEmpty ? fallbackDrugName : heading;
  final String directions = clinicalPrescriptionPaperDirections(
    doseAmount: doseAmount,
    doseUnit: doseUnit,
    dosage: dosage,
    route: route,
    frequency: frequency,
    durationValue: durationValue,
    durationUnit: durationUnit,
  );
  final String qty = clinicalPrescriptionPaperQuantityLabel(
    quantity: quantity,
    quantityUnit: quantityUnit,
  );
  final String line = clinicalActionJoinDisplay(<String?>[
    name,
    if (directions.isNotEmpty) directions,
    if (qty.isNotEmpty) qty,
  ], separator: ' · ');
  final String? note = clinicalActionTrimmedOrNull(instructions);
  if (note == null) {
    return line;
  }
  return '$line. $note';
}

String clinicalPrescriptionSigReadable({
  Object? doseAmount,
  String? doseUnit,
  String? dosage,
  String? route,
  String? frequency,
  Object? durationValue,
  String? durationUnit,
  String? instructions,
  bool includeInstructions = true,
}) {
  final String dose = clinicalActionJoinDisplay(<String?>[
    clinicalActionTrimmedOrNull(doseAmount?.toString()),
    clinicalActionTrimmedOrNull(doseUnit),
    if (doseAmount == null) clinicalActionTrimmedOrNull(dosage),
  ], separator: ' ');
  final String duration = clinicalActionJoinDisplay(<String?>[
    clinicalActionTrimmedOrNull(durationValue?.toString()),
    clinicalActionTrimmedOrNull(durationUnit),
  ], separator: ' ');
  final String sig = clinicalActionJoinDisplay(<String?>[
    if (dose.isNotEmpty) dose,
    if (route != null && route.trim().isNotEmpty)
      clinicalActionApiLabel(route.trim()),
    if (frequency != null && frequency.trim().isNotEmpty)
      clinicalFrequencyReadable(frequency.trim()),
    if (duration.isNotEmpty) 'for $duration',
  ], separator: ' ');
  if (!includeInstructions) {
    return sig;
  }
  final String? note = clinicalActionTrimmedOrNull(instructions);
  if (note == null) {
    return sig;
  }
  if (sig.isEmpty) {
    return note;
  }
  return '$sig. $note';
}

String clinicalPrescriptionItemReadableSummary(ClinicalPharmacyOrderItem item) {
  return clinicalPrescriptionReadableSummary(
    drugName: item.displayTitle,
    quantity: item.quantity,
    quantityUnit: item.quantityUnit,
    doseAmount: item.doseAmount ?? item.dosage,
    doseUnit: item.doseUnit,
    dosage: item.dosage,
    route: item.route,
    frequency: item.frequency,
    durationValue: item.durationValue,
    durationUnit: item.durationUnit,
    instructions: item.instructions,
  );
}

String clinicalPrescriptionRouteReadable(String route) {
  return switch (route.toUpperCase()) {
    'ORAL' => 'by mouth',
    'IV' => 'intravenously',
    'IM' => 'intramuscularly',
    'SC' => 'subcutaneously',
    'SUBLINGUAL' => 'under the tongue',
    'RECTAL' => 'rectally',
    'VAGINAL' => 'vaginally',
    'TOPICAL' => 'topically',
    'INHALATION' => 'by inhalation',
    'OPHTHALMIC' => 'in the eye',
    'OTIC' => 'in the ear',
    'NASAL' => 'in the nose',
    'INTRADERMAL' => 'intradermally',
    _ => clinicalActionApiLabel(route).toLowerCase(),
  };
}

String clinicalFrequencyReadable(String frequency) {
  return switch (frequency.toUpperCase()) {
    'ONCE' => 'once',
    'OD' => 'once daily',
    'BID' => 'twice daily',
    'TID' => 'three times daily',
    'QID' => 'four times daily',
    'Q4H' => 'every 4 hours',
    'Q6H' => 'every 6 hours',
    'Q8H' => 'every 8 hours',
    'Q12H' => 'every 12 hours',
    'QHS' => 'at bedtime',
    'WEEKLY' => 'weekly',
    'PRN' => 'as needed',
    'STAT' => 'immediately',
    _ => clinicalActionApiLabel(frequency).toLowerCase(),
  };
}
