import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Account chart print sections (accounts.md §17).
enum AccountsChartPrintSection {
  summary,
  rows,
  footer,
}

final class AccountsChartPrintOptionsController extends ChangeNotifier {
  AccountsChartPrintOptionsController() {
    _selected = AccountsChartPrintSection.values.toSet();
  }

  late Set<AccountsChartPrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeSummary =>
      _selected.contains(AccountsChartPrintSection.summary);

  bool get includeRows => _selected.contains(AccountsChartPrintSection.rows);

  bool get includeFooter =>
      _selected.contains(AccountsChartPrintSection.footer);

  bool get canPrint => includeSummary || includeRows;

  void setSelection(Set<Object> selected) {
    final Set<AccountsChartPrintSection> next = selected
        .whereType<AccountsChartPrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class AccountsChartPrintOptionsSection extends StatelessWidget {
  const AccountsChartPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final AccountsChartPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: AccountsStrings.chartPrintOptionsSection,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: AccountsChartPrintSection.summary,
                  title: AccountsStrings.chartPrintSectionSummary,
                  icon: Icons.summarize_outlined,
                ),
                AppReportSectionData(
                  id: AccountsChartPrintSection.rows,
                  title: AccountsStrings.chartPrintSectionRows,
                  icon: Icons.list_alt_outlined,
                ),
                AppReportSectionData(
                  id: AccountsChartPrintSection.footer,
                  title: AccountsStrings.chartPrintSectionFooter,
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
