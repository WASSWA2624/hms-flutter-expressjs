import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_approval_print_options.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> printBillingApprovalPacket({
  required WidgetRef ref,
  required BuildContext context,
  required BillingWorkItem item,
}) async {
  final AppLocalizations l10n = context.l10n;
  final BillingApprovalPrintOptionsController options =
      BillingApprovalPrintOptionsController();
  final String title = l10n.billingApprovalPacketTitle;

  String? buildSubtitle() {
    if (!options.includeStatusDecision) {
      return null;
    }
    return '${l10n.billingStatusFilterLabel}: '
        '${billingWorkItemStatusLabel(context, item)}';
  }

  String buildBodyHtml() {
    return billingApprovalHtml(context, item, options: options);
  }

  try {
    await PrintDocumentTemplates.claimStatement(
      ref: ref,
      context: context,
      title: title,
      previewDialogTitle: title,
      subtitle: buildSubtitle(),
      subtitleBuilder: buildSubtitle,
      patientContext: buildPrintFormPatientContext(
        l10n,
        patientName: billingPatientName(context, item),
        patientId: billingPatientPublicNumber(item),
        encounterId: billingPublicLabel(item.encounterDisplayId),
      ),
      claimReference: PrintFormContextReference(
        label: l10n.billingApprovalDetailTitle,
        value: billingWorkItemPublicId(context, item),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: BillingApprovalPrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      includeSignatures: true,
      footerNote: l10n.billingApprovalPacketFooter,
    );
  } finally {
    options.dispose();
  }
}

String billingApprovalHtml(
  BuildContext context,
  BillingWorkItem item, {
  BillingApprovalPrintOptionsController? options,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool includeInvoice = options?.includeInvoice ?? true;
  final bool includeRequestFields = options?.includeRequestFields ?? true;
  final bool includeStatusDecision = options?.includeStatusDecision ?? true;
  final bool includeNotes = options?.includeNotes ?? true;
  final bool includeFooter = options?.includeFooter ?? true;
  final StringBuffer buffer = StringBuffer();

  if (includeInvoice) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingInvoiceLabel,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            l10n.billingLinkedInvoiceLabel,
            l10n.billingEncounterLabel,
            l10n.billingLineItemAmountColumn,
          ],
          rows: <List<String>>[
            <String>[
              billingPublicLabel(item.targetDisplayId) ??
                  billingPublicLabel(item.invoiceDisplayId) ??
                  billingWorkItemPublicId(context, item),
              billingPublicLabel(item.encounterDisplayId) ??
                  l10n.billingNotRecorded,
              billingMoney(context, item.amount, item.currency),
            ],
          ],
          emptyText: l10n.billingNotRecorded,
        ),
      ),
    );
  }

  if (includeRequestFields) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPrintSectionRequestFields,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            l10n.billingRequestTypeLabel,
            l10n.billingRequesterLabel,
            l10n.billingInsurerColumn,
            l10n.billingInvoiceSchemeColumn,
          ],
          rows: <List<String>>[
            <String>[
              billingApiLabel(context, item.approvalType),
              billingPublicLabel(item.requestedByDisplayId) ??
                  l10n.billingNotRecorded,
              billingPublicLabel(item.insurerDisplayName) ??
                  l10n.billingNotRecorded,
              billingPublicLabel(item.schemeDisplayName) ??
                  l10n.billingNotRecorded,
            ],
          ],
          emptyText: l10n.billingNotRecorded,
        ),
      ),
    );
  }

  if (includeStatusDecision) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPrintSectionStatusDecision,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            l10n.billingStatusFilterLabel,
            l10n.billingIssuedDateFilterLabel,
            l10n.billingLineItemAmountColumn,
          ],
          rows: <List<String>>[
            <String>[
              billingWorkItemStatusLabel(context, item),
              billingDateTime(context, item.requestedAt ?? item.timelineAt),
              billingMoney(context, item.amount, item.currency),
            ],
          ],
          emptyText: l10n.billingNotRecorded,
        ),
      ),
    );
  }

  if (includeNotes) {
    final String reason = (item.requestReason ?? '').trim();
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingNotesLabel,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(reason.isEmpty ? l10n.billingNotRecorded : reason)}</p>',
      ),
    );
  }

  if (includeFooter) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPrintSectionFooter,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(l10n.billingApprovalPacketFooter)}</p>',
      ),
    );
  }

  return buffer.toString();
}
