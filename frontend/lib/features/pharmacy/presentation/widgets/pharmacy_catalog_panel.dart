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
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_catalog_tabs.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

const String _inventoryStockStatusFilterKey = 'stock_status';
const String _storageRoomFilterKey = 'storage_room';
const String _storageShelfFilterKey = 'storage_shelf';
const String _formularyActiveFilterKey = 'is_active';
const String _drugStockStatusFilterKey = 'stock_status';

class PharmacyCatalogPanel extends ConsumerStatefulWidget {
  const PharmacyCatalogPanel({
    required this.state,
    this.fillHeight = false,
    super.key,
  });

  final PharmacyWorkspaceState state;
  final bool fillHeight;

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
    final PharmacyWorkspaceState state =
        ref
            .watch(pharmacyWorkspaceControllerProvider)
            .value
            ?.when(
              success: (PharmacyWorkspaceState value) => value,
              failure: (_) => widget.state,
            ) ??
        widget.state;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final PharmacyCatalogTab tab = state.catalogTab;
    final List<PharmacyCatalogTabDescriptor> tabDescriptors =
        pharmacyCatalogTabDescriptors(l10n);

    final Widget tabContent = switch (tab) {
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
        showHeaderActions: false,
        compact: true,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PharmacyCatalogIconTabBar(
          tabs: tabDescriptors,
          selectedTab: tab,
          onTabSelected: controller.setCatalogTab,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        if (widget.fillHeight) Expanded(child: tabContent) else tabContent,
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
  final Set<String> _selectedDrugIds = <String>{};

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

    final PharmacyDrugQuery drugQuery = widget.state.drugQuery;

    return AppListTable<PharmacyDrug>(
      page: widget.state.drugs,
      isLoading: widget.state.isRefreshingDrugs,
      search: AppListTableSearch<PharmacyDrug>(
        controller: _searchController,
        semanticLabel: l10n.pharmacyDrugSearchLabel,
        hintText: l10n.pharmacyDrugSearchHint,
        matcher: (_, _) => true,
        onSubmitted: controller.applyDrugSearch,
        onClear: () => unawaited(controller.applyDrugSearch('')),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.pharmacyQueueFilterLabel,
        advancedFilterTitle: l10n.pharmacyFiltersSemanticLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        enableDateFilter: false,
        allFieldsLabel: l10n.opdAllFieldsFilterLabel,
        filterGroups: _drugCatalogFilterGroups(
          l10n: l10n,
          layout: widget.state.storageLayout,
          storageRoomId: drugQuery.storageRoomId,
        ),
        filterValue: _drugCatalogFilterValue(drugQuery),
        hasActiveFilters: _hasDrugCatalogFilters(drugQuery),
        onFilterChanged: (AppSearchBarFilterValue value) {
          unawaited(_applyDrugCatalogFilter(controller, value));
        },
        trailingActions: _catalogSearchTrailingActions(
          ref: ref,
          writeRequirement: widget.writeRequirement,
          isBusy: widget.state.isRefreshingDrugs,
          selectionActions: _selectedDrugIds.isEmpty
              ? const <AppSearchBarAction>[]
              : <AppSearchBarAction>[
                  AppSearchBarAction(
                    icon: Icons.delete_outline,
                    label: l10n.pharmacyDeleteSelectedDrugsAction,
                    tooltip: l10n.pharmacyDeleteSelectedDrugsAction,
                    destructive: true,
                    enabled: !widget.state.isRefreshingDrugs,
                    onPressed: widget.state.isRefreshingDrugs
                        ? null
                        : () => _confirmDeleteSelectedDrugs(context),
                  ),
                ],
          addLabel: l10n.pharmacyAddDrugAction,
          onAdd: () => _openDrugDialog(context),
        ),
      ),
      onPageChanged: controller.changeDrugPage,
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.pharmacyNoDrugsTitle,
        body: l10n.pharmacyNoDrugsBody,
        icon: Icons.medication_outlined,
      ),
      columns: <AppListTableColumn<PharmacyDrug>>[
        _selectionColumn<PharmacyDrug>(
          visibleItems: widget.state.drugs.items,
          selectedKeys: _selectedDrugIds,
          isBusy: widget.state.isRefreshingDrugs,
          itemKey: (PharmacyDrug item) => item.id,
          onToggle: (PharmacyDrug item, bool selected) {
            setState(() {
              if (selected) {
                _selectedDrugIds.add(item.id);
              } else {
                _selectedDrugIds.remove(item.id);
              }
            });
          },
          onToggleAll: (List<PharmacyDrug> items, bool selected) {
            setState(() {
              if (!selected) {
                for (final PharmacyDrug item in items) {
                  _selectedDrugIds.remove(item.id);
                }
                return;
              }
              for (final PharmacyDrug item in items) {
                _selectedDrugIds.add(item.id);
              }
            });
          },
        ),
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
          alwaysVisible: true,
          cellBuilder: (BuildContext context, PharmacyDrug item) {
            return _catalogRowActions(
              context: context,
              writeRequirement: widget.writeRequirement,
              isBusy: widget.state.isRefreshingDrugs,
              editLabel: l10n.pharmacyEditDrugAction,
              deleteLabel: l10n.pharmacyDeleteDrugAction,
              onEdit: () => _openDrugDialog(context, drug: item),
              onDelete: () => _confirmDeleteDrug(context, item),
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, PharmacyDrug item) {
        return ListTile(
          leading: Checkbox(
            value: _selectedDrugIds.contains(item.id),
            onChanged: widget.state.isRefreshingDrugs
                ? null
                : (bool? value) {
                    setState(() {
                      if (value ?? false) {
                        _selectedDrugIds.add(item.id);
                      } else {
                        _selectedDrugIds.remove(item.id);
                      }
                    });
                  },
            visualDensity: VisualDensity.compact,
          ),
          title: Text(item.displayTitle),
          subtitle: Text(item.code ?? ''),
        );
      },
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
    if (!context.mounted) {
      return;
    }
    if (failure == null) {
      setState(() => _selectedDrugIds.remove(drug.id));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.pharmacyCatalogDeleteFailedMessage)),
    );
  }

  Future<void> _confirmDeleteSelectedDrugs(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    final int count = _selectedDrugIds.length;
    if (count == 0) {
      return;
    }
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: Text(l10n.pharmacyDeleteSelectedDrugsDialogTitle),
        content: Text(l10n.pharmacyDeleteSelectedDrugsDialogBody(count)),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton.primary(
            label: l10n.pharmacyDeleteDrugAction,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final List<String> ids = _selectedDrugIds.toList(growable: false);
    for (final String drugId in ids) {
      final AppFailure? failure = await controller.deleteDrug(drugId);
      if (!context.mounted) {
        return;
      }
      if (failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pharmacyCatalogDeleteFailedMessage)),
        );
        return;
      }
    }
    setState(_selectedDrugIds.clear);
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
  final Set<String> _selectedFormularyIds = <String>{};
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.state.formularyQuery.search,
    );
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
    final bool isBusy = widget.state.isRefreshingFormulary;

    final PharmacyFormularyQuery formularyQuery = widget.state.formularyQuery;

    return AppListTable<PharmacyFormularyItem>(
      page: widget.state.formularyItems,
      isLoading: isBusy,
      onPageChanged: controller.changeFormularyPage,
      search: AppListTableSearch<PharmacyFormularyItem>(
        controller: _searchController,
        semanticLabel: l10n.pharmacyFormularyDrugLabel,
        hintText: l10n.pharmacyDrugSearchHint,
        matcher: (_, _) => true,
        onSubmitted: controller.applyFormularySearch,
        onClear: () => unawaited(controller.applyFormularySearch('')),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.pharmacyQueueFilterLabel,
        advancedFilterTitle: l10n.pharmacyFiltersSemanticLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        enableDateFilter: false,
        allFieldsLabel: l10n.opdAllFieldsFilterLabel,
        filterGroups: _formularyCatalogFilterGroups(l10n),
        filterValue: _formularyCatalogFilterValue(formularyQuery),
        hasActiveFilters: _hasFormularyCatalogFilters(formularyQuery),
        onFilterChanged: (AppSearchBarFilterValue value) {
          unawaited(_applyFormularyCatalogFilter(controller, value));
        },
        trailingActions: _catalogSearchTrailingActions(
          ref: ref,
          writeRequirement: widget.writeRequirement,
          isBusy: isBusy,
          selectionActions: _selectedFormularyIds.isEmpty
              ? const <AppSearchBarAction>[]
              : <AppSearchBarAction>[
                  AppSearchBarAction(
                    icon: Icons.delete_outline,
                    label: l10n.pharmacyDeleteSelectedFormularyAction,
                    tooltip: l10n.pharmacyDeleteSelectedFormularyAction,
                    destructive: true,
                    enabled: !isBusy,
                    onPressed: isBusy
                        ? null
                        : () => _confirmDeleteSelectedFormulary(context),
                  ),
                ],
          addLabel: l10n.pharmacyAddFormularyAction,
          onAdd: () => _openFormularyDialog(context),
        ),
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.pharmacyNoFormularyTitle,
        body: l10n.pharmacyNoFormularyBody,
        icon: Icons.list_alt_outlined,
      ),
      columns: <AppListTableColumn<PharmacyFormularyItem>>[
        _selectionColumn<PharmacyFormularyItem>(
          visibleItems: widget.state.formularyItems.items,
          selectedKeys: _selectedFormularyIds,
          isBusy: isBusy,
          itemKey: (PharmacyFormularyItem item) => item.id,
          onToggle: (PharmacyFormularyItem item, bool selected) {
            setState(() {
              if (selected) {
                _selectedFormularyIds.add(item.id);
              } else {
                _selectedFormularyIds.remove(item.id);
              }
            });
          },
          onToggleAll: (List<PharmacyFormularyItem> items, bool selected) {
            setState(() {
              if (!selected) {
                for (final PharmacyFormularyItem item in items) {
                  _selectedFormularyIds.remove(item.id);
                }
                return;
              }
              for (final PharmacyFormularyItem item in items) {
                _selectedFormularyIds.add(item.id);
              }
            });
          },
        ),
        AppListTableColumn<PharmacyFormularyItem>(
          label: l10n.pharmacyDrugNameLabel,
          cellBuilder: (_, PharmacyFormularyItem item) =>
              Text(item.drugNameLabel ?? '—'),
        ),
        AppListTableColumn<PharmacyFormularyItem>(
          label: l10n.pharmacyFormularyIdLabel,
          cellBuilder: (_, PharmacyFormularyItem item) =>
              Text(item.displayId ?? item.id),
        ),
        AppListTableColumn<PharmacyFormularyItem>(
          label: l10n.pharmacyFormularyActiveLabel,
          cellBuilder: (BuildContext context, PharmacyFormularyItem item) {
            return AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: item.isActive ? l10n.commonYesLabel : l10n.commonNoLabel,
                tone: item.isActive
                    ? AppWorkspaceStatusTone.success
                    : AppWorkspaceStatusTone.neutral,
              ),
            );
          },
        ),
        AppListTableColumn<PharmacyFormularyItem>(
          label: '',
          alwaysVisible: true,
          cellBuilder: (BuildContext context, PharmacyFormularyItem item) {
            return _catalogRowActions(
              context: context,
              writeRequirement: widget.writeRequirement,
              isBusy: isBusy,
              editLabel: l10n.pharmacyEditFormularyAction,
              deleteLabel: l10n.pharmacyDeleteFormularyAction,
              onEdit: () => _openFormularyDialog(context, item: item),
              onDelete: () => _confirmDeleteFormulary(context, item),
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, PharmacyFormularyItem item) {
        return ListTile(
          leading: Checkbox(
            value: _selectedFormularyIds.contains(item.id),
            onChanged: isBusy
                ? null
                : (bool? value) {
                    setState(() {
                      if (value ?? false) {
                        _selectedFormularyIds.add(item.id);
                      } else {
                        _selectedFormularyIds.remove(item.id);
                      }
                    });
                  },
            visualDensity: VisualDensity.compact,
          ),
          title: Text(item.drugNameLabel ?? item.displayId ?? item.id),
          subtitle: item.drugCode == null ? null : Text(item.drugCode!),
        );
      },
    );
  }

  Future<void> _openFormularyDialog(
    BuildContext context, {
    PharmacyFormularyItem? item,
  }) {
    return showAppDialog<bool>(
      context: context,
      builder: (_) => _FormularyItemDialog(item: item),
    );
  }

  Future<void> _confirmDeleteFormulary(
    BuildContext context,
    PharmacyFormularyItem item,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: Text(l10n.pharmacyDeleteFormularyDialogTitle),
        content: Text(l10n.pharmacyDeleteFormularyDialogBody),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton.primary(
            label: l10n.pharmacyDeleteFormularyAction,
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
        .deleteFormularyItem(item.id);
    if (!context.mounted) {
      return;
    }
    if (failure == null) {
      setState(() => _selectedFormularyIds.remove(item.id));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.pharmacyCatalogDeleteFailedMessage)),
    );
  }

  Future<void> _confirmDeleteSelectedFormulary(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    final int count = _selectedFormularyIds.length;
    if (count == 0) {
      return;
    }
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: Text(l10n.pharmacyDeleteSelectedFormularyDialogTitle),
        content: Text(l10n.pharmacyDeleteSelectedFormularyDialogBody(count)),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton.primary(
            label: l10n.pharmacyDeleteFormularyAction,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final List<String> ids = _selectedFormularyIds.toList(growable: false);
    for (final String formularyItemId in ids) {
      final AppFailure? failure = await controller.deleteFormularyItem(
        formularyItemId,
      );
      if (!context.mounted) {
        return;
      }
      if (failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pharmacyCatalogDeleteFailedMessage)),
        );
        return;
      }
    }
    setState(_selectedFormularyIds.clear);
  }
}

