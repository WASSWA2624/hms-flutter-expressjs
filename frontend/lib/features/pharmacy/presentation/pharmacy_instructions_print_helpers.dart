import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

const String pharmacyPrintPriceUnavailable = '—';

String pharmacyOrderItemQuantityLabel(
  PharmacyOrderItem item, {
  AppLocalizations? l10n,
}) {
  final num prescribed = resolvePharmacyItemQuantity(item);
  final String base = clinicalActionJoinDisplay(<String?>[
    _trimQuantity(prescribed),
    clinicalActionTrimmedOrNull(item.quantityUnit),
  ], separator: ' ');

  if (l10n == null || item.quantityDispensed <= 0) {
    return base;
  }

  final String progress = l10n.pharmacyDispenseProgressLabel(
    _trimQuantity(item.quantityDispensed),
    _trimQuantity(prescribed),
  );
  return '$base ($progress)';
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
  PharmacyOrderWorkflow workflow, {
  Set<String>? selectedItemIds,
  bool hideZeroQuantity = false,
  bool hidePartiallyDispensed = false,
  List<PharmacyTimelineItem>? historyItems,
}) {
  final AppLocalizations l10n = context.l10n;
  final PharmacyOrder order = workflow.order;
  final List<PharmacyOrderItem> allItems = workflow.items.isEmpty
      ? order.items
      : workflow.items;
  final List<PharmacyOrderItem> items = allItems.where((PharmacyOrderItem item) {
    if (selectedItemIds != null && !selectedItemIds.contains(item.id)) {
      return false;
    }
    if (hideZeroQuantity && item.quantityRemaining <= 0) {
      return false;
    }
    if (hidePartiallyDispensed &&
        item.quantityDispensed > 0 &&
        item.quantityRemaining > 0) {
      return false;
    }
    return true;
  }).toList(growable: false);

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
      pharmacyOrderItemQuantityLabel(item, l10n: l10n),
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

  final String medicationsSection = PrintFormTemplate.section(
    title: l10n.pharmacyMedicationPanelTitle,
    bodyHtml: tableHtml,
  );

  final List<PharmacyTimelineItem> history = historyItems ?? const <PharmacyTimelineItem>[];
  if (history.isEmpty) {
    return medicationsSection;
  }

  final String historyHtml = pharmacyDispenseHistoryHtml(
    context,
    workflow: workflow,
    historyItems: history,
  );
  return '$medicationsSection$historyHtml';
}

