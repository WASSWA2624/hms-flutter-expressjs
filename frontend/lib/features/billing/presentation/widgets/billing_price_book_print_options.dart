import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Price list print sections (billing.md §17).
enum BillingPriceBookPrintSection {
  summary,
  rows,
  footer,
}

/// Mutable price-list print-section state for live preview rebuilds.
final class BillingPriceBookPrintOptionsController extends ChangeNotifier {
  BillingPriceBookPrintOptionsController() {
    _selected = BillingPriceBookPrintSection.values.toSet();
  }

  late Set<BillingPriceBookPrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeSummary =>
      _selected.contains(BillingPriceBookPrintSection.summary);

  bool get includeRows =>
      _selected.contains(BillingPriceBookPrintSection.rows);

  bool get includeFooter =>
      _selected.contains(BillingPriceBookPrintSection.footer);

  bool get canPrint => includeSummary || includeRows;

  void setSelection(Set<Object> selected) {
    final Set<BillingPriceBookPrintSection> next = selected
        .whereType<BillingPriceBookPrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class BillingPriceBookPrintOptionsSection extends StatelessWidget {
  const BillingPriceBookPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final BillingPriceBookPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: l10n.billingPriceBookPrintOptionsSectionLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: BillingPriceBookPrintSection.summary,
                  title: l10n.billingPriceBookPrintSectionSummary,
                  icon: Icons.summarize_outlined,
                ),
                AppReportSectionData(
                  id: BillingPriceBookPrintSection.rows,
                  title: l10n.billingPriceBookPrintSectionRows,
                  icon: Icons.list_alt_outlined,
                ),
                AppReportSectionData(
                  id: BillingPriceBookPrintSection.footer,
                  title: l10n.billingPrintSectionFooter,
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
