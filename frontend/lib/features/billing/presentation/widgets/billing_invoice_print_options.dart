import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

enum BillingInvoicePrintSection {
  invoiceSummary,
  lineItems,
  payments,
  adjustments,
  insurance,
  notes,
  footer,
}

/// Mutable invoice print-section state for live preview rebuilds.
final class BillingInvoicePrintOptionsController extends ChangeNotifier {
  BillingInvoicePrintOptionsController(this.item) {
    _selected = <BillingInvoicePrintSection>{
      BillingInvoicePrintSection.invoiceSummary,
      BillingInvoicePrintSection.lineItems,
      if (item.payments.isNotEmpty) BillingInvoicePrintSection.payments,
      if (item.adjustments.isNotEmpty) BillingInvoicePrintSection.adjustments,
      if (item.totalPatientShare > 0 || item.totalInsurerShare > 0)
        BillingInvoicePrintSection.insurance,
      BillingInvoicePrintSection.footer,
    };
  }

  final BillingWorkItem item;
  late Set<BillingInvoicePrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includeInvoiceSummary =>
      _selected.contains(BillingInvoicePrintSection.invoiceSummary);

  bool get includeLineItems =>
      _selected.contains(BillingInvoicePrintSection.lineItems);

  bool get includePayments =>
      _selected.contains(BillingInvoicePrintSection.payments);

  bool get includeAdjustments =>
      _selected.contains(BillingInvoicePrintSection.adjustments);

  bool get includeInsurance =>
      _selected.contains(BillingInvoicePrintSection.insurance);

  bool get includeNotes => _selected.contains(BillingInvoicePrintSection.notes);

  bool get includeFooter =>
      _selected.contains(BillingInvoicePrintSection.footer);

  bool get canPrint =>
      includeLineItems ||
      includePayments ||
      includeAdjustments ||
      includeInsurance ||
      includeNotes ||
      includeInvoiceSummary;

  void setSelection(Set<Object> selected) {
    final Set<BillingInvoicePrintSection> next = selected
        .whereType<BillingInvoicePrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class BillingInvoicePrintOptionsSection extends StatelessWidget {
  const BillingInvoicePrintOptionsSection({
    required this.controller,
    super.key,
  });

  final BillingInvoicePrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: l10n.billingPrintOptionsSectionLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: BillingInvoicePrintSection.invoiceSummary,
                  title: l10n.billingPrintSectionInvoiceSummary,
                  icon: Icons.receipt_long_outlined,
                ),
                AppReportSectionData(
                  id: BillingInvoicePrintSection.lineItems,
                  title: l10n.billingLineItemsTitle,
                  icon: Icons.list_alt_outlined,
                ),
                AppReportSectionData(
                  id: BillingInvoicePrintSection.payments,
                  title: l10n.billingPaymentsTitle,
                  icon: Icons.payments_outlined,
                ),
                AppReportSectionData(
                  id: BillingInvoicePrintSection.adjustments,
                  title: l10n.billingAdjustmentsTitle,
                  icon: Icons.tune_outlined,
                ),
                AppReportSectionData(
                  id: BillingInvoicePrintSection.insurance,
                  title: l10n.billingPrintSectionInsurance,
                  icon: Icons.health_and_safety_outlined,
                ),
                AppReportSectionData(
                  id: BillingInvoicePrintSection.notes,
                  title: l10n.billingNotesLabel,
                  icon: Icons.notes_outlined,
                ),
                AppReportSectionData(
                  id: BillingInvoicePrintSection.footer,
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
