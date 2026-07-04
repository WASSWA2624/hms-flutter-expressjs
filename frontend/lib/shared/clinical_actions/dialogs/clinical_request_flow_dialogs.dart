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
    final String currency =
        billing?.currency ?? resolveClinicalRequestBillingCurrency(lineItems);

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
    this.onRemoveSelected,
    this.addItemsLabel,
    this.enabled = true,
    this.showBillingAction = true,
    super.key,
  });

  final VoidCallback? onAddItems;
  final VoidCallback? onReviewBilling;
  final VoidCallback? onRemoveSelected;
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
        if (onRemoveSelected != null)
          AppButton.tertiary(
            label: l10n.clinicalRequestRemoveSelectedAction,
            leadingIcon: Icons.delete_outline,
            enabled: enabled,
            onPressed: onRemoveSelected,
          ),
      ],
    );
  }
}

const String _selectedCatalogSelectColumnKey = 'select';
const String _selectedCatalogNameColumnKey = 'name';
const String _selectedCatalogTypeColumnKey = 'type';
const String _selectedCatalogPriceColumnKey = 'price';
const String _selectedCatalogActionsColumnKey = 'actions';

typedef ClinicalRequestSelectedCatalogItemKey<T> = String Function(T item);
typedef ClinicalRequestSelectedCatalogItemLabel<T> = String Function(T item);
typedef ClinicalRequestSelectedCatalogItemOption<T> =
    ClinicalActionCatalogOption Function(T item);

/// Read-only table for reviewing and removing selected catalog items.
class ClinicalRequestSelectedCatalogTable<T> extends StatelessWidget {
  const ClinicalRequestSelectedCatalogTable({
    required this.items,
    required this.itemKey,
    required this.nameLabel,
    required this.typeLabel,
    required this.optionFor,
    required this.selectedKeys,
    required this.onSelectedKeysChanged,
    required this.onDeleteItem,
    required this.emptyLabel,
    this.enabled = true,
    this.billing,
    super.key,
  });

