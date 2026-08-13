import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_invoice_print_options.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> printAccountsInvoice({
  required WidgetRef ref,
  required BuildContext context,
  required AccountsInvoice invoice,
}) async {
  final bool hasNotes = (invoice.notes ?? '').trim().isNotEmpty;
  final AccountsInvoicePrintOptionsController options =
      AccountsInvoicePrintOptionsController(hasNotes: hasNotes);

  String? buildSubtitle() {
    if (!options.includeSummary) {
      return null;
    }
    return accountsInvoiceSubtitle(context, invoice);
  }

  String buildBodyHtml() {
    return accountsInvoiceHtml(context, invoice, options: options);
  }

  try {
    await PrintDocumentTemplates.invoice(
      ref: ref,
      context: context,
      title: AccountsStrings.invoicePrintTitle,
      previewDialogTitle: context.l10n.printPreviewTitle,
      subtitle: buildSubtitle(),
      subtitleBuilder: buildSubtitle,
      patientContext: buildPrintFormPatientContext(
        context.l10n,
        patientName: invoice.payee,
        patientNameLabel: AccountsStrings.invoicePayeeLabel,
        patientId: invoice.effectiveNumber == '—'
            ? null
            : invoice.effectiveNumber,
        patientIdLabel: AccountsStrings.invoiceNumberColumn,
        encounterId: accountsDateTime(context, invoice.invoiceDate),
        encounterIdLabel: AccountsStrings.invoiceDateLabel,
      ),
      invoiceReference: PrintFormContextReference(
        label: AccountsStrings.invoiceNumberColumn,
        value: invoice.effectiveNumber,
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: AccountsInvoicePrintOptionsSection(
        controller: options,
        showNotes: hasNotes,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      includeSignatures: options.includeFooter,
      footerNote: AccountsStrings.invoicePrintFooterNote,
    );
  } finally {
    options.dispose();
  }
}

String accountsInvoiceSubtitle(BuildContext context, AccountsInvoice invoice) {
  return _invoiceSubtitleItems(context, invoice)
      .map((PrintFormMetadataItem entry) => '${entry.label}: ${entry.value};')
      .join(' , ');
}

String accountsInvoiceHtml(
  BuildContext context,
  AccountsInvoice invoice, {
  AccountsInvoicePrintOptionsController? options,
}) {
  final bool includeSummary = options?.includeSummary ?? true;
  final bool includeItems = options?.includeItems ?? true;
  final bool includeNotes = options?.includeNotes ?? true;
  final StringBuffer buffer = StringBuffer();

  if (includeSummary) {
    // Flat "Label: value" lines — no card-like key/value grid.
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsStrings.invoiceSummarySectionTitle,
        bodyHtml: PrintFormTemplate.unorderedList(
          <String>[
            for (final PrintFormMetadataItem item
                in _invoiceSummaryItems(context, invoice))
              '${item.label}: ${item.value}',
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeItems) {
    // Unwrapped table — no surrounding Items section chrome.
    buffer.write(_invoiceItemsTableHtml(context, invoice));
  }

  if (includeNotes &&
      !includeSummary &&
      (invoice.notes ?? '').trim().isNotEmpty) {
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsStrings.notesLabel,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(invoice.notes!.trim())}</p>',
      ),
    );
  }

  return buffer.toString();
}

List<PrintFormMetadataItem> _invoiceSubtitleItems(
  BuildContext context,
  AccountsInvoice invoice,
) {
  return <PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: AccountsStrings.statusColumn,
      value: accountsStatusLabel(invoice.status),
    ),
    PrintFormMetadataItem(
      label: AccountsStrings.invoiceGrandTotalLabel,
      value: accountsMoney(context, invoice.totalAmount, invoice.currency),
    ),
  ];
}

List<PrintFormMetadataItem> _invoiceSummaryItems(
  BuildContext context,
  AccountsInvoice invoice,
) {
  return <PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: AccountsStrings.invoiceNumberColumn,
      value: invoice.effectiveNumber,
    ),
    PrintFormMetadataItem(
      label: AccountsStrings.invoicePayeeLabel,
      value: invoice.payee,
    ),
    PrintFormMetadataItem(
      label: AccountsStrings.invoiceDateLabel,
      value: accountsDateTime(context, invoice.invoiceDate),
    ),
    PrintFormMetadataItem(
      label: AccountsStrings.statusColumn,
      value: accountsStatusLabel(invoice.status),
    ),
    PrintFormMetadataItem(
      label: AccountsStrings.invoiceCurrencyLabel,
      value: invoice.currency,
    ),
    PrintFormMetadataItem(
      label: AccountsStrings.invoiceGrandTotalLabel,
      value: accountsMoney(context, invoice.totalAmount, invoice.currency),
    ),
    if ((invoice.reference ?? '').trim().isNotEmpty)
      PrintFormMetadataItem(
        label: AccountsStrings.invoiceReferenceLabel,
        value: invoice.reference!.trim(),
      ),
    if ((invoice.notes ?? '').trim().isNotEmpty)
      PrintFormMetadataItem(
        label: AccountsStrings.notesLabel,
        value: invoice.notes!.trim(),
      ),
    if (invoice.isVoided && (invoice.voidReason ?? '').trim().isNotEmpty)
      PrintFormMetadataItem(
        label: AccountsStrings.reasonLabel,
        value: invoice.voidReason!.trim(),
      ),
  ];
}

String _invoiceItemsTableHtml(BuildContext context, AccountsInvoice invoice) {
  final List<String> headers = <String>[
    AccountsStrings.invoicePrintRowNumberColumn,
    AccountsStrings.invoiceItemNameLabel,
    AccountsStrings.invoiceItemDescriptionLabel,
    AccountsStrings.invoiceItemQuantityLabel,
    AccountsStrings.invoiceItemUnitPriceLabel,
    AccountsStrings.invoiceItemLineTotalLabel,
  ];

  final List<List<String>> rows = <List<String>>[];
  for (var index = 0; index < invoice.items.length; index += 1) {
    final AccountsInvoiceLineItem item = invoice.items[index];
    final String? description = item.description?.trim();
    rows.add(<String>[
      '${index + 1}',
      item.name,
      description != null && description.isNotEmpty
          ? description
          : AccountsStrings.unknownValue,
      '${item.quantity}',
      accountsMoney(context, item.unitPrice, invoice.currency),
      accountsMoney(context, item.effectiveLineTotal, invoice.currency),
    ]);
  }

  final List<String>? footerRow = rows.isEmpty
      ? null
      : <String>[
          '',
          AccountsStrings.invoiceGrandTotalLabel,
          AccountsStrings.invoiceItemsCountLabel(invoice.items.length),
          '',
          '',
          accountsMoney(context, invoice.totalAmount, invoice.currency),
        ];

  return PrintFormTemplate.table(
    headers: headers,
    rows: rows,
    emptyText: AccountsStrings.invoiceItemsEmpty,
    footerRow: footerRow,
  );
}
