import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
import 'package:hosspi_hms/core/currency/fx_rate_service.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/mobile_money_provider_selector.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_payment_method_selector.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_payment_methods.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_plan_selector.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

enum _UpgradeStep { plan, paymentMethod, paymentDetails, proof, contact }

Future<bool?> showSubscriptionUpgradeDialog(
  BuildContext context, {
  TenantSubscriptionSummary? initialSummary,
  PlatformAdminContact? initialAdminContact,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return SubscriptionUpgradeDialog(
        initialSummary: initialSummary,
        initialAdminContact: initialAdminContact,
      );
    },
  );
}

class SubscriptionUpgradeDialog extends ConsumerStatefulWidget {
  const SubscriptionUpgradeDialog({
    this.initialSummary,
    this.initialAdminContact,
    super.key,
  });

  final TenantSubscriptionSummary? initialSummary;
  final PlatformAdminContact? initialAdminContact;

  @override
  ConsumerState<SubscriptionUpgradeDialog> createState() =>
      _SubscriptionUpgradeDialogState();
}

class _SubscriptionUpgradeDialogState
    extends ConsumerState<SubscriptionUpgradeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _invoiceEmailController =
      TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _cardLastFourController = TextEditingController();

  SubscriptionUpgradeContext? _context;
  AppFailure? _failure;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isFxLoading = false;
  String? _selectedPlanId;
  String _currency = appDefaultCurrencyCode;
  double? _usdPlanPrice;
  String? _fxWarning;
  SubscriptionUpgradeBillingCycle _billingCycle =
      SubscriptionUpgradeBillingCycle.monthly;
  SubscriptionPaymentMethodId _paymentMethod =
      SubscriptionPaymentMethodId.mobileMoney;
  MobileMoneyProviderId _mobileMoneyProvider = MobileMoneyProviderId.mtn;
  String? _proofFileName;
  List<int>? _proofBytes;
  String? _proofMimeType;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  _UpgradeStep _step = _UpgradeStep.plan;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _invoiceEmailController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    _bankNameController.dispose();
    _cardHolderController.dispose();
    _cardLastFourController.dispose();
    super.dispose();
  }

  SubscriptionPaymentFlowIntent get _flowIntent =>
      resolveSubscriptionFlowIntent(
        currentPlanId: _context?.currentPlanId,
        selectedPlanId: _selectedPlanId,
      );

  SubscriptionUpgradePlanOption? get _selectedPlan {
    final String? planId = _selectedPlanId;
    if (planId == null) {
      return null;
    }
    for (final SubscriptionUpgradePlanOption plan
        in _context?.plans ?? const <SubscriptionUpgradePlanOption>[]) {
      if (plan.id == planId) {
        return plan;
      }
    }
    return null;
  }

  bool get _showReferenceField =>
      _paymentMethod == SubscriptionPaymentMethodId.mobileMoney ||
      _paymentMethod == SubscriptionPaymentMethodId.bankTransfer;

  bool get _requiresProof =>
      subscriptionPaymentMethodRequiresProof(_paymentMethod);

  List<_UpgradeStep> get _steps {
    return <_UpgradeStep>[
      _UpgradeStep.plan,
      _UpgradeStep.paymentMethod,
      _UpgradeStep.paymentDetails,
      if (_requiresProof) _UpgradeStep.proof,
      _UpgradeStep.contact,
    ];
  }

  int get _stepIndex => _steps.indexOf(_step).clamp(0, _steps.length - 1);

  bool get _isFirstStep => _stepIndex <= 0;

  bool get _isLastStep => _stepIndex >= _steps.length - 1;

  String _planLabel(AppLocalizations l10n, SubscriptionUpgradePlanOption plan) {
    if (plan.tierCode == null || plan.tierCode!.isEmpty) {
      return plan.label;
    }
    return '${plan.label} (${plan.tierCode})';
  }

  String _billingCycleServerValue() {
    return switch (_billingCycle) {
      SubscriptionUpgradeBillingCycle.monthly => 'MONTHLY',
      SubscriptionUpgradeBillingCycle.annual => 'ANNUAL',
    };
  }

  Future<void> _loadContext() async {
    final result = await ref
        .read(subscriptionsRepositoryProvider)
        .getUpgradeContext();

    if (!mounted) {
      return;
    }

    result.when(
      success: (SubscriptionUpgradeContext contextData) {
        final String? currentPlanId = contextData.currentPlanId;
        final TenantSubscriptionSummary? summary =
            contextData.summary ?? widget.initialSummary;
        final bool preferRenewal =
            currentPlanId != null &&
            summary != null &&
            summary.headerState != TenantSubscriptionHeaderState.active;

        final String? selectedPlanId = preferRenewal
            ? currentPlanId
            : (contextData.recommendedPlanId ??
                  currentPlanId ??
                  contextData.plans.firstOrNull?.id);

        SubscriptionUpgradeBillingCycle billingCycle =
            SubscriptionUpgradeBillingCycle.monthly;
        final SubscriptionUpgradePlanOption? seedPlan = contextData.plans
            .where(
              (SubscriptionUpgradePlanOption plan) => plan.id == selectedPlanId,
            )
            .firstOrNull;
        final String seedCycle = (seedPlan?.billingCycle ?? '')
            .trim()
            .toUpperCase();
        if (seedCycle.contains('YEAR') || seedCycle == 'ANNUAL') {
          billingCycle = SubscriptionUpgradeBillingCycle.annual;
        }

        setState(() {
          _context = contextData;
          _selectedPlanId = selectedPlanId;
          _billingCycle = billingCycle;
          _isLoading = false;
        });

        _syncUsdPriceFromSelection();
        unawaited(_applyConvertedAmount());
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoading = false;
        });
      },
    );
  }

  void _syncUsdPriceFromSelection() {
    _usdPlanPrice = _selectedPlan?.priceFor(_billingCycle);
  }

  Future<void> _applyConvertedAmount() async {
    final double? usdPrice = _usdPlanPrice;
    if (usdPrice == null) {
      return;
    }

    final String targetCurrency = _currency.trim().toUpperCase();
    if (targetCurrency == subscriptionPlanBaseCurrencyCode) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFxLoading = false;
        _fxWarning = null;
        _amountController.text = formatConvertedAmount(
          usdPrice,
          subscriptionPlanBaseCurrencyCode,
        );
      });
      return;
    }

    setState(() {
      _isFxLoading = true;
      _fxWarning = null;
    });

    final double? rate = await ref
        .read(fxRateServiceProvider)
        .convertUsdTo(targetCurrency);

    if (!mounted) {
      return;
    }

    if (rate == null) {
      setState(() {
        _isFxLoading = false;
        _fxWarning = context.l10n.subscriptionFxRateErrorMessage;
        _amountController.text = formatConvertedAmount(
          usdPrice,
          subscriptionPlanBaseCurrencyCode,
        );
      });
      return;
    }

    final double converted = roundConvertedAmount(
      usdPrice * rate,
      targetCurrency,
    );
    setState(() {
      _isFxLoading = false;
      _fxWarning = null;
      _amountController.text = formatConvertedAmount(converted, targetCurrency);
    });
  }

  Future<void> _onPlanChanged(String planId) async {
    setState(() {
      _selectedPlanId = planId;
      _syncUsdPriceFromSelection();
    });
    await _applyConvertedAmount();
  }

  Future<void> _onBillingCycleChanged(
    SubscriptionUpgradeBillingCycle cycle,
  ) async {
    setState(() {
      _billingCycle = cycle;
      _syncUsdPriceFromSelection();
    });
    await _applyConvertedAmount();
  }

  Future<void> _onCurrencyChanged(String currency) async {
    setState(() => _currency = currency);
    await _applyConvertedAmount();
  }

  Future<void> _pickProof() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'payment-proof',
      extensions: <String>['jpg', 'jpeg', 'png', 'pdf'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );
    if (file == null || !mounted) {
      return;
    }

    final List<int> bytes = await file.readAsBytes();
    setState(() {
      _proofFileName = file.name;
      _proofBytes = bytes;
      _proofMimeType = file.mimeType;
      _failure = null;
    });
  }

  bool _validateCurrentStep() {
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);

    switch (_step) {
      case _UpgradeStep.plan:
        return _selectedPlanId != null && _selectedPlanId!.isNotEmpty;
      case _UpgradeStep.paymentMethod:
        return true;
      case _UpgradeStep.paymentDetails:
        return validateAndSaveAppForm(_formKey);
      case _UpgradeStep.proof:
        if (_requiresProof && _proofBytes == null) {
          setState(() {
            _failure = AppFailure.validation(
              code: 'subscription.proof_required',
              detailMessage: context.l10n.subscriptionProofRequiredMessage,
            );
          });
          return false;
        }
        return true;
      case _UpgradeStep.contact:
        return true;
    }
  }

  void _goNext() {
    if (!_validateCurrentStep()) {
      return;
    }
    final List<_UpgradeStep> steps = _steps;
    final int nextIndex = _stepIndex + 1;
    if (nextIndex >= steps.length) {
      return;
    }
    setState(() {
      _step = steps[nextIndex];
      _failure = null;
      _autovalidateMode = AutovalidateMode.disabled;
    });
  }

  void _goBack() {
    final List<_UpgradeStep> steps = _steps;
    final int previousIndex = _stepIndex - 1;
    if (previousIndex < 0) {
      return;
    }
    setState(() {
      _step = steps[previousIndex];
      _failure = null;
      _autovalidateMode = AutovalidateMode.disabled;
    });
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) {
      return;
    }

    // Re-validate payment details form before submit.
    if (!validateAndSaveAppForm(_formKey)) {
      setState(() => _step = _UpgradeStep.paymentDetails);
      return;
    }

    final String? planId = _selectedPlanId;
    if (planId == null || planId.isEmpty) {
      setState(() => _step = _UpgradeStep.plan);
      return;
    }

    if (_requiresProof && _proofBytes == null) {
      setState(() {
        _step = _UpgradeStep.proof;
        _failure = AppFailure.validation(
          code: 'subscription.proof_required',
          detailMessage: context.l10n.subscriptionProofRequiredMessage,
        );
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final String? provider =
        _paymentMethod == SubscriptionPaymentMethodId.mobileMoney
        ? _mobileMoneyProvider.serverValue
        : null;

    final result = await ref
        .read(subscriptionsRepositoryProvider)
        .submitPaymentRequest(
          SubscriptionPaymentRequestDraft(
            targetPlanId: planId,
            paymentMethod: _paymentMethod.serverValue,
            amount: normalizeCurrencyAmount(_amountController.text),
            currency: _currency,
            billingCycle: _billingCycleServerValue(),
            invoiceEmail: _emptyToNull(_invoiceEmailController.text),
            reference: _showReferenceField
                ? _emptyToNull(_referenceController.text)
                : null,
            notes: _buildSubmissionNotes(),
            paymentProvider: provider,
            payerPhone: _emptyToNull(_phoneController.text),
            bankName: _emptyToNull(_bankNameController.text),
            cardHolderName: _emptyToNull(_cardHolderController.text),
            cardLastFour: _emptyToNull(_cardLastFourController.text),
            proofBytes: _proofBytes,
            proofFileName: _proofFileName,
            proofMimeType: _proofMimeType,
          ),
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isSubmitting = false;
        });
      },
    );
  }

  String? _buildSubmissionNotes() {
    final String base = _emptyToNull(_notesController.text) ?? '';
    final String intent = _flowIntent == SubscriptionPaymentFlowIntent.renewal
        ? 'renewal'
        : 'upgrade';
    final String composed =
        'flow:$intent;billing_cycle:${_billingCycleServerValue()}';
    if (base.isEmpty) {
      return composed;
    }
    return '$composed\n$base';
  }

  String _stepTitle(AppLocalizations l10n, _UpgradeStep step) {
    return switch (step) {
      _UpgradeStep.plan => l10n.subscriptionUpgradeStepPlanTitle,
      _UpgradeStep.paymentMethod =>
        l10n.subscriptionUpgradeStepPaymentMethodTitle,
      _UpgradeStep.paymentDetails =>
        l10n.subscriptionUpgradeStepPaymentDetailsTitle,
      _UpgradeStep.proof => l10n.subscriptionUpgradeStepProofTitle,
      _UpgradeStep.contact => l10n.subscriptionUpgradeStepContactTitle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isRenewal = _flowIntent == SubscriptionPaymentFlowIntent.renewal;

    if (_isLoading) {
      return AppDialog(
        title: Text(l10n.subscriptionUpgradeDialogTitle),
        icon: const Icon(Icons.workspace_premium_outlined),
        content: const SizedBox(
          width: 420,
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: <Widget>[
          AppButton.secondary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      );
    }

    final SubscriptionUpgradeContext? contextData = _context;
    final PlatformAdminContact? adminContact =
        contextData?.platformAdminContact ?? widget.initialAdminContact;
    final List<_UpgradeStep> steps = _steps;

    return AppDialog(
      title: Text(
        isRenewal
            ? l10n.subscriptionRenewDialogTitle
            : l10n.subscriptionUpgradeDialogTitle,
      ),
      icon: Icon(
        isRenewal ? Icons.autorenew : Icons.workspace_premium_outlined,
      ),
      maxWidth: 760,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        autovalidateMode: _autovalidateMode,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          _StepIndicator(
            steps: steps,
            current: _step,
            titleBuilder: (step) => _stepTitle(l10n, step),
          ),
          SizedBox(height: theme.spacing.md),
          for (final _UpgradeStep step in steps)
            Visibility(
              visible: step == _step,
              maintainState: true,
              maintainAnimation: true,
              child: _buildStepContent(
                step: step,
                l10n: l10n,
                theme: theme,
                colorScheme: colorScheme,
                contextData: contextData,
                adminContact: adminContact,
              ),
            ),
        ],
      ),
      actions: _buildActions(l10n, isRenewal),
    );
  }

  Widget _buildStepContent({
    required _UpgradeStep step,
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required SubscriptionUpgradeContext? contextData,
    required PlatformAdminContact? adminContact,
  }) {
    return switch (step) {
      _UpgradeStep.plan => SubscriptionPlanSelector(
        plans: contextData?.plans ?? const <SubscriptionUpgradePlanOption>[],
        selectedPlanId: _selectedPlanId,
        currentPlanId: contextData?.currentPlanId,
        billingCycle: _billingCycle,
        monthlyLabel: l10n.subscriptionUpgradeBillingMonthlyLabel,
        annualLabel: l10n.subscriptionUpgradeBillingAnnualLabel,
        currentPlanLabel: l10n.subscriptionUpgradeCurrentPlanBadge,
        planLabelBuilder: (SubscriptionUpgradePlanOption plan) =>
            _planLabel(l10n, plan),
        onBillingCycleChanged: (SubscriptionUpgradeBillingCycle cycle) {
          unawaited(_onBillingCycleChanged(cycle));
        },
        onSelected: (String planId) => unawaited(_onPlanChanged(planId)),
      ),
      _UpgradeStep.paymentMethod => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.subscriptionUpgradePaymentMethodSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          SubscriptionPaymentMethodSelector(
            selected: _paymentMethod,
            onSelected: (SubscriptionPaymentMethodId method) {
              setState(() {
                _paymentMethod = method;
                if (!_steps.contains(_step)) {
                  _step = _UpgradeStep.paymentMethod;
                }
              });
            },
          ),
        ],
      ),
      _UpgradeStep.paymentDetails => _buildPaymentDetailsStep(
        l10n: l10n,
        theme: theme,
        colorScheme: colorScheme,
        contextData: contextData,
      ),
      _UpgradeStep.proof => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.subscriptionUpgradeProofStepBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          _ProofOfPaymentSection(
            fileName: _proofFileName,
            proofBytes: _proofBytes,
            proofMimeType: _proofMimeType,
            isSubmitting: _isSubmitting,
            attachLabel: l10n.subscriptionUpgradeAttachProofAction,
            removeLabel: l10n.subscriptionUpgradeRemoveProofAction,
            proofLabel: l10n.subscriptionUpgradeProofLabel,
            onAttach: _pickProof,
            onRemove: () => setState(() {
              _proofFileName = null;
              _proofBytes = null;
              _proofMimeType = null;
            }),
          ),
          SizedBox(height: theme.spacing.md),
          AppTextField(
            controller: _notesController,
            labelText: l10n.subscriptionUpgradeNotesLabel,
            maxLines: 2,
          ),
        ],
      ),
      _UpgradeStep.contact => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (adminContact?.hasContact == true)
            _AdminContactSection(
              adminContact: adminContact!,
              title: l10n.subscriptionUpgradeAdminContactTitle,
              body: l10n.subscriptionUpgradeAdminContactBody,
              emailLabel: l10n.subscriptionUpgradeAdminContactEmailLabel,
              phoneLabel: l10n.subscriptionUpgradeAdminContactPhoneLabel,
            )
          else
            Text(
              l10n.subscriptionUpgradeAdminContactBody,
              style: theme.textTheme.bodyMedium,
            ),
          if (!_requiresProof &&
              _paymentMethod != SubscriptionPaymentMethodId.other) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppTextField(
              controller: _notesController,
              labelText: l10n.subscriptionUpgradeNotesLabel,
              maxLines: 2,
            ),
          ],
        ],
      ),
    };
  }

  Widget _buildPaymentDetailsStep({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required SubscriptionUpgradeContext? contextData,
  }) {
    final bool isMobileMoney =
        _paymentMethod == SubscriptionPaymentMethodId.mobileMoney;
    final int amountDigits = decimalDigitsForCurrency(_currency);
    final Widget amountField = AppCurrencyAmountField(
      amountController: _amountController,
      currency: _currency,
      amountReadOnly: true,
      isLoading: _isFxLoading,
      onCurrencyChanged: (String? value) {
        if (value != null) {
          unawaited(_onCurrencyChanged(value));
        }
      },
      amountLabelText: l10n.subscriptionUpgradeAmountLabel,
      currencyLabelText: l10n.billingCurrencyLabel,
      isRequired: true,
      allowZero: false,
      decimalDigits: amountDigits,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_paymentMethod != SubscriptionPaymentMethodId.cash &&
            _paymentMethod != SubscriptionPaymentMethodId.other) ...<Widget>[
          Text(
            l10n.subscriptionUpgradePaymentDetailsTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          ..._paymentDetailFields(l10n, theme, contextData),
          SizedBox(height: theme.spacing.md),
        ],
        AppEmailField(
          controller: _invoiceEmailController,
          labelText: l10n.subscriptionUpgradeInvoiceEmailLabel,
          helperText: l10n.subscriptionUpgradeInvoiceEmailHelper,
          invalidEmailMessage: l10n.authEmailInvalidMessage,
          requiredMessage: l10n.validationRequired,
          isRequired: true,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: theme.spacing.md),
        if (isMobileMoney) ...<Widget>[
          AppTextField(
            controller: _phoneController,
            labelText: l10n.subscriptionMobileMoneyPhoneLabel,
            keyboardType: TextInputType.phone,
            isRequired: true,
          ),
          SizedBox(height: theme.spacing.sm),
        ],
        amountField,
        if (_fxWarning != null) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            _fxWarning!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.tertiary,
            ),
          ),
        ],
        if (_showReferenceField) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          AppTextField(
            controller: _referenceController,
            labelText: l10n.subscriptionUpgradeReferenceLabel,
            hintText: l10n.subscriptionPaymentReferenceHint,
            isRequired: true,
          ),
        ],
        if (_paymentMethod == SubscriptionPaymentMethodId.other) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          AppTextField(
            controller: _notesController,
            labelText: l10n.subscriptionUpgradeNotesLabel,
            maxLines: 3,
            isRequired: true,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions(AppLocalizations l10n, bool isRenewal) {
    final List<Widget> actions = <Widget>[
      AppButton.secondary(
        label: l10n.commonCancelActionLabel,
        leadingIcon: Icons.close,
        enabled: !_isSubmitting,
        onPressed: _isSubmitting
            ? null
            : () => Navigator.of(context).maybePop(),
      ),
    ];

    if (!_isFirstStep) {
      actions.add(
        AppButton.tertiary(
          label: l10n.commonBackActionLabel,
          leadingIcon: Icons.arrow_back,
          enabled: !_isSubmitting,
          onPressed: _isSubmitting ? null : _goBack,
        ),
      );
    }

    if (_isLastStep) {
      actions.add(
        AppButton.primary(
          label: isRenewal
              ? l10n.subscriptionRenewSubmitAction
              : l10n.subscriptionUpgradeSubmitAction,
          leadingIcon: Icons.payments_outlined,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      );
    } else {
      actions.add(
        AppButton.primary(
          label: l10n.commonNextActionLabel,
          leadingIcon: Icons.arrow_forward,
          enabled: !_isSubmitting,
          onPressed: _isSubmitting ? null : _goNext,
        ),
      );
    }

    return actions;
  }

  List<Widget> _paymentDetailFields(
    AppLocalizations l10n,
    ThemeData theme,
    SubscriptionUpgradeContext? contextData,
  ) {
    final List<Widget> fields = switch (_paymentMethod) {
      SubscriptionPaymentMethodId.mobileMoney => <Widget>[
        MobileMoneyProviderSelector(
          selected: _mobileMoneyProvider,
          onSelected: (MobileMoneyProviderId provider) {
            setState(() => _mobileMoneyProvider = provider);
          },
        ),
      ],
      SubscriptionPaymentMethodId.bankTransfer => <Widget>[
        if (contextData?.bankTransferDetails?.hasDetails == true)
          _BankTransferDetailsSection(
            details: contextData!.bankTransferDetails!,
            title: l10n.subscriptionBankTransferDetailsTitle,
            accountNameLabel: l10n.subscriptionBankAccountNameLabel,
            bankNameLabel: l10n.subscriptionPlatformBankNameLabel,
            branchLabel: l10n.subscriptionBankBranchLabel,
            accountNumberLabel: l10n.subscriptionBankAccountNumberLabel,
            swiftLabel: l10n.subscriptionBankSwiftLabel,
            ibanLabel: l10n.subscriptionBankIbanLabel,
          ),
        AppTextField(
          controller: _bankNameController,
          labelText: l10n.subscriptionBankNameLabel,
        ),
      ],
      SubscriptionPaymentMethodId.creditCard ||
      SubscriptionPaymentMethodId.debitCard => <Widget>[
        AppTextField(
          controller: _cardHolderController,
          labelText: l10n.subscriptionCardHolderNameLabel,
          isRequired: true,
        ),
        AppTextField(
          controller: _cardLastFourController,
          labelText: l10n.subscriptionCardLastFourLabel,
          keyboardType: TextInputType.number,
          isRequired: true,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
        ),
      ],
      SubscriptionPaymentMethodId.cash => const <Widget>[],
      SubscriptionPaymentMethodId.other => const <Widget>[],
    };

    return _spacedFields(theme, fields);
  }

  List<Widget> _spacedFields(ThemeData theme, List<Widget> fields) {
    if (fields.isEmpty) {
      return fields;
    }
    final List<Widget> spaced = <Widget>[fields.first];
    for (final Widget field in fields.skip(1)) {
      spaced
        ..add(SizedBox(height: theme.spacing.sm))
        ..add(field);
    }
    return spaced;
  }

  static String? _emptyToNull(String value) {
    final String normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.steps,
    required this.current,
    required this.titleBuilder,
  });

  final List<_UpgradeStep> steps;
  final _UpgradeStep current;
  final String Function(_UpgradeStep step) titleBuilder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final int currentIndex = steps.indexOf(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 560;
            return Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                for (int index = 0; index < steps.length; index += 1)
                  _StepChip(
                    index: index + 1,
                    label: compact ? null : titleBuilder(steps[index]),
                    active: index == currentIndex,
                    completed: index < currentIndex,
                  ),
              ],
            );
          },
        ),
        SizedBox(height: theme.spacing.sm),
        Text(
          titleBuilder(current),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.index,
    required this.label,
    required this.active,
    required this.completed,
  });

  final int index;
  final String? label;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color background = active
        ? colorScheme.primary
        : completed
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final Color foreground = active
        ? colorScheme.onPrimary
        : completed
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(theme.radius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$index',
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (label != null) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            Text(
              label!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BankTransferDetailsSection extends StatelessWidget {
  const _BankTransferDetailsSection({
    required this.details,
    required this.title,
    required this.accountNameLabel,
    required this.bankNameLabel,
    required this.branchLabel,
    required this.accountNumberLabel,
    required this.swiftLabel,
    required this.ibanLabel,
  });

  final PlatformBankTransferDetails details;
  final String title;
  final String accountNameLabel;
  final String bankNameLabel;
  final String branchLabel;
  final String accountNumberLabel;
  final String swiftLabel;
  final String ibanLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (details.accountName != null)
            _BankDetailRow(
              label: accountNameLabel,
              value: details.accountName!,
            ),
          if (details.bankName != null)
            _BankDetailRow(label: bankNameLabel, value: details.bankName!),
          if (details.branch != null)
            _BankDetailRow(label: branchLabel, value: details.branch!),
          if (details.accountNumber != null)
            _BankDetailRow(
              label: accountNumberLabel,
              value: details.accountNumber!,
            ),
          if (details.swiftCode != null)
            _BankDetailRow(label: swiftLabel, value: details.swiftCode!),
          if (details.iban != null)
            _BankDetailRow(label: ibanLabel, value: details.iban!),
        ],
      ),
    );
  }
}

