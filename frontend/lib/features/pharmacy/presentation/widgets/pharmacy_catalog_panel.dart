import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class PharmacyCatalogPanel extends ConsumerStatefulWidget {
  const PharmacyCatalogPanel({required this.state, super.key});

  final PharmacyWorkspaceState state;

  @override
  ConsumerState<PharmacyCatalogPanel> createState() =>
      _PharmacyCatalogPanelState();
}

class _PharmacyCatalogPanelState extends ConsumerState<PharmacyCatalogPanel> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.pharmacyWrite,
      AppPermissions.operationsWrite,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceState state = widget.state;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final PharmacyCatalogTab tab = state.catalogTab;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<PharmacyCatalogTab>(
          segments: <ButtonSegment<PharmacyCatalogTab>>[
            ButtonSegment<PharmacyCatalogTab>(
              value: PharmacyCatalogTab.drugs,
              label: Text(l10n.pharmacyCatalogTabDrugs),
            ),
            ButtonSegment<PharmacyCatalogTab>(
              value: PharmacyCatalogTab.formulary,
              label: Text(l10n.pharmacyCatalogTabFormulary),
            ),
            ButtonSegment<PharmacyCatalogTab>(
              value: PharmacyCatalogTab.inventory,
              label: Text(l10n.pharmacyCatalogTabInventory),
            ),
            ButtonSegment<PharmacyCatalogTab>(
              value: PharmacyCatalogTab.storage,
              label: Text(l10n.pharmacyCatalogTabStorage),
            ),
          ],
          selected: <PharmacyCatalogTab>{tab},
          onSelectionChanged: (Set<PharmacyCatalogTab> selection) {
            if (selection.isNotEmpty) {
              controller.setCatalogTab(selection.first);
            }
          },
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        switch (tab) {
          PharmacyCatalogTab.drugs => _DrugCatalogTab(
            state: state,
            writeRequirement: _writeRequirement,
          ),
          PharmacyCatalogTab.formulary => _FormularyCatalogTab(
            state: state,
            writeRequirement: _writeRequirement,
          ),
          PharmacyCatalogTab.inventory => _InventoryCatalogTab(
            state: state,
            writeRequirement: _writeRequirement,
          ),
          PharmacyCatalogTab.storage => PharmacyStoragePanel(
            state: state,
            writeRequirement: _writeRequirement,
          ),
        },
      ],
    );
  }
}

class _DrugCatalogTab extends ConsumerStatefulWidget {
  const _DrugCatalogTab({required this.state, required this.writeRequirement});

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  ConsumerState<_DrugCatalogTab> createState() => _DrugCatalogTabState();
}

