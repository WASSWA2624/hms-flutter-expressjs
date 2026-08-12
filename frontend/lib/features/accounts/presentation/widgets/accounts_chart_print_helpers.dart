import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_chart_account.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_print_options.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> printAccountsChartList({
  required WidgetRef ref,
  required BuildContext context,
  required List<AccountsChartAccount> accounts,
}) async {
  final AccountsChartPrintOptionsController options =
      AccountsChartPrintOptionsController();

  String? buildSubtitle() {
    if (!options.includeSummary) {
      return null;
    }
    return AccountsStrings.chartPrintRowCount(accounts.length);
  }

  String buildBodyHtml() {
    return accountsChartListHtml(
      context: context,
      accounts: accounts,
      options: options,
    );
  }

  try {
    await PrintDocumentTemplates.registry(
      ref: ref,
      context: context,
      title: AccountsStrings.chartPrintTitle,
      previewDialogTitle: AccountsStrings.chartPrintTitle,
      subtitle: buildSubtitle(),
      recordReference: PrintFormContextReference(
        label: AccountsStrings.accountChartLabel,
        value: AccountsStrings.chartPrintRowCount(accounts.length),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: AccountsChartPrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      footerNote: AccountsStrings.chartPrintFooter,
    );
  } finally {
    options.dispose();
  }
}

String accountsChartListHtml({
  required List<AccountsChartAccount> accounts,
  AccountsChartPrintOptionsController? options,
  BuildContext? context,
}) {
  final bool includeSummary = options?.includeSummary ?? true;
  final bool includeRows = options?.includeRows ?? true;
  final bool includeFooter = options?.includeFooter ?? true;
  final StringBuffer buffer = StringBuffer();

  if (includeSummary) {
    buffer.write(
      PrintFormTemplate.section(
        title: context?.l10n.commonPrintSummarySectionLabel ??
            AccountsStrings.chartPrintSectionSummary,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(AccountsStrings.chartPrintRowCount(accounts.length))}</p>',
      ),
    );
  }

  if (includeRows) {
    final List<List<String>> rows = <List<String>>[
      for (final AccountsChartAccount account in accounts)
        <String>[
          accountsPublicLabel(account.accountLabel) ??
              AccountsStrings.unknownValue,
          accountsChartTypeLabel(account.accountType),
          accountsPublicLabel(account.code) ?? AccountsStrings.unknownValue,
          account.isActive
              ? AccountsStrings.chartStatusActive
              : AccountsStrings.chartStatusInactive,
          accountsPublicLabel(account.parentLabel) ??
              AccountsStrings.unknownValue,
          accountsPublicLabel(account.currency) ??
              AccountsStrings.unknownValue,
        ],
    ];
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsStrings.chartPrintSectionRows,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.accountColumn,
            AccountsStrings.typeColumn,
            AccountsStrings.chartCodeColumn,
            AccountsStrings.statusColumn,
            AccountsStrings.chartParentColumn,
            AccountsStrings.chartCurrencyColumn,
          ],
          rows: rows,
          emptyText: AccountsStrings.chartEmpty,
        ),
      ),
    );
  }

  if (includeFooter) {
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsStrings.chartPrintSectionFooter,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(AccountsStrings.chartPrintFooter)}</p>',
      ),
    );
  }

  return buffer.toString();
}