class _BankDetailRow extends StatelessWidget {
  const _BankDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ProofOfPaymentSection extends StatelessWidget {
  const _ProofOfPaymentSection({
    required this.fileName,
    required this.proofBytes,
    required this.proofMimeType,
    required this.isSubmitting,
    required this.attachLabel,
    required this.removeLabel,
    required this.proofLabel,
    required this.onAttach,
    required this.onRemove,
  });

  final String? fileName;
  final List<int>? proofBytes;
  final String? proofMimeType;
  final bool isSubmitting;
  final String attachLabel;
  final String removeLabel;
  final String proofLabel;
  final VoidCallback onAttach;
  final VoidCallback onRemove;

  bool get _isImage {
    final String? mime = proofMimeType?.toLowerCase();
    if (mime != null && mime.startsWith('image/')) {
      return true;
    }
    final String? name = fileName?.toLowerCase();
    return name != null &&
        (name.endsWith('.jpg') ||
            name.endsWith('.jpeg') ||
            name.endsWith('.png'));
  }

  bool get _isPdf {
    final String? mime = proofMimeType?.toLowerCase();
    if (mime == 'application/pdf') {
      return true;
    }
    return fileName?.toLowerCase().endsWith('.pdf') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          proofLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            AppButton.secondary(
              label: attachLabel,
              leadingIcon: Icons.attach_file_outlined,
              onPressed: isSubmitting ? null : onAttach,
            ),
            if (fileName != null)
              AppButton.tertiary(
                label: removeLabel,
                onPressed: isSubmitting ? null : onRemove,
              ),
          ],
        ),
        if (fileName != null && proofBytes != null) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(theme.radius.sm),
                  child: Image.memory(
                    Uint8List.fromList(proofBytes!),
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(theme.radius.sm),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Icon(
                    _isPdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.insert_drive_file_outlined,
                    size: 36,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(fileName!, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AdminContactSection extends StatelessWidget {
  const _AdminContactSection({
    required this.adminContact,
    required this.title,
    required this.body,
    required this.emailLabel,
    required this.phoneLabel,
  });

  final PlatformAdminContact adminContact;
  final String title;
  final String body;
  final String emailLabel;
  final String phoneLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(theme.radius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Text(body, style: theme.textTheme.bodySmall),
          if (adminContact.email != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              emailLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SelectableText(
              adminContact.email!,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
          if (adminContact.phone != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              phoneLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SelectableText(
              adminContact.phone!,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
