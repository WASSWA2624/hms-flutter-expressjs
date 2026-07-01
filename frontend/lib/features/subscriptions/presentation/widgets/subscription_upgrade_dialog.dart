import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_payment_method_selector.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_payment_methods.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

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
  String? _selectedPlanId;
  String _currency = appDefaultCurrencyCode;
  SubscriptionPaymentMethodId _paymentMethod =
      SubscriptionPaymentMethodId.mobileMoney;
  MobileMoneyProviderId _mobileMoneyProvider = MobileMoneyProviderId.mtn;
  String? _proofFileName;
  List<int>? _proofBytes;
  String? _proofMimeType;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    _bankNameController.dispose();
    _cardHolderController.dispose();
    _cardLastFourController.dispose();
    super.dispose();
  }

  SubscriptionPaymentFlowIntent get _flowIntent => resolveSubscriptionFlowIntent(
    currentPlanId: _context?.currentPlanId,
    selectedPlanId: _selectedPlanId,
  );

  SubscriptionUpgradePlanOption? get _selectedPlan {
    final String? planId = _selectedPlanId;
    if (planId == null) {
      return null;
    }
    for (final SubscriptionUpgradePlanOption plan in _context?.plans ??
        const <SubscriptionUpgradePlanOption>[]) {
      if (plan.id == planId) {
        return plan;
      }
    }
    return null;
  }

  String _planLabel(AppLocalizations l10n, SubscriptionUpgradePlanOption plan) {
    if (plan.tierCode == null || plan.tierCode!.isEmpty) {
      return plan.label;
    }
    return '${plan.label} (${plan.tierCode})';
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

        setState(() {
          _context = contextData;
          _selectedPlanId = preferRenewal
              ? currentPlanId
              : (contextData.recommendedPlanId ??
                    currentPlanId ??
                    contextData.plans.firstOrNull?.id);
          _isLoading = false;
        });

        final SubscriptionUpgradePlanOption? selectedPlan = _selectedPlan;
        if (selectedPlan?.price != null && _amountController.text.isEmpty) {
          _amountController.text = selectedPlan!.price!.toStringAsFixed(0);
        }
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoading = false;
        });
      },
    );
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
    });
  }

  Future<void> _submit() async {
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);

    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    final String? planId = _selectedPlanId;
    if (planId == null || planId.isEmpty) {
      return;
    }

    if (subscriptionPaymentMethodRequiresProof(_paymentMethod) &&
        _proofBytes == null) {
      setState(() {
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

    final String? provider = _paymentMethod ==
            SubscriptionPaymentMethodId.mobileMoney
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
            reference: _emptyToNull(_referenceController.text),
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
    final String composed = 'flow:$intent';
    if (base.isEmpty) {
      return composed;
    }
    return '$composed\n$base';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isRenewal =
        _flowIntent == SubscriptionPaymentFlowIntent.renewal;

    if (_isLoading) {
      return AppDialog(
        title: Text(l10n.subscriptionUpgradeDialogTitle),
        icon: const Icon(Icons.workspace_premium_outlined),
        content: const SizedBox(
          width: 420,
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      );
    }

    final SubscriptionUpgradeContext? contextData = _context;
    final PlatformAdminContact? adminContact =
        contextData?.platformAdminContact ?? widget.initialAdminContact;
    final SubscriptionUpgradePlanOption? selectedPlan = _selectedPlan;
    final String intentPlanLabel =
        selectedPlan?.label ?? contextData?.currentPlanLabel ?? l10n.subscriptionUpgradePlanLabel;

    return AppDialog(
      title: Text(
        isRenewal
            ? l10n.subscriptionRenewDialogTitle
            : l10n.subscriptionUpgradeDialogTitle,
      ),
      icon: Icon(
        isRenewal ? Icons.autorenew : Icons.workspace_premium_outlined,
      ),
      maxWidth: 560,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        autovalidateMode: _autovalidateMode,
        children: <Widget>[
          Text(
            isRenewal
                ? l10n.subscriptionRenewDialogBody
                : l10n.subscriptionUpgradeDialogBody,
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: theme.spacing.md),
          _IntentBanner(
            isRenewal: isRenewal,
            planLabel: intentPlanLabel,
            renewalText: l10n.subscriptionRenewIntentBanner(intentPlanLabel),
            upgradeText: l10n.subscriptionUpgradeIntentBanner,
          ),
          if (_failure != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              context.l10n.failureMessage(_failure!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
          SizedBox(height: theme.spacing.md),
          AppSelectField<String>(
            value: _selectedPlanId,
            labelText: l10n.subscriptionUpgradePlanLabel,
            isRequired: true,
            allowClear: false,
            options:
                (contextData?.plans ?? const <SubscriptionUpgradePlanOption>[])
                    .map(
                      (SubscriptionUpgradePlanOption plan) =>
                          AppSelectOption<String>(
                            value: plan.id,
                            label: _planLabel(l10n, plan),
                            leadingIcon: Icon(
                              plan.id == contextData?.currentPlanId
                                  ? Icons.autorenew
                                  : Icons.trending_up,
                              size: theme.appTokens.listIconSize,
                            ),
                          ),
                    )
                    .toList(growable: false),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedPlanId = value;
                final SubscriptionUpgradePlanOption? plan = _context?.plans
                    .where((SubscriptionUpgradePlanOption entry) => entry.id == value)
                    .firstOrNull;
                if (plan?.price != null) {
                  _amountController.text = plan!.price!.toStringAsFixed(0);
                }
              });
            },
          ),
          SizedBox(height: theme.spacing.lg),
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
              setState(() => _paymentMethod = method);
            },
          ),
          SizedBox(height: theme.spacing.lg),
          Text(
            l10n.subscriptionUpgradePaymentDetailsTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          ..._paymentDetailFields(l10n, theme),
          SizedBox(height: theme.spacing.md),
          AppCurrencyAmountField(
            amountController: _amountController,
            currency: _currency,
            onCurrencyChanged: (String? value) {
              if (value != null) {
                setState(() => _currency = value);
              }
            },
            amountLabelText: l10n.subscriptionUpgradeAmountLabel,
            currencyLabelText: l10n.billingCurrencyLabel,
            isRequired: true,
            allowZero: false,
            decimalDigits: 0,
          ),
          if (_paymentMethod != SubscriptionPaymentMethodId.other) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            AppTextField(
              controller: _referenceController,
              labelText: l10n.subscriptionUpgradeReferenceLabel,
              hintText: l10n.subscriptionPaymentReferenceHint,
              isRequired: _paymentMethod == SubscriptionPaymentMethodId.cash ||
                  subscriptionPaymentMethodRequiresProof(_paymentMethod),
            ),
          ],
          if (_paymentMethod == SubscriptionPaymentMethodId.mobileMoney ||
              _paymentMethod == SubscriptionPaymentMethodId.bankTransfer ||
              _paymentMethod == SubscriptionPaymentMethodId.cash) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            _ProofOfPaymentSection(
              fileName: _proofFileName,
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
          ],
          if (_paymentMethod != SubscriptionPaymentMethodId.other) ...<Widget>[
            AppTextField(
              controller: _notesController,
              labelText: l10n.subscriptionUpgradeNotesLabel,
              maxLines: 2,
            ),
          ],
          if (adminContact?.hasContact == true) ...<Widget>[
            SizedBox(height: theme.spacing.lg),
            _AdminContactSection(
              adminContact: adminContact!,
              title: l10n.subscriptionUpgradeAdminContactTitle,
              body: l10n.subscriptionUpgradeAdminContactBody,
            ),
          ],
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: isRenewal
            ? l10n.subscriptionRenewSubmitAction
            : l10n.subscriptionUpgradeSubmitAction,
        submitIcon: Icons.payments_outlined,
        isSubmitting: _isSubmitting,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }

  List<Widget> _paymentDetailFields(
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final List<Widget> fields = switch (_paymentMethod) {
      SubscriptionPaymentMethodId.mobileMoney => <Widget>[
        AppSelectField<MobileMoneyProviderId>(
          value: _mobileMoneyProvider,
          labelText: l10n.subscriptionMobileMoneyProviderLabel,
          isRequired: true,
          allowClear: false,
          options: MobileMoneyProviderId.values
              .map(
                (MobileMoneyProviderId provider) =>
                    AppSelectOption<MobileMoneyProviderId>(
                      value: provider,
                      label: mobileMoneyProviderLabel(l10n, provider),
                      leadingIcon: const Icon(Icons.account_balance_wallet_outlined),
                    ),
              )
              .toList(growable: false),
          onChanged: (MobileMoneyProviderId? value) {
            if (value != null) {
              setState(() => _mobileMoneyProvider = value);
            }
          },
        ),
        AppTextField(
          controller: _phoneController,
          labelText: l10n.subscriptionMobileMoneyPhoneLabel,
          keyboardType: TextInputType.phone,
          isRequired: true,
        ),
      ],
      SubscriptionPaymentMethodId.bankTransfer => <Widget>[
        AppTextField(
          controller: _bankNameController,
          labelText: l10n.subscriptionBankNameLabel,
          isRequired: true,
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
      SubscriptionPaymentMethodId.other => <Widget>[
        AppTextField(
          controller: _notesController,
          labelText: l10n.subscriptionUpgradeNotesLabel,
          maxLines: 3,
          isRequired: true,
        ),
      ],
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

class _IntentBanner extends StatelessWidget {
  const _IntentBanner({
    required this.isRenewal,
    required this.planLabel,
    required this.renewalText,
    required this.upgradeText,
  });

  final bool isRenewal;
  final String planLabel;
  final String renewalText;
  final String upgradeText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = isRenewal
        ? const Color(0xFF2563EB)
        : const Color(0xFF7C3AED);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isRenewal ? Icons.autorenew : Icons.trending_up,
            color: accent,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              isRenewal ? renewalText : upgradeText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofOfPaymentSection extends StatelessWidget {
  const _ProofOfPaymentSection({
    required this.fileName,
    required this.isSubmitting,
    required this.attachLabel,
    required this.removeLabel,
    required this.proofLabel,
    required this.onAttach,
    required this.onRemove,
  });

  final String? fileName;
  final bool isSubmitting;
  final String attachLabel;
  final String removeLabel;
  final String proofLabel;
  final VoidCallback onAttach;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
            if (fileName != null) Text(fileName!, style: theme.textTheme.bodySmall),
            if (fileName != null)
              AppButton.tertiary(
                label: removeLabel,
                onPressed: isSubmitting ? null : onRemove,
              ),
          ],
        ),
      ],
    );
  }
}

class _AdminContactSection extends StatelessWidget {
  const _AdminContactSection({
    required this.adminContact,
    required this.title,
    required this.body,
  });

  final PlatformAdminContact adminContact;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
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
          SizedBox(height: theme.spacing.xs),
          SelectableText(adminContact.email!),
        ],
        if (adminContact.phone != null) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          SelectableText(adminContact.phone!),
        ],
      ],
    );
  }
}
