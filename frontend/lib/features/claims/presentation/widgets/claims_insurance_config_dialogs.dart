import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/claims/data/repositories/insurance_catalog_repository.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/controllers/claims_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> openClaimsInsuranceCompanyDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ClaimsReferenceData referenceData,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsAddInsuranceCompanyTitle),
    content: _CreateInsuranceCompanyDialog(
      onSubmit: (Map<String, Object?> payload) async {
        final Result<InsuranceCompanyOption> result = await ref
            .read(insuranceCatalogRepositoryProvider)
            .createCompany(payload);
        return result.when(
          success: (_) async {
            await ref
                .read(claimsWorkspaceControllerProvider.notifier)
                .refresh();
            return null;
          },
          failure: (AppFailure failure) async => failure,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.claimsConfigSavedMessage)),
    );
  }
}

Future<void> openClaimsSchemeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ClaimsReferenceData referenceData,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsAddSchemeTitle),
    content: _CreateSchemeDialog(
      companies: referenceData.insuranceCompanies,
      onSubmit: (Map<String, Object?> payload) async {
        final Result<CoveragePlanOption> result = await ref
            .read(insuranceCatalogRepositoryProvider)
            .createScheme(payload);
        return result.when(
          success: (_) async {
            await ref
                .read(claimsWorkspaceControllerProvider.notifier)
                .refresh();
            return null;
          },
          failure: (AppFailure failure) async => failure,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.claimsConfigSavedMessage)),
    );
  }
}

Future<void> openClaimsSchemeOfferDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ClaimsReferenceData referenceData,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsAddSchemeOfferTitle),
    content: _CreateSchemeOfferDialog(
      companies: referenceData.insuranceCompanies,
      schemes: referenceData.coveragePlans,
      onSubmit: (Map<String, Object?> payload) async {
        final Result<Map<String, Object?>> result = await ref
            .read(insuranceCatalogRepositoryProvider)
            .createSchemeOffer(payload);
        return result.when(
          success: (_) async {
            await ref
                .read(claimsWorkspaceControllerProvider.notifier)
                .refresh();
            return null;
          },
          failure: (AppFailure failure) async => failure,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.claimsConfigSavedMessage)),
    );
  }
}

Future<void> openClaimsEnrollmentDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ClaimsReferenceData referenceData,
  String? patientId,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsAddEnrollmentTitle),
    content: _CreateEnrollmentDialog(
      companies: referenceData.insuranceCompanies,
      schemes: referenceData.coveragePlans,
      initialPatientId: patientId,
      onSubmit: (Map<String, Object?> payload) async {
        final Result<Map<String, Object?>> result = await ref
            .read(insuranceCatalogRepositoryProvider)
            .createEnrollment(payload);
        return result.when(
          success: (Map<String, Object?> enrollment) async {
            final String? enrollmentId =
                enrollment['display_id']?.toString() ??
                enrollment['id']?.toString();
            if (enrollmentId != null && enrollmentId.isNotEmpty) {
              await ref
                  .read(insuranceCatalogRepositoryProvider)
                  .verifyEnrollment(enrollmentId);
            }
            await ref
                .read(claimsWorkspaceControllerProvider.notifier)
                .refresh();
            return null;
          },
          failure: (AppFailure failure) async => failure,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.claimsConfigSavedMessage)),
    );
  }
}

String? _sessionTenantId(WidgetRef ref) {
  return ref.read(sessionStateProvider).session?.user?.tenantId;
}

String? _sessionFacilityId(WidgetRef ref) {
  return ref.read(sessionStateProvider).session?.user?.facilityId;
}

class _CreateInsuranceCompanyDialog extends ConsumerStatefulWidget {
  const _CreateInsuranceCompanyDialog({required this.onSubmit});

  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  ConsumerState<_CreateInsuranceCompanyDialog> createState() =>
      _CreateInsuranceCompanyDialogState();
}

