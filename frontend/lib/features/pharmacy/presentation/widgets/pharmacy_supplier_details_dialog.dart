import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> openPharmacySupplierDetailsDialog(
  BuildContext context,
  WidgetRef ref, {
  required PharmacySupplier supplier,
  required AccessRequirement writeRequirement,
  required Future<bool> Function(PharmacySupplier supplier) onEdit,
  required Future<bool> Function(PharmacySupplier supplier) onDelete,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _PharmacySupplierDetailsDialog(
      supplier: supplier,
      writeRequirement: writeRequirement,
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class _PharmacySupplierDetailsDialog extends ConsumerStatefulWidget {
  const _PharmacySupplierDetailsDialog({
    required this.supplier,
    required this.writeRequirement,
    required this.onEdit,
    required this.onDelete,
  });

  final PharmacySupplier supplier;
  final AccessRequirement writeRequirement;
  final Future<bool> Function(PharmacySupplier supplier) onEdit;
  final Future<bool> Function(PharmacySupplier supplier) onDelete;

  @override
  ConsumerState<_PharmacySupplierDetailsDialog> createState() =>
      _PharmacySupplierDetailsDialogState();
}

class _PharmacySupplierDetailsDialogState
    extends ConsumerState<_PharmacySupplierDetailsDialog> {
  late PharmacySupplier _fallbackSupplier;

  @override
  void initState() {
    super.initState();
    _fallbackSupplier = widget.supplier;
  }

  PharmacySupplier _resolveSupplier(
    PharmacySupplier fallback,
    PharmacyWorkspaceState? state,
  ) {
    if (state == null) {
      return fallback;
    }
    for (final PharmacySupplier item in state.suppliers.items) {
      if (item.id == fallback.id) {
        return item;
      }
    }
    return fallback;
  }

  PharmacyWorkspaceState? _workspaceState() {
    PharmacyWorkspaceState? state;
    final asyncState = ref.watch(pharmacyWorkspaceControllerProvider);
    if (asyncState.hasValue) {
      asyncState.requireValue.when(
        success: (PharmacyWorkspaceState value) => state = value,
        failure: (_) {},
      );
    }
    return state;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PharmacySupplier current = _resolveSupplier(
      _fallbackSupplier,
      _workspaceState(),
    );
    final String empty = l10n.clinicalOrderEmptyValueLabel;
    final AccessRequirement writeRequirement = widget.writeRequirement;

    String displayOrEmpty(String? value) {
      final String trimmed = (value ?? '').trim();
      return trimmed.isEmpty ? empty : trimmed;
    }

    final String name = current.primaryName.isEmpty
        ? empty
        : current.primaryName;
    final String? displayId = (current.displayId ?? '').trim().isEmpty
        ? null
        : current.displayId!.trim();

    final List<AppPropertyValueData> metaItems = <AppPropertyValueData>[
      AppPropertyValueData(
        icon: Icons.storefront_outlined,
        label: l10n.pharmacySupplierNameLabel,
        value: name,
      ),
      AppPropertyValueData(
        icon: Icons.place_outlined,
        label: l10n.pharmacySupplierLocationLabel,
        value: displayOrEmpty(current.location),
      ),
      AppPropertyValueData(
        icon: Icons.email_outlined,
        label: l10n.pharmacySupplierEmailLabel,
        value: displayOrEmpty(current.contactEmail),
        copyable: (current.contactEmail ?? '').trim().isNotEmpty,
      ),
      AppPropertyValueData(
        icon: Icons.phone_outlined,
        label: l10n.pharmacySupplierPhoneLabel,
        value: displayOrEmpty(current.phone),
        copyable: (current.phone ?? '').trim().isNotEmpty,
      ),
      if (displayId != null)
        AppPropertyValueData(
          icon: Icons.badge_outlined,
          label: l10n.accessAdminColumnDetails,
          value: displayId,
          copyable: true,
        ),
      if (current.createdAt != null)
        AppPropertyValueData(
          icon: Icons.event_outlined,
          label: l10n.pharmacyStorageCreatedAtColumnLabel,
          value: AppFormatters.dateTime(
            current.createdAt!,
            Localizations.localeOf(context),
          ),
        ),
    ];

    return AppDialog(
      title: Text(l10n.pharmacySupplierDetailsTitle),
      icon: const Icon(Icons.local_shipping_outlined),
      scrollable: true,
      maxWidth: 720,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppCollapsibleSection(
            title: l10n.pharmacySupplierDetailsSectionTitle,
            titleIcon: Icons.info_outline,
            contentPadding: EdgeInsets.all(theme.spacing.md),
            child: AppPropertyValueList(items: metaItems, maxLines: 2),
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
              semanticLabel: l10n.pharmacyDeleteSupplierAction,
              color: theme.colorScheme.error,
              onPressed: () async {
                final bool deleted = await widget.onDelete(current);
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
              semanticLabel: l10n.pharmacyEditSupplierAction,
              onPressed: () async {
                final bool saved = await widget.onEdit(current);
                if (!mounted || !saved) {
                  return;
                }
                setState(() {
                  _fallbackSupplier = _resolveSupplier(
                    current,
                    _workspaceState(),
                  );
                });
              },
            );
          },
        ),
      ],
    );
  }
}

