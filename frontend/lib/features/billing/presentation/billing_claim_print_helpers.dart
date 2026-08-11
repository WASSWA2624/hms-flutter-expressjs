import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_claim_print_options.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> printBillingClaimOrPreAuth({
  required WidgetRef ref,
  required BuildContext context,
  required BillingWorkItem item,
}) async {
  final AppLocalizations l10n = context.l10n;
  final BillingClaimPrintOptionsController options =
      BillingClaimPrintOptionsController();
  final bool isPreAuth = item.isPreAuthorization;
  final String title = isPreAuth
      ? l10n.claimsAuthorizationStatementTitle
      : l10n.claimsClaimStatementTitle;

  String? buildSubtitle() {
    if (!options.includeStatusDecision) {
      return null;
    }
    return '${l10n.billingStatusFilterLabel}: '
        '${billingWorkItemStatusLabel(context, item)}';
  }

  String buildBodyHtml() {
    return billingClaimHtml(context, item, options: options);
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
        label: isPreAuth
            ? l10n.billingPreAuthDetailTitle
            : l10n.billingClaimDetailTitle,
        value: billingWorkItemPublicId(context, item),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: BillingClaimPrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      includeSignatures: true,
      footerNote: l10n.claimsReportFooter,
    );
  } finally {
    options.dispose();
  }
}

String billingClaimHtml(
  BuildContext context,
  BillingWorkItem item, {
  BillingClaimPrintOptionsController? options,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool includeInvoice = options?.includeInvoice ?? true;
  final bool includeClaimFields = options?.includeClaimFields ?? true;
  final bool includeStatusDecision = options?.includeStatusDecision ?? true;
  final bool includeNotes = options?.includeNotes ?? false;
  final bool includeFooter = options?.includeFooter ?? true;
  final StringBuffer buffer = StringBuffer();

  if (includeInvoice) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingInvoiceLabel,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            l10n.billingInvoiceLabel,
            l10n.billingEncounterLabel,
            l10n.billingLineItemAmountColumn,
          ],
          rows: <List<String>>[
            <String>[
              billingPublicLabel(item.invoiceDisplayId) ??
                  billingWorkItemPublicId(context, item),
              billingPublicLabel(item.encounterDisplayId) ??
                  l10n.billingNotRecorded,
              billingMoney(context, item.effectiveTotal, item.currency),
            ],
          ],
          emptyText: l10n.billingNotRecorded,
        ),
      ),
    );
  }

  if (includeClaimFields) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPrintSectionClaimFields,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            l10n.billingInsurerColumn,
            l10n.billingInvoiceSchemeColumn,
            l10n.billingInvoicePatientShareColumn,
            l10n.billingInvoiceInsurerShareColumn,
          ],
          rows: <List<String>>[
            <String>[
              billingPublicLabel(item.insurerDisplayName) ??
                  l10n.billingNotRecorded,
              billingPublicLabel(item.schemeDisplayName) ??
                  l10n.billingNotRecorded,
              billingMoney(context, item.totalPatientShare, item.currency),
              billingMoney(context, item.totalInsurerShare, item.currency),
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
            l10n.billingPaymentStatusLabel,
            l10n.billingIssuedDateFilterLabel,
          ],
          rows: <List<String>>[
            <String>[
              billingWorkItemStatusLabel(context, item),
              billingApiLabel(context, item.billingStatus ?? item.status),
              billingDateTime(context, item.timelineAt),
            ],
          ],
          emptyText: l10n.billingNotRecorded,
        ),
      ),
    );
  }

  if (includeNotes) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingNotesLabel,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(l10n.billingNotRecorded)}</p>',
      ),
    );
  }

  if (includeFooter) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPrintSectionFooter,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(l10n.claimsReportFooter)}</p>',
      ),
    );
  }

  return buffer.toString();
}
