import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum PatientRegistrationSimilarityAction { cancel, useExisting, proceed }

/// Outcome of [showPatientRegistrationSimilarityDialog].
@immutable
final class PatientRegistrationSimilarityDialogResult {
  const PatientRegistrationSimilarityDialogResult._({
    required this.action,
    this.selectedPatient,
  });

  const PatientRegistrationSimilarityDialogResult.cancel()
    : this._(action: PatientRegistrationSimilarityAction.cancel);

  const PatientRegistrationSimilarityDialogResult.proceed()
    : this._(action: PatientRegistrationSimilarityAction.proceed);

  const PatientRegistrationSimilarityDialogResult.useExisting(Patient patient)
    : this._(
        action: PatientRegistrationSimilarityAction.useExisting,
        selectedPatient: patient,
      );

  final PatientRegistrationSimilarityAction action;
  final Patient? selectedPatient;
}

/// Snapshot of the values being registered, shown in the similarity dialog.
@immutable
final class PatientRegistrationSimilarityProposed {
  const PatientRegistrationSimilarityProposed({
    required this.firstName,
    this.lastName = '',
    this.dateOfBirth,
    this.gender = '',
    this.phone = '',
    this.email = '',
    this.identifierType = '',
    this.identifierValue = '',
    this.tenantId = '',
    this.facilityId = '',
    this.tenantLabel = '',
    this.facilityLabel = '',
  });

  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String gender;
  final String phone;
  final String email;
  final String identifierType;
  final String identifierValue;
  final String tenantId;
  final String facilityId;
  final String tenantLabel;
  final String facilityLabel;

  String get displayName {
    final String combined = <String>[
      firstName.trim(),
      lastName.trim(),
    ].where((String part) => part.isNotEmpty).join(' ');
    return combined;
  }

  String get resolvedTenantLabel {
    final String label = tenantLabel.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return tenantId.trim();
  }

  String get resolvedFacilityLabel {
    final String label = facilityLabel.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return facilityId.trim();
  }
}

/// Whether proposed registration and candidate share tenant/facility scope.
@visibleForTesting
bool patientRegistrationScopesMatch({
  required String? leftTenantId,
  required String? leftFacilityId,
  required String? rightTenantId,
  required String? rightFacilityId,
}) {
  final String? leftTenant = _nullIfEmpty(leftTenantId);
  final String? leftFacility = _nullIfEmpty(leftFacilityId);
  final String? rightTenant = _nullIfEmpty(rightTenantId);
  final String? rightFacility = _nullIfEmpty(rightFacilityId);

  if (leftFacility != null || rightFacility != null) {
    if (leftFacility != rightFacility) {
      return false;
    }
    if (leftTenant != null && rightTenant != null && leftTenant != rightTenant) {
      return false;
    }
    return true;
  }

  return leftTenant == rightTenant;
}

