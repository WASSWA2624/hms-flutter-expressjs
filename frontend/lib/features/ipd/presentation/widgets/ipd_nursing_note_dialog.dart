import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_panel.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_feedback.dart';

/// Opens nursing note dialog with optional Billing panel (flat / embedded).
Future<bool?> showIpdNursingNoteDialog(
  BuildContext context, {
  required IpdAdmissionSummary summary,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => IpdNursingNoteDialog(summary: summary),
  );
}

/// Nursing note + optional nursing service charge via clinical-request-billing.
///
/// Dialog chrome is the only titled shell; [ClinicalRequestBillingPanel] stays
/// `embedded: true` so sections remain flat.
class IpdNursingNoteDialog extends ConsumerStatefulWidget {
  const IpdNursingNoteDialog({required this.summary, super.key});

  final IpdAdmissionSummary summary;

  @override
  ConsumerState<IpdNursingNoteDialog> createState() =>
      _IpdNursingNoteDialogState();
}

class _IpdNursingNoteDialogState extends ConsumerState<IpdNursingNoteDialog> {
  final TextEditingController _notesController = TextEditingController();
  ClinicalRequestBillingSubmit? _billing;
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final String note = _notesController.text.trim();
    if (note.isEmpty) {
      showAppFailureSnackBar(context, AppFailure.validation());
      return;
    }
    setState(() => _submitting = true);
    final ClinicalRequestBillingSubmit? billing = _billing;
    final bool charge =
        billing != null &&
        billing.paymentStatus != ClinicalRequestPaymentStatus.notBilled &&
        billing.totalAmount > 0;
    final AppFailure? failure = await ref
        .read(ipdWorkspaceControllerProvider.notifier)
        .addNursingNote(
          widget.summary,
          note,
          billing: charge ? billing.toPayloadMap() : null,
        );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      showAppFailureSnackBar(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalRequestBillingLineItem> lineItems =
        <ClinicalRequestBillingLineItem>[
          ClinicalRequestBillingLineItem(
            id: 'NURSING_SERVICE',
            label: l10n.ipdNursingSectionTitle,
          ),
        ];

    return AppDialog(
      title: Text(l10n.ipdAddNursingNoteAction),
      icon: const Icon(Icons.note_add_outlined),
      maxWidth: 560,
      scrollable: true,
      closeEnabled: !_submitting,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _notesController,
            labelText: l10n.ipdNotesFieldLabel,
            minLines: 3,
            maxLines: 8,
            enabled: !_submitting,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppAccessGate(
            requirement: ipdBillingPanelReadRequirement,
            child: ClinicalRequestBillingPanel(
              lineItems: lineItems,
              enabled: !_submitting,
              embedded: true,
              onChanged: (ClinicalRequestBillingSubmit value) {
                _billing = value;
              },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.close(
          leadingIcon: AppActionIcons.cancel,
          label: l10n.commonCancelActionLabel,
          enabled: !_submitting,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.ipdAddNursingNoteAction,
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
