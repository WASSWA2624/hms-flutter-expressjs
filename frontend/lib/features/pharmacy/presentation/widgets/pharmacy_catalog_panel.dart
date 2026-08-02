import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_access.dart';
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
const String _drugNameFilterKey = 'name';
const String _drugCodeFilterKey = 'code';
const String _drugFormFilterKey = 'form';
const String _drugStrengthFilterKey = 'strength';

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
        writeRequirement: pharmacyCatalogWriteRequirement,
        fillHeight: widget.fillHeight,
      ),
      PharmacyCatalogTab.formulary => _FormularyCatalogTab(
        state: state,
        writeRequirement: pharmacyCatalogWriteRequirement,
        fillHeight: widget.fillHeight,
      ),
      PharmacyCatalogTab.inventory => _InventoryCatalogTab(
        state: state,
        writeRequirement: pharmacyCatalogWriteRequirement,
        fillHeight: widget.fillHeight,
      ),
      PharmacyCatalogTab.storageLayout => _StorageLayoutCatalogTab(
        state: state,
        writeRequirement: pharmacyCatalogWriteRequirement,
        fillHeight: widget.fillHeight,
      ),
      PharmacyCatalogTab.shelves => _ShelvesCatalogTab(
        state: state,
        writeRequirement: pharmacyCatalogWriteRequirement,
        fillHeight: widget.fillHeight,
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
  const _DrugCatalogTab({
    required this.state,
    required this.writeRequirement,
    this.fillHeight = false,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;
  final bool fillHeight;

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
    final bool isBusy = widget.state.isRefreshingDrugs;
    final bool hasSelection = _selectedDrugIds.isNotEmpty;

    final Widget table = AppListTable<PharmacyDrug>(
      page: widget.state.drugs,
      isLoading: isBusy,
      columnVisibilityStorageKey: 'pharmacy_catalog_drugs',
      shrinkWrap: !widget.fillHeight,
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
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _drugNameFilterKey,
            label: l10n.pharmacyDrugGenericNameLabel,
            hintText: l10n.pharmacyDrugGenericNameLabel,
            icon: Icons.medication_outlined,
          ),
          AppSearchBarTextFilter(
            key: _drugCodeFilterKey,
            label: l10n.pharmacyDrugCodeLabel,
            icon: Icons.qr_code_2_outlined,
          ),
          AppSearchBarTextFilter(
            key: _drugFormFilterKey,
            label: l10n.pharmacyDrugFormLabel,
            icon: Icons.science_outlined,
          ),
          AppSearchBarTextFilter(
            key: _drugStrengthFilterKey,
            label: l10n.pharmacyDrugStrengthLabel,
            icon: Icons.straighten_outlined,
          ),
        ],
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
          isBusy: isBusy,
          hasSelection: hasSelection,
          addLabel: l10n.commonCreateActionLabel,
          addSemanticLabel: l10n.pharmacyAddDrugAction,
          onAdd: () => _openDrugDialog(context),
          selectionLabel: l10n.pharmacyDeleteSelectedDrugsAction,
          onSelectionAction: () => _confirmDeleteSelectedDrugs(context),
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
          isBusy: isBusy,
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
          id: 'brand_name',
          label: l10n.pharmacyDrugBrandNameLabel,
          cellBuilder: (_, PharmacyDrug item) =>
              Text((item.brandName ?? '').trim().isEmpty
                  ? '—'
                  : item.brandName!.trim()),
          exportValue: (PharmacyDrug item) => item.brandName ?? '',
        ),
        AppListTableColumn<PharmacyDrug>(
          id: 'generic_name',
          label: l10n.pharmacyDrugGenericNameLabel,
          cellBuilder: (_, PharmacyDrug item) {
            final String generic = (item.genericName ?? '').trim();
            if (generic.isNotEmpty) {
              return Text(generic);
            }
            // Legacy rows stored the scientific name in `name`.
            final String legacy = (item.name ?? '').trim();
            return Text(legacy.isEmpty ? '—' : legacy);
          },
          exportValue: (PharmacyDrug item) {
            final String generic = (item.genericName ?? '').trim();
            if (generic.isNotEmpty) {
              return generic;
            }
            return item.name ?? '';
          },
        ),
        AppListTableColumn<PharmacyDrug>(
          id: 'code',
          label: l10n.pharmacyDrugCodeLabel,
          cellBuilder: (_, PharmacyDrug item) => Text(item.code ?? ''),
        ),
        AppListTableColumn<PharmacyDrug>(
          id: 'form',
          label: l10n.pharmacyDrugFormLabel,
          cellBuilder: (_, PharmacyDrug item) =>
              Text((item.form ?? '').trim().isEmpty ? '—' : item.form!.trim()),
          exportValue: (PharmacyDrug item) => item.form ?? '',
        ),
        AppListTableColumn<PharmacyDrug>(
          id: 'strength',
          label: l10n.pharmacyDrugStrengthLabel,
          cellBuilder: (_, PharmacyDrug item) => Text(
            (item.strength ?? '').trim().isEmpty ? '—' : item.strength!.trim(),
          ),
          exportValue: (PharmacyDrug item) => item.strength ?? '',
        ),
        AppListTableColumn<PharmacyDrug>(
          id: 'pharmacy_price',
          label: l10n.pharmacyPharmacyPriceLabel,
          cellBuilder: (_, PharmacyDrug item) =>
              Text(_priceText(item.pharmacyUnitPrice ?? item.unitPrice)),
        ),
        AppListTableColumn<PharmacyDrug>(
          id: 'facility_price',
          label: l10n.pharmacyFacilityPriceLabel,
          cellBuilder: (_, PharmacyDrug item) =>
              Text(_priceText(item.facilityUnitPrice)),
        ),
        AppListTableColumn<PharmacyDrug>(
          id: 'storage_location',
          label: l10n.pharmacyStorageLocationColumnLabel,
          cellBuilder: (_, PharmacyDrug item) =>
              Text(item.storageLocationLabel ?? '—'),
        ),
        AppListTableColumn<PharmacyDrug>(
          id: 'reorder_level',
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
          id: 'stock_status',
          label: l10n.pharmacyStockStatusFilterLabel,
          cellBuilder: (BuildContext context, PharmacyDrug item) {
            return AppWorkspaceStatusBadge(
              status: _stockStatus(context, item.stockStatus),
            );
          },
        ),
        AppListTableColumn<PharmacyDrug>(
          id: 'actions',
          label: '',
          alwaysVisible: true,
          cellBuilder: (BuildContext context, PharmacyDrug item) {
            return _catalogRowActions(
              context: context,
              writeRequirement: widget.writeRequirement,
              isBusy: isBusy,
              editLabel: l10n.commonEditActionLabel,
              deleteLabel: l10n.commonDeleteActionLabel,
              editSemanticLabel: l10n.pharmacyEditDrugAction,
              deleteSemanticLabel: l10n.pharmacyDeleteDrugAction,
              onEdit: () => _openDrugDialog(context, drug: item),
              onDelete: () => _confirmDeleteDrug(context, item),
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, PharmacyDrug item) {
        return AppListTableMobileItem(
          leading: Checkbox(
            value: _selectedDrugIds.contains(item.id),
            onChanged: isBusy
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
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          title: item.displayTitle,
          caption: item.code,
          showAvatar: false,
        );
      },
    );

    return table;
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
    this.fillHeight = false,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;
  final bool fillHeight;

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
      if (!mounted) {
        return;
      }
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
    final bool hasSelection = _selectedFormularyIds.isNotEmpty;

    final Widget table = AppListTable<PharmacyFormularyItem>(
      page: widget.state.formularyItems,
      isLoading: isBusy,
      columnVisibilityStorageKey: 'pharmacy_catalog_formulary',
      shrinkWrap: !widget.fillHeight,
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
          hasSelection: hasSelection,
          addLabel: l10n.commonCreateActionLabel,
          addSemanticLabel: l10n.pharmacyAddFormularyAction,
          onAdd: () => _openFormularyDialog(context),
          selectionLabel: l10n.pharmacyDeleteSelectedFormularyAction,
          onSelectionAction: () => _confirmDeleteSelectedFormulary(context),
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
          id: 'drug_name',
          label: l10n.pharmacyDrugNameLabel,
          cellBuilder: (_, PharmacyFormularyItem item) =>
              Text(item.drugNameLabel ?? '—'),
        ),
        AppListTableColumn<PharmacyFormularyItem>(
          id: 'formulary_id',
          label: l10n.pharmacyFormularyIdLabel,
          cellBuilder: (_, PharmacyFormularyItem item) =>
              Text(item.displayId ?? item.id),
        ),
        AppListTableColumn<PharmacyFormularyItem>(
          id: 'is_active',
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
          id: 'actions',
          label: '',
          alwaysVisible: true,
          cellBuilder: (BuildContext context, PharmacyFormularyItem item) {
            return _catalogRowActions(
              context: context,
              writeRequirement: widget.writeRequirement,
              isBusy: isBusy,
              editLabel: l10n.commonEditActionLabel,
              deleteLabel: l10n.commonDeleteActionLabel,
              editSemanticLabel: l10n.pharmacyEditFormularyAction,
              deleteSemanticLabel: l10n.pharmacyDeleteFormularyAction,
              onEdit: () => _openFormularyDialog(context, item: item),
              onDelete: () => _confirmDeleteFormulary(context, item),
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, PharmacyFormularyItem item) {
        return AppListTableMobileItem(
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
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          title: item.drugNameLabel ?? item.displayId ?? item.id,
          caption: item.drugCode,
          showAvatar: false,
        );
      },
    );

    return table;
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
        if (!mounted) {
          return;
        }
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
                return GestureDetector(
                  onTap: _isSaving
                      ? null
                      : () => setState(() => _drugId = drug.id),
                  child: AppListTableMobileItem(
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: drug.displayTitle,
                    caption: drug.code,
                    showAvatar: false,
                  ),
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
    this.fillHeight = false,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;
  final bool fillHeight;

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
      if (!mounted) {
        return;
      }
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
    final bool hasSelection = _selectedInventoryIds.isNotEmpty;

    return AppListTable<PharmacyInventoryStock>(
      page: widget.state.inventoryWorkbench.stocks,
      isLoading: isBusy,
      columnVisibilityStorageKey: 'pharmacy_catalog_inventory',
      shrinkWrap: !widget.fillHeight,
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
        trailingActions: _catalogSearchTrailingActions(
          ref: ref,
          writeRequirement: widget.writeRequirement,
          isBusy: isBusy,
          hasSelection: hasSelection,
          selectionLabel: l10n.pharmacyClearSelectedInventoryAction,
          onSelectionAction: () => _confirmClearSelectedInventory(context),
        ),
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
          id: 'item',
          label: l10n.pharmacyInventoryItemLabel,
          cellBuilder: (_, PharmacyInventoryStock item) {
            return Text(
              item.inventoryItem?.displayTitle ?? item.displayId ?? '',
            );
          },
        ),
        AppListTableColumn<PharmacyInventoryStock>(
          id: 'quantity',
          label: l10n.pharmacyInventoryQuantityColumnLabel,
          numeric: true,
          cellBuilder: (_, PharmacyInventoryStock item) =>
              Text(item.quantity.toString()),
        ),
        AppListTableColumn<PharmacyInventoryStock>(
          id: 'reorder_level',
          label: l10n.pharmacyReorderLevelColumnLabel,
          numeric: true,
          cellBuilder: (_, PharmacyInventoryStock item) =>
              Text(item.reorderLevel.toString()),
        ),
        AppListTableColumn<PharmacyInventoryStock>(
          id: 'storage_location',
          label: l10n.pharmacyStorageLocationColumnLabel,
          cellBuilder: (_, PharmacyInventoryStock item) =>
              Text(item.storageLocationLabel ?? '—'),
        ),
        AppListTableColumn<PharmacyInventoryStock>(
          id: 'next_expiry',
          label: l10n.pharmacyNextExpiryColumnLabel,
          cellBuilder: (BuildContext context, PharmacyInventoryStock item) {
            return _expiryCell(context, item);
          },
        ),
        AppListTableColumn<PharmacyInventoryStock>(
          id: 'batch_count',
          label: l10n.pharmacyBatchCountColumnLabel,
          numeric: true,
          cellBuilder: (_, PharmacyInventoryStock item) =>
              Text(item.batchCount.toString()),
        ),
        AppListTableColumn<PharmacyInventoryStock>(
          id: 'stock_status',
          label: l10n.pharmacyStockStatusFilterLabel,
          cellBuilder: (BuildContext context, PharmacyInventoryStock item) {
            return AppWorkspaceStatusBadge(
              status: _stockStatus(context, item.stockStatus),
            );
          },
        ),
        AppListTableColumn<PharmacyInventoryStock>(
          id: 'actions',
          label: '',
          alwaysVisible: true,
          cellBuilder: (BuildContext context, PharmacyInventoryStock item) {
            return _catalogRowActions(
              context: context,
              writeRequirement: widget.writeRequirement,
              isBusy: isBusy,
              editLabel: l10n.commonAdjustActionLabel,
              deleteLabel: l10n.commonClearActionLabel,
              editSemanticLabel: l10n.pharmacyAdjustStockAction,
              deleteSemanticLabel: l10n.pharmacyDeleteInventoryStockAction,
              editIcon: Icons.tune,
              onEdit: () => _openAdjustDialog(context, item),
              onDelete: () => _confirmClearInventoryStock(context, item),
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, PharmacyInventoryStock item) {
        final String selectionKey = _inventorySelectionKey(item);
        final String? expiryLabel = item.nextExpiry == null
            ? null
            : () {
                final String formatted = AppFormatters.dateTime(
                  item.nextExpiry!,
                  Localizations.localeOf(context),
                );
                if (item.expiryAlertStatus == 'EXPIRED') {
                  return '$formatted · ${l10n.pharmacyStockExpiredLabel}';
                }
                if (item.expiryAlertStatus == 'EXPIRING_SOON') {
                  return '$formatted · ${l10n.pharmacyStockExpiringSoonLabel}';
                }
                return formatted;
              }();
        return AppListTableMobileItem(
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
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          title: item.inventoryItem?.displayTitle ?? '',
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: '${item.quantity} · ${l10n.pharmacyReorderLevelColumnLabel}: ${item.reorderLevel}',
            ),
            if (expiryLabel != null)
              AppListTableMobileMeta(
                label: expiryLabel,
                icon: AppActionIcons.calendar,
              ),
          ],
          showAvatar: false,
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

/// Storage layout tab: renders storage rooms as a table with per-room Add
/// shelf / Edit / Delete actions. Reuses the shared storage dialogs and
/// controller CRUD so behavior matches the legacy expansion panel.
class _StorageLayoutCatalogTab extends ConsumerStatefulWidget {
  const _StorageLayoutCatalogTab({
    required this.state,
    required this.writeRequirement,
    this.fillHeight = false,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;
  final bool fillHeight;

  @override
  ConsumerState<_StorageLayoutCatalogTab> createState() =>
      _StorageLayoutCatalogTabState();
}

class _StorageLayoutCatalogTabState
    extends ConsumerState<_StorageLayoutCatalogTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<PharmacyStorageRoom> rooms = widget.state.storageLayout.rooms;
    final AppPage<PharmacyStorageRoom> page = AppPage<PharmacyStorageRoom>(
      items: rooms,
      request: AppPageRequest(pageSize: rooms.isEmpty ? 10 : rooms.length),
    );
    final bool isBusy = widget.state.isRefreshingStorage;

    return AppListTable<PharmacyStorageRoom>(
      page: page,
      isLoading: isBusy,
      shrinkWrap: !widget.fillHeight,
      physics: widget.fillHeight ? null : const NeverScrollableScrollPhysics(),
      columnVisibilityStorageKey: 'pharmacy_catalog_storage_rooms',
      search: AppListTableSearch<PharmacyStorageRoom>(
        controller: _searchController,
        semanticLabel: l10n.pharmacySearchLabel,
        hintText: l10n.pharmacySearchHint,
        matcher: (PharmacyStorageRoom item, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          return (item.name ?? '').toLowerCase().contains(needle) ||
              (item.code ?? '').toLowerCase().contains(needle) ||
              item.id.toLowerCase().contains(needle);
        },
        enableDateFilter: false,
        trailingActions: _catalogSearchTrailingActions(
          ref: ref,
          writeRequirement: widget.writeRequirement,
          isBusy: isBusy,
          hasSelection: false,
          addLabel: l10n.commonCreateActionLabel,
          addSemanticLabel: l10n.pharmacyAddStorageRoomAction,
          onAdd: () => openPharmacyStorageRoomDialog(context, ref),
        ),
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.pharmacyNoStorageRoomsTitle,
        body: l10n.pharmacyNoStorageRoomsBody,
        icon: Icons.warehouse_outlined,
      ),
      columns: <AppListTableColumn<PharmacyStorageRoom>>[
        AppListTableColumn<PharmacyStorageRoom>(
          id: 'name',
          label: l10n.pharmacyStorageRoomNameLabel,
          cellBuilder: (_, PharmacyStorageRoom item) =>
              Text(item.name ?? item.id),
        ),
        AppListTableColumn<PharmacyStorageRoom>(
          id: 'code',
          label: l10n.pharmacyStorageRoomCodeLabel,
          cellBuilder: (_, PharmacyStorageRoom item) =>
              Text((item.code ?? '').isEmpty ? '—' : item.code!),
        ),
        AppListTableColumn<PharmacyStorageRoom>(
          id: 'shelves_count',
          label: l10n.pharmacyStorageShelvesCountColumnLabel,
          numeric: true,
          cellBuilder: (_, PharmacyStorageRoom item) =>
              Text(item.shelves.length.toString()),
        ),
        AppListTableColumn<PharmacyStorageRoom>(
          id: 'status',
          label: l10n.pharmacyStorageStatusColumnLabel,
          cellBuilder: (BuildContext context, PharmacyStorageRoom item) {
            return AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: item.isActive
                    ? l10n.pharmacyStorageActiveLabel
                    : l10n.pharmacyStorageInactiveLabel,
                tone: item.isActive
                    ? AppWorkspaceStatusTone.success
                    : AppWorkspaceStatusTone.neutral,
              ),
            );
          },
        ),
        AppListTableColumn<PharmacyStorageRoom>(
          id: 'actions',
          label: '',
          alwaysVisible: true,
          // Create + Edit + Delete with labels exceed the default 200px actions
          // column and overflow the cell without an explicit width.
          fixedWidth: 280,
          cellBuilder: (BuildContext context, PharmacyStorageRoom item) {
            return _catalogRowActions(
              context: context,
              writeRequirement: widget.writeRequirement,
              isBusy: isBusy,
              editLabel: l10n.commonEditActionLabel,
              deleteLabel: l10n.commonDeleteActionLabel,
              editSemanticLabel: l10n.pharmacyEditStorageRoomAction,
              deleteSemanticLabel: l10n.pharmacyDeleteStorageRoomAction,
              onEdit: () => openPharmacyStorageRoomDialog(
                context,
                ref,
                room: item,
              ),
              onDelete: () => confirmDeletePharmacyStorageRoom(
                context,
                ref,
                item,
              ),
              addLabel: l10n.commonCreateActionLabel,
              addSemanticLabel: l10n.pharmacyAddStorageShelfAction,
              addEnabled: item.isActive,
              onAdd: () => openPharmacyStorageShelfDialog(
                context,
                ref,
                room: item,
              ),
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, PharmacyStorageRoom item) {
        return AppListTableMobileItem(
          title: item.name ?? item.id,
          caption: item.code,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label:
                  '${item.shelves.length} · ${l10n.pharmacyStorageShelvesCountColumnLabel}',
              icon: Icons.view_week_outlined,
            ),
            AppListTableMobileMeta(
              label: item.isActive
                  ? l10n.pharmacyStorageActiveLabel
                  : l10n.pharmacyStorageInactiveLabel,
            ),
          ],
          showAvatar: false,
        );
      },
    );
  }
}

/// Shelves tab: flattens shelves across all rooms into a single table with
/// Add / Edit / Delete actions. Adding a shelf prompts for the parent room.
class _ShelvesCatalogTab extends ConsumerStatefulWidget {
  const _ShelvesCatalogTab({
    required this.state,
    required this.writeRequirement,
    this.fillHeight = false,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;
  final bool fillHeight;

  @override
  ConsumerState<_ShelvesCatalogTab> createState() => _ShelvesCatalogTabState();
}

class _ShelvesCatalogTabState extends ConsumerState<_ShelvesCatalogTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<PharmacyStorageRoom> rooms = widget.state.storageLayout.rooms;
    final List<_ShelfRow> shelfRows = <_ShelfRow>[
      for (final PharmacyStorageRoom room in rooms)
        for (final PharmacyStorageShelf shelf in room.shelves)
          _ShelfRow(room: room, shelf: shelf),
    ];
    final AppPage<_ShelfRow> page = AppPage<_ShelfRow>(
      items: shelfRows,
      request: AppPageRequest(
        pageSize: shelfRows.isEmpty ? 10 : shelfRows.length,
      ),
    );
    final bool isBusy = widget.state.isRefreshingStorage;
    final List<PharmacyStorageRoom> activeRooms = _activeStorageRooms(
      widget.state.storageLayout,
    );

    return AppListTable<_ShelfRow>(
      page: page,
      isLoading: isBusy,
      shrinkWrap: !widget.fillHeight,
      physics: widget.fillHeight ? null : const NeverScrollableScrollPhysics(),
      columnVisibilityStorageKey: 'pharmacy_catalog_shelves',
      search: AppListTableSearch<_ShelfRow>(
        controller: _searchController,
        semanticLabel: l10n.pharmacySearchLabel,
        hintText: l10n.pharmacySearchHint,
        matcher: (_ShelfRow row, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          return row.shelf.displayLabel.toLowerCase().contains(needle) ||
              (row.shelf.shelfCode ?? '').toLowerCase().contains(needle) ||
              (row.shelf.label ?? '').toLowerCase().contains(needle) ||
              (row.room.name ?? '').toLowerCase().contains(needle);
        },
        enableDateFilter: false,
        trailingActions: _catalogSearchTrailingActions(
          ref: ref,
          writeRequirement: widget.writeRequirement,
          isBusy: isBusy,
          hasSelection: false,
          addLabel: l10n.commonCreateActionLabel,
          addSemanticLabel: l10n.pharmacyAddStorageShelfAction,
          onAdd: activeRooms.isEmpty
              ? null
              : () => _promptAddShelf(context, ref, activeRooms),
        ),
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.pharmacyNoStorageShelvesTitle,
        body: l10n.pharmacyNoStorageShelvesBody,
        icon: Icons.view_week_outlined,
      ),
      columns: <AppListTableColumn<_ShelfRow>>[
        AppListTableColumn<_ShelfRow>(
          id: 'shelf_code',
          label: l10n.pharmacyStorageShelfCodeLabel,
          cellBuilder: (_, _ShelfRow row) =>
              Text(row.shelf.shelfCode ?? row.shelf.displayLabel),
        ),
        AppListTableColumn<_ShelfRow>(
          id: 'label',
          label: l10n.pharmacyStorageShelfLabelField,
          cellBuilder: (_, _ShelfRow row) {
            final String label = (row.shelf.label ?? '').trim();
            return Text(label.isEmpty ? '—' : label);
          },
        ),
        AppListTableColumn<_ShelfRow>(
          id: 'room',
          label: l10n.pharmacyStorageRoomLabel,
          cellBuilder: (_, _ShelfRow row) => Text(row.room.name ?? row.room.id),
        ),
        AppListTableColumn<_ShelfRow>(
          id: 'status',
          label: l10n.pharmacyStorageStatusColumnLabel,
          cellBuilder: (BuildContext context, _ShelfRow row) {
            return AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: row.shelf.isActive
                    ? l10n.pharmacyStorageActiveLabel
                    : l10n.pharmacyStorageInactiveLabel,
                tone: row.shelf.isActive
                    ? AppWorkspaceStatusTone.success
                    : AppWorkspaceStatusTone.neutral,
              ),
            );
          },
        ),
        AppListTableColumn<_ShelfRow>(
          id: 'actions',
          label: '',
          alwaysVisible: true,
          cellBuilder: (BuildContext context, _ShelfRow row) {
            return _catalogRowActions(
              context: context,
              writeRequirement: widget.writeRequirement,
              isBusy: isBusy,
              editLabel: l10n.commonEditActionLabel,
              deleteLabel: l10n.commonDeleteActionLabel,
              editSemanticLabel: l10n.pharmacyEditStorageShelfAction,
              deleteSemanticLabel: l10n.pharmacyDeleteStorageShelfAction,
              onEdit: () => openPharmacyStorageShelfDialog(
                context,
                ref,
                room: row.room,
                shelf: row.shelf,
              ),
              onDelete: () =>
                  confirmDeletePharmacyStorageShelf(context, ref, row.shelf),
            );
          },
        ),
      ],
      mobileItemBuilder: (BuildContext context, _ShelfRow row) {
        return AppListTableMobileItem(
          title: row.shelf.displayLabel,
          caption: row.room.name,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: row.shelf.isActive
                  ? l10n.pharmacyStorageActiveLabel
                  : l10n.pharmacyStorageInactiveLabel,
            ),
          ],
          showAvatar: false,
        );
      },
    );
  }

  Future<void> _promptAddShelf(
    BuildContext context,
    WidgetRef ref,
    List<PharmacyStorageRoom> activeRooms,
  ) async {
    final AppLocalizations l10n = context.l10n;
    PharmacyStorageRoom? selectedRoom = activeRooms.length == 1
        ? activeRooms.first
        : null;
    if (activeRooms.length > 1) {
      selectedRoom = await showAppDialog<PharmacyStorageRoom>(
        context: context,
        builder: (BuildContext dialogContext) {
          PharmacyStorageRoom? choice = activeRooms.first;
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return AppDialog(
                title: Text(l10n.pharmacyAddStorageShelfAction),
                icon: const Icon(Icons.view_week_outlined),
                content: AppSelectField<String>(
                  value: choice?.id,
                  labelText: l10n.pharmacyStorageRoomLabel,
                  options: activeRooms
                      .map(
                        (PharmacyStorageRoom room) => AppSelectOption<String>(
                          value: room.id,
                          label: room.name ?? room.id,
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) => setDialogState(() {
                    choice = activeRooms.firstWhere(
                      (PharmacyStorageRoom room) => room.id == value,
                      orElse: () => activeRooms.first,
                    );
                  }),
                ),
                actions: <Widget>[
                  AppButton.tertiary(
                    label: l10n.commonCancelActionLabel,
                    leadingIcon: Icons.close,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                  AppButton.primary(
                    label: l10n.commonNextActionLabel,
                    leadingIcon: Icons.arrow_forward,
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(choice),
                  ),
                ],
              );
            },
          );
        },
      );
    }
    if (selectedRoom == null || !context.mounted) {
      return;
    }
    await openPharmacyStorageShelfDialog(context, ref, room: selectedRoom);
  }
}

@immutable
class _ShelfRow {
  const _ShelfRow({required this.room, required this.shelf});

  final PharmacyStorageRoom room;
  final PharmacyStorageShelf shelf;
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
    fixedWidth: 48,
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
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    },
    cellBuilder: (BuildContext context, T item) {
      return Checkbox(
        value: selectedKeys.contains(itemKey(item)),
        onChanged: isBusy
            ? null
            : (bool? value) => onToggle(item, value ?? false),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
  String? editSemanticLabel,
  String? deleteSemanticLabel,
  IconData editIcon = Icons.edit_outlined,
  IconData deleteIcon = Icons.delete_outline,
  String? addLabel,
  String? addSemanticLabel,
  VoidCallback? onAdd,
  bool addEnabled = true,
  IconData addIcon = Icons.add,
}) {
  final ThemeData theme = Theme.of(context);
  final ColorScheme colorScheme = theme.colorScheme;
  final String editSemantic = editSemanticLabel ?? editLabel;
  final String deleteSemantic = deleteSemanticLabel ?? deleteLabel;
  final String? addSemantic = addSemanticLabel ?? addLabel;
  return AppAccessActionGate(
    requirement: writeRequirement,
    builder: (BuildContext context, bool isAllowed) => Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (onAdd != null && addLabel != null) ...<Widget>[
              AppButton.tertiary(
                dense: true,
                leadingIcon: addIcon,
                label: addLabel,
                semanticLabel: addSemantic,
                tooltip: addSemantic,
                enabled: isAllowed && !isBusy && addEnabled,
                onPressed: isAllowed && !isBusy && addEnabled ? onAdd : null,
              ),
              SizedBox(width: theme.spacing.xs),
            ],
            AppButton.tertiary(
              dense: true,
              leadingIcon: editIcon,
              label: editLabel,
              semanticLabel: editSemantic,
              tooltip: editSemantic,
              enabled: isAllowed && !isBusy,
              onPressed: isAllowed && !isBusy ? onEdit : null,
            ),
            SizedBox(width: theme.spacing.xs),
            AppButton.tertiary(
              dense: true,
              leadingIcon: deleteIcon,
              label: deleteLabel,
              semanticLabel: deleteSemantic,
              tooltip: deleteSemantic,
              color: colorScheme.error,
              enabled: isAllowed && !isBusy,
              onPressed: isAllowed && !isBusy ? onDelete : null,
            ),
          ],
        ),
      ),
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

/// Builds search-bar trailing actions (after Filters → Settings → Export).
/// Selection bulk actions and Add are mutually exclusive.
List<AppSearchBarAction> _catalogSearchTrailingActions({
  required WidgetRef ref,
  required AccessRequirement writeRequirement,
  required bool isBusy,
  required bool hasSelection,
  String? addLabel,
  String? addSemanticLabel,
  VoidCallback? onAdd,
  String? selectionLabel,
  VoidCallback? onSelectionAction,
}) {
  if (!writeRequirement.allows(ref)) {
    return const <AppSearchBarAction>[];
  }

  if (hasSelection &&
      selectionLabel != null &&
      onSelectionAction != null) {
    return <AppSearchBarAction>[
      AppSearchBarAction(
        icon: Icons.delete_outline,
        label: selectionLabel,
        tooltip: selectionLabel,
        enabled: !isBusy,
        destructive: true,
        onPressed: isBusy ? null : onSelectionAction,
      ),
    ];
  }

  if (!hasSelection && addLabel != null && onAdd != null) {
    return <AppSearchBarAction>[
      AppSearchBarAction(
        icon: Icons.add,
        label: addLabel,
        tooltip: addSemanticLabel ?? addLabel,
        enabled: !isBusy,
        onPressed: isBusy ? null : onAdd,
      ),
    ];
  }

  return const <AppSearchBarAction>[];
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
  final Map<String, String> texts = <String, String>{
    if ((query.name ?? '').trim().isNotEmpty) _drugNameFilterKey: query.name!,
    if ((query.code ?? '').trim().isNotEmpty) _drugCodeFilterKey: query.code!,
    if ((query.form ?? '').trim().isNotEmpty) _drugFormFilterKey: query.form!,
    if ((query.strength ?? '').trim().isNotEmpty)
      _drugStrengthFilterKey: query.strength!,
  };
  if (options.isEmpty && texts.isEmpty) {
    return AppSearchBarFilterValue.empty;
  }
  return AppSearchBarFilterValue(options: options, texts: texts);
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
      (query.stockStatus != null && query.stockStatus!.isNotEmpty) ||
      (query.name ?? '').trim().isNotEmpty ||
      (query.code ?? '').trim().isNotEmpty ||
      (query.form ?? '').trim().isNotEmpty ||
      (query.strength ?? '').trim().isNotEmpty;
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
    name: value.text(_drugNameFilterKey),
    code: value.text(_drugCodeFilterKey),
    form: value.text(_drugFormFilterKey),
    strength: value.text(_drugStrengthFilterKey),
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
