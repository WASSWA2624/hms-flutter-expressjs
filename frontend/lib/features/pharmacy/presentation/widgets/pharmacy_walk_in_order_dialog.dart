import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/patient_registry_access.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_access.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_patient_actions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

enum _WalkInPatientMode { existing, newPatient, anonymous }

/// Opens the walk-in pharmacy order dialog when the user can write pharmacy.
///
/// Returns the created order workflow on success, otherwise null.
Future<PharmacyOrderWorkflow?> showPharmacyWalkInOrderDialog({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final bool canWrite = canWritePharmacy(ref.read(appAccessPolicyProvider));
  if (!canWrite) {
    return Future<PharmacyOrderWorkflow?>.value();
  }
  return showAppDialog<PharmacyOrderWorkflow>(
    context: context,
    builder: (_) => const PharmacyWalkInOrderDialog(),
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
  static const Duration _drugSearchDebounce = Duration(milliseconds: 250);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<_WalkInLineState> _lines = <_WalkInLineState>[
    _WalkInLineState(),
  ];
  _WalkInPatientMode _patientMode = _WalkInPatientMode.existing;
  Patient? _patient;
  bool _isSaving = false;
  bool _isRegisteringPatient = false;
  AppFailure? _failure;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_searchDrugs(_lines.first, ''));
  }

  @override
  void dispose() {
    for (final _WalkInLineState line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _setPatientMode(_WalkInPatientMode? mode) {
    if (mode == null || mode == _patientMode) {
      return;
    }
    setState(() {
      _patientMode = mode;
      if (mode == _WalkInPatientMode.anonymous) {
        _patient = null;
      }
      _validationMessage = null;
      _failure = null;
    });
  }

  Future<void> _pickPatient() async {
    final Patient? selected = await showReceptionPatientPickerDialog(
      context: context,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _patient = selected;
      _patientMode = _WalkInPatientMode.existing;
      _validationMessage = null;
      _failure = null;
    });
  }

  Future<void> _registerNewPatient() async {
    if (_isRegisteringPatient || _isSaving) {
      return;
    }
    setState(() {
      _isRegisteringPatient = true;
      _failure = null;
      _validationMessage = null;
    });

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
          _failure = failure;
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

    setState(() {
      _isRegisteringPatient = false;
      _patient = registration.patient;
      _patientMode = _WalkInPatientMode.newPatient;
      _failure = null;
      _validationMessage = null;
    });
  }

  void _addLine() {
    setState(() {
      _lines.add(_WalkInLineState());
      _validationMessage = null;
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) {
      return;
    }
    setState(() {
      _lines.removeAt(index).dispose();
      _validationMessage = null;
    });
  }

  Future<void> _searchDrugs(_WalkInLineState line, String raw) async {
    final int generation = ++line.searchGeneration;
    setState(() {
      line.isLoadingDrugs = true;
    });
    final Result<AppPage<PharmacyDrug>> result = await ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .loadDrugPickerPage(search: raw.trim());
    if (!mounted || generation != line.searchGeneration) {
      return;
    }
    result.when(
      success: (AppPage<PharmacyDrug> page) {
        setState(() {
          line.drugOptions = page.items;
          line.isLoadingDrugs = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          line.drugOptions = const <PharmacyDrug>[];
          line.isLoadingDrugs = false;
          _failure = failure;
        });
      },
    );
  }

  void _scheduleDrugSearch(_WalkInLineState line, String raw) {
    line.searchDebounce?.cancel();
    line.searchDebounce = Timer(_drugSearchDebounce, () {
      if (!mounted) {
        return;
      }
      unawaited(_searchDrugs(line, raw));
    });
  }

  String? _patientId(Patient patient) {
    final String id = patient.id.trim();
    if (id.isNotEmpty) {
      return id;
    }
    final String? publicId = patient.publicId?.trim();
    return (publicId == null || publicId.isEmpty) ? null : publicId;
  }

  List<Map<String, Object?>>? _buildItems(AppLocalizations l10n) {
    final List<Map<String, Object?>> items = <Map<String, Object?>>[];
    for (final _WalkInLineState line in _lines) {
      final PharmacyDrug? drug = line.selectedDrug;
      if (drug == null) {
        setState(() {
          _validationMessage = l10n.pharmacyWalkInOrderDrugRequired;
        });
        return null;
      }
      final int? quantity = int.tryParse(line.quantityController.text.trim());
      if (quantity == null || quantity <= 0) {
        setState(() {
          _validationMessage = l10n.pharmacyWalkInOrderQuantityRequired;
        });
        return null;
      }
      final String dosage = line.dosageController.text.trim();
      final String instructions = line.instructionsController.text.trim();
      if (dosage.isEmpty && instructions.isEmpty) {
        setState(() {
          _validationMessage = l10n.pharmacyWalkInOrderDoseRequired;
        });
        return null;
      }
      items.add(<String, Object?>{
        'drug_id': drug.id,
        'quantity': quantity,
        if (dosage.isNotEmpty) 'dosage': dosage,
        if (instructions.isNotEmpty) 'instructions': instructions,
        if (instructions.isNotEmpty && dosage.isEmpty)
          'custom_prescription': instructions,
      });
    }
    return items;
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    String? patientId;
    if (_patientMode == _WalkInPatientMode.anonymous) {
      patientId = null;
    } else {
      final Patient? patient = _patient;
      patientId = patient == null ? null : _patientId(patient);
      if (patientId == null) {
        setState(() {
          _validationMessage = l10n.pharmacyWalkInOrderPatientRequired;
          _failure = null;
        });
        return;
      }
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final List<Map<String, Object?>>? items = _buildItems(l10n);
    if (items == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
      _validationMessage = null;
    });

    final Map<String, Object?> payload = <String, Object?>{
      'ordered_at': DateTime.now().toUtc().toIso8601String(),
      'items': items,
      'patient_id': ?patientId,
    };

    final AppFailure? failure = await ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .createPharmacyOrder(payload);

    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _isSaving = false;
        _failure = failure;
      });
      return;
    }

    final PharmacyOrderWorkflow? workflow = ref
        .read(pharmacyWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (PharmacyWorkspaceState state) => state.selectedWorkflow,
          failure: (_) => null,
        );
    Navigator.of(context).pop(workflow);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canRegisterPatient = canWritePatientRegistry(policy);
    final bool busy = _isSaving || _isRegisteringPatient;
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

    return AppDialog(
      title: Text(l10n.pharmacyWalkInOrderDialogTitle),
      icon: const Icon(Icons.add_shopping_cart_outlined),
      maxWidth: 720,
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !busy,
      content: AppFormShell(
        formKey: _formKey,
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          if (_validationMessage != null)
            AppFormInformationBanner.message(message: _validationMessage!),
          AppFormSection(
            title: l10n.pharmacyPatientColumnLabel,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppRadioGroup<_WalkInPatientMode>(
                value: _patientMode,
                enabled: !busy,
                dense: true,
                layout: AppRadioGroupLayout.wrap,
                presentation: AppRadioGroupPresentation.borderless,
                itemMinWidth: 140,
                options: modeOptions,
                onChanged: busy ? null : _setPatientMode,
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
                      child: Text(
                        patientLabel,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    SizedBox(width: theme.spacing.sm),
                    AppButton.secondary(
                      label: l10n.pharmacyWalkInOrderRegisterPatientAction,
                      leadingIcon: Icons.person_add_outlined,
                      enabled: !busy,
                      isLoading: _isRegisteringPatient,
                      onPressed: busy ? null : _registerNewPatient,
                    ),
                  ],
                )
              else
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        patientLabel,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    SizedBox(width: theme.spacing.sm),
                    AppButton.secondary(
                      label: l10n.commonSelectActionLabel,
                      leadingIcon: Icons.person_search_outlined,
                      enabled: !busy,
                      onPressed: busy ? null : _pickPatient,
                    ),
                  ],
                ),
            ],
          ),
          AppFormSection(
            title: l10n.pharmacyMedicationPanelTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              for (var index = 0; index < _lines.length; index += 1) ...<Widget>[
                if (index > 0) SizedBox(height: theme.spacing.md),
                _WalkInLineFields(
                  line: _lines[index],
                  index: index,
                  canRemove: _lines.length > 1,
                  isSaving: busy,
                  onSearch: (String raw) =>
                      _scheduleDrugSearch(_lines[index], raw),
                  onDrugChanged: (PharmacyDrug? drug) {
                    setState(() {
                      _lines[index].selectedDrug = drug;
                      _validationMessage = null;
                    });
                  },
                  onRemove: () => _removeLine(index),
                ),
              ],
              SizedBox(height: theme.spacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.tertiary(
                  label: l10n.pharmacyWalkInOrderAddLineAction,
                  leadingIcon: Icons.add_outlined,
                  enabled: !busy,
                  onPressed: busy ? null : _addLine,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          enabled: !busy,
          onPressed: busy ? null : () => Navigator.of(context).maybePop(),
        ),
        AppButton.primary(
          label: l10n.pharmacyWalkInOrderSubmitAction,
          leadingIcon: Icons.add_shopping_cart_outlined,
          enabled: !busy,
          isLoading: _isSaving,
          onPressed: busy ? null : _submit,
        ),
      ],
    );
  }
}

