import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
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
