import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';

class ClinicalRequestBillingPanel extends ConsumerStatefulWidget {
  const ClinicalRequestBillingPanel({
    required this.lineItems,
    this.initialPaymentStatus,
    this.initialPaidAmount,
    this.initialCurrency,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final List<ClinicalRequestBillingLineItem> lineItems;
  final ClinicalRequestPaymentStatus? initialPaymentStatus;
  final num? initialPaidAmount;
  final String? initialCurrency;
  final bool enabled;
  final ValueChanged<ClinicalRequestBillingSubmit>? onChanged;

  @override
  ConsumerState<ClinicalRequestBillingPanel> createState() =>
      _ClinicalRequestBillingPanelState();
}

class _ClinicalRequestBillingPanelState
    extends ConsumerState<ClinicalRequestBillingPanel> {
  late ClinicalRequestPaymentMode _mode;
  late String _currency;
  late String _paymentMethod;
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _currency =
        widget.initialCurrency?.trim().toUpperCase() ??
        resolveClinicalRequestBillingCurrency(widget.lineItems);
    _paymentMethod = clinicalRequestPaymentMethods.first;
    final ClinicalRequestPaymentStatus initialStatus =
        widget.initialPaymentStatus ?? ClinicalRequestPaymentStatus.unpaid;
    _mode = initialStatus == ClinicalRequestPaymentStatus.paid
        ? ClinicalRequestPaymentMode.payNow
        : ClinicalRequestPaymentMode.billLater;
    _amountController = TextEditingController(
      text: opdCurrencyAmountInput(
        widget.initialPaidAmount ?? clinicalRequestBillingTotal(widget.lineItems),
      ),
    );
    _referenceController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialized = true;
      _notifyChanged();
    });
  }

  @override
  void didUpdateWidget(covariant ClinicalRequestBillingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized) {
      return;
    }
    if (_lineItemsChanged(oldWidget.lineItems, widget.lineItems) ||
        oldWidget.initialCurrency != widget.initialCurrency) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyChanged());
    }
  }

  bool _lineItemsChanged(
    List<ClinicalRequestBillingLineItem> previous,
    List<ClinicalRequestBillingLineItem> next,
  ) {
    if (previous.length != next.length) {
      return true;
    }
    for (var index = 0; index < previous.length; index++) {
      final ClinicalRequestBillingLineItem before = previous[index];
      final ClinicalRequestBillingLineItem after = next[index];
      if (before.id != after.id ||
          before.label != after.label ||
          before.quantity != after.quantity ||
          before.unitPrice != after.unitPrice ||
          before.currency != after.currency) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool canRecordPayment = ref
        .watch(appAccessPolicyProvider)
        .grants(AppPermissions.billingWrite);
    final List<ClinicalRequestBillingLineItem> lineItems = widget.lineItems;
    final num total = clinicalRequestBillingTotal(lineItems);
    final bool hasMissingPrices = clinicalRequestBillingHasMissingPrices(
      lineItems,
    );
    final ClinicalRequestPaymentStatus paymentStatus = _resolvePaymentStatus(
      total: total,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(theme.spacing.xs),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.receipt_long_outlined,
                  color: colorScheme.primary,
                  size: theme.appTokens.listIconSize,
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Text(
                    l10n.clinicalRequestBillingSectionTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.initialPaymentStatus != null)
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: clinicalRequestPaymentStatusLabel(
                        l10n,
                        widget.initialPaymentStatus!,
                      ),
                      tone: _paymentStatusTone(widget.initialPaymentStatus!),
                      icon: Icons.payments_outlined,
                    ),
                  ),
              ],
            ),
            if (hasMissingPrices) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label: l10n.clinicalRequestPriceWarningLabel,
                  tone: AppWorkspaceStatusTone.warning,
                  icon: Icons.warning_amber_outlined,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.sm),
            if (lineItems.isEmpty)
              Text(
                l10n.clinicalRequestBillingNoItemsLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: <Widget>[
                  for (final ClinicalRequestBillingLineItem item in lineItems)
                    _BillingLineRow(item: item, currency: _currency),
                ],
              ),
            Divider(height: theme.spacing.lg, color: colorScheme.outlineVariant),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.clinicalRequestBillingTotalLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  clinicalRequestPriceLabel(context, total > 0 ? total : null, _currency),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: clinicalRequestPaymentStatusLabel(l10n, paymentStatus),
                tone: _paymentStatusTone(paymentStatus),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            if (canRecordPayment) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              SegmentedButton<ClinicalRequestPaymentMode>(
                segments: <ButtonSegment<ClinicalRequestPaymentMode>>[
                  ButtonSegment<ClinicalRequestPaymentMode>(
                    value: ClinicalRequestPaymentMode.billLater,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(l10n.clinicalRequestBillLaterAction),
                  ),
                  ButtonSegment<ClinicalRequestPaymentMode>(
                    value: ClinicalRequestPaymentMode.payNow,
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(l10n.clinicalRequestPayNowAction),
                  ),
                ],
                selected: <ClinicalRequestPaymentMode>{_mode},
                showSelectedIcon: false,
                onSelectionChanged: widget.enabled
                    ? (Set<ClinicalRequestPaymentMode> values) {
                        setState(() => _mode = values.first);
                        _notifyChanged();
                      }
                    : null,
              ),
              if (_mode == ClinicalRequestPaymentMode.payNow) ...<Widget>[
                SizedBox(height: theme.spacing.md),
                AppCurrencyAmountField(
                  amountController: _amountController,
                  currency: _currency,
                  amountLabelText: l10n.opdAmountLabel,
                  currencyLabelText: l10n.opdCurrencyLabel,
                  enabled: widget.enabled,
                  onAmountChanged: (_) => _notifyChanged(),
                  onCurrencyChanged: (String? value) {
                    setState(() {
                      _currency = value ?? appDefaultCurrencyCode;
                    });
                    _notifyChanged();
                  },
                ),
                SizedBox(height: theme.spacing.sm),
                AppSelectField<String>(
                  value: _paymentMethod,
                  labelText: l10n.opdPaymentMethodLabel,
                  enabled: widget.enabled,
                  onChanged: (String? value) {
                    setState(() {
                      _paymentMethod = value ?? _paymentMethod;
                    });
                    _notifyChanged();
                  },
                  options: clinicalRequestPaymentMethods
                      .map(
                        (String method) => AppSelectOption<String>(
                          value: method,
                          label: AppDisplay.apiLabel(method),
                        ),
                      )
                      .toList(growable: false),
                ),
                SizedBox(height: theme.spacing.sm),
                AppTextField(
                  controller: _referenceController,
                  labelText: l10n.opdTransactionReferenceLabel,
                  enabled: widget.enabled,
                  onChanged: (_) => _notifyChanged(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  ClinicalRequestPaymentStatus _resolvePaymentStatus({required num total}) {
    if (_mode == ClinicalRequestPaymentMode.billLater || total <= 0) {
      return ClinicalRequestPaymentStatus.unpaid;
    }
    final num? paid = num.tryParse(_amountController.text.trim());
    if (paid == null || paid <= 0) {
      return ClinicalRequestPaymentStatus.unpaid;
    }
    if (paid >= total) {
      return ClinicalRequestPaymentStatus.paid;
    }
    return ClinicalRequestPaymentStatus.partial;
  }

  void _notifyChanged() {
    if (!_initialized || widget.onChanged == null) {
      return;
    }
    final num total = clinicalRequestBillingTotal(widget.lineItems);
    final ClinicalRequestPaymentStatus paymentStatus = _resolvePaymentStatus(
      total: total,
    );
    final num? paidAmount = _mode == ClinicalRequestPaymentMode.payNow
        ? num.tryParse(_amountController.text.trim())
        : null;
    widget.onChanged!(
      ClinicalRequestBillingSubmit(
        mode: _mode,
        totalAmount: total,
        currency: _currency,
        paymentStatus: paymentStatus,
        paidAmount: paidAmount,
        paymentMethod:
            _mode == ClinicalRequestPaymentMode.payNow ? _paymentMethod : null,
        paymentReference:
            _mode == ClinicalRequestPaymentMode.payNow
                ? _referenceController.text.trim()
                : null,
        lineItems: widget.lineItems,
      ),
    );
  }
}

class _BillingLineRow extends StatelessWidget {
  const _BillingLineRow({required this.item, required this.currency});

  final ClinicalRequestBillingLineItem item;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String unitLabel = clinicalRequestPriceLabel(
      context,
      item.unitPrice,
      item.currency ?? currency,
    );
    final String? lineTotalLabel = item.lineTotal == null
        ? null
        : clinicalRequestPriceLabel(
            context,
            item.lineTotal,
            item.currency ?? currency,
          );

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item.quantity} × $unitLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (lineTotalLabel != null)
            Text(
              lineTotalLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

AppWorkspaceStatusTone _paymentStatusTone(ClinicalRequestPaymentStatus status) {
  return switch (status) {
    ClinicalRequestPaymentStatus.paid => AppWorkspaceStatusTone.success,
    ClinicalRequestPaymentStatus.partial => AppWorkspaceStatusTone.warning,
    ClinicalRequestPaymentStatus.unpaid => AppWorkspaceStatusTone.warning,
    ClinicalRequestPaymentStatus.notBilled => AppWorkspaceStatusTone.neutral,
  };
}