class _FormularyItemDialog extends ConsumerStatefulWidget {
  const _FormularyItemDialog({this.item});

  final PharmacyFormularyItem? item;

  @override
  ConsumerState<_FormularyItemDialog> createState() =>
      _FormularyItemDialogState();
}

class _FormularyItemDialogState extends ConsumerState<_FormularyItemDialog> {
  late String? _drugId;
  late bool _isActive;
  bool _isSaving = false;
  late final TextEditingController _drugSearchController;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _drugId = widget.item?.drugId;
    _isActive = widget.item?.isActive ?? true;
    _drugSearchController = TextEditingController();
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          ref
              .read(pharmacyWorkspaceControllerProvider.notifier)
              .applyDrugSearch(''),
        );
      });
    }
  }

  @override
  void dispose() {
    _drugSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final PharmacyWorkspaceState? workspaceState = ref
        .watch(pharmacyWorkspaceControllerProvider)
        .value
        ?.when(
          success: (PharmacyWorkspaceState value) => value,
          failure: (_) => null,
        );
    final AppPage<PharmacyDrug> drugsPage =
        workspaceState?.drugs ??
        const AppPage<PharmacyDrug>(
          items: <PharmacyDrug>[],
          request: AppPageRequest(pageSize: 10),
        );
    final bool isLoadingDrugs = workspaceState?.isRefreshingDrugs ?? false;

    return AppDialog(
      title: Text(
        _isEditing
            ? l10n.pharmacyEditFormularyAction
            : l10n.pharmacyAddFormularyAction,
      ),
      scrollable: true,
      maxWidth: 760,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_isEditing)
            AppTextField(
              readOnly: true,
              initialValue: widget.item?.displayTitle,
              labelText: l10n.pharmacyFormularyDrugLabel,
            )
          else
            AppListTable<PharmacyDrug>(
              page: drugsPage,
              isLoading: isLoadingDrugs,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              tableHorizontalMargin: 0,
              onPageChanged: controller.changeDrugPage,
              onRowSelected: _isSaving
                  ? null
                  : (PharmacyDrug drug) => setState(() => _drugId = drug.id),
              search: AppListTableSearch<PharmacyDrug>(
                controller: _drugSearchController,
                semanticLabel: l10n.pharmacyDrugSearchLabel,
                hintText: l10n.pharmacyDrugSearchHint,
                matcher: (_, _) => true,
                onSubmitted: controller.applyDrugSearch,
                onClear: () => unawaited(controller.applyDrugSearch('')),
              ),
              columns: <AppListTableColumn<PharmacyDrug>>[
                AppListTableColumn<PharmacyDrug>(
                  label: '',
                  cellBuilder: (BuildContext context, PharmacyDrug drug) {
                    final bool selected = _drugId == drug.id;
                    return Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    );
                  },
                ),
                AppListTableColumn<PharmacyDrug>(
                  label: l10n.pharmacyDrugNameLabel,
                  cellBuilder: (_, PharmacyDrug drug) =>
                      Text(drug.displayTitle),
                ),
                AppListTableColumn<PharmacyDrug>(
                  label: l10n.pharmacyDrugCodeLabel,
                  cellBuilder: (_, PharmacyDrug drug) => Text(drug.code ?? ''),
                ),
              ],
              mobileItemBuilder: (BuildContext context, PharmacyDrug drug) {
                final bool selected = _drugId == drug.id;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(drug.displayTitle),
                  subtitle: drug.code == null ? null : Text(drug.code!),
                  onTap: _isSaving
                      ? null
                      : () => setState(() => _drugId = drug.id),
                );
              },
              emptyBuilder: (_) => AppWorkspaceStatePanel.state(
                variant: AppStateViewVariant.empty,
                title: l10n.pharmacyNoDrugsTitle,
                body: l10n.pharmacyNoDrugsBody,
                icon: Icons.medication_outlined,
              ),
            ),
          AppSwitchField(
            title: l10n.pharmacyFormularyActiveLabel,
            value: _isActive,
            onChanged: _isSaving
                ? null
                : (bool value) => setState(() => _isActive = value),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: _isEditing
              ? l10n.pharmacyEditFormularyAction
              : l10n.pharmacyAddFormularyAction,
          leadingIcon: _isEditing ? Icons.save_outlined : Icons.add,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    setState(() => _isSaving = true);
    final AppFailure? failure;
    if (_isEditing) {
      failure = await controller.updateFormularyItem(
        widget.item!.id,
        isActive: _isActive,
      );
    } else {
      final String? drugId = _drugId;
      final String? tenantId = controller.resolveTenantId();
      if (drugId == null || tenantId == null) {
        setState(() => _isSaving = false);
        return;
      }
      failure = await controller.createFormularyItem(
        PharmacyFormularyItemInput(
          tenantId: tenantId,
          drugId: drugId,
          isActive: _isActive,
        ),
      );
    }
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
  final Set<String> _selectedInventoryIds = <String>{};

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
    final bool isBusy = widget.state.isRefreshingInventory;

    final PharmacyInventoryStockQuery inventoryQuery =
        widget.state.inventoryQuery;

    return AppListTable<PharmacyInventoryStock>(
      page: widget.state.inventoryWorkbench.stocks,
      isLoading: isBusy,
      search: AppListTableSearch<PharmacyInventoryStock>(
        controller: _searchController,
        semanticLabel: l10n.pharmacySearchLabel,
        hintText: l10n.pharmacySearchHint,
        matcher: (_, _) => true,
        onSubmitted: controller.applyInventorySearch,
        onClear: () => unawaited(controller.applyInventorySearch('')),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.pharmacyQueueFilterLabel,
        advancedFilterTitle: l10n.pharmacyFiltersSemanticLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        enableDateFilter: false,
        allFieldsLabel: l10n.opdAllFieldsFilterLabel,
        filterGroups: _inventoryCatalogFilterGroups(
          l10n: l10n,
          layout: widget.state.storageLayout,
          storageRoomId: inventoryQuery.storageRoomId,
        ),
        filterValue: _inventoryCatalogFilterValue(inventoryQuery),
        hasActiveFilters: _hasInventoryCatalogFilters(inventoryQuery),
        onFilterChanged: (AppSearchBarFilterValue value) {
          unawaited(_applyInventoryCatalogFilter(controller, value));
        },
        trailingActions: _selectedInventoryIds.isEmpty
            ? const <AppSearchBarAction>[]
            : <AppSearchBarAction>[
                AppSearchBarAction(
                  icon: Icons.delete_outline,
                  label: l10n.pharmacyClearSelectedInventoryAction,
                  tooltip: l10n.pharmacyClearSelectedInventoryAction,
                  destructive: true,
                  enabled: !isBusy,
                  onPressed: isBusy
                      ? null
                      : () => _confirmClearSelectedInventory(context),
                ),
              ],
      ),
      onPageChanged: controller.changeInventoryPage,
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.pharmacyNoInventoryTitle,
        body: l10n.pharmacyNoInventoryBody,
        icon: Icons.warehouse_outlined,
      ),
      columns: <AppListTableColumn<PharmacyInventoryStock>>[
        _selectionColumn<PharmacyInventoryStock>(
          visibleItems: widget.state.inventoryWorkbench.stocks.items,
          selectedKeys: _selectedInventoryIds,
          isBusy: isBusy,
          itemKey: (PharmacyInventoryStock item) =>
              _inventorySelectionKey(item),
          onToggle: (PharmacyInventoryStock item, bool selected) {
            setState(() {
              final String key = _inventorySelectionKey(item);
              if (selected) {
                _selectedInventoryIds.add(key);
              } else {
                _selectedInventoryIds.remove(key);
              }
            });
          },
          onToggleAll: (List<PharmacyInventoryStock> items, bool selected) {
            setState(() {
              if (!selected) {
                for (final PharmacyInventoryStock item in items) {
                  _selectedInventoryIds.remove(_inventorySelectionKey(item));
                }
                return;
              }
              for (final PharmacyInventoryStock item in items) {
                _selectedInventoryIds.add(_inventorySelectionKey(item));
              }
            });
          },
        ),
        AppListTableColumn<PharmacyInventoryStock>(
          label: l10n.pharmacyInventoryItemLabel,
          cellBuilder: (_, PharmacyInventoryStock item) {
            return Text(
              item.inventoryItem?.displayTitle ?? item.displayId ?? '',
            );
          },
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
          alwaysVisible: true,
          cellBuilder: (BuildContext context, PharmacyInventoryStock item) {
            return _catalogRowActions(
              context: context,
              writeRequirement: widget.writeRequirement,
              isBusy: isBusy,
              editLabel: l10n.pharmacyAdjustStockAction,
              deleteLabel: l10n.pharmacyDeleteInventoryStockAction,
              onEdit: () => _openAdjustDialog(context, item),
              onDelete: () => _confirmClearInventoryStock(context, item),
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, PharmacyInventoryStock item) {
        final String selectionKey = _inventorySelectionKey(item);
        return ListTile(
          leading: Checkbox(
            value: _selectedInventoryIds.contains(selectionKey),
            onChanged: isBusy
                ? null
                : (bool? value) {
                    setState(() {
                      if (value ?? false) {
                        _selectedInventoryIds.add(selectionKey);
                      } else {
                        _selectedInventoryIds.remove(selectionKey);
                      }
                    });
                  },
            visualDensity: VisualDensity.compact,
          ),
          title: Text(item.inventoryItem?.displayTitle ?? ''),
          subtitle: Text(
            '${item.quantity} · ${l10n.pharmacyReorderLevelColumnLabel}: ${item.reorderLevel}',
          ),
          trailing: _expiryCell(context, item),
        );
      },
    );
  }

  String _inventorySelectionKey(PharmacyInventoryStock item) {
    return item.id;
  }

  Future<void> _confirmClearInventoryStock(
    BuildContext context,
    PharmacyInventoryStock stock,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: Text(l10n.pharmacyDeleteInventoryStockDialogTitle),
        content: Text(l10n.pharmacyDeleteInventoryStockDialogBody),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton.primary(
            label: l10n.pharmacyDeleteInventoryStockAction,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await _clearInventoryStock(context, stock);
  }

  Future<void> _confirmClearSelectedInventory(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    final int count = _selectedInventoryIds.length;
    if (count == 0) {
      return;
    }
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: Text(l10n.pharmacyClearSelectedInventoryDialogTitle),
        content: Text(l10n.pharmacyClearSelectedInventoryDialogBody(count)),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton.primary(
            label: l10n.pharmacyClearSelectedInventoryAction,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final List<PharmacyInventoryStock> selectedStocks = widget
        .state
        .inventoryWorkbench
        .stocks
        .items
        .where(
          (PharmacyInventoryStock item) =>
              _selectedInventoryIds.contains(_inventorySelectionKey(item)),
        )
        .toList(growable: false);
    for (final PharmacyInventoryStock stock in selectedStocks) {
      if (!context.mounted) {
        return;
      }
      await _clearInventoryStock(context, stock, showFailureSnackBar: false);
    }
    if (context.mounted) {
      setState(_selectedInventoryIds.clear);
    }
  }

  Future<void> _clearInventoryStock(
    BuildContext context,
    PharmacyInventoryStock stock, {
    bool showFailureSnackBar = true,
  }) async {
    if (stock.quantity <= 0) {
      setState(
        () => _selectedInventoryIds.remove(_inventorySelectionKey(stock)),
      );
      return;
    }
    final AppFailure? failure = await ref
        .read(pharmacyWorkspaceControllerProvider.notifier)
        .adjustInventoryStock(
          PharmacyInventoryAdjustInput(
            inventoryItemId:
                stock.inventoryItemId ?? stock.inventoryItem?.id ?? stock.id,
            quantityDelta: -stock.quantity.toInt(),
            reason: 'DAMAGE',
            facilityId: stock.facilityId,
          ),
        );
    if (!context.mounted) {
      return;
    }
    if (failure == null) {
      setState(
        () => _selectedInventoryIds.remove(_inventorySelectionKey(stock)),
      );
      return;
    }
    if (showFailureSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.pharmacyCatalogDeleteFailedMessage),
        ),
      );
    }
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
    final PharmacyStorageLayout storageLayout =
        ref
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
              onChanged: (DateTime? value) =>
                  setState(() => _expiryDate = value),
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
                      final List<PharmacyStorageShelf> nextShelves = activeRooms
                          .where((PharmacyStorageRoom room) => room.id == value)
                          .expand((PharmacyStorageRoom room) => room.shelves)
                          .where((PharmacyStorageShelf shelf) => shelf.isActive)
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
          leadingIcon: Icons.close,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.pharmacyAdjustStockAction,
          leadingIcon: Icons.save_outlined,
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

AppListTableColumn<T> _selectionColumn<T>({
  required List<T> visibleItems,
  required Set<String> selectedKeys,
  required bool isBusy,
  required String Function(T item) itemKey,
  required void Function(T item, bool selected) onToggle,
  required void Function(List<T> items, bool selected) onToggleAll,
}) {
  final bool allSelected =
      visibleItems.isNotEmpty &&
      visibleItems.every((T item) => selectedKeys.contains(itemKey(item)));
  final bool someSelected = visibleItems.any(
    (T item) => selectedKeys.contains(itemKey(item)),
  );

  return AppListTableColumn<T>(
    id: 'select',
    label: '',
    alwaysVisible: true,
    headerBuilder: (BuildContext context) {
      return Checkbox(
        tristate: true,
        value: allSelected
            ? true
            : someSelected
            ? null
            : false,
        onChanged: !isBusy && visibleItems.isNotEmpty
            ? (_) => onToggleAll(visibleItems, !allSelected)
            : null,
        visualDensity: VisualDensity.compact,
      );
    },
    cellBuilder: (BuildContext context, T item) {
      return Checkbox(
        value: selectedKeys.contains(itemKey(item)),
        onChanged: isBusy
            ? null
            : (bool? value) => onToggle(item, value ?? false),
        visualDensity: VisualDensity.compact,
      );
    },
  );
}

Widget _catalogRowActions({
  required BuildContext context,
  required AccessRequirement writeRequirement,
  required bool isBusy,
  required String editLabel,
  required String deleteLabel,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  return AppAccessActionGate(
    requirement: writeRequirement,
    builder: (BuildContext context, bool isAllowed) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppButton.tertiary(
          leadingIcon: Icons.edit_outlined,
          label: editLabel,
          semanticLabel: editLabel,
          tooltip: editLabel,
          enabled: isAllowed && !isBusy,
          onPressed: isAllowed && !isBusy ? onEdit : null,
        ),
        AppButton.tertiary(
          leadingIcon: Icons.delete_outline,
          label: deleteLabel,
          semanticLabel: deleteLabel,
          tooltip: deleteLabel,
          color: colorScheme.error,
          enabled: isAllowed && !isBusy,
          onPressed: isAllowed && !isBusy ? onDelete : null,
        ),
      ],
    ),
  );
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

List<AppSearchBarAction> _catalogSearchTrailingActions({
  required WidgetRef ref,
  required AccessRequirement writeRequirement,
  required bool isBusy,
  required List<AppSearchBarAction> selectionActions,
  String? addLabel,
  VoidCallback? onAdd,
}) {
  if (selectionActions.isNotEmpty) {
    return selectionActions;
  }
  if (addLabel == null || onAdd == null) {
    return const <AppSearchBarAction>[];
  }
  final bool isAllowed = writeRequirement.allows(ref);
  return <AppSearchBarAction>[
    AppSearchBarAction(
      icon: Icons.add,
      label: addLabel,
      tooltip: addLabel,
      enabled: isAllowed && !isBusy,
      onPressed: isAllowed && !isBusy ? onAdd : null,
    ),
  ];
}

List<AppSearchBarFilterGroup> _storageLocationFilterGroups({
  required AppLocalizations l10n,
  required PharmacyStorageLayout layout,
  required String? storageRoomId,
}) {
  final List<PharmacyStorageRoom> activeRooms = _activeStorageRooms(layout);
  if (activeRooms.isEmpty) {
    return const <AppSearchBarFilterGroup>[];
  }

  final List<AppSearchBarFilterGroup> groups = <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: _storageRoomFilterKey,
      label: l10n.pharmacyStorageRoomLabel,
      allLabel: l10n.pharmacyStorageFilterAll,
      choices: activeRooms
          .map(
            (PharmacyStorageRoom room) => AppSearchBarFilterChoice(
              value: room.id,
              label: room.name ?? room.id,
              icon: Icons.warehouse_outlined,
            ),
          )
          .toList(growable: false),
    ),
  ];

  if (storageRoomId != null) {
    final List<PharmacyStorageShelf> shelves = _shelfOptionsForRoom(
      layout,
      storageRoomId,
    );
    if (shelves.isNotEmpty) {
      groups.add(
        AppSearchBarFilterGroup(
          key: _storageShelfFilterKey,
          label: l10n.pharmacyStorageShelfLabel,
          allLabel: l10n.pharmacyStorageFilterAll,
          choices: shelves
              .map(
                (PharmacyStorageShelf shelf) => AppSearchBarFilterChoice(
                  value: shelf.id,
                  label: shelf.displayLabel,
                  icon: Icons.view_week_outlined,
                ),
              )
              .toList(growable: false),
        ),
      );
    }
  }

  return groups;
}

