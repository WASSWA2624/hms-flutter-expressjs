import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_panel.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Compact summary strip for modular clinical request dialogs.
class ClinicalRequestFlowSummaryBar extends StatelessWidget {
  const ClinicalRequestFlowSummaryBar({
    required this.itemCount,
    required this.lineItems,
    this.billing,
    super.key,
  });

  final int itemCount;
  final List<ClinicalRequestBillingLineItem> lineItems;
  final ClinicalRequestBillingSubmit? billing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final num total = clinicalRequestBillingTotal(lineItems);
    final String currency = billing?.currency ??
        resolveClinicalRequestBillingCurrency(lineItems);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(theme.spacing.xs),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.receipt_long_outlined,
              color: colorScheme.primary,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                l10n.clinicalRequestFlowItemCountLabel(itemCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              clinicalRequestPriceLabel(
                context,
                itemCount > 0 && total > 0 ? total : null,
                currency,
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toolbar with actions to open nested catalog and billing dialogs.
class ClinicalRequestFlowToolbar extends StatelessWidget {
  const ClinicalRequestFlowToolbar({
    required this.onAddItems,
    this.onReviewBilling,
    this.addItemsLabel,
    this.enabled = true,
    this.showBillingAction = true,
    super.key,
  });

  final VoidCallback? onAddItems;
  final VoidCallback? onReviewBilling;
  final String? addItemsLabel;
  final bool enabled;
  final bool showBillingAction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      children: <Widget>[
        AppButton.secondary(
          label: addItemsLabel ?? l10n.clinicalRequestAddCatalogItemsAction,
          leadingIcon: Icons.add_circle_outline,
          enabled: enabled,
          onPressed: onAddItems,
        ),
        if (showBillingAction)
          AppButton.tertiary(
            label: l10n.clinicalRequestReviewBillingAction,
            leadingIcon: Icons.payments_outlined,
            enabled: enabled && onReviewBilling != null,
            onPressed: onReviewBilling,
          ),
      ],
    );
  }
}

/// Reusable selected catalog item row with price and actions.
class ClinicalRequestSelectedCatalogRow extends StatelessWidget {
  const ClinicalRequestSelectedCatalogRow({
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.leadingIcon,
    required this.onDelete,
    this.onEdit,
    this.isEditing = false,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String priceLabel;
  final IconData leadingIcon;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isEditing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isEditing
            ? colorScheme.primaryContainer.withValues(alpha: 0.38)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              leadingIcon,
              color: colorScheme.primary,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    priceLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                tooltip: l10n.clinicalLabRequestEditSelectionAction,
                onPressed: enabled ? onEdit : null,
                icon: const Icon(Icons.edit_outlined),
              ),
            IconButton(
              tooltip: l10n.clinicalLabRequestDeleteSelectionAction,
              onPressed: enabled ? onDelete : null,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

String clinicalRequestCatalogPriceLabel(
  BuildContext context,
  ClinicalActionCatalogOption option,
) {
  return clinicalRequestPriceLabel(
    context,
    clinicalCatalogOptionUnitPrice(option),
    clinicalCatalogOptionCurrency(option),
  );
}

Future<ClinicalRequestBillingSubmit?> showClinicalRequestBillingDialog({
  required BuildContext context,
  required List<ClinicalRequestBillingLineItem> lineItems,
  ClinicalRequestBillingSubmit? initialBilling,
  ClinicalRequestPaymentStatus? initialPaymentStatus,
  num? initialPaidAmount,
  String? initialCurrency,
  bool enabled = true,
}) {
  return showAppDialog<ClinicalRequestBillingSubmit>(
    context: context,
    barrierDismissible: enabled,
    builder: (BuildContext context) => _ClinicalRequestBillingDialog(
      lineItems: lineItems,
      initialBilling: initialBilling,
      initialPaymentStatus: initialPaymentStatus,
      initialPaidAmount: initialPaidAmount,
      initialCurrency: initialCurrency,
      enabled: enabled,
    ),
  );
}

class _ClinicalRequestBillingDialog extends StatefulWidget {
  const _ClinicalRequestBillingDialog({
    required this.lineItems,
    this.initialBilling,
    this.initialPaymentStatus,
    this.initialPaidAmount,
    this.initialCurrency,
    this.enabled = true,
  });

  final List<ClinicalRequestBillingLineItem> lineItems;
  final ClinicalRequestBillingSubmit? initialBilling;
  final ClinicalRequestPaymentStatus? initialPaymentStatus;
  final num? initialPaidAmount;
  final String? initialCurrency;
  final bool enabled;

  @override
  State<_ClinicalRequestBillingDialog> createState() =>
      _ClinicalRequestBillingDialogState();
}

class _ClinicalRequestBillingDialogState
    extends State<_ClinicalRequestBillingDialog> {
  ClinicalRequestBillingSubmit? _billing;

  /// Pre-fill catalog line items with any prices/quantities the user previously
  /// entered (carried on [initialBilling]) so editing a request keeps prior input.
  List<ClinicalRequestBillingLineItem> _mergeInitialBilling(
    List<ClinicalRequestBillingLineItem> items,
    ClinicalRequestBillingSubmit? billing,
  ) {
    if (billing == null || billing.lineItems.isEmpty) {
      return items;
    }
    final Map<String, ClinicalRequestBillingLineItem> priorById =
        <String, ClinicalRequestBillingLineItem>{
          for (final ClinicalRequestBillingLineItem line in billing.lineItems)
            line.id: line,
        };
    return <ClinicalRequestBillingLineItem>[
      for (final ClinicalRequestBillingLineItem item in items)
        if (priorById[item.id] case final ClinicalRequestBillingLineItem prior)
          ClinicalRequestBillingLineItem(
            id: item.id,
            label: item.label,
            quantity: prior.quantity,
            unitPrice: prior.unitPrice ?? item.unitPrice,
            currency: prior.currency ?? item.currency,
          )
        else
          item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ClinicalRequestBillingLineItem> effectiveLineItems =
        _mergeInitialBilling(widget.lineItems, widget.initialBilling);

    return AppDialog(
      title: Text(l10n.clinicalRequestBillingSectionTitle),
      icon: const Icon(Icons.payments_outlined),
      maxWidth: 560,
      scrollable: true,
      closeEnabled: widget.enabled,
      content: ClinicalRequestBillingPanel(
        lineItems: effectiveLineItems,
        initialPaymentStatus:
            widget.initialPaymentStatus ?? widget.initialBilling?.paymentStatus,
        initialPaidAmount:
            widget.initialPaidAmount ?? widget.initialBilling?.paidAmount,
        initialCurrency:
            widget.initialCurrency ?? widget.initialBilling?.currency,
        enabled: widget.enabled,
        onChanged: (ClinicalRequestBillingSubmit value) {
          _billing = value;
        },
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: widget.enabled,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.clinicalRequestCatalogPickerDoneAction,
          enabled: widget.enabled && widget.lineItems.isNotEmpty,
          onPressed: () => Navigator.of(context).pop(_billing),
        ),
      ],
    );
  }
}
