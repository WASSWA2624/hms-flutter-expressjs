import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class ClinicalDiagnosisActionDialog extends StatefulWidget {
  const ClinicalDiagnosisActionDialog({
    required this.onSearchClinicalTerms,
    required this.onSubmit,
    super.key,
  });

  final Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })
  onSearchClinicalTerms;
  final Future<AppFailure?> Function({
    required String diagnosisType,
    required List<ClinicalActionCatalogOption> diagnoses,
  })
  onSubmit;

  @override
  State<ClinicalDiagnosisActionDialog> createState() => _DiagnosisDialogState();
}

class _DiagnosisDialogState extends State<ClinicalDiagnosisActionDialog> {
  static const int _catalogLimit = 1000;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 160);
  static const String _selectColumnKey = 'select';
  static const String _nameColumnKey = 'name';

  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  String _diagnosisType = 'PRIMARY';
  String _searchQuery = '';
  int _searchRequest = 0;
  List<ClinicalActionCatalogOption> _catalogOptions =
      const <ClinicalActionCatalogOption>[];
  List<ClinicalActionCatalogOption> _selectedDiagnoses =
      <ClinicalActionCatalogOption>[];
  final Set<String> _checkedAvailableIds = <String>{};
  final Set<String> _checkedSelectedIds = <String>{};
  bool _isSearching = false;
  bool _isSaving = false;
  AppFailure? _failure;
  AppFailure? _catalogFailure;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchRequest += 1;
    unawaited(_loadDiagnosisCatalog('', _searchRequest));
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
    final bool wideRadios =
        AppBreakpoints.of(context).index >= AppBreakpoint.md.index;
    final List<ClinicalActionCatalogOption> available = _availableDiagnoses();
    final List<ClinicalActionCatalogOption> visibleAvailable =
        _filterBySearch(available);

    return AppDialog(
      title: Text(l10n.clinicalAddDiagnosisAction),
      icon: const Icon(Icons.rule_outlined),
      maxWidth: 1100,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          if (_catalogFailure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _catalogFailure!,
            ),
          AppRadioGroup<String>(
            value: _diagnosisType,
            labelText: l10n.opdDiagnosisTypeLabel,
            enabled: !_isSaving,
            layout: wideRadios
                ? AppRadioGroupLayout.horizontal
                : AppRadioGroupLayout.wrap,
            options: <AppRadioOption<String>>[
              for (final String type in _diagnosisTypes)
                AppRadioOption<String>(
                  value: type,
                  label: clinicalActionApiLabel(type),
                ),
            ],
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.opdDiagnosisTypeLabel;
              }
              return null;
            },
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _diagnosisType = value);
            },
          ),
          SizedBox(height: theme.spacing.md),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool twoColumns = constraints.maxWidth >= 760;
                final Widget availablePanel = _buildTransferPanel(
                  context: context,
                  title: l10n.clinicalDiagnosisAvailableTitle,
                  countLabel: l10n.clinicalDiagnosisMatchesLabel(
                    visibleAvailable.length,
                    available.length,
                  ),
                  items: visibleAvailable,
                  checkedIds: _checkedAvailableIds,
                  showSearch: true,
                  actionLabel: l10n.clinicalLabRequestAddSelectionAction,
                  actionIcon: Icons.add,
                  onAction: _addCheckedDiagnoses,
                  actionEnabled:
                      !_isSaving &&
                      _checkedAvailableIds.isNotEmpty &&
                      visibleAvailable.any(
                        (ClinicalActionCatalogOption item) =>
                            _checkedAvailableIds.contains(item.apiId),
                      ),
                  emptyLabel: _catalogEmptyLabel(
                    l10n,
                    hasCatalog: _catalogOptions.isNotEmpty,
                    hasVisible: visibleAvailable.isNotEmpty,
                  ),
                  isLoading: _isSearching,
                  onRetry: _catalogFailure == null
                      ? null
                      : () {
                          _searchRequest += 1;
                          unawaited(
                            _loadDiagnosisCatalog(
                              _searchQuery,
                              _searchRequest,
                            ),
                          );
                        },
                );
                final Widget selectedPanel = _buildTransferPanel(
                  context: context,
                  title: l10n.clinicalDiagnosisSelectedTitle,
                  countLabel: l10n.clinicalDiagnosisSelectedCount(
                    _selectedDiagnoses.length,
                  ),
                  items: List<ClinicalActionCatalogOption>.of(
                    _selectedDiagnoses,
                  ),
                  checkedIds: _checkedSelectedIds,
                  showSearch: false,
                  actionLabel: l10n.clinicalDiagnosisDeselectAction,
                  actionIcon: Icons.remove,
                  onAction: _deselectCheckedDiagnoses,
                  actionEnabled:
                      !_isSaving && _checkedSelectedIds.isNotEmpty,
                  emptyLabel: l10n.clinicalDiagnosisNoSelection,
                  isLoading: false,
                );

                if (!twoColumns) {
                  return Column(
                    children: <Widget>[
                      Expanded(child: availablePanel),
                      SizedBox(height: theme.spacing.md),
                      Expanded(child: selectedPanel),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: availablePanel),
                    SizedBox(width: theme.spacing.md),
                    Expanded(child: selectedPanel),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.clinicalAddDiagnosisAction,
          isLoading: _isSaving,
          enabled: !_isSaving && _selectedDiagnoses.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildTransferPanel({
    required BuildContext context,
    required String title,
    required String countLabel,
    required List<ClinicalActionCatalogOption> items,
    required Set<String> checkedIds,
    required bool showSearch,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onAction,
    required bool actionEnabled,
    required String emptyLabel,
    required bool isLoading,
    VoidCallback? onRetry,
  }) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              countLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showSearch)
                  Expanded(
                    child: AppTextField(
                      controller: _searchController,
                      labelText: l10n.clinicalDiagnosisSearchLabel,
                      hintText: l10n.clinicalDiagnosisSearchHint,
                      enabled: !_isSaving,
                      onChanged: _scheduleSearch,
                    ),
                  )
                else
                  const Spacer(),
                if (showSearch) SizedBox(width: theme.spacing.sm),
                Padding(
                  padding: EdgeInsets.only(top: theme.spacing.xs),
                  child: AppButton.primary(
                    label: actionLabel,
                    leadingIcon: actionIcon,
                    enabled: actionEnabled,
                    onPressed: onAction,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            Expanded(
              child: AppListTable<ClinicalActionCatalogOption>(
                items: items,
                displayMode: AppListTableDisplayMode.table,
                tableHorizontalMargin: 0,
                isLoading: isLoading,
                itemKeyBuilder: (ClinicalActionCatalogOption item) =>
                    ValueKey<String>(item.apiId),
                columns: _transferColumns(
                  context: context,
                  items: items,
                  checkedIds: checkedIds,
                ),
                emptyBuilder: (_) => Padding(
                  padding: EdgeInsets.all(theme.spacing.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      AppMutedText(emptyLabel, textAlign: TextAlign.center),
                      if (onRetry != null) ...<Widget>[
                        SizedBox(height: theme.spacing.sm),
                        AppButton.tertiary(
                          label: l10n.commonRetryActionLabel,
                          enabled: !_isSaving,
                          onPressed: onRetry,
                        ),
                      ],
                    ],
                  ),
                ),
                mobileItemBuilder:
                    (BuildContext context, ClinicalActionCatalogOption item) {
                      final bool checked = checkedIds.contains(item.apiId);
                      return AppListTableMobileItem(
                        leading: Checkbox(
                          value: checked,
                          onChanged: _isSaving
                              ? null
                              : (bool? value) {
                                  _setChecked(
                                    checkedIds,
                                    item.apiId,
                                    value ?? false,
                                  );
                                },
                          visualDensity: VisualDensity.compact,
                        ),
                        title: _diagnosisTitle(item),
                        caption: _diagnosisSubtitle(item),
                        showAvatar: false,
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AppListTableColumn<ClinicalActionCatalogOption>> _transferColumns({
    required BuildContext context,
    required List<ClinicalActionCatalogOption> items,
    required Set<String> checkedIds,
  }) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool allChecked =
        items.isNotEmpty &&
        items.every(
          (ClinicalActionCatalogOption item) => checkedIds.contains(item.apiId),
        );
    final bool someChecked = items.any(
      (ClinicalActionCatalogOption item) => checkedIds.contains(item.apiId),
    );

    return <AppListTableColumn<ClinicalActionCatalogOption>>[
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _selectColumnKey,
        label: '',
        alwaysVisible: true,
        headerBuilder: (BuildContext context) {
          return Checkbox(
            tristate: true,
            value: allChecked
                ? true
                : someChecked
                ? null
                : false,
            onChanged: items.isEmpty || _isSaving
                ? null
                : (bool? checked) {
                    setState(() {
                      if (checked ?? false) {
                        checkedIds.addAll(
                          items.map(
                            (ClinicalActionCatalogOption item) => item.apiId,
                          ),
                        );
                      } else {
                        checkedIds.removeAll(
                          items.map(
                            (ClinicalActionCatalogOption item) => item.apiId,
                          ),
                        );
                      }
                    });
                  },
            visualDensity: VisualDensity.compact,
          );
        },
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Checkbox(
            value: checkedIds.contains(item.apiId),
            onChanged: _isSaving
                ? null
                : (bool? value) {
                    _setChecked(checkedIds, item.apiId, value ?? false);
                  },
            visualDensity: VisualDensity.compact,
          );
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _nameColumnKey,
        label: l10n.clinicalDiagnosisNameColumnLabel,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) => appListTableCompareText(
              _diagnosisTitle(left),
              _diagnosisTitle(right),
            ),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          final String subtitle = _diagnosisSubtitle(item);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _diagnosisTitle(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }

  List<ClinicalActionCatalogOption> _availableDiagnoses() {
    return _catalogOptions
        .where(
          (ClinicalActionCatalogOption option) =>
              !_isDuplicateSelection(option),
        )
        .toList(growable: false);
  }

  List<ClinicalActionCatalogOption> _filterBySearch(
    List<ClinicalActionCatalogOption> options,
  ) {
    final List<String> tokens = _searchQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return options;
    }
    return options
        .where((ClinicalActionCatalogOption option) {
          final String searchText = _diagnosisSearchText(option).toLowerCase();
          return tokens.every(searchText.contains);
        })
        .toList(growable: false);
  }

  String _catalogEmptyLabel(
    AppLocalizations l10n, {
    required bool hasCatalog,
    required bool hasVisible,
  }) {
    if (_catalogFailure != null) {
      return l10n.clinicalDiagnosisNoCatalogOptions;
    }
    if (!hasCatalog) {
      return l10n.clinicalDiagnosisNoFacilityOptions;
    }
    if (!hasVisible) {
      return l10n.clinicalDiagnosisNoCatalogOptions;
    }
    return l10n.clinicalDiagnosisNoCatalogOptions;
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    final String query = value.trim();
    setState(() {
      _searchQuery = query;
      _checkedAvailableIds.clear();
    });
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      _searchRequest += 1;
      unawaited(_loadDiagnosisCatalog(query, _searchRequest));
    });
  }

  Future<void> _loadDiagnosisCatalog(String query, int requestId) async {
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    setState(() {
      _isSearching = true;
      _catalogFailure = null;
    });
    final Result<List<ClinicalActionCatalogOption>> result = await widget
        .onSearchClinicalTerms(
          termType: 'DIAGNOSIS',
          query: query.isEmpty ? null : query,
          limit: _catalogLimit,
          source: ClinicalCatalogSource.facility.apiValue,
        );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    result.when(
      success: (List<ClinicalActionCatalogOption> options) {
        setState(() {
          _catalogOptions = _dedupeDiagnosisOptions(options);
          _isSearching = false;
          _catalogFailure = null;
          _pruneCheckedIds();
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _catalogOptions = const <ClinicalActionCatalogOption>[];
          _isSearching = false;
          _catalogFailure = failure;
          _checkedAvailableIds.clear();
        });
      },
    );
  }

  void _setChecked(Set<String> checkedIds, String id, bool checked) {
    setState(() {
      if (checked) {
        checkedIds.add(id);
      } else {
        checkedIds.remove(id);
      }
    });
  }

  void _addCheckedDiagnoses() {
    if (_isSaving || _checkedAvailableIds.isEmpty) {
      return;
    }
    final List<ClinicalActionCatalogOption> toAdd = _availableDiagnoses()
        .where(
          (ClinicalActionCatalogOption option) =>
              _checkedAvailableIds.contains(option.apiId),
        )
        .where(
          (ClinicalActionCatalogOption option) =>
              !_isDuplicateSelection(option),
        )
        .toList(growable: false);
    if (toAdd.isEmpty) {
      return;
    }
    setState(() {
      _selectedDiagnoses = <ClinicalActionCatalogOption>[
        ..._selectedDiagnoses,
        ...toAdd,
      ];
      _checkedAvailableIds.clear();
      _failure = null;
    });
  }

  void _deselectCheckedDiagnoses() {
    if (_isSaving || _checkedSelectedIds.isEmpty) {
      return;
    }
    setState(() {
      _selectedDiagnoses = _selectedDiagnoses
          .where(
            (ClinicalActionCatalogOption option) =>
                !_checkedSelectedIds.contains(option.apiId),
          )
          .toList(growable: false);
      _checkedSelectedIds.clear();
      _failure = null;
    });
  }

  void _pruneCheckedIds() {
    final Set<String> availableIds = _availableDiagnoses()
        .map((ClinicalActionCatalogOption option) => option.apiId)
        .toSet();
    _checkedAvailableIds.removeWhere((String id) => !availableIds.contains(id));
    final Set<String> selectedIds = _selectedDiagnoses
        .map((ClinicalActionCatalogOption option) => option.apiId)
        .toSet();
    _checkedSelectedIds.removeWhere((String id) => !selectedIds.contains(id));
  }

  bool _isDuplicateSelection(ClinicalActionCatalogOption option) {
    final String key = _diagnosisDedupKey(option);
    return _selectedDiagnoses.any(
      (ClinicalActionCatalogOption item) => _diagnosisDedupKey(item) == key,
    );
  }

  Future<void> _submit() async {
    if (_selectedDiagnoses.isEmpty) {
      setState(
        () => _failure = AppFailure.validation(
          validationFields: const <String>{'diagnosis'},
        ),
      );
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      diagnosisType: _diagnosisType,
      diagnoses: List<ClinicalActionCatalogOption>.unmodifiable(
        _selectedDiagnoses,
      ),
    );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
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

List<ClinicalActionCatalogOption> _dedupeDiagnosisOptions(
  List<ClinicalActionCatalogOption> options,
) {
  final Set<String> seen = <String>{};
  final List<ClinicalActionCatalogOption> deduped =
      <ClinicalActionCatalogOption>[];
  for (final ClinicalActionCatalogOption option in options) {
    final String key = _diagnosisDedupKey(option);
    if (seen.add(key)) {
      deduped.add(option);
    }
  }
  return deduped;
}

String _diagnosisTitle(ClinicalActionCatalogOption option) {
  return clinicalActionTrimmedOrNull(option.name) ?? option.displayTitle;
}

String _diagnosisSubtitle(ClinicalActionCatalogOption option) {
  return clinicalActionJoinDisplay(<String?>[
    option.code,
    option.category,
    option.secondaryText,
    option.status,
  ]);
}

String _diagnosisSearchText(ClinicalActionCatalogOption option) {
  return clinicalActionJoinDisplay(<String?>[
    option.apiId,
    option.publicId,
    option.name,
    option.code,
    option.category,
    option.secondaryText,
    option.status,
    option.searchText,
  ]);
}

String _diagnosisDedupKey(ClinicalActionCatalogOption option) {
  final String code =
      clinicalActionTrimmedOrNull(option.code)?.toUpperCase() ?? '';
  final String title = _diagnosisTitle(option).toUpperCase();
  if (code.isNotEmpty || title.isNotEmpty) {
    return '$code::$title';
  }
  return clinicalActionTrimmedOrNull(option.apiId)?.toUpperCase() ?? '';
}

const List<String> _diagnosisTypes = <String>[
  'PRIMARY',
  'SECONDARY',
  'DIFFERENTIAL',
];
