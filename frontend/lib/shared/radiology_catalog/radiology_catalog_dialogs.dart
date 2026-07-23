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
    Future<Result<List<RadiologyCatalogTest>>> Function({
      required RadiologyCatalogScope scope,
      String? query,
      int limit,
    });

enum _RadiologyEnableWizardStep { catalog, preview, price }

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
  late final TextEditingController _priceController;
  final GlobalKey<FormState> _priceFormKey = GlobalKey<FormState>();
  Timer? _searchDebounce;
  List<RadiologyCatalogTest> _catalogItems = const <RadiologyCatalogTest>[];
  AppFailure? _failure;
  bool _isSearching = true;
  int _searchRequest = 0;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  List<AppSearchBarFilterChoice> _modalityFilterChoices =
      const <AppSearchBarFilterChoice>[];
  final Set<String> _selectedIds = <String>{};
  bool _enabledAny = false;
  _RadiologyEnableWizardStep _step = _RadiologyEnableWizardStep.catalog;
  List<RadiologyCatalogTest> _priceQueue = const <RadiologyCatalogTest>[];
  int _priceIndex = 0;
  late String _currency;
  bool _isSaving = false;

  List<RadiologyCatalogTest> get _filteredCatalogItems {
    final String? modality = _filterValue.option(_modalityFilterKey);
    if (modality == null) {
      return _catalogItems;
    }
    return _catalogItems
        .where((RadiologyCatalogTest item) => item.modality == modality)
        .toList(growable: false);
  }

  List<RadiologyCatalogTest> get _sortedFilteredCatalogItems {
    final List<RadiologyCatalogTest> items = List<RadiologyCatalogTest>.of(
      _filteredCatalogItems,
    );
    items.sort((RadiologyCatalogTest left, RadiologyCatalogTest right) {
      if (left.isOfferedAtFacility != right.isOfferedAtFacility) {
        return left.isOfferedAtFacility ? -1 : 1;
      }
      return appListTableCompareText(left.name, right.name);
    });
    return items;
  }

  List<RadiologyCatalogTest> get _selectedAvailableItems {
    return _catalogItems
        .where(
          (RadiologyCatalogTest item) =>
              !item.isOfferedAtFacility && _selectedIds.contains(item.apiId),
        )
        .toList(growable: false)
      ..sort(
        (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
            appListTableCompareText(left.name, right.name),
      );
  }

  RadiologyCatalogTest? get _currentPriceItem {
    if (_priceIndex < 0 || _priceIndex >= _priceQueue.length) {
      return null;
    }
    return _priceQueue[_priceIndex];
  }

  void _markItemOfferedLocally(RadiologyCatalogTest item) {
    setState(() {
      _catalogItems = _catalogItems
          .map((RadiologyCatalogTest catalogItem) {
            if (catalogItem.apiId != item.apiId) {
              return catalogItem;
            }
            return catalogItem.copyWith(
              unitPrice: item.unitPrice ?? catalogItem.unitPrice,
              currency: item.currency ?? catalogItem.currency,
              isOfferedAtFacility: true,
              facilityOfferingId:
                  item.facilityOfferingId ?? catalogItem.facilityOfferingId,
            );
          })
          .toList(growable: false);
      _selectedIds.remove(item.apiId);
      _enabledAny = true;
    });
  }

  void _syncModalityFilterChoices() {
    final Set<String> values = <String>{};
    for (final RadiologyCatalogTest item in _catalogItems) {
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
    final Set<String> valid = _catalogItems
        .where((RadiologyCatalogTest item) => !item.isOfferedAtFacility)
        .map((RadiologyCatalogTest item) => item.apiId)
        .toSet();
    _selectedIds.removeWhere((String id) => !valid.contains(id));
  }

  void _toggleSelection(RadiologyCatalogTest item, {required bool selected}) {
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

  void _loadPriceFields(RadiologyCatalogTest item) {
    _priceController.text = item.unitPrice?.toString() ?? '';
    _currency = item.currency ?? widget.defaultCurrency;
    _failure = null;
    _isSaving = false;
  }

  void _goToCatalog() {
    setState(() {
      _step = _RadiologyEnableWizardStep.catalog;
      _priceQueue = const <RadiologyCatalogTest>[];
      _priceIndex = 0;
      _failure = null;
      _isSaving = false;
    });
  }

  void _goToPreview() {
    final List<RadiologyCatalogTest> selected = _selectedAvailableItems;
    if (selected.isEmpty) {
      return;
    }
    setState(() {
      _step = _RadiologyEnableWizardStep.preview;
      _failure = null;
      _isSaving = false;
    });
  }

  void _goToPriceQueue() {
    final List<RadiologyCatalogTest> selected = _selectedAvailableItems;
    if (selected.isEmpty) {
      return;
    }
    setState(() {
      _priceQueue = selected;
      _priceIndex = 0;
      _step = _RadiologyEnableWizardStep.price;
      _loadPriceFields(selected.first);
    });
  }

  void _selectSingleAndPreview(RadiologyCatalogTest item) {
    if (item.isOfferedAtFacility) {
      return;
    }
    setState(() {
      _selectedIds
        ..clear()
        ..add(item.apiId);
      _step = _RadiologyEnableWizardStep.preview;
      _failure = null;
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
      case _RadiologyEnableWizardStep.preview:
        _goToCatalog();
      case _RadiologyEnableWizardStep.price:
        setState(() {
          _step = _RadiologyEnableWizardStep.preview;
          _priceQueue = const <RadiologyCatalogTest>[];
          _priceIndex = 0;
          _failure = null;
          _isSaving = false;
        });
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _priceController = TextEditingController();
    _currency = widget.defaultCurrency;
    _searchRequest += 1;
    unawaited(_loadCatalog(query: null, requestId: _searchRequest));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _priceController.dispose();
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
    final Result<List<RadiologyCatalogTest>> result = await widget
        .onSearchCatalog(
          scope: widget.scope,
          query: query?.trim().isEmpty ?? true ? null : query?.trim(),
          limit: _searchLimit,
        );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    result.when(
      success: (List<RadiologyCatalogTest> items) {
        setState(() {
          _catalogItems = items;
          _isSearching = false;
          _syncModalityFilterChoices();
          _pruneSelection();
        });
      },
      failure: (AppFailure value) {
        setState(() {
          _catalogItems = const <RadiologyCatalogTest>[];
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

  Future<void> _submitCurrentPrice() async {
    final RadiologyCatalogTest? item = _currentPriceItem;
    if (item == null) {
      return;
    }
    if (!(_priceFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final num unitPrice =
        num.tryParse(normalizeCurrencyAmount(_priceController.text)) ?? 0;
    final AppFailure? failure = await widget.onEnable(
      item.apiId,
      <String, Object?>{
        'radiology_test_id': item.apiId,
        'is_active': true,
        'unit_price': unitPrice,
        'currency': _currency,
      },
    );
    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _failure = failure;
        _isSaving = false;
      });
      return;
    }
    _markItemOfferedLocally(
      item.copyWith(unitPrice: unitPrice, currency: _currency),
    );
    if (!mounted) {
      return;
    }
    if (_priceIndex + 1 < _priceQueue.length) {
      setState(() {
        _priceIndex += 1;
        _loadPriceFields(_priceQueue[_priceIndex]);
      });
      return;
    }
    _goToCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(_titleForStep(l10n)),
      icon: Icon(_iconForStep),
      scrollable: true,
      maxWidth: _step == _RadiologyEnableWizardStep.price ? 560 : 980,
      closeEnabled: !_isSaving,
      content: switch (_step) {
        _RadiologyEnableWizardStep.catalog => _buildCatalogStep(context),
        _RadiologyEnableWizardStep.preview => _buildPreviewStep(context),
        _RadiologyEnableWizardStep.price => _buildPriceStep(context),
      },
      actions: _buildActions(context),
    );
  }

  String _titleForStep(AppLocalizations l10n) {
    return switch (_step) {
      _RadiologyEnableWizardStep.catalog =>
        l10n.radiologyEnableOfferingDialogTitle,
      _RadiologyEnableWizardStep.preview =>
        l10n.radiologyEnableOfferingPreviewTitle,
      _RadiologyEnableWizardStep.price => l10n.radiologyEnableProcedureAction,
    };
  }

  IconData get _iconForStep {
    return switch (_step) {
      _RadiologyEnableWizardStep.catalog => Icons.add_circle_outline,
      _RadiologyEnableWizardStep.preview => Icons.checklist_outlined,
      _RadiologyEnableWizardStep.price => Icons.image_search_outlined,
    };
  }

  bool get _showBackButton => true;

  VoidCallback? get _backPressed {
    if (_isSaving) {
      return null;
    }
    return _onWizardBack;
  }

  List<Widget> _buildActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int selectedCount = _selectedAvailableItems.length;
    return <Widget>[
      if (_showBackButton)
        AppButton.tertiary(
          label: l10n.commonBackActionLabel,
          leadingIcon: Icons.arrow_back_outlined,
          onPressed: _backPressed,
        ),
      AppButton.tertiary(
        label: l10n.commonCloseActionLabel,
        leadingIcon: Icons.close,
        onPressed: _isSaving
            ? null
            : () => Navigator.of(context).pop(_enabledAny),
      ),
      if (_step == _RadiologyEnableWizardStep.catalog && selectedCount > 0)
        AppButton.primary(
          label: l10n.commonNextActionLabel,
          leadingIcon: Icons.arrow_forward_outlined,
          onPressed: _goToPreview,
        ),
      if (_step == _RadiologyEnableWizardStep.preview)
        AppButton.primary(
          label: l10n.commonNextActionLabel,
          leadingIcon: Icons.arrow_forward_outlined,
          onPressed: selectedCount > 0 ? _goToPriceQueue : null,
        ),
      if (_step == _RadiologyEnableWizardStep.price)
        AppButton.primary(
          label: l10n.radiologyEnableProcedureAction,
          leadingIcon: Icons.check_circle_outline,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : () => unawaited(_submitCurrentPrice()),
        ),
    ];
  }

  Widget _buildCatalogStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<RadiologyCatalogTest> items = _sortedFilteredCatalogItems;
    final int selectedCount = _selectedAvailableItems.length;
    final bool hasSearchOrFilter =
        _searchController.text.trim().isNotEmpty || _filterValue.isActive;
    final String emptyLabel = hasSearchOrFilter
        ? l10n.radiologyEnableOfferingNoItemsLabel
        : l10n.radiologyEnableOfferingNoPlatformItemsLabel;

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
        AppListTable<RadiologyCatalogTest>(
          items: items,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          tableHorizontalMargin: 0,
          isLoading: _isSearching,
          onRowSelected: (RadiologyCatalogTest item) {
            if (item.isOfferedAtFacility) {
              return;
            }
            _toggleSelection(
              item,
              selected: !_selectedIds.contains(item.apiId),
            );
          },
          search: AppListTableSearch<RadiologyCatalogTest>(
            controller: _searchController,
            semanticLabel: l10n.radiologyConfigurationSearchLabel,
            hintText: l10n.radiologyConfigurationSearchHint,
            isLoading: _isSearching,
            matcher: (RadiologyCatalogTest item, String query) => true,
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
                  onPressed: _goToPreview,
                ),
            ],
          ),
          columns: _enableOfferingColumns(context),
          mobileItemBuilder:
              (BuildContext context, RadiologyCatalogTest item) {
                final bool selectable = !item.isOfferedAtFacility;
                return AppListTableMobileItem(
                  leading: selectable
                      ? Checkbox(
                          value: _selectedIds.contains(item.apiId),
                          onChanged: (bool? value) => _toggleSelection(
                            item,
                            selected: value ?? false,
                          ),
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                  showAvatar: !selectable,
                  title: item.name,
                  caption: item.code,
                  meta: <AppListTableMobileMeta>[
                    if (item.modality != null)
                      AppListTableMobileMeta(
                        label: item.modality!,
                        icon: Icons.biotech_outlined,
                      ),
                    if (item.isOfferedAtFacility)
                      AppListTableMobileMeta(
                        label:
                            l10n.radiologyEnableOfferingAlreadyOfferedLabel,
                        icon: AppActionIcons.success,
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

  Widget _buildPreviewStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<RadiologyCatalogTest> selected = _selectedAvailableItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
          AppListTable<RadiologyCatalogTest>(
            items: selected,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            tableHorizontalMargin: 0,
            columns: <AppListTableColumn<RadiologyCatalogTest>>[
              AppListTableColumn<RadiologyCatalogTest>(
                id: 'select',
                label: l10n.commonSelectActionLabel,
                alwaysVisible: true,
                cellBuilder: (_, RadiologyCatalogTest item) {
                  return Checkbox(
                    value: _selectedIds.contains(item.apiId),
                    onChanged: (bool? value) =>
                        _toggleSelection(item, selected: value ?? false),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
              AppListTableColumn<RadiologyCatalogTest>(
                id: 'name',
                label: l10n.radiologyTestNameLabel,
                cellBuilder: (_, RadiologyCatalogTest item) => Text(item.name),
              ),
              AppListTableColumn<RadiologyCatalogTest>(
                id: 'code',
                label: l10n.radiologyTestCodeLabel,
                cellBuilder: (_, RadiologyCatalogTest item) =>
                    Text(item.code ?? l10n.profileUnknownValue),
              ),
              AppListTableColumn<RadiologyCatalogTest>(
                id: 'modality',
                label: l10n.radiologyModalityLabel,
                cellBuilder: (_, RadiologyCatalogTest item) =>
                    Text(item.modality ?? l10n.profileUnknownValue),
              ),
            ],
            mobileItemBuilder:
                (BuildContext context, RadiologyCatalogTest item) {
                  return AppListTableMobileItem(
                    leading: Checkbox(
                      value: _selectedIds.contains(item.apiId),
                      onChanged: (bool? value) =>
                          _toggleSelection(item, selected: value ?? false),
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
      ],
    );
  }

  Widget _buildPriceStep(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyCatalogTest? item = _currentPriceItem;
    if (item == null) {
      return AppMutedText(l10n.radiologyEnableOfferingPreviewEmptyLabel);
    }

    return Form(
      key: _priceFormKey,
      child: AppFormSection(
        children: <Widget>[
          if (_priceQueue.length > 1)
            Text(
              l10n.radiologyEnableOfferingPriceProgressLabel(
                _priceIndex + 1,
                _priceQueue.length,
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    );
  }

  List<AppListTableColumn<RadiologyCatalogTest>> _enableOfferingColumns(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    return <AppListTableColumn<RadiologyCatalogTest>>[
      AppListTableColumn<RadiologyCatalogTest>(
        id: 'select',
        label: l10n.commonSelectActionLabel,
        alwaysVisible: true,
        cellBuilder: (_, RadiologyCatalogTest item) {
          if (item.isOfferedAtFacility) {
            return const SizedBox.shrink();
          }
          return Checkbox(
            value: _selectedIds.contains(item.apiId),
            onChanged: (bool? value) =>
                _toggleSelection(item, selected: value ?? false),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
      AppListTableColumn<RadiologyCatalogTest>(
        id: 'name',
        label: l10n.radiologyTestNameLabel,
        sortComparator:
            (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
                appListTableCompareText(left.name, right.name),
        cellBuilder: (_, RadiologyCatalogTest item) => Text(item.name),
      ),
      AppListTableColumn<RadiologyCatalogTest>(
        id: 'code',
        label: l10n.radiologyTestCodeLabel,
        sortComparator:
            (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
                appListTableCompareText(left.code, right.code),
        cellBuilder: (_, RadiologyCatalogTest item) =>
            Text(item.code ?? l10n.profileUnknownValue),
      ),
      AppListTableColumn<RadiologyCatalogTest>(
        id: 'modality',
        label: l10n.radiologyModalityLabel,
        sortComparator:
            (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
                appListTableCompareText(left.modality, right.modality),
        cellBuilder: (_, RadiologyCatalogTest item) =>
            Text(item.modality ?? l10n.profileUnknownValue),
      ),
      AppListTableColumn<RadiologyCatalogTest>(
        id: 'status',
        label: l10n.radiologyStatusColumnLabel,
        cellBuilder: (_, RadiologyCatalogTest item) {
          if (item.isOfferedAtFacility) {
            return AppMutedText(
              l10n.radiologyEnableOfferingAlreadyOfferedLabel,
            );
          }
          return AppMutedText(l10n.radiologyEnableOfferingAvailableLabel);
        },
      ),
      AppListTableColumn<RadiologyCatalogTest>(
        id: 'actions',
        label: l10n.accessAdminColumnActions,
        cellBuilder: (BuildContext context, RadiologyCatalogTest item) {
          if (item.isOfferedAtFacility) {
            return const SizedBox.shrink();
          }
          return AppButton(
            iconOnly: true,
            leadingIcon: Icons.arrow_forward_outlined,
            label: l10n.commonNextActionLabel,
            semanticLabel: l10n.commonNextActionLabel,
            tooltip: l10n.commonNextActionLabel,
            onPressed: () => _selectSingleAndPreview(item),
          );
        },
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

  final RadiologyCatalogTest item;
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
    final RadiologyCatalogTest item = widget.item;

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

  final RadiologyCatalogTest item;
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
