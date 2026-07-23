import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/facility_catalog/facility_catalog_scope.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_dialogs.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/radiology_catalog/radiology_catalog_dialogs.dart';

enum _CatalogDeskTab { lab, diagnostics, budget }

enum _BudgetSource { lab, diagnostics }

/// Facility clinical service catalog management for the setup Catalog desk tab.
class FacilityCatalogConfigPanel extends ConsumerStatefulWidget {
  const FacilityCatalogConfigPanel({
    required this.facilityId,
    required this.tenantId,
    this.defaultCurrency = appDefaultCurrencyCode,
    this.enabled = true,
    super.key,
  });

  final String facilityId;
  final String tenantId;
  final String defaultCurrency;
  final bool enabled;

  @override
  ConsumerState<FacilityCatalogConfigPanel> createState() =>
      _FacilityCatalogConfigPanelState();
}

class _FacilityCatalogConfigPanelState
    extends ConsumerState<FacilityCatalogConfigPanel> {
  static const int _searchLimit = 200;
  static const String _labTypeFilterKey = 'type';
  static const String _labCategoryFilterKey = 'category';
  static const String _modalityFilterKey = 'modality';
  static const String _budgetSourceFilterKey = 'source';

  final TextEditingController _labSearchController = TextEditingController();
  final TextEditingController _diagnosticsSearchController =
      TextEditingController();
  final TextEditingController _budgetSearchController = TextEditingController();

  _CatalogDeskTab _tab = _CatalogDeskTab.lab;
  List<LabCatalogItem> _labOfferings = const <LabCatalogItem>[];
  List<RadiologyCatalogTest> _radiologyOfferings =
      const <RadiologyCatalogTest>[];
  AppSearchBarFilterValue _labFilterValue = AppSearchBarFilterValue.empty;
  AppSearchBarFilterValue _diagnosticsFilterValue =
      AppSearchBarFilterValue.empty;
  AppSearchBarFilterValue _budgetFilterValue = AppSearchBarFilterValue.empty;
  bool _isLoading = false;
  AppFailure? _failure;

  FacilityCatalogScope get _scope => FacilityCatalogScope(
    tenantId: widget.tenantId,
    facilityId: widget.facilityId,
  );

  String get _resolvedCurrency =>
      resolveFacilityDefaultCurrency(widget.defaultCurrency);

  List<LabCatalogItem> get _filteredLabOfferings {
    final String? type = _labFilterValue.option(_labTypeFilterKey);
    final String? category = _labFilterValue.option(_labCategoryFilterKey);
    return _labOfferings.where((LabCatalogItem item) {
      if (type != null && type.isNotEmpty && item.type.name != type) {
        return false;
      }
      if (category != null && category.isNotEmpty) {
        final String itemCategory = (item.category ?? '').trim();
        if (itemCategory != category) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  List<RadiologyCatalogTest> get _filteredRadiologyOfferings {
    final String? modality = _diagnosticsFilterValue.option(_modalityFilterKey);
    if (modality == null || modality.isEmpty) {
      return _radiologyOfferings;
    }
    return _radiologyOfferings
        .where(
          (RadiologyCatalogTest item) =>
              (item.modality ?? '').trim() == modality,
        )
        .toList(growable: false);
  }

  List<_BudgetOffering> _budgetOfferings(AppLocalizations l10n) {
    final List<_BudgetOffering> items = <_BudgetOffering>[
      for (final LabCatalogItem item in _labOfferings)
        _BudgetOffering.fromLab(item, l10n.tenantFacilityCatalogTabLab),
      for (final RadiologyCatalogTest item in _radiologyOfferings)
        _BudgetOffering.fromRadiology(
          item,
          l10n.tenantFacilityCatalogTabDiagnostics,
        ),
    ];
    items.sort(
      (_BudgetOffering a, _BudgetOffering b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return items;
  }

  List<_BudgetOffering> _filteredBudgetOfferings(AppLocalizations l10n) {
    final String? source = _budgetFilterValue.option(_budgetSourceFilterKey);
    final List<_BudgetOffering> offerings = _budgetOfferings(l10n);
    if (source == null || source.isEmpty) {
      return offerings;
    }
    return offerings
        .where((_BudgetOffering item) => item.source.name == source)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_reloadCurrentTab());
      }
    });
  }

  @override
  void didUpdateWidget(covariant FacilityCatalogConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facilityId != widget.facilityId ||
        oldWidget.tenantId != widget.tenantId) {
      unawaited(_reloadCurrentTab());
    }
  }

  @override
  void dispose() {
    _labSearchController.dispose();
    _diagnosticsSearchController.dispose();
    _budgetSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTabStrip(
          tabs: <AppTabItem>[
            AppTabItem(
              id: _CatalogDeskTab.lab.name,
              icon: Icons.biotech_outlined,
              label: l10n.tenantFacilityCatalogTabLab,
            ),
            AppTabItem(
              id: _CatalogDeskTab.diagnostics.name,
              icon: Icons.image_search_outlined,
              label: l10n.tenantFacilityCatalogTabDiagnostics,
            ),
            AppTabItem(
              id: _CatalogDeskTab.budget.name,
              icon: Icons.payments_outlined,
              label: l10n.tenantFacilityCatalogTabBudget,
            ),
          ],
          selectedId: _tab.name,
          onTabTapped: (String id) {
            final _CatalogDeskTab? next = _CatalogDeskTab.values
                .where((_CatalogDeskTab value) => value.name == id)
                .firstOrNull;
            if (next == null || next == _tab) {
              return;
            }
            setState(() {
              _tab = next;
              _failure = null;
            });
            unawaited(_reloadCurrentTab());
          },
        ),
        SizedBox(height: theme.spacing.sm),
        if (_failure != null)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          ),
        Expanded(child: _buildTableBody(l10n)),
      ],
    );
  }

  Widget _buildTableBody(AppLocalizations l10n) {
    return switch (_tab) {
      _CatalogDeskTab.lab => _buildLabTable(l10n),
      _CatalogDeskTab.diagnostics => _buildDiagnosticsTable(l10n),
      _CatalogDeskTab.budget => _buildBudgetTable(l10n),
    };
  }

  Widget _buildLabTable(AppLocalizations l10n) {
    final List<String> categories = _labOfferings
        .map((LabCatalogItem item) => (item.category ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    return AppListTable<LabCatalogItem>(
      items: _filteredLabOfferings,
      isLoading: _isLoading,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'setup_catalog_lab',
      onRowSelected: widget.enabled
          ? (LabCatalogItem item) => unawaited(_openLabEditDialog(item))
          : null,
      search: AppListTableSearch<LabCatalogItem>(
        controller: _labSearchController,
        semanticLabel: l10n.clinicalLabRequestSearchLabel,
        hintText: l10n.clinicalLabRequestSearchHint,
        matcher: (LabCatalogItem item, String query) =>
            item.matchesSearch(query),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFilterActionLabel,
        advancedFilterTitle: l10n.labFiltersLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        enableDateFilter: false,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _labTypeFilterKey,
            label: l10n.clinicalRequestSelectedTypeColumnLabel,
            allLabel: l10n.commonAllLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: LabCatalogItemType.test.name,
                label: l10n.clinicalLabRequestTestTypeLabel,
              ),
              AppSearchBarFilterChoice(
                value: LabCatalogItemType.panel.name,
                label: l10n.clinicalLabRequestPanelTypeLabel,
              ),
            ],
          ),
          if (categories.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _labCategoryFilterKey,
              label: l10n.labCategoryLabel,
              allLabel: l10n.commonAllLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final String category in categories)
                  AppSearchBarFilterChoice(value: category, label: category),
              ],
            ),
        ],
        filterValue: _labFilterValue,
        hasActiveFilters: _labFilterValue.isActive,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() => _labFilterValue = value);
        },
        trailingActions: <AppSearchBarAction>[
          if (widget.enabled) ...<AppSearchBarAction>[
            AppSearchBarAction(
              icon: Icons.add_circle_outline,
              label: l10n.labEnableTestAction,
              onPressed: () => unawaited(
                _openLabEnableDialog(LabEnableOfferingKind.test),
              ),
            ),
            AppSearchBarAction(
              icon: Icons.add_box_outlined,
              label: l10n.labEnablePanelAction,
              onPressed: () => unawaited(
                _openLabEnableDialog(LabEnableOfferingKind.panel),
              ),
            ),
          ],
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilityCatalogTabLab,
        body: l10n.tenantFacilityCatalogEmptyOfferings,
        action: widget.enabled
            ? AppButton.primary(
                label: l10n.labEnableTestAction,
                leadingIcon: Icons.add_circle_outline,
                onPressed: () => unawaited(
                  _openLabEnableDialog(LabEnableOfferingKind.test),
                ),
              )
            : null,
      ),
      columns: <AppListTableColumn<LabCatalogItem>>[
        AppListTableColumn<LabCatalogItem>(
          id: 'name',
          label: l10n.accessAdminColumnName,
          sortComparator: (LabCatalogItem a, LabCatalogItem b) => a.displayTitle
              .toLowerCase()
              .compareTo(b.displayTitle.toLowerCase()),
          cellBuilder: (_, LabCatalogItem item) => Text(item.displayTitle),
        ),
        AppListTableColumn<LabCatalogItem>(
          id: 'type',
          label: l10n.clinicalRequestSelectedTypeColumnLabel,
          cellBuilder: (_, LabCatalogItem item) => Text(
            item.type == LabCatalogItemType.panel
                ? l10n.clinicalLabRequestPanelTypeLabel
                : l10n.clinicalLabRequestTestTypeLabel,
          ),
        ),
        AppListTableColumn<LabCatalogItem>(
          id: 'code',
          label: l10n.labTestCodeLabel,
          cellBuilder: (_, LabCatalogItem item) =>
              Text(item.code?.trim().isNotEmpty == true ? item.code! : '—'),
        ),
        AppListTableColumn<LabCatalogItem>(
          id: 'category',
          label: l10n.labCategoryLabel,
          cellBuilder: (_, LabCatalogItem item) => Text(
            item.category?.trim().isNotEmpty == true ? item.category! : '—',
          ),
        ),
        AppListTableColumn<LabCatalogItem>(
          id: 'price',
          label: l10n.clinicalRequestUnitPriceLabel,
          cellBuilder: (_, LabCatalogItem item) =>
              Text(_formatPrice(item.unitPrice, item.currency)),
        ),
        if (widget.enabled)
          AppListTableColumn<LabCatalogItem>(
            id: 'actions',
            label: l10n.accessAdminColumnActions,
            alwaysVisible: true,
            cellBuilder: (BuildContext context, LabCatalogItem item) {
              return _CatalogRowActions(
                editLabel: l10n.clinicalLabRequestEditSelectionAction,
                deleteLabel: l10n.tenantFacilityDeleteAction,
                onEdit: () => unawaited(_openLabEditDialog(item)),
                onDelete: () => unawaited(_openLabDeleteDialog(item)),
              );
            },
          ),
      ],
      mobileItemBuilder: (BuildContext context, LabCatalogItem item) {
        return AppListTableMobileItem(
          title: item.displayTitle,
          caption: item.category,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: item.type == LabCatalogItemType.panel
                  ? l10n.clinicalLabRequestPanelTypeLabel
                  : l10n.clinicalLabRequestTestTypeLabel,
            ),
            if (item.code?.trim().isNotEmpty == true)
              AppListTableMobileMeta(label: item.code!),
          ],
        );
      },
    );
  }

  Widget _buildDiagnosticsTable(AppLocalizations l10n) {
    final List<String> modalities = _radiologyOfferings
        .map((RadiologyCatalogTest item) => (item.modality ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    return AppListTable<RadiologyCatalogTest>(
      items: _filteredRadiologyOfferings,
      isLoading: _isLoading,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'setup_catalog_diagnostics',
      onRowSelected: widget.enabled
          ? (RadiologyCatalogTest item) =>
                unawaited(_openRadiologyEditDialog(item))
          : null,
      search: AppListTableSearch<RadiologyCatalogTest>(
        controller: _diagnosticsSearchController,
        semanticLabel: l10n.clinicalRadiologyCatalogSelectTitle,
        hintText: l10n.tenantFacilityCatalogSearchHint,
        matcher: (RadiologyCatalogTest item, String query) {
          final String haystack =
              '${item.name} ${item.code ?? ''} ${item.modality ?? ''} '
                      '${item.bodyRegion ?? ''} ${item.searchText ?? ''}'
                  .toLowerCase();
          return haystack.contains(query.toLowerCase());
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFilterActionLabel,
        advancedFilterTitle: l10n.commonFilterActionLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        enableDateFilter: false,
        filterGroups: <AppSearchBarFilterGroup>[
          if (modalities.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _modalityFilterKey,
              label: l10n.radiologyModalityLabel,
              allLabel: l10n.commonAllLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final String modality in modalities)
                  AppSearchBarFilterChoice(value: modality, label: modality),
              ],
            ),
        ],
        filterValue: _diagnosticsFilterValue,
        hasActiveFilters: _diagnosticsFilterValue.isActive,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() => _diagnosticsFilterValue = value);
        },
        trailingActions: <AppSearchBarAction>[
          if (widget.enabled)
            AppSearchBarAction(
              icon: Icons.add_circle_outline,
              label: l10n.clinicalRadiologyCatalogSelectTitle,
              onPressed: () => unawaited(_openRadiologyEnableDialog()),
            ),
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilityCatalogTabDiagnostics,
        body: l10n.tenantFacilityCatalogEmptyOfferings,
        action: widget.enabled
            ? AppButton.primary(
                label: l10n.clinicalRadiologyCatalogSelectTitle,
                leadingIcon: Icons.add_circle_outline,
                onPressed: () => unawaited(_openRadiologyEnableDialog()),
              )
            : null,
      ),
      columns: <AppListTableColumn<RadiologyCatalogTest>>[
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'name',
          label: l10n.radiologyTestNameLabel,
          sortComparator: (RadiologyCatalogTest a, RadiologyCatalogTest b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          cellBuilder: (_, RadiologyCatalogTest item) => Text(item.name),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'code',
          label: l10n.labTestCodeLabel,
          cellBuilder: (_, RadiologyCatalogTest item) =>
              Text(item.code?.trim().isNotEmpty == true ? item.code! : '—'),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'modality',
          label: l10n.radiologyModalityLabel,
          cellBuilder: (_, RadiologyCatalogTest item) => Text(
            item.modality?.trim().isNotEmpty == true ? item.modality! : '—',
          ),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'price',
          label: l10n.clinicalRequestUnitPriceLabel,
          cellBuilder: (_, RadiologyCatalogTest item) =>
              Text(_formatPrice(item.unitPrice, item.currency)),
        ),
        if (widget.enabled)
          AppListTableColumn<RadiologyCatalogTest>(
            id: 'actions',
            label: l10n.accessAdminColumnActions,
            alwaysVisible: true,
            cellBuilder: (BuildContext context, RadiologyCatalogTest item) {
              return _CatalogRowActions(
                editLabel: l10n.clinicalLabRequestEditSelectionAction,
                deleteLabel: l10n.clinicalRadiologyDeleteSelectionAction,
                onEdit: () => unawaited(_openRadiologyEditDialog(item)),
                onDelete: () => unawaited(_openRadiologyDeleteDialog(item)),
              );
            },
          ),
      ],
      mobileItemBuilder: (BuildContext context, RadiologyCatalogTest item) {
        return AppListTableMobileItem(
          title: item.name,
          caption: item.modality,
          meta: <AppListTableMobileMeta>[
            if (item.code?.trim().isNotEmpty == true)
              AppListTableMobileMeta(label: item.code!),
            if (item.bodyRegion?.trim().isNotEmpty == true)
              AppListTableMobileMeta(label: item.bodyRegion!),
          ],
        );
      },
    );
  }

  Widget _buildBudgetTable(AppLocalizations l10n) {
    return AppListTable<_BudgetOffering>(
      items: _filteredBudgetOfferings(l10n),
      isLoading: _isLoading,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'setup_catalog_budget',
      onRowSelected: widget.enabled
          ? (_BudgetOffering item) => unawaited(_openBudgetEditDialog(item))
          : null,
      search: AppListTableSearch<_BudgetOffering>(
        controller: _budgetSearchController,
        semanticLabel: l10n.settingsWorkspaceSearchLabel,
        hintText: l10n.tenantFacilityCatalogSearchHint,
        matcher: (_BudgetOffering item, String query) {
          final String haystack =
              '${item.name} ${item.code ?? ''} ${item.categoryLabel} '
                      '${item.unitPrice ?? ''}'
                  .toLowerCase();
          return haystack.contains(query.toLowerCase());
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFilterActionLabel,
        advancedFilterTitle: l10n.tenantFacilityCatalogBudgetCategoryFilterLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        enableDateFilter: false,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _budgetSourceFilterKey,
            label: l10n.tenantFacilityCatalogBudgetCategoryFilterLabel,
            allLabel: l10n.commonAllLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: _BudgetSource.lab.name,
                label: l10n.tenantFacilityCatalogTabLab,
              ),
              AppSearchBarFilterChoice(
                value: _BudgetSource.diagnostics.name,
                label: l10n.tenantFacilityCatalogTabDiagnostics,
              ),
            ],
          ),
        ],
        filterValue: _budgetFilterValue,
        hasActiveFilters: _budgetFilterValue.isActive,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() => _budgetFilterValue = value);
        },
        trailingActions: <AppSearchBarAction>[
          if (widget.enabled) ...<AppSearchBarAction>[
            AppSearchBarAction(
              icon: Icons.add_circle_outline,
              label: l10n.labEnableTestAction,
              onPressed: () => unawaited(
                _openLabEnableDialog(LabEnableOfferingKind.test),
              ),
            ),
            AppSearchBarAction(
              icon: Icons.image_search_outlined,
              label: l10n.clinicalRadiologyCatalogSelectTitle,
              onPressed: () => unawaited(_openRadiologyEnableDialog()),
            ),
          ],
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilityCatalogTabBudget,
        body: l10n.tenantFacilityCatalogEmptyOfferings,
        action: widget.enabled
            ? AppButton.primary(
                label: l10n.labEnableTestAction,
                leadingIcon: Icons.add_circle_outline,
                onPressed: () => unawaited(
                  _openLabEnableDialog(LabEnableOfferingKind.test),
                ),
              )
            : null,
      ),
      columns: <AppListTableColumn<_BudgetOffering>>[
        AppListTableColumn<_BudgetOffering>(
          id: 'name',
          label: l10n.accessAdminColumnName,
          sortComparator: (_BudgetOffering a, _BudgetOffering b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          cellBuilder: (_, _BudgetOffering item) => Text(item.name),
        ),
        AppListTableColumn<_BudgetOffering>(
          id: 'category',
          label: l10n.tenantFacilityCatalogBudgetCategoryFilterLabel,
          cellBuilder: (_, _BudgetOffering item) => Text(item.categoryLabel),
        ),
        AppListTableColumn<_BudgetOffering>(
          id: 'code',
          label: l10n.labTestCodeLabel,
          cellBuilder: (_, _BudgetOffering item) =>
              Text(item.code?.trim().isNotEmpty == true ? item.code! : '—'),
        ),
        AppListTableColumn<_BudgetOffering>(
          id: 'price',
          label: l10n.clinicalRequestUnitPriceLabel,
          cellBuilder: (_, _BudgetOffering item) =>
              Text(_formatPrice(item.unitPrice, item.currency)),
        ),
        if (widget.enabled)
          AppListTableColumn<_BudgetOffering>(
            id: 'actions',
            label: l10n.accessAdminColumnActions,
            alwaysVisible: true,
            cellBuilder: (BuildContext context, _BudgetOffering item) {
              return _CatalogRowActions(
                editLabel: l10n.tenantFacilityCatalogConfigurePriceAction,
                deleteLabel: l10n.tenantFacilityDeleteAction,
                onEdit: () => unawaited(_openBudgetEditDialog(item)),
                onDelete: () => unawaited(_openBudgetDeleteDialog(item)),
              );
            },
          ),
      ],
      mobileItemBuilder: (BuildContext context, _BudgetOffering item) {
        return AppListTableMobileItem(
          title: item.name,
          caption: item.categoryLabel,
          meta: <AppListTableMobileMeta>[
            if (item.code?.trim().isNotEmpty == true)
              AppListTableMobileMeta(label: item.code!),
            AppListTableMobileMeta(
              label: _formatPrice(item.unitPrice, item.currency),
            ),
          ],
        );
      },
    );
  }

  String _formatPrice(num? unitPrice, String? currency) {
    if (unitPrice == null) {
      return '—';
    }
    final String code = currency?.trim().isNotEmpty == true
        ? currency!
        : _resolvedCurrency;
    return '$code $unitPrice';
  }

  Future<void> _reloadCurrentTab() async {
    if (_tab == _CatalogDeskTab.lab) {
      await _loadLabOfferings();
      return;
    }
    if (_tab == _CatalogDeskTab.diagnostics) {
      await _loadRadiologyOfferings();
      return;
    }
    await _loadBudgetOfferings();
  }

  Future<void> _loadLabOfferings() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final ({AppFailure? failure, List<LabCatalogItem> items}) loaded =
        await _fetchLabOfferings();
    if (!mounted) {
      return;
    }
    setState(() {
      _labOfferings = loaded.items;
      _failure = loaded.failure;
      _isLoading = false;
    });
  }

  Future<void> _loadRadiologyOfferings() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final ({AppFailure? failure, List<RadiologyCatalogTest> items}) loaded =
        await _fetchRadiologyOfferings();
    if (!mounted) {
      return;
    }
    setState(() {
      _radiologyOfferings = loaded.items;
      _failure = loaded.failure;
      _isLoading = false;
    });
  }

  Future<void> _loadBudgetOfferings() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final List<Object> loaded = await Future.wait(<Future<Object>>[
      _fetchLabOfferings(),
      _fetchRadiologyOfferings(),
    ]);
    if (!mounted) {
      return;
    }
    final ({AppFailure? failure, List<LabCatalogItem> items}) lab =
        loaded[0] as ({AppFailure? failure, List<LabCatalogItem> items});
    final ({AppFailure? failure, List<RadiologyCatalogTest> items}) radiology =
        loaded[1]
            as ({AppFailure? failure, List<RadiologyCatalogTest> items});
    setState(() {
      _labOfferings = lab.items;
      _radiologyOfferings = radiology.items;
      _failure = lab.failure ?? radiology.failure;
      _isLoading = false;
    });
  }

  Future<({AppFailure? failure, List<LabCatalogItem> items})>
  _fetchLabOfferings() async {
    final LabRepository repository = ref.read(labRepositoryProvider);
    final List<Result<List<LabCatalogItem>>> results =
        await Future.wait(<Future<Result<List<LabCatalogItem>>>>[
          repository.listFacilityLabTests(
            tenantId: widget.tenantId,
            facilityId: widget.facilityId,
            offeredOnly: true,
            limit: _searchLimit,
          ),
          repository.listFacilityLabPanels(
            tenantId: widget.tenantId,
            facilityId: widget.facilityId,
            offeredOnly: true,
            limit: _searchLimit,
          ),
        ]);
    AppFailure? failure;
    final List<LabCatalogItem> merged = <LabCatalogItem>[];
    for (final Result<List<LabCatalogItem>> result in results) {
      result.when(
        success: merged.addAll,
        failure: (AppFailure value) => failure ??= value,
      );
    }
    merged.sort(
      (LabCatalogItem a, LabCatalogItem b) =>
          a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()),
    );
    return (failure: failure, items: merged);
  }

  Future<({AppFailure? failure, List<RadiologyCatalogTest> items})>
  _fetchRadiologyOfferings() async {
    final Result<List<RadiologyCatalogTest>> result = await ref
        .read(radiologyRepositoryProvider)
        .listFacilityRadiologyTests(
          tenantId: widget.tenantId,
          facilityId: widget.facilityId,
          offeredOnly: true,
          limit: _searchLimit,
        );
    return result.when(
      success: (List<RadiologyCatalogTest> value) =>
          (failure: null, items: value),
      failure: (AppFailure failure) => (
        failure: failure,
        items: const <RadiologyCatalogTest>[],
      ),
    );
  }

  Future<void> _openLabEnableDialog(LabEnableOfferingKind kind) async {
    final LabRepository repository = ref.read(labRepositoryProvider);
    final FacilityCatalogScope scope = _scope;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabEnableFacilityOfferingDialog(
        kind: kind,
        scope: scope,
        defaultCurrency: _resolvedCurrency,
        onSearchCatalog:
            ({
              required LabEnableOfferingKind kind,
              required LabCatalogScope scope,
              String? query,
              int limit = 100,
            }) {
              return _searchLabCatalog(
                repository: repository,
                kind: kind,
                scope: scope,
                query: query,
                limit: limit,
              );
            },
        onEnable: (String id, Map<String, Object?> payload) async {
          final Result<LabCatalogItem> result =
              kind == LabEnableOfferingKind.test
              ? await repository.upsertFacilityLabTestOffering(
                  id,
                  payload,
                  tenantId: scope.tenantId,
                  facilityId: scope.facilityId,
                )
              : await repository.upsertFacilityLabPanelOffering(
                  id,
                  payload,
                  tenantId: scope.tenantId,
                  facilityId: scope.facilityId,
                );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.labSavedMessage)));
    await _reloadCurrentTab();
  }

  Future<void> _openLabEditDialog(LabCatalogItem item) async {
    final LabRepository repository = ref.read(labRepositoryProvider);
    final FacilityCatalogScope scope = _scope;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FacilityOfferingPriceEditDialog(
        title: context.l10n.tenantFacilityCatalogEditPriceDialogTitle,
        name: item.displayTitle,
        unitPrice: item.unitPrice,
        currency: item.currency ?? _resolvedCurrency,
        submitLabel: context.l10n.tenantFacilityCatalogConfigurePriceAction,
        onSubmit: (num unitPrice, String currency) async {
          final Map<String, Object?> payload = <String, Object?>{
            'is_active': true,
            'unit_price': unitPrice,
            'currency': currency,
          };
          final Result<LabCatalogItem> result =
              item.type == LabCatalogItemType.panel
              ? await repository.upsertFacilityLabPanelOffering(
                  item.apiId,
                  payload,
                  tenantId: scope.tenantId,
                  facilityId: scope.facilityId,
                )
              : await repository.upsertFacilityLabTestOffering(
                  item.apiId,
                  payload,
                  tenantId: scope.tenantId,
                  facilityId: scope.facilityId,
                );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.labSavedMessage)));
    await _reloadCurrentTab();
  }

  Future<void> _openLabDeleteDialog(LabCatalogItem item) async {
    final LabRepository repository = ref.read(labRepositoryProvider);
    final FacilityCatalogScope scope = _scope;
    final AppLocalizations l10n = context.l10n;
    final bool isPanel = item.type == LabCatalogItemType.panel;
    final bool? deleted = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabDeleteReasonDialog(
        title: isPanel
            ? l10n.labDeletePanelDialogTitle
            : l10n.labDeleteTestDialogTitle,
        body: isPanel
            ? l10n.labDeletePanelDialogBody(item.displayTitle)
            : l10n.labDeleteTestDialogBody(item.displayTitle),
        submitLabel: isPanel
            ? l10n.labDeletePanelAction
            : l10n.labDeleteTestAction,
        onDelete: (String reason) async {
          final Result<void> result = isPanel
              ? await repository.disableFacilityLabPanelOffering(
                  item.apiId,
                  reason,
                  tenantId: scope.tenantId,
                  facilityId: scope.facilityId,
                )
              : await repository.disableFacilityLabTestOffering(
                  item.apiId,
                  reason,
                  tenantId: scope.tenantId,
                  facilityId: scope.facilityId,
                );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted || deleted != true) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.labDeletedMessage)));
    await _reloadCurrentTab();
  }

  Future<void> _openRadiologyEnableDialog() async {
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final FacilityCatalogScope scope = _scope;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyEnableFacilityOfferingDialog(
        scope: scope,
        defaultCurrency: _resolvedCurrency,
        onSearchCatalog:
            ({
              required RadiologyCatalogScope scope,
              String? query,
              int limit = 100,
            }) {
              return _searchRadiologyCatalog(
                repository: repository,
                scope: scope,
                query: query,
                limit: limit,
              );
            },
        onEnable: (String id, Map<String, Object?> payload) async {
          final Result<RadiologyCatalogTest> result = await repository
              .upsertFacilityRadiologyTestOffering(
                id,
                payload,
                tenantId: scope.tenantId,
                facilityId: scope.facilityId,
              );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.radiologySaveConfigurationAction)),
    );
    await _reloadCurrentTab();
  }

  Future<void> _openRadiologyEditDialog(RadiologyCatalogTest item) async {
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final FacilityCatalogScope scope = _scope;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyEditFacilityOfferingDialog(
        item: item,
        defaultCurrency: _resolvedCurrency,
        onUpdate: (String id, Map<String, Object?> payload) async {
          final Result<RadiologyCatalogTest> result = await repository
              .upsertFacilityRadiologyTestOffering(
                id,
                payload,
                tenantId: scope.tenantId,
                facilityId: scope.facilityId,
              );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    await _reloadCurrentTab();
  }

  Future<void> _openRadiologyDeleteDialog(RadiologyCatalogTest item) async {
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final FacilityCatalogScope scope = _scope;
    final AppLocalizations l10n = context.l10n;
    final bool? deleted = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabDeleteReasonDialog(
        title: l10n.radiologyDisableOfferingDialogTitle,
        body: l10n.radiologyDisableOfferingDialogBody(item.name),
        submitLabel: l10n.clinicalRadiologyDeleteSelectionAction,
        onDelete: (String reason) async {
          final Result<void> result = await repository
              .disableFacilityRadiologyTestOffering(
                item.apiId,
                reason,
                tenantId: scope.tenantId,
                facilityId: scope.facilityId,
              );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted || deleted != true) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.labDeletedMessage)));
    await _reloadCurrentTab();
  }

  Future<void> _openBudgetEditDialog(_BudgetOffering item) async {
    if (item.labItem != null) {
      await _openLabEditDialog(item.labItem!);
      return;
    }
    if (item.radiologyItem != null) {
      await _openRadiologyEditDialog(item.radiologyItem!);
    }
  }

  Future<void> _openBudgetDeleteDialog(_BudgetOffering item) async {
    if (item.labItem != null) {
      await _openLabDeleteDialog(item.labItem!);
      return;
    }
    if (item.radiologyItem != null) {
      await _openRadiologyDeleteDialog(item.radiologyItem!);
    }
  }

  Future<Result<List<LabCatalogItem>>> _searchLabCatalog({
    required LabRepository repository,
    required LabEnableOfferingKind kind,
    required LabCatalogScope scope,
    String? query,
    int limit = 100,
  }) async {
    if (!scope.isReady) {
      return const Result<List<LabCatalogItem>>.success(<LabCatalogItem>[]);
    }
    final Future<Result<List<LabCatalogItem>>> platformFuture =
        kind == LabEnableOfferingKind.test
        ? repository.listTests(
            search: query,
            tenantId: scope.tenantId,
            includeStandardCatalog: true,
            limit: limit,
          )
        : repository.listPanels(
            search: query,
            tenantId: scope.tenantId,
            includeStandardCatalog: true,
            limit: limit,
          );
    final Future<Result<List<LabCatalogItem>>> offeredFuture =
        kind == LabEnableOfferingKind.test
        ? repository.listFacilityLabTests(
            tenantId: scope.tenantId,
            facilityId: scope.facilityId,
            offeredOnly: true,
            limit: limit,
          )
        : repository.listFacilityLabPanels(
            tenantId: scope.tenantId,
            facilityId: scope.facilityId,
            offeredOnly: true,
            limit: limit,
          );
    final List<Result<List<LabCatalogItem>>> results = await Future.wait(
      <Future<Result<List<LabCatalogItem>>>>[platformFuture, offeredFuture],
    );
    return results[0].when(
      success: (List<LabCatalogItem> platformItems) {
        final Set<String> offeredIds = <String>{};
        final Set<String> offeredCodes = <String>{};
        results[1].when(
          success: (List<LabCatalogItem> offeredItems) {
            for (final LabCatalogItem item in offeredItems) {
              offeredIds.add(item.apiId);
              final String? code = item.code?.trim();
              if (code != null && code.isNotEmpty) {
                offeredCodes.add(code.toUpperCase());
              }
            }
          },
          failure: (_) {},
        );
        return Result<List<LabCatalogItem>>.success(
          platformItems
              .map((LabCatalogItem item) {
                final String? code = item.code?.trim();
                final bool isOffered =
                    offeredIds.contains(item.apiId) ||
                    (code != null &&
                        code.isNotEmpty &&
                        offeredCodes.contains(code.toUpperCase()));
                return isOffered
                    ? item.copyWith(isOfferedAtFacility: true)
                    : item;
              })
              .toList(growable: false),
        );
      },
      failure: (AppFailure failure) =>
          Result<List<LabCatalogItem>>.failure(failure),
    );
  }

  Future<Result<List<RadiologyCatalogTest>>> _searchRadiologyCatalog({
    required RadiologyRepository repository,
    required RadiologyCatalogScope scope,
    String? query,
    int limit = 100,
  }) async {
    if (!scope.isReady) {
      return const Result<List<RadiologyCatalogTest>>.success(
        <RadiologyCatalogTest>[],
      );
    }
    final Future<Result<List<RadiologyCatalogTest>>> platformFuture = repository
        .listRadiologyCatalogTests(search: query, limit: limit);
    final Future<Result<List<RadiologyCatalogTest>>> offeredFuture = repository
        .listFacilityRadiologyTests(
          tenantId: scope.tenantId,
          facilityId: scope.facilityId,
          offeredOnly: true,
          limit: limit,
        );
    final List<Result<List<RadiologyCatalogTest>>> results = await Future.wait(
      <Future<Result<List<RadiologyCatalogTest>>>>[
        platformFuture,
        offeredFuture,
      ],
    );
    return results[0].when(
      success: (List<RadiologyCatalogTest> platformItems) {
        final Set<String> offeredIds = <String>{};
        final Set<String> offeredCodes = <String>{};
        results[1].when(
          success: (List<RadiologyCatalogTest> offeredItems) {
            for (final RadiologyCatalogTest item in offeredItems) {
              offeredIds.add(item.apiId);
              final String? code = item.code?.trim();
              if (code != null && code.isNotEmpty) {
                offeredCodes.add(code.toUpperCase());
              }
            }
          },
          failure: (_) {},
        );
        return Result<List<RadiologyCatalogTest>>.success(
          platformItems
              .map((RadiologyCatalogTest item) {
                final String? code = item.code?.trim();
                final bool isOffered =
                    offeredIds.contains(item.apiId) ||
                    (code != null &&
                        code.isNotEmpty &&
                        offeredCodes.contains(code.toUpperCase()));
                if (!isOffered) {
                  return item;
                }
                return item.copyWith(isOfferedAtFacility: true);
              })
              .toList(growable: false),
        );
      },
      failure: (AppFailure failure) =>
          Result<List<RadiologyCatalogTest>>.failure(failure),
    );
  }
}