class _CreateInsuranceCompanyDialogState
    extends ConsumerState<_CreateInsuranceCompanyDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppTextField(
          controller: _nameController,
          labelText: l10n.claimsInsuranceCompanyNameLabel,
          isRequired: true,
          validator: AppValidators.requiredText(l10n.claimsInsuranceCompanyNameRequired),
        ),
        AppTextField(
          controller: _codeController,
          labelText: l10n.claimsInsuranceCompanyCodeLabel,
          isRequired: true,
          validator: AppValidators.requiredText(l10n.claimsInsuranceCompanyCodeRequired),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsSaveCompanyAction,
          submitIcon: Icons.business_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? tenantId = _sessionTenantId(ref);
    if (tenantId == null || tenantId.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'tenant_id': tenantId,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().toUpperCase(),
      'is_active': true,
    });
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

class _CreateSchemeDialog extends ConsumerStatefulWidget {
  const _CreateSchemeDialog({
    required this.companies,
    required this.onSubmit,
  });

  final List<InsuranceCompanyOption> companies;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  ConsumerState<_CreateSchemeDialog> createState() => _CreateSchemeDialogState();
}

class _CreateSchemeDialogState extends ConsumerState<_CreateSchemeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _coverageController = TextEditingController(
    text: '80',
  );
  String? _companyId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    if (widget.companies.isNotEmpty) {
      _companyId = widget.companies.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _coverageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppSelectField<String>(
          value: _companyId,
          labelText: l10n.claimsInsuranceCompanyFieldLabel,
          isRequired: true,
          enabled: widget.companies.isNotEmpty,
          validator: AppValidators.requiredValue<String>(
            l10n.claimsInsuranceCompanyRequiredMessage,
          ),
          options: <AppSelectOption<String>>[
            for (final InsuranceCompanyOption company in widget.companies)
              AppSelectOption<String>(value: company.id, label: company.title),
          ],
          onChanged: (String? value) => setState(() => _companyId = value),
        ),
        AppTextField(
          controller: _nameController,
          labelText: l10n.claimsSchemeNameLabel,
          isRequired: true,
          validator: AppValidators.requiredText(l10n.claimsSchemeNameRequired),
        ),
        AppTextField(
          controller: _codeController,
          labelText: l10n.claimsSchemeCodeLabel,
        ),
        AppTextField(
          controller: _coverageController,
          labelText: l10n.claimsSchemeCoveragePercentLabel,
          keyboardType: TextInputType.number,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsSaveSchemeAction,
          submitIcon: Icons.account_balance_outlined,
          isSubmitting: _isSubmitting,
          enabled: widget.companies.isNotEmpty,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? tenantId = _sessionTenantId(ref);
    if (tenantId == null || tenantId.isEmpty || _companyId == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'tenant_id': tenantId,
      'insurance_company_id': _companyId,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().isEmpty
          ? null
          : _codeController.text.trim().toUpperCase(),
      'coverage_percentage':
          int.tryParse(_coverageController.text.trim()) ?? 80,
      'status': 'ACTIVE',
    });
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

class _CreateSchemeOfferDialog extends ConsumerStatefulWidget {
  const _CreateSchemeOfferDialog({
    required this.companies,
    required this.schemes,
    required this.onSubmit,
  });

  final List<InsuranceCompanyOption> companies;
  final List<CoveragePlanOption> schemes;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  ConsumerState<_CreateSchemeOfferDialog> createState() =>
      _CreateSchemeOfferDialogState();
}

class _CreateSchemeOfferDialogState
    extends ConsumerState<_CreateSchemeOfferDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _catalogItemController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _coverageController = TextEditingController();
  String? _companyId;
  String? _schemeId;
  String _catalogType = 'LAB_TEST';
  bool _requiresPreAuth = false;
  bool _isExcluded = false;
  bool _isSubmitting = false;
  AppFailure? _failure;

  List<CoveragePlanOption> get _schemes {
    if (_companyId == null) {
      return widget.schemes;
    }
    return widget.schemes
        .where(
          (CoveragePlanOption plan) => plan.insuranceCompanyId == _companyId,
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    if (widget.companies.isNotEmpty) {
      _companyId = widget.companies.first.id;
    }
    final List<CoveragePlanOption> schemes = _schemes;
    if (schemes.isNotEmpty) {
      _schemeId = schemes.first.apiId;
    }
  }

  @override
  void dispose() {
    _catalogItemController.dispose();
    _unitPriceController.dispose();
    _coverageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<CoveragePlanOption> schemes = _schemes;
    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        if (widget.companies.isNotEmpty)
          AppSelectField<String>(
            value: _companyId,
            labelText: l10n.claimsInsuranceCompanyFieldLabel,
            options: <AppSelectOption<String>>[
              for (final InsuranceCompanyOption company in widget.companies)
                AppSelectOption<String>(
                  value: company.id,
                  label: company.title,
                ),
            ],
            onChanged: (String? value) {
              setState(() {
                _companyId = value;
                final List<CoveragePlanOption> next = widget.schemes
                    .where(
                      (CoveragePlanOption plan) =>
                          plan.insuranceCompanyId == value,
                    )
                    .toList(growable: false);
                _schemeId = next.isEmpty ? null : next.first.apiId;
              });
            },
          ),
        AppSelectField<String>(
          value: _schemeId,
          labelText: l10n.claimsCoverageSchemeFieldLabel,
          isRequired: true,
          enabled: schemes.isNotEmpty,
          validator: AppValidators.requiredValue<String>(
            l10n.claimsCoveragePlanRequiredMessage,
          ),
          options: <AppSelectOption<String>>[
            for (final CoveragePlanOption plan in schemes)
              AppSelectOption<String>(value: plan.apiId, label: plan.title),
          ],
          onChanged: (String? value) => setState(() => _schemeId = value),
        ),
        AppSelectField<String>(
          value: _catalogType,
          labelText: l10n.claimsOfferCatalogTypeLabel,
          options: const <AppSelectOption<String>>[
            AppSelectOption<String>(value: 'LAB_TEST', label: 'Lab test'),
            AppSelectOption<String>(value: 'LAB_PANEL', label: 'Lab panel'),
            AppSelectOption<String>(
              value: 'RADIOLOGY_TEST',
              label: 'Radiology test',
            ),
            AppSelectOption<String>(value: 'DRUG', label: 'Drug'),
            AppSelectOption<String>(
              value: 'CONSULTATION',
              label: 'Consultation',
            ),
            AppSelectOption<String>(value: 'SERVICE', label: 'Service'),
          ],
          onChanged: (String? value) {
            setState(() => _catalogType = value ?? _catalogType);
          },
        ),
        AppTextField(
          controller: _catalogItemController,
          labelText: l10n.claimsOfferCatalogItemLabel,
          isRequired: true,
          validator: AppValidators.requiredText(l10n.claimsOfferCatalogItemRequired),
        ),
        AppTextField(
          controller: _unitPriceController,
          labelText: l10n.claimsOfferTariffLabel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        AppTextField(
          controller: _coverageController,
          labelText: l10n.claimsSchemeCoveragePercentLabel,
          keyboardType: TextInputType.number,
        ),
        CheckboxListTile(
          value: _requiresPreAuth,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l10n.claimsOfferRequiresAuthLabel),
          onChanged: (bool? value) {
            setState(() => _requiresPreAuth = value ?? false);
          },
        ),
        CheckboxListTile(
          value: _isExcluded,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l10n.claimsOfferExcludedLabel),
          onChanged: (bool? value) {
            setState(() => _isExcluded = value ?? false);
          },
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsSaveOfferAction,
          submitIcon: Icons.local_offer_outlined,
          isSubmitting: _isSubmitting,
          enabled: schemes.isNotEmpty,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? tenantId = _sessionTenantId(ref);
    if (tenantId == null || tenantId.isEmpty || _schemeId == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'tenant_id': tenantId,
      'coverage_plan_id': _schemeId,
      'catalog_type': _catalogType,
      'catalog_item_id': _catalogItemController.text.trim(),
      'billing_entity': 'FACILITY',
      'unit_price': num.tryParse(_unitPriceController.text.trim()),
      'coverage_percentage': int.tryParse(_coverageController.text.trim()),
      'requires_pre_auth': _requiresPreAuth,
      'is_excluded': _isExcluded,
      'is_active': true,
    });
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

class _CreateEnrollmentDialog extends ConsumerStatefulWidget {
  const _CreateEnrollmentDialog({
    required this.companies,
    required this.schemes,
    required this.onSubmit,
    this.initialPatientId,
  });

  final List<InsuranceCompanyOption> companies;
  final List<CoveragePlanOption> schemes;
  final String? initialPatientId;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  ConsumerState<_CreateEnrollmentDialog> createState() =>
      _CreateEnrollmentDialogState();
}

class _CreateEnrollmentDialogState
    extends ConsumerState<_CreateEnrollmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();
  String? _companyId;
  String? _schemeId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  List<CoveragePlanOption> get _schemes {
    if (_companyId == null) {
      return widget.schemes;
    }
    return widget.schemes
        .where(
          (CoveragePlanOption plan) => plan.insuranceCompanyId == _companyId,
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    if ((widget.initialPatientId ?? '').isNotEmpty) {
      _patientController.text = widget.initialPatientId!;
    }
    if (widget.companies.isNotEmpty) {
      _companyId = widget.companies.first.id;
    }
    final List<CoveragePlanOption> schemes = _schemes;
    if (schemes.isNotEmpty) {
      _schemeId = schemes.first.apiId;
    }
  }

  @override
  void dispose() {
    _patientController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<CoveragePlanOption> schemes = _schemes;
    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppTextField(
          controller: _patientController,
          labelText: l10n.claimsEnrollmentPatientLabel,
          isRequired: true,
          enabled: (widget.initialPatientId ?? '').isEmpty,
          validator: AppValidators.requiredText(l10n.claimsEnrollmentPatientRequired),
        ),
        if (widget.companies.isNotEmpty)
          AppSelectField<String>(
            value: _companyId,
            labelText: l10n.claimsInsuranceCompanyFieldLabel,
            options: <AppSelectOption<String>>[
              for (final InsuranceCompanyOption company in widget.companies)
                AppSelectOption<String>(
                  value: company.id,
                  label: company.title,
                ),
            ],
            onChanged: (String? value) {
              setState(() {
                _companyId = value;
                final List<CoveragePlanOption> next = widget.schemes
                    .where(
                      (CoveragePlanOption plan) =>
                          plan.insuranceCompanyId == value,
                    )
                    .toList(growable: false);
                _schemeId = next.isEmpty ? null : next.first.apiId;
              });
            },
          ),
        AppSelectField<String>(
          value: _schemeId,
          labelText: l10n.claimsCoverageSchemeFieldLabel,
          isRequired: true,
          enabled: schemes.isNotEmpty,
          validator: AppValidators.requiredValue<String>(
            l10n.claimsCoveragePlanRequiredMessage,
          ),
          options: <AppSelectOption<String>>[
            for (final CoveragePlanOption plan in schemes)
              AppSelectOption<String>(value: plan.apiId, label: plan.title),
          ],
          onChanged: (String? value) => setState(() => _schemeId = value),
        ),
        AppTextField(
          controller: _memberController,
          labelText: l10n.claimsEnrollmentMemberIdLabel,
          isRequired: true,
          validator: AppValidators.requiredText(l10n.claimsEnrollmentMemberIdRequired),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsSaveEnrollmentAction,
          submitIcon: Icons.badge_outlined,
          isSubmitting: _isSubmitting,
          enabled: schemes.isNotEmpty,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? tenantId = _sessionTenantId(ref);
    if (tenantId == null || tenantId.isEmpty || _schemeId == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'tenant_id': tenantId,
      'facility_id': _sessionFacilityId(ref),
      'patient_id': _patientController.text.trim(),
      'coverage_plan_id': _schemeId,
      'member_id': _memberController.text.trim(),
      'status': 'PENDING',
      'is_primary': true,
    });
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

Future<void> openClaimsPriceBookEntryDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ClaimsReferenceData referenceData,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsAddPriceBookTitle),
    content: _CreatePriceBookEntryDialog(
      companies: referenceData.insuranceCompanies,
      schemes: referenceData.coveragePlans,
      onSubmit: (Map<String, Object?> payload) async {
        final Result<Map<String, Object?>> result = await ref
            .read(insuranceCatalogRepositoryProvider)
            .createPriceBookEntry(payload);
        return result.when(
          success: (_) async {
            await ref
                .read(claimsWorkspaceControllerProvider.notifier)
                .refresh();
            return null;
          },
          failure: (AppFailure failure) async => failure,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.claimsConfigSavedMessage)),
    );
  }
}

Future<void> openClaimsInsurerIntegrationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ClaimsReferenceData referenceData,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(l10n.claimsAddInsurerIntegrationTitle),
    content: _CreateInsurerIntegrationDialog(
      companies: referenceData.insuranceCompanies,
      schemes: referenceData.coveragePlans,
      onSubmit: (Map<String, Object?> payload) async {
        final Result<Map<String, Object?>> result = await ref
            .read(insuranceCatalogRepositoryProvider)
            .createInsurerIntegration(payload);
        return result.when(
          success: (_) async {
            await ref
                .read(claimsWorkspaceControllerProvider.notifier)
                .refresh();
            return null;
          },
          failure: (AppFailure failure) async => failure,
        );
      },
    ),
  );
  if (context.mounted && saved == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.claimsConfigSavedMessage)),
    );
  }
}

