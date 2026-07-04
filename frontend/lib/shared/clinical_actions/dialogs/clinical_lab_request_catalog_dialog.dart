import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_layer_selector.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum ClinicalLabRequestCatalogKind { tests, panels }

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

Future<void> showClinicalLabRequestCatalogDialog({
  required BuildContext context,
  required ClinicalActionReferenceData referenceData,
  required Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })
  onSearchLabTests,
  required bool Function(
    ClinicalActionCatalogOption option,
    ClinicalLabRequestCatalogKind kind,
  )
  isSelected,
  required void Function(
    ClinicalActionCatalogOption option,
    ClinicalLabRequestCatalogKind kind,
    bool selected,
  )
  onSelectionChanged,
  required int selectedCount,
  ClinicalLabRequestCatalogKind initialKind =
      ClinicalLabRequestCatalogKind.tests,
  bool facilityOfferingsOnly = false,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext context) => ClinicalLabRequestCatalogDialog(
      referenceData: referenceData,
      onSearchLabTests: onSearchLabTests,
      isSelected: isSelected,
      onSelectionChanged: onSelectionChanged,
      selectedCount: selectedCount,
      initialKind: initialKind,
      facilityOfferingsOnly: facilityOfferingsOnly,
    ),
  );
}

class ClinicalLabRequestCatalogDialog extends StatefulWidget {
  const ClinicalLabRequestCatalogDialog({
    required this.referenceData,
    required this.onSearchLabTests,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.selectedCount,
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
  final bool Function(
    ClinicalActionCatalogOption option,
    ClinicalLabRequestCatalogKind kind,
  )
  isSelected;
  final void Function(
    ClinicalActionCatalogOption option,
    ClinicalLabRequestCatalogKind kind,
    bool selected,
  )
  onSelectionChanged;
  final int selectedCount;
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
  late final AppListTableColumnVisibilityController<
      ClinicalActionCatalogOption
  >
  _columnVisibilityController;
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
  late int _displaySelectedCount;

  bool get _showingTests =>
      _selectionKind == ClinicalLabRequestCatalogKind.tests;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<ClinicalActionCatalogOption>();
    _selectionKind = widget.initialKind;
    _displaySelectedCount = widget.selectedCount;
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
      initialMaximized: true,
      maxWidth: 980,
      pinActionsToBottom: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SegmentedButton<ClinicalLabRequestCatalogKind>(
            segments: <ButtonSegment<ClinicalLabRequestCatalogKind>>[
              ButtonSegment<ClinicalLabRequestCatalogKind>(
                value: ClinicalLabRequestCatalogKind.tests,
                icon: const Icon(Icons.science_outlined),
                label: Text(l10n.clinicalLabRequestTestsModeLabel),
              ),
              ButtonSegment<ClinicalLabRequestCatalogKind>(
                value: ClinicalLabRequestCatalogKind.panels,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(l10n.clinicalLabRequestPanelsModeLabel),
              ),
            ],
            selected: <ClinicalLabRequestCatalogKind>{_selectionKind},
            showSelectedIcon: false,
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll<Size>(
                Size(theme.spacing.none, 44),
              ),
              shape: const WidgetStatePropertyAll<OutlinedBorder>(
                RoundedRectangleBorder(),
              ),
            ),
            onSelectionChanged: (Set<ClinicalLabRequestCatalogKind> values) {
              setState(() {
                _selectionKind = values.first;
              });
              _searchRequest += 1;
              if (values.first == ClinicalLabRequestCatalogKind.tests) {
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
                    fontWeight: FontWeight.w800,
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
              l10n.clinicalLabRequestSelectedCount(_displaySelectedCount),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
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
              isLoading: _isSearching,
              rowColorBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
                if (!widget.isSelected(item, _selectionKind)) {
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
              emptyBuilder: (_) => AppMutedText(
                l10n.clinicalLabRequestNoCatalogOptions,
              ),
              mobileItemBuilder:
                  (BuildContext context, ClinicalActionCatalogOption item) {
                    return AppListItemRow(
                      title: item.name ?? item.displayTitle,
                      subtitle: clinicalActionJoinDisplay(<String?>[
                        item.code,
                        item.category,
                      ]),
                      trailing: Checkbox(
                        value: widget.isSelected(item, _selectionKind),
                        onChanged: (bool? value) {
                          _toggleSelection(item, selected: value ?? false);
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.clinicalRequestCatalogPickerDoneAction,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  List<AppListTableColumn<ClinicalActionCatalogOption>> _catalogColumns(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    return <AppListTableColumn<ClinicalActionCatalogOption>>[
      _selectionColumn(context),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _nameColumnKey,
        label: _showingTests
            ? l10n.labTestNameLabel
            : l10n.labPanelNameLabel,
        sortComparator: (ClinicalActionCatalogOption left, ClinicalActionCatalogOption right) =>
            appListTableCompareText(left.name, right.name),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(item.name ?? item.displayTitle);
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _codeColumnKey,
        label: _showingTests
            ? l10n.labTestCodeLabel
            : l10n.labPanelCodeLabel,
        sortComparator: (ClinicalActionCatalogOption left, ClinicalActionCatalogOption right) =>
            appListTableCompareText(left.code, right.code),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(item.code ?? l10n.profileUnknownValue);
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _categoryColumnKey,
        label: l10n.labCategoryLabel,
        sortComparator: (ClinicalActionCatalogOption left, ClinicalActionCatalogOption right) =>
            appListTableCompareText(left.category, right.category),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(item.category ?? l10n.profileUnknownValue);
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _priceColumnKey,
        label: l10n.clinicalRequestUnitPriceLabel,
        numeric: true,
        sortComparator: (ClinicalActionCatalogOption left, ClinicalActionCatalogOption right) {
          return (left.unitPrice ?? 0).compareTo(right.unitPrice ?? 0);
        },
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(
            clinicalRequestPriceLabel(
              context,
              item.unitPrice,
              clinicalCatalogOptionCurrency(item),
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
      headerBuilder: (BuildContext context) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (BuildContext context, TextEditingValue value, Widget? _) {
            final List<ClinicalActionCatalogOption> visibleItems =
                _sortedCatalogItems(_catalogForSelection()).where(
              (ClinicalActionCatalogOption item) {
                return _matchesCatalogSearch(item, value.text) &&
                    _matchesCategoryFilter(item);
              },
            ).toList(growable: false);
            final bool allSelected = visibleItems.isNotEmpty &&
                visibleItems.every(
                  (ClinicalActionCatalogOption item) =>
                      widget.isSelected(item, _selectionKind),
                );
            final bool someSelected = visibleItems.any(
              (ClinicalActionCatalogOption item) =>
                  widget.isSelected(item, _selectionKind),
            );
            return Checkbox(
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
            );
          },
        );
      },
      cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
        return Checkbox(
          value: widget.isSelected(item, _selectionKind),
          onChanged: (bool? value) {
            _toggleSelection(item, selected: value ?? false);
          },
          visualDensity: VisualDensity.compact,
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
        AppSearchBarFilterChoice(value: category, label: category),
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
          widget.isSelected(option, _selectionKind),
    );
  }

  void _toggleSelection(
    ClinicalActionCatalogOption option, {
    required bool selected,
  }) {
    final bool currentlySelected = widget.isSelected(option, _selectionKind);
    if (currentlySelected == selected) {
      return;
    }
    widget.onSelectionChanged(option, _selectionKind, selected);
    setState(() {
      _displaySelectedCount += selected ? 1 : -1;
    });
  }

  void _toggleFilteredItems(
    List<ClinicalActionCatalogOption> items, {
    required bool selected,
  }) {
    var delta = 0;
    for (final ClinicalActionCatalogOption item in items) {
      final bool currentlySelected = widget.isSelected(item, _selectionKind);
      if (currentlySelected == selected) {
        continue;
      }
      widget.onSelectionChanged(item, _selectionKind, selected);
      delta += selected ? 1 : -1;
    }
    if (delta == 0) {
      return;
    }
    setState(() {
      _displaySelectedCount += delta;
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
      _panelCatalogOptions = result.when(
        success: (List<ClinicalActionCatalogOption> value) => value,
        failure: (_) => const <ClinicalActionCatalogOption>[],
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
      _testCatalogOptions = result.when(
        success: (List<ClinicalActionCatalogOption> value) => value,
        failure: (_) => const <ClinicalActionCatalogOption>[],
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
      _favoriteTestOptions = result.when(
        success: (List<ClinicalActionCatalogOption> value) => value,
        failure: (_) => const <ClinicalActionCatalogOption>[],
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