String pharmacyDispenseHistoryHtml(
  BuildContext context, {
  required PharmacyOrderWorkflow workflow,
  required List<PharmacyTimelineItem> historyItems,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<String> headers = <String>[
    l10n.pharmacyPrintRowNumberColumnLabel,
    l10n.pharmacyHistoryWhenColumnLabel,
    l10n.pharmacyHistoryEventColumnLabel,
    l10n.pharmacyHistoryBatchColumnLabel,
    l10n.pharmacyMedicationColumnLabel,
    l10n.pharmacyQuantityColumnLabel,
  ];

  final List<List<String>> rows = <List<String>>[];
  for (var index = 0; index < historyItems.length; index += 1) {
    final PharmacyTimelineItem item = historyItems[index];
    final String? batch = item.labelParams['batch']?.toString().trim();
    final List<PharmacyDispenseBatchLine> lines =
        resolvePharmacyDispenseBatchLines(
          workflow: workflow,
          dispenseBatchRef: batch,
          dispenseLogId: item.labelParams['log_id']?.toString(),
        );
    final String medications = lines
        .map((PharmacyDispenseBatchLine line) => line.item.medicationLabel)
        .where((String label) => label.trim().isNotEmpty)
        .join(', ');
    final String quantities = lines
        .map((PharmacyDispenseBatchLine line) {
          return clinicalActionJoinDisplay(<String?>[
            _trimQuantity(line.quantityDispensed),
            clinicalActionTrimmedOrNull(line.item.quantityUnit),
          ], separator: ' ');
        })
        .where((String label) => label.trim().isNotEmpty)
        .join(', ');
    rows.add(<String>[
      (index + 1).toString(),
      item.at == null
          ? '—'
          : AppFormatters.dateTime(item.at!, Localizations.localeOf(context)),
      pharmacyTimelineEventLabel(context, item),
      (batch == null || batch.isEmpty) ? '—' : batch,
      medications.isEmpty ? '—' : medications,
      quantities.isEmpty ? '—' : quantities,
    ]);
  }

  return PrintFormTemplate.section(
    title: l10n.pharmacyTimelinePanelTitle,
    bodyHtml: PrintFormTemplate.table(
      headers: headers,
      rows: rows,
      emptyText: l10n.pharmacyDispenseHistoryEmptyBody,
    ),
  );
}

String pharmacyTimelineEventLabel(
  BuildContext context,
  PharmacyTimelineItem item,
) {
  final String type = _apiWordLabel(item.type ?? '');
  final String? medication = item.labelParams['medication']?.toString();
  final String? status = item.labelParams['status']?.toString();
  final String? batch = item.labelParams['batch']?.toString();
  final Object? medicationCount = item.labelParams['medication_count'];
  if ((medication ?? '').isNotEmpty) {
    return context.l10n.pharmacyTimelineMedicationEvent(
      medication!,
      _apiWordLabel(status ?? ''),
    );
  }
  if (medicationCount is num && medicationCount > 1) {
    return context.l10n.pharmacyTimelineBatchMedicationsEvent(
      medicationCount.toInt(),
      _apiWordLabel(status ?? type),
    );
  }
  if ((batch ?? '').isNotEmpty) {
    return context.l10n.pharmacyTimelineBatchEvent(type, batch!);
  }
  return type.isEmpty ? context.l10n.pharmacyTimelineOrderPlaced : type;
}

String _apiWordLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

/// One dispensed line belonging to a prepare/attest dispense batch.
@immutable
final class PharmacyDispenseBatchLine {
  const PharmacyDispenseBatchLine({required this.item, required this.log});

  final PharmacyOrderItem item;
  final PharmacyDispenseLog log;

  num get quantityDispensed => log.quantityDispensed;
}

/// Resolves medication lines for a timeline dispense event (by batch ref or log id).
List<PharmacyDispenseBatchLine> resolvePharmacyDispenseBatchLines({
  required PharmacyOrderWorkflow workflow,
  String? dispenseBatchRef,
  String? dispenseLogId,
}) {
  final String? batch = dispenseBatchRef?.trim();
  final String? logId = dispenseLogId?.trim();
  if ((batch == null || batch.isEmpty) && (logId == null || logId.isEmpty)) {
    return const <PharmacyDispenseBatchLine>[];
  }

  final List<PharmacyOrderItem> items = workflow.items.isEmpty
      ? workflow.order.items
      : workflow.items;
  final List<PharmacyDispenseBatchLine> lines = <PharmacyDispenseBatchLine>[];

  for (final PharmacyOrderItem item in items) {
    for (final PharmacyDispenseLog log in item.dispenseLogs) {
      final bool matchesBatch =
          batch != null &&
          batch.isNotEmpty &&
          (log.dispenseBatchRef ?? '').trim() == batch;
      final bool matchesLog =
          logId != null &&
          logId.isNotEmpty &&
          (log.id == logId || (log.displayId ?? '') == logId);
      if (!matchesBatch && !matchesLog) {
        continue;
      }
      lines.add(PharmacyDispenseBatchLine(item: item, log: log));
    }
  }

  return lines;
}

/// Printable HTML for a single dispense batch (quantities from dispense logs).
String pharmacyDispenseBatchHtml(
  BuildContext context, {
  required List<PharmacyDispenseBatchLine> lines,
  String? dispenseBatchRef,
}) {
  final AppLocalizations l10n = context.l10n;

  final List<String> headers = <String>[
    l10n.pharmacyPrintRowNumberColumnLabel,
    l10n.pharmacyMedicationColumnLabel,
    l10n.pharmacyQuantityColumnLabel,
    l10n.clinicalInstructionsLabel,
  ];

  final List<List<String>> rows = <List<String>>[];
  for (var index = 0; index < lines.length; index += 1) {
    final PharmacyDispenseBatchLine line = lines[index];
    final PharmacyOrderItem item = line.item;
    rows.add(<String>[
      (index + 1).toString(),
      item.medicationLabel,
      clinicalActionJoinDisplay(<String?>[
        _trimQuantity(line.quantityDispensed),
        clinicalActionTrimmedOrNull(item.quantityUnit),
      ], separator: ' '),
      _printInstructionsCell(item),
    ]);
  }

  final String tableHtml = PrintFormTemplate.table(
    headers: headers,
    rows: rows,
    emptyText: l10n.pharmacyDispenseBatchEmptyBody,
  );

  final String? batch = dispenseBatchRef?.trim();
  final String title = (batch == null || batch.isEmpty)
      ? l10n.pharmacyDispenseBatchDialogTitle
      : l10n.pharmacyDispenseBatchDialogTitleWithRef(batch);

  return PrintFormTemplate.section(
    title: title,
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