class _CreatePriceBookEntryDialog extends ConsumerStatefulWidget {
  const _CreatePriceBookEntryDialog({
    required this.companies,
    required this.schemes,
    required this.onSubmit,
  });

  final List<InsuranceCompanyOption> companies;
  final List<CoveragePlanOption> schemes;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  ConsumerState<_CreatePriceBookEntryDialog> createState() =>
      _CreatePriceBookEntryDialogState();
}

class _CreatePriceBookEntryDialogState
    extends ConsumerState<_CreatePriceBookEntryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _catalogItemController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController(
    text: 'UGX',
  );
  String _catalogType = 'LAB_TEST';
  String _paymentMode = 'SELF_PAY';
  String _billingEntity = 'FACILITY';
  String? _companyId;
  String? _schemeId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  List<CoveragePlanOption> get _schemes {
    if (_companyId == null) {
      return widget.schemes;
    }
    return widget.schemes
        .where(
          (CoveragePlanOption plan) => plan.insuranceCompanyId == _companyId,
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _catalogItemController.dispose();
    _unitPriceController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool insurance = _paymentMode == 'INSURANCE';
    final List<CoveragePlanOption> schemes = _schemes;
    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppSelectField<String>(
          value: _paymentMode,
          labelText: l10n.claimsPriceBookPaymentModeLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'SELF_PAY',
              label: l10n.claimsPriceBookSelfPayLabel,
            ),
            AppSelectOption<String>(
              value: 'INSURANCE',
              label: l10n.claimsPriceBookInsuranceLabel,
            ),
          ],
          onChanged: (String? value) {
            setState(() {
              _paymentMode = value ?? _paymentMode;
              if (_paymentMode == 'SELF_PAY') {
                _companyId = null;
                _schemeId = null;
              }
            });
          },
        ),
        if (insurance && widget.companies.isNotEmpty)
          AppSelectField<String>(
            value: _companyId,
            labelText: l10n.claimsInsuranceCompanyFieldLabel,
            options: <AppSelectOption<String>>[
              for (final InsuranceCompanyOption company in widget.companies)
                AppSelectOption<String>(
                  value: company.id,
                  label: company.title,
                ),
            ],
            onChanged: (String? value) {
              setState(() {
                _companyId = value;
                final List<CoveragePlanOption> next = widget.schemes
                    .where(
                      (CoveragePlanOption plan) =>
                          plan.insuranceCompanyId == value,
                    )
                    .toList(growable: false);
                _schemeId = next.isEmpty ? null : next.first.apiId;
              });
            },
          ),
        if (insurance)
          AppSelectField<String>(
            value: _schemeId,
            labelText: l10n.claimsCoverageSchemeFieldLabel,
            enabled: schemes.isNotEmpty,
            options: <AppSelectOption<String>>[
              for (final CoveragePlanOption plan in schemes)
                AppSelectOption<String>(value: plan.apiId, label: plan.title),
            ],
            onChanged: (String? value) => setState(() => _schemeId = value),
          ),
        AppSelectField<String>(
          value: _catalogType,
          labelText: l10n.claimsOfferCatalogTypeLabel,
          options: const <AppSelectOption<String>>[
            AppSelectOption<String>(value: 'LAB_TEST', label: 'Lab test'),
            AppSelectOption<String>(value: 'LAB_PANEL', label: 'Lab panel'),
            AppSelectOption<String>(
              value: 'RADIOLOGY_TEST',
              label: 'Radiology test',
            ),
            AppSelectOption<String>(value: 'DRUG', label: 'Drug'),
            AppSelectOption<String>(
              value: 'CONSULTATION',
              label: 'Consultation',
            ),
            AppSelectOption<String>(value: 'SERVICE', label: 'Service'),
          ],
          onChanged: (String? value) {
            setState(() => _catalogType = value ?? _catalogType);
          },
        ),
        AppTextField(
          controller: _catalogItemController,
          labelText: l10n.claimsOfferCatalogItemLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.claimsOfferCatalogItemRequired,
          ),
        ),
        AppSelectField<String>(
          value: _billingEntity,
          labelText: l10n.claimsPriceBookBillingEntityLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'FACILITY',
              label: l10n.claimsPriceBookFacilityEntityLabel,
            ),
            AppSelectOption<String>(
              value: 'PHARMACY',
              label: l10n.claimsPriceBookPharmacyEntityLabel,
            ),
          ],
          onChanged: (String? value) {
            setState(() => _billingEntity = value ?? _billingEntity);
          },
        ),
        AppTextField(
          controller: _unitPriceController,
          labelText: l10n.claimsOfferTariffLabel,
          isRequired: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: AppValidators.requiredText(
            l10n.claimsPriceBookPriceRequired,
          ),
        ),
        AppTextField(
          controller: _currencyController,
          labelText: l10n.claimsPriceBookCurrencyLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.claimsPriceBookCurrencyRequired,
          ),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsSavePriceBookAction,
          submitIcon: Icons.menu_book_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? tenantId = _sessionTenantId(ref);
    final num? unitPrice = num.tryParse(_unitPriceController.text.trim());
    if (tenantId == null || tenantId.isEmpty || unitPrice == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'tenant_id': tenantId,
      'facility_id': _sessionFacilityId(ref),
      'catalog_type': _catalogType,
      'catalog_item_id': _catalogItemController.text.trim(),
      'payment_mode': _paymentMode,
      'insurance_company_id': _companyId,
      'coverage_plan_id': _schemeId,
      'billing_entity': _billingEntity,
      'unit_price': unitPrice,
      'currency': _currencyController.text.trim().toUpperCase(),
      'is_active': true,
    });
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

