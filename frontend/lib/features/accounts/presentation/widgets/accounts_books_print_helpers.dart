import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_books_print_options.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> printAccountsBooksPacket({
  required WidgetRef ref,
  required BuildContext context,
  required AccountsFiscalPeriod period,
}) async {
  final AccountsBooksPrintOptionsController options =
      AccountsBooksPrintOptionsController();
  final String title = AccountsStrings.detailTitlePeriod;
  final String periodLabel = period.effectiveLabel;

  String? buildSubtitle() {
    if (!options.includePeriod) {
      return null;
    }
    return '${AccountsStrings.statusColumn}: ${accountsPeriodStatusLabel(period)}';
  }

  String buildBodyHtml() {
    return accountsBooksHtml(period, options: options);
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
        label: AccountsStrings.periodColumn,
        value: periodLabel,
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: AccountsBooksPrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      includeSignatures: options.includeFooter,
      footerNote: AccountsStrings.booksPrintFooter,
    );
  } finally {
    options.dispose();
  }
}

String accountsBooksHtml(
  AccountsFiscalPeriod period, {
  AccountsBooksPrintOptionsController? options,
}) {
  final bool includePeriod = options?.includePeriod ?? true;
  final bool includeChecklist = options?.includeChecklist ?? true;
  final bool includeNotes = options?.includeNotes ?? true;
  final bool includeFooter = options?.includeFooter ?? true;
  final StringBuffer buffer = StringBuffer();

  if (includePeriod) {
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsStrings.booksPrintSectionPeriod,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.periodColumn,
            AccountsStrings.statusColumn,
            AccountsStrings.openedColumn,
            AccountsStrings.closedColumn,
            AccountsStrings.facilityColumn,
          ],
          rows: <List<String>>[
            <String>[
              period.effectiveLabel,
              accountsPeriodStatusLabel(period),
              _formatDateTime(period.openedAt),
              _formatDateTime(period.closedAt),
              period.publicFacilityLabel.isEmpty
                  ? AccountsStrings.unknownValue
                  : period.publicFacilityLabel,
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeChecklist) {
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsStrings.booksPrintSectionChecklist,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            AccountsStrings.periodUnpostedLabel,
            AccountsStrings.periodPendingApprovalsLabel,
            AccountsStrings.periodTrialSnapshotLabel,
          ],
          rows: <List<String>>[
            <String>[
              '${period.unpostedJournalCount}',
              '${period.pendingApprovalsCount}',
              AccountsStrings.periodTrialSnapshotValue,
            ],
          ],
          emptyText: AccountsStrings.unknownValue,
        ),
      ),
    );
  }

  if (includeNotes) {
    final String notes =
        accountsPublicLabel(period.notes) ?? AccountsStrings.notRecorded;
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsStrings.booksPrintSectionNotes,
        bodyHtml: '<p>${PrintFormTemplate.escape(notes)}</p>',
      ),
    );
  }

  if (includeFooter) {
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsStrings.booksPrintSectionFooter,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(AccountsStrings.booksPrintFooter)}</p>',
      ),
    );
  }

  return buffer.toString();
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return AccountsStrings.unknownValue;
  }
  final DateTime local = value.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
