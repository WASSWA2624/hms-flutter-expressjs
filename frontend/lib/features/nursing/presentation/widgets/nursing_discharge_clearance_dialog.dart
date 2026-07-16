import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class NursingDischargeClearanceDialog extends ConsumerStatefulWidget {
  const NursingDischargeClearanceDialog({required this.detail, super.key});

  final NursingPatientDetail detail;

  @override
  ConsumerState<NursingDischargeClearanceDialog> createState() =>
      _NursingDischargeClearanceDialogState();
}

class _NursingDischargeClearanceDialogState
    extends ConsumerState<NursingDischargeClearanceDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  final Map<String, bool> _checks = <String, bool>{
    'medication_education': false,
    'wound_care': false,
    'follow_up': false,
    'belongings_returned': false,
    'identity_band_removed': false,
  };
  bool _confirm = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.nursingDischargeClearanceTitle),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      maxWidth: 640,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            Text(
              l10n.nursingDischargeClearanceDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            for (final MapEntry<String, String> entry in _clearanceLabels(
              l10n,
            ).entries)
              AppCheckboxField(
                title: entry.value,
                value: _checks[entry.key] ?? false,
                enabled: !_isSaving,
                onChanged: (bool value) =>
                    setState(() => _checks[entry.key] = value),
              ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.nursingDischargeClearanceNotesLabel,
              enabled: !_isSaving,
              maxLines: 4,
            ),
            AppCheckboxField(
              title: l10n.nursingDischargeClearanceConfirmLabel,
              value: _confirm,
              enabled: !_isSaving,
              validator: (bool? value) =>
                  value == true ? null : l10n.validationRequired,
              onChanged: (bool value) => setState(() => _confirm = value),
            ),
          ],
        ),
      ),
      actions: nursingDialogActions(
        context,
        submitLabel: l10n.nursingActionDischargeClearance,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Map<String, String> _clearanceLabels(AppLocalizations l10n) {
    return <String, String>{
      'medication_education': l10n.nursingClearanceMedicationEducationLabel,
      'wound_care': l10n.nursingClearanceWoundCareLabel,
      'follow_up': l10n.nursingClearanceFollowUpLabel,
      'belongings_returned': l10n.nursingClearanceBelongingsReturnedLabel,
      'identity_band_removed': l10n.nursingClearanceIdentityBandLabel,
    };
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final Map<String, String> labels = _clearanceLabels(l10n);
    final List<String> completed = <String>[
      for (final MapEntry<String, bool> entry in _checks.entries)
        if (entry.value) labels[entry.key] ?? entry.key,
    ];
    if (completed.isEmpty) {
      setState(
        () => _failure = AppFailure.validation(
          validationFields: const <String>{'clearance'},
        ),
      );
      return;
    }
    final String notes = _notesController.text.trim();
    final String body = <String>[
      completed.join(', '),
      if (notes.isNotEmpty) notes,
    ].join(' - ');

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(nursingWorkspaceControllerProvider.notifier)
        .recordDischargeClearance(body);
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