class _DrugCatalogTabState extends ConsumerState<_DrugCatalogTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.state.drugQuery.search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyDrugPanelTitle,
      description: l10n.pharmacyDrugPanelDescription,
      actions: <Widget>[
        AppAccessActionGate(
          requirement: widget.writeRequirement,
          builder: (BuildContext context, bool isAllowed) =>
              AppButton.secondary(
                label: l10n.pharmacyAddDrugAction,
                leadingIcon: Icons.add,
                enabled: isAllowed,
                onPressed: () => _openDrugDialog(context),
              ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_activeStorageRooms(widget.state.storageLayout).isNotEmpty) ...<Widget>[
            _StorageLocationFilters(
              layout: widget.state.storageLayout,
              storageRoomId: widget.state.drugQuery.storageRoomId,
              storageShelfId: widget.state.drugQuery.storageShelfId,
              onRoomChanged: (String? roomId) => unawaited(
                controller.applyDrugStorageFilter(
                  storageRoomId: roomId,
                  clearStorageRoomId: roomId == null,
                  clearStorageShelfId: true,
                ),
              ),
              onShelfChanged: (String? shelfId) => unawaited(
                controller.applyDrugStorageFilter(
                  storageRoomId: widget.state.drugQuery.storageRoomId,
                  storageShelfId: shelfId,
                  clearStorageShelfId: shelfId == null,
                ),
              ),
            ),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          AppListTable<PharmacyDrug>(
        page: widget.state.drugs,
        isLoading: widget.state.isRefreshingDrugs,
        search: AppListTableSearch<PharmacyDrug>(
          controller: _searchController,
          semanticLabel: l10n.pharmacyDrugSearchLabel,
          hintText: l10n.pharmacyDrugSearchHint,
          matcher: (_, _) => true,
          onSubmitted: controller.applyDrugSearch,
          onClear: () => unawaited(controller.applyDrugSearch('')),
        ),
        onPageChanged: controller.changeDrugPage,
        emptyBuilder: (_) => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: l10n.pharmacyNoDrugsTitle,
          body: l10n.pharmacyNoDrugsBody,
          icon: Icons.medication_outlined,
        ),
        columns: <AppListTableColumn<PharmacyDrug>>[
          AppListTableColumn<PharmacyDrug>(
            label: l10n.pharmacyDrugNameLabel,
            cellBuilder: (_, PharmacyDrug item) => Text(item.displayTitle),
          ),
          AppListTableColumn<PharmacyDrug>(
            label: l10n.pharmacyDrugCodeLabel,
            cellBuilder: (_, PharmacyDrug item) => Text(item.code ?? ''),
          ),
          AppListTableColumn<PharmacyDrug>(
            label: l10n.pharmacyPharmacyPriceLabel,
            cellBuilder: (_, PharmacyDrug item) =>
                Text(_priceText(item.pharmacyUnitPrice ?? item.unitPrice)),
          ),
          AppListTableColumn<PharmacyDrug>(
            label: l10n.pharmacyFacilityPriceLabel,
            cellBuilder: (_, PharmacyDrug item) =>
                Text(_priceText(item.facilityUnitPrice)),
          ),
          AppListTableColumn<PharmacyDrug>(
            label: l10n.pharmacyStorageLocationColumnLabel,
            cellBuilder: (_, PharmacyDrug item) =>
                Text(item.storageLocationLabel ?? '—'),
          ),
          AppListTableColumn<PharmacyDrug>(
            label: l10n.pharmacyReorderLevelColumnLabel,
            numeric: true,
            cellBuilder: (_, PharmacyDrug item) {
              final num reorderLevel = item.stockRows.isNotEmpty
                  ? item.stockRows.first.reorderLevel
                  : 0;
              return Text(reorderLevel.toString());
            },
          ),
          AppListTableColumn<PharmacyDrug>(
            label: l10n.pharmacyStockStatusFilterLabel,
            cellBuilder: (BuildContext context, PharmacyDrug item) {
              return AppWorkspaceStatusBadge(
                status: _stockStatus(context, item.stockStatus),
              );
            },
          ),
          AppListTableColumn<PharmacyDrug>(
            label: '',
            cellBuilder: (BuildContext context, PharmacyDrug item) {
              return AppAccessActionGate(
                requirement: widget.writeRequirement,
                builder: (BuildContext context, bool isAllowed) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppButton(
                      iconOnly: true,
                      leadingIcon: Icons.edit_outlined,
                      label: l10n.pharmacyEditDrugAction,

                      semanticLabel: l10n.pharmacyEditDrugAction,
                      enabled: isAllowed,
                      onPressed: () => _openDrugDialog(context, drug: item),
                    ),
                    AppButton(
                      iconOnly: true,
                      leadingIcon: Icons.delete_outline,
                      label: l10n.pharmacyDeleteDrugAction,

                      semanticLabel: l10n.pharmacyDeleteDrugAction,
                      enabled: isAllowed,
                      onPressed: () => _confirmDeleteDrug(context, item),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, PharmacyDrug item) {
          return ListTile(
            title: Text(item.displayTitle),
            subtitle: Text(item.code ?? ''),
          );
        },
          ),
        ],
      ),
    );
  }

  Future<void> _openDrugDialog(BuildContext context, {PharmacyDrug? drug}) {
    return showAppDialog<bool>(
      context: context,
      builder: (_) => PharmacyDrugEditDialog(drug: drug),
    );
  }

  Future<void> _confirmDeleteDrug(
    BuildContext context,
    PharmacyDrug drug,
  ) async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: Text(context.l10n.pharmacyDeleteDrugDialogTitle),
        content: Text(context.l10n.pharmacyDeleteDrugDialogBody),
        actions: <Widget>[
          AppButton.tertiary(
            label: context.l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton.primary(
            label: context.l10n.pharmacyDeleteDrugAction,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final AppFailure? failure = await ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .deleteDrug(drug.id);
    if (context.mounted && failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to delete drug')));
    }
  }
}

class _FormularyCatalogTab extends ConsumerStatefulWidget {
  const _FormularyCatalogTab({
    required this.state,
    required this.writeRequirement,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  ConsumerState<_FormularyCatalogTab> createState() =>
      _FormularyCatalogTabState();
}

class _FormularyCatalogTabState extends ConsumerState<_FormularyCatalogTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.state.formularyItems.items.isEmpty) {
        unawaited(
          ref
              .read(pharmacyWorkspaceControllerProvider.notifier)
              .applyFormularySearch(''),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyCatalogTabFormulary,
      description: l10n.pharmacyDrugPanelDescription,
      actions: <Widget>[
        AppAccessActionGate(
          requirement: widget.writeRequirement,
          builder: (BuildContext context, bool isAllowed) =>
              AppButton.secondary(
                label: l10n.pharmacyAddFormularyAction,
                leadingIcon: Icons.add,
                enabled: isAllowed,
                onPressed: () => _openFormularyDialog(context),
              ),
        ),
      ],
      child: AppListTable<PharmacyFormularyItem>(
        page: widget.state.formularyItems,
        isLoading: widget.state.isRefreshingFormulary,
        onPageChanged: controller.changeFormularyPage,
        emptyBuilder: (_) => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.empty,
          title: l10n.pharmacyNoFormularyTitle,
          body: l10n.pharmacyNoFormularyBody,
          icon: Icons.list_alt_outlined,
        ),
        columns: <AppListTableColumn<PharmacyFormularyItem>>[
          AppListTableColumn<PharmacyFormularyItem>(
            label: l10n.pharmacyFormularyDrugLabel,
            cellBuilder: (_, PharmacyFormularyItem item) =>
                Text(item.displayTitle),
          ),
          AppListTableColumn<PharmacyFormularyItem>(
            label: l10n.pharmacyFormularyActiveLabel,
            cellBuilder: (BuildContext context, PharmacyFormularyItem item) {
              return AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label: item.isActive
                      ? l10n.commonYesLabel
                      : l10n.commonNoLabel,
                  tone: item.isActive
                      ? AppWorkspaceStatusTone.success
                      : AppWorkspaceStatusTone.neutral,
                ),
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, PharmacyFormularyItem item) {
          return ListTile(title: Text(item.displayTitle));
        },
      ),
    );
  }

  Future<void> _openFormularyDialog(BuildContext context) {
    return showAppDialog<bool>(
      context: context,
      builder: (_) => _FormularyCreateDialog(drugs: widget.state.drugs.items),
    );
  }
}

class _FormularyCreateDialog extends ConsumerStatefulWidget {
  const _FormularyCreateDialog({required this.drugs});

  final List<PharmacyDrug> drugs;

  @override
  ConsumerState<_FormularyCreateDialog> createState() =>
      _FormularyCreateDialogState();
}

class _FormularyCreateDialogState
    extends ConsumerState<_FormularyCreateDialog> {
  String? _drugId;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.pharmacyAddFormularyAction),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSelectField<String>(
            value: _drugId,
            labelText: l10n.pharmacyFormularyDrugLabel,
            options: widget.drugs
                .map(
                  (PharmacyDrug drug) => AppSelectOption<String>(
                    value: drug.id,
                    label: drug.displayTitle,
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) => setState(() => _drugId = value),
          ),
          AppSwitchField(
            title: l10n.pharmacyFormularyActiveLabel,
            value: _isActive,
            onChanged: (bool value) => setState(() => _isActive = value),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.pharmacyAddFormularyAction,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final String? drugId = _drugId;
    final String? tenantId = ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .resolveTenantId();
    if (drugId == null || tenantId == null) {
      return;
    }
    setState(() => _isSaving = true);
    final AppFailure? failure = await ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .createFormularyItem(
          PharmacyFormularyItemInput(
            tenantId: tenantId,
            drugId: drugId,
            isActive: _isActive,
          ),
        );
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _isSaving = false);
  }
}

class _InventoryCatalogTab extends ConsumerStatefulWidget {
  const _InventoryCatalogTab({
    required this.state,
    required this.writeRequirement,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;

  @override
  ConsumerState<_InventoryCatalogTab> createState() =>
      _InventoryCatalogTabState();
}

class _InventoryCatalogTabState extends ConsumerState<_InventoryCatalogTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.state.inventoryQuery.search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.state.inventoryWorkbench.stocks.items.isEmpty) {
        unawaited(
          ref
              .read(pharmacyWorkspaceControllerProvider.notifier)
              .applyInventorySearch(''),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.pharmacyInventoryPanelTitle,
      description: l10n.pharmacyInventoryPanelDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_activeStorageRooms(widget.state.storageLayout).isNotEmpty) ...<Widget>[
            _StorageLocationFilters(
              layout: widget.state.storageLayout,
              storageRoomId: widget.state.inventoryQuery.storageRoomId,
              storageShelfId: widget.state.inventoryQuery.storageShelfId,
              onRoomChanged: (String? roomId) => unawaited(
                controller.applyInventoryStorageFilter(
                  storageRoomId: roomId,
                  clearStorageRoomId: roomId == null,
                  clearStorageShelfId: true,
                ),
              ),
              onShelfChanged: (String? shelfId) => unawaited(
                controller.applyInventoryStorageFilter(
                  storageRoomId: widget.state.inventoryQuery.storageRoomId,
                  storageShelfId: shelfId,
                  clearStorageShelfId: shelfId == null,
                ),
              ),
            ),
            SizedBox(height: Theme.of(context).spacing.sm),
          ],
          Wrap(
            spacing: Theme.of(context).spacing.sm,
            runSpacing: Theme.of(context).spacing.sm,
            children: <Widget>[
              FilterChip(
                label: Text(l10n.pharmacyLowStockOnlyFilterLabel),
                selected: widget.state.inventoryQuery.lowStockOnly,
                onSelected: (bool value) => unawaited(
                  controller.applyInventoryLowStockOnly(value),
                ),
              ),
              FilterChip(
                label: Text(l10n.pharmacyExpiringSoonFilterLabel),
                selected: widget.state.inventoryQuery.expiringWithinDays != null,
                onSelected: (bool value) => unawaited(
                  value
                      ? controller.applyInventoryFilter(
                          PharmacyInventoryFilter.expiringSoon,
                        )
                      : controller.clearInventoryFilters(),
                ),
              ),
              FilterChip(
                label: Text(l10n.pharmacyExpiredOnlyFilterLabel),
                selected: widget.state.inventoryQuery.expiredOnly,
                onSelected: (bool value) => unawaited(
                  value
                      ? controller.applyInventoryFilter(
                          PharmacyInventoryFilter.expired,
                        )
                      : controller.clearInventoryFilters(),
                ),
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppListTable<PharmacyInventoryStock>(
            page: widget.state.inventoryWorkbench.stocks,
            isLoading: widget.state.isRefreshingInventory,
            search: AppListTableSearch<PharmacyInventoryStock>(
              controller: _searchController,
              semanticLabel: l10n.pharmacySearchLabel,
              hintText: l10n.pharmacySearchHint,
              matcher: (_, _) => true,
              onSubmitted: controller.applyInventorySearch,
              onClear: () => unawaited(controller.applyInventorySearch('')),
            ),
            onPageChanged: controller.changeInventoryPage,
            emptyBuilder: (_) => AppWorkspaceStatePanel.state(
              variant: AppStateViewVariant.empty,
              title: l10n.pharmacyNoInventoryTitle,
              body: l10n.pharmacyNoInventoryBody,
              icon: Icons.warehouse_outlined,
            ),
            columns: <AppListTableColumn<PharmacyInventoryStock>>[
              AppListTableColumn<PharmacyInventoryStock>(
                label: l10n.pharmacyInventoryItemLabel,
                cellBuilder: (_, PharmacyInventoryStock item) {
                  return Text(
                    item.inventoryItem?.displayTitle ?? item.displayId ?? '',
                  );
                },
              ),
              AppListTableColumn<PharmacyInventoryStock>(
                label: l10n.pharmacyInventoryFacilityColumnLabel,
                cellBuilder: (_, PharmacyInventoryStock item) =>
                    Text(item.facilityName ?? ''),
              ),
              AppListTableColumn<PharmacyInventoryStock>(
                label: l10n.pharmacyInventoryQuantityColumnLabel,
                numeric: true,
                cellBuilder: (_, PharmacyInventoryStock item) =>
                    Text(item.quantity.toString()),
              ),
              AppListTableColumn<PharmacyInventoryStock>(
                label: l10n.pharmacyReorderLevelColumnLabel,
                numeric: true,
                cellBuilder: (_, PharmacyInventoryStock item) =>
                    Text(item.reorderLevel.toString()),
              ),
              AppListTableColumn<PharmacyInventoryStock>(
                label: l10n.pharmacyStorageLocationColumnLabel,
                cellBuilder: (_, PharmacyInventoryStock item) =>
                    Text(item.storageLocationLabel ?? '—'),
              ),
              AppListTableColumn<PharmacyInventoryStock>(
                label: l10n.pharmacyNextExpiryColumnLabel,
                cellBuilder: (BuildContext context, PharmacyInventoryStock item) {
                  return _expiryCell(context, item);
                },
              ),
              AppListTableColumn<PharmacyInventoryStock>(
                label: l10n.pharmacyBatchCountColumnLabel,
                numeric: true,
                cellBuilder: (_, PharmacyInventoryStock item) =>
                    Text(item.batchCount.toString()),
              ),
              AppListTableColumn<PharmacyInventoryStock>(
                label: l10n.pharmacyStockStatusFilterLabel,
                cellBuilder: (BuildContext context, PharmacyInventoryStock item) {
                  return AppWorkspaceStatusBadge(
                    status: _stockStatus(context, item.stockStatus),
                  );
                },
              ),
              AppListTableColumn<PharmacyInventoryStock>(
                label: '',
                cellBuilder: (BuildContext context, PharmacyInventoryStock item) {
                  return AppAccessActionGate(
                    requirement: widget.writeRequirement,
                    builder: (BuildContext context, bool isAllowed) => AppButton(
                      iconOnly: true,
                      leadingIcon: Icons.tune_outlined,
                      label: l10n.pharmacyAdjustStockAction,
                      semanticLabel: l10n.pharmacyAdjustStockAction,
                      enabled: isAllowed,
                      onPressed: () => _openAdjustDialog(context, item),
                    ),
                  );
                },
              ),
            ],
            mobileItemBuilder: (BuildContext context, PharmacyInventoryStock item) {
              return ListTile(
                title: Text(item.inventoryItem?.displayTitle ?? ''),
                subtitle: Text(
                  '${item.quantity} · ${l10n.pharmacyReorderLevelColumnLabel}: ${item.reorderLevel}',
                ),
                trailing: _expiryCell(context, item),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAdjustDialog(
    BuildContext context,
    PharmacyInventoryStock stock,
  ) {
    return showAppDialog<bool>(
      context: context,
      builder: (_) => _InventoryAdjustDialog(stock: stock),
    );
  }
}

class _InventoryAdjustDialog extends ConsumerStatefulWidget {
  const _InventoryAdjustDialog({required this.stock});

  final PharmacyInventoryStock stock;

  @override
  ConsumerState<_InventoryAdjustDialog> createState() =>
      _InventoryAdjustDialogState();
}

class _InventoryAdjustDialogState
    extends ConsumerState<_InventoryAdjustDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _deltaController;
  late final TextEditingController _reorderController;
  late final TextEditingController _batchController;
  late final TextEditingController _notesController;
  String _reason = 'PURCHASE';
  DateTime? _expiryDate;
  String? _storageRoomId;
  String? _storageShelfId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _deltaController = TextEditingController();
    _reorderController = TextEditingController(
      text: widget.stock.reorderLevel > 0
          ? widget.stock.reorderLevel.toString()
          : '',
    );
    _batchController = TextEditingController();
    _notesController = TextEditingController();
    _storageRoomId = widget.stock.storageRoomId;
    _storageShelfId = widget.stock.storageShelfId;
  }

  @override
  void dispose() {
    _deltaController.dispose();
    _reorderController.dispose();
    _batchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyStorageLayout storageLayout = ref
            .watch(pharmacyWorkspaceControllerProvider)
            .value
            ?.when(
              success: (PharmacyWorkspaceState state) => state.storageLayout,
              failure: (_) => const PharmacyStorageLayout(),
            ) ??
        const PharmacyStorageLayout();
    final List<PharmacyStorageRoom> activeRooms = _activeStorageRooms(
      storageLayout,
    );
    final List<PharmacyStorageShelf> shelfOptions = activeRooms
        .where((PharmacyStorageRoom room) => room.id == _storageRoomId)
        .expand((PharmacyStorageRoom room) => room.shelves)
        .where((PharmacyStorageShelf shelf) => shelf.isActive)
        .toList(growable: false);
    return AppDialog(
      title: Text(l10n.pharmacyAdjustStockDialogTitle),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        children: <Widget>[
          AppTextField(
            controller: _deltaController,
            labelText: l10n.pharmacyQuantityDeltaLabel,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
            ],
          ),
          AppTextField(
            controller: _reorderController,
            labelText: l10n.pharmacyReorderLevelLabel,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          AppSelectField<String>(
            value: _reason,
            labelText: l10n.pharmacyStockReasonLabel,
            options: const <AppSelectOption<String>>[
              AppSelectOption<String>(value: 'PURCHASE', label: 'PURCHASE'),
              AppSelectOption<String>(value: 'DISPENSE', label: 'DISPENSE'),
              AppSelectOption<String>(value: 'RETURN', label: 'RETURN'),
              AppSelectOption<String>(value: 'DAMAGE', label: 'DAMAGE'),
              AppSelectOption<String>(value: 'EXPIRY', label: 'EXPIRY'),
              AppSelectOption<String>(value: 'OTHER', label: 'OTHER'),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _reason = value);
              }
            },
          ),
          if (_reason == 'PURCHASE') ...<Widget>[
            AppTextField(
              controller: _batchController,
              labelText: l10n.pharmacyBatchNumberLabel,
            ),
            AppDateField(
              labelText: l10n.pharmacyExpiryDateLabel,
              value: _expiryDate,
              pickerButtonLabel: l10n.housekeepingPickDateAction,
              invalidDateMessage: l10n.pharmacyExpiryDateLabel,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onChanged: (DateTime? value) => setState(() => _expiryDate = value),
            ),
            if (activeRooms.isNotEmpty)
              AppResponsiveFieldRow.two(
                gap: AppResponsiveFieldRowGap.form,
                left: AppSelectField<String>(
                  value: _storageRoomId,
                  labelText: l10n.pharmacyStorageRoomLabel,
                  enabled: !_isSaving,
                  options: activeRooms
                      .map(
                        (PharmacyStorageRoom room) => AppSelectOption<String>(
                          value: room.id,
                          label: room.name ?? room.id,
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    setState(() {
                      _storageRoomId = value;
                      final List<PharmacyStorageShelf> nextShelves =
                          activeRooms
                              .where(
                                (PharmacyStorageRoom room) => room.id == value,
                              )
                              .expand(
                                (PharmacyStorageRoom room) => room.shelves,
                              )
                              .where(
                                (PharmacyStorageShelf shelf) => shelf.isActive,
                              )
                              .toList(growable: false);
                      if (_storageShelfId != null &&
                          !nextShelves.any(
                            (PharmacyStorageShelf shelf) =>
                                shelf.id == _storageShelfId,
                          )) {
                        _storageShelfId = null;
                      }
                    });
                  },
                ),
                right: AppSelectField<String>(
                  value: _storageShelfId,
                  labelText: l10n.pharmacyStorageShelfLabel,
                  enabled: !_isSaving && _storageRoomId != null,
                  options: shelfOptions
                      .map(
                        (PharmacyStorageShelf shelf) => AppSelectOption<String>(
                          value: shelf.id,
                          label: shelf.displayLabel,
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) =>
                      setState(() => _storageShelfId = value),
                ),
              ),
          ],
          AppTextField(
            controller: _notesController,
            labelText: l10n.pharmacyNotesLabel,
            maxLines: 2,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.pharmacyAdjustStockAction,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final int delta = int.tryParse(_deltaController.text.trim()) ?? 0;
    final int? reorderLevel = int.tryParse(_reorderController.text.trim());
    if (delta == 0 && reorderLevel == null) {
      return;
    }
    if (_expiryDate != null && _batchController.text.trim().isEmpty) {
      return;
    }
    setState(() => _isSaving = true);
    final AppFailure? failure = await ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .adjustInventoryStock(
          PharmacyInventoryAdjustInput(
            inventoryItemId:
                widget.stock.inventoryItemId ??
                widget.stock.inventoryItem?.id ??
                widget.stock.id,
            quantityDelta: delta,
            reorderLevel: reorderLevel,
            reason: _reason,
            notes: _emptyToNull(_notesController.text),
            facilityId: widget.stock.facilityId,
            batchNumber: _emptyToNull(_batchController.text),
            expiryDate: _expiryDate,
            storageRoomId: _storageRoomId,
            storageShelfId: _storageShelfId,
          ),
        );
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _isSaving = false);
  }
}

Widget _expiryCell(BuildContext context, PharmacyInventoryStock item) {
  final AppLocalizations l10n = context.l10n;
  if (item.nextExpiry == null) {
    return const Text('—');
  }
  final String formatted = AppFormatters.dateTime(
    item.nextExpiry!,
    Localizations.localeOf(context),
  );
  if (item.expiryAlertStatus == 'EXPIRED') {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: '$formatted · ${l10n.pharmacyStockExpiredLabel}',
        tone: AppWorkspaceStatusTone.error,
      ),
    );
  }
  if (item.expiryAlertStatus == 'EXPIRING_SOON') {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: '$formatted · ${l10n.pharmacyStockExpiringSoonLabel}',
        tone: AppWorkspaceStatusTone.warning,
      ),
    );
  }
  return Text(formatted);
}

AppWorkspaceStatus _stockStatus(BuildContext context, String? value) {
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

String? _emptyToNull(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _priceText(num? value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

List<PharmacyStorageRoom> _activeStorageRooms(PharmacyStorageLayout layout) {
  return layout.rooms
      .where((PharmacyStorageRoom room) => room.isActive)
      .toList(growable: false);
}

List<PharmacyStorageShelf> _shelfOptionsForRoom(
  PharmacyStorageLayout layout,
  String? roomId,
) {
  if (roomId == null) {
    return const <PharmacyStorageShelf>[];
  }
  return _activeStorageRooms(layout)
      .where((PharmacyStorageRoom room) => room.id == roomId)
      .expand((PharmacyStorageRoom room) => room.shelves)
      .where((PharmacyStorageShelf shelf) => shelf.isActive)
      .toList(growable: false);
}

class _StorageLocationFilters extends StatelessWidget {
  const _StorageLocationFilters({
    required this.layout,
    required this.storageRoomId,
    required this.storageShelfId,
    required this.onRoomChanged,
    required this.onShelfChanged,
  });

  final PharmacyStorageLayout layout;
  final String? storageRoomId;
  final String? storageShelfId;
  final ValueChanged<String?> onRoomChanged;
  final ValueChanged<String?> onShelfChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<PharmacyStorageRoom> activeRooms = _activeStorageRooms(layout);
    final List<PharmacyStorageShelf> shelfOptions = _shelfOptionsForRoom(
      layout,
      storageRoomId,
    );

    return AppResponsiveFieldRow.two(
      gap: AppResponsiveFieldRowGap.form,
      left: AppSelectField<String?>(
        value: storageRoomId,
        labelText: l10n.pharmacyStorageRoomLabel,
        options: <AppSelectOption<String?>>[
          AppSelectOption<String?>(
            value: null,
            label: l10n.pharmacyStorageFilterAll,
          ),
          ...activeRooms.map(
            (PharmacyStorageRoom room) => AppSelectOption<String?>(
              value: room.id,
              label: room.name ?? room.id,
            ),
          ),
        ],
        onChanged: onRoomChanged,
      ),
      right: AppSelectField<String?>(
        value: storageShelfId,
        labelText: l10n.pharmacyStorageShelfLabel,
        enabled: storageRoomId != null,
        options: <AppSelectOption<String?>>[
          AppSelectOption<String?>(
            value: null,
            label: l10n.pharmacyStorageFilterAll,
          ),
          ...shelfOptions.map(
            (PharmacyStorageShelf shelf) => AppSelectOption<String?>(
              value: shelf.id,
              label: shelf.displayLabel,
            ),
          ),
        ],
        onChanged: onShelfChanged,
      ),
    );
  }
}
