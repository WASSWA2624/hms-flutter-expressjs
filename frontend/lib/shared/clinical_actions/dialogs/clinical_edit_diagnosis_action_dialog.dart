import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Edits diagnosis type for one or more encounter diagnoses.
class ClinicalEditDiagnosisActionDialog extends StatefulWidget {
  const ClinicalEditDiagnosisActionDialog({
    required this.diagnoses,
    required this.onSubmit,
    super.key,
  });

  final List<ClinicalRelatedRecord> diagnoses;
  final Future<AppFailure?> Function({
    required List<ClinicalRelatedRecord> diagnoses,
    required String diagnosisType,
  })
  onSubmit;

  @override
  State<ClinicalEditDiagnosisActionDialog> createState() =>
      _ClinicalEditDiagnosisActionDialogState();
}

class _ClinicalEditDiagnosisActionDialogState
    extends State<ClinicalEditDiagnosisActionDialog> {
  static const List<String> _diagnosisTypes = <String>[
    'PRIMARY',
    'SECONDARY',
    'DIFFERENTIAL',
  ];

  late String _diagnosisType;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final String? sharedType = _sharedDiagnosisType(widget.diagnoses);
    _diagnosisType = sharedType ?? 'PRIMARY';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool wideLayout =
        AppBreakpoints.of(context).index >= AppBreakpoint.md.index;

    return AppDialog(
      title: Text(l10n.clinicalEditDiagnosisDialogTitle),
      icon: const Icon(Icons.rule_outlined),
      maxWidth: 560,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          Text(
            l10n.clinicalEditDiagnosisSelectionCount(widget.diagnoses.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          ...widget.diagnoses.map((ClinicalRelatedRecord diagnosis) {
            return Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.xs),
              child: Text(
                formatClinicalDiagnosisDisplay(diagnosis),
                style: theme.textTheme.bodyLarge,
              ),
            );
          }),
          SizedBox(height: theme.spacing.md),
          AppRadioGroup<String>(
            value: _diagnosisType,
            semanticLabel: l10n.opdDiagnosisTypeLabel,
            enabled: !_isSaving,
            dense: true,
            presentation: AppRadioGroupPresentation.borderless,
            layout: wideLayout
                ? AppRadioGroupLayout.horizontal
                : AppRadioGroupLayout.wrap,
            options: <AppRadioOption<String>>[
              for (final String type in _diagnosisTypes)
                AppRadioOption<String>(
                  value: type,
                  label: clinicalActionApiLabel(type),
                ),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _diagnosisType = value);
            },
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
          label: l10n.commonSaveActionLabel,
          isLoading: _isSaving,
          enabled: !_isSaving && widget.diagnoses.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      diagnoses: widget.diagnoses,
      diagnosisType: _diagnosisType,
    );
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

  String? _sharedDiagnosisType(List<ClinicalRelatedRecord> diagnoses) {
    final Set<String> types = diagnoses
        .map((ClinicalRelatedRecord item) => item.diagnosisType?.trim().toUpperCase() ?? '')
        .where((String value) => value.isNotEmpty)
        .toSet();
    if (types.length == 1) {
      return types.first;
    }
    return null;
  }
}

/// Formats a diagnosis row as `Name - Primary | CODE`.
String formatClinicalDiagnosisDisplay(ClinicalRelatedRecord diagnosis) {
  final String name = (diagnosis.title ?? '').trim();
  final String type = clinicalActionApiLabel(diagnosis.diagnosisType ?? '');
  final String code = (diagnosis.code ?? '').trim();
  final StringBuffer buffer = StringBuffer(name.isEmpty ? '—' : name);
  if (type.isNotEmpty) {
    buffer.write(' - $type');
  }
  if (code.isNotEmpty) {
    buffer.write(' | $code');
  }
  return buffer.toString();
}

/// Dedup key for encounter uniqueness (code + description).
String clinicalDiagnosisDedupKey({
  required String? code,
  required String? description,
  String? fallbackId,
}) {
  final String normalizedCode = (code ?? '').trim().toUpperCase();
  final String normalizedTitle = (description ?? '').trim().toUpperCase();
  if (normalizedCode.isNotEmpty || normalizedTitle.isNotEmpty) {
    return '$normalizedCode::$normalizedTitle';
  }
  return (fallbackId ?? '').trim().toUpperCase();
}
