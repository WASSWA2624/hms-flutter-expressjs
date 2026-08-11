import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Approval packet print sections (billing.md §17).
enum BillingApprovalPrintSection {
  invoice,
  requestFields,
  statusDecision,
  notes,
  footer,
}

/// Mutable approval print-section state for live preview rebuilds.
final class BillingApprovalPrintOptionsController extends ChangeNotifier {
  BillingApprovalPrintOptionsController() {
    _selected = <BillingApprovalPrintSection>{
      BillingApprovalPrintSection.invoice,
      BillingApprovalPrintSection.requestFields,
      BillingApprovalPrintSection.statusDecision,
      BillingApprovalPrintSection.notes,
      BillingApprovalPrintSection.footer,
    };
  }

  late Set<BillingApprovalPrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeInvoice =>
      _selected.contains(BillingApprovalPrintSection.invoice);

  bool get includeRequestFields =>
      _selected.contains(BillingApprovalPrintSection.requestFields);

  bool get includeStatusDecision =>
      _selected.contains(BillingApprovalPrintSection.statusDecision);

  bool get includeNotes =>
      _selected.contains(BillingApprovalPrintSection.notes);

  bool get includeFooter =>
      _selected.contains(BillingApprovalPrintSection.footer);

  bool get canPrint =>
      includeInvoice ||
      includeRequestFields ||
      includeStatusDecision ||
      includeNotes;

  void setSelection(Set<Object> selected) {
    final Set<BillingApprovalPrintSection> next = selected
        .whereType<BillingApprovalPrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class BillingApprovalPrintOptionsSection extends StatelessWidget {
  const BillingApprovalPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final BillingApprovalPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: l10n.billingApprovalPrintOptionsSectionLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: BillingApprovalPrintSection.invoice,
                  title: l10n.billingInvoiceLabel,
                  icon: Icons.receipt_long_outlined,
                ),
                AppReportSectionData(
                  id: BillingApprovalPrintSection.requestFields,
                  title: l10n.billingPrintSectionRequestFields,
                  icon: Icons.rule_outlined,
                ),
                AppReportSectionData(
                  id: BillingApprovalPrintSection.statusDecision,
                  title: l10n.billingPrintSectionStatusDecision,
                  icon: Icons.fact_check_outlined,
                ),
                AppReportSectionData(
                  id: BillingApprovalPrintSection.notes,
                  title: l10n.billingNotesLabel,
                  icon: Icons.notes_outlined,
                ),
                AppReportSectionData(
                  id: BillingApprovalPrintSection.footer,
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
