import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/claims/data/repositories/insurance_catalog_repository.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/patient_registry_access.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_access.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_patient_actions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

enum _WalkInPatientMode { existing, newPatient, anonymous }

/// Opens the pharmacy Create order dialog when the user can write pharmacy.
///
/// Reuses the clinical Prescribe medicines workflow. Returns the created order
/// workflow on success, otherwise null.
Future<PharmacyOrderWorkflow?> showPharmacyWalkInOrderDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final bool canWrite = canWritePharmacy(ref.read(appAccessPolicyProvider));
  if (!canWrite) {
    return null;
  }
  final bool? created = await showAppDialog<bool>(
    context: context,
    builder: (_) => const PharmacyWalkInOrderDialog(),
  );
  if (created != true) {
    return null;
  }
  return ref
      .read(pharmacyWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (PharmacyWorkspaceState state) => state.selectedWorkflow,
        failure: (_) => null,
      );
}

class PharmacyWalkInOrderDialog extends ConsumerStatefulWidget {
  const PharmacyWalkInOrderDialog({super.key});

  @override
  ConsumerState<PharmacyWalkInOrderDialog> createState() =>
      _PharmacyWalkInOrderDialogState();
}

class _PharmacyWalkInOrderDialogState
    extends ConsumerState<PharmacyWalkInOrderDialog> {
  _WalkInPatientMode _patientMode = _WalkInPatientMode.anonymous;
  Patient? _patient;
  ClinicalRequestPayerContext? _payerContext;
  ClinicalActionReferenceData? _referenceData;
  bool _loadingReference = true;
  bool _isRegisteringPatient = false;
  AppFailure? _loadFailure;

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    setState(() {
      _loadingReference = true;
      _loadFailure = null;
    });
    final Result<ClinicalReferenceData> result = await ref
        .read(clinicalRepositoryProvider)
        .loadReferenceData();
    if (!mounted) {
      return;
    }
    result.when(
      success: (ClinicalReferenceData data) {
        setState(() {
          _referenceData = ClinicalActionReferenceData(drugs: data.drugs);
          _loadingReference = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loadFailure = failure;
          _loadingReference = false;
        });
      },
    );
  }

  bool get _billingEnabled =>
      _patientMode != _WalkInPatientMode.anonymous && _patient != null;

  void _setPatientMode(_WalkInPatientMode? mode) {
    if (mode == null || mode == _patientMode) {
      return;
    }
    setState(() {
      _patientMode = mode;
      if (mode == _WalkInPatientMode.anonymous) {
        _patient = null;
        _payerContext = null;
      }
    });
  }

  Future<void> _applyPatient(Patient patient, _WalkInPatientMode mode) async {
    setState(() {
      _patient = patient;
      _patientMode = mode;
      _payerContext = null;
    });
    final String? patientId = _patientId(patient);
    if (patientId == null) {
      return;
    }
    final ClinicalRequestPayerContext? payer = await ref
        .read(insuranceCatalogRepositoryProvider)
        .resolvePayerContextForPatient(patientId);
    if (!mounted) {
      return;
    }
    setState(() => _payerContext = payer);
  }

  Future<void> _pickPatient() async {
    final Patient? selected = await showReceptionPatientPickerDialog(
      context: context,
    );
    if (!mounted || selected == null) {
      return;
    }
    await _applyPatient(selected, _WalkInPatientMode.existing);
  }

  Future<void> _registerNewPatient() async {
    if (_isRegisteringPatient) {
      return;
    }
    setState(() => _isRegisteringPatient = true);

    final Result<PatientReferenceData> referenceResult = await ref
        .read(patientRepositoryProvider)
        .loadReferenceData();
    if (!mounted) {
      return;
    }
    final PatientReferenceData? referenceData = referenceResult.when(
      success: (PatientReferenceData data) => data,
      failure: (AppFailure failure) {
        setState(() {
          _isRegisteringPatient = false;
          _loadFailure = failure;
        });
        return null;
      },
    );
    if (referenceData == null || !mounted) {
      return;
    }

    final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
    final PatientRegistrationResult? registration =
        await showRegisterNewPatientDialog(
          context: context,
          referenceData: referenceData,
          registrationScope: PatientRegistrationScope.resolve(
            referenceData: referenceData,
            accessPolicy: accessPolicy,
          ),
          onSubmit: (Map<String, Object?> payload) {
            return ref.read(patientRepositoryProvider).createPatient(payload);
          },
          onLookupDuplicates: (PatientDuplicateQuery query) {
            return ref
                .read(patientRepositoryProvider)
                .listDuplicateCandidates(query);
          },
        );
    if (!mounted) {
      return;
    }
    if (registration == null) {
      setState(() => _isRegisteringPatient = false);
      return;
    }

    setState(() => _isRegisteringPatient = false);
    await _applyPatient(registration.patient, _WalkInPatientMode.newPatient);
  }

  String? _patientId(Patient patient) {
    final String id = patient.id.trim();
    if (id.isNotEmpty) {
      return id;
    }
    final String? publicId = patient.publicId?.trim();
    return (publicId == null || publicId.isEmpty) ? null : publicId;
  }

  Future<AppFailure?> _submitCreateOrder({
    required List<Map<String, Object?>> items,
    ClinicalRequestBillingSubmit? billing,
  }) async {
    final AppLocalizations l10n = context.l10n;
    String? patientId;
    if (_patientMode != _WalkInPatientMode.anonymous) {
      final Patient? patient = _patient;
      patientId = patient == null ? null : _patientId(patient);
      if (patientId == null) {
        return AppFailure.validation(
          detailMessage: l10n.pharmacyWalkInOrderPatientRequired,
        );
      }
    }

    final Map<String, Object?> payload = mergeClinicalRequestBilling(
      <String, Object?>{
        'ordered_at': DateTime.now().toUtc().toIso8601String(),
        'items': items,
        'patient_id': ?patientId,
      },
      _billingEnabled ? billing : null,
    );

    return ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .createPharmacyOrder(payload);
  }

  Widget _buildPatientHeader(AppLocalizations l10n, ThemeData theme) {
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canRegisterPatient = canWritePatientRegistry(policy);
    final Patient? patient = _patient;
    final String patientLabel = patient == null
        ? l10n.receptionPatientPickerTitle
        : () {
            final String name = patient.effectiveDisplayName.trim();
            final String? identifier = patient.effectiveIdentifier?.trim();
            if (identifier == null || identifier.isEmpty) {
              return name.isEmpty ? l10n.receptionPatientPickerTitle : name;
            }
            if (name.isEmpty) {
              return identifier;
            }
            return '$name • $identifier';
          }();

    final List<AppRadioOption<_WalkInPatientMode>> modeOptions =
        <AppRadioOption<_WalkInPatientMode>>[
          AppRadioOption<_WalkInPatientMode>(
            value: _WalkInPatientMode.existing,
            label: l10n.pharmacyWalkInOrderPatientModeExisting,
          ),
          if (canRegisterPatient)
            AppRadioOption<_WalkInPatientMode>(
              value: _WalkInPatientMode.newPatient,
              label: l10n.pharmacyWalkInOrderPatientModeNew,
            ),
          AppRadioOption<_WalkInPatientMode>(
            value: _WalkInPatientMode.anonymous,
            label: l10n.pharmacyWalkInOrderPatientModeAnonymous,
          ),
        ];

    return AppFormSection(
      title: l10n.pharmacyPatientColumnLabel,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        AppRadioGroup<_WalkInPatientMode>(
          value: _patientMode,
          enabled: !_isRegisteringPatient,
          dense: true,
          layout: AppRadioGroupLayout.wrap,
          presentation: AppRadioGroupPresentation.borderless,
          itemMinWidth: 140,
          options: modeOptions,
          onChanged: _isRegisteringPatient ? null : _setPatientMode,
        ),
        SizedBox(height: theme.spacing.sm),
        if (_patientMode == _WalkInPatientMode.anonymous)
          Text(
            l10n.pharmacyWalkInOrderAnonymousHint,
            style: theme.textTheme.bodyMedium,
          )
        else if (_patientMode == _WalkInPatientMode.newPatient)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(patientLabel, style: theme.textTheme.bodyLarge),
              ),
              SizedBox(width: theme.spacing.sm),
              AppButton.secondary(
                label: l10n.pharmacyWalkInOrderRegisterPatientAction,
                leadingIcon: Icons.person_add_outlined,
                enabled: !_isRegisteringPatient,
                isLoading: _isRegisteringPatient,
                onPressed: _isRegisteringPatient ? null : _registerNewPatient,
              ),
            ],
          )
        else
          Row(
            children: <Widget>[
              Expanded(
                child: Text(patientLabel, style: theme.textTheme.bodyLarge),
              ),
              SizedBox(width: theme.spacing.sm),
              AppButton.secondary(
                label: l10n.commonSelectActionLabel,
                leadingIcon: Icons.person_search_outlined,
                enabled: !_isRegisteringPatient,
                onPressed: _isRegisteringPatient ? null : _pickPatient,
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (_loadingReference) {
      return AppDialog(
        title: Text(l10n.pharmacyWalkInOrderDialogTitle),
        icon: const Icon(Icons.add_shopping_cart_outlined),
        maxWidth: 880,
        content: const Center(
          child: AppLoadingIndicator(
            size: AppLoadingIndicatorSize.compact,
            expand: false,
          ),
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      );
    }

    if (_loadFailure != null || _referenceData == null) {
      return AppDialog(
        title: Text(l10n.pharmacyWalkInOrderDialogTitle),
        icon: const Icon(Icons.add_shopping_cart_outlined),
        maxWidth: 720,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFormInformationBanner.failure(
              context: context,
              failure: _loadFailure ?? const AppFailure.unexpected(),
            ),
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton.secondary(
            label: l10n.commonRetryActionLabel,
            onPressed: _loadReferenceData,
          ),
        ],
      );
    }

    return ClinicalPrescriptionActionDialog(
      key: const ValueKey<String>('pharmacy-create-order-rx'),
      referenceData: _referenceData!,
      payerContext: _billingEnabled ? _payerContext : null,
      header: _buildPatientHeader(l10n, theme),
      dialogTitle: l10n.pharmacyWalkInOrderDialogTitle,
      submitLabel: l10n.pharmacyWalkInOrderSubmitAction,
      dialogIcon: Icons.add_shopping_cart_outlined,
      enableBilling: _billingEnabled,
      defaultBillingEntity: 'PHARMACY',
      onSubmit: _submitCreateOrder,
    );
  }
}
