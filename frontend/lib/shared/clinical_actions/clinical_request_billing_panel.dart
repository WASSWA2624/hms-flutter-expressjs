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
  final List<_EditableBillingLine> _lines = <_EditableBillingLine>[];
  bool _initialized = false;
  bool _amountTouched = false;

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
    _syncLines();
    _amountController = TextEditingController(
      text: opdCurrencyAmountInput(widget.initialPaidAmount ?? _currentTotal()),
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
      setState(_syncLines);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeSyncAmountToTotal();
        _notifyChanged();
      });
    }
  }

  /// Reconcile internal editable rows with the catalog-provided [lineItems],
  /// preserving any prices/quantities the user has manually overridden.
  void _syncLines() {
    final Map<String, _EditableBillingLine> existingById =
        <String, _EditableBillingLine>{
          for (final _EditableBillingLine line in _lines) line.id: line,
        };
    final List<_EditableBillingLine> next = <_EditableBillingLine>[];
    for (final ClinicalRequestBillingLineItem item in widget.lineItems) {
      final _EditableBillingLine? existing = existingById.remove(item.id);
      if (existing != null) {
        existing.reconcileWithCatalog(item);
        next.add(existing);
      } else {
        next.add(
          _EditableBillingLine.fromCatalog(item, onChanged: _onLineChanged),
        );
      }
    }
    for (final _EditableBillingLine leftover in existingById.values) {
      leftover.dispose();
    }
    _lines
      ..clear()
      ..addAll(next);
  }

  void _onLineChanged() {
    setState(() {});
    _maybeSyncAmountToTotal();
    _notifyChanged();
  }

  num _currentTotal() {
    var total = 0.0;
    for (final _EditableBillingLine line in _lines) {
      total += (line.lineTotal ?? 0).toDouble();
    }
    return total;
  }

  bool _hasMissingPrices() =>
      _lines.any((_EditableBillingLine line) => !line.hasPrice);

  List<ClinicalRequestBillingLineItem> _submitLineItems() {
    return <ClinicalRequestBillingLineItem>[
      for (final _EditableBillingLine line in _lines)
        ClinicalRequestBillingLineItem(
          id: line.id,
          label: line.label,
          quantity: line.quantity,
          unitPrice: line.unitPrice,
          currency: line.currency ?? _currency,
        ),
    ];
  }

  void _maybeSyncAmountToTotal() {
    if (_amountTouched || _mode != ClinicalRequestPaymentMode.payNow) {
      return;
    }
    _amountController.text = opdCurrencyAmountInput(_currentTotal());
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
    for (final _EditableBillingLine line in _lines) {
      line.dispose();
    }
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
    final bool canEditPrices = canRecordPayment && widget.enabled;
    final num total = _currentTotal();
    final bool hasMissingPrices = _hasMissingPrices();
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
            if (_lines.isEmpty)
              Text(
                l10n.clinicalRequestBillingNoItemsLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else if (canEditPrices) ...<Widget>[
              Text(
                l10n.clinicalRequestEditPricesHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              Column(
                children: <Widget>[
                  for (final _EditableBillingLine line in _lines)
                    _EditableBillingLineRow(
                      key: ValueKey<String>('billing-line-${line.id}'),
                      line: line,
                      currency: _currency,
                      enabled: widget.enabled,
                    ),
                ],
              ),
            ] else
              Column(
                children: <Widget>[
                  for (final _EditableBillingLine line in _lines)
                    _BillingLineRow(
                      item: line.toLineItem(_currency),
                      currency: _currency,
                    ),
                ],
              ),
            Divider(
              height: theme.spacing.lg,
              color: colorScheme.outlineVariant,
            ),
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
                  clinicalRequestPriceLabel(
                    context,
                    total > 0 ? total : null,
                    _currency,
                  ),
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
                        _maybeSyncAmountToTotal();
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
                  onAmountChanged: (_) {
                    _amountTouched = true;
                    _notifyChanged();
                  },
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
    final num total = _currentTotal();
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
        paymentMethod: _mode == ClinicalRequestPaymentMode.payNow
            ? _paymentMethod
            : null,
        paymentReference: _mode == ClinicalRequestPaymentMode.payNow
            ? _referenceController.text.trim()
            : null,
        lineItems: _submitLineItems(),
      ),
    );
  }
}

