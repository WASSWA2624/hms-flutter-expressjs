import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Opens [PrintOpdSummaryDialog] with non-dismissible barrier rules.
///
/// Print/copy are client-side only. The patient-report `print-events` route
/// audits section-based patient clinical reports, not OPD visit summaries, so
/// this path does not call it and never patches Riverpod. Returns `false`
/// after print so parents do not treat the action as a persisted mutation.
Future<bool?> showPrintOpdSummaryDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
  OpdFlowDetail? detail,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PrintOpdSummaryDialog(flow: flow, detail: detail),
  );
}

/// Preview / print / copy an OPD encounter summary (local-only read action).
class PrintOpdSummaryDialog extends ConsumerStatefulWidget {
  const PrintOpdSummaryDialog({
    required this.flow,
    this.detail,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  ConsumerState<PrintOpdSummaryDialog> createState() =>
      _PrintOpdSummaryDialogState();
}

class _PrintOpdSummaryDialogState extends ConsumerState<PrintOpdSummaryDialog> {
  bool _isCopying = false;
  bool _isPrinting = false;
  AppFailure? _failure;

  bool get _isBusy => _isCopying || _isPrinting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary flow = widget.flow;
    final String summary = buildOpdPrintSummaryText(
      context: context,
      flow: flow,
      detail: widget.detail,
    );
    return AppDialog(
      title: Text(l10n.opdPrintSummaryAction),
      icon: const Icon(AppActionIcons.print),
      maxWidth: 720,
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isBusy,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          OpdActionContextPanel(flow: flow, showTitle: false),
          AppReportPreviewPanel(
            selectable: true,
            semanticLabel: l10n.opdPrintSummaryAction,
            child: Text(summary, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
      // Secondary (copy) → Cancel → primary (print). Client-side only; no patch.
      actions: <Widget>[
        AppReportActionButton.copy(
          label: l10n.opdCopySummaryAction,
          icon: AppActionIcons.copy,
          enabled: !_isBusy,
          isLoading: _isCopying,
          onPressed: _isBusy ? null : () => _copySummary(summary),
        ),
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: !_isBusy,
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
        ),
        AppReportActionButton.print(
          label: l10n.opdPrintAction,
          icon: AppActionIcons.print,
          enabled: !_isBusy,
          isLoading: _isPrinting,
          onPressed: _isBusy ? null : () => _printSummaryDocument(summary),
        ),
      ],
    );
  }

  Future<void> _copySummary(String summary) async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isCopying = true;
      _failure = null;
    });
    try {
      await Clipboard.setData(ClipboardData(text: summary));
      if (!mounted) {
        return;
      }
      // Copy is local-only — leave dialog open so Print remains available.
      setState(() => _isCopying = false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCopying = false;
        _failure = const AppFailure.unexpected();
      });
    }
  }

  Future<void> _printSummaryDocument(String summary) async {
    if (_isBusy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary flow = widget.flow;
    setState(() {
      _isPrinting = true;
      _failure = null;
    });
    try {
      await printFormTemplateDocument(
        ref: ref,
        context: context,
        title: l10n.opdPrintSummaryAction,
        patientContext: buildPrintFormPatientContext(
          l10n,
          patientName: flow.patientDisplayName ?? flow.displayTitle,
          patientId: flow.patientDisplayId,
          encounterId: flow.publicId,
        ),
        bodyHtml:
            '<div class="print-template-note">${printHtmlEscape(summary)}</div>',
        includeSignatures: true,
      );
      if (!mounted) {
        return;
      }
      // Print is client-side only — no Riverpod patch; dismiss without saved signal.
      Navigator.of(context).pop(false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPrinting = false;
        _failure = const AppFailure.unexpected();
      });
    }
  }
}

/// Builds the plain-text OPD summary preview used by [PrintOpdSummaryDialog].
@visibleForTesting
String buildOpdPrintSummaryText({
  required BuildContext context,
  required OpdFlowSummary flow,
  OpdFlowDetail? detail,
}) {
  final AppLocalizations l10n = context.l10n;
  final OpdFlowDetail? value = detail;
  final List<String> lines = <String>[
    flow.displayTitle,
    AppDisplay.joinNonEmpty(<String?>[
      flow.patientIdentifier,
      flow.patientPhone,
      flow.assignedStaffLabel ?? flow.providerDisplayName,
    ], separator: ' | '),
    '${l10n.opdStageLabel}: '
        '${opdStageDisplayLabel(l10n, flow.displayCode ?? flow.stage)}',
    '${l10n.opdNextStepColumnLabel}: '
        '${opdNextStepDisplayLabel(l10n, flow.displayNextStep ?? flow.nextStep)}',
    '${l10n.opdTriageLevelLabel}: ${triageLevelDisplayLabel(l10n, flow.triageLevel, emptyAsPending: false)}',
    '${l10n.opdRouteDecisionLabel}: ${AppDisplay.apiLabel(flow.lastRouteTo ?? '')}',
    if (_isNonEmpty(flow.chiefComplaint))
      '${l10n.opdChiefComplaintLabel}: ${flow.chiefComplaint}',
    if (_isNonEmpty(flow.triageNotes))
      '${l10n.opdTriageNotesLabel}: ${flow.triageNotes}',
    '${l10n.opdPaymentStatusLabel}: ${opdFlowBillingDisplay(context, flow).label}',
    '${l10n.opdVitalsSummaryLabel}: ${value?.vitalSigns.length ?? 0}',
    '${l10n.opdClinicalNotesSummaryLabel}: ${value?.clinicalNotes.length ?? 0}',
    '${l10n.opdServicesSummaryLabel}: ${(value?.labOrders.length ?? 0) + (value?.radiologyOrders.length ?? 0) + (value?.pharmacyOrders.length ?? 0)}',
    if (value != null && value.vitalSigns.isNotEmpty) '',
    if (value != null && value.vitalSigns.isNotEmpty) l10n.opdVitalsSummaryLabel,
    if (value != null)
      for (final OpdRelatedRecord vital in value.vitalSigns)
        AppDisplay.joinNonEmpty(<String?>[vital.title, vital.subtitle], separator: ' | '),
    if (value != null && value.timeline.isNotEmpty) '',
    if (value != null && value.timeline.isNotEmpty) l10n.opdTimelineTitle,
    if (value != null)
      for (final OpdTimelineItem item in value.timeline)
        AppDisplay.joinNonEmpty(<String?>[
          AppDisplay.apiLabel(item.action),
          opdStageDisplayLabel(l10n, item.stage),
          item.notes,
        ], separator: ' | '),
  ];
  return lines.where((String line) => line.trim().isNotEmpty).join('\n');
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}
