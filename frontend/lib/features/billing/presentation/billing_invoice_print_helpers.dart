import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_invoice_print_options.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_detail_header.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> printBillingInvoice({
  required WidgetRef ref,
  required BuildContext context,
  required BillingWorkItem item,
}) async {
  final AppLocalizations l10n = context.l10n;
  final BillingInvoicePrintOptionsController options =
      BillingInvoicePrintOptionsController(item);

  String? buildSubtitle() {
    if (!options.includeInvoiceSummary) {
      return null;
    }
    return billingInvoiceSubtitle(context, item);
  }

  String buildBodyHtml() {
    return billingInvoiceHtml(context, item, options: options);
  }

  try {
    await PrintDocumentTemplates.invoice(
      ref: ref,
      context: context,
      title: l10n.billingInvoiceLabel,
      subtitle: buildSubtitle(),
      subtitleBuilder: buildSubtitle,
      patientContext: buildPrintFormPatientContext(
        l10n,
        patientName: billingPatientName(context, item),
        patientId: billingPatientPublicNumber(item),
        encounterId: billingPublicLabel(item.encounterDisplayId),
      ),
      invoiceReference: PrintFormContextReference(
        label: l10n.billingInvoiceLabel,
        value: billingWorkItemPublicId(context, item),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: BillingInvoicePrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      includeSignatures: true,
      footerNote: l10n.billingInvoiceReportFooter,
    );
  } finally {
    options.dispose();
  }
}

String billingInvoiceSubtitle(BuildContext context, BillingWorkItem item) {
  final List<PrintFormMetadataItem> items = _invoiceSubtitleItems(
    context,
    item,
  );
  return items
      .map((PrintFormMetadataItem entry) => '${entry.label}: ${entry.value};')
      .join(' , ');
}

String billingInvoiceHtml(
  BuildContext context,
  BillingWorkItem item, {
  BillingInvoicePrintOptionsController? options,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool includeLineItems = options?.includeLineItems ?? true;
  final bool includePayments = options?.includePayments ?? true;
  final bool includeAdjustments = options?.includeAdjustments ?? true;
  final bool includeInsurance = options?.includeInsurance ?? true;
  final bool includeNotes = options?.includeNotes ?? false;

  final StringBuffer buffer = StringBuffer();
  if (includeLineItems) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingLineItemsTitle,
        bodyHtml: _lineItemsTableHtml(context, item),
      ),
    );
  }
  if (includePayments) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPaymentsTitle,
        bodyHtml: _paymentsTableHtml(context, item),
      ),
    );
  }
  if (includeAdjustments) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingAdjustmentsTitle,
        bodyHtml: _adjustmentsTableHtml(context, item),
      ),
    );
  }
  if (includeInsurance) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPrintSectionInsurance,
        bodyHtml: _insuranceTableHtml(context, item),
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
  if (options?.includeFooter ?? true) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPrintSectionFooter,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(l10n.billingInvoiceReportFooter)}</p>',
      ),
    );
  }
  return buffer.toString();
}

List<PrintFormMetadataItem> _invoiceSubtitleItems(
  BuildContext context,
  BillingWorkItem item,
) {
  final AppLocalizations l10n = context.l10n;
  final List<PrintFormMetadataItem> items = <PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: l10n.billingPaymentStatusLabel,
      value: billingWorkItemStatusLabel(context, item),
    ),
    PrintFormMetadataItem(
      label: l10n.billingInvoiceStatusLabel,
      value: billingApiLabel(context, item.billingStatus ?? item.status),
    ),
    PrintFormMetadataItem(
      label: l10n.billingIssuedDateFilterLabel,
      value: billingDateTime(context, item.timelineAt),
    ),
    PrintFormMetadataItem(
      label: l10n.billingAmountPaidLabel,
      value: billingMoney(context, item.paidAmount, item.currency),
    ),
    PrintFormMetadataItem(
      label: l10n.billingBalanceColumn,
      value: billingMoney(context, item.balanceDue, item.currency),
    ),
  ];

  final String? gender = item.patientGender?.trim();
  if (gender != null && gender.isNotEmpty) {
    items.add(
      PrintFormMetadataItem(
        label: l10n.patientsGenderLabel,
        value: patientGenderLabel(l10n, gender),
      ),
    );
  }

  final String? sourceSummary = item.invoiceSourceSummary;
  if (sourceSummary != null && sourceSummary.trim().isNotEmpty) {
    items.add(
      PrintFormMetadataItem(
        label: l10n.billingLineItemDepartmentColumn,
        value: billingInvoiceSourceLabel(context, item),
      ),
    );
  }

  return items;
}

