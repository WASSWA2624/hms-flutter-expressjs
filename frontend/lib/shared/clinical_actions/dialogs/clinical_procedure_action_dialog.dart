import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_select_helpers.dart';
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
  String? _focusedProcedureId;
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
            if (_failure != null) AppFormInformationBanner.failure(context: context, failure: _failure!),
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
            Expanded(child: _buildSelectedPanel(context)),
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

  Widget _buildSelectedPanel(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalActionCatalogOption? focusedProcedure = _focusedProcedure();

    return ClinicalRequestSelectionManager(
      title: l10n.clinicalProcedureSelectedTitle,
      emptyLabel: l10n.clinicalProcedureNoSelection,
      options: clinicalCatalogSelectOptions(
        _selectedProcedures,
        icon: Icons.healing_outlined,
        labelBuilder: (ClinicalActionCatalogOption procedure) {
          return ClinicalCatalogOptionLabel(
            option: procedure,
            title: _procedureTitle(procedure),
            subtitle: clinicalActionJoinDisplay(<String?>[
              clinicalActionTrimmedOrNull(procedure.code),
              procedure.displaySubtitle,
            ]),
          );
        },
      ),
      value: _focusedProcedureId,
      enabled: !_isSaving,
      onChanged: (String? value) {
        setState(() => _focusedProcedureId = value);
      },
      onEdit: null,
      onDelete: focusedProcedure == null
          ? null
          : () => _removeProcedure(_procedureIndex(focusedProcedure)),
    );
  }

  ClinicalActionCatalogOption? _focusedProcedure() {
    if (_focusedProcedureId == null) {
      return null;
    }
    for (final ClinicalActionCatalogOption procedure in _selectedProcedures) {
      if (procedure.apiId == _focusedProcedureId) {
        return procedure;
      }
    }
    return null;
  }

  int _procedureIndex(ClinicalActionCatalogOption procedure) {
    return _selectedProcedures.indexWhere(
      (ClinicalActionCatalogOption item) => item.apiId == procedure.apiId,
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
    final String removedId = _selectedProcedures[index].apiId;
    setState(() {
      _selectedProcedures.removeAt(index);
      if (_focusedProcedureId == removedId) {
        _focusedProcedureId = null;
      }
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
