import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Account ledger (GL) print sections (accounts.md §17).
enum AccountsGlPrintSection {
  header,
  accountIdentity,
  periodFilter,
  balances,
  entryLines,
  footer,
}

final class AccountsGlPrintOptionsController extends ChangeNotifier {
  AccountsGlPrintOptionsController() {
    _selected = <AccountsGlPrintSection>{
      AccountsGlPrintSection.header,
      AccountsGlPrintSection.accountIdentity,
      AccountsGlPrintSection.periodFilter,
      AccountsGlPrintSection.balances,
      AccountsGlPrintSection.entryLines,
      AccountsGlPrintSection.footer,
    };
  }

  late Set<AccountsGlPrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeHeader =>
      _selected.contains(AccountsGlPrintSection.header);

  bool get includeAccountIdentity =>
      _selected.contains(AccountsGlPrintSection.accountIdentity);

  bool get includePeriodFilter =>
      _selected.contains(AccountsGlPrintSection.periodFilter);

  bool get includeBalances =>
      _selected.contains(AccountsGlPrintSection.balances);

  bool get includeEntryLines =>
      _selected.contains(AccountsGlPrintSection.entryLines);

  bool get includeFooter =>
      _selected.contains(AccountsGlPrintSection.footer);

  bool get canPrint =>
      includeAccountIdentity ||
      includePeriodFilter ||
      includeBalances ||
      includeEntryLines;

  void setSelection(Set<Object> selected) {
    final Set<AccountsGlPrintSection> next = selected
        .whereType<AccountsGlPrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class AccountsGlPrintOptionsSection extends StatelessWidget {
  const AccountsGlPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final AccountsGlPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: 'Print sections',
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: AccountsGlPrintSection.header,
                  title: 'Header / facility',
                  icon: Icons.apartment_outlined,
                ),
                AppReportSectionData(
                  id: AccountsGlPrintSection.accountIdentity,
                  title: 'Account identity',
                  icon: Icons.account_balance_outlined,
                ),
                AppReportSectionData(
                  id: AccountsGlPrintSection.periodFilter,
                  title: 'Period filter',
                  icon: Icons.date_range_outlined,
                ),
                AppReportSectionData(
                  id: AccountsGlPrintSection.balances,
                  title: 'Balances',
                  icon: Icons.payments_outlined,
                ),
                AppReportSectionData(
                  id: AccountsGlPrintSection.entryLines,
                  title: 'Entry lines',
                  icon: Icons.view_list_outlined,
                ),
                AppReportSectionData(
                  id: AccountsGlPrintSection.footer,
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
