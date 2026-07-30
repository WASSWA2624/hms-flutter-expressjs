import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_panel.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_feedback.dart';

/// Nursing note + optional nursing service charge via clinical-request-billing.
///
/// Dialog chrome is the only titled shell; [ClinicalRequestBillingPanel] stays
/// `embedded: true` so sections remain flat. Posts through IPD
/// `add-nursing-note` → `persistNursingServiceBilling`.
class NursingNoteDialog extends ConsumerStatefulWidget {
  const NursingNoteDialog({super.key});

  @override
  ConsumerState<NursingNoteDialog> createState() => _NursingNoteDialogState();
}

class _NursingNoteDialogState extends ConsumerState<NursingNoteDialog> {
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
        .read(nursingWorkspaceControllerProvider.notifier)
        .addNursingNote(
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
      title: Text(l10n.nursingActionAddNote),
      icon: const Icon(Icons.note_add_outlined),
      maxWidth: 560,
      scrollable: true,
      closeEnabled: !_submitting,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _notesController,
            labelText: l10n.nursingNoteLabel,
            minLines: 3,
            maxLines: 8,
            enabled: !_submitting,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppAccessGate(
            requirement: NursingAllAtomPermissions.billingPanel,
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
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_submitting,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.nursingActionAddNote,
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
