import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_catalog_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_drug_catalog_options.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

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
  late final TextEditingController _nameController;
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

  bool get _isEdit => widget.drug != null;

  @override
  void initState() {
    super.initState();
    final PharmacyDrug? drug = widget.drug;
    _nameController = TextEditingController(text: drug?.name ?? '');
    _brandNameController = TextEditingController(text: drug?.brandName ?? '');
    _genericNameController = TextEditingController(
      text: drug?.genericName ?? '',
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
    _nameController.dispose();
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
      initialTab: PharmacyCatalogTab.storage,
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
          AppFormSection(
            title: l10n.pharmacyDrugIdentitySectionTitle,
            children: <Widget>[
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppTextField(
                  controller: _nameController,
                  labelText: l10n.pharmacyDrugNameLabel,
                  isRequired: true,
                  validator: AppValidators.requiredText(
                    l10n.validationRequired,
                  ),
                ),
                right: AppTextField(
                  controller: _codeController,
                  labelText: l10n.pharmacyDrugCodeLabel,
                ),
              ),
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppTextField(
                  controller: _brandNameController,
                  labelText: l10n.pharmacyDrugBrandNameLabel,
                ),
                right: AppTextField(
                  controller: _genericNameController,
                  labelText: l10n.pharmacyDrugGenericNameLabel,
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
                left: AppSelectField<String>.searchable(
                  value: _form,
                  labelText: l10n.pharmacyDrugFormLabel,
                  enabled: !_isSaving,
                  options: formOptions,
                  onChanged: _onFormChanged,
                ),
                right: AppSelectField<String>.searchable(
                  value: _strength,
                  labelText: l10n.pharmacyDrugStrengthLabel,
                  enabled: !_isSaving && _form != null,
                  options: strengthOptions,
                  onChanged: (String? value) =>
                      setState(() => _strength = value),
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
                  left: AppTextField(
                    controller: _batchNumberController,
                    labelText: l10n.pharmacyBatchNumberLabel,
                    isRequired: _expiryDate != null,
                    validator: (String? value) {
                      if (_expiryDate != null && (value ?? '').trim().isEmpty) {
                        return l10n.validationRequired;
                      }
                      return null;
                    },
                  ),
                  right: AppDateField(
                    labelText: l10n.pharmacyManufacturingDateLabel,
                    value: _manufacturedAt,
                    pickerButtonLabel: l10n.housekeepingPickDateAction,
                    invalidDateMessage: l10n.pharmacyManufacturingDateLabel,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    onChanged: (DateTime? value) =>
                        setState(() => _manufacturedAt = value),
                  ),
                ),
                AppResponsiveFieldRow.two(
                  gap: AppResponsiveFieldRowGap.form,
                  left: AppDateField(
                    labelText: l10n.pharmacyExpiryDateLabel,
                    value: _expiryDate,
                    pickerButtonLabel: l10n.housekeepingPickDateAction,
                    invalidDateMessage: l10n.pharmacyExpiryDateLabel,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    onChanged: (DateTime? value) {
                      setState(() => _expiryDate = value);
                      _formKey.currentState?.validate();
                    },
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
          onPressed: () => Navigator.of(context).pop(false),
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
    setState(() => _isSaving = true);
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
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
        failure = await controller.createDrug(
          PharmacyDrugInput(
            tenantId: tenantId,
            name: _nameController.text.trim(),
            brandName: _emptyToNull(_brandNameController.text),
            genericName: _emptyToNull(_genericNameController.text),
            code: _emptyToNull(_codeController.text),
            form: _form,
            strength: _strength,
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
          ),
          facilityOffering: facilityOffering,
        );
      }
    } else {
      failure = await controller.updateDrug(
        widget.drug!.id,
        PharmacyDrugUpdateInput(
          name: _nameController.text.trim(),
          brandName: _brandNameController.text.trim(),
          genericName: _genericNameController.text.trim(),
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
    }
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
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
