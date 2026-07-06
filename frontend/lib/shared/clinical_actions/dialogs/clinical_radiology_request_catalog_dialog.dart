import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_radiology_catalog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';

@immutable
final class ClinicalRadiologyCatalogSelection {
  const ClinicalRadiologyCatalogSelection({
    required this.option,
    this.clinicalNote,
    this.bodyRegion,
    this.laterality,
    this.priority,
    this.modality,
  });

  final ClinicalActionCatalogOption option;
  final String? clinicalNote;
  final String? bodyRegion;
  final String? laterality;
  final String? priority;
  final String? modality;

  String get key => option.apiId;
}

Future<List<ClinicalRadiologyCatalogSelection>?>
showClinicalRadiologyRequestCatalogDialog({
  required BuildContext context,
  required Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })
  onSearchRadiologyTests,
  required List<ClinicalRadiologyCatalogSelection> initialSelections,
  ClinicalRadiologyCatalogSelection? editingSelection,
}) {
  return showAppDialog<List<ClinicalRadiologyCatalogSelection>>(
    context: context,
    builder: (BuildContext context) => ClinicalRadiologyRequestCatalogDialog(
      onSearchRadiologyTests: onSearchRadiologyTests,
      initialSelections: initialSelections,
      editingSelection: editingSelection,
    ),
  );
}

class ClinicalRadiologyRequestCatalogDialog extends StatefulWidget {
  const ClinicalRadiologyRequestCatalogDialog({
    required this.onSearchRadiologyTests,
    required this.initialSelections,
    this.editingSelection,
    super.key,
  });

  final Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })
  onSearchRadiologyTests;
  final List<ClinicalRadiologyCatalogSelection> initialSelections;
  final ClinicalRadiologyCatalogSelection? editingSelection;

  @override
  State<ClinicalRadiologyRequestCatalogDialog> createState() =>
      _ClinicalRadiologyRequestCatalogDialogState();
}