List<AppSearchBarFilterGroup> _drugCatalogFilterGroups({
  required AppLocalizations l10n,
  required PharmacyStorageLayout layout,
  required String? storageRoomId,
}) {
  return <AppSearchBarFilterGroup>[
    ..._storageLocationFilterGroups(
      l10n: l10n,
      layout: layout,
      storageRoomId: storageRoomId,
    ),
    AppSearchBarFilterGroup(
      key: _drugStockStatusFilterKey,
      label: l10n.pharmacyStockStatusFilterLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'IN_STOCK',
          label: l10n.pharmacyStockInStock,
          icon: Icons.check_circle_outline,
        ),
        AppSearchBarFilterChoice(
          value: 'ALMOST_OUT_OF_STOCK',
          label: l10n.pharmacyStockAlmostOut,
          icon: Icons.warning_amber_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'LOW_STOCK',
          label: l10n.pharmacyStockLow,
          icon: Icons.trending_down,
        ),
        AppSearchBarFilterChoice(
          value: 'OUT_OF_STOCK',
          label: l10n.pharmacyStockOut,
          icon: Icons.remove_shopping_cart_outlined,
        ),
      ],
    ),
  ];
}

List<AppSearchBarFilterGroup> _formularyCatalogFilterGroups(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: _formularyActiveFilterKey,
      label: l10n.pharmacyFormularyActiveLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'true',
          label: l10n.commonYesLabel,
          icon: Icons.check_circle_outline,
        ),
        AppSearchBarFilterChoice(
          value: 'false',
          label: l10n.commonNoLabel,
          icon: Icons.cancel_outlined,
        ),
      ],
    ),
  ];
}

