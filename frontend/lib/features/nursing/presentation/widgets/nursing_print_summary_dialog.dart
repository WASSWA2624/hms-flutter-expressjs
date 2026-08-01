import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

class NursingPrintSummaryDialog extends ConsumerWidget {
  const NursingPrintSummaryDialog({required this.detail, super.key});

  final NursingPatientDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingPatientSummary summary = detail.enrichedSummary;
    final String preview = nursingSummaryText(context, detail);
    return AppDialog(
      title: Text(l10n.nursingActionPrintSummary),
      icon: const Icon(Icons.print_outlined),
      maxWidth: 720,
      scrollable: true,
      content: AppReportPreviewPanel(
        selectable: true,
        title: l10n.nursingReportTitle,
        child: Text(preview, style: Theme.of(context).textTheme.bodyMedium),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppReportActionButton.print(
          label: l10n.nursingActionPrintSummary,
          onPressed: () async {
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
              bodyHtml: nursingSummaryHtml(context, detail),
              footerNote: l10n.nursingReportFooter,
              includeSignatures: true,
            );
          },
        ),
      ],
    );
  }
}
