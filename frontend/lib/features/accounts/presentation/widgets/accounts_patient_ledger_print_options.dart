import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Patient ledger print sections (accounts.md §17).
enum AccountsPatientLedgerPrintSection {
  header,
  patient,
  summary,
  entryLines,
  footer,
}

final class AccountsPatientLedgerPrintOptionsController extends ChangeNotifier {
  AccountsPatientLedgerPrintOptionsController() {
    _selected = <AccountsPatientLedgerPrintSection>{
      AccountsPatientLedgerPrintSection.header,
      AccountsPatientLedgerPrintSection.patient,
      AccountsPatientLedgerPrintSection.summary,
      AccountsPatientLedgerPrintSection.entryLines,
      AccountsPatientLedgerPrintSection.footer,
    };
  }

  late Set<AccountsPatientLedgerPrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeHeader =>
      _selected.contains(AccountsPatientLedgerPrintSection.header);

  bool get includePatient =>
      _selected.contains(AccountsPatientLedgerPrintSection.patient);

  bool get includeSummary =>
      _selected.contains(AccountsPatientLedgerPrintSection.summary);

  bool get includeEntryLines =>
      _selected.contains(AccountsPatientLedgerPrintSection.entryLines);

  bool get includeFooter =>
      _selected.contains(AccountsPatientLedgerPrintSection.footer);

  bool get canPrint => includePatient || includeSummary || includeEntryLines;

  void setSelection(Set<Object> selected) {
    final Set<AccountsPatientLedgerPrintSection> next = selected
        .whereType<AccountsPatientLedgerPrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class AccountsPatientLedgerPrintOptionsSection extends StatelessWidget {
  const AccountsPatientLedgerPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final AccountsPatientLedgerPrintOptionsController controller;

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
                  id: AccountsPatientLedgerPrintSection.header,
                  title: 'Header / facility',
                  icon: Icons.apartment_outlined,
                ),
                AppReportSectionData(
                  id: AccountsPatientLedgerPrintSection.patient,
                  title: 'Patient',
                  icon: Icons.person_outline,
                ),
                AppReportSectionData(
                  id: AccountsPatientLedgerPrintSection.summary,
                  title: 'Summary',
                  icon: Icons.payments_outlined,
                ),
                AppReportSectionData(
                  id: AccountsPatientLedgerPrintSection.entryLines,
                  title: 'Entry lines',
                  icon: Icons.view_list_outlined,
                ),
                AppReportSectionData(
                  id: AccountsPatientLedgerPrintSection.footer,
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
