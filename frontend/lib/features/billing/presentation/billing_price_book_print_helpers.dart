import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_dialogs.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_print_options.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> printBillingPriceBookList({
  required WidgetRef ref,
  required BuildContext context,
  required List<BillingPriceBookEntry> entries,
}) async {
  final AppLocalizations l10n = context.l10n;
  final BillingPriceBookPrintOptionsController options =
      BillingPriceBookPrintOptionsController();

  String? buildSubtitle() {
    if (!options.includeSummary) {
      return null;
    }
    return l10n.billingPriceBookPrintRowCount(entries.length);
  }

  String buildBodyHtml() {
    return billingPriceBookListHtml(
      context,
      entries: entries,
      options: options,
    );
  }

  try {
    await PrintDocumentTemplates.registry(
      ref: ref,
      context: context,
      title: l10n.billingPriceBookPrintTitle,
      previewDialogTitle: l10n.billingPriceBookPrintTitle,
      subtitle: buildSubtitle(),
      recordReference: PrintFormContextReference(
        label: l10n.billingPriceBookTab,
        value: l10n.billingPriceBookPrintRowCount(entries.length),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: BillingPriceBookPrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      footerNote: l10n.billingPriceBookPrintFooter,
    );
  } finally {
    options.dispose();
  }
}

String billingPriceBookListHtml(
  BuildContext context, {
  required List<BillingPriceBookEntry> entries,
  BillingPriceBookPrintOptionsController? options,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool includeSummary = options?.includeSummary ?? true;
  final bool includeRows = options?.includeRows ?? true;
  final bool includeFooter = options?.includeFooter ?? true;
  final StringBuffer buffer = StringBuffer();

  if (includeSummary) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPriceBookPrintSectionSummary,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(l10n.billingPriceBookPrintRowCount(entries.length))}</p>',
      ),
    );
  }

  if (includeRows) {
    final List<String> headers = <String>[
      l10n.billingPriceBookItemColumn,
      l10n.billingPriceBookModeColumn,
      l10n.billingPriceBookPriceColumn,
      l10n.billingPriceBookStatusColumn,
      l10n.billingPriceBookSchemeColumn,
      l10n.billingPriceBookEffectiveColumn,
    ];
    final List<List<String>> rows = <List<String>>[];
    for (final BillingPriceBookEntry entry in entries) {
      rows.add(<String>[
        billingPriceBookItemDisplayLabel(l10n, entry),
        billingPriceBookModeLabel(l10n, entry.paymentMode),
        billingPriceBookMoney(context, entry.unitPrice, entry.currency),
        entry.isActive
            ? l10n.billingPriceBookStatusActive
            : l10n.billingPriceBookStatusInactive,
        billingPriceBookSchemeDisplayLabel(l10n, entry),
        entry.effectiveFrom == null
            ? l10n.billingNotRecorded
            : _formatDate(entry.effectiveFrom!),
      ]);
    }
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPriceBookPrintSectionRows,
        bodyHtml: PrintFormTemplate.table(
          headers: headers,
          rows: rows,
          emptyText: l10n.billingPriceBookEmptyTitle,
        ),
      ),
    );
  }

  if (includeFooter) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPrintSectionFooter,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(l10n.billingPriceBookPrintFooter)}</p>',
      ),
    );
  }

  return buffer.toString();
}

String _formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
