import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
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
  await PrintDocumentTemplates.invoice(
    ref: ref,
    context: context,
    title: l10n.billingInvoiceLabel,
    subtitle: billingInvoiceSubtitle(context, item),
    patientContext: buildPrintFormPatientContext(
      l10n,
      patientName: billingPatientName(context, item),
      patientId: item.effectivePatientNumber,
      encounterId: item.encounterDisplayId ?? item.encounterId,
    ),
    invoiceReference: PrintFormContextReference(
      label: l10n.billingInvoiceLabel,
      value: item.effectiveDisplayId,
    ),
    bodyHtml: billingInvoiceHtml(context, item),
    footerNote: l10n.billingInvoiceReportFooter,
    includeSignatures: true,
  );
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

String billingInvoiceHtml(BuildContext context, BillingWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  final String lineItemsHtml = PrintFormTemplate.section(
    title: l10n.billingLineItemsTitle,
    bodyHtml: _lineItemsTableHtml(context, item),
  );
  final String paymentsHtml = PrintFormTemplate.section(
    title: l10n.billingPaymentsTitle,
    bodyHtml: _paymentsTableHtml(context, item),
  );

  return '$lineItemsHtml$paymentsHtml';
}

List<PrintFormMetadataItem> _invoiceSubtitleItems(
  BuildContext context,
  BillingWorkItem item,
) {
  final AppLocalizations l10n = context.l10n;
  final List<PrintFormMetadataItem> items = <PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: l10n.billingPaymentStatusLabel,
      value: billingClearanceLabel(context, item.clearanceState),
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
      lineItem.encounterDisplayId ?? l10n.billingNotRecorded,
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
      payment.effectiveDisplayId,
      billingApiLabel(context, payment.method),
      billingApiLabel(context, payment.status),
      payment.transactionRef ?? l10n.billingNotRecorded,
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
