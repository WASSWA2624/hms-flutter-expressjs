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
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_select_helpers.dart';
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

  Timer? _searchDebounce;
  String _diagnosisType = 'PRIMARY';
  ClinicalCatalogSource _catalogSource = ClinicalCatalogSource.all;
  String _searchQuery = '';
  int _searchRequest = 0;
  String? _selectedCatalogId;
  String? _focusedDiagnosisId;
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
    _searchRequest += 1;
    unawaited(_loadDiagnosisCatalog('', _searchRequest));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
                unawaited(_loadDiagnosisCatalog(_searchQuery, _searchRequest));
              },
            ),
            SizedBox(height: theme.spacing.md),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool twoColumns = constraints.maxWidth >= 760;
                  final Widget catalogPanel = _buildCatalogPanel(
                    context,
                    searchResults,
                  );
                  final Widget selectedPanel = _buildSelectedDiagnosesPanel(
                    context,
                  );

                  if (!twoColumns) {
                    return Column(
                      children: <Widget>[
                        catalogPanel,
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
    setState(() {
      _searchQuery = query;
      _selectedCatalogId = null;
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

  void _addDiagnosis(ClinicalActionCatalogOption option) {
    if (_isDuplicateSelection(option)) {
      return;
    }
    setState(() {
      _selectedDiagnoses.add(option);
      _selectedCatalogId = null;
      _failure = null;
    });
  }

  void _removeDiagnosis(int index) {
    if (index < 0 || index >= _selectedDiagnoses.length) {
      return;
    }
    final String removedId = _selectedDiagnoses[index].apiId;
    setState(() {
      _selectedDiagnoses.removeAt(index);
      if (_focusedDiagnosisId == removedId) {
        _focusedDiagnosisId = null;
      }
      _failure = null;
    });
  }

  Widget _buildCatalogPanel(
    BuildContext context,
    _DiagnosisCatalogSearchResults searchResults,
  ) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalActionCatalogOption> options = searchResults.options;
    final List<AppSelectOption<String>> selectOptions =
        clinicalCatalogSelectOptions(
          options,
          icon: Icons.medical_information_outlined,
          labelBuilder: (ClinicalActionCatalogOption option) {
            return ClinicalCatalogOptionLabel(
              option: option,
              title: _diagnosisTitle(option),
              subtitle: _diagnosisSubtitle(option),
            );
          },
        );
    final ClinicalActionCatalogOption? selectedOption =
        clinicalActionCatalogOptionById(options, _selectedCatalogId);
    final bool selectedIsDuplicate =
        selectedOption != null && _isDuplicateSelection(selectedOption);

    return ClinicalCatalogSelectPanel(
      title: l10n.clinicalDiagnosisMatchesLabel(
        options.length,
        searchResults.totalMatches,
      ),
      body: options.isEmpty
          ? l10n.clinicalDiagnosisNoCatalogOptions
          : l10n.clinicalDiagnosisSearchHint,
      labelText: l10n.clinicalDiagnosisSearchLabel,
      hintText: l10n.clinicalDiagnosisSearchHint,
      options: selectOptions,
      value: _selectedCatalogId,
      enabled: !_isSaving,
      isLoading: _isSearching,
      selectedIsDuplicate: selectedIsDuplicate,
      duplicateMessage: l10n.clinicalRadiologyDuplicateSelectionMessage,
      onChanged: (String? value) {
        setState(() => _selectedCatalogId = value);
      },
      onSearchTextChanged: _scheduleSearch,
      onAdd: selectedOption == null || selectedIsDuplicate
          ? null
          : () => _addDiagnosis(selectedOption),
    );
  }

  Widget _buildSelectedDiagnosesPanel(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalActionCatalogOption? focusedDiagnosis = _focusedDiagnosis();

    return ClinicalRequestSelectionManager(
      title: l10n.clinicalDiagnosisSelectedTitle,
      emptyLabel: l10n.clinicalDiagnosisNoSelection,
      options: clinicalCatalogSelectOptions(
        _selectedDiagnoses,
        icon: Icons.rule_outlined,
        labelBuilder: (ClinicalActionCatalogOption option) {
          return ClinicalCatalogOptionLabel(
            option: option,
            title: _diagnosisTitle(option),
            subtitle: clinicalActionJoinDisplay(<String?>[
              clinicalActionApiLabel(_diagnosisType),
              _diagnosisSubtitle(option),
            ]),
          );
        },
      ),
      value: _focusedDiagnosisId,
      enabled: !_isSaving,
      onChanged: (String? value) {
        setState(() => _focusedDiagnosisId = value);
      },
      onEdit: null,
      onDelete: focusedDiagnosis == null
          ? null
          : () => _removeDiagnosis(_diagnosisIndex(focusedDiagnosis)),
    );
  }

  ClinicalActionCatalogOption? _focusedDiagnosis() {
    if (_focusedDiagnosisId == null) {
      return null;
    }
    for (final ClinicalActionCatalogOption diagnosis in _selectedDiagnoses) {
      if (diagnosis.apiId == _focusedDiagnosisId) {
        return diagnosis;
      }
    }
    return null;
  }

  int _diagnosisIndex(ClinicalActionCatalogOption diagnosis) {
    return _selectedDiagnoses.indexWhere(
      (ClinicalActionCatalogOption item) => item.apiId == diagnosis.apiId,
    );
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
