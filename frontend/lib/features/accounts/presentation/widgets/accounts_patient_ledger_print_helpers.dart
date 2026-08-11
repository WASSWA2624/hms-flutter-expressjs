import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_patient_ledger_print_options.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

String accountsPatientPublicLabel({
  String? patientDisplayName,
  String? patientDisplayId,
  String? patientId,
}) {
  final String? name = accountsPublicLabel(patientDisplayName);
  final String? mrn =
      accountsPublicLabel(patientDisplayId) ?? accountsPublicLabel(patientId);
  if (name != null && mrn != null && name != mrn) {
    return '$name ($mrn)';
  }
  return name ?? mrn ?? AccountsStrings.patientColumn;
}

Future<void> printAccountsPatientLedgerPacket({
  required WidgetRef ref,
  required BuildContext context,
  required AccountsPatientLedger ledger,
  String? currency,
}) async {
  final AccountsPatientLedgerPrintOptionsController options =
      AccountsPatientLedgerPrintOptionsController();
  final String title = AccountsStrings.patientLedgerTitle;
  final String patientLabel = accountsPatientPublicLabel(
    patientDisplayName: ledger.patientDisplayName,
    patientDisplayId: ledger.patientDisplayId,
    patientId: ledger.patientId,
  );

  String? buildSubtitle() {
    if (!options.includeSummary) {
      return null;
    }
    return '${AccountsStrings.balanceColumn}: '
        '${accountsMoney(context, ledger.summary.balanceDue, currency)}';
  }

  String buildBodyHtml() {
    return accountsPatientLedgerHtml(
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
        label: AccountsStrings.patientColumn,
        value: patientLabel,
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: AccountsPatientLedgerPrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      includeSignatures: options.includeFooter,
      footerNote: 'Accounts patient ledger print',
    );
  } finally {
    options.dispose();
  }
}

String accountsPatientLedgerHtml(
  BuildContext context,
  AccountsPatientLedger ledger, {
  String? currency,
  AccountsPatientLedgerPrintOptionsController? options,
}) {
  final bool includePatient = options?.includePatient ?? true;
  final bool includeSummary = options?.includeSummary ?? true;
  final bool includeLines = options?.includeEntryLines ?? true;
  final StringBuffer buffer = StringBuffer();
  final String patientLabel = accountsPatientPublicLabel(
    patientDisplayName: ledger.patientDisplayName,
    patientDisplayId: ledger.patientDisplayId,
    patientId: ledger.patientId,
  );

  if (includePatient) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Patient',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.patientColumn,
            'MRN',
          ],
          rows: <List<String>>[
            <String>[
              accountsPublicLabel(ledger.patientDisplayName) ?? patientLabel,
              accountsPublicLabel(ledger.patientDisplayId) ??
                  AccountsStrings.unknownValue,
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeSummary) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Summary',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.invoicedColumn,
            AccountsStrings.paidColumn,
            AccountsStrings.balanceColumn,
          ],
          rows: <List<String>>[
            <String>[
              accountsMoney(context, ledger.summary.totalInvoiced, currency),
              accountsMoney(context, ledger.summary.netPaid, currency),
              accountsMoney(context, ledger.summary.balanceDue, currency),
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeLines) {
    final List<List<String>> rows = <List<String>>[
      for (final AccountsPatientLedgerEntry entry in ledger.entries)
        <String>[
          accountsPublicLabel(entry.displayId) ??
              AccountsStrings.unknownValue,
          accountsPublicLabel(entry.action) ?? '',
          accountsPublicLabel(entry.status) ?? '',
          accountsMoney(context, entry.amount, entry.currency ?? currency),
        ],
    ];
    buffer.write(
      PrintFormTemplate.section(
        title: 'Entry lines',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            'Reference',
            'Action',
            AccountsStrings.statusColumn,
            AccountsStrings.amountColumn,
          ],
          rows: rows,
          emptyText: AccountsStrings.patientLedgerEmpty,
        ),
      ),
    );
  }

  return buffer.toString();
}
