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
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalProcedureActionDialog extends StatefulWidget {
  const ClinicalProcedureActionDialog({
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
    required List<ClinicalActionCatalogOption> procedures,
    DateTime? performedAt,
  })
  onSubmit;

  @override
  State<ClinicalProcedureActionDialog> createState() => _ProcedureDialogState();
}

class _ProcedureDialogState extends State<ClinicalProcedureActionDialog> {
  static const int _searchLimit = 80;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 160);
  static const double _menuHeight = 360;

  Timer? _searchDebounce;
  int _searchRequest = 0;
  ClinicalCatalogSource _catalogSource = ClinicalCatalogSource.all;
  List<ClinicalActionCatalogOption> _catalogOptions =
      const <ClinicalActionCatalogOption>[];
  final List<ClinicalActionCatalogOption> _selectedProcedures =
      <ClinicalActionCatalogOption>[];
  ClinicalActionCatalogOption? _activeProcedure;
  bool _isSearching = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _searchRequest += 1;
    unawaited(_loadProcedureCatalog('', _searchRequest));
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
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalActionCatalogOption> options = _catalogWithActive();
    final ClinicalActionCatalogOption? activeProcedure = _activeProcedure;
    final String? activeProcedureKey = activeProcedure == null
        ? null
        : _procedureDedupKey(activeProcedure);
    final bool activeAlreadySelected =
        activeProcedureKey != null &&
        _selectedProcedures.any(
          (ClinicalActionCatalogOption item) =>
              _procedureDedupKey(item) == activeProcedureKey,
        );
    final bool canAddSelection =
        activeProcedure != null && !_isSaving && !activeAlreadySelected;
    return AppDialog(
      title: Text(l10n.clinicalRequestProcedureAction),
      icon: const Icon(Icons.healing_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 760,
      content: AppFormSection(
        title: l10n.clinicalProcedureSelectedTitle,
        density: AppFormSectionDensity.spacious,
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.manage_search_outlined,
                    color: colorScheme.primary,
                    size: theme.appTokens.listIconSize,
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      l10n.clinicalProcedureDialogHelp,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClinicalCatalogLayerSelector(
            value: _catalogSource,
            enabled: !_isSaving,
            onChanged: (ClinicalCatalogSource source) {
              setState(() => _catalogSource = source);
              _searchRequest += 1;
              unawaited(_loadProcedureCatalog('', _searchRequest));
            },
          ),
          AppResponsiveFieldRow(
            gap: AppResponsiveFieldRowGap.form,
            children: <Widget>[
              AppSelectField<String>.searchable(
                value: _activeProcedure?.apiId,
                labelText: l10n.clinicalProcedureSearchLabel,
                hintText: l10n.clinicalProcedureSearchHint,
                enabled: !_isSaving,
                menuHeight: _menuHeight,
                options: _procedureNameOptions(options),
                onSearchTextChanged: _scheduleProcedureSearch,
                onChanged: _selectProcedureByApiId,
              ),
              AppSelectField<String>.searchable(
                value: _activeProcedure?.apiId,
                labelText: l10n.opdProcedureCodeLabel,
                hintText: l10n.clinicalProcedureCodeSearchHint,
                enabled: !_isSaving,
                menuHeight: _menuHeight,
                options: _procedureCodeOptions(options),
                onSearchTextChanged: _scheduleProcedureSearch,
                onChanged: _selectProcedureByApiId,
              ),
            ],
          ),
          if (_isSearching) const LinearProgressIndicator(),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.secondary(
              label: l10n.clinicalLabRequestAddSelectionAction,
              leadingIcon: Icons.add,
              enabled: canAddSelection,
              onPressed: _addActiveProcedure,
            ),
          ),
          _ProcedureSelectedPanel(
            procedures: _selectedProcedures,
            isSaving: _isSaving,
            onDelete: _removeProcedure,
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
          label: l10n.clinicalRequestProcedureAction,
          isLoading: _isSaving,
          enabled: _selectedProcedures.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  List<AppSelectOption<String>> _procedureNameOptions(
    List<ClinicalActionCatalogOption> options,
  ) {
    return <AppSelectOption<String>>[
      for (final ClinicalActionCatalogOption option in options)
        AppSelectOption<String>(
          value: option.apiId,
          label: _procedureTitle(option),
          labelWidget: _ProcedureOptionLabel(
            title: _procedureTitle(option),
            subtitle: _procedureSubtitle(option),
          ),
          leadingIcon: const Icon(Icons.healing_outlined),
        ),
    ];
  }

  List<AppSelectOption<String>> _procedureCodeOptions(
    List<ClinicalActionCatalogOption> options,
  ) {
    return <AppSelectOption<String>>[
      for (final ClinicalActionCatalogOption option in options)
        AppSelectOption<String>(
          value: option.apiId,
          label: _procedureCodeLabel(option),
          labelWidget: _ProcedureOptionLabel(
            title: _procedureCodeLabel(option),
            subtitle: clinicalActionJoinDisplay(<String?>[
              _procedureTitle(option),
              option.displaySubtitle,
            ]),
          ),
          leadingIcon: const Icon(Icons.tag_outlined),
        ),
    ];
  }

  void _scheduleProcedureSearch(String value) {
    final String query = value.trim();
    _searchDebounce?.cancel();
    _searchRequest += 1;
    final int requestId = _searchRequest;
    _searchDebounce = Timer(
      _searchDebounceDuration,
      () => _loadProcedureCatalog(query, requestId),
    );
  }

  Future<void> _loadProcedureCatalog(String query, int requestId) async {
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    setState(() => _isSearching = true);
    final Result<List<ClinicalActionCatalogOption>> result = await widget
        .onSearchClinicalTerms(
          termType: 'PROCEDURE',
          query: query,
          limit: _searchLimit,
          source: _catalogSource.apiValue,
        );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    setState(() {
      _catalogOptions = result.when(
        success: _dedupeProcedureOptions,
        failure: (_) => const <ClinicalActionCatalogOption>[],
      );
      _failure = result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      _isSearching = false;
    });
  }

  void _selectProcedureByApiId(String? value) {
    if (value == null) {
      setState(() {
        _activeProcedure = null;
        _failure = null;
      });
      return;
    }

    final ClinicalActionCatalogOption? procedure = _findProcedure(value);
    if (procedure == null) {
      return;
    }
    setState(() {
      _activeProcedure = procedure;
      _catalogOptions = clinicalActionMergeCatalogOption(
        _catalogOptions,
        procedure,
      );
      _failure = null;
    });
  }

  ClinicalActionCatalogOption? _findProcedure(String apiId) {
    for (final ClinicalActionCatalogOption option in _catalogWithActive()) {
      if (option.apiId == apiId) {
        return option;
      }
    }
    return null;
  }

  List<ClinicalActionCatalogOption> _catalogWithActive() {
    final ClinicalActionCatalogOption? active = _activeProcedure;
    if (active == null) {
      return _catalogOptions;
    }
    return clinicalActionMergeCatalogOption(_catalogOptions, active);
  }

  void _addActiveProcedure() {
    final ClinicalActionCatalogOption? procedure = _activeProcedure;
    if (procedure == null) {
      return;
    }
    if (_selectedProcedures.any(
      (ClinicalActionCatalogOption item) =>
          _procedureDedupKey(item) == _procedureDedupKey(procedure),
    )) {
      setState(() {
        _activeProcedure = null;
        _failure = null;
      });
      return;
    }

    setState(() {
      _selectedProcedures.add(procedure);
      _activeProcedure = null;
      _failure = null;
    });
  }

  void _removeProcedure(int index) {
    if (index < 0 || index >= _selectedProcedures.length) {
      return;
    }
    setState(() {
      _selectedProcedures.removeAt(index);
      _failure = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedProcedures.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      procedures: List<ClinicalActionCatalogOption>.unmodifiable(
        _selectedProcedures,
      ),
      performedAt: DateTime.now(),
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

class _ProcedureOptionLabel extends StatelessWidget {
  const _ProcedureOptionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
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

class _ProcedureSelectedPanel extends StatelessWidget {
  const _ProcedureSelectedPanel({
    required this.procedures,
    required this.isSaving,
    required this.onDelete,
  });

  final List<ClinicalActionCatalogOption> procedures;
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
                    l10n.clinicalProcedureSelectedTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  l10n.clinicalProcedureSelectedCount(procedures.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: procedures.isEmpty
                ? SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(l10n.clinicalProcedureNoSelection),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: procedures.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      return _ProcedureSelectedRow(
                        procedure: procedures[index],
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

class _ProcedureSelectedRow extends StatelessWidget {
  const _ProcedureSelectedRow({
    required this.procedure,
    required this.isSaving,
    required this.onDelete,
  });

  final ClinicalActionCatalogOption procedure;
  final bool isSaving;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String subtitle = clinicalActionJoinDisplay(<String?>[
      clinicalActionTrimmedOrNull(procedure.code),
      procedure.displaySubtitle,
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.healing_outlined,
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
                  _procedureTitle(procedure),
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

List<ClinicalActionCatalogOption> _dedupeProcedureOptions(
  List<ClinicalActionCatalogOption> options,
) {
  final Set<String> seen = <String>{};
  final List<ClinicalActionCatalogOption> deduped =
      <ClinicalActionCatalogOption>[];
  for (final ClinicalActionCatalogOption option in options) {
    final String key = _procedureDedupKey(option);
    if (seen.add(key)) {
      deduped.add(option);
    }
  }
  return deduped;
}

String _procedureTitle(ClinicalActionCatalogOption option) {
  return clinicalActionTrimmedOrNull(option.name) ?? option.displayTitle;
}

String _procedureCodeLabel(ClinicalActionCatalogOption option) {
  return clinicalActionTrimmedOrNull(option.code) ?? option.displayTitle;
}

String _procedureSubtitle(ClinicalActionCatalogOption option) {
  return clinicalActionJoinDisplay(<String?>[
    option.code,
    option.displaySubtitle,
  ]);
}

String _procedureDedupKey(ClinicalActionCatalogOption option) {
  final String code =
      clinicalActionTrimmedOrNull(option.code)?.toUpperCase() ?? '';
  final String title = _procedureTitle(option).toUpperCase();
  if (code.isNotEmpty || title.isNotEmpty) {
    return '$code::$title';
  }
  return clinicalActionTrimmedOrNull(option.apiId)?.toUpperCase() ?? '';
}
