import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_layer_selector.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
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

final class _DiagnosisCatalogSearchResults {
  const _DiagnosisCatalogSearchResults({
    required this.options,
    required this.totalMatches,
  });

  final List<ClinicalActionCatalogOption> options;
  final int totalMatches;
}

class _DiagnosisDialogState extends State<ClinicalDiagnosisActionDialog> {
  static const int _searchLimit = 80;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 160);

  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  String _diagnosisType = 'PRIMARY';
  ClinicalCatalogSource _catalogSource = ClinicalCatalogSource.all;
  String _searchQuery = '';
  int _searchRequest = 0;
  List<ClinicalActionCatalogOption> _catalogOptions =
      const <ClinicalActionCatalogOption>[];
  final List<ClinicalActionCatalogOption> _selectedDiagnoses =
      <ClinicalActionCatalogOption>[];
  bool _isSearching = false;
  bool _isSaving = false;
  AppFailure? _failure;

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
    final double bodyHeight = (MediaQuery.sizeOf(context).height * 0.64)
        .clamp(420.0, 640.0)
        .toDouble();
    final _DiagnosisCatalogSearchResults searchResults = _searchCatalog(
      _catalogOptions,
    );

    return AppDialog(
      title: Text(l10n.clinicalAddDiagnosisAction),
      icon: const Icon(Icons.rule_outlined),
      maxWidth: 920,
      closeEnabled: !_isSaving,
      content: SizedBox(
        height: bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _diagnosisType,
              labelText: l10n.opdDiagnosisTypeLabel,
              enabled: !_isSaving,
              isRequired: true,
              options: clinicalActionStatusOptions(_diagnosisTypes),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _diagnosisType = value);
                }
              },
            ),
            SizedBox(height: theme.spacing.sm),
            ClinicalCatalogLayerSelector(
              value: _catalogSource,
              enabled: !_isSaving,
              onChanged: (ClinicalCatalogSource source) {
                setState(() => _catalogSource = source);
                _searchRequest += 1;
                unawaited(
                  _loadDiagnosisCatalog(_searchQuery, _searchRequest),
                );
              },
            ),
            SizedBox(height: theme.spacing.md),
            AppTextField(
              controller: _searchController,
              labelText: l10n.clinicalDiagnosisSearchLabel,
              hintText: l10n.clinicalDiagnosisSearchHint,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.manage_search_outlined),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : AppIconButton(
                      icon: Icons.close,
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      onPressed: _isSaving ? null : _clearSearch,
                    ),
              onChanged: _scheduleSearch,
            ),
            if (_isSearching) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              const LinearProgressIndicator(),
            ],
            SizedBox(height: theme.spacing.md),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool twoColumns = constraints.maxWidth >= 760;
                  final Widget catalogPanel = _DiagnosisCatalogResultsPanel(
                    results: searchResults,
                    isSaving: _isSaving,
                    onSelected: _addDiagnosis,
                    isDuplicate: _isDuplicateSelection,
                  );
                  final Widget selectedPanel = _DiagnosisSelectedPanel(
                    diagnoses: _selectedDiagnoses,
                    diagnosisType: _diagnosisType,
                    isSaving: _isSaving,
                    onDelete: _removeDiagnosis,
                  );

                  if (!twoColumns) {
                    return Column(
                      children: <Widget>[
                        Expanded(child: catalogPanel),
                        SizedBox(height: theme.spacing.md),
                        Expanded(child: selectedPanel),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: catalogPanel),
                      SizedBox(width: theme.spacing.md),
                      Expanded(child: selectedPanel),
                    ],
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

  _DiagnosisCatalogSearchResults _searchCatalog(
    List<ClinicalActionCatalogOption> catalog,
  ) {
    final List<String> tokens = _searchQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return _DiagnosisCatalogSearchResults(
        options: catalog.take(_searchLimit).toList(growable: false),
        totalMatches: catalog.length,
      );
    }

    final List<ClinicalActionCatalogOption> visible =
        <ClinicalActionCatalogOption>[];
    var totalMatches = 0;
    for (final ClinicalActionCatalogOption option in catalog) {
      final String searchText = _diagnosisSearchText(option).toLowerCase();
      final bool isMatch = tokens.every(searchText.contains);
      if (!isMatch) {
        continue;
      }
      totalMatches += 1;
      if (visible.length < _searchLimit) {
        visible.add(option);
      }
    }

    return _DiagnosisCatalogSearchResults(
      options: visible,
      totalMatches: totalMatches,
    );
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    final String query = value.trim();
    setState(() => _searchQuery = query);
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
    setState(() => _isSearching = true);
    final Result<List<ClinicalActionCatalogOption>> result = await widget
        .onSearchClinicalTerms(
          termType: 'DIAGNOSIS',
          query: query.isEmpty ? null : query,
          limit: _searchLimit,
          source: _catalogSource.apiValue,
        );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    setState(() {
      _catalogOptions = result.when(
        success: _dedupeDiagnosisOptions,
        failure: (_) => const <ClinicalActionCatalogOption>[],
      );
      _isSearching = false;
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchRequest += 1;
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _failure = null;
    });
    unawaited(_loadDiagnosisCatalog('', _searchRequest));
  }

  void _addDiagnosis(ClinicalActionCatalogOption option) {
    if (_isDuplicateSelection(option)) {
      return;
    }
    setState(() {
      _selectedDiagnoses.add(option);
      _failure = null;
    });
  }

  void _removeDiagnosis(int index) {
    if (index < 0 || index >= _selectedDiagnoses.length) {
      return;
    }
    setState(() {
      _selectedDiagnoses.removeAt(index);
      _failure = null;
    });
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

class _DiagnosisCatalogResultsPanel extends StatelessWidget {
  const _DiagnosisCatalogResultsPanel({
    required this.results,
    required this.isSaving,
    required this.onSelected,
    required this.isDuplicate,
  });

  final _DiagnosisCatalogSearchResults results;
  final bool isSaving;
  final ValueChanged<ClinicalActionCatalogOption> onSelected;
  final bool Function(ClinicalActionCatalogOption option) isDuplicate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalActionCatalogOption> options = results.options;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Text(
              l10n.clinicalDiagnosisMatchesLabel(
                options.length,
                results.totalMatches,
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: options.isEmpty
                ? Center(child: Text(l10n.clinicalDiagnosisNoCatalogOptions))
                : ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      final ClinicalActionCatalogOption option = options[index];
                      final bool duplicate = isDuplicate(option);
                      return _DiagnosisCatalogOptionRow(
                        option: option,
                        isSaving: isSaving,
                        isDuplicate: duplicate,
                        onSelected: duplicate ? null : () => onSelected(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosisCatalogOptionRow extends StatelessWidget {
  const _DiagnosisCatalogOptionRow({
    required this.option,
    required this.isSaving,
    required this.isDuplicate,
    required this.onSelected,
  });

  final ClinicalActionCatalogOption option;
  final bool isSaving;
  final bool isDuplicate;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String subtitle = _diagnosisSubtitle(option);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.medical_information_outlined,
            color: colorScheme.primary,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _diagnosisTitle(option),
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
            ),
          ),
          TextButton.icon(
            onPressed: isSaving || isDuplicate ? null : onSelected,
            icon: Icon(Icons.add, size: theme.appTokens.listIconSize),
            label: Text(l10n.clinicalLabRequestAddSelectionAction),
          ),
        ],
      ),
    );
  }
}

