import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_age_formatter.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_registration_scope.dart';

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

String patientGenderLabel(AppLocalizations l10n, String value) {
  return switch (value.toUpperCase()) {
    'MALE' => l10n.patientsGenderMale,
    'FEMALE' => l10n.patientsGenderFemale,
    'OTHER' => l10n.patientsGenderOther,
    'UNKNOWN' => l10n.patientsGenderUnknown,
    _ => value.replaceAll('_', ' '),
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
    final ThemeData theme = Theme.of(context);

    return AppWorkspacePatientContextHeader(
      patientName: patient.effectiveDisplayName,
      showPatientName: false,
      showAvatar: false,
      patientNumber: patient.effectiveIdentifier ?? '',
      patientNumberLabel: patientIdentifierTypeLabel(l10n, patient),
      demographicsWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            formatPatientAge(l10n, patient.dateOfBirth),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (genderIcon != null) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            Icon(
              genderIcon,
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
          SizedBox(width: theme.spacing.xs),
          Text(
            gender,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
      fieldStyle: AppWorkspacePatientContextFieldStyle.inline,
      fields: <AppWorkspacePatientContextField>[
        AppWorkspacePatientContextField(
          label: l10n.patientsDobLabel,
          value: formatPatientOptionalDate(context, patient.dateOfBirth),
          icon: Icons.cake_outlined,
        ),
        AppWorkspacePatientContextField(
          label: l10n.patientsPhoneLabel,
          value: patient.primaryPhone ?? '',
          icon: Icons.phone_outlined,
        ),
        if (registrationScope.showFacilityPicker)
          AppWorkspacePatientContextField(
            label: l10n.patientsFacilityLabel,
            value: patient.facilityLabel ?? '',
            icon: Icons.business_outlined,
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