/// Patient registration adapter over [showAppSimilarityReviewDialog].
///
/// Exact/blocking conflicts require **same tenant/facility scope**. Cross-scope
/// near-duplicates still surface for review but do not hard-block proceed.
Future<PatientRegistrationSimilarityDialogResult>
showPatientRegistrationSimilarityDialog(
  BuildContext context, {
  required PatientRegistrationSimilarityProposed proposed,
  required List<PatientDuplicateCandidate> matches,
}) async {
  final AppLocalizations l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  final List<PatientDuplicateCandidate> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final List<AppSimilarityMatch<Patient>> appMatches =
      <AppSimilarityMatch<Patient>>[];

  for (final PatientDuplicateCandidate duplicate in visibleMatches) {
    final Patient? patient = _candidatePatient(duplicate);
    if (patient == null) {
      continue;
    }
    final bool sameScope = patientRegistrationScopesMatch(
      leftTenantId: proposed.tenantId,
      leftFacilityId: proposed.facilityId,
      rightTenantId: patient.tenantId,
      rightFacilityId: patient.facilityId,
    );
    final List<AppSimilarityFieldRow> fields = _buildFieldRows(
      context: context,
      l10n: l10n,
      locale: locale,
      proposed: proposed,
      duplicate: duplicate,
      patient: patient,
      sameScope: sameScope,
    );
    final bool identityExact = _isIdentityExact(duplicate, fields);
    // Same-scope exact identity can hard-block. Cross-scope peers stay reviewable.
    final bool isExact = sameScope && identityExact;
    appMatches.add(
      AppSimilarityMatch<Patient>(
        item: patient,
        title: patient.effectiveDisplayName,
        subtitle: _patientSubtitle(
          context: context,
          locale: locale,
          patient: patient,
          sameScope: sameScope,
          l10n: l10n,
        ),
        overallScore: duplicate.confidenceScore.clamp(0, 100),
        isExact: isExact,
        fields: fields,
      ),
    );
  }

  final bool hasMatches = appMatches.isNotEmpty;
  final bool hasExact = appMatches.any(
    (AppSimilarityMatch<Patient> match) => match.isExact,
  );
  final int overallScore = appMatches.isEmpty
      ? 0
      : appMatches
            .map((AppSimilarityMatch<Patient> match) => match.overallScore)
            .reduce((int a, int b) => a > b ? a : b);

  final String dialogTitle = hasExact
      ? l10n.patientsExactDialogTitle
      : hasMatches
      ? l10n.patientsSimilarDialogTitle
      : l10n.patientsDuplicateWarningTitle;
  final String bannerTitle = hasExact
      ? l10n.patientsExactBannerTitle
      : hasMatches
      ? l10n.patientsDuplicateWarningTitle
      : l10n.patientsDuplicateWarningTitle;
  final String bannerMessage = hasExact
      ? l10n.patientsExactDialogBody
      : hasMatches
      ? l10n.patientsSimilarDialogBody(overallScore)
      : l10n.patientsDuplicateWarningBody;
  final AppFormInformationVariant bannerVariant = hasExact
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final AppSimilarityReviewResult<Patient> result =
      await showAppSimilarityReviewDialog<Patient>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: _proposedFields(context, l10n, locale, proposed),
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: hasExact,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: l10n.patientsRegisterAnywayAction,
        continueLabel: l10n.patientsRegisterNewPatientAction,
        useThisLabel: l10n.patientsUseExistingPatientAction,
        useThisIcon: AppActionIcons.person,
        proposedHeading: l10n.patientsProposedHeading,
        matchesHeading: l10n.patientsMatchesHeading,
        exactBadgeLabel: l10n.appSimilarityExactMatchLabel,
        nearBadgeLabel: l10n.appSimilarityNearMatchLabel,
        existingHeading: l10n.patientsDuplicateExistingRecordLabel,
        fieldColumnLabel: l10n.appSimilarityFieldColumnLabel,
        proposedColumnLabel: l10n.patientsDuplicateYourEntryLabel,
        existingColumnLabel: l10n.patientsDuplicateExistingRecordLabel,
        closestMatchLabel: l10n.appSimilarityClosestMatchLabel,
        emptyValueLabel: l10n.clinicalOrderEmptyValueLabel,
        dialogIcon: hasExact
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
    case AppSimilarityReviewAction.retry:
    case AppSimilarityReviewAction.replaceExisting:
      return const PatientRegistrationSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.useExisting:
      final Patient? patient = result.selected;
      if (patient == null) {
        return const PatientRegistrationSimilarityDialogResult.cancel();
      }
      return PatientRegistrationSimilarityDialogResult.useExisting(patient);
    case AppSimilarityReviewAction.proceed:
      return const PatientRegistrationSimilarityDialogResult.proceed();
  }
}