/// Mutable, editable representation of a single billing line within the panel.
class _EditableBillingLine {
  _EditableBillingLine({
    required this.id,
    required this.label,
    required this.currency,
    required num quantity,
    required num? unitPrice,
    required VoidCallback onChanged,
  }) : _quantity = quantity < 1 ? 1 : quantity,
       _baseQuantity = quantity,
       _baseUnitPrice = unitPrice,
       priceController = TextEditingController(
         text: unitPrice == null ? '' : opdCurrencyAmountInput(unitPrice),
       ) {
    priceController.addListener(onChanged);
    _onChanged = onChanged;
  }

  factory _EditableBillingLine.fromCatalog(
    ClinicalRequestBillingLineItem item, {
    required VoidCallback onChanged,
  }) {
    return _EditableBillingLine(
      id: item.id,
      label: item.label,
      currency: item.currency,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      onChanged: onChanged,
    );
  }

  final String id;
  String label;
  String? currency;
  final TextEditingController priceController;
  late final VoidCallback _onChanged;

  num _quantity;
  num _baseQuantity;
  num? _baseUnitPrice;

  num get quantity => _quantity;

  num? get unitPrice {
    final String text = priceController.text.trim();
    if (text.isEmpty) {
      return null;
    }
    return num.tryParse(text);
  }

  bool get hasPrice {
    final num? price = unitPrice;
    return price != null && price > 0;
  }

  num? get lineTotal {
    final num? price = unitPrice;
    if (price == null || price <= 0) {
      return null;
    }
    return price * _quantity;
  }

  bool get _priceOverridden {
    final num? current = unitPrice;
    if (current == null && _baseUnitPrice == null) {
      return false;
    }
    return current != _baseUnitPrice;
  }

  void setQuantity(num value) {
    _quantity = value < 1 ? 1 : value;
    _onChanged();
  }

  /// Adopt fresh catalog values when the parent re-supplies this line, unless the
  /// user has manually overridden the price/quantity.
  void reconcileWithCatalog(ClinicalRequestBillingLineItem item) {
    label = item.label;
    currency = item.currency;
    if (_quantity == _baseQuantity) {
      _quantity = item.quantity < 1 ? 1 : item.quantity;
    }
    _baseQuantity = item.quantity;
    if (!_priceOverridden && item.unitPrice != _baseUnitPrice) {
      priceController.text = item.unitPrice == null
          ? ''
          : opdCurrencyAmountInput(item.unitPrice);
    }
    _baseUnitPrice = item.unitPrice;
  }

  ClinicalRequestBillingLineItem toLineItem(String fallbackCurrency) {
    return ClinicalRequestBillingLineItem(
      id: id,
      label: label,
      quantity: _quantity,
      unitPrice: unitPrice,
      currency: currency ?? fallbackCurrency,
    );
  }

  void dispose() {
    priceController.removeListener(_onChanged);
    priceController.dispose();
  }
}

class _EditableBillingLineRow extends StatelessWidget {
  const _EditableBillingLineRow({
    required this.line,
    required this.currency,
    required this.enabled,
    super.key,
  });

  final _EditableBillingLine line;
  final String currency;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? lineTotalLabel = line.lineTotal == null
        ? null
        : clinicalRequestPriceLabel(
            context,
            line.lineTotal,
            line.currency ?? currency,
          );

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            line.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Row(
            children: <Widget>[
              _QuantityStepper(
                quantity: line.quantity,
                enabled: enabled,
                onChanged: line.setQuantity,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: AppTextField(
                  controller: line.priceController,
                  labelText: l10n.clinicalRequestUnitPriceLabel,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              SizedBox(
                width: 84,
                child: Text(
                  lineTotalLabel ?? l10n.clinicalRequestPriceNotSetLabel,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: lineTotalLabel == null
                        ? colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });

  final num quantity;
  final bool enabled;
  final ValueChanged<num> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(theme.spacing.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: theme.appTokens.listIconSize,
            onPressed: enabled && quantity > 1
                ? () => onChanged(quantity - 1)
                : null,
            icon: const Icon(Icons.remove),
          ),
          Text(
            '${quantity % 1 == 0 ? quantity.toInt() : quantity}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: theme.appTokens.listIconSize,
            onPressed: enabled ? () => onChanged(quantity + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
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
