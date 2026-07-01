import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
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

  SubscriptionUpgradeContext? _context;
  AppFailure? _failure;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _selectedPlanId;
  String _paymentMethod = 'BANK_TRANSFER';
  String? _proofFileName;
  List<int>? _proofBytes;
  String? _proofMimeType;

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
    super.dispose();
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
        setState(() {
          _context = contextData;
          _selectedPlanId =
              contextData.recommendedPlanId ??
              contextData.plans.firstOrNull?.id;
          if (contextData.paymentMethods.isNotEmpty) {
            _paymentMethod = contextData.paymentMethods.first;
          }
          _isLoading = false;
        });
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
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
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
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    final String? planId = _selectedPlanId;
    if (planId == null || planId.isEmpty) {
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
            paymentMethod: _paymentMethod,
            amount: _emptyToNull(_amountController.text),
            reference: _emptyToNull(_referenceController.text),
            notes: _emptyToNull(_notesController.text),
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (_isLoading) {
      return AppDialog(
        title: Text(l10n.subscriptionUpgradeDialogTitle),
        icon: const Icon(Icons.workspace_premium_outlined),
        content: const SizedBox(
          width: 360,
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

    return AppDialog(
      title: Text(l10n.subscriptionUpgradeDialogTitle),
      icon: const Icon(Icons.workspace_premium_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          Text(
            l10n.subscriptionUpgradeDialogBody,
            style: theme.textTheme.bodyMedium,
          ),
          if (_failure != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              context.l10n.failureMessage(_failure!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          SizedBox(height: theme.spacing.md),
          AppSelectField<String>(
            value: _selectedPlanId,
            labelText: l10n.subscriptionUpgradePlanLabel,
            allowClear: false,
            options: (contextData?.plans ?? const <SubscriptionUpgradePlanOption>[])
                .map(
                  (SubscriptionUpgradePlanOption plan) => AppSelectOption<String>(
                    value: plan.id,
                    label: plan.tierCode == null
                        ? plan.label
                        : '${plan.label} (${plan.tierCode})',
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _selectedPlanId = value);
              }
            },
          ),
          AppSelectField<String>(
            value: _paymentMethod,
            labelText: l10n.subscriptionUpgradePaymentMethodLabel,
            allowClear: false,
            options: _paymentMethodOptions(l10n, contextData?.paymentMethods),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _paymentMethod = value);
              }
            },
          ),
          AppTextField(
            controller: _amountController,
            labelText: l10n.subscriptionUpgradeAmountLabel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          AppTextField(
            controller: _referenceController,
            labelText: l10n.subscriptionUpgradeReferenceLabel,
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.subscriptionUpgradeNotesLabel,
            maxLines: 3,
          ),
          SizedBox(height: theme.spacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                AppButton.secondary(
                  label: l10n.subscriptionUpgradeAttachProofAction,
                  leadingIcon: Icons.attach_file_outlined,
                  onPressed: _isSubmitting ? null : _pickProof,
                ),
                if (_proofFileName != null)
                  Text(
                    _proofFileName!,
                    style: theme.textTheme.bodySmall,
                  ),
                if (_proofFileName != null)
                  AppButton.tertiary(
                    label: l10n.subscriptionUpgradeRemoveProofAction,
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
          ),
          if (adminContact?.hasContact == true) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            Text(
              l10n.subscriptionUpgradeAdminContactTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              l10n.subscriptionUpgradeAdminContactBody,
              style: theme.textTheme.bodySmall,
            ),
            if (adminContact?.email != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              SelectableText(adminContact!.email!),
            ],
            if (adminContact?.phone != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              SelectableText(adminContact!.phone!),
            ],
          ],
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.subscriptionUpgradeSubmitAction,
        submitIcon: Icons.payments_outlined,
        isSubmitting: _isSubmitting,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }

  static String? _emptyToNull(String value) {
    final String normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

List<AppSelectOption<String>> _paymentMethodOptions(
  AppLocalizations l10n,
  List<String>? methods,
) {
  final List<String> values = methods == null || methods.isEmpty
      ? const <String>[
          'BANK_TRANSFER',
          'MOBILE_MONEY',
          'CREDIT_CARD',
          'DEBIT_CARD',
          'CASH',
          'OTHER',
        ]
      : methods;

  return values
      .map(
        (String method) => AppSelectOption<String>(
          value: method,
          label: _paymentMethodLabel(l10n, method),
        ),
      )
      .toList(growable: false);
}

String _paymentMethodLabel(AppLocalizations l10n, String method) {
  return switch (method.toUpperCase()) {
    'BANK_TRANSFER' => l10n.subscriptionPaymentMethodBankTransfer,
    'MOBILE_MONEY' => l10n.subscriptionPaymentMethodMobileMoney,
    'CREDIT_CARD' => l10n.subscriptionPaymentMethodCreditCard,
    'DEBIT_CARD' => l10n.subscriptionPaymentMethodDebitCard,
    'CASH' => l10n.subscriptionPaymentMethodCash,
    _ => l10n.subscriptionPaymentMethodOther,
  };
}
