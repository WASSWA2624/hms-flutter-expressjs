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

class NursingTransferDialog extends ConsumerStatefulWidget {
  const NursingTransferDialog({required this.detail, super.key});

  final NursingPatientDetail detail;

  @override
  ConsumerState<NursingTransferDialog> createState() =>
      _NursingTransferDialogState();
}

class _NursingTransferDialogState extends ConsumerState<NursingTransferDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _bedController;
  late String _action;
  bool _confirm = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _bedController = TextEditingController();
    _action = nursingDefaultTransferAction(
      widget.detail.activeTransfer?.status,
    );
  }

  @override
  void dispose() {
    _bedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.nursingActionAcknowledgeTransfer),
      icon: const Icon(Icons.transfer_within_a_station_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppSelectField<String>(
              value: _action,
              labelText: l10n.nursingTransferActionLabel,
              enabled: !_isSaving,
              options: nursingStatusOptions(nursingTransferActions),
              onChanged: (String? value) =>
                  setState(() => _action = value ?? _action),
            ),
            if (_action == 'COMPLETE')
              AppTextField(
                controller: _bedController,
                labelText: l10n.nursingToBedLabel,
                enabled: !_isSaving,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
            AppCheckboxField(
              title: l10n.nursingConfirmTransferLabel,
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
        submitLabel: l10n.nursingActionAcknowledgeTransfer,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(nursingWorkspaceControllerProvider.notifier)
        .updateTransfer(action: _action, toBedId: _bedController.text.trim());
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
