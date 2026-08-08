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
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/errors/validation_message_presenter.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/subscriptions/subscription_plan_theme.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_payment_methods.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_plan_selector.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum _UpgradeStep { plan, pay, confirm }

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
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

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
  String? _proofFileName;
  List<int>? _proofBytes;
  String? _proofMimeType;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  _UpgradeStep _step = _UpgradeStep.plan;

  static const List<SubscriptionPaymentMethodId> _payChannels =
      <SubscriptionPaymentMethodId>[
        SubscriptionPaymentMethodId.mobileMoney,
        SubscriptionPaymentMethodId.bankTransfer,
        SubscriptionPaymentMethodId.other,
      ];

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
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

  bool get _isNoPaymentPlan {
    final SubscriptionUpgradePlanOption? plan = _selectedPlan;
    if (plan == null) {
      return false;
    }
    return plan.isNoPaymentPlan(_billingCycle);
  }

  List<_UpgradeStep> get _steps {
    if (_isNoPaymentPlan) {
      return const <_UpgradeStep>[_UpgradeStep.plan, _UpgradeStep.confirm];
    }
    return const <_UpgradeStep>[_UpgradeStep.plan, _UpgradeStep.pay];
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
                    whatsappLabel:
                        l10n.subscriptionUpgradeAdminContactWhatsappLabel,
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

  String _billingCycleLabel(AppLocalizations l10n) {
    return switch (_billingCycle) {
      SubscriptionUpgradeBillingCycle.monthly =>
        l10n.subscriptionUpgradeBillingMonthlyLabel,
      SubscriptionUpgradeBillingCycle.annual =>
        l10n.subscriptionUpgradeBillingAnnualLabel,
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

    if (result.isFailure) {
      setState(() {
        _failure = (result as ResultFailure<SubscriptionUpgradeContext>).failure;
        _isLoading = false;
      });
      return;
    }

    final SubscriptionUpgradeContext contextData =
        (result as ResultSuccess<SubscriptionUpgradeContext>).value;

    final String? currentPlanId =
        contextData.currentPlanId ??
        contextData.summary?.planId ??
        widget.initialSummary?.planId;
    final List<SubscriptionUpgradePlanOption> commercialPlans = contextData
        .plans
        .where(
          (SubscriptionUpgradePlanOption plan) => !plan.isDeveloperPlan,
        )
        .toList(growable: false);

    final String? preferredPlanId =
        currentPlanId ??
        contextData.recommendedPlanId ??
        commercialPlans.firstOrNull?.id;

    final bool preferredInCatalog =
        preferredPlanId != null &&
        commercialPlans.any(
          (SubscriptionUpgradePlanOption plan) => plan.id == preferredPlanId,
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

    _currency = ref.read(tenantDefaultCurrencyProvider);
    _selectedPlanId = selectedPlanId;
    _billingCycle = billingCycle;
    _context = contextData;
    _syncUsdPriceFromSelection();
    await _refreshDisplayFxRate();
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
    unawaited(_applyConvertedAmount());
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
      case _UpgradeStep.pay:
        return validateAndSaveAppForm(_formKey);
      case _UpgradeStep.confirm:
        return true;
    }
  }

  void _goNext() {
    if (!_validateCurrentStep()) {
      return;
    }
    if (_step == _UpgradeStep.plan && !_canProceedWithSelectedPlan()) {
      setState(() {
        _failure = AppFailure.validation(
          detailMessage: context.l10n.subscriptionUpgradeHigherPackageOnlyMessage,
        );
      });
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

  int _planRank(SubscriptionUpgradePlanOption? plan) {
    if (plan == null) {
      return -1;
    }
    const Map<String, int> ranks = <String, int>{
      'FREE': 0,
      'BASIC': 1,
      'ADVANCED': 2,
      'PRO': 3,
      'CUSTOM': 4,
      'DEVELOPER': 5,
    };
    final String tier = (plan.tierCode ?? '').trim().toUpperCase();
    if (ranks.containsKey(tier)) {
      return ranks[tier]!;
    }
    return plan.price?.round() ?? -1;
  }

  bool _canProceedWithSelectedPlan() {
    final SubscriptionUpgradeContext? contextData = _context;
    final SubscriptionUpgradePlanOption? selected = _selectedPlan;
    if (contextData == null || selected == null) {
      return false;
    }

    final SubscriptionPendingPaymentRequest? pending =
        contextData.pendingPaymentRequest;
    final SubscriptionUpgradePolicy policy = contextData.policy;

    if (pending == null && policy.canSubmitPaymentRequest) {
      return true;
    }

    final int selectedRank = _planRank(selected);
    final int floorRank =
        policy.pendingTargetPlanRank ??
        _planRank(
          contextData.plans
              .where(
                (SubscriptionUpgradePlanOption plan) =>
                    plan.id ==
                    (pending?.targetPlanId ??
                        contextData.scheduledPlanChange?.pendingPlanId),
              )
              .firstOrNull,
        );

    if (floorRank < 0) {
      return selectedRank > (policy.currentPlanRank ?? -1);
    }

    return selectedRank > floorRank;
  }

  Widget _buildPolicyBanners({
    required AppLocalizations l10n,
    required ThemeData theme,
    required SubscriptionUpgradeContext? contextData,
  }) {
    if (contextData == null) {
      return const SizedBox.shrink();
    }

    final List<Widget> banners = <Widget>[];
    final SubscriptionPendingPaymentRequest? pending =
        contextData.pendingPaymentRequest;
    final SubscriptionScheduledPlanChange? scheduled =
        contextData.scheduledPlanChange;

    if (pending != null && pending.isPending) {
      banners.add(
        AppMessagePanel(
          title: l10n.subscriptionUpgradePendingRequestTitle,
          message: l10n.subscriptionUpgradePendingRequestBody(
            pending.planLabel?.trim().isNotEmpty == true
                ? pending.planLabel!
                : (contextData.currentPlanLabel ?? '—'),
          ),
          icon: Icons.hourglass_top_outlined,
          tone: AppWorkspaceStatusTone.info,
          density: AppContentPanelDensity.compact,
        ),
      );
    }

    if (scheduled != null) {
      final String startDate = scheduled.changeEffectiveAt != null
          ? AppFormatters.mediumDate(
              scheduled.changeEffectiveAt!.toLocal(),
              Localizations.localeOf(context),
            )
          : '—';
      banners.add(
        AppMessagePanel(
          message: l10n.subscriptionUpgradeScheduledChangeBody(
            scheduled.pendingPlanLabel?.trim().isNotEmpty == true
                ? scheduled.pendingPlanLabel!
                : '—',
            startDate,
          ),
          icon: Icons.event_available_outlined,
          tone: AppWorkspaceStatusTone.info,
          density: AppContentPanelDensity.compact,
        ),
      );
    } else if (contextData.policy.prepaidStartsAfterCurrent) {
      banners.add(
        AppMessagePanel(
          message: l10n.subscriptionUpgradePrepaidStartsAfterBody,
          icon: Icons.schedule_outlined,
          tone: AppWorkspaceStatusTone.info,
          density: AppContentPanelDensity.compact,
        ),
      );
    }

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < banners.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: theme.spacing.sm),
          banners[i],
        ],
        SizedBox(height: theme.spacing.md),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) {
      return;
    }
    if (!_canProceedWithSelectedPlan()) {
      setState(() {
        _failure = AppFailure.validation(
          detailMessage:
              context.l10n.subscriptionUpgradeHigherPackageOnlyMessage,
        );
      });
      return;
    }

    final bool noPayment = _isNoPaymentPlan;
    final String? planId = _selectedPlanId;
    if (planId == null || planId.isEmpty) {
      setState(() => _step = _UpgradeStep.plan);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

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
            reference: null,
            notes: _buildSubmissionNotes(noPayment: noPayment),
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
        : 'flow:$intent;billing_cycle:${_billingCycleServerValue()};channel:${_paymentMethod.serverValue}';
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
      _UpgradeStep.pay => l10n.subscriptionUpgradeStepPayTitle,
      _UpgradeStep.confirm => l10n.subscriptionUpgradeStepConfirmTitle,
    };
  }

  String _formattedAmountDue(BuildContext context) {
    final String raw = normalizeCurrencyAmount(_amountController.text);
    final double? amount = double.tryParse(raw);
    if (amount == null) {
      return _amountController.text.trim().isEmpty
          ? '—'
          : '${_currency.trim().toUpperCase()} ${_amountController.text.trim()}';
    }
    return AppFormatters.currency(
      amount,
      Localizations.localeOf(context),
      currencyCode: _currency,
      decimalDigits: decimalDigitsForCurrency(_currency),
    );
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
    ref.listen<String>(tenantDefaultCurrencyProvider, (
      String? previous,
      String next,
    ) {
      if (previous == next ||
          next.trim().toUpperCase() == _currency.trim().toUpperCase()) {
        return;
      }
      unawaited(_onCurrencyChanged(next));
    });

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

    final double viewportWidth = MediaQuery.sizeOf(context).width;
    final double planStepMaxWidth = viewportWidth < AppBreakpoints.md
        ? viewportWidth
        : viewportWidth < AppBreakpoints.lg
        ? 720
        : 920;

    return AppDialog(
      title: Text(_dialogTitle(l10n)),
      icon: Icon(
        noPayment
            ? Icons.check_circle_outline
            : (isRenewal
                  ? Icons.autorenew
                  : Icons.workspace_premium_outlined),
      ),
      maxWidth: noPayment ? 560 : planStepMaxWidth,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        autovalidateMode: _autovalidateMode,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          if (_step != _UpgradeStep.plan && _step != _UpgradeStep.pay) ...<Widget>[
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
                  : l10n.subscriptionUpgradeNotifyAdminsAction)
            : l10n.commonNextActionLabel,
        showBack: !_isFirstStep,
        isSubmitting: _isSubmitting,
        primaryIcon: _isLastStep
            ? (noPayment
                  ? Icons.check_circle_outline
                  : Icons.notifications_active_outlined)
            : Icons.arrow_forward,
        onCancel: () => Navigator.of(context).maybePop(),
        onBack: _goBack,
        onPrimary: _isLastStep
            ? (_canProceedWithSelectedPlan() ? _submit : null)
            : (_step == _UpgradeStep.plan && !_canProceedWithSelectedPlan()
                  ? null
                  : _goNext),
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
          _buildPolicyBanners(
            l10n: l10n,
            theme: theme,
            contextData: contextData,
          ),
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
          if (_failure != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            AppMessagePanel(
              message: ValidationMessagePresenter.displayMessage(
                _failure!,
                l10n,
              ),
              icon: Icons.error_outline,
              tone: AppWorkspaceStatusTone.error,
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
      _UpgradeStep.pay => _buildPayStep(
        l10n: l10n,
        theme: theme,
        colorScheme: colorScheme,
        contextData: contextData,
        adminContact: adminContact,
      ),
      _UpgradeStep.confirm => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppMessagePanel(
            message: l10n.subscriptionUpgradeFreePlanStepBody(
              _selectedPlanDisplayLabel(l10n),
            ),
            icon: Icons.verified_outlined,
            tone: AppWorkspaceStatusTone.success,
            density: AppContentPanelDensity.compact,
          ),
          SizedBox(height: theme.spacing.md),
          if (adminContact?.hasContact == true)
            _AdminContactSection(
              adminContact: adminContact!,
              title: l10n.subscriptionUpgradeFreePlanAdminContactTitle,
              body: l10n.subscriptionUpgradeFreePlanAdminContactBody,
              emailLabel: l10n.subscriptionUpgradeAdminContactEmailLabel,
              phoneLabel: l10n.subscriptionUpgradeAdminContactPhoneLabel,
              whatsappLabel: l10n.subscriptionUpgradeAdminContactWhatsappLabel,
            ),
          SizedBox(height: theme.spacing.md),
          AppTextField(
            controller: _notesController,
            labelText: l10n.subscriptionUpgradeNotesLabel,
            maxLines: 2,
          ),
        ],
      ),
    };
  }

  Widget _buildPayStep({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required SubscriptionUpgradeContext? contextData,
    required PlatformAdminContact? adminContact,
  }) {
    final PlatformBankTransferDetails? bank = contextData?.bankTransferDetails;
    final PlatformMobileMoneyDetails? mobile = contextData?.mobileMoneyDetails;
    final String planLabel = _selectedPlanDisplayLabel(l10n);
    final SubscriptionPlanTheme planTheme = SubscriptionPlanTheme.resolve(
      theme,
      _selectedPlan?.tierCode ?? planLabel,
    );
    final List<(String, String)> bankRows = <(String, String)>[
      if (bank?.accountName != null)
        (l10n.subscriptionBankAccountNameLabel, bank!.accountName!),
      if (bank?.bankName != null)
        (l10n.subscriptionPlatformBankNameLabel, bank!.bankName!),
      if (bank?.branch != null)
        (l10n.subscriptionBankBranchLabel, bank!.branch!),
      if (bank?.accountNumber != null)
        (l10n.subscriptionBankAccountNumberLabel, bank!.accountNumber!),
      if (bank?.swiftCode != null)
        (l10n.subscriptionBankSwiftLabel, bank!.swiftCode!),
      if (bank?.iban != null) (l10n.subscriptionBankIbanLabel, bank!.iban!),
    ];
    final List<(String, String)> mobileRows = <(String, String)>[
      if (mobile?.accountName != null)
        (l10n.subscriptionMobileMoneyAccountNameLabel, mobile!.accountName!),
      if (mobile?.mtn != null)
        (l10n.subscriptionMobileMoneyMtnLabel, mobile!.mtn!),
      if (mobile?.airtel != null)
        (l10n.subscriptionMobileMoneyAirtelLabel, mobile!.airtel!),
    ];
    final bool showBank =
        _paymentMethod == SubscriptionPaymentMethodId.bankTransfer ||
        _paymentMethod == SubscriptionPaymentMethodId.other;
    final bool showMobile =
        _paymentMethod == SubscriptionPaymentMethodId.mobileMoney ||
        _paymentMethod == SubscriptionPaymentMethodId.other;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PaySummaryStrip(
          planLabel: planLabel,
          billingCycleLabel: _billingCycleLabel(l10n),
          amountDueLabel: l10n.subscriptionUpgradeAmountDueLabel,
          amountValue: _isFxLoading ? null : _formattedAmountDue(context),
          isLoading: _isFxLoading,
          planTheme: planTheme,
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
        SizedBox(height: theme.spacing.md),
        _PayStepHeader(
          step: '1',
          title: l10n.subscriptionUpgradePaymentChannelLabel,
          accent: colorScheme.tertiary,
        ),
        SizedBox(height: theme.spacing.sm),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wrap = constraints.maxWidth < 520;
            final List<Widget> methodCards = <Widget>[
              for (final SubscriptionPaymentMethodId channel in _payChannels)
                _PayMethodTile(
                  selected: _paymentMethod == channel,
                  label: subscriptionPaymentMethodLabel(l10n, channel),
                  icon: switch (channel) {
                    SubscriptionPaymentMethodId.mobileMoney =>
                      Icons.phone_android_outlined,
                    SubscriptionPaymentMethodId.bankTransfer =>
                      Icons.account_balance_outlined,
                    _ => Icons.more_horiz,
                  },
                  accent: switch (channel) {
                    SubscriptionPaymentMethodId.mobileMoney =>
                      const Color(0xFFF59E0B),
                    SubscriptionPaymentMethodId.bankTransfer =>
                      const Color(0xFF2563EB),
                    _ => colorScheme.secondary,
                  },
                  onTap: () => setState(() => _paymentMethod = channel),
                ),
            ];
            if (wrap) {
              return Column(
                children: <Widget>[
                  for (int i = 0; i < methodCards.length; i++) ...<Widget>[
                    if (i > 0) SizedBox(height: theme.spacing.xs),
                    methodCards[i],
                  ],
                ],
              );
            }
            return Row(
              children: <Widget>[
                for (int i = 0; i < methodCards.length; i++) ...<Widget>[
                  if (i > 0) SizedBox(width: theme.spacing.xs),
                  Expanded(child: methodCards[i]),
                ],
              ],
            );
          },
        ),
        SizedBox(height: theme.spacing.md),
        _PayStepHeader(
          step: '2',
          title: l10n.subscriptionUpgradePayDestinationLabel,
          accent: const Color(0xFF16A34A),
        ),
        if (_paymentMethod == SubscriptionPaymentMethodId.other) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            l10n.subscriptionUpgradePayOtherDestinationBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        SizedBox(height: theme.spacing.sm),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget? bankCard = showBank && bankRows.isNotEmpty
                ? _PayDestinationCard(
                    icon: Icons.account_balance_outlined,
                    title: l10n.subscriptionBankTransferDetailsTitle,
                    accent: const Color(0xFF2563EB),
                    rows: bankRows,
                    copyTooltip: l10n.subscriptionUpgradeCopyValueAction,
                    onCopied: () => _showCopiedSnack(l10n),
                  )
                : null;
            final Widget? mobileCard = showMobile && mobileRows.isNotEmpty
                ? _PayDestinationCard(
                    icon: Icons.phone_android_outlined,
                    title: l10n.subscriptionMobileMoneyDetailsTitle,
                    accent: const Color(0xFFF59E0B),
                    rows: mobileRows,
                    copyTooltip: l10n.subscriptionUpgradeCopyValueAction,
                    onCopied: () => _showCopiedSnack(l10n),
                  )
                : null;

            if (bankCard == null && mobileCard == null) {
              return AppMessagePanel(
                message: l10n.subscriptionUpgradePayOtherDestinationBody,
                icon: Icons.info_outline,
                density: AppContentPanelDensity.compact,
              );
            }

            final bool sideBySide =
                constraints.maxWidth >= 640 &&
                bankCard != null &&
                mobileCard != null;

            if (sideBySide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: SizedBox.expand(child: bankCard)),
                    SizedBox(width: theme.spacing.sm),
                    Expanded(child: SizedBox.expand(child: mobileCard)),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ?bankCard,
                if (bankCard != null && mobileCard != null)
                  SizedBox(height: theme.spacing.sm),
                ?mobileCard,
              ],
            );
          },
        ),
        SizedBox(height: theme.spacing.md),
        _PayStepHeader(
          step: '3',
          title: l10n.subscriptionUpgradePayNotifyLabel,
          accent: const Color(0xFF7C3AED),
        ),
        SizedBox(height: theme.spacing.sm),
        _PayNotifyCard(
          title: l10n.subscriptionUpgradeAdminContactTitle,
          guidance: l10n.subscriptionUpgradePayContactGuidance,
          adminContact: adminContact,
          emailLabel: l10n.subscriptionUpgradeAdminContactEmailLabel,
          phoneLabel: l10n.subscriptionUpgradeAdminContactPhoneLabel,
          whatsappLabel: l10n.subscriptionUpgradeAdminContactWhatsappLabel,
          copyTooltip: l10n.subscriptionUpgradeCopyValueAction,
          onCopied: () => _showCopiedSnack(l10n),
        ),
        SizedBox(height: theme.spacing.md),
        _PayStepHeader(
          step: '4',
          title: l10n.subscriptionUpgradePayExtrasLabel,
          accent: colorScheme.primary,
        ),
        SizedBox(height: theme.spacing.sm),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget notes = _PayExtrasCard(
              accent: colorScheme.primary,
              icon: Icons.notes_outlined,
              title: l10n.subscriptionUpgradeNotesLabel,
              child: AppTextField(
                controller: _notesController,
                labelText: l10n.subscriptionUpgradeNotesLabel,
                maxLines: 3,
              ),
            );
            final Widget proof = _PayExtrasCard(
              accent: const Color(0xFF0891B2),
              icon: Icons.attach_file_outlined,
              title: l10n.subscriptionUpgradeProofLabel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.subscriptionUpgradeProofOptionalBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Wrap(
                    spacing: theme.spacing.xs,
                    runSpacing: theme.spacing.xs,
                    children: <Widget>[
                      AppButton.secondary(
                        label: l10n.subscriptionUpgradeAttachProofAction,
                        leadingIcon: Icons.attach_file_outlined,
                        enabled: !_isSubmitting,
                        onPressed: _isSubmitting ? null : _pickProof,
                      ),
                      if (_proofFileName != null)
                        AppButton.tertiary(
                          label: l10n.subscriptionUpgradeRemoveProofAction,
                          leadingIcon: Icons.close,
                          enabled: !_isSubmitting,
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                  _proofFileName = null;
                                  _proofBytes = null;
                                  _proofMimeType = null;
                                }),
                        ),
                    ],
                  ),
                  if (_proofFileName != null)
                    Padding(
                      padding: EdgeInsets.only(top: theme.spacing.xs),
                      child: Text(
                        _proofFileName!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: AppFontWeight.emphasis,
                        ),
                      ),
                    ),
                ],
              ),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  notes,
                  SizedBox(height: theme.spacing.sm),
                  proof,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: SizedBox.expand(child: notes)),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(child: SizedBox.expand(child: proof)),
                ],
              ),
            );
          },
        ),
        if (_proofFileName != null && _proofBytes != null) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          _ProofPreview(
            fileName: _proofFileName!,
            proofBytes: _proofBytes!,
            proofMimeType: _proofMimeType,
          ),
        ],
      ],
    );
  }

  void _showCopiedSnack(AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.subscriptionUpgradeValueCopiedMessage)),
    );
  }

  static String? _emptyToNull(String value) {
    final String normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class _PayStepHeader extends StatelessWidget {
  const _PayStepHeader({
    required this.step,
    required this.title,
    required this.accent,
  });

  final String step;
  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(theme.radius.sm),
          ),
          child: Text(
            step,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
        ),
      ],
    );
  }
}