List<AppSearchBarFilterGroup> _inventoryCatalogFilterGroups({
  required AppLocalizations l10n,
  required PharmacyStorageLayout layout,
  required String? storageRoomId,
}) {
  return <AppSearchBarFilterGroup>[
    ..._storageLocationFilterGroups(
      l10n: l10n,
      layout: layout,
      storageRoomId: storageRoomId,
    ),
    AppSearchBarFilterGroup(
      key: _inventoryStockStatusFilterKey,
      label: l10n.pharmacyStockStatusFilterLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'LOW_STOCK',
          label: l10n.pharmacyLowStockOnlyFilterLabel,
          icon: Icons.trending_down,
        ),
        AppSearchBarFilterChoice(
          value: 'EXPIRING_SOON',
          label: l10n.pharmacyExpiringSoonFilterLabel,
          icon: Icons.schedule,
        ),
        AppSearchBarFilterChoice(
          value: 'EXPIRED',
          label: l10n.pharmacyExpiredOnlyFilterLabel,
          icon: Icons.event_busy,
        ),
      ],
    ),
  ];
}

AppSearchBarFilterValue _catalogStorageFilterValue({
  String? storageRoomId,
  String? storageShelfId,
}) {
  final Map<String, String> options = <String, String>{};
  if (storageRoomId != null) {
    options[_storageRoomFilterKey] = storageRoomId;
  }
  if (storageShelfId != null) {
    options[_storageShelfFilterKey] = storageShelfId;
  }
  if (options.isEmpty) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(options: options);
}

