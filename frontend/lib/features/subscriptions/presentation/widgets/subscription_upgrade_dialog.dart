import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/effective_default_currency_provider.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
import 'package:hosspi_hms/core/currency/fx_rate_service.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/validation_message_presenter.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
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
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum _UpgradeStep { plan, paymentMethod, paymentDetails, proof, contact }

/// Result of a successful subscription upgrade/renew/free-plan submission.
enum SubscriptionUpgradeDialogResult { paidSubmitted, freeSubmitted }

Future<SubscriptionUpgradeDialogResult?> showSubscriptionUpgradeDialog(
  BuildContext context, {
  TenantSubscriptionSummary? initialSummary,
  PlatformAdminContact? initialAdminContact,
}) {
  return showAppDialog<SubscriptionUpgradeDialogResult>(
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
  final GlobalKey<State<AppPhoneField>> _phoneFieldKey =
      GlobalKey<State<AppPhoneField>>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _invoiceEmailController = TextEditingController();
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
  double? _usdToDisplayRate;
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
      !_isNoPaymentPlan &&
      subscriptionPaymentMethodRequiresProof(_paymentMethod);

  bool get _isNoPaymentPlan {
    final SubscriptionUpgradePlanOption? plan = _selectedPlan;
    if (plan == null) {
      return false;
    }
    return plan.isNoPaymentPlan(_billingCycle);
  }

  List<_UpgradeStep> get _steps {
    if (_isNoPaymentPlan) {
      return const <_UpgradeStep>[_UpgradeStep.plan, _UpgradeStep.contact];
    }
    return <_UpgradeStep>[
      _UpgradeStep.plan,
      _UpgradeStep.paymentMethod,
      _UpgradeStep.paymentDetails,
      if (_requiresProof) _UpgradeStep.proof,
      _UpgradeStep.contact,
    ];
  }

  void _ensureStepInFlow() {
    final List<_UpgradeStep> steps = _steps;
    if (!steps.contains(_step)) {
      _step = steps.last;
    }
  }

  int get _stepIndex => _steps.indexOf(_step).clamp(0, _steps.length - 1);

  bool get _isFirstStep => _stepIndex <= 0;

  bool get _isLastStep => _stepIndex >= _steps.length - 1;

  String _planLabel(SubscriptionUpgradePlanOption plan) => plan.label;

  Future<void> _showCustomPlanContactDialog({
    PlatformAdminContact? adminContact,
  }) {
    final AppLocalizations l10n = context.l10n;
    return showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialog(
          title: Text(l10n.subscriptionUpgradeCustomContactDialogTitle),
          icon: const Icon(Icons.support_agent_outlined),
          content: SizedBox(
            width: 420,
            child: adminContact?.hasContact == true
                ? _AdminContactSection(
                    adminContact: adminContact!,
                    title: l10n.subscriptionUpgradeAdminContactTitle,
                    body: l10n.subscriptionUpgradeCustomContactDialogBody,
                    emailLabel: l10n.subscriptionUpgradeAdminContactEmailLabel,
                    phoneLabel: l10n.subscriptionUpgradeAdminContactPhoneLabel,
                  )
                : AppMessagePanel(
                    message: l10n.subscriptionUpgradeCustomContactEmptyMessage,
                    icon: Icons.support_agent_outlined,
                    tone: AppWorkspaceStatusTone.warning,
                  ),
          ),
          actions: buildAppDialogWizardActions(
            cancelLabel: l10n.commonCloseActionLabel,
            primaryLabel: l10n.commonCloseActionLabel,
            onCancel: () => Navigator.of(dialogContext).maybePop(),
            onPrimary: () => Navigator.of(dialogContext).maybePop(),
            primaryIcon: Icons.close,
          ),
        );
      },
    );
  }

  String _billingCycleServerValue() {
    return switch (_billingCycle) {
      SubscriptionUpgradeBillingCycle.monthly => 'MONTHLY',
      SubscriptionUpgradeBillingCycle.annual => 'ANNUAL',
    };
  }

  Future<void> _loadContext() async {
    if (!ref.read(appAccessPolicyProvider).canManageSubscriptionBilling()) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _failure = null;
    });

    final result = await ref
        .read(subscriptionsRepositoryProvider)
        .getUpgradeContext();

    if (!mounted) {
      return;
    }

    result.when(
      success: (SubscriptionUpgradeContext contextData) {
        final String? currentPlanId =
            contextData.currentPlanId ??
            contextData.summary?.planId ??
            widget.initialSummary?.planId;
        final List<SubscriptionUpgradePlanOption> commercialPlans =
            contextData.plans
                .where(
                  (SubscriptionUpgradePlanOption plan) => !plan.isDeveloperPlan,
                )
                .toList(growable: false);

        // Prefer the tenant's current package; fall back to recommendation / first plan.
        final String? preferredPlanId =
            currentPlanId ??
            contextData.recommendedPlanId ??
            commercialPlans.firstOrNull?.id;

        final bool preferredInCatalog =
            preferredPlanId != null &&
            commercialPlans.any(
              (SubscriptionUpgradePlanOption plan) =>
                  plan.id == preferredPlanId,
            );
        final String? selectedPlanId = preferredInCatalog
            ? preferredPlanId
            : commercialPlans.firstOrNull?.id;

        SubscriptionUpgradeBillingCycle billingCycle =
            SubscriptionUpgradeBillingCycle.monthly;
        final SubscriptionUpgradePlanOption? seedPlan = commercialPlans
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
          _currency = ref.read(effectiveDefaultCurrencyProvider);
          _isLoading = false;
        });

        _syncUsdPriceFromSelection();
        unawaited(_refreshDisplayFxRate());
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

  Future<void> _refreshDisplayFxRate() async {
    final String targetCurrency = _currency.trim().toUpperCase();
    if (targetCurrency.isEmpty ||
        targetCurrency == subscriptionPlanBaseCurrencyCode) {
      if (!mounted) {
        return;
      }
      setState(() {
        _usdToDisplayRate = 1;
        _fxWarning = null;
      });
      return;
    }

    final double? rate = await ref
        .read(fxRateServiceProvider)
        .convertUsdTo(targetCurrency);
    if (!mounted) {
      return;
    }
    setState(() {
      _usdToDisplayRate = rate;
      _fxWarning = rate == null
          ? context.l10n.subscriptionFxRateErrorMessage
          : null;
    });
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
      _ensureStepInFlow();
    });
    await _applyConvertedAmount();
  }

  Future<void> _onBillingCycleChanged(
    SubscriptionUpgradeBillingCycle cycle,
  ) async {
    setState(() {
      _billingCycle = cycle;
      _syncUsdPriceFromSelection();
      _ensureStepInFlow();
    });
    await _applyConvertedAmount();
  }

  Future<void> _onCurrencyChanged(String currency) async {
    setState(() {
      _currency = currency;
      _usdToDisplayRate = null;
    });
    await _refreshDisplayFxRate();
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
        return _selectedPlan != null;
      case _UpgradeStep.paymentMethod:
        return true;
      case _UpgradeStep.paymentDetails:
        AppPhoneField.commitPhone(_phoneFieldKey);
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

    final bool noPayment = _isNoPaymentPlan;

    if (!noPayment) {
      AppPhoneField.commitPhone(_phoneFieldKey);
      // Re-validate payment details form before submit.
      if (!validateAndSaveAppForm(_formKey)) {
        setState(() => _step = _UpgradeStep.paymentDetails);
        return;
      }
    }

    final String? planId = _selectedPlanId;
    if (planId == null || planId.isEmpty) {
      setState(() => _step = _UpgradeStep.plan);
      return;
    }

    if (!noPayment && _requiresProof && _proofBytes == null) {
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

    final String? provider = noPayment
        ? null
        : (_paymentMethod == SubscriptionPaymentMethodId.mobileMoney
              ? _mobileMoneyProvider.serverValue
              : null);

    final result = await ref
        .read(subscriptionsRepositoryProvider)
        .submitPaymentRequest(
          SubscriptionPaymentRequestDraft(
            targetPlanId: planId,
            paymentMethod: noPayment
                ? SubscriptionPaymentMethodId.other.serverValue
                : _paymentMethod.serverValue,
            amount: noPayment
                ? '0'
                : normalizeCurrencyAmount(_amountController.text),
            currency: noPayment ? subscriptionPlanBaseCurrencyCode : _currency,
            billingCycle: _billingCycleServerValue(),
            invoiceEmail: noPayment
                ? null
                : _emptyToNull(_invoiceEmailController.text),
            reference: noPayment || !_showReferenceField
                ? null
                : _emptyToNull(_referenceController.text),
            notes: _buildSubmissionNotes(noPayment: noPayment),
            paymentProvider: provider,
            payerPhone: noPayment ? null : _emptyToNull(_phoneController.text),
            bankName: noPayment ? null : _emptyToNull(_bankNameController.text),
            cardHolderName: noPayment
                ? null
                : _emptyToNull(_cardHolderController.text),
            cardLastFour: noPayment
                ? null
                : _emptyToNull(_cardLastFourController.text),
            proofBytes: noPayment ? null : _proofBytes,
            proofFileName: noPayment ? null : _proofFileName,
            proofMimeType: noPayment ? null : _proofMimeType,
          ),
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) => Navigator.of(context).pop(
        noPayment
            ? SubscriptionUpgradeDialogResult.freeSubmitted
            : SubscriptionUpgradeDialogResult.paidSubmitted,
      ),
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isSubmitting = false;
        });
      },
    );
  }

  String? _buildSubmissionNotes({required bool noPayment}) {
    final String base = _emptyToNull(_notesController.text) ?? '';
    final String intent = _flowIntent == SubscriptionPaymentFlowIntent.renewal
        ? 'renewal'
        : 'upgrade';
    final String composed = noPayment
        ? 'flow:$intent;billing_cycle:${_billingCycleServerValue()};no_payment:true'
        : 'flow:$intent;billing_cycle:${_billingCycleServerValue()}';
    if (base.isEmpty) {
      return composed;
    }
    return '$composed\n$base';
  }

  String _selectedPlanDisplayLabel(AppLocalizations l10n) {
    final String? label = _selectedPlan?.label.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return l10n.subscriptionHeaderFreeLabel;
  }

  String _dialogTitle(AppLocalizations l10n) {
    if (_isNoPaymentPlan) {
      final String? label = _selectedPlan?.label.trim();
      if (label != null && label.isNotEmpty) {
        return l10n.subscriptionConfirmPlanDialogTitle(label);
      }
      return l10n.subscriptionConfirmFreeDialogTitle;
    }
    if (_flowIntent == SubscriptionPaymentFlowIntent.renewal) {
      return l10n.subscriptionRenewDialogTitle;
    }
    return l10n.subscriptionUpgradeDialogTitle;
  }

  String _stepTitle(AppLocalizations l10n, _UpgradeStep step) {
    return switch (step) {
      _UpgradeStep.plan => l10n.subscriptionUpgradeStepPlanTitle,
      _UpgradeStep.paymentMethod =>
        l10n.subscriptionUpgradeStepPaymentMethodTitle,
      _UpgradeStep.paymentDetails =>
        l10n.subscriptionUpgradeStepPaymentDetailsTitle,
      _UpgradeStep.proof => l10n.subscriptionUpgradeStepProofTitle,
      _UpgradeStep.contact =>
        _isNoPaymentPlan
            ? l10n.subscriptionUpgradeStepConfirmTitle
            : l10n.subscriptionUpgradeStepContactTitle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isRenewal = _flowIntent == SubscriptionPaymentFlowIntent.renewal;
    final bool canManageBilling = ref
        .watch(appAccessPolicyProvider)
        .canManageSubscriptionBilling();

    if (!canManageBilling) {
      return AppDialog(
        title: Text(l10n.subscriptionUpgradeDialogTitle),
        icon: const Icon(Icons.lock_outline),
        content: SizedBox(
          width: 420,
          child: Text(l10n.subscriptionUpgradeAccessDeniedMessage),
        ),
        actions: buildAppDialogWizardActions(
          cancelLabel: l10n.commonCloseActionLabel,
          primaryLabel: l10n.commonCloseActionLabel,
          onCancel: () => Navigator.of(context).maybePop(),
          onPrimary: () => Navigator.of(context).maybePop(),
          primaryIcon: Icons.close,
        ),
      );
    }

    if (_isLoading) {
      return AppDialog(
        title: Text(l10n.subscriptionUpgradeDialogTitle),
        icon: const Icon(Icons.workspace_premium_outlined),
        content: const SizedBox(
          width: 420,
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: buildAppDialogWizardActions(
          cancelLabel: l10n.commonCancelActionLabel,
          primaryLabel: l10n.commonCloseActionLabel,
          onCancel: () => Navigator.of(context).maybePop(),
          onPrimary: () => Navigator.of(context).maybePop(),
          primaryIcon: Icons.close,
        ),
      );
    }

    final SubscriptionUpgradeContext? contextData = _context;
    final PlatformAdminContact? adminContact =
        contextData?.platformAdminContact ?? widget.initialAdminContact;
    final List<_UpgradeStep> steps = _steps;
    final bool noPayment = _isNoPaymentPlan;
    final String planLabel = _selectedPlanDisplayLabel(l10n);

    return AppDialog(
      title: Text(_dialogTitle(l10n)),
      icon: Icon(
        noPayment
            ? Icons.check_circle_outline
            : (isRenewal
                  ? Icons.autorenew
                  : Icons.workspace_premium_outlined),
      ),
      maxWidth: 1080,
      initialMaximized: false,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        autovalidateMode: _autovalidateMode,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          if (_step != _UpgradeStep.plan) ...<Widget>[
            Text(
              _stepTitle(l10n, _step),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
            SizedBox(height: theme.spacing.md),
          ],
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
      actions: buildAppDialogWizardActions(
        cancelLabel: l10n.commonCancelActionLabel,
        backLabel: l10n.commonBackActionLabel,
        primaryLabel: _isLastStep
            ? (noPayment
                  ? l10n.subscriptionUpgradeConfirmFreeAction(planLabel)
                  : (isRenewal
                        ? l10n.subscriptionRenewSubmitAction
                        : l10n.subscriptionUpgradeSubmitAction))
            : l10n.commonNextActionLabel,
        showBack: !_isFirstStep,
        isSubmitting: _isSubmitting,
        primaryIcon: _isLastStep
            ? (noPayment
                  ? Icons.check_circle_outline
                  : Icons.payments_outlined)
            : Icons.arrow_forward,
        onCancel: () => Navigator.of(context).maybePop(),
        onBack: _goBack,
        onPrimary: _isLastStep ? _submit : _goNext,
      ),
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
      _UpgradeStep.plan => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SubscriptionPlanSelector(
            plans:
                contextData?.plans ?? const <SubscriptionUpgradePlanOption>[],
            selectedPlanId: _selectedPlanId,
            currentPlanId: contextData?.currentPlanId,
            billingCycle: _billingCycle,
            monthlyLabel: l10n.subscriptionUpgradeBillingMonthlyLabel,
            annualLabel: l10n.subscriptionUpgradeBillingAnnualLabel,
            currentPlanLabel: l10n.subscriptionUpgradeCurrentPlanBadge,
            featuresColumnLabel: l10n.subscriptionUpgradeFeaturesColumnLabel,
            priceRowLabel: l10n.subscriptionUpgradePriceRowLabel,
            contactUsLabel: l10n.subscriptionUpgradeCustomContactUsAction,
            displayCurrency: _currency,
            usdToDisplayRate: _usdToDisplayRate,
            emptyTitle: _failure != null
                ? l10n.failureTitle(_failure!)
                : l10n.subscriptionUpgradePlansEmptyTitle,
            emptyMessage: _failure != null
                ? ValidationMessagePresenter.displayMessage(_failure!, l10n)
                : l10n.subscriptionUpgradePlansEmptyMessage,
            planLabelBuilder: _planLabel,
            onBillingCycleChanged: (SubscriptionUpgradeBillingCycle cycle) {
              unawaited(_onBillingCycleChanged(cycle));
            },
            onSelected: (String planId) => unawaited(_onPlanChanged(planId)),
            onContactCustomPlan: () {
              unawaited(
                _showCustomPlanContactDialog(adminContact: adminContact),
              );
            },
          ),
          if (_fxWarning != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            AppMessagePanel(
              message: _fxWarning!,
              icon: Icons.currency_exchange,
              tone: AppWorkspaceStatusTone.warning,
              density: AppContentPanelDensity.compact,
            ),
          ],
          if (_failure != null &&
              (contextData?.plans.isEmpty ?? true)) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: l10n.commonRetryActionLabel,
                leadingIcon: Icons.refresh,
                variant: AppButtonVariant.secondary,
                onPressed: _isLoading ? null : _loadContext,
              ),
            ),
          ],
        ],
      ),
      _UpgradeStep.paymentMethod => SubscriptionPaymentMethodSelector(
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
      _UpgradeStep.paymentDetails => _buildPaymentDetailsStep(
        l10n: l10n,
        theme: theme,
        colorScheme: colorScheme,
        contextData: contextData,
      ),
      _UpgradeStep.proof => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFileUploadPanel(
            title: l10n.subscriptionUpgradeProofLabel,
            emptyDescription: l10n.subscriptionUpgradeProofStepBody,
            chooseLabel: l10n.subscriptionUpgradeAttachProofAction,
            clearLabel: l10n.subscriptionUpgradeRemoveProofAction,
            fileNames: _proofFileName == null
                ? const <String>[]
                : <String>[_proofFileName!],
            onChoose: _pickProof,
            onClear: () => setState(() {
              _proofFileName = null;
              _proofBytes = null;
              _proofMimeType = null;
            }),
            enabled: !_isSubmitting,
            tone: AppWorkspaceStatusTone.info,
          ),
          if (_proofFileName != null && _proofBytes != null) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            _ProofPreview(
              fileName: _proofFileName!,
              proofBytes: _proofBytes!,
              proofMimeType: _proofMimeType,
            ),
          ],
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
          if (_isNoPaymentPlan) ...<Widget>[
            AppMessagePanel(
              message: l10n.subscriptionUpgradeFreePlanStepBody(
                _selectedPlanDisplayLabel(l10n),
              ),
              icon: Icons.verified_outlined,
              tone: AppWorkspaceStatusTone.success,
              density: AppContentPanelDensity.compact,
            ),
            SizedBox(height: theme.spacing.md),
          ],
          if (adminContact?.hasContact == true)
            _AdminContactSection(
              adminContact: adminContact!,
              title: _isNoPaymentPlan
                  ? l10n.subscriptionUpgradeFreePlanAdminContactTitle
                  : l10n.subscriptionUpgradeAdminContactTitle,
              body: _isNoPaymentPlan
                  ? l10n.subscriptionUpgradeFreePlanAdminContactBody
                  : l10n.subscriptionUpgradeAdminContactBody,
              emailLabel: l10n.subscriptionUpgradeAdminContactEmailLabel,
              phoneLabel: l10n.subscriptionUpgradeAdminContactPhoneLabel,
            )
          else if (!_isNoPaymentPlan)
            AppMessagePanel(
              title: l10n.subscriptionUpgradeAdminContactTitle,
              message: l10n.subscriptionUpgradeAdminContactBody,
              icon: Icons.support_agent_outlined,
            ),
          if (!_isNoPaymentPlan &&
              !_requiresProof &&
              _paymentMethod != SubscriptionPaymentMethodId.other) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppTextField(
              controller: _notesController,
              labelText: l10n.subscriptionUpgradeNotesLabel,
              maxLines: 2,
            ),
          ],
          if (_isNoPaymentPlan) ...<Widget>[
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
      isLoading: _isFxLoading,
      convertOnCurrencyChange: false,
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

    final List<Widget> methodFields = _paymentDetailFields(
      l10n,
      theme,
      contextData,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (methodFields.isNotEmpty) ...<Widget>[
          ..._spacedFields(theme, methodFields),
          SizedBox(height: theme.spacing.md),
        ],
        AppSectionPanel(
          leadingIcon: Icons.receipt_long_outlined,
          tone: AppWorkspaceStatusTone.info,
          density: AppContentPanelDensity.compact,
          children: <Widget>[
            AppEmailField(
              controller: _invoiceEmailController,
              labelText: l10n.subscriptionUpgradeInvoiceEmailLabel,
              helperText: l10n.subscriptionUpgradeInvoiceEmailHelper,
              invalidEmailMessage: l10n.authEmailInvalidMessage,
              requiredMessage: l10n.validationRequired,
              isRequired: true,
              textInputAction: TextInputAction.next,
            ),
            if (isMobileMoney)
              AppPhoneField(
                key: _phoneFieldKey,
                controller: _phoneController,
                labelText: l10n.subscriptionMobileMoneyPhoneLabel,
                countryLabelText: l10n.appPhoneCountryLabel,
                countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
                countryNoResultsText: l10n.appPhoneCountryNoResults,
                numberLabelText: l10n.appPhoneNumberLabel,
                numberHintText: l10n.appPhoneNumberHint,
                invalidPhoneMessage: l10n.appPhoneInvalidMessage,
                requiredMessage: l10n.validationRequired,
                isRequired: true,
                textInputAction: TextInputAction.next,
                enabled: !_isSubmitting,
              ),
            amountField,
            if (_fxWarning != null)
              Text(
                _fxWarning!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            if (_showReferenceField)
              AppTextField(
                controller: _referenceController,
                labelText: l10n.subscriptionUpgradeReferenceLabel,
                hintText: l10n.subscriptionPaymentReferenceHint,
                isRequired: true,
              ),
            if (_paymentMethod == SubscriptionPaymentMethodId.other)
              AppTextField(
                controller: _notesController,
                labelText: l10n.subscriptionUpgradeNotesLabel,
                maxLines: 3,
                isRequired: true,
              ),
          ],
        ),
      ],
    );
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
        AppResponsiveFieldRow.two(
          left: AppTextField(
            controller: _cardHolderController,
            labelText: l10n.subscriptionCardHolderNameLabel,
            isRequired: true,
          ),
          right: AppTextField(
            controller: _cardLastFourController,
            labelText: l10n.subscriptionCardLastFourLabel,
            keyboardType: TextInputType.number,
            isRequired: true,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
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
    return AppSectionPanel(
      title: title,
      leadingIcon: Icons.account_balance_outlined,
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        if (details.accountName != null)
          _BankDetailRow(label: accountNameLabel, value: details.accountName!),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(value, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _ProofPreview extends StatelessWidget {
  const _ProofPreview({
    required this.fileName,
    required this.proofBytes,
    required this.proofMimeType,
  });

  final String fileName;
  final List<int> proofBytes;
  final String? proofMimeType;

  bool get _isImage {
    final String? mime = proofMimeType?.toLowerCase();
    if (mime != null && mime.startsWith('image/')) {
      return true;
    }
    final String name = fileName.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  bool get _isPdf {
    final String? mime = proofMimeType?.toLowerCase();
    if (mime == 'application/pdf') {
      return true;
    }
    return fileName.toLowerCase().endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(theme.radius.sm),
              child: Image.memory(
                Uint8List.fromList(proofBytes),
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
                border: theme.borders.all(),
              ),
              child: Icon(
                _isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.insert_drive_file_outlined,
                size: 36,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Text(
              fileName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
          ),
        ],
      ),
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

    return AppSectionPanel(
      title: title,
      description: body,
      leadingIcon: Icons.support_agent_outlined,
      tone: AppWorkspaceStatusTone.info,
      children: <Widget>[
        if (adminContact.email != null)
          _ContactDetail(
            label: emailLabel,
            value: adminContact.email!,
            icon: Icons.mail_outline,
            color: colorScheme.primary,
          ),
        if (adminContact.phone != null)
          _ContactDetail(
            label: phoneLabel,
            value: adminContact.phone!,
            icon: Icons.phone_outlined,
            color: colorScheme.primary,
          ),
      ],
    );
  }
}

class _ContactDetail extends StatelessWidget {
  const _ContactDetail({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              SelectableText(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
