import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_catalog_similarity.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_catalog_similarity.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/facility_catalog/facility_catalog_scope.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_similarity_dialog.dart';
import 'package:hosspi_hms/shared/radiology_catalog/radiology_catalog_similarity_dialog.dart';

typedef CatalogTenantOptionsLoader = Future<List<TenantProfile>> Function();
typedef CatalogFacilityOptionsLoader =
    Future<List<FacilityProfile>> Function(String? tenantId);

/// Role-aware visibility for Clinical Services Configure scope step.
@immutable
final class CatalogConfigureScopeVisibility {
  const CatalogConfigureScopeVisibility({
    required this.showTenantSelector,
    required this.showFacilitySelector,
  });

  factory CatalogConfigureScopeVisibility.fromPolicy(AppAccessPolicy policy) {
    final bool showTenantSelector = policy.isElevated;
    final bool showFacilitySelector = policy.isElevated ||
        (policy.canManageTenant() && !policy.hasFacilityContext);
    return CatalogConfigureScopeVisibility(
      showTenantSelector: showTenantSelector,
      showFacilitySelector: showFacilitySelector,
    );
  }

  final bool showTenantSelector;
  final bool showFacilitySelector;

  /// Facility admins (and other fixed-context actors) skip the picker.
  bool get skipPicker => !showTenantSelector && !showFacilitySelector;
}

typedef ClinicalCatalogTermSubmit =
    Future<AppFailure?> Function(Map<String, Object?> payload);

typedef ClinicalCatalogTermUpdateSubmit =
    Future<AppFailure?> Function(String id, Map<String, Object?> payload);

typedef DiagnosisCatalogSearch =
    Future<Result<List<ClinicalCatalogOption>>> Function({
      String? query,
      int limit,
    });

typedef DiagnosisOfferingEnable =
    Future<AppFailure?> Function(ClinicalCatalogOption item);

const List<String> kRadiologyCatalogModalities = <String>[
  'XRAY',
  'CT',
  'MRI',
  'ULTRASOUND',
  'FLUOROSCOPY',
  'MAMMOGRAPHY',
  'PET',
  'NUCLEAR_MEDICINE',
  'INTERVENTIONAL_RADIOLOGY',
  'ECG',
  'ECHO',
  'ENDO',
  'GASTRO',
  'OTHER',
];

Future<FacilityCatalogScopePick?> showCatalogFacilityScopePicker({
  required BuildContext context,
  required CatalogTenantOptionsLoader loadTenants,
  required CatalogFacilityOptionsLoader loadFacilities,
  String? initialTenantId,
  String? initialFacilityId,
  String? title,
  String? body,
  bool showTenantSelector = true,
  bool showFacilitySelector = true,
  bool lockTenant = false,
}) {
  return showAppDialog<FacilityCatalogScopePick>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CatalogFacilityScopePickerDialog(
      loadTenants: loadTenants,
      loadFacilities: loadFacilities,
      initialTenantId: initialTenantId,
      initialFacilityId: initialFacilityId,
      title: title,
      body: body,
      showTenantSelector: showTenantSelector,
      showFacilitySelector: showFacilitySelector,
      lockTenant: lockTenant,
    ),
  );
}

class _CatalogFacilityScopePickerDialog extends StatefulWidget {
  const _CatalogFacilityScopePickerDialog({
    required this.loadTenants,
    required this.loadFacilities,
    required this.showTenantSelector,
    required this.showFacilitySelector,
    required this.lockTenant,
    this.initialTenantId,
    this.initialFacilityId,
    this.title,
    this.body,
  });

  final CatalogTenantOptionsLoader loadTenants;
  final CatalogFacilityOptionsLoader loadFacilities;
  final String? initialTenantId;
  final String? initialFacilityId;
  final String? title;
  final String? body;
  final bool showTenantSelector;
  final bool showFacilitySelector;
  final bool lockTenant;

  @override
  State<_CatalogFacilityScopePickerDialog> createState() =>
      _CatalogFacilityScopePickerDialogState();
}

