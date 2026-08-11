import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_print_options.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> printAccountsGlLedgerPacket({
  required WidgetRef ref,
  required BuildContext context,
  required AccountsGlLedger ledger,
  String? currency,
}) async {
  final AccountsGlPrintOptionsController options =
      AccountsGlPrintOptionsController();
  final String title = AccountsStrings.accountLedgerTitle;
  final String accountLabel = accountsGlAccountPublicLabel(ledger.account);

  String? buildSubtitle() {
    if (!options.includeBalances) {
      return null;
    }
    return '${AccountsStrings.balanceColumn}: '
        '${accountsMoney(context, ledger.summary.balance, currency)}';
  }

  String buildBodyHtml() {
    return accountsGlLedgerHtml(
      context,
      ledger,
      currency: currency,
      options: options,
    );
  }

  try {
    await PrintDocumentTemplates.claimStatement(
      ref: ref,
      context: context,
      title: title,
      previewDialogTitle: title,
      subtitle: buildSubtitle(),
      subtitleBuilder: buildSubtitle,
      patientContext: null,
      claimReference: PrintFormContextReference(
        label: AccountsStrings.accountColumn,
        value: accountLabel,
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: AccountsGlPrintOptionsSection(controller: options),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      includeSignatures: options.includeFooter,
      footerNote: 'Accounts general ledger print',
    );
  } finally {
    options.dispose();
  }
}

String accountsGlAccountPublicLabel(AccountsGlAccount account) {
  return accountsPublicLabel(account.code) != null ||
          accountsPublicLabel(account.name) != null
      ? account.accountLabel
      : accountsPublicLabel(account.displayId) ??
            AccountsStrings.accountColumn;
}

String accountsGlLedgerHtml(
  BuildContext context,
  AccountsGlLedger ledger, {
  String? currency,
  AccountsGlPrintOptionsController? options,
}) {
  final bool includeIdentity = options?.includeAccountIdentity ?? true;
  final bool includePeriod = options?.includePeriodFilter ?? true;
  final bool includeBalances = options?.includeBalances ?? true;
  final bool includeLines = options?.includeEntryLines ?? true;
  final StringBuffer buffer = StringBuffer();
  final AccountsGlAccount account = ledger.account;
  final String accountLabel = accountsGlAccountPublicLabel(account);

  if (includeIdentity) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Account identity',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.accountColumn,
            AccountsStrings.typeColumn,
            'Code',
          ],
          rows: <List<String>>[
            <String>[
              accountLabel,
              accountsPublicLabel(account.type) ??
                  AccountsStrings.unknownValue,
              accountsPublicLabel(account.code) ??
                  AccountsStrings.unknownValue,
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includePeriod) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Period filter',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[AccountsStrings.periodColumn],
          rows: <List<String>>[
            <String>[
              accountsPublicLabel(account.period) ??
                  AccountsStrings.unknownValue,
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeBalances) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Balances',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.debitColumn,
            AccountsStrings.creditColumn,
            AccountsStrings.balanceColumn,
          ],
          rows: <List<String>>[
            <String>[
              accountsMoney(context, ledger.summary.debit, currency),
              accountsMoney(context, ledger.summary.credit, currency),
              accountsMoney(context, ledger.summary.balance, currency),
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeLines) {
    final List<List<String>> rows = <List<String>>[
      for (final AccountsGlLedgerEntry entry in ledger.entries)
        <String>[
          accountsPublicLabel(entry.journal) ??
              AccountsStrings.unknownValue,
          accountsPublicLabel(entry.reference) ?? '',
          accountsPublicLabel(entry.memo) ?? '',
          entry.debit == 0
              ? ''
              : accountsMoney(context, entry.debit, currency),
          entry.credit == 0
              ? ''
              : accountsMoney(context, entry.credit, currency),
        ],
    ];
    buffer.write(
      PrintFormTemplate.section(
        title: 'Entry lines',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.journalColumn,
            'Reference',
            AccountsStrings.journalMemoLabel,
            AccountsStrings.debitColumn,
            AccountsStrings.creditColumn,
          ],
          rows: rows,
          emptyText: AccountsStrings.accountLedgerEmpty,
        ),
      ),
    );
  }

  return buffer.toString();
}
