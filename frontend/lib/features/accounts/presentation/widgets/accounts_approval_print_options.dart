import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Approval-packet print sections for Need approval Detail (accounts.md §17).
enum AccountsApprovalPrintSection {
  header,
  summary,
  requestFields,
  statusDecision,
  notes,
  footer,
}

final class AccountsApprovalPrintOptionsController extends ChangeNotifier {
  AccountsApprovalPrintOptionsController() {
    _selected = <AccountsApprovalPrintSection>{
      AccountsApprovalPrintSection.header,
      AccountsApprovalPrintSection.summary,
      AccountsApprovalPrintSection.requestFields,
      AccountsApprovalPrintSection.statusDecision,
      AccountsApprovalPrintSection.footer,
    };
  }

  late Set<AccountsApprovalPrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeHeader =>
      _selected.contains(AccountsApprovalPrintSection.header);

  bool get includeSummary =>
      _selected.contains(AccountsApprovalPrintSection.summary);

  bool get includeRequestFields =>
      _selected.contains(AccountsApprovalPrintSection.requestFields);

  bool get includeStatusDecision =>
      _selected.contains(AccountsApprovalPrintSection.statusDecision);

  bool get includeNotes =>
      _selected.contains(AccountsApprovalPrintSection.notes);

  bool get includeFooter =>
      _selected.contains(AccountsApprovalPrintSection.footer);

  bool get canPrint =>
      includeSummary ||
      includeRequestFields ||
      includeStatusDecision ||
      includeNotes;

  void setSelection(Set<Object> selected) {
    final Set<AccountsApprovalPrintSection> next = selected
        .whereType<AccountsApprovalPrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class AccountsApprovalPrintOptionsSection extends StatelessWidget {
  const AccountsApprovalPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final AccountsApprovalPrintOptionsController controller;

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
                  id: AccountsApprovalPrintSection.header,
                  title: 'Header / facility',
                  icon: Icons.apartment_outlined,
                ),
                AppReportSectionData(
                  id: AccountsApprovalPrintSection.summary,
                  title: 'Request summary',
                  icon: Icons.receipt_long_outlined,
                ),
                AppReportSectionData(
                  id: AccountsApprovalPrintSection.requestFields,
                  title: 'Request fields',
                  icon: Icons.rule_outlined,
                ),
                AppReportSectionData(
                  id: AccountsApprovalPrintSection.statusDecision,
                  title: 'Status / decision',
                  icon: Icons.fact_check_outlined,
                ),
                AppReportSectionData(
                  id: AccountsApprovalPrintSection.notes,
                  title: AccountsStrings.notesLabel,
                  icon: Icons.notes_outlined,
                ),
                AppReportSectionData(
                  id: AccountsApprovalPrintSection.footer,
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
