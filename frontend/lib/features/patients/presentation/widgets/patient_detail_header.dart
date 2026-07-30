import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

export 'package:hosspi_hms/shared/patient_actions/patient_age_formatter.dart'
    show formatPatientAge, patientGenderIcon, patientGenderLabel;

String patientIdentifierTypeLabel(AppLocalizations l10n, Patient patient) {
  final String? type = patient.primaryIdentifierType?.trim();
  if (type == null || type.isEmpty) {
    return l10n.patientsIdentifierLabel;
  }
  return switch (type.toUpperCase()) {
    'MRN' => 'MRN',
    'NATIONAL_ID' => l10n.patientsIdentifierLabel,
    _ => type.replaceAll('_', ' '),
  };
}

String formatPatientOptionalDate(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.mediumDate(value, Localizations.localeOf(context));
}

class PatientDetailHeader extends ConsumerWidget {
  const PatientDetailHeader({
    required this.detail,
    required this.referenceData,
    super.key,
  });

  final PatientDetail detail;
  final PatientReferenceData referenceData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Patient patient = detail.patient;
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final PatientRegistrationScope registrationScope =
        PatientRegistrationScope.resolve(
          referenceData: referenceData,
          accessPolicy: accessPolicy,
        );
    final String gender = patient.gender == null
        ? l10n.profileUnknownValue
        : patientGenderLabel(l10n, patient.gender!);
    final IconData? genderIcon = patientGenderIcon(patient.gender);
    final PatientVisitContext? visit = patient.currentVisit;

    return AppPatientDetails(
      patientName: patient.effectiveDisplayName,
      showPatientName: false,
      showAvatar: false,
      patientNumber: patient.effectiveIdentifier ?? '',
      patientNumberLabel: patientIdentifierTypeLabel(l10n, patient),
      ageLabel: formatPatientAge(l10n, patient.dateOfBirth),
      genderLabel: gender,
      genderIcon: genderIcon,
      phoneLabel: patient.primaryPhone,
      emailLabel: patient.primaryEmail,
      semanticLabel: l10n.patientsDetailTitle,
      status: AppWorkspaceStatus(
        label: patient.isActive
            ? l10n.patientsActiveFilter
            : l10n.patientsInactiveFilter,
        tone: patient.isActive
            ? AppWorkspaceStatusTone.success
            : AppWorkspaceStatusTone.neutral,
        icon: patient.isActive
            ? Icons.check_circle_outline
            : Icons.block_outlined,
      ),
      alerts: <AppWorkspaceStatus>[
        if (patient.hasAllergyAlert)
          AppWorkspaceStatus(
            label: patient.allergyAlertLabel ?? l10n.patientsAllergyAlertLabel,
            tone: AppWorkspaceStatusTone.warning,
            icon: Icons.warning_amber_outlined,
          ),
        if (patient.requiresCompletion)
          AppWorkspaceStatus(
            label: l10n.patientsRegistrationIncompleteValue,
            tone: AppWorkspaceStatusTone.warning,
            icon: Icons.error_outline,
          ),
      ],
      expandedFields: <AppWorkspacePatientContextField>[
        AppWorkspacePatientContextField(
          label: l10n.patientsDobLabel,
          value: formatPatientOptionalDate(context, patient.dateOfBirth),
          icon: Icons.cake_outlined,
        ),
        AppWorkspacePatientContextField(
          label: l10n.patientsFacilityLabel,
          value: patient.facilityLabel ?? '',
          icon: Icons.business_outlined,
          authorized: registrationScope.showFacilityPicker,
        ),
        if (visit != null)
          AppWorkspacePatientContextField(
            label: l10n.patientsVisitIdLabel,
            value: visit.publicId ?? '',
            icon: Icons.assignment_turned_in_outlined,
            tone: AppWorkspaceStatusTone.info,
            copyable: true,
            copyTooltip: l10n.copyIdentifierAction,
            copiedMessage: l10n.identifierCopiedMessage,
          ),
      ],
    );
  }
}