List<AppSimilarityProposedField> _proposedFields(
  BuildContext context,
  AppLocalizations l10n,
  Locale locale,
  PatientRegistrationSimilarityProposed proposed,
) {
  final List<AppSimilarityProposedField> fields = <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'first_name',
      label: l10n.patientsFirstNameLabel,
      initialValue: proposed.firstName,
      isRequired: true,
      editable: false,
    ),
    AppSimilarityProposedField(
      key: 'last_name',
      label: l10n.patientsLastNameLabel,
      initialValue: proposed.lastName,
      editable: false,
    ),
    AppSimilarityProposedField(
      key: 'date_of_birth',
      label: l10n.patientsDobLabel,
      initialValue: _dateLabel(context, locale, proposed.dateOfBirth) ?? '',
      editable: false,
    ),
    AppSimilarityProposedField(
      key: 'gender',
      label: l10n.patientsGenderLabel,
      initialValue: _genderLabel(proposed.gender),
      editable: false,
    ),
    AppSimilarityProposedField(
      key: 'phone',
      label: l10n.patientsPhoneLabel,
      initialValue: proposed.phone,
      editable: false,
    ),
    AppSimilarityProposedField(
      key: 'email',
      label: l10n.patientsEmailLabel,
      initialValue: proposed.email,
      editable: false,
    ),
    AppSimilarityProposedField(
      key: 'identifier',
      label: l10n.patientsIdentifierLabel,
      initialValue: _identifierLabel(
        proposed.identifierType,
        proposed.identifierValue,
      ),
      editable: false,
    ),
  ];

  final String tenantLabel = proposed.resolvedTenantLabel;
  if (tenantLabel.isNotEmpty) {
    fields.add(
      AppSimilarityProposedField(
        key: 'tenant',
        label: l10n.profileTenantLabel,
        initialValue: tenantLabel,
        editable: false,
      ),
    );
  }
  final String facilityLabel = proposed.resolvedFacilityLabel;
  if (facilityLabel.isNotEmpty) {
    fields.add(
      AppSimilarityProposedField(
        key: 'facility',
        label: l10n.patientsFacilityLabel,
        initialValue: facilityLabel,
        editable: false,
      ),
    );
  }

  return fields;
}

List<AppSimilarityFieldRow> _buildFieldRows({
  required BuildContext context,
  required AppLocalizations l10n,
  required Locale locale,
  required PatientRegistrationSimilarityProposed proposed,
  required PatientDuplicateCandidate duplicate,
  required Patient patient,
  required bool sameScope,
}) {
  final List<AppSimilarityFieldRow> rows;
  if (duplicate.fieldComparisons.isNotEmpty) {
    rows = duplicate.fieldComparisons
        .map((PatientDuplicateFieldComparison comparison) {
          return AppSimilarityFieldRow(
            key: comparison.field.trim().toUpperCase(),
            label: _comparisonFieldLabel(l10n, comparison.field),
            proposedValue: _comparisonValueLabel(
              context,
              locale,
              comparison.field,
              comparison.inputValue,
            ),
            existingValue: _comparisonValueLabel(
              context,
              locale,
              comparison.field,
              comparison.candidateValue,
            ),
            score: _comparisonScore(comparison),
          );
        })
        .toList(growable: true);
  } else {
    rows = <AppSimilarityFieldRow>[
      AppSimilarityFieldRow(
        key: 'NAME',
        label: l10n.patientsNameLabel,
        proposedValue: proposed.displayName,
        existingValue: patient.effectiveDisplayName,
      ),
      AppSimilarityFieldRow(
        key: 'DATE_OF_BIRTH',
        label: l10n.patientsDobLabel,
        proposedValue: _dateLabel(context, locale, proposed.dateOfBirth),
        existingValue: _dateLabel(context, locale, patient.dateOfBirth),
      ),
      AppSimilarityFieldRow(
        key: 'GENDER',
        label: l10n.patientsGenderLabel,
        proposedValue: _genderLabel(proposed.gender),
        existingValue: _genderLabel(patient.gender),
      ),
      AppSimilarityFieldRow(
        key: 'PHONE',
        label: l10n.patientsPhoneLabel,
        proposedValue: proposed.phone.trim(),
        existingValue: (patient.primaryPhone ?? '').trim(),
      ),
      AppSimilarityFieldRow(
        key: 'EMAIL',
        label: l10n.patientsEmailLabel,
        proposedValue: proposed.email.trim(),
        existingValue: (patient.primaryEmail ?? '').trim(),
      ),
      AppSimilarityFieldRow(
        key: 'IDENTIFIER',
        label: l10n.patientsIdentifierLabel,
        proposedValue: _identifierLabel(
          proposed.identifierType,
          proposed.identifierValue,
        ),
        existingValue: (patient.effectiveIdentifier ?? '').trim(),
      ),
    ];
  }

  _ensureScopeRows(
    rows: rows,
    l10n: l10n,
    proposed: proposed,
    patient: patient,
    sameScope: sameScope,
  );
  return rows;
}

