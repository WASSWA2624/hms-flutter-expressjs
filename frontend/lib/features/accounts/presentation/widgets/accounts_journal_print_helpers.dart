import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_print_options.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> printAccountsJournalPacket({
  required WidgetRef ref,
  required BuildContext context,
  required AccountsWorkItem item,
}) async {
  final bool hasSource =
      (item.reference ?? '').trim().isNotEmpty ||
      item.source.trim().isNotEmpty;
  final bool hasApprovals = item.isApproval ||
      (item.requestedByDisplayId ?? '').trim().isNotEmpty ||
      (item.requestReason ?? '').trim().isNotEmpty;
  final AccountsJournalPrintOptionsController options =
      AccountsJournalPrintOptionsController(
        hasSourceAttachments: hasSource,
        hasApprovals: hasApprovals,
      );
  final String title = AccountsStrings.detailTitleJournal;
  final String journalLabel = accountsWorkItemPublicId(item);

  String? buildSubtitle() {
    if (!options.includeSummary) {
      return null;
    }
    return '${AccountsStrings.statusColumn}: '
        '${accountsWorkItemStatusLabel(context, item)}';
  }

  String buildBodyHtml() {
    return accountsJournalHtml(context, item, options: options);
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
        label: AccountsStrings.journalColumn,
        value: journalLabel,
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: AccountsJournalPrintOptionsSection(
        controller: options,
        showSourceAttachments: hasSource,
        showApprovals: hasApprovals,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      includeSignatures: options.includeFooter,
      footerNote: 'Accounts journal print',
    );
  } finally {
    options.dispose();
  }
}

String accountsJournalHtml(
  BuildContext context,
  AccountsWorkItem item, {
  AccountsJournalPrintOptionsController? options,
}) {
  final bool includeSummary = options?.includeSummary ?? true;
  final bool includeLines = options?.includeLines ?? true;
  final bool includeSource = options?.includeSourceAttachments ?? true;
  final bool includeApprovals = options?.includeApprovals ?? true;
  final bool includeNotes = options?.includeNotes ?? false;
  final StringBuffer buffer = StringBuffer();

  if (includeSummary) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Journal summary',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.journalColumn,
            AccountsStrings.statusColumn,
            AccountsStrings.periodColumn,
            AccountsStrings.sourceColumn,
            AccountsStrings.amountColumn,
          ],
          rows: <List<String>>[
            <String>[
              accountsWorkItemPublicId(item),
              accountsWorkItemStatusLabel(context, item),
              accountsPublicLabel(item.periodLabel) ??
                  AccountsStrings.unknownValue,
              accountsPublicLabel(item.source) ?? AccountsStrings.unknownValue,
              accountsMoney(context, item.amount, item.currency),
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeLines) {
    final List<List<String>> lineRows;
    if (item.lines.isNotEmpty) {
      lineRows = <List<String>>[
        for (final AccountsJournalLineDraft line in item.lines)
          <String>[
            accountsPublicLabel(line.accountId) ??
                AccountsStrings.unknownValue,
            line.debit == 0
                ? ''
                : accountsMoney(context, line.debit, item.currency),
            line.credit == 0
                ? ''
                : accountsMoney(context, line.credit, item.currency),
            accountsPublicLabel(line.memo) ?? '',
          ],
      ];
    } else {
      final String account =
          accountsPublicLabel(item.accountDisplayId) ??
          accountsPublicLabel(item.accountLabel) ??
          AccountsStrings.unknownValue;
      lineRows = <List<String>>[
        <String>[
          account,
          accountsMoney(context, item.amount, item.currency),
          accountsMoney(context, 0, item.currency),
          accountsPublicLabel(item.reference) ??
              AccountsStrings.unknownValue,
        ],
      ];
    }
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsStrings.journalLinesLabel,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.accountColumn,
            'Debit',
            'Credit',
            AccountsStrings.journalMemoLabel,
          ],
          rows: lineRows,
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeSource &&
      (item.source.trim().isNotEmpty ||
          (item.reference ?? '').trim().isNotEmpty)) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Source / attachments',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.sourceColumn,
            'Reference',
          ],
          rows: <List<String>>[
            <String>[
              accountsPublicLabel(item.source) ?? AccountsStrings.unknownValue,
              accountsPublicLabel(item.reference) ??
                  AccountsStrings.unknownValue,
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeApprovals &&
      (item.isApproval ||
          (item.requestedByDisplayId ?? '').trim().isNotEmpty ||
          (item.requestReason ?? '').trim().isNotEmpty)) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Approvals',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.typeColumn,
            'Requested by',
            AccountsStrings.reasonColumn,
          ],
          rows: <List<String>>[
            <String>[
              accountsApprovalTypeLabel(item.approvalType),
              accountsPublicLabel(item.requestedByDisplayId) ??
                  AccountsStrings.unknownValue,
              accountsPublicLabel(item.requestReason) ??
                  AccountsStrings.unknownValue,
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeNotes && (item.requestReason ?? '').trim().isNotEmpty) {
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsStrings.notesLabel,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(accountsPublicLabel(item.requestReason) ?? item.requestReason!)}</p>',
      ),
    );
  }

  return buffer.toString();
}