  final List<T> items;
  final ClinicalRequestSelectedCatalogItemKey<T> itemKey;
  final ClinicalRequestSelectedCatalogItemLabel<T> nameLabel;
  final ClinicalRequestSelectedCatalogItemLabel<T> typeLabel;
  final ClinicalRequestSelectedCatalogItemOption<T> optionFor;
  final Set<String> selectedKeys;
  final ValueChanged<Set<String>> onSelectedKeysChanged;
  final ValueChanged<T> onDeleteItem;
  final String emptyLabel;
  final bool enabled;
  final ClinicalRequestBillingSubmit? billing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalRequestBillingLineItem> lineItems =
        clinicalRequestBillingLineItems(
          options: items.map(optionFor).toList(growable: false),
        );
    final num total = clinicalRequestBillingTotal(lineItems);
    final String currency =
        billing?.currency ?? resolveClinicalRequestBillingCurrency(lineItems);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(theme.spacing.xs),
      ),
      child: AppListTable<T>(
        items: items,
        displayMode: AppListTableDisplayMode.table,
        tableHorizontalMargin: theme.spacing.sm,
        itemKeyBuilder: (T item) => ValueKey<String>(itemKey(item)),
        columns: _columns(context),
        emptyBuilder: (BuildContext context) {
          return Padding(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: Center(
              child: Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
        footer: items.isEmpty
            ? null
            : Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.md,
                  theme.spacing.sm,
                  theme.spacing.md,
                  theme.spacing.md,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: theme.spacing.sm),
                    child: Row(
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
                ),
              ),
        mobileItemBuilder: (BuildContext context, T item) {
          final String key = itemKey(item);
          return AppListItemRow(
            title: nameLabel(item),
            subtitle: typeLabel(item),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  clinicalRequestCatalogPriceLabel(context, optionFor(item)),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Checkbox(
                  value: selectedKeys.contains(key),
                  onChanged: enabled
                      ? (bool? value) => _toggleKey(key, value ?? false)
                      : null,
                  visualDensity: VisualDensity.compact,
                ),
                AppButton(
                  iconOnly: true,
                  leadingIcon: Icons.delete_outline,
                  label: l10n.clinicalLabRequestDeleteSelectionAction,
                  semanticLabel: l10n.clinicalLabRequestDeleteSelectionAction,
                  tooltip: l10n.clinicalLabRequestDeleteSelectionAction,
                  enabled: enabled,
                  onPressed: enabled ? () => onDeleteItem(item) : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<AppListTableColumn<T>> _columns(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return <AppListTableColumn<T>>[
      _selectionColumn(context),
      AppListTableColumn<T>(
        id: _selectedCatalogNameColumnKey,
        label: l10n.clinicalRequestSelectedNameColumnLabel,
        sortComparator: (T left, T right) =>
            appListTableCompareText(nameLabel(left), nameLabel(right)),
        cellBuilder: (BuildContext context, T item) {
          return Text(nameLabel(item));
        },
      ),
      AppListTableColumn<T>(
        id: _selectedCatalogTypeColumnKey,
        label: l10n.clinicalRequestSelectedTypeColumnLabel,
        sortComparator: (T left, T right) =>
            appListTableCompareText(typeLabel(left), typeLabel(right)),
        cellBuilder: (BuildContext context, T item) {
          return Text(typeLabel(item));
        },
      ),
      AppListTableColumn<T>(
        id: _selectedCatalogPriceColumnKey,
        label: l10n.clinicalRequestSelectedPriceColumnLabel,
        numeric: true,
        sortComparator: (T left, T right) {
          final num? leftPrice = clinicalCatalogOptionUnitPrice(optionFor(left));
          final num? rightPrice =
              clinicalCatalogOptionUnitPrice(optionFor(right));
          return (leftPrice ?? 0).compareTo(rightPrice ?? 0);
        },
        cellBuilder: (BuildContext context, T item) {
          return Text(clinicalRequestCatalogPriceLabel(context, optionFor(item)));
        },
      ),
      AppListTableColumn<T>(
        id: _selectedCatalogActionsColumnKey,
        label: l10n.clinicalRequestSelectedActionsColumnLabel,
        alwaysVisible: true,
        cellBuilder: (BuildContext context, T item) {
          return Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              iconOnly: true,
              leadingIcon: Icons.delete_outline,
              label: l10n.clinicalLabRequestDeleteSelectionAction,
              semanticLabel: l10n.clinicalLabRequestDeleteSelectionAction,
              tooltip: l10n.clinicalLabRequestDeleteSelectionAction,
              enabled: enabled,
              onPressed: enabled ? () => onDeleteItem(item) : null,
            ),
          );
        },
      ),
    ];
  }

  AppListTableColumn<T> _selectionColumn(BuildContext context) {
    return AppListTableColumn<T>(
      id: _selectedCatalogSelectColumnKey,
      label: '',
      alwaysVisible: true,
      headerBuilder: (BuildContext context) {
        final bool allSelected = items.isNotEmpty &&
            items.every((T item) => selectedKeys.contains(itemKey(item)));
        final bool someSelected = items.any(
          (T item) => selectedKeys.contains(itemKey(item)),
        );
        return Checkbox(
          tristate: true,
          value: allSelected
              ? true
              : someSelected
              ? null
              : false,
          onChanged: !enabled || items.isEmpty
              ? null
              : (bool? checked) => _toggleAll(checked ?? false),
          visualDensity: VisualDensity.compact,
        );
      },
      cellBuilder: (BuildContext context, T item) {
        final String key = itemKey(item);
        return Checkbox(
          value: selectedKeys.contains(key),
          onChanged: enabled
              ? (bool? value) => _toggleKey(key, value ?? false)
              : null,
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }

  void _toggleKey(String key, bool selected) {
    final Set<String> next = Set<String>.from(selectedKeys);
    if (selected) {
      next.add(key);
    } else {
      next.remove(key);
    }
    onSelectedKeysChanged(next);
  }

  void _toggleAll(bool selected) {
    if (!selected) {
      onSelectedKeysChanged(<String>{});
      return;
    }
    onSelectedKeysChanged(items.map(itemKey).toSet());
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
              AppButton(
                iconOnly: true,
                leadingIcon: Icons.edit_outlined,
                label: l10n.clinicalLabRequestEditSelectionAction,
                semanticLabel: l10n.clinicalLabRequestEditSelectionAction,
                tooltip: l10n.clinicalLabRequestEditSelectionAction,
                enabled: enabled,
                onPressed: enabled ? onEdit : null,
              ),
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.delete_outline,
              label: l10n.clinicalLabRequestDeleteSelectionAction,
              semanticLabel: l10n.clinicalLabRequestDeleteSelectionAction,
              tooltip: l10n.clinicalLabRequestDeleteSelectionAction,
              enabled: enabled,
              onPressed: enabled ? onDelete : null,
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
