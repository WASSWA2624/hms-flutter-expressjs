import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class ClinicalRadiologyOrderActionDialog extends StatefulWidget {
  const ClinicalRadiologyOrderActionDialog({
    required this.referenceData,
    required this.onSubmit,
    this.initialRequests = const <ClinicalActionRadiologyRequest>[],
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final List<ClinicalActionRadiologyRequest> initialRequests;
  final Future<AppFailure?> Function({
    required List<ClinicalActionRadiologyRequest> requests,
  })
  onSubmit;

  @override
  State<ClinicalRadiologyOrderActionDialog> createState() =>
      _RadiologyOrderDialogState();
}

final class _PendingRadiologyRequest {
  const _PendingRadiologyRequest({
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

  String get id => option.apiId;
}

final class _RadiologyCatalogSearchResults {
  const _RadiologyCatalogSearchResults({
    required this.options,
    required this.totalMatches,
  });

  final List<ClinicalActionCatalogOption> options;
  final int totalMatches;
}

class _RadiologyOrderDialogState
    extends State<ClinicalRadiologyOrderActionDialog> {
  static const int _maxVisibleCatalogOptions = 100;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 120);

  late final TextEditingController _searchController;
  late final TextEditingController _noteController;
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _modality;
  String? _bodyRegion;
  String? _laterality;
  String? _priority;
  final List<_PendingRadiologyRequest> _requests = <_PendingRadiologyRequest>[];
  int? _editingIndex;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _noteController = TextEditingController();
    _requests.addAll(_initialPendingRequests());
  }


  List<_PendingRadiologyRequest> _initialPendingRequests() {
    final List<_PendingRadiologyRequest> pending = <_PendingRadiologyRequest>[];
    for (final ClinicalActionRadiologyRequest request in widget.initialRequests) {
      final ClinicalActionCatalogOption? option = _catalogOptionForRequest(request);
      if (option == null) {
        continue;
      }
      pending.add(
        _PendingRadiologyRequest(
          option: option,
          clinicalNote: request.clinicalNote,
          bodyRegion: request.bodyRegion,
          laterality: request.laterality,
          priority: request.priority,
          modality: request.modality,
        ),
      );
    }
    return pending;
  }

  ClinicalActionCatalogOption? _catalogOptionForRequest(
    ClinicalActionRadiologyRequest request,
  ) {
    final String id = request.radiologyTestId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final ClinicalActionCatalogOption option
        in widget.referenceData.radiologyTests) {
      if (option.apiId == id || option.id == id || option.publicId == id) {
        return option;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final double bodyHeight = (MediaQuery.sizeOf(context).height * 0.68)
        .clamp(460.0, 680.0)
        .toDouble();
    final _RadiologyCatalogSearchResults searchResults = _searchCatalog(
      widget.referenceData.radiologyTests,
    );
    final List<AppSelectOption<String>> modalityOptions =
        _radiologyModalityOptions(widget.referenceData.radiologyTests);
    final List<AppSelectOption<String>> bodyRegionOptions =
        _radiologyBodyRegionOptions(
          widget.referenceData.radiologyTests,
          modality: _modality,
          laterality: _laterality,
        );
    return AppDialog(
      title: Text(l10n.clinicalRequestRadiologyAction),
      icon: const Icon(Icons.biotech_outlined),
      maxWidth: 980,
      closeEnabled: !_isSaving,
      content: SizedBox(
        height: bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 760;
                final List<Widget> firstRowFields = <Widget>[
                  AppSelectField<String>.searchable(
                    value: _modality,
                    labelText: l10n.radiologyModalityLabel,
                    hintText: l10n.radiologyModalityLabel,
                    enabled: !_isSaving,
                    options: modalityOptions,
                    onChanged: (String? value) {
                      setState(() {
                        _modality = value;
                        if (!_bodyRegionAvailable(value, _bodyRegion)) {
                          _bodyRegion = null;
                        }
                      });
                    },
                  ),
                  AppSelectField<String>.searchable(
                    value: _bodyRegion,
                    labelText: l10n.clinicalRadiologyBodyRegionLabel,
                    hintText: l10n.clinicalRadiologyBodyRegionLabel,
                    enabled: !_isSaving,
                    options: bodyRegionOptions,
                    onChanged: (String? value) {
                      setState(() => _bodyRegion = value);
                    },
                  ),
                  AppSelectField<String>(
                    value: _laterality,
                    labelText: l10n.clinicalRadiologyLateralityLabel,
                    enabled: !_isSaving,
                    options: clinicalActionStatusOptions(_radiologyLateralityValues),
                    onChanged: (String? value) {
                      setState(() {
                        _laterality = value;
                        if (!_bodyRegionAvailable(_modality, _bodyRegion)) {
                          _bodyRegion = null;
                        }
                      });
                    },
                  ),
                ];
                final List<Widget> secondRowFields = <Widget>[
                  AppSelectField<String>(
                    value: _priority,
                    labelText: l10n.clinicalRadiologyPriorityLabel,
                    enabled: !_isSaving,
                    options: clinicalActionStatusOptions(const <String>[
                      'ROUTINE',
                      'URGENT',
                      'STAT',
                    ]),
                    onChanged: (String? value) {
                      setState(() => _priority = value);
                    },
                  ),
                  AppTextField(
                    controller: _noteController,
                    labelText: l10n.opdClinicalNoteLabel,
                    enabled: !_isSaving,
                    maxLines: compact ? 2 : 1,
                  ),
                ];

                if (compact) {
                  return Column(
                    children: <Widget>[
                      for (final Widget field in <Widget>[
                        ...firstRowFields,
                        ...secondRowFields,
                      ]) ...<Widget>[field, SizedBox(height: theme.spacing.sm)],
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        for (
                          var index = 0;
                          index < firstRowFields.length;
                          index += 1
                        ) ...<Widget>[
                          Expanded(child: firstRowFields[index]),
                          if (index < firstRowFields.length - 1)
                            SizedBox(width: theme.spacing.sm),
                        ],
                      ],
                    ),
                    SizedBox(height: theme.spacing.sm),
                    Row(
                      children: <Widget>[
                        SizedBox(width: 220, child: secondRowFields.first),
                        SizedBox(width: theme.spacing.sm),
                        Expanded(child: secondRowFields.last),
                      ],
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: theme.spacing.md),
            AppTextField(
              controller: _searchController,
              labelText: l10n.clinicalRadiologyRequestSearchLabel,
              hintText: l10n.clinicalRadiologyRequestSearchHint,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.search),
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
            if (_editingIndex != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.tertiary(
                  label: l10n.clinicalRadiologyCancelEditAction,
                  leadingIcon: Icons.close,
                  enabled: !_isSaving,
                  onPressed: _cancelEdit,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.md),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool twoColumns = constraints.maxWidth >= 760;
                  final Widget catalogPanel = _RadiologyCatalogResultsPanel(
                    results: searchResults,
                    isSaving: _isSaving,
                    isEditing: _editingIndex != null,
                    onSelected: _addOrUpdateRequest,
                    isDuplicate: _isDuplicateSelection,
                  );
                  final Widget selectedPanel = _RadiologySelectedRequestsPanel(
                    requests: _requests,
                    editingIndex: _editingIndex,
                    isSaving: _isSaving,
                    onEdit: _editRequest,
                    onDelete: _deleteRequest,
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
          label: l10n.clinicalRequestRadiologyAction,
          isLoading: _isSaving,
          enabled: !_isSaving && _requests.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  _RadiologyCatalogSearchResults _searchCatalog(
    List<ClinicalActionCatalogOption> catalog,
  ) {
    final List<String> tokens = _searchQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    final List<ClinicalActionCatalogOption> visible =
        <ClinicalActionCatalogOption>[];
    var totalMatches = 0;
    for (final ClinicalActionCatalogOption option in catalog) {
      if (!_matchesRadiologyFilters(option)) {
        continue;
      }
      final String searchText = _catalogSearchText(option);
      final bool isMatch = tokens.isEmpty || tokens.every(searchText.contains);
      if (!isMatch) {
        continue;
      }
      totalMatches += 1;
      if (visible.length < _maxVisibleCatalogOptions) {
        visible.add(option);
      }
    }

    return _RadiologyCatalogSearchResults(
      options: visible,
      totalMatches: totalMatches,
    );
  }

  bool _matchesRadiologyFilters(ClinicalActionCatalogOption option) {
    final String? selectedModality = clinicalActionTrimmedOrNull(_modality);
    final String? selectedBodyRegion = clinicalActionTrimmedOrNull(_bodyRegion);
    final String? selectedLaterality = clinicalActionTrimmedOrNull(_laterality);
    if (selectedModality != null &&
        clinicalActionNormalizedCatalogToken(_radiologyOptionModality(option) ?? '') !=
            clinicalActionNormalizedCatalogToken(selectedModality)) {
      return false;
    }
    if (selectedBodyRegion != null &&
        clinicalActionNormalizedCatalogToken(_radiologyOptionBodyRegion(option) ?? '') !=
            clinicalActionNormalizedCatalogToken(selectedBodyRegion)) {
      return false;
    }
    if (selectedLaterality != null &&
        clinicalActionNormalizedCatalogToken(_radiologyOptionLaterality(option) ?? '') !=
            clinicalActionNormalizedCatalogToken(selectedLaterality)) {
      return false;
    }
    return true;
  }

  String _catalogSearchText(ClinicalActionCatalogOption option) {
    return clinicalActionJoinDisplay(<String?>[
      option.apiId,
      option.displayTitle,
      option.displaySubtitle,
      option.name,
      option.code,
      _radiologyOptionModality(option),
      _radiologyOptionBodyRegion(option),
      _radiologyOptionLaterality(option),
      option.category,
      option.secondaryText,
      option.status,
      option.searchText,
    ]).toLowerCase();
  }

  bool _bodyRegionAvailable(String? modality, String? bodyRegion) {
    final String? normalizedBodyRegion = clinicalActionTrimmedOrNull(bodyRegion);
    if (normalizedBodyRegion == null) {
      return true;
    }
    return _radiologyBodyRegionOptions(
      widget.referenceData.radiologyTests,
      modality: modality,
      laterality: _laterality,
    ).any(
      (AppSelectOption<String> option) =>
          clinicalActionNormalizedCatalogToken(option.value) ==
          clinicalActionNormalizedCatalogToken(normalizedBodyRegion),
    );
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value);
    });
  }

  void _clearSearch() {
    setState(_resetSearch);
  }

  void _resetSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchQuery = '';
  }

  void _addOrUpdateRequest(ClinicalActionCatalogOption option) {
    final int? editingIndex = _editingIndex;
    final _PendingRadiologyRequest request = _PendingRadiologyRequest(
      option: option,
      clinicalNote: clinicalActionTrimmedOrNull(_noteController.text),
      bodyRegion:
          clinicalActionTrimmedOrNull(_bodyRegion) ?? _radiologyOptionBodyRegion(option),
      laterality: _laterality ?? _radiologyOptionLaterality(option),
      priority: _priority,
      modality: clinicalActionTrimmedOrNull(_modality) ?? _radiologyOptionModality(option),
    );

    setState(() {
      _failure = null;
      if (editingIndex != null &&
          editingIndex >= 0 &&
          editingIndex < _requests.length) {
        _requests[editingIndex] = request;
        _editingIndex = null;
        _resetSearch();
        _resetRequestDetails();
        return;
      }
      _requests.add(request);
      _resetRequestDetails();
    });
  }

  void _editRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    final _PendingRadiologyRequest request = _requests[index];
    setState(() {
      _editingIndex = index;
      _failure = null;
      _searchController.text = request.option.displayTitle;
      _searchQuery = request.option.displayTitle;
      _noteController.text = request.clinicalNote ?? '';
      _modality = request.modality ?? _radiologyOptionModality(request.option);
      _bodyRegion =
          request.bodyRegion ?? _radiologyOptionBodyRegion(request.option);
      _laterality = request.laterality;
      _priority = request.priority;
    });
  }

  void _deleteRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    setState(() {
      _requests.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _resetSearch();
        _resetRequestDetails();
      } else if (_editingIndex case final int editingIndex
          when editingIndex > index) {
        _editingIndex = editingIndex - 1;
      }
      _failure = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _failure = null;
      _resetSearch();
      _resetRequestDetails();
    });
  }

  void _resetRequestDetails() {
    _noteController.clear();
    _modality = null;
    _bodyRegion = null;
    _laterality = null;
    _priority = null;
  }

  bool _isDuplicateSelection(ClinicalActionCatalogOption option) {
    final int? editingIndex = _editingIndex;
    for (var index = 0; index < _requests.length; index += 1) {
      if (index == editingIndex) {
        continue;
      }
      if (_requests[index].id == option.apiId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _submit() async {
    if (_requests.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      requests: <ClinicalActionRadiologyRequest>[
        for (final _PendingRadiologyRequest request in _requests)
          ClinicalActionRadiologyRequest(
            radiologyTestId: request.id,
            clinicalNote: request.clinicalNote,
            bodyRegion: request.bodyRegion,
            laterality: request.laterality,
            priority: request.priority,
            modality: request.modality,
          ),
      ],
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

class _RadiologyCatalogResultsPanel extends StatelessWidget {
  const _RadiologyCatalogResultsPanel({
    required this.results,
    required this.isSaving,
    required this.isEditing,
    required this.onSelected,
    required this.isDuplicate,
  });

  final _RadiologyCatalogSearchResults results;
  final bool isSaving;
  final bool isEditing;
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
              l10n.clinicalRadiologyRequestMatchesLabel(
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
                ? Center(
                    child: Text(l10n.clinicalRadiologyRequestNoCatalogOptions),
                  )
                : ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      final ClinicalActionCatalogOption option = options[index];
                      final bool duplicate = isDuplicate(option);
                      return _RadiologyCatalogOptionRow(
                        option: option,
                        isSaving: isSaving,
                        isEditing: isEditing,
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

class _RadiologyCatalogOptionRow extends StatelessWidget {
  const _RadiologyCatalogOptionRow({
    required this.option,
    required this.isSaving,
    required this.isEditing,
    required this.isDuplicate,
    required this.onSelected,
  });

  final ClinicalActionCatalogOption option;
  final bool isSaving;
  final bool isEditing;
  final bool isDuplicate;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String actionLabel = isEditing
        ? l10n.clinicalRadiologyUpdateSelectionAction
        : l10n.clinicalRadiologyAddSelectionAction;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            _radiologyCatalogIcon(option),
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
                  option.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Builder(
                  builder: (BuildContext context) {
                    final String subtitle = clinicalActionJoinDisplay(<String?>[
                      _radiologyOptionModality(option),
                      _radiologyOptionBodyRegion(option),
                      _radiologyOptionLaterality(option),
                      option.status,
                      option.displaySubtitle,
                    ]);
                    if (subtitle.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: isSaving || isDuplicate ? null : onSelected,
            icon: Icon(
              isEditing ? Icons.done_outlined : Icons.add,
              size: theme.appTokens.listIconSize,
            ),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _RadiologySelectedRequestsPanel extends StatelessWidget {
  const _RadiologySelectedRequestsPanel({
    required this.requests,
    required this.editingIndex,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_PendingRadiologyRequest> requests;
  final int? editingIndex;
  final bool isSaving;
  final ValueChanged<int> onEdit;
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
                    l10n.clinicalRadiologyRequestSelectedTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  l10n.clinicalRadiologyRequestSelectedCount(requests.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: requests.isEmpty
                ? Center(child: Text(l10n.clinicalRadiologyRequestNoSelection))
                : ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      return _RadiologySelectedRequestRow(
                        request: requests[index],
                        isEditing: editingIndex == index,
                        isSaving: isSaving,
                        onEdit: () => onEdit(index),
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

class _RadiologySelectedRequestRow extends StatelessWidget {
  const _RadiologySelectedRequestRow({
    required this.request,
    required this.isEditing,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final _PendingRadiologyRequest request;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String subtitle = clinicalActionJoinDisplay(<String?>[
      request.modality ?? _radiologyOptionModality(request.option),
      request.bodyRegion ?? _radiologyOptionBodyRegion(request.option),
      request.laterality == null ? null : clinicalActionApiLabel(request.laterality!),
      request.priority == null ? null : clinicalActionApiLabel(request.priority!),
      request.option.status,
    ]);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isEditing
            ? colorScheme.primaryContainer.withValues(alpha: 0.38)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              _radiologyCatalogIcon(request.option),
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
                    request.option.displayTitle,
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
                  if (clinicalActionHasText(request.clinicalNote))
                    Text(
                      request.clinicalNote!,
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
              tooltip: l10n.clinicalRadiologyEditSelectionAction,
              onPressed: isSaving ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: l10n.clinicalRadiologyDeleteSelectionAction,
              onPressed: isSaving ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

List<AppSelectOption<String>> _radiologyModalityOptions(
  List<ClinicalActionCatalogOption> catalog,
) {
  final List<String> values = _sortedRadiologyValues(
    catalog.map(_radiologyOptionModality),
  );
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(
        value: value,
        label: clinicalActionApiLabel(value),
        leadingIcon: Icon(
          _radiologyCatalogIcon(
            ClinicalActionCatalogOption(
              id: value,
              name: value,
              category: value,
            ),
          ),
        ),
      ),
  ];
}

List<AppSelectOption<String>> _radiologyBodyRegionOptions(
  List<ClinicalActionCatalogOption> catalog, {
  String? modality,
  String? laterality,
}) {
  final String? selectedModality = clinicalActionTrimmedOrNull(modality);
  final String? selectedLaterality = clinicalActionTrimmedOrNull(laterality);
  final Iterable<ClinicalActionCatalogOption> filtered = catalog.where((
    ClinicalActionCatalogOption option,
  ) {
    if (selectedModality != null &&
        clinicalActionNormalizedCatalogToken(_radiologyOptionModality(option) ?? '') !=
            clinicalActionNormalizedCatalogToken(selectedModality)) {
      return false;
    }
    if (selectedLaterality != null &&
        clinicalActionNormalizedCatalogToken(_radiologyOptionLaterality(option) ?? '') !=
            clinicalActionNormalizedCatalogToken(selectedLaterality)) {
      return false;
    }
    return true;
  });
  final List<String> values = _sortedRadiologyValues(
    filtered.map(_radiologyOptionBodyRegion),
  );
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(
        value: value,
        label: clinicalActionApiLabel(value),
        leadingIcon: const Icon(Icons.accessibility_new_outlined),
      ),
  ];
}

List<String> _sortedRadiologyValues(Iterable<String?> values) {
  final Set<String> seen = <String>{};
  final List<String> unique = <String>[];
  for (final String? value in values) {
    final String? normalized = clinicalActionTrimmedOrNull(value);
    if (normalized == null) {
      continue;
    }
    final String key = clinicalActionNormalizedCatalogToken(normalized);
    if (seen.add(key)) {
      unique.add(normalized);
    }
  }
  unique.sort(
    (String left, String right) => clinicalActionApiLabel(
      left,
    ).compareTo(clinicalActionApiLabel(right)),
  );
  return unique;
}

String? _radiologyOptionModality(ClinicalActionCatalogOption option) {
  return clinicalActionTrimmedOrNull(_radiologyMetadataText(option, 'modality')) ??
      clinicalActionTrimmedOrNull(option.category);
}

String? _radiologyOptionBodyRegion(ClinicalActionCatalogOption option) {
  return clinicalActionTrimmedOrNull(_radiologyMetadataText(option, 'body_region')) ??
      clinicalActionTrimmedOrNull(_radiologyMetadataText(option, 'bodyRegion')) ??
      _radiologySecondaryFragment(
        option,
        exclude: <String?>[
          _radiologyOptionModality(option),
          _radiologyOptionLaterality(option),
          option.status,
        ],
      );
}

String? _radiologyOptionLaterality(ClinicalActionCatalogOption option) {
  final String? metadataValue = clinicalActionTrimmedOrNull(
    _radiologyMetadataText(option, 'laterality'),
  );
  if (metadataValue != null) {
    return metadataValue;
  }
  final String haystack = clinicalActionJoinDisplay(<String?>[
    option.secondaryText,
    option.searchText,
    option.name,
  ]).toUpperCase();
  for (final String value in _radiologyLateralityValues) {
    if (haystack.contains(value)) {
      return value;
    }
  }
  return null;
}

String? _radiologyMetadataText(ClinicalActionCatalogOption option, String key) {
  final Object? value = option.metadata[key];
  final String? normalized = clinicalActionTrimmedOrNull(value?.toString());
  return normalized;
}

String? _radiologySecondaryFragment(
  ClinicalActionCatalogOption option, {
  required Iterable<String?> exclude,
}) {
  final Set<String> excluded = exclude
      .whereType<String>()
      .map(clinicalActionNormalizedCatalogToken)
      .where((String value) => value.isNotEmpty)
      .toSet();
  final List<String> fragments = <String>[
    ...?clinicalActionTrimmedOrNull(option.secondaryText)?.split(RegExp(r'[|,;/]+')),
  ];
  for (final String fragment in fragments) {
    final String? normalized = clinicalActionTrimmedOrNull(fragment);
    if (normalized == null) {
      continue;
    }
    final String token = clinicalActionNormalizedCatalogToken(normalized);
    if (excluded.contains(token) ||
        _radiologyLateralityValues.contains(token)) {
      continue;
    }
    return normalized;
  }
  return null;
}

IconData _radiologyCatalogIcon(ClinicalActionCatalogOption option) {
  return switch ((option.category ?? '').toUpperCase()) {
    'XRAY' => Icons.photo_camera_outlined,
    'CT' => Icons.donut_large_outlined,
    'MRI' => Icons.all_out_outlined,
    'ULTRASOUND' => Icons.graphic_eq_outlined,
    'FLUOROSCOPY' => Icons.video_camera_back_outlined,
    'MAMMOGRAPHY' => Icons.image_search_outlined,
    'PET' || 'NUCLEAR_MEDICINE' => Icons.blur_on_outlined,
    'INTERVENTIONAL_RADIOLOGY' => Icons.medical_services_outlined,
    'ECG' => Icons.monitor_heart_outlined,
    'ECHO' => Icons.favorite_border,
    'ENDO' || 'GASTRO' => Icons.biotech_outlined,
    _ => Icons.biotech_outlined,
  };
}

const List<String> _radiologyLateralityValues = <String>[
  'LEFT',
  'RIGHT',
  'BILATERAL',
];
