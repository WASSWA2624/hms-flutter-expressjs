import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_catalog_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_drug_catalog_options.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_pack_scan_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_similarity_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/scan/scan.dart';

final class PharmacyDrugFormResult {
  const PharmacyDrugFormResult._({
    required this.saved,
    required this.useExisting,
    this.drug,
  });

  const PharmacyDrugFormResult.cancelled()
    : this._(saved: false, useExisting: false);

  const PharmacyDrugFormResult.saved(PharmacyDrug drug)
    : this._(saved: true, useExisting: false, drug: drug);

  const PharmacyDrugFormResult.useExisting(PharmacyDrug drug)
    : this._(saved: false, useExisting: true, drug: drug);

  final bool saved;
  final bool useExisting;
  final PharmacyDrug? drug;
}

class PharmacyDrugEditDialog extends ConsumerStatefulWidget {
  const PharmacyDrugEditDialog({this.drug, super.key});

  final PharmacyDrug? drug;

  @override
  ConsumerState<PharmacyDrugEditDialog> createState() =>
      _PharmacyDrugEditDialogState();
}

class _PharmacyDrugEditDialogState
    extends ConsumerState<PharmacyDrugEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _brandNameController;
  late final TextEditingController _genericNameController;
  late final TextEditingController _codeController;
  late final TextEditingController _pharmacyPriceController;
  late final TextEditingController _facilityPriceController;
  late final TextEditingController _initialStockController;
  late final TextEditingController _reorderLevelController;
  late final TextEditingController _batchNumberController;
  late String _pharmacyCurrency;
  late String _facilityCurrency;
  String? _form;
  String? _strength;
  String? _inventoryUnit;
  String? _storageRoomId;
  String? _storageShelfId;
  int? _expiryAlertLeadDays;
  DateTime? _manufacturedAt;
  DateTime? _expiryDate;
  bool _isSaving = false;
  final AppSuggestedFieldSet _suggestions = AppSuggestedFieldSet();

  bool get _isEdit => widget.drug != null;

  @override
  void initState() {
    super.initState();
    final PharmacyDrug? drug = widget.drug;
    _brandNameController = TextEditingController(text: drug?.brandName ?? '');
    final String generic = (drug?.genericName ?? '').trim();
    final String legacyName = (drug?.name ?? '').trim();
    _genericNameController = TextEditingController(
      text: generic.isNotEmpty ? generic : legacyName,
    );
    _codeController = TextEditingController(text: drug?.code ?? '');
    _form = _emptyToNull(drug?.form ?? '');
    _strength = _emptyToNull(drug?.strength ?? '');
    _pharmacyPriceController = TextEditingController(
      text: _priceText(drug?.pharmacyUnitPrice ?? drug?.unitPrice),
    );
    _facilityPriceController = TextEditingController(
      text: _priceText(drug?.facilityUnitPrice),
    );
    _pharmacyCurrency =
        drug?.pharmacyCurrency ?? drug?.currency ?? appDefaultCurrencyCode;
    _facilityCurrency =
        drug?.facilityCurrency ?? drug?.currency ?? appDefaultCurrencyCode;
    _initialStockController = TextEditingController();
    final num? existingReorderLevel = drug?.stockRows.isNotEmpty == true
        ? drug!.stockRows.first.reorderLevel
        : null;
    _reorderLevelController = TextEditingController(
      text: existingReorderLevel != null && existingReorderLevel > 0
          ? existingReorderLevel.toString()
          : '',
    );
    _storageRoomId = drug?.storageRoomId;
    _storageShelfId = drug?.storageShelfId;
    _batchNumberController = TextEditingController();
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _genericNameController.dispose();
    _codeController.dispose();
    _pharmacyPriceController.dispose();
    _facilityPriceController.dispose();
    _initialStockController.dispose();
    _reorderLevelController.dispose();
    _batchNumberController.dispose();
    super.dispose();
  }

  void _onFormChanged(String? value) {
    setState(() {
      _form = value;
      if (_suggestions.isSuggested(PharmacyDrugSuggestedFields.form)) {
        _suggestions.edit(PharmacyDrugSuggestedFields.form);
      }
      if (_form == null) {
        _strength = null;
        return;
      }
      final String? defaultUnit = pharmacyDefaultInventoryUnitForForm(_form);
      if (defaultUnit != null) {
        _inventoryUnit = defaultUnit;
      }
      if (_strength != null &&
          !pharmacyStrengthSuggestionsForForm(_form).contains(_strength)) {
        _strength = null;
      }
    });
  }

  Future<void> _openStorageConfiguration() async {
    await openPharmacyCatalogDialog(
      context,
      ref,
      initialTab: PharmacyCatalogTab.storageLayout,
    );
  }

  Future<void> _openPackScan() async {
    final DrugPackFieldCandidates? candidates =
        await showPharmacyDrugPackScanDialog(context);
    if (!mounted || candidates == null || !candidates.hasAnyIdentityField) {
      return;
    }
    setState(() {
      final List<String> suggested = <String>[];
      if ((candidates.genericName ?? '').trim().isNotEmpty) {
        _genericNameController.text = candidates.genericName!.trim();
        suggested.add(PharmacyDrugSuggestedFields.genericName);
      }
      if ((candidates.brandName ?? '').trim().isNotEmpty) {
        _brandNameController.text = candidates.brandName!.trim();
        suggested.add(PharmacyDrugSuggestedFields.brandName);
      }
      if ((candidates.code ?? '').trim().isNotEmpty) {
        _codeController.text = candidates.code!.trim();
        suggested.add(PharmacyDrugSuggestedFields.code);
      }
      if ((candidates.form ?? '').trim().isNotEmpty) {
        _form = candidates.form!.trim();
        suggested.add(PharmacyDrugSuggestedFields.form);
        final String? defaultUnit = pharmacyDefaultInventoryUnitForForm(_form);
        if (defaultUnit != null) {
          _inventoryUnit = defaultUnit;
        }
      }
      if ((candidates.strength ?? '').trim().isNotEmpty) {
        _strength = candidates.strength!.trim();
        suggested.add(PharmacyDrugSuggestedFields.strength);
      }
      if ((candidates.batchNumber ?? '').trim().isNotEmpty) {
        _batchNumberController.text = candidates.batchNumber!.trim();
        suggested.add(PharmacyDrugSuggestedFields.batchNumber);
      }
      if (candidates.manufacturedAt != null) {
        _manufacturedAt = candidates.manufacturedAt;
        suggested.add(PharmacyDrugSuggestedFields.manufacturedAt);
      }
      if (candidates.expiryDate != null) {
        _expiryDate = candidates.expiryDate;
        suggested.add(PharmacyDrugSuggestedFields.expiryDate);
      }
      _suggestions.markAll(suggested);
    });
  }

  Widget _suggestedChrome({
    required String fieldKey,
    required AppLocalizations l10n,
    required ThemeData theme,
    required Widget child,
  }) {
    final bool suggested = _suggestions.isSuggested(fieldKey);
    if (!suggested) {
      return child;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.radius.md),
            border: Border.all(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.7),
              width: 1.5,
            ),
            color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.xs),
            child: child,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Wrap(
          spacing: theme.spacing.xs,
          children: <Widget>[
            AppButton.tertiary(
              label: l10n.pharmacyDrugAcceptSuggestionAction,
              leadingIcon: Icons.check,
              dense: true,
              enabled: !_isSaving,
              onPressed: () => setState(() => _suggestions.accept(fieldKey)),
            ),
            AppButton.tertiary(
              label: l10n.pharmacyDrugEditSuggestionAction,
              leadingIcon: Icons.edit_outlined,
              dense: true,
              enabled: !_isSaving,
              onPressed: () => setState(() => _suggestions.edit(fieldKey)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageLocationSection({
    required AppLocalizations l10n,
    required ThemeData theme,
    required List<PharmacyStorageRoom> activeRooms,
    required List<PharmacyStorageShelf> shelfOptions,
  }) {
    return AppFormSection(
      title: l10n.pharmacyDrugStorageSectionTitle,
      description: l10n.pharmacyDrugStorageSectionHelper,
      children: <Widget>[
        if (activeRooms.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.pharmacyNoStorageRoomsBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              AppButton.tertiary(
                label: l10n.pharmacyConfigureStorageAction,
                leadingIcon: Icons.warehouse_outlined,
                enabled: !_isSaving,
                onPressed: _openStorageConfiguration,
              ),
            ],
          )
        else
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppSelectField<String>(
              value: _storageRoomId,
              labelText: l10n.pharmacyStorageRoomLabel,
              enabled: !_isSaving,
              options: activeRooms
                  .map(
                    (PharmacyStorageRoom room) => AppSelectOption<String>(
                      value: room.id,
                      label: room.name ?? room.id,
                    ),
                  )
                  .toList(growable: false),
              onChanged: (String? value) {
                setState(() {
                  _storageRoomId = value;
                  final List<PharmacyStorageShelf> nextShelves = activeRooms
                      .where((PharmacyStorageRoom room) => room.id == value)
                      .expand((PharmacyStorageRoom room) => room.shelves)
                      .where((PharmacyStorageShelf shelf) => shelf.isActive)
                      .toList(growable: false);
                  if (_storageShelfId != null &&
                      !nextShelves.any(
                        (PharmacyStorageShelf shelf) =>
                            shelf.id == _storageShelfId,
                      )) {
                    _storageShelfId = null;
                  }
                });
              },
            ),
            right: AppSelectField<String>(
              value: _storageShelfId,
              labelText: l10n.pharmacyStorageShelfLabel,
              enabled: !_isSaving && _storageRoomId != null,
              options: shelfOptions
                  .map(
                    (PharmacyStorageShelf shelf) => AppSelectOption<String>(
                      value: shelf.id,
                      label: shelf.displayLabel,
                    ),
                  )
                  .toList(growable: false),
              onChanged: (String? value) =>
                  setState(() => _storageShelfId = value),
            ),
          ),
      ],
    );
  }

  String? _resolveInventoryItemId(PharmacyDrug drug) {
    for (final PharmacyDrugStockMapping mapping in drug.stockMappings) {
      final String? inventoryItemId = mapping.inventoryItemId;
      if (inventoryItemId != null && inventoryItemId.isNotEmpty) {
        return inventoryItemId;
      }
    }
    for (final PharmacyInventoryStock stock in drug.stockRows) {
      final String? inventoryItemId = stock.inventoryItemId;
      if (inventoryItemId != null && inventoryItemId.isNotEmpty) {
        return inventoryItemId;
      }
    }
    return null;
  }

  PharmacyFacilityOfferingInput? _buildFacilityOfferingInput(
    PharmacyWorkspaceController controller,
    num? facilityPrice,
  ) {
    final num? offeringPrice =
        facilityPrice ??
        widget.drug?.facilityUnitPrice ??
        widget.drug?.pharmacyUnitPrice ??
        widget.drug?.unitPrice;
    final bool shouldUpsertOffering =
        facilityPrice != null ||
        _storageShelfId != null ||
        widget.drug?.storageShelfId != null;
    if (!shouldUpsertOffering || offeringPrice == null) {
      return null;
    }
    return PharmacyFacilityOfferingInput(
      unitPrice: offeringPrice,
      currency: _facilityCurrency,
      facilityId: controller.resolveFacilityId(),
      defaultStorageShelfId: _storageShelfId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<AppSelectOption<String>> formOptions =
        pharmacyDrugFormSelectOptions(l10n);
    final List<AppSelectOption<String>> strengthOptions =
        pharmacyStrengthSelectOptions(_form);
    final List<AppSelectOption<String>> unitOptions =
        pharmacyInventoryUnitSelectOptions(l10n, form: _form);
    final String? inventoryUnitLabel = pharmacyInventoryUnitDisplayLabel(
      l10n,
      _inventoryUnit,
    );
    final List<PharmacyExpiryAlertLeadOption> expiryLeadOptions =
        pharmacyExpiryAlertLeadOptions(l10n);
    final PharmacyStorageLayout storageLayout =
        ref
            .watch(pharmacyWorkspaceControllerProvider)
            .value
            ?.when(
              success: (PharmacyWorkspaceState state) => state.storageLayout,
              failure: (_) => const PharmacyStorageLayout(),
            ) ??
        const PharmacyStorageLayout();
    final List<PharmacyStorageRoom> activeRooms = storageLayout.rooms
        .where((PharmacyStorageRoom room) => room.isActive)
        .toList(growable: false);
    final List<PharmacyStorageShelf> shelfOptions = activeRooms
        .where((PharmacyStorageRoom room) => room.id == _storageRoomId)
        .expand((PharmacyStorageRoom room) => room.shelves)
        .where((PharmacyStorageShelf shelf) => shelf.isActive)
        .toList(growable: false);

    return AppDialog(
      title: Text(
        _isEdit ? l10n.pharmacyEditDrugAction : l10n.pharmacyAddDrugAction,
      ),
      icon: const Icon(Icons.medication_outlined),
      scrollable: true,
      maxWidth: 820,
      closeEnabled: !_isSaving,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        children: <Widget>[
          if (!_isEdit) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton.secondary(
                label: l10n.pharmacyDrugScanPackAction,
                leadingIcon: Icons.document_scanner_outlined,
                enabled: !_isSaving,
                onPressed: _openPackScan,
              ),
            ),
            if (_suggestions.hasPending) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              AppFormInformationBanner(
                title: l10n.pharmacyDrugSuggestedBannerTitle,
                message: l10n.pharmacyDrugSuggestedBannerBody,
                variant: AppFormInformationVariant.warning,
                children: <Widget>[
                  AppButton.secondary(
                    label: l10n.pharmacyDrugAcceptAllSuggestionsAction,
                    leadingIcon: Icons.done_all,
                    dense: true,
                    enabled: !_isSaving,
                    onPressed: () => setState(_suggestions.acceptAll),
                  ),
                ],
              ),
            ],
            SizedBox(height: theme.spacing.md),
          ],
          AppFormSection(
            title: l10n.pharmacyDrugIdentitySectionTitle,
            children: <Widget>[
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: _suggestedChrome(
                  fieldKey: PharmacyDrugSuggestedFields.genericName,
                  l10n: l10n,
                  theme: theme,
                  child: AppTextField(
                    controller: _genericNameController,
                    labelText: l10n.pharmacyDrugGenericNameLabel,
                    isRequired: true,
                    validator: AppValidators.requiredText(
                      l10n.validationRequired,
                    ),
                    onChanged: (_) {
                      if (_suggestions.isSuggested(
                        PharmacyDrugSuggestedFields.genericName,
                      )) {
                        setState(
                          () => _suggestions.edit(
                            PharmacyDrugSuggestedFields.genericName,
                          ),
                        );
                      }
                    },
                  ),
                ),
                right: _suggestedChrome(
                  fieldKey: PharmacyDrugSuggestedFields.code,
                  l10n: l10n,
                  theme: theme,
                  child: AppTextField(
                    controller: _codeController,
                    labelText: l10n.pharmacyDrugCodeLabel,
                    onChanged: (_) {
                      if (_suggestions.isSuggested(
                        PharmacyDrugSuggestedFields.code,
                      )) {
                        setState(
                          () =>
                              _suggestions.edit(PharmacyDrugSuggestedFields.code),
                        );
                      }
                    },
                  ),
                ),
              ),
              _suggestedChrome(
                fieldKey: PharmacyDrugSuggestedFields.brandName,
                l10n: l10n,
                theme: theme,
                child: AppTextField(
                  controller: _brandNameController,
                  labelText: l10n.pharmacyDrugBrandNameLabel,
                  onChanged: (_) {
                    if (_suggestions.isSuggested(
                      PharmacyDrugSuggestedFields.brandName,
                    )) {
                      setState(
                        () => _suggestions.edit(
                          PharmacyDrugSuggestedFields.brandName,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          AppFormSection(
            title: l10n.pharmacyDrugFormulationSectionTitle,
            children: <Widget>[
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: _suggestedChrome(
                  fieldKey: PharmacyDrugSuggestedFields.form,
                  l10n: l10n,
                  theme: theme,
                  child: AppSelectField<String>.searchable(
                    value: _form,
                    labelText: l10n.pharmacyDrugFormLabel,
                    enabled: !_isSaving,
                    options: formOptions,
                    onChanged: _onFormChanged,
                  ),
                ),
                right: _suggestedChrome(
                  fieldKey: PharmacyDrugSuggestedFields.strength,
                  l10n: l10n,
                  theme: theme,
                  child: AppSelectField<String>.searchable(
                    value: _strength,
                    labelText: l10n.pharmacyDrugStrengthLabel,
                    enabled: !_isSaving && _form != null,
                    options: strengthOptions,
                    onChanged: (String? value) {
                      setState(() {
                        _strength = value;
                        if (_suggestions.isSuggested(
                          PharmacyDrugSuggestedFields.strength,
                        )) {
                          _suggestions.edit(
                            PharmacyDrugSuggestedFields.strength,
                          );
                        }
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          AppFormSection(
            title: l10n.pharmacyDrugPricingSectionTitle,
            children: <Widget>[
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppCurrencyAmountField(
                  amountController: _pharmacyPriceController,
                  currency: _pharmacyCurrency,
                  amountLabelText: l10n.pharmacyPharmacyPriceLabel,
                  currencyLabelText: l10n.opdCurrencyLabel,
                  enabled: !_isSaving,
                  onCurrencyChanged: (String? value) {
                    setState(() {
                      _pharmacyCurrency = value ?? appDefaultCurrencyCode;
                    });
                  },
                  validator: _optionalPositiveAmountValidator,
                ),
                right: AppCurrencyAmountField(
                  amountController: _facilityPriceController,
                  currency: _facilityCurrency,
                  amountLabelText: l10n.pharmacyFacilityPriceLabel,
                  currencyLabelText: l10n.opdCurrencyLabel,
                  enabled: !_isSaving,
                  onCurrencyChanged: (String? value) {
                    setState(() {
                      _facilityCurrency = value ?? appDefaultCurrencyCode;
                    });
                  },
                  validator: _optionalPositiveAmountValidator,
                ),
              ),
            ],
          ),
          if (_isEdit) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppFormSection(
              title: l10n.pharmacyDrugInitialStockSectionTitle,
              children: <Widget>[
                AppTextField(
                  controller: _reorderLevelController,
                  labelText: l10n.pharmacyReorderLevelLabel,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: _optionalNonNegativeIntegerValidator,
                ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            _buildStorageLocationSection(
              l10n: l10n,
              theme: theme,
              activeRooms: activeRooms,
              shelfOptions: shelfOptions,
            ),
          ],
          if (!_isEdit) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppFormSection(
              title: l10n.pharmacyDrugInitialStockSectionTitle,
              children: <Widget>[
                AppResponsiveFieldRow.two(
                  gap: AppResponsiveFieldRowGap.form,
                  left: AppTextField(
                    controller: _initialStockController,
                    labelText: l10n.pharmacyInitialStockLabel,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: _optionalNonNegativeIntegerValidator,
                  ),
                  right: AppSelectField<String>.searchable(
                    value: _inventoryUnit,
                    labelText: l10n.pharmacyInventoryUnitLabel,
                    enabled: !_isSaving,
                    options: unitOptions,
                    onChanged: (String? value) =>
                        setState(() => _inventoryUnit = value),
                  ),
                ),
                AppTextField(
                  controller: _reorderLevelController,
                  labelText: inventoryUnitLabel == null
                      ? l10n.pharmacyReorderLevelLabel
                      : l10n.pharmacyReorderLevelLabelWithUnit(
                          inventoryUnitLabel,
                        ),
                  helperText: inventoryUnitLabel == null
                      ? l10n.pharmacyReorderLevelSelectUnitHelper
                      : l10n.pharmacyReorderLevelHelperWithUnit,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: _optionalNonNegativeIntegerValidator,
                ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            AppFormSection(
              title: l10n.pharmacyDrugBatchSectionTitle,
              children: <Widget>[
                AppResponsiveFieldRow.two(
                  gap: AppResponsiveFieldRowGap.form,
                  left: _suggestedChrome(
                    fieldKey: PharmacyDrugSuggestedFields.batchNumber,
                    l10n: l10n,
                    theme: theme,
                    child: AppTextField(
                      controller: _batchNumberController,
                      labelText: l10n.pharmacyBatchNumberLabel,
                      isRequired: _expiryDate != null,
                      validator: (String? value) {
                        if (_expiryDate != null &&
                            (value ?? '').trim().isEmpty) {
                          return l10n.validationRequired;
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (_suggestions.isSuggested(
                          PharmacyDrugSuggestedFields.batchNumber,
                        )) {
                          setState(
                            () => _suggestions.edit(
                              PharmacyDrugSuggestedFields.batchNumber,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  right: _suggestedChrome(
                    fieldKey: PharmacyDrugSuggestedFields.manufacturedAt,
                    l10n: l10n,
                    theme: theme,
                    child: AppDateField(
                      labelText: l10n.pharmacyManufacturingDateLabel,
                      value: _manufacturedAt,
                      pickerButtonLabel: l10n.housekeepingPickDateAction,
                      invalidDateMessage: l10n.pharmacyManufacturingDateLabel,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      onChanged: (DateTime? value) {
                        setState(() {
                          _manufacturedAt = value;
                          if (_suggestions.isSuggested(
                            PharmacyDrugSuggestedFields.manufacturedAt,
                          )) {
                            _suggestions.edit(
                              PharmacyDrugSuggestedFields.manufacturedAt,
                            );
                          }
                        });
                      },
                    ),
                  ),
                ),
                AppResponsiveFieldRow.two(
                  gap: AppResponsiveFieldRowGap.form,
                  left: _suggestedChrome(
                    fieldKey: PharmacyDrugSuggestedFields.expiryDate,
                    l10n: l10n,
                    theme: theme,
                    child: AppDateField(
                      labelText: l10n.pharmacyExpiryDateLabel,
                      value: _expiryDate,
                      pickerButtonLabel: l10n.housekeepingPickDateAction,
                      invalidDateMessage: l10n.pharmacyExpiryDateLabel,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      onChanged: (DateTime? value) {
                        setState(() {
                          _expiryDate = value;
                          if (_suggestions.isSuggested(
                            PharmacyDrugSuggestedFields.expiryDate,
                          )) {
                            _suggestions.edit(
                              PharmacyDrugSuggestedFields.expiryDate,
                            );
                          }
                        });
                        _formKey.currentState?.validate();
                      },
                    ),
                  ),
                  right: AppSelectField<int>(
                    value: _expiryAlertLeadDays,
                    labelText: l10n.pharmacyExpiryAlertLeadLabel,
                    helperText: l10n.pharmacyExpiryAlertLeadHelper,
                    enabled: !_isSaving,
                    options: expiryLeadOptions
                        .map(
                          (PharmacyExpiryAlertLeadOption option) =>
                              AppSelectOption<int>(
                                value: option.days,
                                label: option.label,
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (int? value) =>
                        setState(() => _expiryAlertLeadDays = value),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            _buildStorageLocationSection(
              l10n: l10n,
              theme: theme,
              activeRooms: activeRooms,
              shelfOptions: shelfOptions,
            ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          enabled: !_isSaving,
          onPressed: () =>
              Navigator.of(context).pop(const PharmacyDrugFormResult.cancelled()),
        ),
        AppButton.primary(
          label: _isEdit
              ? l10n.commonSaveActionLabel
              : l10n.pharmacyAddDrugAction,
          leadingIcon: _isEdit ? Icons.save_outlined : Icons.add,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_isEdit && _suggestions.hasPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pharmacyDrugSuggestionsPendingBody)),
      );
      return;
    }
    setState(() => _isSaving = true);
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    String genericName = _genericNameController.text.trim();
    String? brandName = _emptyToNull(_brandNameController.text);
    String? code = _emptyToNull(_codeController.text);
    String? form = _form;
    String? strength = _strength;
    final num? pharmacyPrice = _parsePrice(_pharmacyPriceController.text);
    final num? facilityPrice = _parsePrice(_facilityPriceController.text);
    final String? pharmacyCurrency = pharmacyPrice == null
        ? null
        : _pharmacyCurrency;
    final PharmacyFacilityOfferingInput? facilityOffering =
        _buildFacilityOfferingInput(controller, facilityPrice);
    AppFailure? failure;
    if (widget.drug == null) {
      final String? tenantId = controller.resolveTenantId();
      if (tenantId == null) {
        failure = AppFailure.validation();
      } else {
        while (mounted) {
          final Result<PharmacyDrugSimilarityResult> similarityResult =
              await controller.checkDrugSimilarity(
                genericName: genericName,
                name: genericName,
                brandName: brandName,
                code: code,
                form: form,
                strength: strength,
                tenantId: tenantId,
              );
          final PharmacyDrugSimilarityResult? check = similarityResult.when(
            success: (PharmacyDrugSimilarityResult value) => value,
            failure: (AppFailure error) {
              failure = error;
              return null;
            },
          );
          if (check == null) {
            break;
          }

          if (!mounted) {
            return;
          }

          final PharmacyDrugSimilarityDialogResult similarityDecision =
              await showPharmacyDrugSimilarityDialog(
                context,
                proposed: PharmacyDrugSimilarityProposedValues(
                  genericName: genericName,
                  brandName: brandName,
                  code: code,
                  form: form,
                  strength: strength,
                ),
                check: check,
              );

          if (similarityDecision.action == PharmacyDrugSimilarityAction.cancel) {
            if (mounted) {
              setState(() => _isSaving = false);
            }
            return;
          }

          if (similarityDecision.action == PharmacyDrugSimilarityAction.retry) {
            final PharmacyDrugSimilarityProposedValues? proposed =
                similarityDecision.proposed;
            if (proposed != null) {
              genericName = proposed.genericName;
              brandName = proposed.brandName;
              code = proposed.code;
              form = proposed.form;
              strength = proposed.strength;
              _genericNameController.text = genericName;
              _brandNameController.text = brandName ?? '';
              _codeController.text = code ?? '';
              setState(() {
                _form = form;
                _strength = strength;
              });
            }
            continue;
          }

          if (similarityDecision.action ==
              PharmacyDrugSimilarityAction.useExisting) {
            final PharmacyDrug? existing = similarityDecision.selectedDrug;
            if (!mounted) {
              return;
            }
            setState(() => _isSaving = false);
            if (existing != null) {
              Navigator.of(
                context,
              ).pop(PharmacyDrugFormResult.useExisting(existing));
            }
            return;
          }

          if (similarityDecision.action ==
              PharmacyDrugSimilarityAction.replaceExisting) {
            final PharmacyDrug? existing = similarityDecision.selectedDrug;
            final PharmacyDrugSimilarityProposedValues? proposed =
                similarityDecision.proposed;
            if (existing == null || proposed == null) {
              if (mounted) {
                setState(() => _isSaving = false);
              }
              return;
            }
            genericName = proposed.genericName;
            brandName = proposed.brandName;
            code = proposed.code;
            form = proposed.form;
            strength = proposed.strength;
            _genericNameController.text = genericName;
            _brandNameController.text = brandName ?? '';
            _codeController.text = code ?? '';
            setState(() {
              _form = form;
              _strength = strength;
            });
            failure = await controller.updateDrug(
              existing.id,
              PharmacyDrugUpdateInput(
                name: genericName,
                brandName: brandName,
                genericName: genericName,
                code: code,
                form: form,
                strength: strength,
                unitPrice: pharmacyPrice,
                currency: pharmacyCurrency,
              ),
              facilityOffering: facilityOffering,
            );
            if (!mounted) {
              return;
            }
            if (failure == null) {
              Navigator.of(
                context,
              ).pop(PharmacyDrugFormResult.saved(existing));
              return;
            }
            setState(() => _isSaving = false);
            return;
          }

          final PharmacyDrugSimilarityProposedValues? confirmed =
              similarityDecision.proposed;
          if (confirmed != null) {
            genericName = confirmed.genericName;
            brandName = confirmed.brandName;
            code = confirmed.code;
            form = confirmed.form;
            strength = confirmed.strength;
            _genericNameController.text = genericName;
            _brandNameController.text = brandName ?? '';
            _codeController.text = code ?? '';
            setState(() {
              _form = form;
              _strength = strength;
            });
          }
          break;
        }

        if (failure != null) {
          if (mounted) {
            setState(() => _isSaving = false);
          }
          return;
        }

        final Result<PharmacyDrug> createResult = await controller.createDrug(
          PharmacyDrugInput(
            tenantId: tenantId,
            name: genericName,
            brandName: brandName,
            genericName: genericName,
            code: code,
            form: form,
            strength: strength,
            unitPrice: pharmacyPrice,
            currency: pharmacyCurrency,
            inventoryUnit: _inventoryUnit,
            initialStock: int.tryParse(_initialStockController.text.trim()),
            reorderLevel: int.tryParse(_reorderLevelController.text.trim()),
            batchNumber: _emptyToNull(_batchNumberController.text),
            manufacturedAt: _manufacturedAt,
            expiryDate: _expiryDate,
            expiryAlertLeadDays: _expiryAlertLeadDays,
            storageRoomId: _storageRoomId,
            storageShelfId: _storageShelfId,
            facilityId: controller.resolveFacilityId(),
            confirmSimilar: true,
          ),
          facilityOffering: facilityOffering,
        );
        if (!mounted) {
          return;
        }
        createResult.when(
          success: (PharmacyDrug created) {
            Navigator.of(context).pop(PharmacyDrugFormResult.saved(created));
          },
          failure: (AppFailure error) {
            setState(() => _isSaving = false);
            failure = error;
          },
        );
        if (failure != null) {
          return;
        }
        return;
      }
    } else {
      failure = await controller.updateDrug(
        widget.drug!.id,
        PharmacyDrugUpdateInput(
          name: genericName,
          brandName: _brandNameController.text.trim(),
          genericName: genericName,
          code: _emptyToNull(_codeController.text),
          form: _form,
          strength: _strength,
          unitPrice: pharmacyPrice,
          currency: pharmacyCurrency,
        ),
        facilityOffering: facilityOffering,
      );
      if (failure == null) {
        final int? reorderLevel = int.tryParse(
          _reorderLevelController.text.trim(),
        );
        final String? inventoryItemId = _resolveInventoryItemId(widget.drug!);
        if (reorderLevel != null && inventoryItemId != null) {
          failure = await controller.adjustInventoryStock(
            PharmacyInventoryAdjustInput(
              inventoryItemId: inventoryItemId,
              reorderLevel: reorderLevel,
              reason: 'OTHER',
              facilityId: controller.resolveFacilityId(),
            ),
          );
        }
      }
      if (!mounted) {
        return;
      }
      if (failure == null) {
        Navigator.of(context).pop(PharmacyDrugFormResult.saved(widget.drug!));
        return;
      }
      setState(() => _isSaving = false);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
  }

  String? _optionalPositiveAmountValidator(String? value) {
    final String trimmed = normalizeCurrencyAmount(value ?? '');
    if (trimmed.isEmpty) {
      return null;
    }
    final num? parsed = num.tryParse(trimmed);
    if (parsed == null || parsed < 0) {
      return context.l10n.validationFieldInvalidMessage('amount');
    }
    return null;
  }

  String? _optionalNonNegativeIntegerValidator(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) {
      return context.l10n.validationFieldInvalidMessage('number');
    }
    return null;
  }
}

String? _emptyToNull(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _priceText(num? value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

num? _parsePrice(String value) {
  final String trimmed = normalizeCurrencyAmount(value);
  if (trimmed.isEmpty) {
    return null;
  }
  return num.tryParse(trimmed);
}