String _lineItemsTableHtml(BuildContext context, BillingWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  final List<String> headers = <String>[
    l10n.pharmacyPrintRowNumberColumnLabel,
    l10n.billingLineItemDescriptionColumn,
    l10n.billingLineItemQtyColumn,
    l10n.billingLineItemUnitPriceColumn,
    l10n.billingLineItemDepartmentColumn,
    l10n.billingEncounterLabel,
    l10n.billingLineItemAmountColumn,
  ];

  final List<List<String>> rows = <List<String>>[];
  for (var index = 0; index < item.items.length; index += 1) {
    final BillingInvoiceItem lineItem = item.items[index];
    rows.add(<String>[
      '${index + 1}',
      lineItem.description,
      '${lineItem.quantity}',
      billingMoney(context, lineItem.unitPrice, item.currency),
      lineItem.sourceModule ?? l10n.billingNotRecorded,
      billingPublicLabel(lineItem.encounterDisplayId) ?? l10n.billingNotRecorded,
      billingMoney(context, lineItem.totalPrice, item.currency),
    ]);
  }

  final num invoiceTotal = item.financials.invoiceTotal != 0
      ? item.financials.invoiceTotal
      : item.items.fold<num>(
          0,
          (num sum, BillingInvoiceItem lineItem) => sum + lineItem.totalPrice,
        );

  final List<String> footerRow = <String>[
    '',
    '',
    '',
    '',
    '',
    l10n.billingTotalAmountLabel,
    billingMoney(context, invoiceTotal, item.currency),
  ];

  return PrintFormTemplate.table(
    headers: headers,
    rows: rows,
    emptyText: l10n.billingNoLineItems,
    footerRow: rows.isEmpty ? null : footerRow,
  );
}

String _paymentsTableHtml(BuildContext context, BillingWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  final List<String> headers = <String>[
    l10n.billingPaymentLabel,
    l10n.billingPaymentMethodLabel,
    l10n.billingPaymentStatusLabel,
    l10n.billingReferenceLabel,
    l10n.billingIssuedDateFilterLabel,
    l10n.billingLineItemAmountColumn,
  ];

  final List<List<String>> rows = <List<String>>[];
  for (final BillingPayment payment in item.payments) {
    rows.add(<String>[
      billingPublicLabel(payment.displayId) ?? l10n.billingPaymentLabel,
      billingApiLabel(context, payment.method),
      billingApiLabel(context, payment.status),
      billingPublicLabel(payment.transactionRef) ?? l10n.billingNotRecorded,
      billingDateTime(context, payment.paidAt),
      billingMoney(context, payment.amount, item.currency),
    ]);
  }

  return PrintFormTemplate.table(
    headers: headers,
    rows: rows,
    emptyText: l10n.billingNoPayments,
  );
}

String _adjustmentsTableHtml(BuildContext context, BillingWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  final List<String> headers = <String>[
    l10n.billingAdjustmentsTitle,
    l10n.billingStatusFilterLabel,
    l10n.billingNotesLabel,
    l10n.billingLineItemAmountColumn,
  ];

  final List<List<String>> rows = <List<String>>[];
  for (final BillingAdjustment adjustment in item.adjustments) {
    rows.add(<String>[
      billingPublicLabel(adjustment.displayId) ?? l10n.billingAdjustmentsTitle,
      billingApiLabel(context, adjustment.status),
      adjustment.reason ?? l10n.billingNotRecorded,
      billingMoney(context, adjustment.amount, item.currency),
    ]);
  }

  return PrintFormTemplate.table(
    headers: headers,
    rows: rows,
    emptyText: l10n.billingNotRecorded,
  );
}

String _insuranceTableHtml(BuildContext context, BillingWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  final List<String> headers = <String>[
    l10n.billingPrintSectionInsurance,
    l10n.billingInvoicePatientShareColumn,
    l10n.billingLineItemAmountColumn,
  ];
  final List<List<String>> rows = <List<String>>[
    <String>[
      billingPublicLabel(item.schemeDisplayName) ??
          billingPublicLabel(item.insurerDisplayName) ??
          l10n.billingNotRecorded,
      billingMoney(context, item.totalPatientShare, item.currency),
      billingMoney(context, item.totalInsurerShare, item.currency),
    ],
  ];
  return PrintFormTemplate.table(
    headers: headers,
    rows: rows,
    emptyText: l10n.billingNotRecorded,
  );
}