AppSearchBarFilterValue _drugCatalogFilterValue(PharmacyDrugQuery query) {
  final Map<String, String> options = Map<String, String>.from(
    _catalogStorageFilterValue(
      storageRoomId: query.storageRoomId,
      storageShelfId: query.storageShelfId,
    ).options,
  );
  if (query.stockStatus != null && query.stockStatus!.isNotEmpty) {
    options[_drugStockStatusFilterKey] = query.stockStatus!;
  }
  if (options.isEmpty) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(options: options);
}

AppSearchBarFilterValue _formularyCatalogFilterValue(
  PharmacyFormularyQuery query,
) {
  if (query.isActive == null) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(
    options: <String, String>{
      _formularyActiveFilterKey: query.isActive! ? 'true' : 'false',
    },
  );
}

AppSearchBarFilterValue _inventoryCatalogFilterValue(
  PharmacyInventoryStockQuery query,
) {
  final Map<String, String> options = Map<String, String>.from(
    _catalogStorageFilterValue(
      storageRoomId: query.storageRoomId,
      storageShelfId: query.storageShelfId,
    ).options,
  );

  final String? stockChoice;
  if (query.lowStockOnly) {
    stockChoice = 'LOW_STOCK';
  } else if (query.expiredOnly) {
    stockChoice = 'EXPIRED';
  } else if (query.expiringWithinDays != null) {
    stockChoice = 'EXPIRING_SOON';
  } else {
    stockChoice = null;
  }
  if (stockChoice != null) {
    options[_inventoryStockStatusFilterKey] = stockChoice;
  }

  if (options.isEmpty) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(options: options);
}