class _WalkInLineFields extends StatelessWidget {
  const _WalkInLineFields({
    required this.line,
    required this.index,
    required this.canRemove,
    required this.isSaving,
    required this.onSearch,
    required this.onDrugChanged,
    required this.onRemove,
  });

  final _WalkInLineState line;
  final int index;
  final bool canRemove;
  final bool isSaving;
  final ValueChanged<String> onSearch;
  final ValueChanged<PharmacyDrug?> onDrugChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? selectedId = line.selectedDrug?.id;
    final Map<String, PharmacyDrug> byId = <String, PharmacyDrug>{
      for (final PharmacyDrug drug in line.drugOptions) drug.id: drug,
    };
    final PharmacyDrug? selected = line.selectedDrug;
    if (selected != null) {
      byId[selected.id] = selected;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.pharmacyWalkInOrderLineLabel(index + 1),
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (canRemove)
              AppButton.tertiary(
                label: l10n.commonRemoveActionLabel,
                leadingIcon: Icons.delete_outline,
                enabled: !isSaving,
                onPressed: isSaving ? null : onRemove,
              ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        AppSelectField<String>.searchable(
          value: selectedId,
          labelText: l10n.pharmacyWalkInOrderDrugLabel,
          isRequired: true,
          enabled: !isSaving,
          isLoading: line.isLoadingDrugs,
          options: <AppSelectOption<String>>[
            for (final PharmacyDrug drug in byId.values)
              AppSelectOption<String>(
                value: drug.id,
                label: drug.displayTitle,
                searchText: <String?>[
                  drug.displayTitle,
                  drug.code,
                  drug.genericName,
                  drug.brandName,
                ].whereType<String>().join(' '),
              ),
          ],
          validator: AppValidators.requiredValue(l10n.validationRequired),
          onSearchTextChanged: onSearch,
          onChanged: (String? value) {
            onDrugChanged(value == null ? null : byId[value]);
          },
        ),
        SizedBox(height: theme.spacing.xs),
        AppResponsiveFieldRow(
          children: <Widget>[
            AppTextField(
              controller: line.quantityController,
              labelText: l10n.pharmacyQuantityFieldLabel,
              isRequired: true,
              enabled: !isSaving,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: line.dosageController,
              labelText: l10n.pharmacyDoseColumnLabel,
              enabled: !isSaving,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        AppTextField(
          controller: line.instructionsController,
          labelText: l10n.clinicalInstructionsLabel,
          enabled: !isSaving,
          maxLines: 2,
        ),
      ],
    );
  }
}

class _WalkInLineState {
  _WalkInLineState()
    : quantityController = TextEditingController(text: '1'),
      dosageController = TextEditingController(),
      instructionsController = TextEditingController();

  final TextEditingController quantityController;
  final TextEditingController dosageController;
  final TextEditingController instructionsController;
  PharmacyDrug? selectedDrug;
  List<PharmacyDrug> drugOptions = const <PharmacyDrug>[];
  bool isLoadingDrugs = false;
  int searchGeneration = 0;
  Timer? searchDebounce;

  void dispose() {
    searchDebounce?.cancel();
    quantityController.dispose();
    dosageController.dispose();
    instructionsController.dispose();
  }
}
