import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

Future<BillingPaymentDraft?> showBillingReceivePaymentDialog(
  BuildContext context, {
  required BillingWorkItem item,
}) {
  return showAppDialog<BillingPaymentDraft>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BillingReceivePaymentDialog(item: item),
  );
}

class BillingReceivePaymentDialog extends StatefulWidget {
  const BillingReceivePaymentDialog({required this.item, super.key});

  final BillingWorkItem item;

  @override
  State<BillingReceivePaymentDialog> createState() =>
      _BillingReceivePaymentDialogState();
}

class _BillingReceivePaymentDialogState
    extends State<BillingReceivePaymentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _payerController = TextEditingController();
  String _method = 'CASH';
  bool _issueReceipt = true;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.item.balanceDue.clamp(0, double.infinity).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _payerController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      BillingPaymentDraft(
        amount: _amountController.text,
        method: _method,
        reference: billingEmptyToNull(_referenceController.text),
        payer: billingEmptyToNull(_payerController.text),
        issueReceipt: _issueReceipt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(context.l10n.billingReceivePayment),
      icon: const Icon(Icons.point_of_sale),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppReportSummaryGrid(
            records: <AppReportSummaryItem>[
              AppReportSummaryItem(
                label: context.l10n.billingInvoiceLabel,
                value: widget.item.effectiveDisplayId,
                icon: Icons.receipt_long_outlined,
              ),
              AppReportSummaryItem(
                label: context.l10n.billingDueLabel,
                value: billingMoney(
                  context,
                  widget.item.balanceDue,
                  widget.item.currency,
                ),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ],
          ),
          AppCurrencyAmountField(
            amountController: _amountController,
            currency: widget.item.currency ?? appDefaultCurrencyCode,
            onCurrencyChanged: (_) {},
            amountLabelText: context.l10n.billingAmountReceivedLabel,
            currencyLabelText: context.l10n.billingCurrencyLabel,
            isRequired: true,
            allowZero: false,
            maxAmount: widget.item.balanceDue,
          ),
          AppSelectField<String>(
            value: _method,
            labelText: context.l10n.billingPaymentMethodLabel,
            options: <AppSelectOption<String>>[
              for (final String method in billingPaymentMethods)
                AppSelectOption<String>(
                  value: method,
                  label: billingApiLabel(context, method),
                ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _method = value);
              }
            },
          ),
          AppTextField(
            controller: _referenceController,
            labelText: context.l10n.billingReferenceLabel,
            hintText: context.l10n.billingPaymentReferenceHint,
          ),
          AppTextField(
            controller: _payerController,
            labelText: context.l10n.billingPayerLabel,
            hintText: context.l10n.billingPayerHint,
          ),
          AppCheckboxField(
            title: context.l10n.billingGenerateReceiptLabel,
            value: _issueReceipt,
            onChanged: (bool value) => setState(() => _issueReceipt = value),
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: context.l10n.billingReceivePayment,
        submitIcon: Icons.point_of_sale,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}