class _CatalogFacilityScopePickerDialogState
    extends State<_CatalogFacilityScopePickerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<TenantProfile> _tenants = const <TenantProfile>[];
  List<FacilityProfile> _facilities = const <FacilityProfile>[];
  String? _tenantId;
  String? _facilityId;
  AppFailure? _failure;
  bool _isLoadingTenants = true;
  bool _isLoadingFacilities = false;

  bool get _canSubmit {
    final String? tenantId = _tenantId?.trim();
    final String? facilityId = _facilityId?.trim();
    return !_isLoadingTenants &&
        !_isLoadingFacilities &&
        tenantId != null &&
        tenantId.isNotEmpty &&
        facilityId != null &&
        facilityId.isNotEmpty;
  }

  bool get _facilitySelectorEnabled {
    if (!widget.showFacilitySelector) {
      return false;
    }
    if (!widget.showTenantSelector || widget.lockTenant) {
      return true;
    }
    // Elevated: facilities can load without a tenant (facility→tenant fill).
    return true;
  }

  @override
  void initState() {
    super.initState();
    _tenantId = widget.initialTenantId?.trim();
    _facilityId = widget.initialFacilityId?.trim();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    if (widget.showTenantSelector) {
      await _loadTenants();
      return;
    }
    setState(() => _isLoadingTenants = false);
    final String? tenantId = _tenantId;
    if (tenantId != null && tenantId.isNotEmpty) {
      await _loadFacilities(tenantId);
      return;
    }
    if (widget.showFacilitySelector) {
      await _loadFacilities(null);
    }
  }

  Future<void> _loadTenants() async {
    setState(() {
      _isLoadingTenants = true;
      _failure = null;
    });
    try {
      final List<TenantProfile> tenants = await widget.loadTenants();
      if (!mounted) {
        return;
      }
      final String? preferred = _tenantId;
      final String? resolvedTenant =
          (preferred != null &&
              preferred.isNotEmpty &&
              tenants.any((TenantProfile t) => t.id == preferred))
          ? preferred
          : (tenants.length == 1 ? tenants.first.id : preferred);
      setState(() {
        _tenants = tenants;
        _tenantId = resolvedTenant;
        _isLoadingTenants = false;
      });
      if (resolvedTenant != null && resolvedTenant.isNotEmpty) {
        await _loadFacilities(resolvedTenant);
      } else if (widget.showFacilitySelector) {
        await _loadFacilities(null);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingTenants = false;
        _failure = const AppFailure.unexpected();
      });
    }
  }

  Future<void> _loadFacilities(String? tenantId) async {
    setState(() {
      _isLoadingFacilities = true;
      _failure = null;
    });
    try {
      final List<FacilityProfile> facilities = await widget.loadFacilities(
        tenantId?.trim().isEmpty ?? true ? null : tenantId?.trim(),
      );
      if (!mounted) {
        return;
      }
      final String? preferred = _facilityId;
      final String? resolvedFacility =
          (preferred != null &&
              preferred.isNotEmpty &&
              facilities.any((FacilityProfile f) => f.id == preferred))
          ? preferred
          : (facilities.length == 1 ? facilities.first.id : null);
      String? resolvedTenant = _tenantId;
      if (resolvedFacility != null) {
        final FacilityProfile? facility = _findFacility(
          facilities,
          resolvedFacility,
        );
        final String facilityTenant = facility?.tenantId.trim() ?? '';
        if (facilityTenant.isNotEmpty) {
          resolvedTenant = facilityTenant;
        }
      }
      setState(() {
        _facilities = facilities;
        _facilityId = resolvedFacility;
        _tenantId = resolvedTenant;
        _isLoadingFacilities = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _facilities = const <FacilityProfile>[];
        _facilityId = null;
        _isLoadingFacilities = false;
        _failure = const AppFailure.unexpected();
      });
    }
  }

  void _onFacilityChanged(String? value) {
    final String? facilityId = value?.trim();
    if (facilityId == null || facilityId.isEmpty) {
      setState(() => _facilityId = null);
      return;
    }
    final FacilityProfile? facility = _findFacility(_facilities, facilityId);
    final String facilityTenant = facility?.tenantId.trim() ?? '';
    setState(() {
      _facilityId = facilityId;
      if (facilityTenant.isNotEmpty) {
        _tenantId = facilityTenant;
      }
    });
  }

  TenantProfile? _findTenant(List<TenantProfile> tenants, String id) {
    for (final TenantProfile tenant in tenants) {
      if (tenant.id == id) {
        return tenant;
      }
    }
    return null;
  }

  FacilityProfile? _findFacility(List<FacilityProfile> facilities, String id) {
    for (final FacilityProfile facility in facilities) {
      if (facility.id == id) {
        return facility;
      }
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false) || !_canSubmit) {
      return;
    }
    final String? tenantId = _tenantId?.trim();
    final String? facilityId = _facilityId?.trim();
    if (tenantId == null ||
        tenantId.isEmpty ||
        facilityId == null ||
        facilityId.isEmpty) {
      return;
    }
    final TenantProfile? tenant = _findTenant(_tenants, tenantId);
    final FacilityProfile? facility = _findFacility(_facilities, facilityId);
    Navigator.of(context).pop(
      FacilityCatalogScopePick(
        scope: FacilityCatalogScope(
          tenantId: tenantId,
          facilityId: facilityId,
        ),
        tenantCurrency: tenant?.currency,
        facilityCurrency: facility?.currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool tenantEditable =
        widget.showTenantSelector && !widget.lockTenant;
    return AppDialog(
      title: Text(widget.title ?? l10n.accessAdminCreateUserSelectScopeTitle),
      icon: const Icon(Icons.apartment_outlined),
      scrollable: true,
      maxWidth: 560,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            Text(
              widget.body ?? l10n.radiologyConfigurationsSelectScopeBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.showTenantSelector)
              AppSelectField<String>.searchable(
                value: _tenantId,
                labelText: l10n.tenantFacilitySelectTenantLabel,
                isRequired: true,
                enabled: tenantEditable,
                isLoading: _isLoadingTenants,
                options: <AppSelectOption<String>>[
                  for (final TenantProfile tenant in _tenants)
                    AppSelectOption<String>(
                      value: tenant.id,
                      label: tenant.name,
                    ),
                ],
                validator: AppValidators.requiredValue(l10n.validationRequired),
                onChanged: tenantEditable
                    ? (String? value) {
                        setState(() {
                          _tenantId = value;
                          _facilityId = null;
                          _facilities = const <FacilityProfile>[];
                        });
                        if (value != null && value.trim().isNotEmpty) {
                          unawaited(_loadFacilities(value));
                        } else {
                          unawaited(_loadFacilities(null));
                        }
                      }
                    : null,
              ),
            if (widget.showFacilitySelector)
              AppSelectField<String>.searchable(
                value: _facilityId,
                labelText: l10n.tenantFacilityFacilitySelectLabel,
                isRequired: true,
                enabled: _facilitySelectorEnabled,
                isLoading: _isLoadingFacilities,
                options: <AppSelectOption<String>>[
                  for (final FacilityProfile facility in _facilities)
                    AppSelectOption<String>(
                      value: facility.id,
                      label: facility.name,
                    ),
                ],
                validator: AppValidators.requiredValue(l10n.validationRequired),
                onChanged: _onFacilityChanged,
              ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.commonNextActionLabel,
          leadingIcon: Icons.arrow_forward_outlined,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

class RadiologyCatalogMutationDialog extends StatefulWidget {
  const RadiologyCatalogMutationDialog({
    required this.onSubmit,
    this.item,
    this.tenantId,
    this.existingItems = const <RadiologyCatalogProcedure>[],
    this.loadExistingItems,
    super.key,
  });

  final RadiologyCatalogProcedure? item;
  final String? tenantId;
  final List<RadiologyCatalogProcedure> existingItems;
  final Future<List<RadiologyCatalogProcedure>> Function()? loadExistingItems;
  final ClinicalCatalogTermSubmit onSubmit;

  bool get isEditing => item != null;

  @override
  State<RadiologyCatalogMutationDialog> createState() =>
      _RadiologyCatalogMutationDialogState();
}

class _RadiologyCatalogMutationDialogState
    extends State<RadiologyCatalogMutationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late List<RadiologyCatalogProcedure> _existingItems;
  String? _modality;
  AppFailure? _failure;
  String? _nameErrorText;
  String? _codeErrorText;
  bool _isSaving = false;
  bool _isCheckingSimilarity = false;
  bool _isLoadingCatalog = false;
  bool _similarityAccepted = false;
  bool _noSimilarConfirmed = false;

  @override
  void initState() {
    super.initState();
    final RadiologyCatalogProcedure? item = widget.item;
    _existingItems = List<RadiologyCatalogProcedure>.of(widget.existingItems);
    _nameController = TextEditingController(text: item?.name ?? '');
    _codeController = TextEditingController(text: item?.code ?? '');
    _modality = item?.modality?.trim().isNotEmpty == true
        ? item!.modality!.trim().toUpperCase()
        : null;
    _nameController.addListener(_clearSimilarityState);
    _codeController.addListener(_clearSimilarityState);
    final Future<List<RadiologyCatalogProcedure>> Function()? loader =
        widget.loadExistingItems;
    if (loader != null) {
      _isLoadingCatalog = true;
      unawaited(_loadSimilarityCatalog(loader));
    }
  }

  Future<void> _loadSimilarityCatalog(
    Future<List<RadiologyCatalogProcedure>> Function() loader,
  ) async {
    try {
      final List<RadiologyCatalogProcedure> items = await loader();
      if (!mounted) {
        return;
      }
      setState(() {
        _existingItems = items;
        _isLoadingCatalog = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingCatalog = false);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_clearSimilarityState);
    _codeController.removeListener(_clearSimilarityState);
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _clearSimilarityState() {
    if (!_similarityAccepted &&
        !_noSimilarConfirmed &&
        _nameErrorText == null &&
        _codeErrorText == null) {
      return;
    }
    setState(() {
      _similarityAccepted = false;
      _noSimilarConfirmed = false;
      _nameErrorText = null;
      _codeErrorText = null;
    });
  }

  String? get _excludeProcedureId {
    final RadiologyCatalogProcedure? item = widget.item;
    if (item == null) {
      return null;
    }
    final String apiId = item.apiId.trim();
    if (apiId.isNotEmpty) {
      return apiId;
    }
    final String? displayId = item.displayId?.trim();
    if (displayId != null && displayId.isNotEmpty) {
      return displayId;
    }
    return item.id.trim().isEmpty ? null : item.id.trim();
  }

  Future<bool> _guardAgainstDuplicates(AppLocalizations l10n) async {
    final String proposedName = _nameController.text.trim();
    final String proposedCode = _codeController.text.trim();
    final String? proposedModality = _modality;
    final String? excludeProcedureId = _excludeProcedureId;

    setState(() => _isCheckingSimilarity = true);
    // Let the loading indicator paint before the composite scan.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return false;
    }

    late final RadiologyCatalogDuplicateCheckResult result;
    try {
      final List<RadiologyCatalogProcedure> tenantItems = _existingItems
          .where((RadiologyCatalogProcedure item) => !item.isStandard)
          .toList(growable: false);
      final List<RadiologyCatalogProcedure> standardItems = _existingItems
          .where((RadiologyCatalogProcedure item) => item.isStandard)
          .toList(growable: false);
      result = await Future<RadiologyCatalogDuplicateCheckResult>(
        () => mergeRadiologyCatalogDuplicateChecks(
          <RadiologyCatalogDuplicateCheckResult>[
            checkRadiologyCatalogDuplicates(
              name: proposedName,
              code: proposedCode,
              modality: proposedModality,
              existing: tenantItems,
              excludeProcedureId: excludeProcedureId,
            ),
            checkRadiologyCatalogDuplicates(
              name: proposedName,
              code: proposedCode,
              modality: proposedModality,
              existing: standardItems,
              excludeProcedureId: excludeProcedureId,
              includeTokenSimilarity: false,
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingSimilarity = false);
      }
    }
    if (!mounted) {
      return false;
    }

    // Exact clashes block save with clear field errors — no proceed path.
    if (result.hasExactConflict) {
      setState(() {
        _isSaving = false;
        _similarityAccepted = false;
        _noSimilarConfirmed = false;
        _nameErrorText = result.exactNameConflict
            ? l10n.radiologyProcedureNameAlreadyInUse
            : null;
        _codeErrorText = result.exactCodeConflict
            ? l10n.radiologyProcedureCodeAlreadyInUse
            : null;
      });
      return false;
    }

    final List<RadiologyCatalogSimilarityMatch> similarMatches =
        result.nonExactSimilarMatches;
    if (similarMatches.isNotEmpty) {
      if (_similarityAccepted) {
        return true;
      }
      final RadiologyCatalogSimilarityDialogResult dialogResult =
          await showRadiologyCatalogSimilarityDialog(
            context,
            proposed: RadiologyCatalogProposedTest(
              name: proposedName,
              code: proposedCode,
              modality: proposedModality,
            ),
            matches: similarMatches,
            allowProceed: true,
            isEditing: widget.isEditing,
          );
      if (!mounted) {
        return false;
      }

      switch (dialogResult.action) {
        case RadiologyCatalogSimilarityAction.cancel:
          setState(() {
            _isSaving = false;
            _nameErrorText = null;
            _codeErrorText = null;
          });
          return false;
        case RadiologyCatalogSimilarityAction.useExisting:
          final RadiologyCatalogProcedure? existing =
              dialogResult.selectedProcedure;
          if (existing == null) {
            setState(() => _isSaving = false);
            return false;
          }
          Navigator.of(context).pop(existing);
          return false;
        case RadiologyCatalogSimilarityAction.proceed:
          setState(() {
            _similarityAccepted = true;
            _noSimilarConfirmed = false;
            _nameErrorText = null;
            _codeErrorText = null;
          });
          return true;
      }
    }

    if (_noSimilarConfirmed || _similarityAccepted) {
      return true;
    }

    // Edit: skip the extra no-similar confirm so single-field saves stay seamless.
    if (widget.isEditing) {
      return true;
    }

    final bool continueSave = await showRadiologyCatalogNoSimilarDialog(
      context,
      proposed: RadiologyCatalogProposedTest(
        name: proposedName,
        code: proposedCode,
        modality: proposedModality,
      ),
    );
    if (!mounted) {
      return false;
    }
    if (!continueSave) {
      setState(() => _isSaving = false);
      return false;
    }
    setState(() => _noSimilarConfirmed = true);
    return true;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
      _nameErrorText = null;
      _codeErrorText = null;
    });

    final AppLocalizations l10n = context.l10n;
    final bool maySave = await _guardAgainstDuplicates(l10n);
    if (!mounted || !maySave) {
      return;
    }

    final Map<String, Object?> payload = <String, Object?>{
      if (!widget.isEditing) 'tenant_id': widget.tenantId,
      if (_similarityAccepted) 'confirm_similar': true,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'modality': _modality,
    };
    final AppFailure? failure = await widget.onSubmit(payload);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = widget.isEditing
        ? l10n.radiologyEditProcedureDialogTitle
        : l10n.radiologyCreateProcedureAction;
    final IconData iconData =
        widget.isEditing ? Icons.edit_outlined : Icons.add_circle_outline;

    if (_isLoadingCatalog) {
      return AppDialog(
        title: Text(title),
        icon: Icon(iconData),
        maxWidth: 560,
        closeEnabled: true,
        content: SizedBox(
          height: 160,
          child: AppLoadingIndicator.compact(
            title: l10n.labSimilarityCatalogLoadingTitle,
            body: l10n.labSimilarityCatalogLoadingBody,
          ),
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    final bool formLocked = _isSaving || _isCheckingSimilarity;
    return AppDialog(
      title: Text(title),
      icon: Icon(iconData),
      scrollable: true,
      maxWidth: 560,
      closeEnabled: !formLocked,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_isCheckingSimilarity)
              AppFormInformationBanner(
                title: l10n.labSimilarityCheckLoadingTitle,
                message: l10n.labSimilarityCheckLoadingBody,
                variant: AppFormInformationVariant.info,
                icon: Icons.manage_search_outlined,
                children: <Widget>[
                  SizedBox(
                    height: 40,
                    child: AppLoadingIndicator.compact(expand: false),
                  ),
                ],
              ),
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppTextField(
              controller: _nameController,
              labelText: l10n.radiologyProcedureNameLabel,
              enabled: !formLocked,
              isRequired: true,
              errorText: _nameErrorText,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppTextField(
                controller: _codeController,
                labelText: l10n.labTestCodeLabel,
                enabled: !formLocked,
                errorText: _codeErrorText,
              ),
              right: AppSelectField<String>.searchable(
                value: _modality,
                labelText: l10n.radiologyModalityLabel,
                isRequired: true,
                enabled: !formLocked,
                options: <AppSelectOption<String>>[
                  for (final String modality in kRadiologyCatalogModalities)
                    AppSelectOption<String>(value: modality, label: modality),
                ],
                validator: AppValidators.requiredValue(l10n.validationRequired),
                onChanged: (String? value) {
                  setState(() {
                    _modality = value;
                    _similarityAccepted = false;
                    _noSimilarConfirmed = false;
                  });
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: formLocked ? null : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: _isCheckingSimilarity
              ? l10n.radiologySimilarityCheckLoadingTitle
              : l10n.commonSaveActionLabel,
          leadingIcon: Icons.save_outlined,
          isLoading: formLocked,
          onPressed: formLocked ? null : _submit,
        ),
      ],
    );
  }
}

class LabCatalogItemMutationDialog extends StatefulWidget {
  const LabCatalogItemMutationDialog({
    required this.kind,
    required this.onSubmit,
    this.item,
    this.tenantId,
    this.catalogItems = const <LabCatalogItem>[],
    this.loadExistingItems,
    super.key,
  });

  final LabCatalogItemType kind;
  final LabCatalogItem? item;
  final String? tenantId;
  final List<LabCatalogItem> catalogItems;
  final Future<List<LabCatalogItem>> Function()? loadExistingItems;
  final ClinicalCatalogTermSubmit onSubmit;

  bool get isEditing => item != null;

  @override
  State<LabCatalogItemMutationDialog> createState() =>
      _LabCatalogItemMutationDialogState();
}

class _LabCatalogItemMutationDialogState
    extends State<LabCatalogItemMutationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _specimenController;
  late final TextEditingController _unitController;
  late final TextEditingController _descriptionController;
  late List<EditableLabValue> _unitOptions;
  late List<EditableLabValue> _resultOptions;
  late List<EditableLabReferenceRange> _referenceRanges;
  String? _resultKind;
  AppFailure? _failure;
  String? _nameErrorText;
  String? _codeErrorText;
  bool _isSaving = false;
  bool _isCheckingSimilarity = false;
  bool _isLoadingCatalog = false;
  bool _similarityAccepted = false;
  bool _noSimilarConfirmed = false;
  bool _didPrefillAdultLabel = false;
  String? _rangeErrorText;

  late final List<String> _cachedCategoryOptions;
  late final List<String> _cachedSpecimenOptions;
  late final List<LabCatalogItem> _catalogTests;
  late List<LabCatalogItem> _existingItems;

  bool get _isPanel => widget.kind == LabCatalogItemType.panel;

  @override
  void initState() {
    super.initState();
    final LabCatalogItem? item = widget.item;
    _catalogTests = widget.catalogItems
        .where((LabCatalogItem entry) => entry.type == LabCatalogItemType.test)
        .toList(growable: false);
    _existingItems = _catalogTests;
    _nameController = TextEditingController(text: item?.name ?? '');
    _codeController = TextEditingController(text: item?.code ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _specimenController = TextEditingController(text: item?.specimenType ?? '');
    _unitController = TextEditingController(text: item?.unit ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _resultKind = item?.resultKind ?? 'NUMERIC';
    _unitOptions = (item?.unitOptions ?? const <LabUnitOption>[])
        .map(EditableLabValue.fromUnitOption)
        .where((EditableLabValue value) => value.value.trim().isNotEmpty)
        .toList(growable: true);
    _resultOptions = (item?.resultOptions ?? const <LabResultOption>[])
        .map(EditableLabValue.fromResultOption)
        .where((EditableLabValue value) => value.value.trim().isNotEmpty)
        .toList(growable: true);
    final List<LabReferenceRange> existingRanges =
        item?.referenceRanges ?? const <LabReferenceRange>[];
    _referenceRanges = existingRanges.isEmpty
        ? <EditableLabReferenceRange>[
            EditableLabReferenceRange(defaultUnit: item?.unit),
          ]
        : existingRanges
              .map(
                (LabReferenceRange range) => EditableLabReferenceRange(
                  range: range,
                  defaultUnit: item?.unit,
                ),
              )
              .toList(growable: true);
    _cachedCategoryOptions = labUniqueNonEmpty(<String?>[
      ...kLabCatalogCategories,
      for (final LabCatalogItem entry in widget.catalogItems) entry.category,
    ]);
    _cachedSpecimenOptions = labUniqueNonEmpty(<String?>[
      ...kLabCatalogSpecimenTypes,
      for (final LabCatalogItem entry in _catalogTests) entry.specimenType,
    ]);
    _nameController.addListener(_clearSimilarityState);
    _codeController.addListener(_clearSimilarityState);
    _categoryController.addListener(_clearSimilarityState);
    final Future<List<LabCatalogItem>> Function()? loader = widget.loadExistingItems;
    if (loader != null && !_isPanel) {
      _isLoadingCatalog = true;
      unawaited(_loadSimilarityCatalog(loader));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrefillAdultLabel ||
        _isPanel ||
        widget.isEditing ||
        _referenceRanges.isEmpty) {
      return;
    }
    final EditableLabReferenceRange first = _referenceRanges.first;
    if (first.labelController.text.trim().isEmpty) {
      first.labelController.text = context.l10n.labAdultRangeLabel;
    }
    _didPrefillAdultLabel = true;
  }

  @override
  void dispose() {
    _nameController.removeListener(_clearSimilarityState);
    _codeController.removeListener(_clearSimilarityState);
    _categoryController.removeListener(_clearSimilarityState);
    _nameController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    _specimenController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    for (final EditableLabReferenceRange range in _referenceRanges) {
      range.dispose();
    }
    super.dispose();
  }

  void _clearSimilarityState() {
    if (!_similarityAccepted &&
        !_noSimilarConfirmed &&
        _nameErrorText == null &&
        _codeErrorText == null) {
      return;
    }
    setState(() {
      _similarityAccepted = false;
      _noSimilarConfirmed = false;
      _nameErrorText = null;
      _codeErrorText = null;
    });
  }

  String? get _excludeTestId {
    final LabCatalogItem? item = widget.item;
    if (item == null) {
      return null;
    }
    final String apiId = item.apiId.trim();
    if (apiId.isNotEmpty) {
      return apiId;
    }
    final String? displayId = item.displayId?.trim();
    if (displayId != null && displayId.isNotEmpty) {
      return displayId;
    }
    return item.id.trim().isEmpty ? null : item.id.trim();
  }

  Future<void> _loadSimilarityCatalog(
    Future<List<LabCatalogItem>> Function() loader,
  ) async {
    try {
      final List<LabCatalogItem> items = await loader();
      if (!mounted) {
        return;
      }
      setState(() {
        _existingItems = items
            .where(
              (LabCatalogItem e) => e.type == LabCatalogItemType.test,
            )
            .toList(growable: false);
        _isLoadingCatalog = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingCatalog = false);
    }
  }

  Future<bool> _guardAgainstDuplicates(AppLocalizations l10n) async {
    final String proposedName = _nameController.text.trim();
    final String proposedCode = _codeController.text.trim();
    final String proposedCategory = _categoryController.text.trim();
    final String? excludeTestId = _excludeTestId;

    setState(() => _isCheckingSimilarity = true);
    // Let the loading indicator paint before the composite scan.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return false;
    }

    late final LabCatalogDuplicateCheckResult result;
    try {
      final List<LabCatalogItem> tenantItems = _existingItems
          .where((LabCatalogItem item) => !item.isStandard)
          .toList(growable: false);
      final List<LabCatalogItem> standardItems = _existingItems
          .where((LabCatalogItem item) => item.isStandard)
          .toList(growable: false);
      result = await Future<LabCatalogDuplicateCheckResult>(
        () => mergeLabCatalogDuplicateChecks(
          <LabCatalogDuplicateCheckResult>[
            checkLabCatalogDuplicates(
              name: proposedName,
              code: proposedCode,
              category: proposedCategory,
              existing: tenantItems,
              excludeTestId: excludeTestId,
            ),
            checkLabCatalogDuplicates(
              name: proposedName,
              code: proposedCode,
              category: proposedCategory,
              existing: standardItems,
              excludeTestId: excludeTestId,
              includeTokenSimilarity: false,
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingSimilarity = false);
      }
    }
    if (!mounted) {
      return false;
    }

    // Exact clashes block save with clear field errors — no proceed path.
    if (result.hasExactConflict) {
      setState(() {
        _isSaving = false;
        _similarityAccepted = false;
        _noSimilarConfirmed = false;
        _nameErrorText = result.exactNameConflict
            ? l10n.labDuplicateTestNameMessage
            : null;
        _codeErrorText = result.exactCodeConflict
            ? l10n.labDuplicateTestCodeMessage
            : null;
      });
      return false;
    }

    final List<LabCatalogSimilarityMatch> similarMatches =
        result.nonExactSimilarMatches;
    if (similarMatches.isNotEmpty) {
      if (_similarityAccepted) {
        return true;
      }
      final LabCatalogSimilarityDialogResult dialogResult =
          await showLabCatalogSimilarityDialog(
            context,
            proposed: LabCatalogProposedTest(
              name: proposedName,
              code: proposedCode.isEmpty ? null : proposedCode,
              category: proposedCategory.isEmpty ? null : proposedCategory,
            ),
            matches: similarMatches,
            allowProceed: true,
            isEditing: widget.isEditing,
          );
      if (!mounted) {
        return false;
      }

      switch (dialogResult.action) {
        case LabCatalogSimilarityAction.cancel:
          setState(() {
            _isSaving = false;
            _nameErrorText = null;
            _codeErrorText = null;
          });
          return false;
        case LabCatalogSimilarityAction.useExisting:
          final LabCatalogItem? existing = dialogResult.selectedItem;
          if (existing == null) {
            setState(() => _isSaving = false);
            return false;
          }
          Navigator.of(context).pop(existing);
          return false;
        case LabCatalogSimilarityAction.proceed:
          setState(() {
            _similarityAccepted = true;
            _noSimilarConfirmed = false;
            _nameErrorText = null;
            _codeErrorText = null;
          });
          return true;
      }
    }

    if (_noSimilarConfirmed || _similarityAccepted) {
      return true;
    }

    // Edit: skip the extra no-similar confirm so single-field saves stay seamless.
    if (widget.isEditing) {
      return true;
    }

    final bool continueSave = await showLabCatalogNoSimilarDialog(
      context,
      proposed: LabCatalogProposedTest(
        name: proposedName,
        code: proposedCode.isEmpty ? null : proposedCode,
        category: proposedCategory.isEmpty ? null : proposedCategory,
      ),
    );
    if (!mounted) {
      return false;
    }
    if (!continueSave) {
      setState(() => _isSaving = false);
      return false;
    }
    setState(() => _noSimilarConfirmed = true);
    return true;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_isPanel && !_rangesAreValid()) {
      setState(() {
        _failure = AppFailure.validation();
        _rangeErrorText = _rangeValidationMessage(context.l10n);
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
      _nameErrorText = null;
      _codeErrorText = null;
    });

    if (!_isPanel) {
      final AppLocalizations l10n = context.l10n;
      final bool maySave = await _guardAgainstDuplicates(l10n);
      if (!mounted || !maySave) {
        return;
      }
    }

    final AppFailure? failure = await widget.onSubmit(_payload());
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  bool _rangesAreValid() {
    if (labReferenceRangesHaveDuplicateApplicability(_referenceRanges)) {
      return false;
    }
    return _referenceRanges.every(
      (EditableLabReferenceRange range) => range.isValid(),
    );
  }

  String? _rangeValidationMessage(AppLocalizations l10n) {
    if (labReferenceRangesHaveDuplicateApplicability(_referenceRanges)) {
      return l10n.labReferenceRangeDuplicateMessage;
    }
    for (final EditableLabReferenceRange range in _referenceRanges) {
      if (!range.isValid()) {
        if (range.contradictsCriticalVsNormal()) {
          return l10n.labReferenceRangeCriticalVsNormalMessage;
        }
        return l10n.labReferenceRangeInvalidBoundsMessage;
      }
    }
    return null;
  }

  Map<String, Object?> _payload() {
    final Map<String, Object?> payload = <String, Object?>{
      if (!widget.isEditing) 'tenant_id': widget.tenantId,
      if (!_isPanel && _similarityAccepted) 'confirm_similar': true,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'category': _categoryController.text.trim(),
      'description': _descriptionController.text.trim(),
    };
    if (_isPanel) {
      return payload;
    }

    final String unit = _unitController.text.trim();
    final List<Map<String, Object?>> referenceRanges =
        <Map<String, Object?>>[];
    for (int index = 0; index < _referenceRanges.length; index++) {
      final EditableLabReferenceRange range = _referenceRanges[index];
      if (!range.hasContent(unit)) {
        continue;
      }
      referenceRanges.add(
        range.toPayload(sortOrder: referenceRanges.length, fallbackUnit: unit),
      );
    }

    return <String, Object?>{
      ...payload,
      'specimen_type': _specimenController.text.trim(),
      'result_kind': _resultKind,
      'unit': unit,
      'unit_options': _unitOptions
          .asMap()
          .entries
          .map((MapEntry<int, EditableLabValue> entry) {
            return <String, Object?>{
              if (entry.value.id != null) 'id': entry.value.id,
              'unit': entry.value.value,
              'label': entry.value.label ?? entry.value.value,
              'is_default': entry.key == 0,
              'sort_order': entry.key,
            };
          })
          .toList(growable: false),
      'result_options': _resultOptions
          .asMap()
          .entries
          .map((MapEntry<int, EditableLabValue> entry) {
            return <String, Object?>{
              if (entry.value.id != null) 'id': entry.value.id,
              'value': entry.value.value,
              'label': entry.value.label ?? entry.value.value,
              'status': 'NORMAL',
              'sort_order': entry.key,
            };
          })
          .toList(growable: false),
      'reference_ranges': referenceRanges,
    };
  }

  List<String> get _unitOptionsCatalog {
    return labUniqueNonEmpty(<String?>[
      for (final LabCatalogItem item in _catalogTests) item.unit,
      for (final LabCatalogItem item in _catalogTests)
        for (final LabUnitOption option in item.unitOptions)
          option.unit ?? option.label,
      for (final EditableLabValue option in _unitOptions) option.value,
      _unitController.text,
    ]);
  }

  List<String> _resultOptionsCatalog(AppLocalizations l10n) {
    return labUniqueNonEmpty(<String?>[
      l10n.labPositiveOption,
      l10n.labNegativeOption,
      for (final LabCatalogItem item in _catalogTests)
        for (final LabResultOption option in item.resultOptions)
          option.value ?? option.label,
      for (final EditableLabValue option in _resultOptions) option.value,
    ]);
  }

  bool _hasDuplicateName(String? value) {
    final String normalized = labNormalizeCatalogToken(value);
    if (normalized.isEmpty) {
      return false;
    }
    return widget.catalogItems.any(
      (LabCatalogItem item) =>
          !_isCurrentItem(item) &&
          item.type == widget.kind &&
          labNormalizeCatalogToken(item.name) == normalized,
    );
  }

  bool _hasDuplicateCode(String? value) {
    final String normalized = labNormalizeCatalogToken(value);
    if (normalized.isEmpty) {
      return false;
    }
    return widget.catalogItems.any(
      (LabCatalogItem item) =>
          !_isCurrentItem(item) &&
          item.type == widget.kind &&
          labNormalizeCatalogToken(item.code) == normalized,
    );
  }

  bool _isCurrentItem(LabCatalogItem candidate) {
    final LabCatalogItem? item = widget.item;
    if (item == null) {
      return false;
    }
    return candidate.id == item.id ||
        candidate.apiId == item.apiId ||
        candidate.displayId == item.displayId;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = widget.isEditing
        ? (_isPanel
              ? l10n.labUpdatePanelDialogTitle
              : l10n.labUpdateTestDialogTitle)
        : (_isPanel
              ? l10n.labCreatePanelDialogTitle
              : l10n.labCreateTestDialogTitle);
    final IconData iconData =
        widget.isEditing ? Icons.edit_outlined : Icons.add_circle_outline;

    if (_isLoadingCatalog && !_isPanel) {
      return AppDialog(
        title: Text(title),
        icon: Icon(iconData),
        maxWidth: 860,
        closeEnabled: true,
        content: SizedBox(
          height: 160,
          child: AppLoadingIndicator.compact(
            title: l10n.labSimilarityCatalogLoadingTitle,
            body: l10n.labSimilarityCatalogLoadingBody,
          ),
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    final bool formLocked = _isSaving || _isCheckingSimilarity;
    return AppDialog(
      title: Text(title),
      icon: Icon(iconData),
      scrollable: true,
      maxWidth: _isPanel ? 640 : 860,
      closeEnabled: !formLocked,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_isCheckingSimilarity && !_isPanel)
              AppFormInformationBanner(
                title: l10n.labSimilarityCheckLoadingTitle,
                message: l10n.labSimilarityCheckLoadingBody,
                variant: AppFormInformationVariant.info,
                icon: Icons.manage_search_outlined,
                children: <Widget>[
                  SizedBox(
                    height: 40,
                    child: AppLoadingIndicator.compact(expand: false),
                  ),
                ],
              ),
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            if (_isPanel)
              AppFormSection(
                title: l10n.labPanelIdentitySectionTitle,
                description: l10n.labPanelIdentitySectionBody,
                children: <Widget>[
                  AppTextField(
                    controller: _nameController,
                    labelText: l10n.labPanelNameLabel,
                    enabled: !_isSaving,
                    isRequired: true,
                    prefixIcon: const Icon(Icons.science_outlined),
                    validator: (String? value) {
                      final String? requiredFailure =
                          AppValidators.requiredText(
                            l10n.validationRequired,
                          )(value);
                      if (requiredFailure != null) {
                        return requiredFailure;
                      }
                      return _hasDuplicateName(value)
                          ? l10n.labDuplicatePanelNameMessage
                          : null;
                    },
                  ),
                  AppResponsiveFieldRow.two(
                    gap: AppResponsiveFieldRowGap.form,
                    left: AppTextField(
                      controller: _codeController,
                      labelText: l10n.labTestCodeLabel,
                      enabled: !_isSaving,
                      prefixIcon: const Icon(Icons.tag_outlined),
                      validator: (String? value) => _hasDuplicateCode(value)
                          ? l10n.labDuplicatePanelCodeMessage
                          : null,
                    ),
                    right: LabSearchableTextField(
                      controller: _categoryController,
                      labelText: l10n.labCategoryLabel,
                      enabled: !_isSaving,
                      prefixIcon: const Icon(Icons.category_outlined),
                      options: _cachedCategoryOptions,
                    ),
                  ),
                  AppTextField(
                    controller: _descriptionController,
                    labelText: l10n.labPanelDescriptionLabel,
                    enabled: !_isSaving,
                    maxLines: 2,
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                ],
              )
            else
              LabTestDefinitionForm(
                nameController: _nameController,
                codeController: _codeController,
                categoryController: _categoryController,
                specimenController: _specimenController,
                unitController: _unitController,
                descriptionController: _descriptionController,
                resultKind: _resultKind,
                onResultKindChanged: (String? value) =>
                    setState(() => _resultKind = value),
                unitOptions: _unitOptions,
                resultOptions: _resultOptions,
                referenceRanges: _referenceRanges,
                categoryOptions: _cachedCategoryOptions,
                specimenOptions: _cachedSpecimenOptions,
                unitSuggestions: _unitOptionsCatalog,
                resultSuggestions: _resultOptionsCatalog(l10n),
                enabled: !formLocked,
                nameErrorText: _nameErrorText,
                codeErrorText: _codeErrorText,
                rangeErrorText: _rangeErrorText,
                nameValidator: (String? value) {
                  if (_nameErrorText != null) {
                    return _nameErrorText;
                  }
                  return AppValidators.requiredText(l10n.validationRequired)(
                    value,
                  );
                },
                codeValidator: (String? value) => _codeErrorText,
                onUnitOptionAdd: (String value) {
                  setState(
                    () => _unitOptions.add(EditableLabValue(value: value)),
                  );
                },
                onUnitOptionRemove: (EditableLabValue value) {
                  setState(() => _unitOptions.remove(value));
                },
                onResultOptionAdd: (String value) {
                  setState(
                    () =>
                        _resultOptions.add(EditableLabValue(value: value)),
                  );
                },
                onResultOptionRemove: (EditableLabValue value) {
                  setState(() => _resultOptions.remove(value));
                },
                onRangesChanged: () => setState(() => _rangeErrorText = null),
                onRangeAdd: () {
                  final EditableLabReferenceRange next =
                      EditableLabReferenceRange(
                        defaultUnit: _unitController.text.trim(),
                      );
                  final List<EditableLabReferenceRange> proposed =
                      <EditableLabReferenceRange>[
                        ..._referenceRanges,
                        next,
                      ];
                  if (labReferenceRangesHaveDuplicateApplicability(proposed)) {
                    next.dispose();
                    setState(
                      () => _rangeErrorText =
                          l10n.labReferenceRangeDuplicateMessage,
                    );
                    return;
                  }
                  setState(() {
                    _rangeErrorText = null;
                    _referenceRanges.add(next);
                  });
                },
                onRangeRemove: (EditableLabReferenceRange range) {
                  setState(() {
                    range.dispose();
                    _referenceRanges.remove(range);
                    _rangeErrorText = null;
                  });
                },
              ),
          ],
        ),
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: _isCheckingSimilarity && !_isPanel
            ? l10n.labSimilarityCheckLoadingTitle
            : l10n.commonSaveActionLabel,
        submitIcon: Icons.save_outlined,
        isSubmitting: formLocked,
        onCancel: formLocked ? null : () => Navigator.of(context).pop(),
        onSubmit: formLocked ? null : _submit,
      ),
    );
  }
}

class DiagnosisCatalogMutationDialog extends StatefulWidget {
  const DiagnosisCatalogMutationDialog({
    required this.onSubmit,
    this.item,
    this.tenantId,
    super.key,
  });

  final ClinicalCatalogOption? item;
  final String? tenantId;
  final ClinicalCatalogTermSubmit onSubmit;

  bool get isEditing => item != null;

  @override
  State<DiagnosisCatalogMutationDialog> createState() =>
      _DiagnosisCatalogMutationDialogState();
}

class _DiagnosisCatalogMutationDialogState
    extends State<DiagnosisCatalogMutationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _codeController;
  late final TextEditingController _categoryController;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final ClinicalCatalogOption? item = widget.item;
    _descriptionController = TextEditingController(text: item?.name ?? '');
    _codeController = TextEditingController(text: item?.code ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final Map<String, Object?> payload = <String, Object?>{
      if (!widget.isEditing) ...<String, Object?>{
        'tenant_id': widget.tenantId,
        'term_type': 'DIAGNOSIS',
      },
      'description': _descriptionController.text.trim(),
      'code': _codeController.text.trim(),
      'category': _categoryController.text.trim(),
    };
    final AppFailure? failure = await widget.onSubmit(payload);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(
        widget.isEditing
            ? l10n.clinicalEditDiagnosisDialogTitle
            : l10n.clinicalCreateDiagnosisAction,
      ),
      icon: Icon(
        widget.isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
      ),
      scrollable: true,
      maxWidth: 560,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppTextField(
              controller: _descriptionController,
              labelText: l10n.accessAdminColumnName,
              enabled: !_isSaving,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppTextField(
                controller: _codeController,
                labelText: l10n.labTestCodeLabel,
                enabled: !_isSaving,
              ),
              right: AppTextField(
                controller: _categoryController,
                labelText: l10n.labCategoryLabel,
                enabled: !_isSaving,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.commonSaveActionLabel,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _submit,
        ),
      ],
    );
  }
}

class DiagnosisEnableFacilityOfferingDialog extends StatefulWidget {
  const DiagnosisEnableFacilityOfferingDialog({
    required this.scope,
    required this.onSearchCatalog,
    required this.onEnable,
    super.key,
  });

  final FacilityCatalogScope scope;
  final DiagnosisCatalogSearch onSearchCatalog;
  final DiagnosisOfferingEnable onEnable;

  @override
  State<DiagnosisEnableFacilityOfferingDialog> createState() =>
      _DiagnosisEnableFacilityOfferingDialogState();
}

class _DiagnosisEnableFacilityOfferingDialogState
    extends State<DiagnosisEnableFacilityOfferingDialog> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const int _searchLimit = 100;
  static const String _categoryFilterKey = 'category';

  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  List<ClinicalCatalogOption> _catalogItems = const <ClinicalCatalogOption>[];
  final Set<String> _offeredIds = <String>{};
  AppFailure? _failure;
  bool _isSearching = true;
  bool _isEnabling = false;
  int _searchRequest = 0;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;

  List<ClinicalCatalogOption> get _filteredCatalogItems {
    final String? category = _filterValue.option(_categoryFilterKey);
    if (category == null || category.isEmpty) {
      return _catalogItems;
    }
    return _catalogItems
        .where(
          (ClinicalCatalogOption item) =>
              (item.category ?? '').trim() == category,
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchRequest += 1;
    unawaited(_loadCatalog(query: null, requestId: _searchRequest));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog({
    required String? query,
    required int requestId,
  }) async {
    setState(() {
      _isSearching = true;
      _failure = null;
    });
    final Result<List<ClinicalCatalogOption>> result = await widget
        .onSearchCatalog(
          query: query?.trim().isEmpty ?? true ? null : query?.trim(),
          limit: _searchLimit,
        );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    result.when(
      success: (List<ClinicalCatalogOption> items) {
        setState(() {
          _catalogItems = items;
          _isSearching = false;
        });
      },
      failure: (AppFailure value) {
        setState(() {
          _catalogItems = const <ClinicalCatalogOption>[];
          _isSearching = false;
          _failure = value;
        });
      },
    );
  }

  void _scheduleCatalogSearch(String query) {
    _searchDebounce?.cancel();
    _searchRequest += 1;
    final int requestId = _searchRequest;
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_loadCatalog(query: query, requestId: requestId));
    });
  }

  Future<void> _enable(ClinicalCatalogOption item) async {
    if (_offeredIds.contains(item.apiId) || _isEnabling) {
      return;
    }
    setState(() {
      _isEnabling = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onEnable(item);
    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _failure = failure;
        _isEnabling = false;
      });
      return;
    }
    setState(() {
      _offeredIds.add(item.apiId);
      _isEnabling = false;
    });
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<String> categories = _catalogItems
        .map((ClinicalCatalogOption item) => (item.category ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    return AppDialog(
      title: Text(l10n.tenantFacilityCatalogBrowseTitle),
      icon: const Icon(Icons.medical_information_outlined),
      scrollable: true,
      maxWidth: 880,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            Padding(
              padding: EdgeInsets.only(bottom: Theme.of(context).spacing.sm),
              child: AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            ),
          SizedBox(
            height: 480,
            child: AppListTable<ClinicalCatalogOption>(
              items: _filteredCatalogItems,
              isLoading: _isSearching || _isEnabling,
              tableHorizontalMargin: 0,
              columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
              columnVisibilityStorageKey: 'setup_catalog_diagnosis_enable',
              onRowSelected: (ClinicalCatalogOption item) {
                if (_offeredIds.contains(item.apiId)) {
                  return;
                }
                unawaited(_enable(item));
              },
              search: AppListTableSearch<ClinicalCatalogOption>(
                controller: _searchController,
                semanticLabel: l10n.clinicalDiagnosisSearchLabel,
                hintText: l10n.clinicalDiagnosisSearchHint,
                matcher: (ClinicalCatalogOption item, String query) {
                  final String haystack =
                      '${item.name ?? ''} ${item.code ?? ''} ${item.category ?? ''}'
                          .toLowerCase();
                  return haystack.contains(query.toLowerCase());
                },
                onChanged: _scheduleCatalogSearch,
                showAdvancedFilterButton: categories.isNotEmpty,
                advancedFilterButtonLabel: l10n.commonFilterActionLabel,
                advancedFilterTitle: l10n.labCategoryLabel,
                advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                advancedFilterResetLabel: l10n.opdClearFiltersAction,
                enableDateFilter: false,
                filterGroups: <AppSearchBarFilterGroup>[
                  if (categories.isNotEmpty)
                    AppSearchBarFilterGroup(
                      key: _categoryFilterKey,
                      label: l10n.labCategoryLabel,
                      allLabel: l10n.commonAllLabel,
                      choices: <AppSearchBarFilterChoice>[
                        for (final String category in categories)
                          AppSearchBarFilterChoice(
                            value: category,
                            label: category,
                          ),
                      ],
                    ),
                ],
                filterValue: _filterValue,
                hasActiveFilters: _filterValue.isActive,
                onFilterChanged: (AppSearchBarFilterValue value) {
                  setState(() => _filterValue = value);
                },
              ),
              emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
                title: l10n.tenantFacilityCatalogTabDiagnoses,
                body: l10n.clinicalDiagnosisNoCatalogOptions,
              ),
              columns: <AppListTableColumn<ClinicalCatalogOption>>[
                AppListTableColumn<ClinicalCatalogOption>(
                  id: 'name',
                  label: l10n.accessAdminColumnName,
                  cellBuilder: (_, ClinicalCatalogOption item) =>
                      Text(item.displayTitle),
                ),
                AppListTableColumn<ClinicalCatalogOption>(
                  id: 'code',
                  label: l10n.labTestCodeLabel,
                  cellBuilder: (_, ClinicalCatalogOption item) => Text(
                    item.code?.trim().isNotEmpty == true ? item.code! : '—',
                  ),
                ),
                AppListTableColumn<ClinicalCatalogOption>(
                  id: 'category',
                  label: l10n.labCategoryLabel,
                  cellBuilder: (_, ClinicalCatalogOption item) => Text(
                    item.category?.trim().isNotEmpty == true
                        ? item.category!
                        : '—',
                  ),
                ),
                AppListTableColumn<ClinicalCatalogOption>(
                  id: 'actions',
                  label: l10n.accessAdminColumnActions,
                  alwaysVisible: true,
                  cellBuilder: (_, ClinicalCatalogOption item) {
                    final bool offered = _offeredIds.contains(item.apiId);
                    return AppButton.tertiary(
                      label: offered
                          ? l10n.tenantFacilitySummaryConfigured
                          : l10n.clinicalAddDiagnosisAction,
                      leadingIcon: offered
                          ? Icons.check_circle_outline
                          : Icons.add_circle_outline,
                      onPressed: offered || _isEnabling
                          ? null
                          : () => unawaited(_enable(item)),
                    );
                  },
                ),
              ],
              mobileItemBuilder:
                  (BuildContext context, ClinicalCatalogOption item) {
                    return AppListTableMobileItem(
                      title: item.displayTitle,
                      caption: item.category,
                      meta: <AppListTableMobileMeta>[
                        if (item.code?.trim().isNotEmpty == true)
                          AppListTableMobileMeta(label: item.code!),
                      ],
                    );
                  },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
