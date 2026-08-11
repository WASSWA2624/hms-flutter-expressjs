import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_approval_print_options.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_approvals_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> printAccountsApprovalPacket({
  required WidgetRef ref,
  required BuildContext context,
  required AccountsWorkItem item,
}) async {
  final AccountsApprovalPrintOptionsController options =
      AccountsApprovalPrintOptionsController();
  final String title = AccountsStrings.detailTitleApproval;
  final String journalLabel = accountsWorkItemPublicId(item);

  String? buildSubtitle() {
    if (!options.includeSummary) {
      return null;
    }
    return '${AccountsStrings.statusColumn}: '
        '${accountsApprovalsStatusLabel(item)}';
  }

  String buildBodyHtml() {
    return accountsApprovalHtml(context, item, options: options);
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
      previewSectionsExtra: AccountsApprovalPrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      includeSignatures: options.includeFooter,
      footerNote: 'Accounts approval print',
    );
  } finally {
    options.dispose();
  }
}

String accountsApprovalHtml(
  BuildContext context,
  AccountsWorkItem item, {
  AccountsApprovalPrintOptionsController? options,
}) {
  final bool includeSummary = options?.includeSummary ?? true;
  final bool includeRequest = options?.includeRequestFields ?? true;
  final bool includeStatus = options?.includeStatusDecision ?? true;
  final bool includeNotes = options?.includeNotes ?? false;
  final StringBuffer buffer = StringBuffer();

  if (includeSummary) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Request summary',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.journalColumn,
            AccountsStrings.typeColumn,
            AccountsStrings.statusColumn,
            AccountsStrings.periodColumn,
            AccountsStrings.amountColumn,
          ],
          rows: <List<String>>[
            <String>[
              accountsWorkItemPublicId(item),
              accountsApprovalsTypeLabel(item.approvalType),
              accountsApprovalsStatusLabel(item),
              accountsPublicLabel(item.periodLabel) ??
                  AccountsStrings.unknownValue,
              accountsMoney(context, item.amount, item.currency),
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeRequest) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Request fields',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.typeColumn,
            AccountsStrings.byColumn,
            AccountsStrings.reasonColumn,
            'Reference',
          ],
          rows: <List<String>>[
            <String>[
              accountsApprovalsTypeLabel(item.approvalType),
              accountsPublicLabel(item.requestedByDisplayId) ??
                  AccountsStrings.unknownValue,
              accountsPublicLabel(item.requestReason) ??
                  AccountsStrings.unknownValue,
              accountsPublicLabel(item.reference) ??
                  AccountsStrings.unknownValue,
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeStatus) {
    buffer.write(
      PrintFormTemplate.section(
        title: 'Status / decision',
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.statusColumn,
            AccountsStrings.typeColumn,
          ],
          rows: <List<String>>[
            <String>[
              accountsApprovalsStatusLabel(item),
              accountsApprovalsTypeLabel(item.approvalType),
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
            '<p>${PrintFormTemplate.escape(accountsPublicLabel(item.requestReason) ?? AccountsStrings.unknownValue)}</p>',
      ),
    );
  }

  return buffer.toString();
}
