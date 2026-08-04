import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Predefined pharmacy cancel reasons for order- and line-level cancellation.
enum PharmacyCancelReason {
  discontinuedByPrescriber,
  duplicateOrder,
  patientRefused,
  allergyOrAdverseReaction,
  drugInteractionOrContraindication,
  outOfStock,
  wrongMedicationOrDose,
  patientDischargedOrTransferred,
  paymentOrInsuranceDenied,
  enteredInError,
  therapyNoLongerIndicated,
  patientDeceased,
  substitutionNotAccepted,
  awaitingClinicalClarification,
}

extension PharmacyCancelReasonX on PharmacyCancelReason {
  String get id => name;

  IconData get icon {
    return switch (this) {
      PharmacyCancelReason.discontinuedByPrescriber => Icons.person_off_outlined,
      PharmacyCancelReason.duplicateOrder => Icons.content_copy_outlined,
      PharmacyCancelReason.patientRefused => Icons.front_hand_outlined,
      PharmacyCancelReason.allergyOrAdverseReaction => Icons.warning_amber_outlined,
      PharmacyCancelReason.drugInteractionOrContraindication =>
        Icons.health_and_safety_outlined,
      PharmacyCancelReason.outOfStock => Icons.inventory_2_outlined,
      PharmacyCancelReason.wrongMedicationOrDose => Icons.report_gmailerrorred_outlined,
      PharmacyCancelReason.patientDischargedOrTransferred => Icons.logout_outlined,
      PharmacyCancelReason.paymentOrInsuranceDenied => Icons.payments_outlined,
      PharmacyCancelReason.enteredInError => Icons.edit_off_outlined,
      PharmacyCancelReason.therapyNoLongerIndicated => Icons.task_alt_outlined,
      PharmacyCancelReason.patientDeceased => Icons.sentiment_very_dissatisfied_outlined,
      PharmacyCancelReason.substitutionNotAccepted => Icons.swap_horiz_outlined,
      PharmacyCancelReason.awaitingClinicalClarification => Icons.help_outline,
    };
  }

  String label(AppLocalizations l10n) {
    return switch (this) {
      PharmacyCancelReason.discontinuedByPrescriber =>
        l10n.pharmacyCancelReasonDiscontinuedByPrescriber,
      PharmacyCancelReason.duplicateOrder => l10n.pharmacyCancelReasonDuplicateOrder,
      PharmacyCancelReason.patientRefused => l10n.pharmacyCancelReasonPatientRefused,
      PharmacyCancelReason.allergyOrAdverseReaction =>
        l10n.pharmacyCancelReasonAllergyOrAdverseReaction,
      PharmacyCancelReason.drugInteractionOrContraindication =>
        l10n.pharmacyCancelReasonDrugInteractionOrContraindication,
      PharmacyCancelReason.outOfStock => l10n.pharmacyCancelReasonOutOfStock,
      PharmacyCancelReason.wrongMedicationOrDose =>
        l10n.pharmacyCancelReasonWrongMedicationOrDose,
      PharmacyCancelReason.patientDischargedOrTransferred =>
        l10n.pharmacyCancelReasonPatientDischargedOrTransferred,
      PharmacyCancelReason.paymentOrInsuranceDenied =>
        l10n.pharmacyCancelReasonPaymentOrInsuranceDenied,
      PharmacyCancelReason.enteredInError => l10n.pharmacyCancelReasonEnteredInError,
      PharmacyCancelReason.therapyNoLongerIndicated =>
        l10n.pharmacyCancelReasonTherapyNoLongerIndicated,
      PharmacyCancelReason.patientDeceased => l10n.pharmacyCancelReasonPatientDeceased,
      PharmacyCancelReason.substitutionNotAccepted =>
        l10n.pharmacyCancelReasonSubstitutionNotAccepted,
      PharmacyCancelReason.awaitingClinicalClarification =>
        l10n.pharmacyCancelReasonAwaitingClinicalClarification,
    };
  }
}

List<PharmacyCancelReason> pharmacyCancelReasonsCatalog() {
  return List<PharmacyCancelReason>.unmodifiable(PharmacyCancelReason.values);
}

String composePharmacyCancelReason({
  required AppLocalizations l10n,
  required Set<PharmacyCancelReason> selected,
  required String customReason,
}) {
  final List<String> parts = <String>[
    for (final PharmacyCancelReason reason in pharmacyCancelReasonsCatalog())
      if (selected.contains(reason)) reason.label(l10n),
    if (customReason.trim().isNotEmpty) customReason.trim(),
  ];
  return parts.join('; ');
}