void _ensureScopeRows({
  required List<AppSimilarityFieldRow> rows,
  required AppLocalizations l10n,
  required PatientRegistrationSimilarityProposed proposed,
  required Patient patient,
  required bool sameScope,
}) {
  final Set<String> keys = rows
      .map((AppSimilarityFieldRow row) => row.key.trim().toUpperCase())
      .toSet();

  final String proposedTenant = proposed.resolvedTenantLabel;
  final String existingTenant =
      (patient.tenantLabel ?? patient.tenantId ?? '').trim();
  if (!keys.contains('TENANT') &&
      (proposedTenant.isNotEmpty || existingTenant.isNotEmpty)) {
    rows.add(
      AppSimilarityFieldRow(
        key: 'TENANT',
        label: l10n.profileTenantLabel,
        proposedValue: proposedTenant,
        existingValue: existingTenant,
        score: _scopeFieldScore(
          proposed.tenantId,
          patient.tenantId,
          sameScope: sameScope,
        ),
      ),
    );
  }

  final String proposedFacility = proposed.resolvedFacilityLabel;
  final String existingFacility =
      (patient.facilityLabel ?? patient.facilityId ?? '').trim();
  if (!keys.contains('FACILITY') &&
      (proposedFacility.isNotEmpty || existingFacility.isNotEmpty)) {
    rows.add(
      AppSimilarityFieldRow(
        key: 'FACILITY',
        label: l10n.patientsFacilityLabel,
        proposedValue: proposedFacility,
        existingValue: existingFacility,
        score: _scopeFieldScore(
          proposed.facilityId,
          patient.facilityId,
          sameScope: sameScope,
        ),
      ),
    );
  }
}

int? _scopeFieldScore(
  String? leftId,
  String? rightId, {
  required bool sameScope,
}) {
  final String? left = _nullIfEmpty(leftId);
  final String? right = _nullIfEmpty(rightId);
  if (left == null && right == null) {
    return null;
  }
  if (left != null && right != null) {
    // Only score conflicts so matching scope cannot fake a full-parameter exact.
    return left == right ? null : 0;
  }
  return sameScope ? null : 0;
}

bool _isIdentityExact(
  PatientDuplicateCandidate duplicate,
  List<AppSimilarityFieldRow> fields,
) {
  if (duplicate.confidenceScore >= 100) {
    return true;
  }
  final List<AppSimilarityFieldRow> scoredIdentity = fields
      .where((AppSimilarityFieldRow field) {
        final String key = field.key.trim().toUpperCase();
        return field.score != null && key != 'TENANT' && key != 'FACILITY';
      })
      .toList(growable: false);
  // Require multiple scored identity parameters so a single matching field
  // does not look like a full-parameter exact duplicate.
  if (scoredIdentity.length >= 2 &&
      scoredIdentity.every(
        (AppSimilarityFieldRow field) => field.score == 100,
      )) {
    return true;
  }
  final List<PatientDuplicateFieldComparison> identityComparisons = duplicate
      .fieldComparisons
      .where((PatientDuplicateFieldComparison comparison) {
        final String key = comparison.field.trim().toUpperCase();
        return key != 'TENANT' && key != 'FACILITY' && key != 'SCOPE';
      })
      .toList(growable: false);
  if (identityComparisons.length >= 2 &&
      identityComparisons.every(
        (PatientDuplicateFieldComparison comparison) =>
            comparison.status.trim().toUpperCase() == 'MATCH',
      )) {
    return true;
  }
  return false;
}

