import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/currency/effective_default_currency_provider.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class BillingRefundForm extends StatefulWidget {
  const BillingRefundForm({
    super.key,
    required this.dialogTitle,
    this.dialogIcon,
    required this.item,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final BillingWorkItem item;

  @override
  State<BillingRefundForm> createState() => _BillingRefundFormState();
}

class _BillingRefundFormState extends State<BillingRefundForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late String _paymentId;

  @override
  void initState() {
    super.initState();
    final BillingPayment payment = widget.item.firstRefundablePayment!;
    _paymentId = payment.id;
    _amountController = TextEditingController(
      text: payment.amount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      BillingRefundDraft(
        paymentId: _paymentId,
        amount: _amountController.text,
        reason: _reasonController.text.trim(),
        notes: billingEmptyToNull(_notesController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>(
            value: _paymentId,
            labelText: context.l10n.billingPaymentLabel,
            options: <AppSelectOption<String>>[
              for (final BillingPayment payment in widget.item.payments)
                if (payment.isRefundable)
                  AppSelectOption<String>(
                    value: payment.id,
                    label: billingJoinDisplay(<String?>[
                      payment.effectiveDisplayId,
                      billingMoney(
                        context,
                        payment.amount,
                        widget.item.currency,
                      ),
                    ]),
                  ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _paymentId = value);
              }
            },
          ),
          AppCurrencyAmountField(
            amountController: _amountController,
            currency: widget.item.currency ?? appDefaultCurrencyCode,
            onCurrencyChanged: (_) {},
            amountLabelText: context.l10n.billingRefundAmountLabel,
            currencyLabelText: context.l10n.billingCurrencyLabel,
            isRequired: true,
            allowZero: false,
          ),
          AppTextField(
            controller: _reasonController,
            labelText: context.l10n.billingReasonLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              context.l10n.billingRefundReasonValidation,
            ),
          ),
          AppTextField(
            controller: _notesController,
            labelText: context.l10n.billingNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: context.l10n.billingRequestRefund,
        submitIcon: Icons.assignment_return_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class BillingAdjustmentForm extends StatefulWidget {
  const BillingAdjustmentForm({
    super.key,
    required this.dialogTitle,
    this.dialogIcon,
    required this.item,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final BillingWorkItem item;

  @override
  State<BillingAdjustmentForm> createState() => _BillingAdjustmentFormState();
}

class _BillingAdjustmentFormState extends State<BillingAdjustmentForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _status = 'ISSUED';

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      BillingAdjustmentDraft(
        amount: _amountController.text,
        reason: _reasonController.text.trim(),
        status: _status,
        notes: billingEmptyToNull(_notesController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _amountController,
            labelText: context.l10n.billingAdjustmentAmountLabel,
            isRequired: true,
            validator: (String? value) {
              final String normalized = value?.replaceAll(',', '').trim() ?? '';
              if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(normalized)) {
                return context.l10n.billingAdjustmentAmountValidation;
              }
              return null;
            },
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          AppSelectField<String>(
            value: _status,
            labelText: context.l10n.billingAppliedStatusLabel,
            options: <AppSelectOption<String>>[
              AppSelectOption<String>(
                value: 'ISSUED',
                label: context.l10n.billingStatusIssued,
              ),
              AppSelectOption<String>(
                value: 'PARTIAL',
                label: context.l10n.billingStatusPartial,
              ),
              AppSelectOption<String>(
                value: 'PAID',
                label: context.l10n.billingStatusPaid,
              ),
              AppSelectOption<String>(
                value: 'DRAFT',
                label: context.l10n.billingStatusDraft,
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _status = value);
              }
            },
          ),
          AppTextField(
            controller: _reasonController,
            labelText: context.l10n.billingReasonLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              context.l10n.billingAdjustmentReasonValidation,
            ),
          ),
          AppTextField(
            controller: _notesController,
            labelText: context.l10n.billingNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: context.l10n.billingRequestAdjustment,
        submitIcon: Icons.tune,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class BillingReasonForm extends StatefulWidget {
  const BillingReasonForm({
    super.key,
    required this.dialogTitle,
    this.dialogIcon,
    required this.submitLabel,
    required this.reasonLabel,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final String submitLabel;
  final String reasonLabel;

  @override
  State<BillingReasonForm> createState() => _BillingReasonFormState();
}

class _BillingReasonFormState extends State<BillingReasonForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(<String, String?>{
      'reason': _reasonController.text.trim(),
      'notes': billingEmptyToNull(_notesController.text),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _reasonController,
            labelText: widget.reasonLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              context.l10n.billingReasonValidation,
            ),
          ),
          AppTextField(
            controller: _notesController,
            labelText: context.l10n.billingNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class BillingNotesForm extends StatefulWidget {
  const BillingNotesForm({
    super.key,
    required this.dialogTitle,
    this.dialogIcon,
    required this.submitLabel,
    this.email = false,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final String submitLabel;
  final bool email;

  @override
  State<BillingNotesForm> createState() => _BillingNotesFormState();
}

class _BillingNotesFormState extends State<BillingNotesForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(billingEmptyToNull(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _controller,
            labelText: widget.email
                ? context.l10n.billingRecipientEmailLabel
                : context.l10n.billingNotesLabel,
            keyboardType: widget.email ? TextInputType.emailAddress : null,
            maxLines: widget.email ? 1 : 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class BillingCloseForm extends ConsumerStatefulWidget {
  const BillingCloseForm({
    super.key,
    required this.dialogTitle,
    this.dialogIcon,
    required this.title,
    required this.shiftClose,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final String title;
  final bool shiftClose;

  @override
  ConsumerState<BillingCloseForm> createState() => _BillingCloseFormState();
}

class _BillingCloseFormState extends ConsumerState<BillingCloseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _expectedController = TextEditingController();
  final TextEditingController _actualController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _submitForApproval = true;

  @override
  void dispose() {
    _expectedController.dispose();
    _actualController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      BillingCloseDraft(
        expectedAmount: billingEmptyToNull(_expectedController.text),
        actualAmount: billingEmptyToNull(_actualController.text),
        notes: billingEmptyToNull(_notesController.text),
        submit: _submitForApproval,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String defaultCurrency = ref.watch(effectiveDefaultCurrencyProvider);
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          if (widget.shiftClose) ...<Widget>[
            AppCurrencyAmountField(
              amountController: _expectedController,
              currency: defaultCurrency,
              onCurrencyChanged: (_) {},
              amountLabelText: context.l10n.billingExpectedAmountLabel,
              currencyLabelText: context.l10n.billingCurrencyLabel,
            ),
            AppCurrencyAmountField(
              amountController: _actualController,
              currency: defaultCurrency,
              onCurrencyChanged: (_) {},
              amountLabelText: context.l10n.billingActualAmountLabel,
              currencyLabelText: context.l10n.billingCurrencyLabel,
            ),
          ],
          AppTextField(
            controller: _notesController,
            labelText: context.l10n.billingNotesLabel,
            maxLines: 3,
          ),
          AppCheckboxField(
            title: context.l10n.billingSubmitForApprovalLabel,
            value: _submitForApproval,
            onChanged: (bool value) =>
                setState(() => _submitForApproval = value),
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.title,
        submitIcon: Icons.task_alt_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class BillingClaimReconcileForm extends StatefulWidget {
  const BillingClaimReconcileForm({
    super.key,
    required this.dialogTitle,
    this.dialogIcon,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;

  @override
  State<BillingClaimReconcileForm> createState() =>
      _BillingClaimReconcileFormState();
}

class _BillingClaimReconcileFormState extends State<BillingClaimReconcileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _settlementController = TextEditingController();
  String _status = 'APPROVED';

  bool get _requiresSettlement =>
      _status == 'PAID' || _status == 'PARTIAL';

  @override
  void dispose() {
    _notesController.dispose();
    _settlementController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      BillingClaimActionDraft(
        status: _status,
        notes: billingEmptyToNull(_notesController.text),
        settlementAmount: _requiresSettlement
            ? billingEmptyToNull(_settlementController.text)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppSelectField<String>(
            value: _status,
            labelText: l10n.billingStatusColumn,
            options: <AppSelectOption<String>>[
              AppSelectOption<String>(
                value: 'APPROVED',
                label: l10n.billingClaimStatusApproved,
              ),
              AppSelectOption<String>(
                value: 'REJECTED',
                label: l10n.billingClaimStatusRejected,
              ),
              AppSelectOption<String>(
                value: 'PARTIAL',
                label: l10n.billingClaimStatusPartial,
              ),
              AppSelectOption<String>(
                value: 'PAID',
                label: l10n.billingClaimStatusPaid,
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _status = value);
              }
            },
          ),
          if (_requiresSettlement)
            AppCurrencyAmountField(
              controller: _settlementController,
              amountLabelText: l10n.claimsSettlementAmountColumnLabel,
              required: _status == 'PARTIAL',
            ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.billingNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.billingReconcileClaimAction,
        submitIcon: Icons.fact_check_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}
