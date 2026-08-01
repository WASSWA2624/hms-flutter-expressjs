import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class NursingPrintSummaryDialog extends ConsumerStatefulWidget {
  const NursingPrintSummaryDialog({required this.detail, super.key});

  final NursingPatientDetail detail;

  @override
  ConsumerState<NursingPrintSummaryDialog> createState() =>
      _NursingPrintSummaryDialogState();
}

class _NursingPrintSummaryDialogState
    extends ConsumerState<NursingPrintSummaryDialog> {
  static const double _previewHeight = 420;

  bool _isPrinting = false;
  bool _previewMaximized = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final NursingPatientSummary summary = widget.detail.enrichedSummary;
    final String preview = nursingSummaryText(context, widget.detail);
    final String documentHtml = PrintDocumentTemplates.buildDocumentHtml(
      kind: PrintDocumentTemplateKind.clinicalSummary,
      ref: ref,
      context: context,
      title: l10n.nursingReportTitle,
      patientContext: buildPrintFormPatientContext(
        l10n,
        patientName: summary.displayTitle,
        patientId: summary.patientId ?? summary.patientDisplayId,
        encounterId: summary.encounterDisplayId,
      ),
      contextReference: PrintFormContextReference(
        label: l10n.nursingAdmissionLabel,
        value: summary.displayId ?? l10n.profileUnknownValue,
      ),
      bodyHtml: nursingSummaryHtml(context, widget.detail),
      footerNote: l10n.nursingReportFooter,
      includeSignatures: true,
    );
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double maximizedPreviewHeight = (viewportHeight * 0.72).clamp(
      360.0,
      900.0,
    );

    return AppDialog(
      title: Text(l10n.nursingActionPrintSummary),
      icon: const Icon(Icons.print_outlined),
      maxWidth: 960,
      scrollable: !_previewMaximized,
      pinActionsToBottom: true,
      closeEnabled: !_isPrinting,
      content: AppPrintPreviewLayout(
        previewMaximized: _previewMaximized,
        preview: AppPrintPreviewPanel(
          html: documentHtml,
          title: l10n.printPreviewTitle,
          height: _previewMaximized
              ? maximizedPreviewHeight
              : _previewHeight,
          maximized: _previewMaximized,
          maximizeEnabled: !_isPrinting,
          onMaximizeToggle: () {
            setState(() => _previewMaximized = !_previewMaximized);
          },
          fallbackChild: SelectableText(
            preview,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isPrinting,
          onPressed: _isPrinting
              ? null
              : () => Navigator.of(context).pop(false),
        ),
        AppReportActionButton.print(
          label: l10n.nursingActionPrintSummary,
          enabled: !_isPrinting,
          isLoading: _isPrinting,
          onPressed: _isPrinting ? null : () => _print(summary),
        ),
      ],
    );
  }

  Future<void> _print(NursingPatientSummary summary) async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _isPrinting = true);
    try {
      await PrintDocumentTemplates.clinicalSummary(
        ref: ref,
        context: context,
        title: l10n.nursingReportTitle,
        patientContext: buildPrintFormPatientContext(
          l10n,
          patientName: summary.displayTitle,
          patientId: summary.patientId ?? summary.patientDisplayId,
          encounterId: summary.encounterDisplayId,
        ),
        visitReference: PrintFormContextReference(
          label: l10n.nursingAdmissionLabel,
          value: summary.displayId ?? l10n.profileUnknownValue,
        ),
        bodyHtml: nursingSummaryHtml(context, widget.detail),
        footerNote: l10n.nursingReportFooter,
        includeSignatures: true,
        showPreview: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }
}
