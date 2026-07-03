import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_layer_selector.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_select_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum ClinicalLabRequestCatalogKind { tests, panels }

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
  required void Function(
    ClinicalActionCatalogOption option,
    ClinicalLabRequestCatalogKind kind,
  )
  onAdd,
  required bool Function(
    ClinicalActionCatalogOption option,
    ClinicalLabRequestCatalogKind kind,
  )
  isDuplicate,
  ClinicalLabRequestCatalogKind initialKind =
      ClinicalLabRequestCatalogKind.tests,
  ClinicalActionCatalogOption? editingOption,
  ClinicalLabRequestCatalogKind? editingKind,
  bool facilityOfferingsOnly = false,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext context) => ClinicalLabRequestCatalogDialog(
      referenceData: referenceData,
      onSearchLabTests: onSearchLabTests,
      onAdd: onAdd,
      isDuplicate: isDuplicate,
      initialKind: initialKind,
      editingOption: editingOption,
      editingKind: editingKind,
      facilityOfferingsOnly: facilityOfferingsOnly,
    ),
  );
}

class ClinicalLabRequestCatalogDialog extends StatefulWidget {
  const ClinicalLabRequestCatalogDialog({
    required this.referenceData,
    required this.onSearchLabTests,
    required this.onAdd,
    required this.isDuplicate,
    this.initialKind = ClinicalLabRequestCatalogKind.tests,
    this.editingOption,
    this.editingKind,
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
  final void Function(
    ClinicalActionCatalogOption option,
    ClinicalLabRequestCatalogKind kind,
  )
  onAdd;
  final bool Function(
    ClinicalActionCatalogOption option,
    ClinicalLabRequestCatalogKind kind,
  )
  isDuplicate;
  final ClinicalLabRequestCatalogKind initialKind;
  final ClinicalActionCatalogOption? editingOption;
  final ClinicalLabRequestCatalogKind? editingKind;
  final bool facilityOfferingsOnly;

  @override
  State<ClinicalLabRequestCatalogDialog> createState() =>
      _ClinicalLabRequestCatalogDialogState();
}

class _ClinicalLabRequestCatalogDialogState
    extends State<ClinicalLabRequestCatalogDialog> {
  static const int _maxVisibleCatalogOptions = 80;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 160);

  Timer? _searchDebounce;
  late ClinicalLabRequestCatalogKind _selectionKind;
  ClinicalCatalogSource _catalogSource = ClinicalCatalogSource.facility;
  String _searchQuery = '';
  int _searchRequest = 0;
  String? _selectedCatalogId;
  List<ClinicalActionCatalogOption> _testCatalogOptions =
      const <ClinicalActionCatalogOption>[];
  List<ClinicalActionCatalogOption> _panelCatalogOptions =
      const <ClinicalActionCatalogOption>[];
  List<ClinicalActionCatalogOption> _favoriteTestOptions =
      const <ClinicalActionCatalogOption>[];
  bool _isSearching = false;

  bool get _isEditing => widget.editingOption != null;

  @override
  void initState() {
    super.initState();
    _selectionKind = widget.editingKind ?? widget.initialKind;
    _selectedCatalogId = widget.editingOption?.apiId;
    _searchQuery = widget.editingOption?.displayTitle ?? '';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<ClinicalActionCatalogOption> catalog = _catalogForSelection();
    final List<ClinicalActionCatalogOption> visibleOptions = _searchCatalog(
      catalog,
    );
    final ClinicalActionCatalogOption? selectedOption =
        clinicalActionCatalogOptionById(visibleOptions, _selectedCatalogId);
    final bool selectedIsDuplicate =
        selectedOption != null &&
        widget.isDuplicate(selectedOption, _selectionKind);
    final List<AppSelectOption<String>> selectOptions =
        clinicalCatalogSelectOptions(
          visibleOptions,
          icon: _selectionKind == ClinicalLabRequestCatalogKind.tests
              ? Icons.science_outlined
              : Icons.inventory_2_outlined,
        );

    return AppDialog(
      title: Text(l10n.clinicalLabRequestCatalogPickerTitle),
      icon: const Icon(Icons.manage_search_outlined),
      maxWidth: 640,
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
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
                _selectedCatalogId = null;
              });
              _searchRequest += 1;
              if (values.first == ClinicalLabRequestCatalogKind.tests) {
                unawaited(_loadTestCatalog(_searchQuery, _searchRequest));
                return;
              }
              unawaited(_loadPanelCatalog(_searchQuery, _searchRequest));
            },
          ),
          if (_selectionKind == ClinicalLabRequestCatalogKind.tests &&
              !widget.facilityOfferingsOnly) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            ClinicalCatalogLayerSelector(
              value: _catalogSource,
              onChanged: (ClinicalCatalogSource source) {
                setState(() {
                  _catalogSource = source;
                  _selectedCatalogId = null;
                });
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
                      onPressed: () => _handleAdd(option),
                    ),
                ],
              ),
            ],
          ],
          SizedBox(height: theme.spacing.md),
          ClinicalCatalogSelectPanel(
            title: l10n.clinicalLabRequestMatchesLabel(
              visibleOptions.length,
              visibleOptions.length,
            ),
            body: selectOptions.isEmpty
                ? l10n.clinicalLabRequestNoCatalogOptions
                : l10n.clinicalLabRequestSearchHint,
            labelText: l10n.clinicalLabRequestSearchLabel,
            hintText: l10n.clinicalLabRequestSearchHint,
            options: selectOptions,
            value: _selectedCatalogId,
            isLoading: _isSearching,
            isEditing: _isEditing,
            selectedIsDuplicate: selectedIsDuplicate,
            duplicateMessage: l10n.clinicalRadiologyDuplicateSelectionMessage,
            onChanged: (String? value) {
              setState(() => _selectedCatalogId = value);
            },
            onSearchTextChanged: _scheduleSearch,
            onAdd: selectedOption == null || selectedIsDuplicate
                ? null
                : () => _handleAdd(selectedOption),
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

  void _handleAdd(ClinicalActionCatalogOption option) {
    widget.onAdd(option, _selectionKind);
    if (_isEditing) {
      Navigator.of(context).pop();
    } else {
      setState(() => _selectedCatalogId = null);
    }
  }

  List<ClinicalActionCatalogOption> _catalogForSelection() {
    return switch (_selectionKind) {
      ClinicalLabRequestCatalogKind.tests =>
        _testCatalogOptions.isNotEmpty
            ? _testCatalogOptions
            : const <ClinicalActionCatalogOption>[],
      ClinicalLabRequestCatalogKind.panels =>
        _panelCatalogOptions.isNotEmpty
            ? _panelCatalogOptions
            : const <ClinicalActionCatalogOption>[],
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

  List<ClinicalActionCatalogOption> _searchCatalog(
    List<ClinicalActionCatalogOption> catalog,
  ) {
    return catalog.take(_maxVisibleCatalogOptions).toList(growable: false);
  }

  void _scheduleSearch(String value) {
    setState(() {
      _searchQuery = value.trim();
      _selectedCatalogId = null;
    });
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