class _ClinicalRadiologyRequestCatalogDialogState
    extends State<ClinicalRadiologyRequestCatalogDialog> {
  static const int _maxVisibleCatalogOptions = 100;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 160);
  static const String _modalityFilterKey = 'modality';
  static const String _selectColumnKey = 'select';
  static const String _nameColumnKey = 'name';
  static const String _modalityColumnKey = 'modality';
  static const String _bodyRegionColumnKey = 'body_region';
  static const String _priceColumnKey = 'price';
  static const String _columnVisibilityStorageKey =
      'clinical-radiology-request-catalog';

  late final TextEditingController _noteController;
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<ClinicalActionCatalogOption>
  _columnVisibilityController;
  late final List<ClinicalRadiologyCatalogSelection> _stagedSelections;
  Timer? _searchDebounce;
  String? _modality;
  String? _bodyRegion;
  String? _laterality;
  String? _priority;
  String _searchQuery = '';
  int _searchRequest = 0;
  List<ClinicalActionCatalogOption> _catalogOptions =
      const <ClinicalActionCatalogOption>[];
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  bool _isSearching = false;
  AppFailure? _catalogFailure;

  @override
  void initState() {
    super.initState();
    final ClinicalRadiologyCatalogSelection? editing = widget.editingSelection;
    _noteController = TextEditingController(text: editing?.clinicalNote ?? '');
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<ClinicalActionCatalogOption>();
    _stagedSelections = List<ClinicalRadiologyCatalogSelection>.from(
      widget.initialSelections,
    );
    _modality = editing?.modality;
    _bodyRegion = editing?.bodyRegion;
    _laterality = editing?.laterality;
    _priority = editing?.priority;
    if (editing != null && !_isStagedSelected(editing.option)) {
      _stagedSelections.add(editing);
    }
    _searchRequest += 1;
    unawaited(_loadCatalog(_searchQuery, _searchRequest));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double bodyHeight = (MediaQuery.sizeOf(context).height * 0.72)
        .clamp(480.0, 720.0)
        .toDouble();
    final List<ClinicalActionCatalogOption> catalog = _sortedCatalogItems(
      _filteredCatalog(_catalogOptions),
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
    final List<AppSelectOption<String>> modalityOptions =
        clinicalRadiologyModalityOptions(
          l10n,
          _catalogOptions,
        );
    final List<AppSelectOption<String>> bodyRegionOptions =
        clinicalRadiologyBodyRegionOptions(
          _catalogOptions,
          modality: _modality,
          laterality: _laterality,
          priority: _priority,
        );

    return AppDialog(
      title: Text(l10n.clinicalRadiologyCatalogPickerTitle),
      icon: const Icon(Icons.manage_search_outlined),
      maxWidth: 980,
      pinActionsToBottom: true,
      content: SizedBox(
        height: bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_catalogFailure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _catalogFailure!,
              ),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 640;
                if (compact) {
                  return Column(
                    children: <Widget>[
                      _modalityField(l10n, modalityOptions),
                      SizedBox(height: theme.spacing.sm),
                      _lateralityField(l10n),
                      SizedBox(height: theme.spacing.sm),
                      _priorityField(l10n),
                      SizedBox(height: theme.spacing.sm),
                      _bodyRegionField(l10n, bodyRegionOptions),
                      SizedBox(height: theme.spacing.sm),
                      _clinicalNoteField(l10n),
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: _modalityField(l10n, modalityOptions)),
                        SizedBox(width: theme.spacing.sm),
                        Expanded(child: _lateralityField(l10n)),
                      ],
                    ),
                    SizedBox(height: theme.spacing.sm),
                    Row(
                      children: <Widget>[
                        SizedBox(width: 220, child: _priorityField(l10n)),
                        SizedBox(width: theme.spacing.sm),
                        Expanded(
                          child: _bodyRegionField(l10n, bodyRegionOptions),
                        ),
                      ],
                    ),
                    SizedBox(height: theme.spacing.sm),
                    _clinicalNoteField(l10n),
                  ],
                );
              },
            ),
            if (bodyRegionOptions.isNotEmpty &&
                bodyRegionOptions.length <= 16) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              _RadiologyBodyRegionChipPicker(
                regions: bodyRegionOptions,
                value: _bodyRegion,
                onChanged: (String? value) {
                  setState(() => _bodyRegion = value);
                },
              ),
            ],
            SizedBox(height: theme.spacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.clinicalRadiologyRequestSelectedCount(
                  _stagedSelections.length,
                ),
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
                columnVisibilityTitle:
                    l10n.clinicalRadiologyRequestCatalogColumnsTitle,
                columnVisibilityApplyLabel: l10n.labApplyColumnsAction,
                columnVisibilityResetLabel: l10n.labResetColumnsAction,
                displayMode: AppListTableDisplayMode.table,
                tableHorizontalMargin: 0,
                isLoading: _isSearching,
                rowColorBuilder:
                    (BuildContext context, ClinicalActionCatalogOption item) {
                      if (!_isStagedSelected(item)) {
                        return null;
                      }
                      return colorScheme.primaryContainer.withValues(
                        alpha: 0.35,
                      );
                    },
                search: AppListTableSearch<ClinicalActionCatalogOption>(
                  controller: _searchController,
                  semanticLabel: l10n.clinicalRadiologyRequestSearchLabel,
                  hintText: l10n.clinicalRadiologyRequestSearchHint,
                  isLoading: _isSearching,
                  matcher: _matchesCatalogSearch,
                  onChanged: _scheduleSearch,
                  showAdvancedFilterButton: true,
                  advancedFilterButtonLabel: l10n.radiologyFiltersLabel,
                  advancedFilterTitle: l10n.radiologyFiltersLabel,
                  advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                  advancedFilterResetLabel: l10n.opdClearFiltersAction,
                  enableDateFilter: false,
                  allFieldsLabel: l10n.labScopeAll,
                  filterGroups: _modalityFilterGroups(l10n, modalityOptions),
                  filterValue: _filterValue,
                  hasActiveFilters: _filterValue.isActive,
                  onFilterChanged: (AppSearchBarFilterValue value) {
                    setState(() => _filterValue = value);
                  },
                ),
                emptyBuilder: (_) =>
                    AppMutedText(l10n.clinicalRadiologyRequestNoCatalogOptions),
                mobileItemBuilder:
                    (BuildContext context, ClinicalActionCatalogOption item) {
                      return AppListItemRow(
                        title: item.name ?? item.displayTitle,
                        subtitle: clinicalActionJoinDisplay(<String?>[
                          clinicalRadiologyOptionModality(item),
                          clinicalRadiologyOptionBodyRegion(item),
                        ]),
                        trailing: Checkbox(
                          value: _isStagedSelected(item),
                          onChanged: (bool? value) {
                            _toggleSelection(
                              item,
                              selected: value ?? false,
                            );
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    },
              ),
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
          label: l10n.clinicalRadiologyRequestCatalogPickerConfirmAction,
          leadingIcon: Icons.playlist_add_check,
          onPressed: () => Navigator.of(context).pop(_confirmedSelections()),
        ),
      ],
    );
  }

  Widget _modalityField(
    AppLocalizations l10n,
    List<AppSelectOption<String>> modalityOptions,
  ) {
    return AppSelectField<String>.searchable(
      value: _modality,
      labelText: l10n.radiologyModalityLabel,
      hintText: l10n.radiologyModalityLabel,
      options: modalityOptions,
      onChanged: (String? value) {
        setState(() {
          _modality = value;
          if (!_bodyRegionAvailable(value, _bodyRegion)) {
            _bodyRegion = null;
          }
        });
      },
    );
  }

  Widget _lateralityField(AppLocalizations l10n) {
    return AppSelectField<String>(
      value: _laterality,
      labelText: l10n.clinicalRadiologyLateralityLabel,
      options: clinicalRadiologyLateralityOptions(l10n),
      onChanged: (String? value) {
        setState(() {
          _laterality = value;
          if (!_bodyRegionAvailable(_modality, _bodyRegion)) {
            _bodyRegion = null;
          }
        });
      },
    );
  }

  Widget _priorityField(AppLocalizations l10n) {
    return AppSelectField<String>(
      value: _priority,
      labelText: l10n.clinicalRadiologyPriorityLabel,
      options: clinicalActionStatusOptions(const <String>[
        'ROUTINE',
        'URGENT',
        'STAT',
      ]),
      onChanged: (String? value) {
        setState(() => _priority = value);
      },
    );
  }

  Widget _bodyRegionField(
    AppLocalizations l10n,
    List<AppSelectOption<String>> bodyRegionOptions,
  ) {
    if (bodyRegionOptions.isEmpty) {
      return const SizedBox.shrink();
    }
    if (bodyRegionOptions.length <= 16) {
      return AppSelectField<String>(
        value: _bodyRegion,
        labelText: l10n.clinicalRadiologyBodyRegionLabel,
        options: bodyRegionOptions,
        onChanged: (String? value) {
          setState(() => _bodyRegion = value);
        },
      );
    }
    return AppSelectField<String>.searchable(
      value: _bodyRegion,
      labelText: l10n.clinicalRadiologyBodyRegionLabel,
      hintText: l10n.clinicalRadiologyBodyRegionLabel,
      options: bodyRegionOptions,
      onChanged: (String? value) {
        setState(() => _bodyRegion = value);
      },
    );
  }

  Widget _clinicalNoteField(AppLocalizations l10n) {
    return AppTextField(
      controller: _noteController,
      labelText: l10n.opdClinicalNoteLabel,
      maxLines: 2,
    );
  }

  List<ClinicalRadiologyCatalogSelection> _confirmedSelections() {
    final String? clinicalNote = clinicalActionTrimmedOrNull(
      _noteController.text,
    );
    return <ClinicalRadiologyCatalogSelection>[
      for (final ClinicalRadiologyCatalogSelection selection in _stagedSelections)
        ClinicalRadiologyCatalogSelection(
          option: selection.option,
          clinicalNote: clinicalNote ?? selection.clinicalNote,
          bodyRegion:
              clinicalActionTrimmedOrNull(_bodyRegion) ??
              selection.bodyRegion ??
              clinicalRadiologyOptionBodyRegion(selection.option),
          laterality:
              _laterality ??
              selection.laterality ??
              clinicalRadiologyOptionLaterality(selection.option),
          priority: _priority ?? selection.priority,
          modality:
              clinicalActionTrimmedOrNull(_modality) ??
              selection.modality ??
              clinicalRadiologyOptionModality(selection.option),
        ),
    ];
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
        label: l10n.radiologyStudyColumnLabel,
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
        id: _modalityColumnKey,
        label: l10n.radiologyModalityLabel,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) => appListTableCompareText(
              clinicalRadiologyOptionModality(left),
              clinicalRadiologyOptionModality(right),
            ),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(
            clinicalRadiologyModalityDisplayLabel(
              l10n,
              clinicalRadiologyOptionModality(item),
            ),
          );
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _bodyRegionColumnKey,
        label: l10n.clinicalRadiologyBodyRegionLabel,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) => appListTableCompareText(
              clinicalRadiologyOptionBodyRegion(left),
              clinicalRadiologyOptionBodyRegion(right),
            ),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(
            clinicalRadiologyOptionBodyRegion(item) ??
                l10n.profileUnknownValue,
          );
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
      headerBuilder: (BuildContext context) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (BuildContext context, TextEditingValue value, Widget? _) {
            final List<ClinicalActionCatalogOption> visibleItems = _sortedCatalogItems(
              _filteredCatalog(_catalogOptions),
            ).where((ClinicalActionCatalogOption item) {
              return _matchesCatalogSearch(item, value.text) &&
                  _matchesModalityFilter(item);
            }).toList(growable: false);
            final bool allSelected =
                visibleItems.isNotEmpty &&
                visibleItems.every(_isStagedSelected);
            final bool someSelected = visibleItems.any(_isStagedSelected);
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
          value: _isStagedSelected(item),
          onChanged: (bool? value) {
            _toggleSelection(item, selected: value ?? false);
          },
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }

  List<AppSearchBarFilterGroup> _modalityFilterGroups(
    AppLocalizations l10n,
    List<AppSelectOption<String>> modalityOptions,
  ) {
    return <AppSearchBarFilterGroup>[
      AppSearchBarFilterGroup(
        key: _modalityFilterKey,
        label: l10n.radiologyModalityLabel,
        allLabel: l10n.labScopeAll,
        choices: <AppSearchBarFilterChoice>[
          for (final AppSelectOption<String> option in modalityOptions)
            AppSearchBarFilterChoice(
              value: option.value,
              label: option.label,
            ),
        ],
      ),
    ];
  }

  bool _isStagedSelected(ClinicalActionCatalogOption option) {
    return _stagedSelections.any(
      (ClinicalRadiologyCatalogSelection selection) =>
          selection.option.apiId == option.apiId,
    );
  }

  List<ClinicalActionCatalogOption> _filteredCatalog(
    List<ClinicalActionCatalogOption> catalog,
  ) {
    return <ClinicalActionCatalogOption>[
      for (final ClinicalActionCatalogOption option in catalog)
        if (_matchesRadiologyFilters(option)) option,
    ];
  }

  List<ClinicalActionCatalogOption> _sortedCatalogItems(
    List<ClinicalActionCatalogOption> catalog,
  ) {
    return orderClinicalRadiologyRequestCatalogItems(
      catalog,
      includeOption: (ClinicalActionCatalogOption option) =>
          _matchesModalityFilter(option),
      isSelected: _isStagedSelected,
    );
  }

  bool _matchesRadiologyFilters(ClinicalActionCatalogOption option) {
    final String? selectedModality = clinicalActionTrimmedOrNull(_modality);
    final String? selectedBodyRegion = clinicalActionTrimmedOrNull(_bodyRegion);
    final String? selectedLaterality = clinicalActionTrimmedOrNull(_laterality);
    final String? selectedPriority = clinicalActionTrimmedOrNull(_priority);
    if (selectedModality != null &&
        clinicalActionNormalizedCatalogToken(
              clinicalRadiologyOptionModality(option) ?? '',
            ) !=
            clinicalActionNormalizedCatalogToken(selectedModality)) {
      return false;
    }
    if (selectedBodyRegion != null &&
        clinicalActionNormalizedCatalogToken(
              clinicalRadiologyOptionBodyRegion(option) ?? '',
            ) !=
            clinicalActionNormalizedCatalogToken(selectedBodyRegion)) {
      return false;
    }
    if (selectedLaterality != null &&
        clinicalActionNormalizedCatalogToken(
              clinicalRadiologyOptionLaterality(option) ?? '',
            ) !=
            clinicalActionNormalizedCatalogToken(selectedLaterality)) {
      return false;
    }
    final String? optionPriority = clinicalRadiologyOptionPriority(option);
    if (selectedPriority != null &&
        optionPriority != null &&
        clinicalActionNormalizedCatalogToken(optionPriority) !=
            clinicalActionNormalizedCatalogToken(selectedPriority)) {
      return false;
    }
    return true;
  }

  bool _matchesModalityFilter(ClinicalActionCatalogOption option) {
    final String? modality = _filterValue.option(_modalityFilterKey);
    if (modality == null) {
      return true;
    }
    return clinicalActionNormalizedCatalogToken(
          clinicalRadiologyOptionModality(option) ?? '',
        ) ==
        clinicalActionNormalizedCatalogToken(modality);
  }

  bool _matchesCatalogSearch(
    ClinicalActionCatalogOption item,
    String query,
  ) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    final String haystack = clinicalActionJoinDisplay(<String?>[
      item.apiId,
      item.displayTitle,
      item.displaySubtitle,
      item.name,
      item.code,
      clinicalRadiologyOptionModality(item),
      clinicalRadiologyOptionBodyRegion(item),
      clinicalRadiologyOptionLaterality(item),
      clinicalRadiologyOptionPriority(item),
      item.category,
      item.secondaryText,
      item.status,
      item.searchText,
    ]).toLowerCase();
    return haystack.contains(normalized);
  }

  bool _bodyRegionAvailable(String? modality, String? bodyRegion) {
    final String? normalizedBodyRegion = clinicalActionTrimmedOrNull(
      bodyRegion,
    );
    if (normalizedBodyRegion == null) {
      return true;
    }
    return clinicalRadiologyBodyRegionOptions(
      _catalogOptions,
      modality: modality,
      laterality: _laterality,
      priority: _priority,
    ).any(
      (AppSelectOption<String> option) =>
          clinicalActionNormalizedCatalogToken(option.value) ==
          clinicalActionNormalizedCatalogToken(normalizedBodyRegion),
    );
  }

  void _toggleSelection(
    ClinicalActionCatalogOption option, {
    required bool selected,
  }) {
    final bool currentlySelected = _isStagedSelected(option);
    if (currentlySelected == selected) {
      return;
    }
    setState(() {
      if (selected) {
        _stagedSelections.add(
          ClinicalRadiologyCatalogSelection(
            option: option,
            bodyRegion: clinicalRadiologyOptionBodyRegion(option),
            laterality: clinicalRadiologyOptionLaterality(option),
            modality: clinicalRadiologyOptionModality(option),
            priority: clinicalRadiologyOptionPriority(option),
          ),
        );
        return;
      }
      _stagedSelections.removeWhere(
        (ClinicalRadiologyCatalogSelection selection) =>
            selection.option.apiId == option.apiId,
      );
    });
  }

  void _toggleFilteredItems(
    List<ClinicalActionCatalogOption> items, {
    required bool selected,
  }) {
    setState(() {
      for (final ClinicalActionCatalogOption item in items) {
        final bool currentlySelected = _isStagedSelected(item);
        if (currentlySelected == selected) {
          continue;
        }
        if (selected) {
          _stagedSelections.add(
            ClinicalRadiologyCatalogSelection(
              option: item,
              bodyRegion: clinicalRadiologyOptionBodyRegion(item),
              laterality: clinicalRadiologyOptionLaterality(item),
              modality: clinicalRadiologyOptionModality(item),
              priority: clinicalRadiologyOptionPriority(item),
            ),
          );
          continue;
        }
        _stagedSelections.removeWhere(
          (ClinicalRadiologyCatalogSelection selection) =>
              selection.option.apiId == item.apiId,
        );
      }
    });
  }

  Future<void> _loadCatalog(String query, int requestId) async {
    setState(() => _isSearching = true);
    final Result<List<ClinicalActionCatalogOption>> result = await widget
        .onSearchRadiologyTests(
          termType: ClinicalCatalogTermType.radiologyTest.apiValue,
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
          _catalogOptions = value;
        },
        failure: (AppFailure failure) {
          _catalogFailure = failure;
          _catalogOptions = const <ClinicalActionCatalogOption>[];
        },
      );
    });
  }

  void _scheduleSearch(String value) {
    setState(() => _searchQuery = value.trim());
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      _searchRequest += 1;
      unawaited(_loadCatalog(_searchQuery, _searchRequest));
    });
  }
}

class _RadiologyBodyRegionChipPicker extends StatelessWidget {
  const _RadiologyBodyRegionChipPicker({
    required this.regions,
    required this.value,
    required this.onChanged,
  });

  final List<AppSelectOption<String>> regions;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (final AppSelectOption<String> region in regions)
          FilterChip(
            avatar: region.leadingIcon,
            label: Text(region.label),
            selected:
                clinicalActionNormalizedCatalogToken(value ?? '') ==
                clinicalActionNormalizedCatalogToken(region.value),
            onSelected: (bool selected) {
              onChanged(selected ? region.value : null);
            },
          ),
      ],
    );
  }
}
