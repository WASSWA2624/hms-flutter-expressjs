import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
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
    final String currency = widget.item.currency ?? appDefaultCurrencyCode;
    final double due = widget.item.balanceDue
        .clamp(0, double.infinity)
        .toDouble();
    _amountController = TextEditingController(
      text: formatConvertedAmount(due, currency),
    );
  }

  String? get _schemeLabel {
    for (final BillingInvoiceItem line in widget.item.items) {
      final String? scheme = line.coveragePlanName?.trim();
      if (scheme != null && scheme.isNotEmpty) {
        return scheme;
      }
      final String? company = line.insuranceCompanyName?.trim();
      if (company != null && company.isNotEmpty) {
        return company;
      }
    }
    return null;
  }

  num? get _patientShareTotal {
    num total = 0;
    var hasShare = false;
    for (final BillingInvoiceItem line in widget.item.items) {
      if (line.patientShare != null) {
        total += line.patientShare!;
        hasShare = true;
      }
    }
    return hasShare ? total : null;
  }

  num? get _insurerShareTotal {
    num total = 0;
    var hasShare = false;
    for (final BillingInvoiceItem line in widget.item.items) {
      if (line.insurerShare != null) {
        total += line.insurerShare!;
        hasShare = true;
      }
    }
    return hasShare ? total : null;
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
      title: Text(context.l10n.billingPayAction),
      icon: const Icon(Icons.point_of_sale),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppReportSummaryGrid(
            records: <AppReportSummaryItem>[
              AppReportSummaryItem(
                label: context.l10n.billingInvoiceLabel,
                value: billingWorkItemPublicId(context, widget.item),
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
              if (_schemeLabel != null)
                AppReportSummaryItem(
                  label: context.l10n.billingReceivePaymentSchemeLabel,
                  value: _schemeLabel!,
                  icon: Icons.verified_user_outlined,
                ),
              if (_patientShareTotal != null)
                AppReportSummaryItem(
                  label: context.l10n.billingReceivePaymentPatientShareLabel,
                  value: billingMoney(
                    context,
                    _patientShareTotal!,
                    widget.item.currency,
                  ),
                  icon: Icons.person_outline,
                ),
              if (_insurerShareTotal != null)
                AppReportSummaryItem(
                  label: context.l10n.billingReceivePaymentInsurerShareLabel,
                  value: billingMoney(
                    context,
                    _insurerShareTotal!,
                    widget.item.currency,
                  ),
                  icon: Icons.business_outlined,
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
            maxAmount: roundConvertedAmount(
              widget.item.balanceDue.clamp(0, double.infinity).toDouble(),
              widget.item.currency ?? appDefaultCurrencyCode,
            ),
          ),
          AppSelectField<String>(
            value: _method,
            labelText: context.l10n.billingPaymentMethodLabel,
            options: buildAppPaymentMethodSelectOptions(
              methods: billingPaymentMethods,
              labelOf: (String method) => billingApiLabel(context, method),
            ),
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
        submitLabel: context.l10n.billingPayAction,
        submitIcon: Icons.point_of_sale,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}
