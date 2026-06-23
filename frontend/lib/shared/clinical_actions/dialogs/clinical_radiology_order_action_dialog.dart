import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_radiology_catalog_helpers.dart';
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

class _RadiologyOrderDialogState
    extends State<ClinicalRadiologyOrderActionDialog> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 120);

  late final TextEditingController _noteController;
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _modality;
  String? _bodyRegion;
  String? _laterality;
  String? _priority;
  String? _selectedCatalogId;
  final List<_PendingRadiologyRequest> _requests = <_PendingRadiologyRequest>[];
  int? _editingIndex;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _requests.addAll(_initialPendingRequests());
  }

  List<_PendingRadiologyRequest> _initialPendingRequests() {
    final List<_PendingRadiologyRequest> pending = <_PendingRadiologyRequest>[];
    for (final ClinicalActionRadiologyRequest request
        in widget.initialRequests) {
      final ClinicalActionCatalogOption? option = _catalogOptionForRequest(
        request,
      );
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

  ClinicalActionCatalogOption? _catalogOptionForId(
    String? id,
    List<ClinicalActionCatalogOption> options,
  ) {
    final String normalizedId = (id ?? '').trim();
    if (normalizedId.isEmpty) {
      return null;
    }
    for (final ClinicalActionCatalogOption option in options) {
      if (option.apiId == normalizedId ||
          option.id == normalizedId ||
          option.publicId == normalizedId) {
        return option;
      }
    }
    return null;
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
    final List<ClinicalActionCatalogOption> visibleCatalogOptions =
        _searchCatalog(widget.referenceData.radiologyTests);
    final ClinicalActionCatalogOption? selectedCatalogOption =
        _catalogOptionForId(_selectedCatalogId, visibleCatalogOptions);
    final bool selectedIsDuplicate =
        selectedCatalogOption != null &&
        _isDuplicateSelection(selectedCatalogOption);
    final List<AppSelectOption<String>> catalogSelectOptions =
        _radiologyCatalogSelectOptions(visibleCatalogOptions);
    final List<AppSelectOption<String>> modalityOptions =
        clinicalRadiologyModalityOptions(
          l10n,
          widget.referenceData.radiologyTests,
        );
    final List<AppSelectOption<String>> bodyRegionOptions =
        clinicalRadiologyBodyRegionOptions(
          widget.referenceData.radiologyTests,
          modality: _modality,
          laterality: _laterality,
          priority: _priority,
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
                        _selectedCatalogId = null;
                        if (!_bodyRegionAvailable(value, _bodyRegion)) {
                          _bodyRegion = null;
                        }
                      });
                    },
                  ),
                  AppSelectField<String>(
                    value: _laterality,
                    labelText: l10n.clinicalRadiologyLateralityLabel,
                    enabled: !_isSaving,
                    options: clinicalRadiologyLateralityOptions(l10n),
                    onChanged: (String? value) {
                      setState(() {
                        _laterality = value;
                        _selectedCatalogId = null;
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
                      setState(() {
                        _priority = value;
                        _selectedCatalogId = null;
                      });
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
            _RadiologyBodyRegionPicker(
              regions: bodyRegionOptions,
              value: _bodyRegion,
              enabled: !_isSaving,
              onChanged: (String? value) {
                setState(() {
                  _bodyRegion = value;
                  _selectedCatalogId = null;
                });
              },
            ),
            SizedBox(height: theme.spacing.md),
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
                  final Widget catalogPanel = _RadiologyCatalogSelectPanel(
                    value: _selectedCatalogId,
                    options: catalogSelectOptions,
                    isSaving: _isSaving,
                    isEditing: _editingIndex != null,
                    selectedIsDuplicate: selectedIsDuplicate,
                    onChanged: (String? value) {
                      setState(() => _selectedCatalogId = value);
                    },
                    onSearchTextChanged: _scheduleSearch,
                    onAdd: selectedCatalogOption == null || selectedIsDuplicate
                        ? null
                        : () => _addOrUpdateRequest(selectedCatalogOption),
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

  List<ClinicalActionCatalogOption> _searchCatalog(
    List<ClinicalActionCatalogOption> catalog,
  ) {
    final List<String> tokens = _searchQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    return <ClinicalActionCatalogOption>[
      for (final ClinicalActionCatalogOption option in catalog)
        if (_matchesRadiologyFilters(option) &&
            (tokens.isEmpty ||
                tokens.every(_catalogSearchText(option).contains)))
          option,
    ];
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

  String _catalogSearchText(ClinicalActionCatalogOption option) {
    return clinicalActionJoinDisplay(<String?>[
      option.apiId,
      option.displayTitle,
      option.displaySubtitle,
      option.name,
      option.code,
      clinicalRadiologyOptionModality(option),
      clinicalRadiologyOptionBodyRegion(option),
      clinicalRadiologyOptionLaterality(option),
      clinicalRadiologyOptionPriority(option),
      option.category,
      option.secondaryText,
      option.status,
      option.searchText,
    ]).toLowerCase();
  }

  bool _bodyRegionAvailable(String? modality, String? bodyRegion) {
    final String? normalizedBodyRegion = clinicalActionTrimmedOrNull(
      bodyRegion,
    );
    if (normalizedBodyRegion == null) {
      return true;
    }
    return clinicalRadiologyBodyRegionOptions(
      widget.referenceData.radiologyTests,
      modality: modality,
      laterality: _laterality,
      priority: _priority,
    ).any(
      (AppSelectOption<String> option) =>
          clinicalActionNormalizedCatalogToken(option.value) ==
          clinicalActionNormalizedCatalogToken(normalizedBodyRegion),
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
    });
  }

  void _resetSearch() {
    _searchDebounce?.cancel();
    _searchQuery = '';
    _selectedCatalogId = null;
  }

  void _addOrUpdateRequest(ClinicalActionCatalogOption option) {
    final int? editingIndex = _editingIndex;
    final _PendingRadiologyRequest request = _PendingRadiologyRequest(
      option: option,
      clinicalNote: clinicalActionTrimmedOrNull(_noteController.text),
      bodyRegion:
          clinicalActionTrimmedOrNull(_bodyRegion) ??
          clinicalRadiologyOptionBodyRegion(option),
      laterality: _laterality ?? clinicalRadiologyOptionLaterality(option),
      priority: _priority,
      modality:
          clinicalActionTrimmedOrNull(_modality) ??
          clinicalRadiologyOptionModality(option),
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
      _resetSearch();
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
      _selectedCatalogId = request.option.apiId;
      _searchQuery = '';
      _noteController.text = request.clinicalNote ?? '';
      _modality = request.modality ?? clinicalRadiologyOptionModality(request.option);
      _bodyRegion =
          request.bodyRegion ?? clinicalRadiologyOptionBodyRegion(request.option);
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
      } else {
        final int? editingIndex = _editingIndex;
        if (editingIndex != null && editingIndex > index) {
          _editingIndex = editingIndex - 1;
        }
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

class _RadiologyCatalogSelectPanel extends StatelessWidget {
  const _RadiologyCatalogSelectPanel({
    required this.value,
    required this.options,
    required this.isSaving,
    required this.isEditing,
    required this.selectedIsDuplicate,
    required this.onChanged,
    required this.onSearchTextChanged,
    required this.onAdd,
  });

  final String? value;
  final List<AppSelectOption<String>> options;
  final bool isSaving;
  final bool isEditing;
  final bool selectedIsDuplicate;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onSearchTextChanged;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String actionLabel = isEditing
        ? l10n.clinicalRadiologyUpdateSelectionAction
        : l10n.clinicalRadiologyAddSelectionAction;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.clinicalRadiologyCatalogSelectTitle,
              style: theme.textTheme.labelLarge,
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              options.isEmpty
                  ? l10n.clinicalRadiologyRequestNoCatalogOptions
                  : l10n.clinicalRadiologyCatalogSelectBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AppSelectField<String>.searchable(
                    value: value,
                    labelText: l10n.clinicalRadiologyCatalogSelectLabel,
                    hintText: l10n.clinicalRadiologyCatalogSelectHint,
                    enabled: !isSaving,
                    options: options,
                    onChanged: onChanged,
                    onSearchTextChanged: onSearchTextChanged,
                    menuHeight: 360,
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Padding(
                  padding: EdgeInsets.only(top: theme.spacing.xs),
                  child: AppButton.primary(
                    label: actionLabel,
                    leadingIcon: isEditing ? Icons.done_outlined : Icons.add,
                    enabled: !isSaving && !selectedIsDuplicate && onAdd != null,
                    onPressed: isSaving || selectedIsDuplicate ? null : onAdd,
                  ),
                ),
              ],
            ),
            if (selectedIsDuplicate) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                l10n.clinicalRadiologyDuplicateSelectionMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
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
      clinicalRadiologyModalityDisplayLabel(
        l10n,
        request.modality ?? clinicalRadiologyOptionModality(request.option),
      ),
      request.bodyRegion ?? clinicalRadiologyOptionBodyRegion(request.option),
      clinicalRadiologyLateralityLabel(l10n, request.laterality),
      request.priority == null
          ? null
          : clinicalActionApiLabel(request.priority!),
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
              clinicalRadiologyCatalogIcon(request.option),
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

List<AppSelectOption<String>> _radiologyCatalogSelectOptions(
  List<ClinicalActionCatalogOption> options,
) {
  return <AppSelectOption<String>>[
    for (final ClinicalActionCatalogOption option in options)
      AppSelectOption<String>(
        value: option.apiId,
        label: option.displayTitle,
        searchText: clinicalActionJoinDisplay(<String?>[
          option.apiId,
          option.displayTitle,
          option.displaySubtitle,
          clinicalRadiologyOptionModality(option),
          clinicalRadiologyOptionBodyRegion(option),
          clinicalRadiologyOptionLaterality(option),
          clinicalRadiologyOptionPriority(option),
          option.searchText,
        ]),
        leadingIcon: Icon(clinicalRadiologyCatalogIcon(option)),
        labelWidget: _RadiologyCatalogOptionLabel(option: option),
      ),
  ];
}

class _RadiologyCatalogOptionLabel extends StatelessWidget {
  const _RadiologyCatalogOptionLabel({required this.option});

  final ClinicalActionCatalogOption option;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final String subtitle = clinicalActionJoinDisplay(<String?>[
      clinicalRadiologyModalityDisplayLabel(l10n, clinicalRadiologyOptionModality(option)),
      clinicalRadiologyOptionBodyRegion(option),
      clinicalRadiologyOptionLaterality(option),
      clinicalRadiologyOptionPriority(option),
      option.status,
      option.displaySubtitle,
    ]);
    return Column(
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
  }
}

class _RadiologyBodyRegionPicker extends StatelessWidget {
  const _RadiologyBodyRegionPicker({
    required this.regions,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<AppSelectOption<String>> regions;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    if (regions.isEmpty) {
      return const SizedBox.shrink();
    }

    if (regions.length > 16) {
      return AppSelectField<String>.searchable(
        value: value,
        labelText: l10n.clinicalRadiologyBodyRegionLabel,
        hintText: l10n.clinicalRadiologyBodyRegionLabel,
        enabled: enabled,
        options: regions,
        onChanged: onChanged,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.clinicalRadiologyBodyRegionLabel,
          style: theme.textTheme.labelLarge,
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          l10n.clinicalRadiologyBodyRegionPickerHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        Wrap(
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
                onSelected: enabled
                    ? (bool selected) {
                        onChanged(selected ? region.value : null);
                      }
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}
