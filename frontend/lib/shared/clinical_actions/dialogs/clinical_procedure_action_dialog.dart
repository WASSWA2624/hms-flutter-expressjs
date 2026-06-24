import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_procedure_catalog_dialog.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';

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
  final List<ClinicalActionCatalogOption> _selectedProcedures =
      <ClinicalActionCatalogOption>[];
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return AppDialog(
      title: Text(l10n.clinicalRequestProcedureAction),
      icon: const Icon(Icons.healing_outlined),
      closeEnabled: !_isSaving,
      maxWidth: 560,
      content: SizedBox(
        height: (MediaQuery.sizeOf(context).height * 0.45).clamp(320.0, 480.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            Text(
              l10n.clinicalRequestMainPanelHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.md),
            ClinicalRequestFlowToolbar(
              enabled: !_isSaving,
              showBillingAction: false,
              onAddItems: _openCatalogPicker,
            ),
            SizedBox(height: theme.spacing.md),
            Expanded(
              child: _ProcedureSelectedPanel(
                procedures: _selectedProcedures,
                isSaving: _isSaving,
                onDelete: _removeProcedure,
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
          label: l10n.clinicalRequestProcedureAction,
          isLoading: _isSaving,
          enabled: _selectedProcedures.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _openCatalogPicker() async {
    await showClinicalProcedureCatalogDialog(
      context: context,
      onSearchClinicalTerms: widget.onSearchClinicalTerms,
      isDuplicate: (ClinicalActionCatalogOption option) =>
          _selectedProcedures.any(
            (ClinicalActionCatalogOption item) =>
                _procedureDedupKey(item) == _procedureDedupKey(option),
          ),
      onAdd: (ClinicalActionCatalogOption procedure) {
        setState(() {
          _selectedProcedures.add(procedure);
          _failure = null;
        });
      },
    );
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
          Expanded(
            child: procedures.isEmpty
                ? Center(child: Text(l10n.clinicalProcedureNoSelection))
                : ListView.separated(
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

String _procedureTitle(ClinicalActionCatalogOption option) {
  return clinicalActionTrimmedOrNull(option.name) ?? option.displayTitle;
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