class _PayMethodTile extends StatelessWidget {
  const _PayMethodTile({
    required this.selected,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.14)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radius.md),
        side: BorderSide(
          color: selected ? accent : theme.colorScheme.outlineVariant,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radius.md),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: accent, size: 20),
              SizedBox(width: theme.spacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: AppFontWeight.emphasis,
                    color: selected ? accent : null,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaySummaryStrip extends StatelessWidget {
  const _PaySummaryStrip({
    required this.planLabel,
    required this.billingCycleLabel,
    required this.amountDueLabel,
    required this.amountValue,
    required this.isLoading,
    required this.planTheme,
  });

  final String planLabel;
  final String billingCycleLabel;
  final String amountDueLabel;
  final String? amountValue;
  final bool isLoading;
  final SubscriptionPlanTheme planTheme;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            planTheme.background,
            planTheme.rowTint,
          ],
        ),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: planTheme.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm + 2,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stack = constraints.maxWidth < 360;
            final Widget planInfo = Row(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(theme.spacing.xs),
                  decoration: BoxDecoration(
                    color: planTheme.foreground.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(theme.radius.sm),
                  ),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    size: 22,
                    color: planTheme.foreground,
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        planLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: AppFontWeight.emphasis,
                          color: planTheme.foreground,
                        ),
                      ),
                      Text(
                        billingCycleLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: planTheme.foreground.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final Widget amountInfo = Column(
              crossAxisAlignment: stack
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  amountDueLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: planTheme.foreground.withValues(alpha: 0.75),
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: planTheme.foreground,
                    ),
                  )
                else
                  Text(
                    amountValue ?? '—',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                      color: planTheme.foreground,
                    ),
                  ),
              ],
            );

            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  planInfo,
                  SizedBox(height: theme.spacing.sm),
                  amountInfo,
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: planInfo),
                amountInfo,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PayDestinationCard extends StatelessWidget {
  const _PayDestinationCard({
    required this.icon,
    required this.title,
    required this.accent,
    required this.rows,
    required this.copyTooltip,
    required this.onCopied,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final List<(String, String)> rows;
  final String copyTooltip;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(theme.spacing.xs),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(theme.radius.sm),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                SizedBox(width: theme.spacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            for (int index = 0; index < rows.length; index++) ...<Widget>[
              if (index > 0) SizedBox(height: theme.spacing.xs),
              _CopyableDetailRow(
                label: rows[index].$1,
                value: rows[index].$2,
                accent: accent,
                copyTooltip: copyTooltip,
                onCopied: onCopied,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyableDetailRow extends StatelessWidget {
  const _CopyableDetailRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.copyTooltip,
    required this.onCopied,
  });

  final String label;
  final String value;
  final Color accent;
  final String copyTooltip;
  final VoidCallback onCopied;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: value));
    onCopied();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(theme.radius.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
            ),
            IconButton(
              tooltip: copyTooltip,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.copy_outlined, size: 16, color: accent),
              onPressed: () => unawaited(_copy()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayNotifyCard extends StatelessWidget {
  const _PayNotifyCard({
    required this.title,
    required this.guidance,
    required this.adminContact,
    required this.emailLabel,
    required this.phoneLabel,
    required this.whatsappLabel,
    required this.copyTooltip,
    required this.onCopied,
  });

  final String title;
  final String guidance;
  final PlatformAdminContact? adminContact;
  final String emailLabel;
  final String phoneLabel;
  final String whatsappLabel;
  final String copyTooltip;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const Color accent = Color(0xFF7C3AED);
    final List<(IconData, String, String)> chips = <(IconData, String, String)>[
      if (adminContact?.email != null)
        (Icons.mail_outline, emailLabel, adminContact!.email!),
      if (adminContact?.phone != null)
        (Icons.phone_outlined, phoneLabel, adminContact!.phone!),
      if (adminContact?.whatsapp != null)
        (Icons.chat_outlined, whatsappLabel, adminContact!.whatsapp!),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(theme.spacing.xs),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(theme.radius.sm),
                  ),
                  child: const Icon(
                    Icons.support_agent_outlined,
                    size: 18,
                    color: accent,
                  ),
                ),
                SizedBox(width: theme.spacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              guidance,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (chips.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  for (final (IconData icon, String label, String value)
                      in chips)
                    _CopyableContactChip(
                      icon: icon,
                      label: label,
                      value: value,
                      accent: accent,
                      copyTooltip: copyTooltip,
                      onCopied: onCopied,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyableContactChip extends StatelessWidget {
  const _CopyableContactChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.copyTooltip,
    required this.onCopied,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String copyTooltip;
  final VoidCallback onCopied;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: value));
    onCopied();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double maxChipWidth = MediaQuery.sizeOf(context).width * 0.9;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(theme.radius.sm),
      child: InkWell(
        onTap: () => unawaited(_copy()),
        borderRadius: BorderRadius.circular(theme.radius.sm),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxChipWidth),
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.radius.sm),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: accent),
              SizedBox(width: theme.spacing.xs),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '$label · ',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: value,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: AppFontWeight.emphasis,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: theme.spacing.xs),
              Tooltip(
                message: copyTooltip,
                child: Icon(Icons.copy_outlined, size: 14, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayExtrasCard extends StatelessWidget {
  const _PayExtrasCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.child,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: accent),
                SizedBox(width: theme.spacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            child,
          ],
        ),
      ),
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
    required this.whatsappLabel,
  });

  final PlatformAdminContact adminContact;
  final String title;
  final String body;
  final String emailLabel;
  final String phoneLabel;
  final String whatsappLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<Widget> contacts = <Widget>[
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
      if (adminContact.whatsapp != null)
        _ContactDetail(
          label: whatsappLabel,
          value: adminContact.whatsapp!,
          icon: Icons.chat_outlined,
          color: colorScheme.primary,
        ),
    ];

    return AppSectionPanel(
      title: title,
      description: body,
      leadingIcon: Icons.support_agent_outlined,
      tone: AppWorkspaceStatusTone.info,
      children: contacts,
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
