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

  String buildBodyHtml() {
    return accountsInvoiceHtml(context, invoice, options: options);
  }

  try {
    await PrintDocumentTemplates.invoice(
      ref: ref,
      context: context,
      title: AccountsStrings.invoicePrintTitle,
      previewDialogTitle: context.l10n.printPreviewTitle,
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

String accountsInvoiceHtml(
  BuildContext context,
  AccountsInvoice invoice, {
  AccountsInvoicePrintOptionsController? options,
}) {
  final bool includeItems = options?.includeItems ?? true;
  final bool includeNotes = options?.includeNotes ?? true;
  final StringBuffer buffer = StringBuffer();

  if (includeItems) {
    // Unwrapped table — no surrounding Items section chrome.
    buffer.write(_invoiceItemsTableHtml(context, invoice));
  }

  if (includeNotes && (invoice.notes ?? '').trim().isNotEmpty) {
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