Patient? _candidatePatient(PatientDuplicateCandidate duplicate) {
  return duplicate.secondaryPatient ??
      duplicate.candidatePatient ??
      duplicate.primaryPatient;
}

String? _patientSubtitle({
  required BuildContext context,
  required Locale locale,
  required Patient patient,
  required bool sameScope,
  required AppLocalizations l10n,
}) {
  final String scopeHint = sameScope
      ? ''
      : <String?>[
          patient.facilityLabel ?? patient.facilityId,
          patient.tenantLabel ?? patient.tenantId,
        ].whereType<String>().map((String part) => part.trim()).where((
          String part,
        ) {
          return part.isNotEmpty;
        }).join(' · ');

  final String value = <String?>[
    if (scopeHint.isNotEmpty) scopeHint,
    patient.effectiveIdentifier,
    _dateLabel(context, locale, patient.dateOfBirth),
    _genderLabel(patient.gender),
    patient.primaryPhone,
    patient.primaryEmail,
  ].whereType<String>().map((String part) => part.trim()).where((String part) {
    return part.isNotEmpty;
  }).join(' · ');
  return value.isEmpty ? null : value;
}

int? _comparisonScore(PatientDuplicateFieldComparison comparison) {
  final int? similarityPercent = comparison.similarityPercent;
  return switch (comparison.status.trim().toUpperCase()) {
    'MATCH' => 100,
    'SIMILAR' => similarityPercent,
    'CONFLICT' => similarityPercent ?? 0,
    _ => similarityPercent,
  };
}

String _comparisonFieldLabel(AppLocalizations l10n, String field) {
  return switch (field.trim().toUpperCase()) {
    'NAME' => l10n.patientsNameLabel,
    'DATE_OF_BIRTH' || 'DOB' => l10n.patientsDobLabel,
    'GENDER' => l10n.patientsGenderLabel,
    'PHONE' => l10n.patientsPhoneLabel,
    'EMAIL' => l10n.patientsEmailLabel,
    'IDENTIFIER' => l10n.patientsIdentifierLabel,
    'TENANT' || 'SCOPE' => l10n.profileTenantLabel,
    'FACILITY' => l10n.patientsFacilityLabel,
    _ => AppDisplay.apiLabel(field),
  };
}

String _comparisonValueLabel(
  BuildContext context,
  Locale locale,
  String field,
  String raw,
) {
  final String value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  return switch (field.trim().toUpperCase()) {
    'GENDER' => _genderLabel(value),
    'DATE_OF_BIRTH' || 'DOB' =>
      _dateLabel(context, locale, DateTime.tryParse(value)) ?? value,
    _ => value,
  };
}

String _genderLabel(String? value) {
  final String trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return AppDisplay.apiLabel(trimmed);
}

String? _dateLabel(BuildContext context, Locale locale, DateTime? value) {
  if (value == null) {
    return null;
  }
  return AppFormatters.mediumDate(value, locale);
}

String _identifierLabel(String type, String value) {
  final String normalizedType = type.trim().toUpperCase();
  final String normalizedValue = value.trim();
  if (normalizedType.isEmpty && normalizedValue.isEmpty) {
    return '';
  }
  if (normalizedType.isEmpty) {
    return normalizedValue;
  }
  if (normalizedValue.isEmpty) {
    return normalizedType;
  }
  return '$normalizedType · $normalizedValue';
}

String? _nullIfEmpty(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
