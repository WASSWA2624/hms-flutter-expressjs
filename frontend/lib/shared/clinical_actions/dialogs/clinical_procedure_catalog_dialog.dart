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
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

Future<void> showClinicalProcedureCatalogDialog({
  required BuildContext context,
  required Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })
  onSearchClinicalTerms,
  required ValueChanged<ClinicalActionCatalogOption> onAdd,
  required bool Function(ClinicalActionCatalogOption option) isDuplicate,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext context) => ClinicalProcedureCatalogDialog(
      onSearchClinicalTerms: onSearchClinicalTerms,
      onAdd: onAdd,
      isDuplicate: isDuplicate,
    ),
  );
}

class ClinicalProcedureCatalogDialog extends StatefulWidget {
  const ClinicalProcedureCatalogDialog({
    required this.onSearchClinicalTerms,
    required this.onAdd,
    required this.isDuplicate,
    super.key,
  });

  final Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })
  onSearchClinicalTerms;
  final ValueChanged<ClinicalActionCatalogOption> onAdd;
  final bool Function(ClinicalActionCatalogOption option) isDuplicate;

  @override
  State<ClinicalProcedureCatalogDialog> createState() =>
      _ClinicalProcedureCatalogDialogState();
}

class _ClinicalProcedureCatalogDialogState
    extends State<ClinicalProcedureCatalogDialog> {
  static const int _searchLimit = 80;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 160);
  static const double _menuHeight = 360;

  Timer? _searchDebounce;
  int _searchRequest = 0;
  ClinicalCatalogSource _catalogSource = ClinicalCatalogSource.all;
  List<ClinicalActionCatalogOption> _catalogOptions =
      const <ClinicalActionCatalogOption>[];
  ClinicalActionCatalogOption? _activeProcedure;
  bool _isSearching = false;
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
        activeProcedureKey != null && widget.isDuplicate(activeProcedure!);

    return AppDialog(
      title: Text(l10n.clinicalProcedureCatalogPickerTitle),
      icon: const Icon(Icons.manage_search_outlined),
      maxWidth: 720,
      scrollable: true,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          Text(
            l10n.clinicalProcedureDialogHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          ClinicalCatalogLayerSelector(
            value: _catalogSource,
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
                menuHeight: _menuHeight,
                options: _procedureNameOptions(options),
                onSearchTextChanged: _scheduleProcedureSearch,
                onChanged: _selectProcedureByApiId,
              ),
              AppSelectField<String>.searchable(
                value: _activeProcedure?.apiId,
                labelText: l10n.opdProcedureCodeLabel,
                hintText: l10n.clinicalProcedureCodeSearchHint,
                menuHeight: _menuHeight,
                options: _procedureCodeOptions(options),
                onSearchTextChanged: _scheduleProcedureSearch,
                onChanged: _selectProcedureByApiId,
              ),
            ],
          ),
          if (_isSearching) const LinearProgressIndicator(),
          if (activeProcedure != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            _ProcedurePreviewCard(procedure: activeProcedure),
          ],
          if (activeAlreadySelected) ...<Widget>[
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
      actions: <Widget>[
        AppButton.primary(
          label: l10n.clinicalLabRequestAddSelectionAction,
          leadingIcon: Icons.add,
          enabled: activeProcedure != null && !activeAlreadySelected,
          onPressed: activeProcedure == null || activeAlreadySelected
              ? null
              : () {
                  widget.onAdd(activeProcedure);
                  setState(() => _activeProcedure = null);
                },
        ),
        AppButton.secondary(
          label: l10n.clinicalRequestCatalogPickerDoneAction,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  List<ClinicalActionCatalogOption> _catalogWithActive() {
    final ClinicalActionCatalogOption? active = _activeProcedure;
    if (active == null) {
      return _catalogOptions;
    }
    return clinicalActionMergeCatalogOption(_catalogOptions, active);
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
}

class _ProcedurePreviewCard extends StatelessWidget {
  const _ProcedurePreviewCard({required this.procedure});

  final ClinicalActionCatalogOption procedure;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: theme.borders.all(),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: AppFontWeight.medium,
                    ),
                  ),
                  if (_procedureSubtitle(procedure).isNotEmpty)
                    Text(
                      _procedureSubtitle(procedure),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            fontWeight: AppFontWeight.medium,
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
  return option.displayTitle;
}

String _procedureCodeLabel(ClinicalActionCatalogOption option) {
  return option.code ?? option.apiId;
}

String _procedureSubtitle(ClinicalActionCatalogOption option) {
  return clinicalActionJoinDisplay(<String?>[
    option.code,
    option.displaySubtitle,
  ]);
}

String _procedureDedupKey(ClinicalActionCatalogOption option) {
  return clinicalActionJoinDisplay(<String?>[
    option.apiId,
    option.code,
    option.name,
  ]);
}
