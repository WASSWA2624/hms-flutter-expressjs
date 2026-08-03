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
import 'package:hosspi_hms/shared/layout/app_workspace_feedback.dart';
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
  late final TextEditingController _onHandQuantityController;
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
  bool _didResolveStorageRoom = false;
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
    _inventoryUnit = _resolveInventoryUnit(drug) ??
        pharmacyDefaultInventoryUnitForForm(_form);
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
    final num onHand = drug?.quantityOnHand ??
        drug?.availableQuantity ??
        drug?.stockLevel ??
        0;
    _onHandQuantityController = TextEditingController(
      text: onHand > 0 ? _trimNumber(onHand) : '0',
    );
    // Edit: leave add-quantity empty so save does not re-add on-hand.
    _initialStockController = TextEditingController();
    final num? existingReorderLevel = _resolveReorderLevel(drug);
    _reorderLevelController = TextEditingController(
      text: existingReorderLevel != null
          ? _trimNumber(existingReorderLevel)
          : '',
    );
    final PharmacyInventoryStock? primaryStock = _primaryStockRow(drug);
    _storageRoomId =
        _emptyToNull(drug?.storageRoomId ?? '') ??
        _emptyToNull(primaryStock?.storageRoomId ?? '');
    _storageShelfId =
        _emptyToNull(drug?.storageShelfId ?? '') ??
        _emptyToNull(primaryStock?.storageShelfId ?? '');
    _expiryDate = primaryStock?.nextExpiry;
    _batchNumberController = TextEditingController();
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _genericNameController.dispose();
    _codeController.dispose();
    _pharmacyPriceController.dispose();
    _facilityPriceController.dispose();
    _onHandQuantityController.dispose();
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

  PharmacyInventoryStock? _primaryStockRow(PharmacyDrug? drug) {
    if (drug == null || drug.stockRows.isEmpty) {
      return null;
    }
    return drug.stockRows.first;
  }

  num? _resolveReorderLevel(PharmacyDrug? drug) {
    final PharmacyInventoryStock? stock = _primaryStockRow(drug);
    if (stock != null) {
      return stock.reorderLevel;
    }
    return null;
  }

  String? _resolveInventoryUnit(PharmacyDrug? drug) {
    if (drug == null) {
      return null;
    }
    for (final PharmacyDrugStockMapping mapping in drug.stockMappings) {
      final String? unit = _emptyToNull(mapping.inventoryItem?.unit ?? '');
      if (unit != null) {
        return unit;
      }
    }
    for (final PharmacyInventoryStock stock in drug.stockRows) {
      final String? unit = _emptyToNull(stock.inventoryItem?.unit ?? '');
      if (unit != null) {
        return unit;
      }
    }
    return null;
  }

  void _resolveStorageRoomFromLayout(List<PharmacyStorageRoom> rooms) {
    if (_didResolveStorageRoom ||
        _storageShelfId == null ||
        _storageRoomId != null ||
        rooms.isEmpty) {
      return;
    }
    _didResolveStorageRoom = true;
    for (final PharmacyStorageRoom room in rooms) {
      final bool hasShelf = room.shelves.any(
        (PharmacyStorageShelf shelf) => shelf.id == _storageShelfId,
      );
      if (hasShelf) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _storageRoomId != null) {
            return;
          }
          setState(() => _storageRoomId = room.id);
        });
        return;
      }
    }
  }

  PharmacyFacilityOfferingInput? _buildFacilityOfferingInput(
    PharmacyWorkspaceController controller, {
    num? facilityPrice,
    num? pharmacyPrice,
  }) {
    final String? previousShelfId = widget.drug?.storageShelfId;
    final bool storageChanged = _storageShelfId != previousShelfId;
    final bool facilityPriceChanged = !_sameOptionalPrice(
      facilityPrice,
      widget.drug?.facilityUnitPrice,
    );
    // Only hit facility catalog when facility price or storage actually changed.
    // Pre-filled unchanged prices must not trigger a gated upsert on every save.
    if (!facilityPriceChanged && !storageChanged) {
      return null;
    }
    // Active offerings require unit_price (>= 0). Prefer the edited facility
    // price, then existing facility/pharmacy prices, then 0 so storage-only
    // edits still attempt to persist.
    final num offeringPrice =
        facilityPrice ??
        widget.drug?.facilityUnitPrice ??
        pharmacyPrice ??
        widget.drug?.pharmacyUnitPrice ??
        widget.drug?.unitPrice ??
        0;
    return PharmacyFacilityOfferingInput(
      unitPrice: offeringPrice,
      currency: _facilityCurrency,
      facilityId: controller.resolveFacilityId(),
      defaultStorageShelfId: _storageShelfId,
    );
  }

  List<AppSelectOption<String>> _withCurrentOption(
    List<AppSelectOption<String>> options,
    String? current,
  ) {
    final String? value = _emptyToNull(current ?? '');
    if (value == null) {
      return options;
    }
    if (options.any((AppSelectOption<String> option) => option.value == value)) {
      return options;
    }
    return <AppSelectOption<String>>[
      ...options,
      AppSelectOption<String>(value: value, label: value),
    ];
  }

  /// Drops the drug under edit from similarity matches (id or display id).
  PharmacyDrugSimilarityResult _similarityExcludingDrug(
    PharmacyDrugSimilarityResult check,
    String excludeDrugId,
  ) {
    final String exclude = excludeDrugId.trim().toUpperCase();
    if (exclude.isEmpty) {
      return check;
    }

    bool isExcluded(PharmacyDrug drug) {
      final String id = drug.id.trim().toUpperCase();
      final String display = (drug.displayId ?? '').trim().toUpperCase();
      return id == exclude || (display.isNotEmpty && display == exclude);
    }

    final List<PharmacyDrugSimilarityMatch> matches = check.matches
        .where(
          (PharmacyDrugSimilarityMatch match) => !isExcluded(match.drug),
        )
        .toList(growable: false);
    if (matches.length == check.matches.length) {
      return check;
    }

    int closestScore = 0;
    for (final PharmacyDrugSimilarityMatch match in matches) {
      if (match.score > closestScore) {
        closestScore = match.score;
      }
    }

    return PharmacyDrugSimilarityResult(
      exactIdentityConflict: matches.any(
        (PharmacyDrugSimilarityMatch match) => match.exactIdentityConflict,
      ),
      exactCodeConflict: matches.any(
        (PharmacyDrugSimilarityMatch match) => match.exactCodeConflict,
      ),
      closestScore: closestScore,
      matches: matches,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<AppSelectOption<String>> formOptions = _withCurrentOption(
      pharmacyDrugFormSelectOptions(l10n),
      _form,
    );
    final List<AppSelectOption<String>> strengthOptions = _withCurrentOption(
      pharmacyStrengthSelectOptions(_form),
      _strength,
    );
    final List<AppSelectOption<String>> unitOptions = _withCurrentOption(
      pharmacyInventoryUnitSelectOptions(l10n, form: _form),
      _inventoryUnit,
    );
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
    _resolveStorageRoomFromLayout(activeRooms);

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
                    isRequired: true,
                    enabled: !_isSaving,
                    options: formOptions,
                    validator: AppValidators.requiredValue(
                      l10n.validationRequired,
                    ),
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
                    isRequired: true,
                    enabled: !_isSaving && _form != null,
                    options: strengthOptions,
                    validator: AppValidators.requiredValue(
                      l10n.validationRequired,
                    ),
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
          SizedBox(height: theme.spacing.md),
          AppFormSection(
            title: l10n.pharmacyDrugInitialStockSectionTitle,
            children: <Widget>[
              if (_isEdit) ...<Widget>[
                AppResponsiveFieldRow.two(
                  gap: AppResponsiveFieldRowGap.form,
                  left: AppTextField(
                    controller: _onHandQuantityController,
                    labelText: l10n.pharmacyOnHandQuantityLabel,
                    enabled: false,
                    keyboardType: TextInputType.number,
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
                AppResponsiveFieldRow.two(
                  gap: AppResponsiveFieldRowGap.form,
                  left: AppTextField(
                    controller: _initialStockController,
                    labelText: l10n.pharmacyAddQuantityLabel,
                    hintText: l10n.pharmacyAddQuantityHint,
                    helperText: l10n.pharmacyAddQuantityHelper,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: _optionalNonNegativeIntegerValidator,
                  ),
                  right: AppTextField(
                    controller: _reorderLevelController,
                    labelText: inventoryUnitLabel == null
                        ? l10n.pharmacyReorderLevelLabel
                        : l10n.pharmacyReorderLevelLabelWithUnit(
                            inventoryUnitLabel,
                          ),
                    hintText: l10n.pharmacyReorderLevelHint,
                    helperText: inventoryUnitLabel == null
                        ? l10n.pharmacyReorderLevelHelper
                        : l10n.pharmacyReorderLevelHelperWithUnit,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: _optionalNonNegativeIntegerValidator,
                  ),
                ),
              ] else ...<Widget>[
                AppResponsiveFieldRow.two(
                  gap: AppResponsiveFieldRowGap.form,
                  left: AppTextField(
                    controller: _initialStockController,
                    labelText: l10n.pharmacyInitialStockLabel,
                    hintText: l10n.pharmacyInitialStockHint,
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
                  hintText: l10n.pharmacyReorderLevelHint,
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
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
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
        _buildFacilityOfferingInput(
          controller,
          facilityPrice: facilityPrice,
          pharmacyPrice: pharmacyPrice,
        );
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
            final Result<PharmacyDrug> updateResult = await controller
                .updateDrug(
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
            updateResult.when(
              success: (PharmacyDrug updated) {
                Navigator.of(
                  context,
                ).pop(PharmacyDrugFormResult.saved(updated));
              },
              failure: (AppFailure error) {
                failure = error;
                setState(() => _isSaving = false);
              },
            );
            if (failure != null) {
              showAppFailureSnackBar(context, failure);
              return;
            }
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
            showAppFailureSnackBar(context, failure);
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
          showAppFailureSnackBar(context, failure);
          return;
        }
        return;
      }
    } else {
      final String? tenantId =
          controller.resolveTenantId() ?? widget.drug!.tenantId;
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
                excludeDrugId: widget.drug!.id,
              );
          final PharmacyDrugSimilarityResult? rawCheck = similarityResult.when(
            success: (PharmacyDrugSimilarityResult value) => value,
            failure: (AppFailure error) {
              failure = error;
              return null;
            },
          );
          if (rawCheck == null) {
            break;
          }

          if (!mounted) {
            return;
          }

          // Never compare the drug against itself — only other catalog drugs.
          final PharmacyDrugSimilarityResult check = _similarityExcludingDrug(
            rawCheck,
            widget.drug!.id,
          );

          final PharmacyDrugSimilarityDialogResult similarityDecision =
              await showPharmacyDrugSimilarityDialog(
                context,
                isEdit: true,
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
            final Result<PharmacyDrug> replaceResult = await controller
                .updateDrug(
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
                    confirmSimilar: true,
                  ),
                  facilityOffering: facilityOffering,
                );
            if (!mounted) {
              return;
            }
            replaceResult.when(
              success: (PharmacyDrug updated) {
                Navigator.of(
                  context,
                ).pop(PharmacyDrugFormResult.saved(updated));
              },
              failure: (AppFailure error) {
                failure = error;
                setState(() => _isSaving = false);
              },
            );
            if (failure != null) {
              showAppFailureSnackBar(context, failure);
              return;
            }
            return;
          }

          // Edit anyway / continue — apply any proposed edits, then update self.
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
            showAppFailureSnackBar(context, failure);
          }
          return;
        }

        final Result<PharmacyDrug> updateResult = await controller.updateDrug(
          widget.drug!.id,
          PharmacyDrugUpdateInput(
            name: genericName,
            brandName: brandName,
            genericName: genericName,
            code: code,
            form: form,
            strength: strength,
            unitPrice: pharmacyPrice,
            currency: pharmacyCurrency,
            confirmSimilar: true,
          ),
          facilityOffering: facilityOffering,
        );
        PharmacyDrug? updatedDrug;
        updateResult.when(
          success: (PharmacyDrug value) => updatedDrug = value,
          failure: (AppFailure error) => failure = error,
        );
        if (failure == null && updatedDrug != null) {
          final int addQuantity =
              int.tryParse(_initialStockController.text.trim()) ?? 0;
          final int? reorderLevel = int.tryParse(
            _reorderLevelController.text.trim(),
          );
          final num? previousReorder = widget.drug!.stockRows.isNotEmpty
              ? widget.drug!.stockRows.first.reorderLevel
              : null;
          final bool reorderChanged =
              reorderLevel != null &&
              (previousReorder == null ||
                  previousReorder.toInt() != reorderLevel);
          // Prefer the pre-edit catalog drug — PUT /drugs often omits stock maps.
          final String? inventoryItemId =
              _resolveInventoryItemId(widget.drug!) ??
              _resolveInventoryItemId(updatedDrug!);
          if (inventoryItemId != null &&
              (addQuantity > 0 || reorderChanged)) {
            final AppFailure? stockFailure = await controller
                .adjustInventoryStock(
                  PharmacyInventoryAdjustInput(
                    inventoryItemId: inventoryItemId,
                    quantityDelta: addQuantity > 0 ? addQuantity : 0,
                    reorderLevel: reorderChanged ? reorderLevel : null,
                    reason: 'OTHER',
                    facilityId: controller.resolveFacilityId(),
                    batchNumber: addQuantity > 0
                        ? _emptyToNull(_batchNumberController.text)
                        : null,
                    manufacturedAt: addQuantity > 0 ? _manufacturedAt : null,
                    expiryDate: addQuantity > 0 ? _expiryDate : null,
                    expiryAlertLeadDays:
                        addQuantity > 0 ? _expiryAlertLeadDays : null,
                    storageRoomId: addQuantity > 0 ? _storageRoomId : null,
                    storageShelfId: addQuantity > 0 ? _storageShelfId : null,
                    drugId: widget.drug!.id,
                  ),
                );
            // Stock adjust is best-effort; identity update already succeeded.
            if (stockFailure == null) {
              updatedDrug =
                  _findDrugInProvider(ref, widget.drug!.id) ?? updatedDrug;
            }
          }
        }
        if (!mounted) {
          return;
        }
        if (failure == null && updatedDrug != null) {
          Navigator.of(context).pop(PharmacyDrugFormResult.saved(updatedDrug!));
          return;
        }
        setState(() => _isSaving = false);
        showAppFailureSnackBar(context, failure);
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    showAppFailureSnackBar(context, failure);
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

String _trimNumber(num value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value.toString();
}

bool _sameOptionalPrice(num? left, num? right) {
  if (left == null && right == null) {
    return true;
  }
  if (left == null || right == null) {
    return false;
  }
  return left == right;
}

PharmacyDrug? _findDrugInProvider(WidgetRef ref, String drugId) {
  final AsyncValue<Result<PharmacyWorkspaceState>> asyncState = ref.read(
    pharmacyWorkspaceControllerProvider,
  );
  if (!asyncState.hasValue) {
    return null;
  }
  PharmacyDrug? found;
  asyncState.requireValue.when(
    success: (PharmacyWorkspaceState value) {
      for (final PharmacyDrug item in value.drugs.items) {
        if (item.id == drugId) {
          found = item;
          return;
        }
      }
    },
    failure: (_) {},
  );
  return found;
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
