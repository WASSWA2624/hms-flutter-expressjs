import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_layer_selector.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_fields.dart';

enum ClinicalLabRequestCatalogKind { tests, panels }

final class ClinicalLabRequestCatalogSelection {
  const ClinicalLabRequestCatalogSelection({
    required this.option,
    required this.kind,
  });

  final ClinicalActionCatalogOption option;
  final ClinicalLabRequestCatalogKind kind;

  String get key => '${kind.name}:${option.apiId}';
}

List<ClinicalActionCatalogOption> orderClinicalLabRequestCatalogItems(
  List<ClinicalActionCatalogOption> catalog, {
  required bool Function(ClinicalActionCatalogOption option) includeOption,
  required bool Function(ClinicalActionCatalogOption option) isSelected,
}) {
  final List<ClinicalActionCatalogOption> selected =
      <ClinicalActionCatalogOption>[];
  final List<ClinicalActionCatalogOption> unselected =
      <ClinicalActionCatalogOption>[];
  for (final ClinicalActionCatalogOption option in catalog) {
    if (!includeOption(option)) {
      continue;
    }
    if (isSelected(option)) {
      selected.add(option);
    } else {
      unselected.add(option);
    }
  }
  return <ClinicalActionCatalogOption>[...selected, ...unselected];
}

Future<List<ClinicalLabRequestCatalogSelection>?>
showClinicalLabRequestCatalogDialog({
  required BuildContext context,
  required ClinicalActionReferenceData referenceData,
  required Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })
  onSearchLabTests,
  required List<ClinicalLabRequestCatalogSelection> initialSelections,
  ClinicalLabRequestCatalogKind initialKind =
      ClinicalLabRequestCatalogKind.tests,
  bool facilityOfferingsOnly = false,
}) {
  return showAppDialog<List<ClinicalLabRequestCatalogSelection>>(
    context: context,
    builder: (BuildContext context) => ClinicalLabRequestCatalogDialog(
      referenceData: referenceData,
      onSearchLabTests: onSearchLabTests,
      initialSelections: initialSelections,
      initialKind: initialKind,
      facilityOfferingsOnly: facilityOfferingsOnly,
    ),
  );
}

class ClinicalLabRequestCatalogDialog extends StatefulWidget {
  const ClinicalLabRequestCatalogDialog({
    required this.referenceData,
    required this.onSearchLabTests,
    required this.initialSelections,
    this.initialKind = ClinicalLabRequestCatalogKind.tests,
    this.facilityOfferingsOnly = false,
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })
  onSearchLabTests;
  final List<ClinicalLabRequestCatalogSelection> initialSelections;
  final ClinicalLabRequestCatalogKind initialKind;
  final bool facilityOfferingsOnly;

  @override
  State<ClinicalLabRequestCatalogDialog> createState() =>
      _ClinicalLabRequestCatalogDialogState();
}

