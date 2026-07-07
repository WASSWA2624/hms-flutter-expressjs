import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

const String pharmacyPrintPriceUnavailable = '—';

String pharmacyOrderItemQuantityLabel(PharmacyOrderItem item) {
  final num quantity = resolvePharmacyItemQuantity(item);
  return clinicalActionJoinDisplay(<String?>[
    _trimQuantity(quantity),
    clinicalActionTrimmedOrNull(item.quantityUnit),
  ], separator: ' ');
}

String pharmacyOrderItemReadableInstructions(PharmacyOrderItem item) {
  return clinicalPrescriptionSigReadable(
    doseAmount: item.doseAmount,
    doseUnit: item.doseUnit,
    dosage: item.dosage,
    route: item.route,
    frequency: item.frequency,
    durationValue: item.durationValue,
    durationUnit: item.durationUnit,
    instructions: item.instructions,
  );
}

String pharmacyInstructionsHtml(
  BuildContext context,
  PharmacyOrderWorkflow workflow,
) {
  final AppLocalizations l10n = context.l10n;
  final PharmacyOrder order = workflow.order;
  final List<PharmacyOrderItem> items = workflow.items.isEmpty
      ? order.items
      : workflow.items;

  final List<String> headers = <String>[
    l10n.pharmacyPrintRowNumberColumnLabel,
    l10n.pharmacyMedicationColumnLabel,
    l10n.pharmacyQuantityColumnLabel,
    l10n.clinicalInstructionsLabel,
    l10n.clinicalRequestUnitPriceLabel,
    l10n.pharmacyPrintAmountColumnLabel,
  ];

  num grandTotal = 0;
  String? grandTotalCurrency;
  final List<List<String>> rows = <List<String>>[];
  for (var index = 0; index < items.length; index += 1) {
    final PharmacyOrderItem item = items[index];
    final num? unitPrice = resolvePharmacyItemUnitPrice(
      order: order,
      item: item,
    );
    final num? lineTotal = resolvePharmacyItemLineTotal(
      order: order,
      item: item,
    );
    final String? currency = resolvePharmacyItemCurrency(
      order: order,
      item: item,
    );
    if (lineTotal != null && lineTotal > 0) {
      grandTotal += lineTotal;
      grandTotalCurrency ??= currency;
    }

    rows.add(<String>[
      (index + 1).toString(),
      item.medicationLabel,
      pharmacyOrderItemQuantityLabel(item),
      _printInstructionsCell(item),
      _printPriceLabel(context, unitPrice: unitPrice, currency: currency),
      _printPriceLabel(context, unitPrice: lineTotal, currency: currency),
    ]);
  }

  final List<String> footerRow = <String>[
    '',
    '',
    '',
    '',
    l10n.pharmacyReportTotalAmountSoldLabel,
    grandTotal > 0
        ? _printPriceLabel(
            context,
            unitPrice: grandTotal,
            currency: grandTotalCurrency,
          )
        : pharmacyPrintPriceUnavailable,
  ];

  final String tableHtml = PrintFormTemplate.table(
    headers: headers,
    rows: rows,
    emptyText: l10n.pharmacyNoMedicationBody,
    footerRow: rows.isEmpty ? null : footerRow,
  );

  return PrintFormTemplate.section(
    title: l10n.pharmacyMedicationPanelTitle,
    bodyHtml: tableHtml,
  );
}

String _printInstructionsCell(PharmacyOrderItem item) {
  final String instructions = pharmacyOrderItemReadableInstructions(
    item,
  ).trim();
  return instructions.isEmpty ? pharmacyPrintPriceUnavailable : instructions;
}

String _printPriceLabel(
  BuildContext context, {
  required num? unitPrice,
  required String? currency,
}) {
  if (unitPrice == null || unitPrice <= 0) {
    return pharmacyPrintPriceUnavailable;
  }
  return clinicalRequestPriceLabel(context, unitPrice, currency);
}

String _trimQuantity(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
