import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

enum AccountsInvoicePrintSection {
  items,
  notes,
  footer,
}

/// Mutable invoice print-section state for live preview rebuilds.
final class AccountsInvoicePrintOptionsController extends ChangeNotifier {
  AccountsInvoicePrintOptionsController({bool hasNotes = false}) {
    _selected = <AccountsInvoicePrintSection>{
      AccountsInvoicePrintSection.items,
      if (hasNotes) AccountsInvoicePrintSection.notes,
      AccountsInvoicePrintSection.footer,
    };
  }

  late Set<AccountsInvoicePrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeItems =>
      _selected.contains(AccountsInvoicePrintSection.items);

  bool get includeNotes =>
      _selected.contains(AccountsInvoicePrintSection.notes);

  bool get includeFooter =>
      _selected.contains(AccountsInvoicePrintSection.footer);

  bool get canPrint => includeItems || includeNotes;

  void setSelection(Set<Object> selected) {
    final Set<AccountsInvoicePrintSection> next = selected
        .whereType<AccountsInvoicePrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class AccountsInvoicePrintOptionsSection extends StatelessWidget {
  const AccountsInvoicePrintOptionsSection({
    required this.controller,
    this.showNotes = false,
    super.key,
  });

  final AccountsInvoicePrintOptionsController controller;
  final bool showNotes;

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
                const AppReportSectionData(
                  id: AccountsInvoicePrintSection.items,
                  title: AccountsStrings.invoiceItemsSectionTitle,
                  icon: Icons.list_alt_outlined,
                ),
                if (showNotes)
                  const AppReportSectionData(
                    id: AccountsInvoicePrintSection.notes,
                    title: AccountsStrings.notesLabel,
                    icon: Icons.notes_outlined,
                  ),
                const AppReportSectionData(
                  id: AccountsInvoicePrintSection.footer,
                  title: AccountsStrings.invoicePrintSectionFooter,
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
