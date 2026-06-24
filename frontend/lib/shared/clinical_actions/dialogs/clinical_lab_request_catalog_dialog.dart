import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_layer_selector.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
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
  required bool Function(ClinicalActionCatalogOption option, ClinicalLabRequestCatalogKind kind)
  isDuplicate,
  ClinicalLabRequestCatalogKind initialKind = ClinicalLabRequestCatalogKind.tests,
  ClinicalActionCatalogOption? editingOption,
  ClinicalLabRequestCatalogKind? editingKind,
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

  @override
  State<ClinicalLabRequestCatalogDialog> createState() =>
      _ClinicalLabRequestCatalogDialogState();
}

class _ClinicalLabRequestCatalogDialogState
    extends State<ClinicalLabRequestCatalogDialog> {
  static const int _maxVisibleCatalogOptions = 80;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 160);

  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  late ClinicalLabRequestCatalogKind _selectionKind;
  ClinicalCatalogSource _catalogSource = ClinicalCatalogSource.all;
  String _searchQuery = '';
  int _searchRequest = 0;
  List<ClinicalActionCatalogOption> _testCatalogOptions =
      const <ClinicalActionCatalogOption>[];
  List<ClinicalActionCatalogOption> _favoriteTestOptions =
      const <ClinicalActionCatalogOption>[];
  bool _isSearching = false;

  bool get _isEditing => widget.editingOption != null;

  @override
  void initState() {
    super.initState();
    _selectionKind = widget.editingKind ?? widget.initialKind;
    _searchController = TextEditingController(
      text: widget.editingOption?.displayTitle ?? '',
    );
    _searchQuery = _searchController.text.trim();
    _searchRequest += 1;
    unawaited(_loadTestCatalog(_searchQuery, _searchRequest));
    unawaited(_loadFavoriteTests());
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
    final double bodyHeight = (MediaQuery.sizeOf(context).height * 0.62)
        .clamp(400.0, 600.0)
        .toDouble();
    final List<ClinicalActionCatalogOption> catalog = _catalogForSelection();
    final _LabCatalogSearchResults searchResults = _searchCatalog(catalog);

    return AppDialog(
      title: Text(l10n.clinicalLabRequestCatalogPickerTitle),
      icon: const Icon(Icons.manage_search_outlined),
      maxWidth: 720,
      content: SizedBox(
        height: bodyHeight,
        child: Column(
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
                setState(() => _selectionKind = values.first);
                if (values.first == ClinicalLabRequestCatalogKind.tests) {
                  _searchRequest += 1;
                  unawaited(_loadTestCatalog(_searchQuery, _searchRequest));
                }
              },
            ),
            if (_selectionKind == ClinicalLabRequestCatalogKind.tests) ...<Widget>[
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
                        onPressed: () => _handleAdd(option),
                      ),
                  ],
                ),
              ],
            ],
            SizedBox(height: theme.spacing.md),
            AppTextField(
              controller: _searchController,
              labelText: l10n.clinicalLabRequestSearchLabel,
              hintText: l10n.clinicalLabRequestSearchHint,
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
                      onPressed: _clearSearch,
                    ),
              onChanged: _scheduleSearch,
            ),
            if (_isSearching &&
                _selectionKind == ClinicalLabRequestCatalogKind.tests) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              const LinearProgressIndicator(),
            ],
            SizedBox(height: theme.spacing.md),
            Expanded(
              child: _LabCatalogResultsPanel(
                results: searchResults,
                kind: _selectionKind,
                isEditing: _isEditing,
                onSelected: _handleAdd,
                isDuplicate: (ClinicalActionCatalogOption option) =>
                    widget.isDuplicate(option, _selectionKind),
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
    widget.onAdd(option, _selectionKind);
    if (_isEditing) {
      Navigator.of(context).pop();
    }
  }

  List<ClinicalActionCatalogOption> _catalogForSelection() {
    return switch (_selectionKind) {
      ClinicalLabRequestCatalogKind.tests =>
        _testCatalogOptions.isNotEmpty
            ? _testCatalogOptions
            : widget.referenceData.labTests,
      ClinicalLabRequestCatalogKind.panels => widget.referenceData.labPanels,
    };
  }

  Future<void> _loadTestCatalog(String query, int requestId) async {
    setState(() => _isSearching = true);
    final Result<List<ClinicalActionCatalogOption>> result =
        await widget.onSearchLabTests(
      termType: ClinicalCatalogTermType.labTest.apiValue,
      query: query.trim().isEmpty ? null : query.trim(),
      limit: _maxVisibleCatalogOptions,
      source: _catalogSource.apiValue,
    );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    setState(() {
      _isSearching = false;
      _testCatalogOptions = result.when(
        success: (List<ClinicalActionCatalogOption> value) => value,
        failure: (_) => widget.referenceData.labTests,
      );
    });
  }

  Future<void> _loadFavoriteTests() async {
    final Result<List<ClinicalActionCatalogOption>> result =
        await widget.onSearchLabTests(
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

  _LabCatalogSearchResults _searchCatalog(
    List<ClinicalActionCatalogOption> catalog,
  ) {
    final List<String> tokens = _searchQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return _LabCatalogSearchResults(
        options: catalog.take(_maxVisibleCatalogOptions).toList(growable: false),
        totalMatches: catalog.length,
      );
    }

    final List<ClinicalActionCatalogOption> visible =
        <ClinicalActionCatalogOption>[];
    var totalMatches = 0;
    for (final ClinicalActionCatalogOption option in catalog) {
      final String searchText = _catalogSearchText(option);
      final bool isMatch = tokens.every(searchText.contains);
      if (!isMatch) {
        continue;
      }
      totalMatches += 1;
      if (visible.length < _maxVisibleCatalogOptions) {
        visible.add(option);
      }
    }

    return _LabCatalogSearchResults(
      options: visible,
      totalMatches: totalMatches,
    );
  }

  String _catalogSearchText(ClinicalActionCatalogOption option) {
    return clinicalActionJoinDisplay(<String?>[
      option.apiId,
      option.displayTitle,
      option.displaySubtitle,
      option.name,
      option.code,
      option.category,
      option.secondaryText,
      option.status,
    ]).toLowerCase();
  }

  void _scheduleSearch(String value) {
    setState(() => _searchQuery = value.trim());
    if (_selectionKind != ClinicalLabRequestCatalogKind.tests) {
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      _searchRequest += 1;
      unawaited(_loadTestCatalog(_searchQuery, _searchRequest));
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }
}

final class _LabCatalogSearchResults {
  const _LabCatalogSearchResults({
    required this.options,
    required this.totalMatches,
  });

  final List<ClinicalActionCatalogOption> options;
  final int totalMatches;
}

class _LabCatalogResultsPanel extends StatelessWidget {
  const _LabCatalogResultsPanel({
    required this.results,
    required this.kind,
    required this.isEditing,
    required this.onSelected,
    required this.isDuplicate,
  });

  final _LabCatalogSearchResults results;
  final ClinicalLabRequestCatalogKind kind;
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
              l10n.clinicalLabRequestMatchesLabel(
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
                ? Center(child: Text(l10n.clinicalLabRequestNoCatalogOptions))
                : ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      final ClinicalActionCatalogOption option = options[index];
                      final bool duplicate = isDuplicate(option);
                      return _LabCatalogOptionRow(
                        option: option,
                        kind: kind,
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

class _LabCatalogOptionRow extends StatelessWidget {
  const _LabCatalogOptionRow({
    required this.option,
    required this.kind,
    required this.isEditing,
    required this.isDuplicate,
    required this.onSelected,
  });

  final ClinicalActionCatalogOption option;
  final ClinicalLabRequestCatalogKind kind;
  final bool isEditing;
  final bool isDuplicate;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String actionLabel = isEditing
        ? l10n.clinicalLabRequestUpdateSelectionAction
        : l10n.clinicalLabRequestAddSelectionAction;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            kind == ClinicalLabRequestCatalogKind.tests
                ? Icons.science_outlined
                : Icons.inventory_2_outlined,
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
                if (option.displaySubtitle != null)
                  Text(
                    option.displaySubtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  clinicalRequestCatalogPriceLabel(context, option),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onSelected,
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
