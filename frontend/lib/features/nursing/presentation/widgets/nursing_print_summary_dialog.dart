import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Opens the shared App print-preview dialog for a nursing care summary.
///
/// Uses [PrintDocumentTemplates.clinicalSummary] with default preview so nursing
/// stays on the same chrome as other simple print flows.
Future<void> showNursingPrintSummary({
  required WidgetRef ref,
  required BuildContext context,
  required NursingPatientDetail detail,
}) {
  final AppLocalizations l10n = context.l10n;
  final NursingPatientSummary summary = detail.enrichedSummary;

  return PrintDocumentTemplates.clinicalSummary(
    ref: ref,
    context: context,
    title: l10n.nursingReportTitle,
    previewDialogTitle: l10n.printPreviewTitle,
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
    fallbackText: nursingSummaryText(context, detail),
  );
}