@immutable
final class _BudgetOffering {
  const _BudgetOffering({
    required this.id,
    required this.name,
    required this.source,
    required this.categoryLabel,
    this.code,
    this.unitPrice,
    this.currency,
    this.labItem,
    this.radiologyItem,
  });

  factory _BudgetOffering.fromLab(LabCatalogItem item, String categoryLabel) {
    return _BudgetOffering(
      id: 'lab:${item.apiId}',
      name: item.displayTitle,
      source: _BudgetSource.lab,
      categoryLabel: categoryLabel,
      code: item.code,
      unitPrice: item.unitPrice,
      currency: item.currency,
      labItem: item,
    );
  }

  factory _BudgetOffering.fromRadiology(
    RadiologyCatalogTest item,
    String categoryLabel,
  ) {
    return _BudgetOffering(
      id: 'diagnostics:${item.apiId}',
      name: item.name,
      source: _BudgetSource.diagnostics,
      categoryLabel: categoryLabel,
      code: item.code,
      unitPrice: item.unitPrice,
      currency: item.currency,
      radiologyItem: item,
    );
  }

  final String id;
  final String name;
  final _BudgetSource source;
  final String categoryLabel;
  final String? code;
  final num? unitPrice;
  final String? currency;
  final LabCatalogItem? labItem;
  final RadiologyCatalogTest? radiologyItem;
}

