import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Prints a pharmacy order invoice/receipt using the shared invoice template.
///
/// Prices and money totals are included when the order has billing amounts or
/// the viewer has billing:read; otherwise lines print with quantity only.
Future<void> printPharmacyOrderInvoice({
  required WidgetRef ref,
  required BuildContext context,
  required PharmacyOrderWorkflow workflow,
}) async {
  final AppLocalizations l10n = context.l10n;
  final PharmacyOrder order = workflow.order;
  final List<PharmacyOrderItem> lines = workflow.items.isEmpty
      ? order.items
      : workflow.items;
  if (lines.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.pharmacyInvoiceEmptyLinesMessage)),
    );
    return;
  }
  final bool includeMoney = _canIncludeMoney(ref, order);

  await PrintDocumentTemplates.invoice(
    ref: ref,
    context: context,
    title: l10n.pharmacyInvoiceTitle,
    subtitle: pharmacyOrderInvoiceSubtitle(context, order, includeMoney),
    patientContext: buildPrintFormPatientContext(
      l10n,
      patientName: order.patientDisplayName ?? order.displayTitle,
      patientId: order.patientId,
      encounterId: order.encounterId,
    ),
    invoiceReference: PrintFormContextReference(
      label: l10n.pharmacyOrderFieldLabel,
      value: order.displayId ?? order.id,
    ),
    bodyHtml: pharmacyOrderInvoiceHtml(
      context,
      workflow,
      includeMoney: includeMoney,
    ),
    footerNote: l10n.pharmacyInvoiceReportFooter,
  );
}

String pharmacyOrderInvoiceSubtitle(
  BuildContext context,
  PharmacyOrder order,
  bool includeMoney,
) {
  final AppLocalizations l10n = context.l10n;
  final List<PrintFormMetadataItem> items = <PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: l10n.pharmacyOrderFieldLabel,
      value: order.displayId ?? order.id,
    ),
    if ((order.effectivePaymentStatus ?? '').trim().isNotEmpty)
      PrintFormMetadataItem(
        label: l10n.pharmacyPaymentClearanceFieldLabel,
        value: clinicalRequestPaymentStatusDisplayLabel(
          l10n,
          order.effectivePaymentStatus,
        ),
      ),
    if (includeMoney && order.billingTotalAmount != null)
      PrintFormMetadataItem(
        label: l10n.billingTotalAmountLabel,
        value: billingMoney(
          context,
          order.billingTotalAmount!,
          order.billingCurrency,
        ),
      ),
  ];
  return items
      .map((PrintFormMetadataItem entry) => '${entry.label}: ${entry.value};')
      .join(' , ');
}

String pharmacyOrderInvoiceHtml(
  BuildContext context,
  PharmacyOrderWorkflow workflow, {
  required bool includeMoney,
}) {
  final AppLocalizations l10n = context.l10n;
  return PrintFormTemplate.section(
    title: l10n.billingLineItemsTitle,
    bodyHtml: _lineItemsTableHtml(
      context,
      workflow,
      includeMoney: includeMoney,
    ),
  );
}

bool _canIncludeMoney(WidgetRef ref, PharmacyOrder order) {
  if (order.billingTotalAmount != null ||
      (order.billing['line_items'] is List &&
          (order.billing['line_items'] as List).isNotEmpty)) {
    return true;
  }
  return canReadBilling(ref.read(appAccessPolicyProvider));
}

String _lineItemsTableHtml(
  BuildContext context,
  PharmacyOrderWorkflow workflow, {
  required bool includeMoney,
}) {
  final AppLocalizations l10n = context.l10n;
  final PharmacyOrder order = workflow.order;
  final List<PharmacyOrderItem> items = workflow.items.isEmpty
      ? order.items
      : workflow.items;

  final List<String> headers = <String>[
    l10n.pharmacyPrintRowNumberColumnLabel,
    l10n.pharmacyMedicationColumnLabel,
    l10n.billingLineItemQtyColumn,
    if (includeMoney) l10n.billingLineItemUnitPriceColumn,
    if (includeMoney) l10n.billingLineItemAmountColumn,
  ];

  num runningTotal = 0;
  final List<List<String>> rows = <List<String>>[];
  for (var index = 0; index < items.length; index += 1) {
    final PharmacyOrderItem item = items[index];
    final num quantity = resolvePharmacyItemBillableQuantity(
      order: order,
      item: item,
    );
    final List<String> row = <String>[
      '${index + 1}',
      item.medicationLabel,
      quantity.toString(),
    ];
    if (includeMoney) {
      final num? unitPrice = resolvePharmacyItemUnitPrice(
        order: order,
        item: item,
      );
      final String? currency = resolvePharmacyItemCurrency(
        order: order,
        item: item,
      );
      final num? lineTotal = unitPrice == null ? null : unitPrice * quantity;
      if (lineTotal != null) {
        runningTotal += lineTotal;
      }
      row.add(
        unitPrice == null
            ? pharmacyPrintPriceUnavailable
            : billingMoney(context, unitPrice, currency),
      );
      row.add(
        lineTotal == null
            ? pharmacyPrintPriceUnavailable
            : billingMoney(context, lineTotal, currency),
      );
    }
    rows.add(row);
  }

  final num invoiceTotal = order.billingTotalAmount ?? runningTotal;
  final List<String>? footerRow = !includeMoney || rows.isEmpty
      ? null
      : <String>[
          '',
          '',
          '',
          l10n.billingTotalAmountLabel,
          billingMoney(context, invoiceTotal, order.billingCurrency),
        ];

  return PrintFormTemplate.table(
    headers: headers,
    rows: rows,
    emptyText: l10n.pharmacyNoMedicationBody,
    footerRow: footerRow,
  );
}
