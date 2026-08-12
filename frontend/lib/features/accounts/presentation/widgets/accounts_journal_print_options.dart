import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Journal / Detail print sections (accounts.md §17).
enum AccountsJournalPrintSection {
  header,
  summary,
  lines,
  sourceAttachments,
  approvals,
  notes,
  footer,
}

/// Mutable journal print-section state for live preview rebuilds.
final class AccountsJournalPrintOptionsController extends ChangeNotifier {
  AccountsJournalPrintOptionsController({
    bool hasSourceAttachments = false,
    bool hasApprovals = false,
  }) {
    _selected = <AccountsJournalPrintSection>{
      AccountsJournalPrintSection.header,
      AccountsJournalPrintSection.summary,
      AccountsJournalPrintSection.lines,
      if (hasSourceAttachments) AccountsJournalPrintSection.sourceAttachments,
      if (hasApprovals) AccountsJournalPrintSection.approvals,
      AccountsJournalPrintSection.footer,
    };
  }

  late Set<AccountsJournalPrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeHeader =>
      _selected.contains(AccountsJournalPrintSection.header);

  bool get includeSummary =>
      _selected.contains(AccountsJournalPrintSection.summary);

  bool get includeLines =>
      _selected.contains(AccountsJournalPrintSection.lines);

  bool get includeSourceAttachments =>
      _selected.contains(AccountsJournalPrintSection.sourceAttachments);

  bool get includeApprovals =>
      _selected.contains(AccountsJournalPrintSection.approvals);

  bool get includeNotes =>
      _selected.contains(AccountsJournalPrintSection.notes);

  bool get includeFooter =>
      _selected.contains(AccountsJournalPrintSection.footer);

  bool get canPrint =>
      includeSummary ||
      includeLines ||
      includeSourceAttachments ||
      includeApprovals ||
      includeNotes;

  void setSelection(Set<Object> selected) {
    final Set<AccountsJournalPrintSection> next = selected
        .whereType<AccountsJournalPrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class AccountsJournalPrintOptionsSection extends StatelessWidget {
  const AccountsJournalPrintOptionsSection({
    required this.controller,
    this.showSourceAttachments = false,
    this.showApprovals = false,
    super.key,
  });

  final AccountsJournalPrintOptionsController controller;
  final bool showSourceAttachments;
  final bool showApprovals;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: context.l10n.commonPrintSectionsLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: AccountsJournalPrintSection.header,
                  title: 'Header / facility',
                  icon: Icons.apartment_outlined,
                ),
                AppReportSectionData(
                  id: AccountsJournalPrintSection.summary,
                  title: 'Journal summary',
                  icon: Icons.receipt_long_outlined,
                ),
                AppReportSectionData(
                  id: AccountsJournalPrintSection.lines,
                  title: 'Lines',
                  icon: Icons.view_list_outlined,
                ),
                if (showSourceAttachments)
                  AppReportSectionData(
                    id: AccountsJournalPrintSection.sourceAttachments,
                    title: 'Source / attachments',
                    icon: Icons.attach_file_outlined,
                  ),
                if (showApprovals)
                  AppReportSectionData(
                    id: AccountsJournalPrintSection.approvals,
                    title: 'Approvals',
                    icon: Icons.rule_outlined,
                  ),
                AppReportSectionData(
                  id: AccountsJournalPrintSection.notes,
                  title: AccountsStrings.notesLabel,
                  icon: Icons.notes_outlined,
                ),
                AppReportSectionData(
                  id: AccountsJournalPrintSection.footer,
                  title: 'Footer / signature',
                  icon: Icons.draw_outlined,
                ),
              ],
              selectedIds: controller.selectedIds,
              onSelectionChanged: controller.setSelection,
            ),
            SizedBox(height: theme.spacing.xs),
          ],
        );
      },
    );
  }
}