class _DiagnosisSelectedPanel extends StatelessWidget {
  const _DiagnosisSelectedPanel({
    required this.diagnoses,
    required this.diagnosisType,
    required this.isSaving,
    required this.onDelete,
  });

  final List<ClinicalActionCatalogOption> diagnoses;
  final String diagnosisType;
  final bool isSaving;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.clinicalDiagnosisSelectedTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  l10n.clinicalDiagnosisSelectedCount(diagnoses.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: diagnoses.isEmpty
                ? Center(child: Text(l10n.clinicalDiagnosisNoSelection))
                : ListView.separated(
                    itemCount: diagnoses.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      return _DiagnosisSelectedRow(
                        option: diagnoses[index],
                        diagnosisType: diagnosisType,
                        isSaving: isSaving,
                        onDelete: () => onDelete(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosisSelectedRow extends StatelessWidget {
  const _DiagnosisSelectedRow({
    required this.option,
    required this.diagnosisType,
    required this.isSaving,
    required this.onDelete,
  });

  final ClinicalActionCatalogOption option;
  final String diagnosisType;
  final bool isSaving;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String subtitle = clinicalActionJoinDisplay(<String?>[
      clinicalActionApiLabel(diagnosisType),
      _diagnosisSubtitle(option),
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.rule_outlined,
            color: colorScheme.primary,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _diagnosisTitle(option),
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
            ),
          ),
          IconButton(
            tooltip: l10n.clinicalLabRequestDeleteSelectionAction,
            onPressed: isSaving ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
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
  final String code = clinicalActionTrimmedOrNull(option.code)?.toUpperCase() ?? '';
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
