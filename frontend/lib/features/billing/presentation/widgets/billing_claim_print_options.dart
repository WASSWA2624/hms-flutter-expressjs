import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Claim / pre-auth print sections (billing.md §17).
enum BillingClaimPrintSection {
  invoice,
  claimFields,
  statusDecision,
  notes,
  footer,
}

/// Mutable claim print-section state for live preview rebuilds.
final class BillingClaimPrintOptionsController extends ChangeNotifier {
  BillingClaimPrintOptionsController() {
    _selected = <BillingClaimPrintSection>{
      BillingClaimPrintSection.invoice,
      BillingClaimPrintSection.claimFields,
      BillingClaimPrintSection.statusDecision,
      BillingClaimPrintSection.footer,
    };
  }

  late Set<BillingClaimPrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeInvoice =>
      _selected.contains(BillingClaimPrintSection.invoice);

  bool get includeClaimFields =>
      _selected.contains(BillingClaimPrintSection.claimFields);

  bool get includeStatusDecision =>
      _selected.contains(BillingClaimPrintSection.statusDecision);

  bool get includeNotes => _selected.contains(BillingClaimPrintSection.notes);

  bool get includeFooter =>
      _selected.contains(BillingClaimPrintSection.footer);

  bool get canPrint =>
      includeInvoice ||
      includeClaimFields ||
      includeStatusDecision ||
      includeNotes;

  void setSelection(Set<Object> selected) {
    final Set<BillingClaimPrintSection> next = selected
        .whereType<BillingClaimPrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class BillingClaimPrintOptionsSection extends StatelessWidget {
  const BillingClaimPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final BillingClaimPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: l10n.billingClaimPrintOptionsSectionLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: BillingClaimPrintSection.invoice,
                  title: l10n.billingInvoiceLabel,
                  icon: Icons.receipt_long_outlined,
                ),
                AppReportSectionData(
                  id: BillingClaimPrintSection.claimFields,
                  title: l10n.billingPrintSectionClaimFields,
                  icon: Icons.health_and_safety_outlined,
                ),
                AppReportSectionData(
                  id: BillingClaimPrintSection.statusDecision,
                  title: l10n.billingPrintSectionStatusDecision,
                  icon: Icons.rule_outlined,
                ),
                AppReportSectionData(
                  id: BillingClaimPrintSection.notes,
                  title: l10n.billingNotesLabel,
                  icon: Icons.notes_outlined,
                ),
                AppReportSectionData(
                  id: BillingClaimPrintSection.footer,
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
