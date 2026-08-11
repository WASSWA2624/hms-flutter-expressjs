import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

enum BillingReceiptPrintSection {
  payment,
  balance,
  footer,
}

/// Mutable receipt print-section state for live preview rebuilds.
final class BillingReceiptPrintOptionsController extends ChangeNotifier {
  BillingReceiptPrintOptionsController() {
    _selected = BillingReceiptPrintSection.values.toSet();
  }

  late Set<BillingReceiptPrintSection> _selected;

  Set<Object> get selectedIds => Set<Object>.unmodifiable(_selected);

  bool get includePayment =>
      _selected.contains(BillingReceiptPrintSection.payment);

  bool get includeBalance =>
      _selected.contains(BillingReceiptPrintSection.balance);

  bool get includeFooter =>
      _selected.contains(BillingReceiptPrintSection.footer);

  bool get canPrint => includePayment || includeBalance;

  void setSelection(Set<Object> selected) {
    final Set<BillingReceiptPrintSection> next = selected
        .whereType<BillingReceiptPrintSection>()
        .toSet();
    if (setEquals(next, _selected)) {
      return;
    }
    _selected = next;
    notifyListeners();
  }
}

class BillingReceiptPrintOptionsSection extends StatelessWidget {
  const BillingReceiptPrintOptionsSection({
    required this.controller,
    super.key,
  });

  final BillingReceiptPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: l10n.billingReceiptPrintOptionsSectionLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: BillingReceiptPrintSection.payment,
                  title: l10n.billingPaymentLabel,
                  icon: Icons.payments_outlined,
                ),
                AppReportSectionData(
                  id: BillingReceiptPrintSection.balance,
                  title: l10n.billingBalanceColumn,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                AppReportSectionData(
                  id: BillingReceiptPrintSection.footer,
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

Future<void> printBillingReceipt({
  required WidgetRef ref,
  required BuildContext context,
  required BillingWorkItem item,
  required BillingPaymentDraft draft,
}) async {
  final AppLocalizations l10n = context.l10n;
  final BillingReceiptPrintOptionsController options =
      BillingReceiptPrintOptionsController();
  final num paidAmount = num.tryParse(draft.amount.replaceAll(',', '')) ?? 0;

  String buildBodyHtml() {
    return billingReceiptHtml(
      context,
      item: item,
      draft: draft,
      paidAmount: paidAmount,
      options: options,
    );
  }

  try {
    await PrintDocumentTemplates.invoice(
      ref: ref,
      context: context,
      title: l10n.billingReceiptTitle,
      previewDialogTitle: l10n.billingReceiptTitle,
      patientContext: buildPrintFormPatientContext(
        l10n,
        patientName: billingPatientName(context, item),
        patientId: billingPatientPublicNumber(item),
        encounterId: billingPublicLabel(item.encounterDisplayId),
      ),
      invoiceReference: PrintFormContextReference(
        label: l10n.billingInvoiceLabel,
        value: billingWorkItemPublicId(context, item),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: BillingReceiptPrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
      includeSignatures: true,
      footerNote: l10n.billingInvoiceReportFooter,
    );
  } finally {
    options.dispose();
  }
}

String billingReceiptHtml(
  BuildContext context, {
  required BillingWorkItem item,
  required BillingPaymentDraft draft,
  required num paidAmount,
  BillingReceiptPrintOptionsController? options,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool includePayment = options?.includePayment ?? true;
  final bool includeBalance = options?.includeBalance ?? true;
  final bool includeFooter = options?.includeFooter ?? true;
  final StringBuffer buffer = StringBuffer();

  if (includePayment) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPaymentLabel,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            l10n.billingPaymentMethodLabel,
            l10n.billingReferenceLabel,
            l10n.billingLineItemAmountColumn,
          ],
          rows: <List<String>>[
            <String>[
              billingApiLabel(context, draft.method),
              billingPublicLabel(draft.reference) ?? l10n.billingNotRecorded,
              billingMoney(context, paidAmount, item.currency),
            ],
          ],
          emptyText: l10n.billingNoPayments,
        ),
      ),
    );
  }

  if (includeBalance) {
    final num remaining = (item.balanceDue - paidAmount)
        .clamp(0, double.infinity)
        .toDouble();
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingBalanceColumn,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(billingMoney(context, remaining, item.currency))}</p>',
      ),
    );
  }

  if (includeFooter) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.billingPrintSectionFooter,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(l10n.billingInvoiceReportFooter)}</p>',
      ),
    );
  }

  return buffer.toString();
}