class _CatalogRowActions extends StatelessWidget {
  const _CatalogRowActions({
    required this.editLabel,
    required this.deleteLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final String editLabel;
  final String deleteLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        AppButton.tertiary(
          label: editLabel,
          leadingIcon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        AppButton.tertiary(
          label: deleteLabel,
          leadingIcon: Icons.delete_outline,
          color: theme.colorScheme.error,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _FacilityOfferingPriceEditDialog extends StatefulWidget {
  const _FacilityOfferingPriceEditDialog({
    required this.title,
    required this.name,
    required this.currency,
    required this.submitLabel,
    required this.onSubmit,
    this.unitPrice,
  });

  final String title;
  final String name;
  final num? unitPrice;
  final String currency;
  final String submitLabel;
  final Future<AppFailure?> Function(num unitPrice, String currency) onSubmit;

  @override
  State<_FacilityOfferingPriceEditDialog> createState() =>
      _FacilityOfferingPriceEditDialogState();
}

class _FacilityOfferingPriceEditDialogState
    extends State<_FacilityOfferingPriceEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late String _currency;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.unitPrice?.toString() ?? '',
    );
    _currency = widget.currency;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.payments_outlined),
      scrollable: true,
      maxWidth: 520,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            Text(
              widget.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            AppCurrencyAmountField(
              amountController: _priceController,
              currency: _currency,
              amountLabelText: l10n.clinicalRequestUnitPriceLabel,
              currencyLabelText: l10n.opdCurrencyLabel,
              enabled: !_isSaving,
              isRequired: true,
              allowZero: false,
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
              validator: (String? value) {
                final String normalized = normalizeCurrencyAmount(value ?? '');
                if (normalized.isEmpty) {
                  return l10n.validationRequired;
                }
                final num? parsed = num.tryParse(normalized);
                if (parsed == null || parsed <= 0) {
                  return l10n.validationRequired;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: widget.submitLabel,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final num unitPrice =
        num.tryParse(normalizeCurrencyAmount(_priceController.text)) ?? 0;
    final AppFailure? failure = await widget.onSubmit(unitPrice, _currency);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}
