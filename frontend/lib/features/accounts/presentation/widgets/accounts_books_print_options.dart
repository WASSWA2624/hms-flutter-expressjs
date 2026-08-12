import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Close books / period print sections (accounts.md §17).
enum AccountsBooksPrintSection {
  header,
  period,
  checklist,
  notes,
  footer,
}

final class AccountsBooksPrintOptionsController extends ChangeNotifier {
  AccountsBooksPrintOptionsController() {
    _selected = AccountsBooksPrintSection.values.toSet();
  }

  late Set<AccountsBooksPrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeHeader =>
      _selected.contains(AccountsBooksPrintSection.header);

  bool get includePeriod =>
      _selected.contains(AccountsBooksPrintSection.period);

  bool get includeChecklist =>
      _selected.contains(AccountsBooksPrintSection.checklist);

  bool get includeNotes => _selected.contains(AccountsBooksPrintSection.notes);

  bool get includeFooter =>
      _selected.contains(AccountsBooksPrintSection.footer);

  bool get canPrint => includePeriod || includeChecklist || includeNotes;

  void setSelection(Set<Object> selected) {
    final Set<AccountsBooksPrintSection> next = selected
        .whereType<AccountsBooksPrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class AccountsBooksPrintOptionsSection extends StatelessWidget {
  const AccountsBooksPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final AccountsBooksPrintOptionsController controller;

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
                  id: AccountsBooksPrintSection.header,
                  title: AccountsStrings.booksPrintSectionHeader,
                  icon: Icons.apartment_outlined,
                ),
                AppReportSectionData(
                  id: AccountsBooksPrintSection.period,
                  title: AccountsStrings.booksPrintSectionPeriod,
                  icon: Icons.date_range_outlined,
                ),
                AppReportSectionData(
                  id: AccountsBooksPrintSection.checklist,
                  title: AccountsStrings.booksPrintSectionChecklist,
                  icon: Icons.checklist_outlined,
                ),
                AppReportSectionData(
                  id: AccountsBooksPrintSection.notes,
                  title: AccountsStrings.booksPrintSectionNotes,
                  icon: Icons.notes_outlined,
                ),
                AppReportSectionData(
                  id: AccountsBooksPrintSection.footer,
                  title: AccountsStrings.booksPrintSectionFooter,
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
