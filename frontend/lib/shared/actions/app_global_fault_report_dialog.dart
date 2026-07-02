import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/presentation/controllers/biomedical_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

Future<void> showAppGlobalFaultReportDialog({
  required BuildContext context,
  required WidgetRef ref,
  VoidCallback? onCompleted,
}) async {
  final AsyncValue<Result<BiomedicalWorkspaceState>> workspace = ref.read(
    biomedicalWorkspaceControllerProvider,
  );
  if (workspace.isLoading || workspace.hasError) {
    unawaited(
      ref.read(biomedicalWorkspaceControllerProvider.notifier).refresh(),
    );
  }

  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AppGlobalFaultReportDialog(),
  );

  if (saved == true) {
    onCompleted?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.biomedicalSavedMessage)),
      );
    }
  }
}

class _AppGlobalFaultReportDialog extends ConsumerStatefulWidget {
  const _AppGlobalFaultReportDialog();

  @override
  ConsumerState<_AppGlobalFaultReportDialog> createState() =>
      _AppGlobalFaultReportDialogState();
}

class _AppGlobalFaultReportDialogState
    extends ConsumerState<_AppGlobalFaultReportDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reportedNameController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _facilityId;
  String? _roomId;
  String? _priority;
  String? _severity;
  bool _patientSafetyRisk = false;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _reportedNameController.dispose();
    _symptomsController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Result<BiomedicalWorkspaceState>> workspace = ref.watch(
      biomedicalWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.biomedicalFaultDialogTitle),
      icon: const Icon(Icons.report_problem_outlined),
      scrollable: true,
      closeEnabled: !_isSubmitting,
      content: workspace.when(
        loading: () => AppStateView(
          variant: AppStateViewVariant.loading,
          title: l10n.biomedicalLoadingTitle,
          body: l10n.biomedicalLoadingBody,
        ),
        error: (_, _) => AppStateView(
          variant: AppStateViewVariant.error,
          title: l10n.errorNotFoundTitle,
          body: l10n.errorNotFoundMessage,
          action: AppButton.primary(
            label: l10n.commonRetryActionLabel,
            onPressed: () {
              ref
                  .read(biomedicalWorkspaceControllerProvider.notifier)
                  .refresh();
            },
          ),
        ),
        data: (Result<BiomedicalWorkspaceState> result) {
          return switch (result) {
            ResultFailure<BiomedicalWorkspaceState>() => AppStateView(
              variant: AppStateViewVariant.error,
              title: l10n.errorNotFoundTitle,
              body: l10n.errorNotFoundMessage,
            ),
            ResultSuccess<BiomedicalWorkspaceState>(value: final state) =>
              _buildForm(context, state),
          };
        },
      ),
      actions: _buildActions(context),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return <Widget>[
      AppButton.tertiary(
        label: l10n.commonCancelActionLabel,
        enabled: !_isSubmitting,
        onPressed: _isSubmitting
            ? null
            : () => Navigator.of(context).maybePop(),
      ),
      AppButton.primary(
        label: l10n.biomedicalFaultDialogTitle,
        leadingIcon: Icons.check_outlined,
        isLoading: _isSubmitting,
        onPressed: _isSubmitting ? null : _submit,
      ),
    ];
  }

  Widget _buildForm(BuildContext context, BiomedicalWorkspaceState state) {
    final AppLocalizations l10n = context.l10n;
    final BiomedicalLookupData lookups = state.workbench.lookups;

    return AppFormShell(
      formKey: _formKey,
      enabled: !_isSubmitting,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _facilityId,
          labelText: l10n.biomedicalFacilityLabel,
          options: _lookupOptions(lookups.facilities),
          onChanged: (String? value) => setState(() => _facilityId = value),
        ),
        AppSelectField<String>.searchable(
          value: _roomId,
          labelText: l10n.biomedicalRoomLabel,
          options: _lookupOptions(lookups.rooms),
          onChanged: (String? value) => setState(() => _roomId = value),
        ),
        AppSelectField<String>(
          value: _priority,
          labelText: l10n.biomedicalPriorityLabel,
          options: _lookupOptions(lookups.priorities),
          onChanged: (String? value) => setState(() => _priority = value),
        ),
        AppSelectField<String>(
          value: _severity,
          labelText: l10n.biomedicalSeverityLabel,
          options: _lookupOptions(lookups.priorities),
          onChanged: (String? value) => setState(() => _severity = value),
        ),
        AppTextField(
          controller: _reportedNameController,
          labelText: l10n.biomedicalReportedEquipmentNameLabel,
        ),
        AppTextField(
          controller: _symptomsController,
          labelText: l10n.biomedicalReasonLabel,
          minLines: 2,
          maxLines: 4,
        ),
        AppTextField(
          controller: _descriptionController,
          labelText: l10n.biomedicalDescriptionLabel,
          minLines: 3,
          maxLines: 5,
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.biomedicalNotesLabel,
          minLines: 2,
          maxLines: 4,
        ),
        AppCheckboxField(
          title: l10n.biomedicalPatientSafetyRiskLabel,
          value: _patientSafetyRisk,
          onChanged: (bool value) {
            setState(() => _patientSafetyRisk = value);
          },
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(biomedicalWorkspaceControllerProvider.notifier)
        .createFaultReport(<String, Object?>{
          if (_facilityId != null) 'facility_id': _facilityId,
          if (_roomId != null) 'room_id': _roomId,
          if (_priority != null) 'priority': _priority,
          if (_severity != null) 'severity': _severity,
          'reported_equipment_name': _reportedNameController.text.trim(),
          'symptoms': _symptomsController.text.trim(),
          'description': _descriptionController.text.trim(),
          'notes': _notesController.text.trim(),
          'patient_safety_risk': _patientSafetyRisk,
          'source_scope': 'global',
          'source_route': ModalRoute.of(context)?.settings.name,
        });

    if (!mounted) {
      return;
    }

    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

List<AppSelectOption<String>> _lookupOptions(
  List<BiomedicalLookupOption> options,
) {
  return <AppSelectOption<String>>[
    for (final BiomedicalLookupOption option in options)
      AppSelectOption<String>(value: option.id, label: option.displayLabel),
  ];
}