bool _hasDrugCatalogFilters(PharmacyDrugQuery query) {
  return query.storageRoomId != null ||
      query.storageShelfId != null ||
      (query.stockStatus != null && query.stockStatus!.isNotEmpty);
}

bool _hasFormularyCatalogFilters(PharmacyFormularyQuery query) {
  return query.isActive != null;
}

bool _hasInventoryCatalogFilters(PharmacyInventoryStockQuery query) {
  return query.storageRoomId != null ||
      query.storageShelfId != null ||
      query.lowStockOnly ||
      query.expiredOnly ||
      query.expiringWithinDays != null;
}

Future<void> _applyDrugCatalogFilter(
  PharmacyWorkspaceController controller,
  AppSearchBarFilterValue value,
) async {
  if (!value.isActive) {
    await controller.applyDrugCatalogFilters(clearAll: true);
    return;
  }

  await controller.applyDrugCatalogFilters(
    stockStatus: value.option(_drugStockStatusFilterKey),
    storageRoomId: value.option(_storageRoomFilterKey),
    storageShelfId: value.option(_storageShelfFilterKey),
  );
}

Future<void> _applyFormularyCatalogFilter(
  PharmacyWorkspaceController controller,
  AppSearchBarFilterValue value,
) async {
  if (!value.isActive) {
    await controller.clearFormularyFilters();
    return;
  }

  final String? activeChoice = value.option(_formularyActiveFilterKey);
  await controller.applyFormularyActiveFilter(
    isActive: switch (activeChoice) {
      'true' => true,
      'false' => false,
      _ => null,
    },
    clearIsActive: activeChoice == null,
  );
}

Future<void> _applyInventoryCatalogFilter(
  PharmacyWorkspaceController controller,
  AppSearchBarFilterValue value,
) async {
  if (!value.isActive) {
    await controller.applyInventoryCatalogFilters(clearAll: true);
    return;
  }

  await controller.applyInventoryCatalogFilters(
    stockStatusChoice: value.option(_inventoryStockStatusFilterKey),
    storageRoomId: value.option(_storageRoomFilterKey),
    storageShelfId: value.option(_storageShelfFilterKey),
  );
}

extension _CatalogAccessRequirement on AccessRequirement {
  bool allows(WidgetRef ref) {
    return isAllowed(ref.read(appAccessPolicyProvider));
  }
}
