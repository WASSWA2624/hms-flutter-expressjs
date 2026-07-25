import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

typedef RadiologyCatalogUpdateSubmit =
    Future<AppFailure?> Function(String id, Map<String, Object?> payload);

typedef RadiologyOfferingCatalogSearch =
    Future<Result<List<RadiologyCatalogProcedure>>> Function({
      required RadiologyCatalogScope scope,
      String? query,
      int limit,
    });

enum _RadiologyEnableWizardStep { catalog, price, preview }

class RadiologyEnableFacilityOfferingDialog extends StatefulWidget {
  const RadiologyEnableFacilityOfferingDialog({
    required this.scope,
    required this.onSearchCatalog,
    required this.onEnable,
    this.defaultCurrency = appDefaultCurrencyCode,
    this.showBackAction = false,
    super.key,
  });

  /// Sentinel popped when the user presses Back to return to the scope step.
  static const Object backResult = Object();

  final RadiologyCatalogScope scope;
  final RadiologyOfferingCatalogSearch onSearchCatalog;
  final RadiologyCatalogUpdateSubmit onEnable;
  final String defaultCurrency;

  /// When true, catalog-step Back returns [backResult] to revisit the scope step.
  final bool showBackAction;

  @override
  State<RadiologyEnableFacilityOfferingDialog> createState() =>
      _RadiologyEnableFacilityOfferingDialogState();
}

