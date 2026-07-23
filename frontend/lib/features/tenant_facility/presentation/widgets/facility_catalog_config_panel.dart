import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/facility_catalog/clinical_catalog_admin_dialogs.dart';
import 'package:hosspi_hms/shared/facility_catalog/facility_catalog_scope.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_dialogs.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/radiology_catalog/radiology_catalog_dialogs.dart';

enum _CatalogDeskTab { radiology, lab, diagnoses }

class FacilityCatalogConfigPanel extends ConsumerStatefulWidget {
  const FacilityCatalogConfigPanel({
    this.facilityId,
    this.tenantId,
    this.defaultCurrency = appDefaultCurrencyCode,
    this.enabled = true,
    super.key,
  });

  final String? facilityId;
  final String? tenantId;
  final String defaultCurrency;
  final bool enabled;

  @override
  ConsumerState<FacilityCatalogConfigPanel> createState() =>
      _FacilityCatalogConfigPanelState();
}

class _FacilityCatalogConfigPanelState
    extends ConsumerState<FacilityCatalogConfigPanel> {
  static const int _pageSize = AppPageRequest.maxPageSize;
  static const int _radiologyFetchLimit = 7500;
  static const int _labFetchLimit = 5000;
  static const int _diagnosisFetchLimit = 1000;
  static const String _labTypeFilterKey = 'type';
  static const String _labCategoryFilterKey = 'category';
  static const String _modalityFilterKey = 'modality';
  static const String _diagnosisCategoryFilterKey = 'category';

  final TextEditingController _labSearchController = TextEditingController();
  final TextEditingController _radiologySearchController =
      TextEditingController();
  final TextEditingController _diagnosisSearchController =
      TextEditingController();

  _CatalogDeskTab _tab = _CatalogDeskTab.radiology;
  List<LabCatalogItem> _labItems = const <LabCatalogItem>[];
  List<RadiologyCatalogTest> _radiologyItems = const <RadiologyCatalogTest>[];
  List<ClinicalCatalogOption> _diagnosisItems = const <ClinicalCatalogOption>[];
  AppSearchBarFilterValue _labFilterValue = AppSearchBarFilterValue.empty;
  AppSearchBarFilterValue _radiologyFilterValue = AppSearchBarFilterValue.empty;
  AppSearchBarFilterValue _diagnosisFilterValue = AppSearchBarFilterValue.empty;
  AppPageRequest _radiologyRequest = const AppPageRequest(pageSize: _pageSize);
  AppPageRequest _labRequest = const AppPageRequest(pageSize: _pageSize);
  AppPageRequest _diagnosisRequest = const AppPageRequest(pageSize: _pageSize);
  bool _radiologyHydrated = false;
  bool _labHydrated = false;
  bool _diagnosisHydrated = false;
  bool _radiologyLoading = false;
  bool _labLoading = false;
  bool _diagnosisLoading = false;
  AppFailure? _radiologyFailure;
  AppFailure? _labFailure;
  AppFailure? _diagnosisFailure;

  String get _resolvedCurrency =>
      resolveFacilityDefaultCurrency(widget.defaultCurrency);

  AppFailure? get _activeFailure => switch (_tab) {
    _CatalogDeskTab.radiology => _radiologyFailure,
    _CatalogDeskTab.lab => _labFailure,
    _CatalogDeskTab.diagnoses => _diagnosisFailure,
  };

  List<LabCatalogItem> get _filteredLabItems {
    final String? type = _labFilterValue.option(_labTypeFilterKey);
    final String? category = _labFilterValue.option(_labCategoryFilterKey);
    return _labItems.where((LabCatalogItem item) {
      if (type != null && type.isNotEmpty && item.type.name != type) {
        return false;
      }
      if (category != null &&
          category.isNotEmpty &&
          (item.category ?? '').trim() != category) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  List<RadiologyCatalogTest> get _filteredRadiologyItems {
    final String? modality = _radiologyFilterValue.option(_modalityFilterKey);
    if (modality == null || modality.isEmpty) {
      return _radiologyItems;
    }
    return _radiologyItems
        .where(
          (RadiologyCatalogTest item) =>
              (item.modality ?? '').trim() == modality,
        )
        .toList(growable: false);
  }

  List<ClinicalCatalogOption> get _filteredDiagnosisItems {
    final String? category =
        _diagnosisFilterValue.option(_diagnosisCategoryFilterKey);
    if (category == null || category.isEmpty) {
      return _diagnosisItems;
    }
    return _diagnosisItems
        .where(
          (ClinicalCatalogOption item) =>
              (item.category ?? '').trim() == category,
        )
        .toList(growable: false);
  }

  List<RadiologyCatalogTest> get _radiologyVisibleItems {
    final String query = _radiologySearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _filteredRadiologyItems;
    }
    return _filteredRadiologyItems
        .where((RadiologyCatalogTest item) {
          final String haystack =
              '${item.name} ${item.code ?? ''} ${item.modality ?? ''}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  List<LabCatalogItem> get _labVisibleItems {
    final String query = _labSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _filteredLabItems;
    }
    return _filteredLabItems
        .where((LabCatalogItem item) => item.matchesSearch(query))
        .toList(growable: false);
  }

  List<ClinicalCatalogOption> get _diagnosisVisibleItems {
    final String query = _diagnosisSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _filteredDiagnosisItems;
    }
    return _filteredDiagnosisItems
        .where((ClinicalCatalogOption item) {
          final String haystack =
              '${item.name ?? ''} ${item.code ?? ''} ${item.category ?? ''}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  AppPage<T> _pageOf<T>(List<T> items, AppPageRequest request) {
    final List<T> slice = items
        .skip(request.offset)
        .take(request.pageSize)
        .toList(growable: false);
    return AppPage<T>(
      items: slice,
      request: request,
      totalItemCount: items.length,
    );
  }

  void _onRadiologySearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _radiologyRequest = _radiologyRequest.first());
  }

  void _onLabSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _labRequest = _labRequest.first());
  }

  void _onDiagnosisSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _diagnosisRequest = _diagnosisRequest.first());
  }

  @override
  void initState() {
    super.initState();
    _radiologySearchController.addListener(_onRadiologySearchChanged);
    _labSearchController.addListener(_onLabSearchChanged);
    _diagnosisSearchController.addListener(_onDiagnosisSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_ensureTabLoaded(_tab));
      }
    });
  }

  @override
  void didUpdateWidget(covariant FacilityCatalogConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId ||
        oldWidget.facilityId != widget.facilityId) {
      _radiologyHydrated = false;
      _labHydrated = false;
      _diagnosisHydrated = false;
      unawaited(_ensureTabLoaded(_tab, force: true));
    }
  }

  @override
  void dispose() {
    _radiologySearchController.removeListener(_onRadiologySearchChanged);
    _labSearchController.removeListener(_onLabSearchChanged);
    _diagnosisSearchController.removeListener(_onDiagnosisSearchChanged);
    _labSearchController.dispose();
    _radiologySearchController.dispose();
    _diagnosisSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppFailure? failure = _activeFailure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTabStrip(
          variant: AppTabStripVariant.nested,
          tabs: <AppTabItem>[
            AppTabItem(
              id: _CatalogDeskTab.radiology.name,
              icon: Icons.image_search_outlined,
              label: l10n.tenantFacilityCatalogTabRadiology,
            ),
            AppTabItem(
              id: _CatalogDeskTab.lab.name,
              icon: Icons.biotech_outlined,
              label: l10n.tenantFacilityCatalogTabLab,
            ),
            AppTabItem(
              id: _CatalogDeskTab.diagnoses.name,
              icon: Icons.medical_information_outlined,
              label: l10n.tenantFacilityCatalogTabDiagnoses,
            ),
          ],
          selectedId: _tab.name,
          onTabTapped: (String id) {
            final _CatalogDeskTab? next = _CatalogDeskTab.values
                .where((_CatalogDeskTab t) => t.name == id)
                .firstOrNull;
            if (next == null || next == _tab) {
              return;
            }
            setState(() {
              _tab = next;
              switch (next) {
                case _CatalogDeskTab.radiology:
                  _radiologyRequest = _radiologyRequest.first();
                case _CatalogDeskTab.lab:
                  _labRequest = _labRequest.first();
                case _CatalogDeskTab.diagnoses:
                  _diagnosisRequest = _diagnosisRequest.first();
              }
            });
            unawaited(_ensureTabLoaded(next));
          },
        ),
        SizedBox(height: theme.spacing.sm),
        if (failure != null)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: AppFormInformationBanner.failure(
              context: context,
              failure: failure,
            ),
          ),
        Expanded(child: _buildTableBody(l10n)),
      ],
    );
  }

  Widget _buildTableBody(AppLocalizations l10n) {
    return switch (_tab) {
      _CatalogDeskTab.radiology => _buildRadiologyTable(l10n),
      _CatalogDeskTab.lab => _buildLabTable(l10n),
      _CatalogDeskTab.diagnoses => _buildDiagnosisTable(l10n),
    };
  }

  Widget _buildRadiologyTable(AppLocalizations l10n) {
    final List<String> modalities = _radiologyItems
        .map((RadiologyCatalogTest item) => (item.modality ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    return AppListTable<RadiologyCatalogTest>(
      page: _pageOf(_radiologyVisibleItems, _radiologyRequest),
      onPageChanged: (AppPageRequest request) {
        if (request == _radiologyRequest) {
          return;
        }
        setState(() => _radiologyRequest = request);
      },
      paginationMode: AppListTablePaginationMode.infinite,
      isLoading: _radiologyLoading,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'admin_catalog_radiology',
      onRowSelected: widget.enabled
          ? (RadiologyCatalogTest item) =>
                unawaited(_openRadiologyEditDialog(item))
          : null,
      search: AppListTableSearch<RadiologyCatalogTest>(
        controller: _radiologySearchController,
        semanticLabel: l10n.tenantFacilityCatalogTabRadiology,
        hintText: l10n.tenantFacilityCatalogSearchHint,
        matcher: (_, _) => true,
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFilterActionLabel,
        advancedFilterTitle: l10n.radiologyModalityLabel,
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
                for (final String m in modalities)
                  AppSearchBarFilterChoice(value: m, label: m),
              ],
            ),
        ],
        filterValue: _radiologyFilterValue,
        hasActiveFilters: _radiologyFilterValue.isActive,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() {
            _radiologyFilterValue = value;
            _radiologyRequest = _radiologyRequest.first();
          });
        },
        trailingActions: <AppSearchBarAction>[
          if (widget.enabled) ...<AppSearchBarAction>[
            AppSearchBarAction(
              icon: Icons.settings_suggest_outlined,
              label: l10n.tenantFacilityCatalogConfigureAction,
              onPressed: () => unawaited(_openConfigureFlow()),
            ),
            AppSearchBarAction(
              icon: Icons.add_circle_outline,
              label: l10n.radiologyCreateImagingTestAction,
              onPressed: () => unawaited(_openRadiologyAddDialog()),
            ),
          ],
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilityCatalogTabRadiology,
        body: l10n.tenantFacilityCatalogEmptyCatalog,
        action: widget.enabled
            ? AppButton.primary(
                label: l10n.radiologyCreateImagingTestAction,
                leadingIcon: Icons.add_circle_outline,
                onPressed: () => unawaited(_openRadiologyAddDialog()),
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
        if (widget.enabled)
          AppListTableColumn<RadiologyCatalogTest>(
            id: 'actions',
            label: l10n.accessAdminColumnActions,
            alwaysVisible: true,
            cellBuilder: (BuildContext context, RadiologyCatalogTest item) =>
                _CatalogRowActions(
                  editLabel: l10n.clinicalLabRequestEditSelectionAction,
                  deleteLabel: l10n.clinicalRadiologyDeleteSelectionAction,
                  onEdit: () => unawaited(_openRadiologyEditDialog(item)),
                  onDelete: () => unawaited(_openRadiologyDeleteDialog(item)),
                ),
          ),
      ],
      mobileItemBuilder: (BuildContext context, RadiologyCatalogTest item) =>
          AppListTableMobileItem(
            title: item.name,
            caption: item.modality,
            meta: <AppListTableMobileMeta>[
              if (item.code?.trim().isNotEmpty == true)
                AppListTableMobileMeta(label: item.code!),
            ],
          ),
    );
  }

  Widget _buildLabTable(AppLocalizations l10n) {
    final List<String> categories = _labItems
        .map((LabCatalogItem item) => (item.category ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    return AppListTable<LabCatalogItem>(
      page: _pageOf(_labVisibleItems, _labRequest),
      onPageChanged: (AppPageRequest request) {
        if (request == _labRequest) {
          return;
        }
        setState(() => _labRequest = request);
      },
      paginationMode: AppListTablePaginationMode.infinite,
      isLoading: _labLoading,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'admin_catalog_lab',
      onRowSelected: widget.enabled
          ? (LabCatalogItem item) => unawaited(_openLabEditDialog(item))
          : null,
      search: AppListTableSearch<LabCatalogItem>(
        controller: _labSearchController,
        semanticLabel: l10n.tenantFacilityCatalogTabLab,
        hintText: l10n.tenantFacilityCatalogSearchHint,
        matcher: (_, _) => true,
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
          setState(() {
            _labFilterValue = value;
            _labRequest = _labRequest.first();
          });
        },
        trailingActions: <AppSearchBarAction>[
          if (widget.enabled) ...<AppSearchBarAction>[
            AppSearchBarAction(
              icon: Icons.settings_suggest_outlined,
              label: l10n.tenantFacilityCatalogConfigureAction,
              onPressed: () => unawaited(_openConfigureFlow()),
            ),
            AppSearchBarAction(
              icon: Icons.add_circle_outline,
              label: l10n.labCreateTestAction,
              onPressed: () =>
                  unawaited(_openLabAddDialog(LabCatalogItemType.test)),
            ),
            AppSearchBarAction(
              icon: Icons.add_box_outlined,
              label: l10n.labCreatePanelAction,
              onPressed: () =>
                  unawaited(_openLabAddDialog(LabCatalogItemType.panel)),
            ),
          ],
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilityCatalogTabLab,
        body: l10n.tenantFacilityCatalogEmptyCatalog,
        action: widget.enabled
            ? AppButton.primary(
                label: l10n.labCreateTestAction,
                leadingIcon: Icons.add_circle_outline,
                onPressed: () =>
                    unawaited(_openLabAddDialog(LabCatalogItemType.test)),
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
        if (widget.enabled)
          AppListTableColumn<LabCatalogItem>(
            id: 'actions',
            label: l10n.accessAdminColumnActions,
            alwaysVisible: true,
            cellBuilder: (BuildContext context, LabCatalogItem item) =>
                _CatalogRowActions(
                  editLabel: l10n.clinicalLabRequestEditSelectionAction,
                  deleteLabel: l10n.tenantFacilityDeleteAction,
                  onEdit: () => unawaited(_openLabEditDialog(item)),
                  onDelete: () => unawaited(_openLabDeleteDialog(item)),
                ),
          ),
      ],
      mobileItemBuilder: (BuildContext context, LabCatalogItem item) =>
          AppListTableMobileItem(
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
          ),
    );
  }

  Widget _buildDiagnosisTable(AppLocalizations l10n) {
    final List<String> categories = _diagnosisItems
        .map((ClinicalCatalogOption item) => (item.category ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    return AppListTable<ClinicalCatalogOption>(
      page: _pageOf(_diagnosisVisibleItems, _diagnosisRequest),
      onPageChanged: (AppPageRequest request) {
        if (request == _diagnosisRequest) {
          return;
        }
        setState(() => _diagnosisRequest = request);
      },
      paginationMode: AppListTablePaginationMode.infinite,
      isLoading: _diagnosisLoading,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'admin_catalog_diagnoses',
      onRowSelected: widget.enabled
          ? (ClinicalCatalogOption item) =>
                unawaited(_openDiagnosisEditDialog(item))
          : null,
      search: AppListTableSearch<ClinicalCatalogOption>(
        controller: _diagnosisSearchController,
        semanticLabel: l10n.tenantFacilityCatalogTabDiagnoses,
        hintText: l10n.tenantFacilityCatalogSearchHint,
        matcher: (_, _) => true,
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFilterActionLabel,
        advancedFilterTitle: l10n.labCategoryLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        enableDateFilter: false,
        filterGroups: <AppSearchBarFilterGroup>[
          if (categories.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _diagnosisCategoryFilterKey,
              label: l10n.labCategoryLabel,
              allLabel: l10n.commonAllLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final String category in categories)
                  AppSearchBarFilterChoice(value: category, label: category),
              ],
            ),
        ],
        filterValue: _diagnosisFilterValue,
        hasActiveFilters: _diagnosisFilterValue.isActive,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() {
            _diagnosisFilterValue = value;
            _diagnosisRequest = _diagnosisRequest.first();
          });
        },
        trailingActions: <AppSearchBarAction>[
          if (widget.enabled) ...<AppSearchBarAction>[
            AppSearchBarAction(
              icon: Icons.settings_suggest_outlined,
              label: l10n.tenantFacilityCatalogConfigureAction,
              onPressed: () => unawaited(_openConfigureFlow()),
            ),
            AppSearchBarAction(
              icon: Icons.add_circle_outline,
              label: l10n.clinicalAddDiagnosisAction,
              onPressed: () => unawaited(_openDiagnosisAddDialog()),
            ),
          ],
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilityCatalogTabDiagnoses,
        body: l10n.tenantFacilityCatalogEmptyCatalog,
        action: widget.enabled
            ? AppButton.primary(
                label: l10n.clinicalAddDiagnosisAction,
                leadingIcon: Icons.add_circle_outline,
                onPressed: () => unawaited(_openDiagnosisAddDialog()),
              )
            : null,
      ),
      columns: <AppListTableColumn<ClinicalCatalogOption>>[
        AppListTableColumn<ClinicalCatalogOption>(
          id: 'name',
          label: l10n.accessAdminColumnName,
          sortComparator: (ClinicalCatalogOption a, ClinicalCatalogOption b) =>
              (a.name ?? '').toLowerCase().compareTo(
                (b.name ?? '').toLowerCase(),
              ),
          cellBuilder: (_, ClinicalCatalogOption item) =>
              Text(item.displayTitle),
        ),
        AppListTableColumn<ClinicalCatalogOption>(
          id: 'code',
          label: l10n.labTestCodeLabel,
          cellBuilder: (_, ClinicalCatalogOption item) =>
              Text(item.code?.trim().isNotEmpty == true ? item.code! : '—'),
        ),
        AppListTableColumn<ClinicalCatalogOption>(
          id: 'category',
          label: l10n.labCategoryLabel,
          cellBuilder: (_, ClinicalCatalogOption item) => Text(
            item.category?.trim().isNotEmpty == true ? item.category! : '—',
          ),
        ),
        if (widget.enabled)
          AppListTableColumn<ClinicalCatalogOption>(
            id: 'actions',
            label: l10n.accessAdminColumnActions,
            alwaysVisible: true,
            cellBuilder: (BuildContext context, ClinicalCatalogOption item) =>
                _CatalogRowActions(
                  editLabel: l10n.clinicalLabRequestEditSelectionAction,
                  deleteLabel: l10n.tenantFacilityDeleteAction,
                  onEdit: () => unawaited(_openDiagnosisEditDialog(item)),
                  onDelete: () => unawaited(_openDiagnosisDeleteDialog(item)),
                ),
          ),
      ],
      mobileItemBuilder: (BuildContext context, ClinicalCatalogOption item) =>
          AppListTableMobileItem(
            title: item.displayTitle,
            caption: item.category,
            meta: <AppListTableMobileMeta>[
              if (item.code?.trim().isNotEmpty == true)
                AppListTableMobileMeta(label: item.code!),
            ],
          ),
    );
  }

  Future<void> _ensureTabLoaded(
    _CatalogDeskTab tab, {
    bool force = false,
  }) async {
    return switch (tab) {
      _CatalogDeskTab.radiology => _loadRadiologyItems(force: force),
      _CatalogDeskTab.lab => _loadLabItems(force: force),
      _CatalogDeskTab.diagnoses => _loadDiagnosisItems(force: force),
    };
  }

  Future<void> _loadRadiologyItems({bool force = false}) async {
    if (!mounted) {
      return;
    }
    if (_radiologyHydrated && !force) {
      return;
    }
    setState(() {
      _radiologyLoading = true;
      _radiologyFailure = null;
    });
    final Result<List<RadiologyCatalogTest>> result = await ref
        .read(radiologyRepositoryProvider)
        .listRadiologyCatalogTests(
          includeStandardCatalog: true,
          search: null,
          limit: _radiologyFetchLimit,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _radiologyLoading = false;
      result.when(
        success: (List<RadiologyCatalogTest> items) {
          _radiologyItems = items;
          _radiologyHydrated = true;
          _radiologyRequest = _radiologyRequest.first();
        },
        failure: (AppFailure failure) {
          _radiologyFailure = failure;
        },
      );
    });
  }

  Future<void> _loadLabItems({bool force = false}) async {
    if (!mounted) {
      return;
    }
    if (_labHydrated && !force) {
      return;
    }
    setState(() {
      _labLoading = true;
      _labFailure = null;
    });
    final LabRepository repository = ref.read(labRepositoryProvider);
    final List<Result<List<LabCatalogItem>>> results =
        await Future.wait(<Future<Result<List<LabCatalogItem>>>>[
          repository.listTests(
            includeStandardCatalog: true,
            tenantId: widget.tenantId,
            limit: _labFetchLimit,
          ),
          repository.listPanels(
            includeStandardCatalog: true,
            tenantId: widget.tenantId,
            limit: _labFetchLimit,
          ),
        ]);
    if (!mounted) {
      return;
    }
    AppFailure? failure;
    final List<LabCatalogItem> merged = <LabCatalogItem>[];
    for (final Result<List<LabCatalogItem>> result in results) {
      result.when(
        success: merged.addAll,
        failure: (AppFailure f) => failure ??= f,
      );
    }
    merged.sort(
      (LabCatalogItem a, LabCatalogItem b) =>
          a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()),
    );
    setState(() {
      _labItems = merged;
      _labFailure = failure;
      _labLoading = false;
      if (failure == null) {
        _labHydrated = true;
        _labRequest = _labRequest.first();
      }
    });
  }

  Future<void> _loadDiagnosisItems({bool force = false}) async {
    if (!mounted) {
      return;
    }
    if (_diagnosisHydrated && !force) {
      return;
    }
    setState(() {
      _diagnosisLoading = true;
      _diagnosisFailure = null;
    });
    final Result<List<ClinicalCatalogOption>> result = await ref
        .read(clinicalRepositoryProvider)
        .searchClinicalCatalog(
          termType: 'DIAGNOSIS',
          source: 'GLOBAL',
          query: null,
          limit: _diagnosisFetchLimit,
          facilityId: null,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _diagnosisLoading = false;
      result.when(
        success: (List<ClinicalCatalogOption> items) {
          _diagnosisItems = items;
          _diagnosisHydrated = true;
          _diagnosisRequest = _diagnosisRequest.first();
        },
        failure: (AppFailure failure) {
          _diagnosisFailure = failure;
        },
      );
    });
  }

  Future<void> _openConfigureFlow() async {
    final TenantFacilityRepository tenantRepo = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final FacilityCatalogScope? scope = await showCatalogFacilityScopePicker(
      context: context,
      loadTenants: () async {
        final Result<AppPage<TenantProfile>> result = await tenantRepo
            .listTenants(request: const AppPageRequest(pageSize: 100));
        return result.when(
          success: (AppPage<TenantProfile> page) => page.items,
          failure: (_) => const <TenantProfile>[],
        );
      },
      loadFacilities: (String tenantId) async {
        final Result<AppPage<FacilityProfile>> result = await tenantRepo
            .listFacilities(
              request: const AppPageRequest(pageSize: 100),
              tenantId: tenantId,
            );
        return result.when(
          success: (AppPage<FacilityProfile> page) => page.items,
          failure: (_) => const <FacilityProfile>[],
        );
      },
      initialTenantId: widget.tenantId,
      initialFacilityId: widget.facilityId,
    );
    if (!mounted || scope == null || !scope.isReady) {
      return;
    }
    switch (_tab) {
      case _CatalogDeskTab.radiology:
        await _openRadiologyConfigureDialog(scope);
      case _CatalogDeskTab.lab:
        await _openLabConfigureDialog(scope);
      case _CatalogDeskTab.diagnoses:
        await _openDiagnosisConfigureDialog(scope);
    }
  }

  Future<void> _openRadiologyConfigureDialog(FacilityCatalogScope scope) async {
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyEnableFacilityOfferingDialog(
        scope: scope,
        defaultCurrency: _resolvedCurrency,
        onSearchCatalog: ({
          required RadiologyCatalogScope scope,
          String? query,
          int limit = 100,
        }) =>
            _searchRadiologyCatalog(
              repository: repository,
              scope: scope,
              query: query,
              limit: limit,
            ),
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
  }

  Future<void> _openLabConfigureDialog(FacilityCatalogScope scope) async {
    final LabRepository repository = ref.read(labRepositoryProvider);
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabEnableFacilityOfferingDialog(
        kind: LabEnableOfferingKind.test,
        scope: scope,
        defaultCurrency: _resolvedCurrency,
        onSearchCatalog: ({
          required LabEnableOfferingKind kind,
          required LabCatalogScope scope,
          String? query,
          int limit = 100,
        }) =>
            _searchLabCatalog(
              repository: repository,
              kind: kind,
              scope: scope,
              query: query,
              limit: limit,
            ),
        onEnable: (String id, Map<String, Object?> payload) async {
          final Result<LabCatalogItem> result =
              await repository.upsertFacilityLabTestOffering(
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
      SnackBar(content: Text(context.l10n.labSavedMessage)),
    );
  }

  Future<void> _openDiagnosisConfigureDialog(FacilityCatalogScope scope) async {
    final ClinicalRepository repository = ref.read(clinicalRepositoryProvider);
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DiagnosisEnableFacilityOfferingDialog(
        scope: scope,
        onSearchCatalog: ({String? query, int limit = 100}) =>
            repository.searchClinicalCatalog(
              termType: 'DIAGNOSIS',
              source: 'GLOBAL',
              query: query,
              limit: limit,
              facilityId: null,
            ),
        onEnable: (ClinicalCatalogOption item) async {
          final Result<void> result =
              await repository.upsertFacilityCatalogOffering(<String, Object?>{
                'facility_id': scope.facilityId,
                'tenant_id': scope.tenantId,
                'term_type': 'DIAGNOSIS',
                'item_id': item.apiId,
                'is_active': true,
              });
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
      SnackBar(content: Text(context.l10n.labSavedMessage)),
    );
  }

  Future<void> _openRadiologyAddDialog() async {
    final String? tenantId = await _resolveTenantIdForCreate();
    if (!mounted || tenantId == null) {
      return;
    }
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyCatalogMutationDialog(
        tenantId: tenantId,
        onSubmit: (Map<String, Object?> payload) async {
          final Result<RadiologyCatalogTest> result = await repository
              .createRadiologyCatalogTest(payload);
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
    await _ensureTabLoaded(_tab, force: true);
  }

  Future<void> _openRadiologyEditDialog(RadiologyCatalogTest item) async {
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyCatalogMutationDialog(
        item: item,
        onSubmit: (Map<String, Object?> payload) async {
          final Result<RadiologyCatalogTest> result = await repository
              .updateRadiologyCatalogTest(item.apiId, payload);
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
    await _ensureTabLoaded(_tab, force: true);
  }

  Future<void> _openRadiologyDeleteDialog(RadiologyCatalogTest item) async {
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final AppLocalizations l10n = context.l10n;
    final bool? deleted = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabDeleteReasonDialog(
        title: l10n.radiologyDisableOfferingDialogTitle,
        body: l10n.radiologyDisableOfferingDialogBody(item.name),
        submitLabel: l10n.clinicalRadiologyDeleteSelectionAction,
        onDelete: (String _) async {
          final Result<void> result = await repository
              .deleteRadiologyCatalogTest(item.apiId);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.labDeletedMessage)),
    );
    await _ensureTabLoaded(_tab, force: true);
  }

  Future<void> _openLabAddDialog(LabCatalogItemType kind) async {
    final String? tenantId = await _resolveTenantIdForCreate();
    if (!mounted || tenantId == null) {
      return;
    }
    final LabRepository repository = ref.read(labRepositoryProvider);
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabCatalogItemMutationDialog(
        kind: kind,
        tenantId: tenantId,
        onSubmit: (Map<String, Object?> payload) async {
          final Result<LabCatalogItem> result = kind == LabCatalogItemType.panel
              ? await repository.createLabPanel(payload)
              : await repository.createLabTest(payload);
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
      SnackBar(content: Text(context.l10n.labSavedMessage)),
    );
    await _ensureTabLoaded(_tab, force: true);
  }

  Future<void> _openLabEditDialog(LabCatalogItem item) async {
    final LabRepository repository = ref.read(labRepositoryProvider);
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabCatalogItemMutationDialog(
        kind: item.type,
        item: item,
        onSubmit: (Map<String, Object?> payload) async {
          final Result<LabCatalogItem> result =
              item.type == LabCatalogItemType.panel
              ? await repository.updateLabPanel(item.apiId, payload)
              : await repository.updateLabTest(item.apiId, payload);
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
    await _ensureTabLoaded(_tab, force: true);
  }

  Future<void> _openLabDeleteDialog(LabCatalogItem item) async {
    final LabRepository repository = ref.read(labRepositoryProvider);
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
              ? await repository.deleteLabPanel(item.apiId, reason)
              : await repository.deleteLabTest(item.apiId, reason);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.labDeletedMessage)),
    );
    await _ensureTabLoaded(_tab, force: true);
  }

  Future<void> _openDiagnosisAddDialog() async {
    final String? tenantId = await _resolveTenantIdForCreate();
    if (!mounted || tenantId == null) {
      return;
    }
    final ClinicalRepository repository = ref.read(clinicalRepositoryProvider);
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DiagnosisCatalogMutationDialog(
        tenantId: tenantId,
        onSubmit: (Map<String, Object?> payload) async {
          final Result<ClinicalCatalogOption> result = await repository
              .createClinicalCatalogTerm(payload);
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
      SnackBar(content: Text(context.l10n.labSavedMessage)),
    );
    await _ensureTabLoaded(_tab, force: true);
  }

  Future<void> _openDiagnosisEditDialog(ClinicalCatalogOption item) async {
    final ClinicalRepository repository = ref.read(clinicalRepositoryProvider);
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DiagnosisCatalogMutationDialog(
        item: item,
        onSubmit: (Map<String, Object?> payload) async {
          final Result<ClinicalCatalogOption> result = await repository
              .updateClinicalCatalogTerm(item.apiId, payload);
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
    await _ensureTabLoaded(_tab, force: true);
  }

  Future<void> _openDiagnosisDeleteDialog(ClinicalCatalogOption item) async {
    final ClinicalRepository repository = ref.read(clinicalRepositoryProvider);
    final AppLocalizations l10n = context.l10n;
    final bool? deleted = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabDeleteReasonDialog(
        title: l10n.clinicalDiagnosisFormTitle,
        body: item.displayTitle,
        submitLabel: l10n.tenantFacilityDeleteAction,
        onDelete: (String _) async {
          final Result<void> result = await repository
              .deleteClinicalCatalogTerm(item.apiId);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.labDeletedMessage)),
    );
    await _ensureTabLoaded(_tab, force: true);
  }

  Future<String?> _resolveTenantIdForCreate() async {
    final String? existing = widget.tenantId?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final TenantFacilityRepository tenantRepo = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final FacilityCatalogScope? scope = await showCatalogFacilityScopePicker(
      context: context,
      loadTenants: () async {
        final Result<AppPage<TenantProfile>> result = await tenantRepo
            .listTenants(request: const AppPageRequest(pageSize: 100));
        return result.when(
          success: (AppPage<TenantProfile> page) => page.items,
          failure: (_) => const <TenantProfile>[],
        );
      },
      loadFacilities: (String tenantId) async {
        final Result<AppPage<FacilityProfile>> result = await tenantRepo
            .listFacilities(
              request: const AppPageRequest(pageSize: 100),
              tenantId: tenantId,
            );
        return result.when(
          success: (AppPage<FacilityProfile> page) => page.items,
          failure: (_) => const <FacilityProfile>[],
        );
      },
    );
    return scope?.tenantId;
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
                return isOffered
                    ? item.copyWith(isOfferedAtFacility: true)
                    : item;
              })
              .toList(growable: false),
        );
      },
      failure: (AppFailure failure) =>
          Result<List<RadiologyCatalogTest>>.failure(failure),
    );
  }
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