class _ClinicalLabRequestCatalogDialogState
    extends State<ClinicalLabRequestCatalogDialog> {
  static const int _maxVisibleCatalogOptions = 100;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 160);
  static const String _categoryFilterKey = 'category';
  static const String _selectColumnKey = 'select';
  static const String _nameColumnKey = 'name';
  static const String _codeColumnKey = 'code';
  static const String _categoryColumnKey = 'category';
  static const String _priceColumnKey = 'price';
  static const String _columnVisibilityStorageKey =
      'clinical-lab-request-catalog';

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<ClinicalActionCatalogOption>
  _columnVisibilityController;
  late final List<ClinicalLabRequestCatalogSelection> _stagedSelections;
  Timer? _searchDebounce;
  late ClinicalLabRequestCatalogKind _selectionKind;
  ClinicalCatalogSource _catalogSource = ClinicalCatalogSource.facility;
  String _searchQuery = '';
  int _searchRequest = 0;
  List<ClinicalActionCatalogOption> _testCatalogOptions =
      const <ClinicalActionCatalogOption>[];
  List<ClinicalActionCatalogOption> _panelCatalogOptions =
      const <ClinicalActionCatalogOption>[];
  List<ClinicalActionCatalogOption> _favoriteTestOptions =
      const <ClinicalActionCatalogOption>[];
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  bool _isSearching = false;
  AppFailure? _catalogFailure;

  bool get _showingTests =>
      _selectionKind == ClinicalLabRequestCatalogKind.tests;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<ClinicalActionCatalogOption>();
    _stagedSelections = List<ClinicalLabRequestCatalogSelection>.from(
      widget.initialSelections,
    );
    _selectionKind = widget.initialKind;
    _searchRequest += 1;
    if (widget.facilityOfferingsOnly) {
      _catalogSource = ClinicalCatalogSource.facility;
    }
    unawaited(_loadTestCatalog(_searchQuery, _searchRequest));
    unawaited(_loadPanelCatalog(_searchQuery, _searchRequest));
    if (!widget.facilityOfferingsOnly) {
      unawaited(_loadFavoriteTests());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalActionCatalogOption> catalog = _sortedCatalogItems(
      _catalogForSelection(),
    );
    final List<AppListTableColumn<ClinicalActionCatalogOption>> columns =
        _catalogColumns(context);
    final List<AppListTableColumn<ClinicalActionCatalogOption>> columnChoices =
        columns
            .where(
              (AppListTableColumn<ClinicalActionCatalogOption> column) =>
                  column.key != _selectColumnKey,
            )
            .toList(growable: false);

    return AppDialog(
      title: Text(l10n.clinicalLabRequestCatalogPickerTitle),
      icon: const Icon(Icons.manage_search_outlined),
      maxWidth: 980,
      pinActionsToBottom: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_catalogFailure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _catalogFailure!,
            ),
          _CatalogKindRadioGroup(
            value: _selectionKind,
            testsLabel: l10n.clinicalLabRequestTestsModeLabel,
            panelsLabel: l10n.clinicalLabRequestPanelsModeLabel,
            onChanged: (ClinicalLabRequestCatalogKind kind) {
              setState(() => _selectionKind = kind);
              _searchRequest += 1;
              if (kind == ClinicalLabRequestCatalogKind.tests) {
                unawaited(_loadTestCatalog(_searchQuery, _searchRequest));
                return;
              }
              unawaited(_loadPanelCatalog(_searchQuery, _searchRequest));
            },
          ),
          if (_showingTests && !widget.facilityOfferingsOnly) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            ClinicalCatalogLayerSelector(
              value: _catalogSource,
              onChanged: (ClinicalCatalogSource source) {
                setState(() => _catalogSource = source);
                _searchRequest += 1;
                unawaited(_loadTestCatalog(_searchQuery, _searchRequest));
              },
            ),
            if (_favoriteTestOptions.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.labOrderFavoriteTestsLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  for (final ClinicalActionCatalogOption option
                      in _favoriteTestOptions)
                    ActionChip(
                      label: Text(option.displayTitle),
                      onPressed: () => _toggleSelection(option, selected: true),
                    ),
                ],
              ),
            ],
          ],
          SizedBox(height: theme.spacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.clinicalLabRequestSelectedCount(_stagedSelections.length),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: AppFontWeight.emphasis,
                color: colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          Expanded(
            child: AppListTable<ClinicalActionCatalogOption>(
              items: catalog,
              columns: columns,
              columnChoices: columnChoices,
              columnVisibilityController: _columnVisibilityController,
              columnVisibilityStorageKey: _columnVisibilityStorageKey,
              columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
              columnVisibilityTitle: l10n.clinicalLabRequestCatalogColumnsTitle,
              columnVisibilityApplyLabel: l10n.labApplyColumnsAction,
              columnVisibilityResetLabel: l10n.labResetColumnsAction,
              displayMode: AppListTableDisplayMode.table,
              tableHorizontalMargin: 0,
              showRowNumbers: false,
              isLoading: _isSearching,
              onRowSelected: (ClinicalActionCatalogOption item) {
                _toggleSelection(
                  item,
                  selected: !_isStagedSelected(item, _selectionKind),
                );
              },
              rowColorBuilder:
                  (BuildContext context, ClinicalActionCatalogOption item) {
                    if (!_isStagedSelected(item, _selectionKind)) {
                      return null;
                    }
                    return colorScheme.primaryContainer.withValues(alpha: 0.35);
                  },
              search: AppListTableSearch<ClinicalActionCatalogOption>(
                controller: _searchController,
                semanticLabel: l10n.clinicalLabRequestSearchLabel,
                hintText: l10n.clinicalLabRequestSearchHint,
                isLoading: _isSearching,
                matcher: _matchesCatalogSearch,
                onChanged: _scheduleSearch,
                showAdvancedFilterButton: true,
                advancedFilterButtonLabel: l10n.labFiltersLabel,
                advancedFilterTitle: l10n.labFiltersLabel,
                advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                advancedFilterResetLabel: l10n.opdClearFiltersAction,
                enableDateFilter: false,
                allFieldsLabel: l10n.labScopeAll,
                filterGroups: _categoryFilterGroups(l10n),
                filterValue: _filterValue,
                hasActiveFilters: _filterValue.isActive,
                onFilterChanged: (AppSearchBarFilterValue value) {
                  setState(() => _filterValue = value);
                },
              ),
              emptyBuilder: (_) =>
                  AppMutedText(l10n.clinicalLabRequestNoCatalogOptions),
              mobileItemBuilder:
                  (BuildContext context, ClinicalActionCatalogOption item) {
                    final bool selected = _isStagedSelected(
                      item,
                      _selectionKind,
                    );
                    return InkWell(
                      onTap: () =>
                          _toggleSelection(item, selected: !selected),
                      child: AppListTableMobileItem(
                        leading: IgnorePointer(
                          child: Checkbox(
                            value: selected,
                            onChanged: (_) {},
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        title: item.name ?? item.displayTitle,
                        caption: item.code,
                        meta: <AppListTableMobileMeta>[
                          if ((item.category ?? '').isNotEmpty)
                            AppListTableMobileMeta(label: item.category!),
                        ],
                        showAvatar: false,
                      ),
                    );
                  },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.close(
          leadingIcon: AppActionIcons.cancel,
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.clinicalLabRequestCatalogPickerConfirmAction,
          leadingIcon: Icons.playlist_add_check,
          onPressed: () => Navigator.of(context).pop(
            List<ClinicalLabRequestCatalogSelection>.from(_stagedSelections),
          ),
        ),
      ],
    );
  }

  bool _isStagedSelected(
    ClinicalActionCatalogOption option,
    ClinicalLabRequestCatalogKind kind,
  ) {
    final String key = ClinicalLabRequestCatalogSelection(
      option: option,
      kind: kind,
    ).key;
    return _stagedSelections.any(
      (ClinicalLabRequestCatalogSelection selection) => selection.key == key,
    );
  }

  List<AppListTableColumn<ClinicalActionCatalogOption>> _catalogColumns(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return <AppListTableColumn<ClinicalActionCatalogOption>>[
      _selectionColumn(context),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _nameColumnKey,
        label: _showingTests ? l10n.labTestNameLabel : l10n.labPanelNameLabel,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) => appListTableCompareText(left.name, right.name),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(item.name ?? item.displayTitle);
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _codeColumnKey,
        label: _showingTests ? l10n.labTestCodeLabel : l10n.labPanelCodeLabel,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) => appListTableCompareText(left.code, right.code),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(item.code ?? l10n.profileUnknownValue);
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _categoryColumnKey,
        label: l10n.labCategoryLabel,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) => appListTableCompareText(left.category, right.category),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(item.category ?? l10n.profileUnknownValue);
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _priceColumnKey,
        label: l10n.clinicalRequestUnitPriceLabel,
        numeric: true,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) {
              return (left.unitPrice ?? 0).compareTo(right.unitPrice ?? 0);
            },
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Padding(
            padding: EdgeInsetsDirectional.only(end: theme.spacing.md),
            child: Text(
              clinicalRequestPriceLabel(
                context,
                item.unitPrice,
                clinicalCatalogOptionCurrency(item),
              ),
              textAlign: TextAlign.end,
            ),
          );
        },
      ),
    ];
  }

  AppListTableColumn<ClinicalActionCatalogOption> _selectionColumn(
    BuildContext context,
  ) {
    return AppListTableColumn<ClinicalActionCatalogOption>(
      id: _selectColumnKey,
      label: '',
      alwaysVisible: true,
      fixedWidth: 40,
      headerBuilder: (BuildContext context) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (BuildContext context, TextEditingValue value, Widget? _) {
            final List<ClinicalActionCatalogOption> visibleItems =
                _sortedCatalogItems(_catalogForSelection())
                    .where((ClinicalActionCatalogOption item) {
                      return _matchesCatalogSearch(item, value.text) &&
                          _matchesCategoryFilter(item);
                    })
                    .toList(growable: false);
            final bool allSelected =
                visibleItems.isNotEmpty &&
                visibleItems.every(
                  (ClinicalActionCatalogOption item) =>
                      _isStagedSelected(item, _selectionKind),
                );
            final bool someSelected = visibleItems.any(
              (ClinicalActionCatalogOption item) =>
                  _isStagedSelected(item, _selectionKind),
            );
            return Center(
              child: Checkbox(
                tristate: true,
                value: allSelected
                    ? true
                    : someSelected
                    ? null
                    : false,
                onChanged: visibleItems.isEmpty
                    ? null
                    : (bool? checked) {
                        _toggleFilteredItems(
                          visibleItems,
                          selected: checked ?? false,
                        );
                      },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          },
        );
      },
      cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
        return Center(
          child: IgnorePointer(
            child: Checkbox(
              value: _isStagedSelected(item, _selectionKind),
              onChanged: (_) {},
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      },
    );
  }

  List<AppSearchBarFilterGroup> _categoryFilterGroups(AppLocalizations l10n) {
    return <AppSearchBarFilterGroup>[
      AppSearchBarFilterGroup(
        key: _categoryFilterKey,
        label: l10n.labCategoryLabel,
        allLabel: l10n.labScopeAll,
        choices: _categoryFilterChoices(),
      ),
    ];
  }

  List<AppSearchBarFilterChoice> _categoryFilterChoices() {
    final Set<String> categories = <String>{};
    for (final ClinicalActionCatalogOption item in _catalogForSelection()) {
      final String? category = item.category?.trim();
      if (category != null && category.isNotEmpty) {
        categories.add(category);
      }
    }
    final List<String> sorted = categories.toList(growable: false)..sort();
    return <AppSearchBarFilterChoice>[
      for (final String category in sorted)
        AppSearchBarFilterChoice(
          value: category,
          label: category,
          icon: labCatalogCategoryIcon(category),
        ),
    ];
  }

  bool _matchesCategoryFilter(ClinicalActionCatalogOption item) {
    final String? category = _filterValue.option(_categoryFilterKey);
    if (category == null) {
      return true;
    }
    return item.category == category;
  }

  bool _matchesCatalogSearch(ClinicalActionCatalogOption item, String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    final String haystack = <String?>[
      item.name,
      item.code,
      item.category,
      item.secondaryText,
      item.status,
      item.searchText,
      item.displayTitle,
      item.displaySubtitle,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(normalized);
  }

  List<ClinicalActionCatalogOption> _sortedCatalogItems(
    List<ClinicalActionCatalogOption> catalog,
  ) {
    return orderClinicalLabRequestCatalogItems(
      catalog,
      includeOption: _matchesCategoryFilter,
      isSelected: (ClinicalActionCatalogOption option) =>
          _isStagedSelected(option, _selectionKind),
    );
  }

  void _toggleSelection(
    ClinicalActionCatalogOption option, {
    required bool selected,
  }) {
    final bool currentlySelected = _isStagedSelected(option, _selectionKind);
    if (currentlySelected == selected) {
      return;
    }
    setState(() {
      if (selected) {
        if (_isStagedSelected(option, _selectionKind)) {
          return;
        }
        _stagedSelections.add(
          ClinicalLabRequestCatalogSelection(
            option: option,
            kind: _selectionKind,
          ),
        );
        return;
      }
      _stagedSelections.removeWhere(
        (ClinicalLabRequestCatalogSelection selection) =>
            selection.option.apiId == option.apiId &&
            selection.kind == _selectionKind,
      );
    });
  }

  void _toggleFilteredItems(
    List<ClinicalActionCatalogOption> items, {
    required bool selected,
  }) {
    setState(() {
      for (final ClinicalActionCatalogOption item in items) {
        final bool currentlySelected = _isStagedSelected(item, _selectionKind);
        if (currentlySelected == selected) {
          continue;
        }
        if (selected) {
          _stagedSelections.add(
            ClinicalLabRequestCatalogSelection(
              option: item,
              kind: _selectionKind,
            ),
          );
          continue;
        }
        _stagedSelections.removeWhere(
          (ClinicalLabRequestCatalogSelection selection) =>
              selection.option.apiId == item.apiId &&
              selection.kind == _selectionKind,
        );
      }
    });
  }

  List<ClinicalActionCatalogOption> _catalogForSelection() {
    return switch (_selectionKind) {
      ClinicalLabRequestCatalogKind.tests => _testCatalogOptions,
      ClinicalLabRequestCatalogKind.panels => _panelCatalogOptions,
    };
  }

  Future<void> _loadPanelCatalog(String query, int requestId) async {
    setState(() => _isSearching = true);
    final Result<List<ClinicalActionCatalogOption>> result = await widget
        .onSearchLabTests(
          termType: ClinicalCatalogTermType.labPanel.apiValue,
          query: query.trim().isEmpty ? null : query.trim(),
          limit: _maxVisibleCatalogOptions,
          source: ClinicalCatalogSource.facility.apiValue,
        );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    setState(() {
      _isSearching = false;
      result.when(
        success: (List<ClinicalActionCatalogOption> value) {
          _catalogFailure = null;
          _panelCatalogOptions = value;
        },
        failure: (AppFailure failure) {
          _catalogFailure = failure;
          _panelCatalogOptions = const <ClinicalActionCatalogOption>[];
        },
      );
    });
  }

  Future<void> _loadTestCatalog(String query, int requestId) async {
    setState(() => _isSearching = true);
    final Result<List<ClinicalActionCatalogOption>> result = await widget
        .onSearchLabTests(
          termType: ClinicalCatalogTermType.labTest.apiValue,
          query: query.trim().isEmpty ? null : query.trim(),
          limit: _maxVisibleCatalogOptions,
          source: widget.facilityOfferingsOnly
              ? ClinicalCatalogSource.facility.apiValue
              : _catalogSource.apiValue,
        );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    setState(() {
      _isSearching = false;
      result.when(
        success: (List<ClinicalActionCatalogOption> value) {
          _catalogFailure = null;
          _testCatalogOptions = value;
        },
        failure: (AppFailure failure) {
          _catalogFailure = failure;
          _testCatalogOptions = const <ClinicalActionCatalogOption>[];
        },
      );
    });
  }

  Future<void> _loadFavoriteTests() async {
    final Result<List<ClinicalActionCatalogOption>> result = await widget
        .onSearchLabTests(
          termType: ClinicalCatalogTermType.labTest.apiValue,
          limit: 12,
          source: ClinicalCatalogSource.favorites.apiValue,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      result.when(
        success: (List<ClinicalActionCatalogOption> value) {
          _favoriteTestOptions = value;
        },
        failure: (_) {
          _favoriteTestOptions = const <ClinicalActionCatalogOption>[];
        },
      );
    });
  }

  void _scheduleSearch(String value) {
    setState(() => _searchQuery = value.trim());
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      _searchRequest += 1;
      if (_selectionKind == ClinicalLabRequestCatalogKind.tests) {
        unawaited(_loadTestCatalog(_searchQuery, _searchRequest));
        return;
      }
      unawaited(_loadPanelCatalog(_searchQuery, _searchRequest));
    });
  }
}

class _CatalogKindRadioGroup extends StatelessWidget {
  const _CatalogKindRadioGroup({
    required this.value,
    required this.testsLabel,
    required this.panelsLabel,
    required this.onChanged,
  });

  final ClinicalLabRequestCatalogKind value;
  final String testsLabel;
  final String panelsLabel;
  final ValueChanged<ClinicalLabRequestCatalogKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return RadioGroup<ClinicalLabRequestCatalogKind>(
      groupValue: value,
      onChanged: (ClinicalLabRequestCatalogKind? next) {
        if (next != null && next != value) {
          onChanged(next);
        }
      },
      child: Row(
        children: <Widget>[
          Expanded(
            child: RadioListTile<ClinicalLabRequestCatalogKind>(
              value: ClinicalLabRequestCatalogKind.tests,
              title: Text(testsLabel),
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: RadioListTile<ClinicalLabRequestCatalogKind>(
              value: ClinicalLabRequestCatalogKind.panels,
              title: Text(panelsLabel),
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ],
      ),
    );
  }
}