class _CreateInsurerIntegrationDialog extends ConsumerStatefulWidget {
  const _CreateInsurerIntegrationDialog({
    required this.companies,
    required this.schemes,
    required this.onSubmit,
  });

  final List<InsuranceCompanyOption> companies;
  final List<CoveragePlanOption> schemes;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  ConsumerState<_CreateInsurerIntegrationDialog> createState() =>
      _CreateInsurerIntegrationDialogState();
}

class _CreateInsurerIntegrationDialogState
    extends ConsumerState<_CreateInsurerIntegrationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  String _adapterType = 'STUB';
  String? _companyId;
  String? _schemeId;
  bool _isEnabled = true;
  bool _isSubmitting = false;
  AppFailure? _failure;

  List<CoveragePlanOption> get _schemes {
    if (_companyId == null) {
      return widget.schemes;
    }
    return widget.schemes
        .where(
          (CoveragePlanOption plan) => plan.insuranceCompanyId == _companyId,
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    if (widget.companies.isNotEmpty) {
      _companyId = widget.companies.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<CoveragePlanOption> schemes = _schemes;
    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppTextField(
          controller: _nameController,
          labelText: l10n.claimsInsurerIntegrationNameLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.claimsInsurerIntegrationNameRequired,
          ),
        ),
        if (widget.companies.isNotEmpty)
          AppSelectField<String>(
            value: _companyId,
            labelText: l10n.claimsInsuranceCompanyFieldLabel,
            options: <AppSelectOption<String>>[
              for (final InsuranceCompanyOption company in widget.companies)
                AppSelectOption<String>(
                  value: company.id,
                  label: company.title,
                ),
            ],
            onChanged: (String? value) {
              setState(() {
                _companyId = value;
                final List<CoveragePlanOption> next = widget.schemes
                    .where(
                      (CoveragePlanOption plan) =>
                          plan.insuranceCompanyId == value,
                    )
                    .toList(growable: false);
                _schemeId = next.isEmpty ? null : next.first.apiId;
              });
            },
          ),
        AppSelectField<String>(
          value: _schemeId,
          labelText: l10n.claimsCoverageSchemeFieldLabel,
          enabled: schemes.isNotEmpty,
          options: <AppSelectOption<String>>[
            for (final CoveragePlanOption plan in schemes)
              AppSelectOption<String>(value: plan.apiId, label: plan.title),
          ],
          onChanged: (String? value) => setState(() => _schemeId = value),
        ),
        AppSelectField<String>(
          value: _adapterType,
          labelText: l10n.claimsInsurerAdapterTypeLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'STUB',
              label: l10n.claimsInsurerAdapterStubLabel,
            ),
            AppSelectOption<String>(
              value: 'GENERIC_REST',
              label: l10n.claimsInsurerAdapterRestLabel,
            ),
          ],
          onChanged: (String? value) {
            setState(() => _adapterType = value ?? _adapterType);
          },
        ),
        AppTextField(
          controller: _baseUrlController,
          labelText: l10n.claimsInsurerBaseUrlLabel,
        ),
        AppTextField(
          controller: _apiKeyController,
          labelText: l10n.claimsInsurerApiKeyLabel,
          obscureText: true,
        ),
        CheckboxListTile(
          value: _isEnabled,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l10n.claimsInsurerEnabledLabel),
          onChanged: (bool? value) {
            setState(() => _isEnabled = value ?? false);
          },
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.claimsSaveInsurerIntegrationAction,
          submitIcon: Icons.vpn_key_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? tenantId = _sessionTenantId(ref);
    if (tenantId == null || tenantId.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final String apiKey = _apiKeyController.text.trim();
    final AppFailure? failure = await widget.onSubmit(<String, Object?>{
      'tenant_id': tenantId,
      'facility_id': _sessionFacilityId(ref),
      'insurance_company_id': _companyId,
      'coverage_plan_id': _schemeId,
      'name': _nameController.text.trim(),
      'adapter_type': _adapterType,
      'base_url': _baseUrlController.text.trim(),
      'is_enabled': _isEnabled,
      if (apiKey.isNotEmpty) 'credentials_encrypted': apiKey,
      'config_json': <String, Object?>{
        if (apiKey.isNotEmpty) 'has_api_key': true,
      },
    });
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}
