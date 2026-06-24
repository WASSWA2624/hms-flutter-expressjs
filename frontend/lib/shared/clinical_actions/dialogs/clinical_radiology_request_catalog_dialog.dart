import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_select_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_radiology_catalog_helpers.dart';
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
}

Future<void> showClinicalRadiologyRequestCatalogDialog({
  required BuildContext context,
  required ClinicalActionReferenceData referenceData,
  required void Function(ClinicalRadiologyCatalogSelection selection) onAdd,
  required bool Function(ClinicalActionCatalogOption option) isDuplicate,
  ClinicalRadiologyCatalogSelection? editingSelection,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext context) => ClinicalRadiologyRequestCatalogDialog(
      referenceData: referenceData,
      onAdd: onAdd,
      isDuplicate: isDuplicate,
      editingSelection: editingSelection,
    ),
  );
}

class ClinicalRadiologyRequestCatalogDialog extends StatefulWidget {
  const ClinicalRadiologyRequestCatalogDialog({
    required this.referenceData,
    required this.onAdd,
    required this.isDuplicate,
    this.editingSelection,
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final void Function(ClinicalRadiologyCatalogSelection selection) onAdd;
  final bool Function(ClinicalActionCatalogOption option) isDuplicate;
  final ClinicalRadiologyCatalogSelection? editingSelection;

  @override
  State<ClinicalRadiologyRequestCatalogDialog> createState() =>
      _ClinicalRadiologyRequestCatalogDialogState();
}

class _ClinicalRadiologyRequestCatalogDialogState
    extends State<ClinicalRadiologyRequestCatalogDialog> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 120);

  late final TextEditingController _noteController;
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _modality;
  String? _bodyRegion;
  String? _laterality;
  String? _priority;
  String? _selectedCatalogId;

  bool get _isEditing => widget.editingSelection != null;

  @override
  void initState() {
    super.initState();
    final ClinicalRadiologyCatalogSelection? editing = widget.editingSelection;
    _noteController = TextEditingController(text: editing?.clinicalNote ?? '');
    _modality = editing?.modality;
    _bodyRegion = editing?.bodyRegion;
    _laterality = editing?.laterality;
    _priority = editing?.priority;
    _selectedCatalogId = editing?.option.apiId;
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
    final double bodyHeight = (MediaQuery.sizeOf(context).height * 0.62)
        .clamp(420.0, 620.0)
        .toDouble();
    final List<ClinicalActionCatalogOption> visibleCatalogOptions =
        _searchCatalog(widget.referenceData.radiologyTests);
    final ClinicalActionCatalogOption? selectedCatalogOption =
        _catalogOptionForId(_selectedCatalogId, visibleCatalogOptions);
    final bool selectedIsDuplicate = selectedCatalogOption != null &&
        widget.isDuplicate(selectedCatalogOption);
    final List<AppSelectOption<String>> catalogSelectOptions =
        clinicalRadiologyCatalogSelectOptions(l10n, visibleCatalogOptions);
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
      title: Text(l10n.clinicalRadiologyCatalogPickerTitle),
      icon: const Icon(Icons.manage_search_outlined),
      maxWidth: 760,
      scrollable: true,
      content: SizedBox(
        height: bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 640;
                final List<Widget> firstRowFields = <Widget>[
                  AppSelectField<String>.searchable(
                    value: _modality,
                    labelText: l10n.radiologyModalityLabel,
                    hintText: l10n.radiologyModalityLabel,
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
                        for (var index = 0; index < firstRowFields.length; index += 1) ...<Widget>[
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
              onChanged: (String? value) {
                setState(() {
                  _bodyRegion = value;
                  _selectedCatalogId = null;
                });
              },
            ),
            SizedBox(height: theme.spacing.md),
            Expanded(
              child: ClinicalCatalogSelectPanel(
                title: l10n.clinicalRadiologyCatalogSelectTitle,
                body: catalogSelectOptions.isEmpty
                    ? l10n.clinicalRadiologyRequestNoCatalogOptions
                    : l10n.clinicalRadiologyCatalogSelectBody,
                labelText: l10n.clinicalRadiologyCatalogSelectLabel,
                hintText: l10n.clinicalRadiologyCatalogSelectHint,
                options: catalogSelectOptions,
                value: _selectedCatalogId,
                isEditing: _isEditing,
                selectedIsDuplicate: selectedIsDuplicate,
                addLabel: l10n.clinicalRadiologyAddSelectionAction,
                updateLabel: l10n.clinicalRadiologyUpdateSelectionAction,
                duplicateMessage:
                    l10n.clinicalRadiologyDuplicateSelectionMessage,
                onChanged: (String? value) {
                  setState(() => _selectedCatalogId = value);
                },
                onSearchTextChanged: _scheduleSearch,
                onAdd: selectedCatalogOption == null || selectedIsDuplicate
                    ? null
                    : () => _handleAdd(selectedCatalogOption),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.clinicalRequestCatalogPickerDoneAction,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  void _handleAdd(ClinicalActionCatalogOption option) {
    widget.onAdd(
      ClinicalRadiologyCatalogSelection(
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
      ),
    );
    if (_isEditing) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _selectedCatalogId = null;
        _noteController.clear();
      });
    }
  }

  ClinicalActionCatalogOption? _catalogOptionForId(
    String? id,
    List<ClinicalActionCatalogOption> options,
  ) {
    return clinicalActionCatalogOptionById(options, id);
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
    final String? normalizedBodyRegion = clinicalActionTrimmedOrNull(bodyRegion);
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
}

class _RadiologyBodyRegionPicker extends StatelessWidget {
  const _RadiologyBodyRegionPicker({
    required this.regions,
    required this.value,
    required this.onChanged,
  });

  final List<AppSelectOption<String>> regions;
  final String? value;
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
        options: regions,
        onChanged: onChanged,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: theme.spacing.md),
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
                onSelected: (bool selected) {
                  onChanged(selected ? region.value : null);
                },
              ),
          ],
        ),
      ],
    );
  }
}
