import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

Future<void> openPharmacyDrugDetailsDialog(
  BuildContext context,
  WidgetRef ref, {
  required PharmacyDrug drug,
  required AccessRequirement writeRequirement,
  required Future<bool> Function(PharmacyDrug drug) onDelete,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _PharmacyDrugDetailsDialog(
      drug: drug,
      writeRequirement: writeRequirement,
      onDelete: onDelete,
    ),
  );
}

class _PharmacyDrugDetailsDialog extends ConsumerStatefulWidget {
  const _PharmacyDrugDetailsDialog({
    required this.drug,
    required this.writeRequirement,
    required this.onDelete,
  });

  final PharmacyDrug drug;
  final AccessRequirement writeRequirement;
  final Future<bool> Function(PharmacyDrug drug) onDelete;

  @override
  ConsumerState<_PharmacyDrugDetailsDialog> createState() =>
      _PharmacyDrugDetailsDialogState();
}

class _PharmacyDrugDetailsDialogState
    extends ConsumerState<_PharmacyDrugDetailsDialog> {
  late PharmacyDrug _fallbackDrug;

  @override
  void initState() {
    super.initState();
    _fallbackDrug = widget.drug;
  }

  PharmacyDrug _resolveDrug(
    PharmacyDrug fallback,
    PharmacyWorkspaceState? state,
  ) {
    if (state == null) {
      return fallback;
    }
    for (final PharmacyDrug item in state.drugs.items) {
      if (item.id == fallback.id) {
        return item;
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    PharmacyWorkspaceState? state;
    final asyncState = ref.watch(pharmacyWorkspaceControllerProvider);
    if (asyncState.hasValue) {
      asyncState.requireValue.when(
        success: (PharmacyWorkspaceState value) => state = value,
        failure: (_) {},
      );
    }
    final PharmacyDrug current = _resolveDrug(_fallbackDrug, state);
    final String empty = l10n.clinicalOrderEmptyValueLabel;
    final AccessRequirement writeRequirement = widget.writeRequirement;
    final Future<bool> Function(PharmacyDrug drug) onDelete = widget.onDelete;

    String displayOrEmpty(String? value) {
      final String trimmed = (value ?? '').trim();
      return trimmed.isEmpty ? empty : trimmed;
    }

    final String brand = displayOrEmpty(current.brandName);
    final String generic = () {
      final String value = (current.genericName ?? '').trim();
      if (value.isNotEmpty) {
        return value;
      }
      return displayOrEmpty(current.name);
    }();
    final String code = displayOrEmpty(current.code);
    final String? displayId = (current.displayId ?? '').trim().isEmpty
        ? null
        : current.displayId!.trim();
    final num reorderLevel = current.stockRows.isNotEmpty
        ? current.stockRows.first.reorderLevel
        : 0;
    final AppWorkspaceStatus stockStatus = _drugDetailsStockStatus(
      context,
      current.stockStatus,
    );

    final List<_DrugDetailMetaItem> metaItems = <_DrugDetailMetaItem>[
      _DrugDetailMetaItem(
        icon: Icons.sell_outlined,
        label: l10n.pharmacyDrugBrandNameLabel,
        value: brand,
      ),
      _DrugDetailMetaItem(
        icon: Icons.medication_outlined,
        label: l10n.pharmacyDrugGenericNameLabel,
        value: generic,
      ),
      _DrugDetailMetaItem(
        icon: Icons.qr_code_2_outlined,
        label: l10n.pharmacyDrugCodeLabel,
        value: code,
        copyable: (current.code ?? '').trim().isNotEmpty,
      ),
      _DrugDetailMetaItem(
        icon: Icons.science_outlined,
        label: l10n.pharmacyDrugFormLabel,
        value: displayOrEmpty(current.form),
      ),
      _DrugDetailMetaItem(
        icon: Icons.straighten_outlined,
        label: l10n.pharmacyDrugStrengthLabel,
        value: displayOrEmpty(current.strength),
      ),
      _DrugDetailMetaItem(
        icon: Icons.shopping_cart_outlined,
        label: l10n.pharmacyBuyPriceLabel,
        value: _drugDetailsPriceText(current.buyUnitPrice),
      ),
      if ((current.supplierName ?? '').trim().isNotEmpty)
        _DrugDetailMetaItem(
          icon: Icons.local_shipping_outlined,
          label: l10n.pharmacyDrugSupplierLabel,
          value: current.supplierName!.trim(),
        ),
      _DrugDetailMetaItem(
        icon: Icons.payments_outlined,
        label: l10n.pharmacyPharmacyPriceLabel,
        value: _drugDetailsPriceText(
          current.pharmacyUnitPrice ?? current.unitPrice,
        ),
      ),
      _DrugDetailMetaItem(
        icon: Icons.swap_horiz_outlined,
        label: l10n.pharmacyTransferPriceLabel,
        value: _drugDetailsPriceText(current.transferUnitPrice),
      ),
      _DrugDetailMetaItem(
        icon: Icons.account_balance_outlined,
        label: l10n.pharmacyFacilityPriceLabel,
        value: _drugDetailsPriceText(current.facilityUnitPrice),
      ),
      _DrugDetailMetaItem(
        icon: Icons.warehouse_outlined,
        label: l10n.pharmacyStorageLocationColumnLabel,
        value: displayOrEmpty(current.storageLocationLabel),
      ),
      _DrugDetailMetaItem(
        icon: Icons.low_priority_outlined,
        label: l10n.pharmacyReorderLevelColumnLabel,
        value: reorderLevel.toString(),
      ),
      _DrugDetailMetaItem(
        icon: Icons.flag_outlined,
        label: l10n.pharmacyStockStatusColumnLabel,
        value: stockStatus.label,
      ),
      if (displayId != null)
        _DrugDetailMetaItem(
          icon: Icons.badge_outlined,
          label: l10n.accessAdminColumnDetails,
          value: displayId,
          copyable: true,
        ),
      if (current.createdAt != null)
        _DrugDetailMetaItem(
          icon: Icons.event_outlined,
          label: l10n.pharmacyStorageCreatedAtColumnLabel,
          value: AppFormatters.dateTime(
            current.createdAt!,
            Localizations.localeOf(context),
          ),
        ),
    ];

    return AppDialog(
      title: Text(l10n.pharmacyDrugDetailsTitle),
      icon: const Icon(Icons.medication_outlined),
      scrollable: true,
      maxWidth: 720,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppCollapsibleSection(
            title: l10n.pharmacyDrugDetailsSectionTitle,
            titleIcon: Icons.info_outline,
            contentPadding: EdgeInsets.all(theme.spacing.md),
            child: _DrugDetailMetaWrap(items: metaItems),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppAccessActionGate(
          requirement: writeRequirement,
          builder: (BuildContext _, bool allowed) {
            if (!allowed) {
              return const SizedBox.shrink();
            }
            return AppButton.tertiary(
              label: l10n.commonDeleteActionLabel,
              leadingIcon: Icons.delete_outline,
              semanticLabel: l10n.pharmacyDeleteDrugAction,
              color: theme.colorScheme.error,
              onPressed: () async {
                final bool deleted = await onDelete(current);
                // Pop the details dialog route (root navigator), not a shell route.
                if (deleted && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        ),
        AppAccessActionGate(
          requirement: writeRequirement,
          builder: (BuildContext _, bool allowed) {
            if (!allowed) {
              return const SizedBox.shrink();
            }
            return AppButton.primary(
              label: l10n.commonEditActionLabel,
              leadingIcon: Icons.edit_outlined,
              semanticLabel: l10n.pharmacyEditDrugAction,
              onPressed: () async {
                final PharmacyDrugFormResult? result =
                    await showAppDialog<PharmacyDrugFormResult>(
                      context: context,
                      builder: (_) => PharmacyDrugEditDialog(drug: current),
                    );
                if (!mounted) {
                  return;
                }
                final PharmacyDrug? saved = result?.drug;
                if (result != null &&
                    (result.saved || result.useExisting) &&
                    saved != null) {
                  setState(() => _fallbackDrug = saved);
                }
              },
            );
          },
        ),
      ],
    );
  }
}

final class _DrugDetailMetaItem {
  const _DrugDetailMetaItem({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyable;
}

class _DrugDetailMetaWrap extends StatelessWidget {
  const _DrugDetailMetaWrap({required this.items});

  final List<_DrugDetailMetaItem> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: theme.spacing.lg,
      runSpacing: theme.spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final _DrugDetailMetaItem item in items)
          _DrugDetailMetaRow(item: item),
      ],
    );
  }
}

class _DrugDetailMetaRow extends StatelessWidget {
  const _DrugDetailMetaRow({required this.item});

  final _DrugDetailMetaItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle? labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: AppFontWeight.emphasis,
    );
    final TextStyle? valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: AppFontWeight.emphasis,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          item.icon,
          size: theme.appTokens.listIconSize,
          color: colorScheme.primary,
        ),
        SizedBox(width: theme.spacing.xs),
        Text('${item.label}: ', style: labelStyle),
        if (item.copyable)
          AppCopyableIdentifier(value: item.value, textStyle: valueStyle)
        else
          Text(
            item.value,
            style: valueStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
          ),
      ],
    );
  }
}

String _drugDetailsPriceText(num? value) {
  if (value == null) {
    return '—';
  }
  return value.toString();
}

AppWorkspaceStatus _drugDetailsStockStatus(BuildContext context, String? value) {
  final AppLocalizations l10n = context.l10n;
  final String normalized = (value ?? '').toUpperCase();
  final String label = switch (normalized) {
    'IN_STOCK' => l10n.pharmacyStockInStock,
    'ALMOST_OUT_OF_STOCK' => l10n.pharmacyStockAlmostOut,
    'LOW_STOCK' => l10n.pharmacyStockLow,
    'OUT_OF_STOCK' => l10n.pharmacyStockOut,
    _ => l10n.pharmacyStockUnknown,
  };
  return AppWorkspaceStatus(
    label: label,
    tone: switch (normalized) {
      'IN_STOCK' => AppWorkspaceStatusTone.success,
      'ALMOST_OUT_OF_STOCK' => AppWorkspaceStatusTone.warning,
      'LOW_STOCK' || 'OUT_OF_STOCK' => AppWorkspaceStatusTone.error,
      _ => AppWorkspaceStatusTone.neutral,
    },
  );
}