class _RadiologyEnableFacilityOfferingDialogState
    extends State<RadiologyEnableFacilityOfferingDialog> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const int _searchLimit = 100;
  static const String _modalityFilterKey = 'modality';

  late final TextEditingController _searchController;
  final GlobalKey<FormState> _priceFormKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _priceControllers =
      <String, TextEditingController>{};
  final Map<String, String> _currencies = <String, String>{};
  Timer? _searchDebounce;
  List<RadiologyCatalogProcedure> _catalogItems = const <RadiologyCatalogProcedure>[];
  AppFailure? _failure;
  bool _isSearching = true;
  int _searchRequest = 0;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  List<AppSearchBarFilterChoice> _modalityFilterChoices =
      const <AppSearchBarFilterChoice>[];
  final Set<String> _selectedIds = <String>{};
  bool _enabledAny = false;
  _RadiologyEnableWizardStep _step = _RadiologyEnableWizardStep.catalog;
  bool _isSaving = false;

  List<RadiologyCatalogProcedure> get _availableCatalogItems {
    return _catalogItems
        .where((RadiologyCatalogProcedure item) => !item.isOfferedAtFacility)
        .toList(growable: false);
  }

  List<RadiologyCatalogProcedure> get _filteredCatalogItems {
    final String? modality = _filterValue.option(_modalityFilterKey);
    final List<RadiologyCatalogProcedure> available = _availableCatalogItems;
    if (modality == null) {
      return available;
    }
    return available
        .where((RadiologyCatalogProcedure item) => item.modality == modality)
        .toList(growable: false);
  }

  List<RadiologyCatalogProcedure> get _sortedFilteredCatalogItems {
    final List<RadiologyCatalogProcedure> items = List<RadiologyCatalogProcedure>.of(
      _filteredCatalogItems,
    );
    items.sort(
      (RadiologyCatalogProcedure left, RadiologyCatalogProcedure right) =>
          appListTableCompareText(left.name, right.name),
    );
    return items;
  }

  List<RadiologyCatalogProcedure> get _selectedAvailableItems {
    return _availableCatalogItems
        .where(
          (RadiologyCatalogProcedure item) => _selectedIds.contains(item.apiId),
        )
        .toList(growable: false)
      ..sort(
        (RadiologyCatalogProcedure left, RadiologyCatalogProcedure right) =>
            appListTableCompareText(left.name, right.name),
      );
  }

  void _markItemsOfferedLocally(List<RadiologyCatalogProcedure> items) {
    if (items.isEmpty) {
      return;
    }
    final Map<String, RadiologyCatalogProcedure> byId = <String, RadiologyCatalogProcedure>{
      for (final RadiologyCatalogProcedure item in items) item.apiId: item,
    };
    setState(() {
      _catalogItems = _catalogItems
          .map((RadiologyCatalogProcedure catalogItem) {
            final RadiologyCatalogProcedure? updated = byId[catalogItem.apiId];
            if (updated == null) {
              return catalogItem;
            }
            return catalogItem.copyWith(
              unitPrice: updated.unitPrice ?? catalogItem.unitPrice,
              currency: updated.currency ?? catalogItem.currency,
              isOfferedAtFacility: true,
              facilityOfferingId:
                  updated.facilityOfferingId ?? catalogItem.facilityOfferingId,
            );
          })
          .toList(growable: false);
      _selectedIds.removeAll(byId.keys);
      _enabledAny = true;
    });
  }

  void _syncModalityFilterChoices() {
    final Set<String> values = <String>{};
    for (final RadiologyCatalogProcedure item in _availableCatalogItems) {
      final String? modality = item.modality?.trim();
      if (modality != null && modality.isNotEmpty) {
        values.add(modality);
      }
    }
    _modalityFilterChoices = values
        .map(
          (String value) =>
              AppSearchBarFilterChoice(value: value, label: value),
        )
        .toList(growable: false);
  }

  void _pruneSelection() {
    final Set<String> valid = _availableCatalogItems
        .map((RadiologyCatalogProcedure item) => item.apiId)
        .toSet();
    _selectedIds.removeWhere((String id) => !valid.contains(id));
  }

  void _toggleSelection(RadiologyCatalogProcedure item, {required bool selected}) {
    if (item.isOfferedAtFacility) {
      return;
    }
    setState(() {
      if (selected) {
        _selectedIds.add(item.apiId);
      } else {
        _selectedIds.remove(item.apiId);
      }
    });
  }

  void _ensurePriceFields(List<RadiologyCatalogProcedure> items) {
    for (final RadiologyCatalogProcedure item in items) {
      _priceControllers.putIfAbsent(
        item.apiId,
        () => TextEditingController(text: item.unitPrice?.toString() ?? ''),
      );
      _currencies.putIfAbsent(
        item.apiId,
        () => item.currency ?? widget.defaultCurrency,
      );
    }
  }

  String _priceDisplay(RadiologyCatalogProcedure item) {
    final TextEditingController? controller = _priceControllers[item.apiId];
    final String amount = controller?.text.trim().isNotEmpty == true
        ? controller!.text.trim()
        : (item.unitPrice?.toString() ?? '');
    final String currency =
        _currencies[item.apiId] ?? item.currency ?? widget.defaultCurrency;
    if (amount.isEmpty) {
      return currency;
    }
    return '$amount $currency';
  }

  bool _selectionHasValidPrices(List<RadiologyCatalogProcedure> items) {
    for (final RadiologyCatalogProcedure item in items) {
      final String raw = _priceControllers[item.apiId]?.text ?? '';
      final String normalized = normalizeCurrencyAmount(raw);
      final num? parsed = num.tryParse(normalized);
      if (parsed == null || parsed <= 0) {
        return false;
      }
    }
    return items.isNotEmpty;
  }

  void _goToCatalog() {
    setState(() {
      _step = _RadiologyEnableWizardStep.catalog;
      _failure = null;
      _isSaving = false;
    });
  }

  void _goToPriceStep() {
    final List<RadiologyCatalogProcedure> selected = _selectedAvailableItems;
    if (selected.isEmpty) {
      return;
    }
    _ensurePriceFields(selected);
    setState(() {
      _step = _RadiologyEnableWizardStep.price;
      _failure = null;
      _isSaving = false;
    });
  }

  void _goToPreview() {
    final List<RadiologyCatalogProcedure> selected = _selectedAvailableItems;
    if (selected.isEmpty) {
      return;
    }
    if (!(_priceFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_selectionHasValidPrices(selected)) {
      return;
    }
    setState(() {
      _step = _RadiologyEnableWizardStep.preview;
      _failure = null;
      _isSaving = false;
    });
  }

  void _onWizardBack() {
    switch (_step) {
      case _RadiologyEnableWizardStep.catalog:
        if (widget.showBackAction) {
          Navigator.of(context).pop(
            RadiologyEnableFacilityOfferingDialog.backResult,
          );
          return;
        }
        Navigator.of(context).pop(_enabledAny);
      case _RadiologyEnableWizardStep.price:
        _goToCatalog();
      case _RadiologyEnableWizardStep.preview:
        setState(() {
          _step = _RadiologyEnableWizardStep.price;
          _failure = null;
          _isSaving = false;
        });
    }
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
    for (final TextEditingController controller in _priceControllers.values) {
      controller.dispose();
    }
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
    final Result<List<RadiologyCatalogProcedure>> result = await widget
        .onSearchCatalog(
          scope: widget.scope,
          query: query?.trim().isEmpty ?? true ? null : query?.trim(),
          limit: _searchLimit,
        );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    result.when(
      success: (List<RadiologyCatalogProcedure> items) {
        setState(() {
          _catalogItems = items;
          _isSearching = false;
          _syncModalityFilterChoices();
          _pruneSelection();
        });
      },
      failure: (AppFailure value) {
        setState(() {
          _catalogItems = const <RadiologyCatalogProcedure>[];
          _isSearching = false;
          _modalityFilterChoices = const <AppSearchBarFilterChoice>[];
          _failure = value;
          _selectedIds.clear();
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

  Future<void> _submitAllSelected() async {
    final List<RadiologyCatalogProcedure> selected = _selectedAvailableItems;
    if (selected.isEmpty || !_selectionHasValidPrices(selected)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final List<RadiologyCatalogProcedure> enabled = <RadiologyCatalogProcedure>[];
    for (final RadiologyCatalogProcedure item in selected) {
      final String currency =
          _currencies[item.apiId] ?? item.currency ?? widget.defaultCurrency;
      final num unitPrice =
          num.tryParse(
            normalizeCurrencyAmount(_priceControllers[item.apiId]?.text ?? ''),
          ) ??
          0;
      final AppFailure? failure = await widget.onEnable(
        item.apiId,
        <String, Object?>{
          'radiology_test_id': item.apiId,
          'is_active': true,
          'unit_price': unitPrice,
          'currency': currency,
        },
      );
      if (!mounted) {
        return;
      }
      if (failure != null) {
        if (enabled.isNotEmpty) {
          _markItemsOfferedLocally(enabled);
        }
        setState(() {
          _failure = failure;
          _isSaving = false;
        });
        return;
      }
      enabled.add(item.copyWith(unitPrice: unitPrice, currency: currency));
    }
    _markItemsOfferedLocally(enabled);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(_titleForStep(l10n)),
      icon: Icon(_iconForStep),
      scrollable: true,
      maxWidth: _step == _RadiologyEnableWizardStep.catalog ? 980 : 720,
      closeEnabled: !_isSaving,
      content: switch (_step) {
        _RadiologyEnableWizardStep.catalog => _buildCatalogStep(context),
        _RadiologyEnableWizardStep.price => _buildPriceStep(context),
        _RadiologyEnableWizardStep.preview => _buildPreviewStep(context),
      },
      actions: _buildActions(context),
    );
  }

  String _titleForStep(AppLocalizations l10n) {
    return switch (_step) {
      _RadiologyEnableWizardStep.catalog =>
        l10n.radiologyEnableOfferingDialogTitle,
      _RadiologyEnableWizardStep.price =>
        l10n.radiologyEnableOfferingSetPricesTitle,
      _RadiologyEnableWizardStep.preview =>
        l10n.radiologyEnableOfferingPreviewTitle,
    };
  }

  IconData get _iconForStep {
    return switch (_step) {
      _RadiologyEnableWizardStep.catalog => Icons.add_circle_outline,
      _RadiologyEnableWizardStep.price => Icons.payments_outlined,
      _RadiologyEnableWizardStep.preview => Icons.checklist_outlined,
    };
  }

  VoidCallback? get _backPressed {
    if (_isSaving) {
      return null;
    }
    return _onWizardBack;
  }

  List<Widget> _buildActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int selectedCount = _selectedAvailableItems.length;
    final bool catalogCanNext = selectedCount > 0;
    final bool previewCanEnable =
        selectedCount > 0 &&
        _selectionHasValidPrices(_selectedAvailableItems);

    return <Widget>[
      AppButton.tertiary(
        label: l10n.commonBackActionLabel,
        leadingIcon: Icons.arrow_back_outlined,
        onPressed: _backPressed,
      ),
      if (_step == _RadiologyEnableWizardStep.catalog)
        AppButton.primary(
          label: l10n.commonNextActionLabel,
          leadingIcon: Icons.arrow_forward_outlined,
          enabled: catalogCanNext,
          tooltip: catalogCanNext
              ? l10n.commonNextActionLabel
              : l10n.radiologySelectAtLeastOneTestMessage,
          onPressed: catalogCanNext ? _goToPriceStep : null,
        ),
      if (_step == _RadiologyEnableWizardStep.price)
        AppButton.primary(
          label: l10n.commonNextActionLabel,
          leadingIcon: Icons.arrow_forward_outlined,
          enabled: selectedCount > 0,
          tooltip: selectedCount > 0
              ? l10n.commonNextActionLabel
              : l10n.radiologySelectAtLeastOneTestMessage,
          onPressed: selectedCount > 0 ? _goToPreview : null,
        ),
      if (_step == _RadiologyEnableWizardStep.preview)
        AppButton.primary(
          label: l10n.radiologyEnableSelectedProceduresAction,
          leadingIcon: Icons.check_circle_outline,
          isLoading: _isSaving,
          enabled: previewCanEnable && !_isSaving,
          tooltip: previewCanEnable
              ? l10n.radiologyEnableSelectedProceduresAction
              : l10n.radiologySelectAtLeastOneTestMessage,
          onPressed: previewCanEnable && !_isSaving
              ? () => unawaited(_submitAllSelected())
              : null,
        ),
      AppButton.tertiary(
        label: l10n.commonCloseActionLabel,
        leadingIcon: Icons.close,
        onPressed: _isSaving
            ? null
            : () => Navigator.of(context).pop(_enabledAny),
      ),
    ];
  }

  Widget _buildCatalogStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<RadiologyCatalogProcedure> items = _sortedFilteredCatalogItems;
    final int selectedCount = _selectedAvailableItems.length;
    final bool hasSearchOrFilter =
        _searchController.text.trim().isNotEmpty || _filterValue.isActive;
    final bool catalogEmpty = !_isSearching && _availableCatalogItems.isEmpty;
    final String emptyLabel = hasSearchOrFilter
        ? l10n.radiologyEnableOfferingNoItemsLabel
        : (catalogEmpty && _catalogItems.isNotEmpty
              ? l10n.radiologyEnableOfferingNoItemsLabel
              : l10n.radiologyEnableOfferingNoPlatformItemsLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_failure != null)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.md),
            child: AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          ),
        Text(
          l10n.radiologyEnableOfferingDialogBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.md),
        if (_isSearching) const LinearProgressIndicator(minHeight: 2),
        AppListTable<RadiologyCatalogProcedure>(
          items: items,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          tableHorizontalMargin: 0,
          isLoading: _isSearching,
          onRowSelected: (RadiologyCatalogProcedure item) {
            _toggleSelection(
              item,
              selected: !_selectedIds.contains(item.apiId),
            );
          },
          search: AppListTableSearch<RadiologyCatalogProcedure>(
            controller: _searchController,
            semanticLabel: l10n.radiologyConfigurationSearchLabel,
            hintText: l10n.radiologyConfigurationSearchHint,
            isLoading: _isSearching,
            matcher: (RadiologyCatalogProcedure item, String query) => true,
            onChanged: _scheduleCatalogSearch,
            showAdvancedFilterButton: true,
            advancedFilterButtonLabel: l10n.radiologyFiltersLabel,
            advancedFilterTitle: l10n.radiologyFiltersLabel,
            advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
            advancedFilterResetLabel: l10n.radiologyClearFiltersAction,
            enableDateFilter: false,
            allFieldsLabel: l10n.labScopeAll,
            filterGroups: <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: _modalityFilterKey,
                label: l10n.radiologyModalityLabel,
                allLabel: l10n.labScopeAll,
                choices: _modalityFilterChoices,
              ),
            ],
            filterValue: _filterValue,
            hasActiveFilters: _filterValue.isActive,
            onFilterChanged: (AppSearchBarFilterValue value) {
              setState(() => _filterValue = value);
            },
            trailingActions: <AppSearchBarAction>[
              if (selectedCount > 0)
                AppSearchBarAction(
                  icon: Icons.arrow_forward_outlined,
                  label: '${l10n.commonNextActionLabel} ($selectedCount)',
                  onPressed: _goToPriceStep,
                ),
            ],
          ),
          columns: _enableOfferingColumns(context),
          mobileItemBuilder:
              (BuildContext context, RadiologyCatalogProcedure item) {
                return AppListTableMobileItem(
                  leading: Checkbox(
                    value: _selectedIds.contains(item.apiId),
                    onChanged: (bool? value) => _toggleSelection(
                      item,
                      selected: value ?? false,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  showAvatar: false,
                  title: item.name,
                  caption: item.code,
                  meta: <AppListTableMobileMeta>[
                    if (item.modality != null)
                      AppListTableMobileMeta(
                        label: item.modality!,
                        icon: Icons.biotech_outlined,
                      ),
                  ],
                );
              },
        ),
        if (!_isSearching && items.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.sm),
            child: AppMutedText(emptyLabel),
          ),
      ],
    );
  }

  Widget _buildPriceStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<RadiologyCatalogProcedure> selected = _selectedAvailableItems;

    return Form(
      key: _priceFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.md),
              child: AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            ),
          Text(
            l10n.radiologyEnableSelectedProceduresBody(selected.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          if (selected.isEmpty)
            AppMutedText(l10n.radiologyEnableOfferingPreviewEmptyLabel)
          else
            ...selected.map((RadiologyCatalogProcedure item) {
              final TextEditingController? controller =
                  _priceControllers[item.apiId];
              if (controller == null) {
                return const SizedBox.shrink();
              }
              final String currency =
                  _currencies[item.apiId] ?? widget.defaultCurrency;
              return Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.lg),
                child: AppFormSection(
                  children: <Widget>[
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.code != null && item.code!.isNotEmpty)
                      AppMutedText(
                        <String?>[
                          item.code,
                          item.modality,
                        ].whereType<String>().join(' · '),
                      ),
                    AppCurrencyAmountField(
                      amountController: controller,
                      currency: currency,
                      amountLabelText: l10n.clinicalRequestUnitPriceLabel,
                      currencyLabelText: l10n.opdCurrencyLabel,
                      enabled: !_isSaving,
                      isRequired: true,
                      allowZero: false,
                      onCurrencyChanged: (String? value) {
                        setState(() {
                          _currencies[item.apiId] =
                              value ?? appDefaultCurrencyCode;
                        });
                      },
                      validator: (String? value) =>
                          _positiveUnitPriceValidator(l10n, value),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPreviewStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<RadiologyCatalogProcedure> selected = _selectedAvailableItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_failure != null)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.md),
            child: AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          ),
        Text(
          l10n.radiologyEnableOfferingPreviewBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.md),
        if (selected.isEmpty)
          AppMutedText(l10n.radiologyEnableOfferingPreviewEmptyLabel)
        else
          AppListTable<RadiologyCatalogProcedure>(
            items: selected,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            tableHorizontalMargin: 0,
            columns: <AppListTableColumn<RadiologyCatalogProcedure>>[
              AppListTableColumn<RadiologyCatalogProcedure>(
                id: 'select',
                label: l10n.commonSelectActionLabel,
                alwaysVisible: true,
                cellBuilder: (_, RadiologyCatalogProcedure item) {
                  return Checkbox(
                    value: _selectedIds.contains(item.apiId),
                    onChanged: _isSaving
                        ? null
                        : (bool? value) =>
                              _toggleSelection(item, selected: value ?? false),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
              AppListTableColumn<RadiologyCatalogProcedure>(
                id: 'name',
                label: l10n.radiologyProcedureNameLabel,
                cellBuilder: (_, RadiologyCatalogProcedure item) => Text(item.name),
              ),
              AppListTableColumn<RadiologyCatalogProcedure>(
                id: 'code',
                label: l10n.radiologyProcedureCodeLabel,
                cellBuilder: (_, RadiologyCatalogProcedure item) =>
                    Text(item.code ?? l10n.profileUnknownValue),
              ),
              AppListTableColumn<RadiologyCatalogProcedure>(
                id: 'modality',
                label: l10n.radiologyModalityLabel,
                cellBuilder: (_, RadiologyCatalogProcedure item) =>
                    Text(item.modality ?? l10n.profileUnknownValue),
              ),
              AppListTableColumn<RadiologyCatalogProcedure>(
                id: 'price',
                label: l10n.clinicalRequestUnitPriceLabel,
                cellBuilder: (_, RadiologyCatalogProcedure item) =>
                    Text(_priceDisplay(item)),
              ),
            ],
            mobileItemBuilder:
                (BuildContext context, RadiologyCatalogProcedure item) {
                  return AppListTableMobileItem(
                    leading: Checkbox(
                      value: _selectedIds.contains(item.apiId),
                      onChanged: _isSaving
                          ? null
                          : (bool? value) => _toggleSelection(
                              item,
                              selected: value ?? false,
                            ),
                      visualDensity: VisualDensity.compact,
                    ),
                    showAvatar: false,
                    title: item.name,
                    caption: item.code,
                    meta: <AppListTableMobileMeta>[
                      if (item.modality != null)
                        AppListTableMobileMeta(
                          label: item.modality!,
                          icon: Icons.biotech_outlined,
                        ),
                      AppListTableMobileMeta(
                        label: _priceDisplay(item),
                        icon: Icons.payments_outlined,
                      ),
                    ],
                  );
                },
          ),
      ],
    );
  }

  List<AppListTableColumn<RadiologyCatalogProcedure>> _enableOfferingColumns(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    return <AppListTableColumn<RadiologyCatalogProcedure>>[
      AppListTableColumn<RadiologyCatalogProcedure>(
        id: 'select',
        label: l10n.commonSelectActionLabel,
        alwaysVisible: true,
        cellBuilder: (_, RadiologyCatalogProcedure item) {
          return Checkbox(
            value: _selectedIds.contains(item.apiId),
            onChanged: (bool? value) =>
                _toggleSelection(item, selected: value ?? false),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
      AppListTableColumn<RadiologyCatalogProcedure>(
        id: 'name',
        label: l10n.radiologyProcedureNameLabel,
        sortComparator:
            (RadiologyCatalogProcedure left, RadiologyCatalogProcedure right) =>
                appListTableCompareText(left.name, right.name),
        cellBuilder: (_, RadiologyCatalogProcedure item) => Text(item.name),
      ),
      AppListTableColumn<RadiologyCatalogProcedure>(
        id: 'code',
        label: l10n.radiologyProcedureCodeLabel,
        sortComparator:
            (RadiologyCatalogProcedure left, RadiologyCatalogProcedure right) =>
                appListTableCompareText(left.code, right.code),
        cellBuilder: (_, RadiologyCatalogProcedure item) =>
            Text(item.code ?? l10n.profileUnknownValue),
      ),
      AppListTableColumn<RadiologyCatalogProcedure>(
        id: 'modality',
        label: l10n.radiologyModalityLabel,
        sortComparator:
            (RadiologyCatalogProcedure left, RadiologyCatalogProcedure right) =>
                appListTableCompareText(left.modality, right.modality),
        cellBuilder: (_, RadiologyCatalogProcedure item) =>
            Text(item.modality ?? l10n.profileUnknownValue),
      ),
    ];
  }
}

/// Standalone single-procedure price dialog (workspace / nested callers).
class RadiologyEnableOfferingPriceDialog extends StatefulWidget {
  const RadiologyEnableOfferingPriceDialog({
    required this.item,
    required this.onEnable,
    required this.defaultCurrency,
    this.showBackAction = false,
    super.key,
  });

  final RadiologyCatalogProcedure item;
  final RadiologyCatalogUpdateSubmit onEnable;
  final String defaultCurrency;
  final bool showBackAction;

  @override
  State<RadiologyEnableOfferingPriceDialog> createState() =>
      _RadiologyEnableOfferingPriceDialogState();
}

class _RadiologyEnableOfferingPriceDialogState
    extends State<RadiologyEnableOfferingPriceDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late String _currency;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.item.unitPrice?.toString() ?? '',
    );
    _currency = widget.item.currency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyCatalogProcedure item = widget.item;

    return AppDialog(
      title: Text(l10n.radiologyEnableProcedureAction),
      icon: const Icon(Icons.image_search_outlined),
      scrollable: true,
      maxWidth: 520,
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
            Text(
              item.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.code != null && item.code!.isNotEmpty)
              AppMutedText(
                <String?>[
                  item.code,
                  item.modality,
                ].whereType<String>().join(' · '),
              ),
            AppCurrencyAmountField(
              amountController: _priceController,
              currency: _currency,
              amountLabelText: l10n.clinicalRequestUnitPriceLabel,
              currencyLabelText: l10n.opdCurrencyLabel,
              enabled: !_isSaving,
              isRequired: true,
              allowZero: false,
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
              validator: (String? value) =>
                  _positiveUnitPriceValidator(l10n, value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.showBackAction)
          AppButton.tertiary(
            label: l10n.commonBackActionLabel,
            leadingIcon: Icons.arrow_back_outlined,
            onPressed: _isSaving
                ? null
                : () => Navigator.of(context).pop(false),
          ),
        AppButton.primary(
          label: l10n.radiologyEnableProcedureAction,
          leadingIcon: Icons.check_circle_outline,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget
        .onEnable(widget.item.apiId, <String, Object?>{
          'radiology_test_id': widget.item.apiId,
          'is_active': true,
          'unit_price':
              num.tryParse(normalizeCurrencyAmount(_priceController.text)) ?? 0,
          'currency': _currency,
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
      _isSaving = false;
    });
  }
}

class RadiologyEditFacilityOfferingDialog extends StatefulWidget {
  const RadiologyEditFacilityOfferingDialog({
    required this.item,
    required this.onUpdate,
    this.defaultCurrency = appDefaultCurrencyCode,
    super.key,
  });

  final RadiologyCatalogProcedure item;
  final RadiologyCatalogUpdateSubmit onUpdate;
  final String defaultCurrency;

  @override
  State<RadiologyEditFacilityOfferingDialog> createState() =>
      _RadiologyEditFacilityOfferingDialogState();
}

class _RadiologyEditFacilityOfferingDialogState
    extends State<RadiologyEditFacilityOfferingDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late String _currency;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.item.unitPrice?.toString() ?? '',
    );
    _currency = widget.item.currency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.radiologyEditOfferingDialogTitle),
      icon: const Icon(Icons.edit_outlined),
      scrollable: true,
      maxWidth: 520,
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
            Text(
              widget.item.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            AppCurrencyAmountField(
              amountController: _priceController,
              currency: _currency,
              amountLabelText: l10n.clinicalRequestUnitPriceLabel,
              currencyLabelText: l10n.opdCurrencyLabel,
              enabled: !_isSaving,
              isRequired: true,
              allowZero: false,
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
              validator: (String? value) =>
                  _positiveUnitPriceValidator(l10n, value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.radiologySaveConfigurationAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget
        .onUpdate(widget.item.apiId, <String, Object?>{
          'radiology_test_id': widget.item.apiId,
          'is_active': true,
          'unit_price':
              num.tryParse(normalizeCurrencyAmount(_priceController.text)) ?? 0,
          'currency': _currency,
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
      _isSaving = false;
    });
  }
}

String? _positiveUnitPriceValidator(AppLocalizations l10n, String? value) {
  final String normalized = normalizeCurrencyAmount(value ?? '');
  if (normalized.isEmpty) {
    return l10n.validationRequired;
  }
  final num? parsed = num.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return l10n.validationRequired;
  }
  return null;
}
