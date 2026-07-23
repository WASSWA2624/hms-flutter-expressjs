import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_layer_selector.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/facility_catalog/facility_catalog_scope.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_dialogs.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/radiology_catalog/radiology_catalog_dialogs.dart';

enum _CatalogDeskTab {
  diagnoses,
  procedures,
  prescriptions,
  lab,
  radiology,
}

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

  final TextEditingController _clinicalSearchController =
      TextEditingController();
  final TextEditingController _labSearchController = TextEditingController();
  final TextEditingController _radiologySearchController =
      TextEditingController();

  _CatalogDeskTab _tab = _CatalogDeskTab.diagnoses;
  List<ClinicalCatalogOption> _clinicalOfferings =
      const <ClinicalCatalogOption>[];
  List<LabCatalogItem> _labOfferings = const <LabCatalogItem>[];
  List<RadiologyCatalogTest> _radiologyOfferings =
      const <RadiologyCatalogTest>[];
  bool _isLoading = false;
  AppFailure? _failure;

  FacilityCatalogScope get _scope => FacilityCatalogScope(
    tenantId: widget.tenantId,
    facilityId: widget.facilityId,
  );

  String get _resolvedCurrency =>
      resolveFacilityDefaultCurrency(widget.defaultCurrency);

  ClinicalCatalogTermType get _clinicalTermType => switch (_tab) {
    _CatalogDeskTab.diagnoses => ClinicalCatalogTermType.diagnosis,
    _CatalogDeskTab.procedures => ClinicalCatalogTermType.procedure,
    _CatalogDeskTab.prescriptions => ClinicalCatalogTermType.prescription,
    _CatalogDeskTab.lab || _CatalogDeskTab.radiology =>
      ClinicalCatalogTermType.diagnosis,
  };

  bool get _isClinicalTab =>
      _tab == _CatalogDeskTab.diagnoses ||
      _tab == _CatalogDeskTab.procedures ||
      _tab == _CatalogDeskTab.prescriptions;

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
    _clinicalSearchController.dispose();
    _labSearchController.dispose();
    _radiologySearchController.dispose();
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
              id: _CatalogDeskTab.diagnoses.name,
              icon: Icons.healing_outlined,
              label: l10n.tenantFacilityCatalogTabDiagnoses,
            ),
            AppTabItem(
              id: _CatalogDeskTab.procedures.name,
              icon: Icons.medical_services_outlined,
              label: l10n.tenantFacilityCatalogTabProcedures,
            ),
            AppTabItem(
              id: _CatalogDeskTab.prescriptions.name,
              icon: Icons.medication_outlined,
              label: l10n.tenantFacilityCatalogTabPrescriptions,
            ),
            AppTabItem(
              id: _CatalogDeskTab.lab.name,
              icon: Icons.biotech_outlined,
              label: l10n.tenantFacilityCatalogTabLab,
            ),
            AppTabItem(
              id: _CatalogDeskTab.radiology.name,
              icon: Icons.image_search_outlined,
              label: l10n.tenantFacilityCatalogTabRadiology,
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
    if (_isClinicalTab) {
      return _buildClinicalTable(l10n);
    }
    if (_tab == _CatalogDeskTab.lab) {
      return _buildLabTable(l10n);
    }
    return _buildRadiologyTable(l10n);
  }

  Widget _buildClinicalTable(AppLocalizations l10n) {
    return AppListTable<ClinicalCatalogOption>(
      items: _clinicalOfferings,
      isLoading: _isLoading,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'setup_catalog_clinical_${_tab.name}',
      search: AppListTableSearch<ClinicalCatalogOption>(
        controller: _clinicalSearchController,
        semanticLabel: l10n.settingsWorkspaceSearchLabel,
        hintText: l10n.tenantFacilityCatalogSearchHint,
        matcher: (ClinicalCatalogOption item, String query) {
          final String haystack =
              '${item.displayTitle} ${item.displaySubtitle ?? ''} '
                      '${item.code ?? ''} ${item.category ?? ''} '
                      '${item.searchText ?? ''}'
                  .toLowerCase();
          return haystack.contains(query.toLowerCase());
        },
        trailingActions: <AppSearchBarAction>[
          if (widget.enabled)
            AppSearchBarAction(
              icon: Icons.add_circle_outline,
              label: l10n.tenantFacilityCatalogAddServiceAction,
              onPressed: () => unawaited(_openClinicalBrowseDialog()),
            ),
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.clinicalCatalogConfigurationTitle,
        body: l10n.tenantFacilityCatalogEmptyOfferings,
        action: widget.enabled
            ? AppButton.primary(
                label: l10n.tenantFacilityCatalogAddServiceAction,
                leadingIcon: Icons.add_circle_outline,
                onPressed: () => unawaited(_openClinicalBrowseDialog()),
              )
            : null,
      ),
      columns: <AppListTableColumn<ClinicalCatalogOption>>[
        AppListTableColumn<ClinicalCatalogOption>(
          id: 'name',
          label: l10n.accessAdminColumnName,
          sortComparator: (ClinicalCatalogOption a, ClinicalCatalogOption b) =>
              a.displayTitle.toLowerCase().compareTo(
                b.displayTitle.toLowerCase(),
              ),
          cellBuilder: (_, ClinicalCatalogOption item) =>
              Text(item.displayTitle),
        ),
        AppListTableColumn<ClinicalCatalogOption>(
          id: 'code',
          label: l10n.labTestCodeLabel,
          sortComparator: (ClinicalCatalogOption a, ClinicalCatalogOption b) =>
              (a.code ?? '').toLowerCase().compareTo(
                (b.code ?? '').toLowerCase(),
              ),
          cellBuilder: (_, ClinicalCatalogOption item) =>
              Text(item.code?.trim().isNotEmpty == true ? item.code! : '—'),
        ),
        AppListTableColumn<ClinicalCatalogOption>(
          id: 'category',
          label: l10n.labCategoryLabel,
          sortComparator: (ClinicalCatalogOption a, ClinicalCatalogOption b) =>
              (a.category ?? '').toLowerCase().compareTo(
                (b.category ?? '').toLowerCase(),
              ),
          cellBuilder: (_, ClinicalCatalogOption item) => Text(
            item.category?.trim().isNotEmpty == true ? item.category! : '—',
          ),
        ),
        AppListTableColumn<ClinicalCatalogOption>(
          id: 'status',
          label: l10n.accessAdminColumnStatus,
          cellBuilder: (_, ClinicalCatalogOption item) => Text(
            item.status?.trim().isNotEmpty == true
                ? item.status!
                : l10n.tenantFacilityStatusActive,
          ),
        ),
      ],
      mobileItemBuilder: (BuildContext context, ClinicalCatalogOption item) {
        return AppListTableMobileItem(
          title: item.displayTitle,
          caption: item.displaySubtitle,
          meta: <AppListTableMobileMeta>[
            if (item.code?.trim().isNotEmpty == true)
              AppListTableMobileMeta(label: item.code!),
            if (item.category?.trim().isNotEmpty == true)
              AppListTableMobileMeta(label: item.category!),
          ],
        );
      },
    );
  }

  Widget _buildLabTable(AppLocalizations l10n) {
    return AppListTable<LabCatalogItem>(
      items: _labOfferings,
      isLoading: _isLoading,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'setup_catalog_lab',
      search: AppListTableSearch<LabCatalogItem>(
        controller: _labSearchController,
        semanticLabel: l10n.clinicalLabRequestSearchLabel,
        hintText: l10n.clinicalLabRequestSearchHint,
        matcher: (LabCatalogItem item, String query) =>
            item.matchesSearch(query),
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
          cellBuilder: (_, LabCatalogItem item) {
            if (item.unitPrice == null) {
              return const Text('—');
            }
            final String currency =
                item.currency?.trim().isNotEmpty == true
                ? item.currency!
                : _resolvedCurrency;
            return Text('$currency ${item.unitPrice}');
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

  Widget _buildRadiologyTable(AppLocalizations l10n) {
    return AppListTable<RadiologyCatalogTest>(
      items: _radiologyOfferings,
      isLoading: _isLoading,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'setup_catalog_radiology',
      onRowSelected: widget.enabled
          ? (RadiologyCatalogTest item) =>
                unawaited(_openRadiologyEditDialog(item))
          : null,
      search: AppListTableSearch<RadiologyCatalogTest>(
        controller: _radiologySearchController,
        semanticLabel: l10n.clinicalRadiologyCatalogSelectTitle,
        hintText: l10n.tenantFacilityCatalogSearchHint,
        matcher: (RadiologyCatalogTest item, String query) {
          final String haystack =
              '${item.name} ${item.code ?? ''} ${item.modality ?? ''} '
                      '${item.bodyRegion ?? ''} ${item.searchText ?? ''}'
                  .toLowerCase();
          return haystack.contains(query.toLowerCase());
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
        title: l10n.tenantFacilityCatalogTabRadiology,
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
          cellBuilder: (_, RadiologyCatalogTest item) {
            if (item.unitPrice == null) {
              return const Text('—');
            }
            final String currency =
                item.currency?.trim().isNotEmpty == true
                ? item.currency!
                : _resolvedCurrency;
            return Text('$currency ${item.unitPrice}');
          },
        ),
        if (widget.enabled)
          AppListTableColumn<RadiologyCatalogTest>(
            id: 'actions',
            label: l10n.accessAdminColumnActions,
            cellBuilder: (BuildContext context, RadiologyCatalogTest item) {
              return AppButton.tertiary(
                label: l10n.clinicalLabRequestEditSelectionAction,
                leadingIcon: Icons.edit_outlined,
                onPressed: () => unawaited(_openRadiologyEditDialog(item)),
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

  Future<void> _reloadCurrentTab() async {
    if (_isClinicalTab) {
      await _loadClinicalOfferings();
      return;
    }
    if (_tab == _CatalogDeskTab.lab) {
      await _loadLabOfferings();
      return;
    }
    await _loadRadiologyOfferings();
  }

  Future<void> _loadClinicalOfferings() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final Result<List<ClinicalCatalogOption>> result = await ref
        .read(clinicalRepositoryProvider)
        .searchClinicalCatalog(
          termType: _clinicalTermType.apiValue,
          limit: _searchLimit,
          source: ClinicalCatalogSource.facility.apiValue,
          offeredOnly: true,
          facilityId: widget.facilityId,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _clinicalOfferings = result.when(
        success: (List<ClinicalCatalogOption> value) => value,
        failure: (_) => const <ClinicalCatalogOption>[],
      );
      _failure = result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      _isLoading = false;
    });
  }

  Future<void> _loadLabOfferings() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _failure = null;
    });
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
    if (!mounted) {
      return;
    }
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
    setState(() {
      _labOfferings = merged;
      _failure = failure;
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
    final Result<List<RadiologyCatalogTest>> result = await ref
        .read(radiologyRepositoryProvider)
        .listFacilityRadiologyTests(
          tenantId: widget.tenantId,
          facilityId: widget.facilityId,
          offeredOnly: true,
          limit: _searchLimit,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _radiologyOfferings = result.when(
        success: (List<RadiologyCatalogTest> value) => value,
        failure: (_) => const <RadiologyCatalogTest>[],
      );
      _failure = result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      _isLoading = false;
    });
  }

  Future<void> _openClinicalBrowseDialog() async {
    final bool? added = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _ClinicalCatalogBrowseDialog(
        facilityId: widget.facilityId,
        termType: _clinicalTermType,
        enabled: widget.enabled,
      ),
    );
    if (!mounted || added != true) {
      return;
    }
    await _loadClinicalOfferings();
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
    await _loadLabOfferings();
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
    await _loadRadiologyOfferings();
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
    await _loadRadiologyOfferings();
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

class _ClinicalCatalogBrowseDialog extends ConsumerStatefulWidget {
  const _ClinicalCatalogBrowseDialog({
    required this.facilityId,
    required this.termType,
    required this.enabled,
  });

  final String facilityId;
  final ClinicalCatalogTermType termType;
  final bool enabled;

  @override
  ConsumerState<_ClinicalCatalogBrowseDialog> createState() =>
      _ClinicalCatalogBrowseDialogState();
}

class _ClinicalCatalogBrowseDialogState
    extends ConsumerState<_ClinicalCatalogBrowseDialog> {
  static const int _searchLimit = 40;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  ClinicalCatalogSource _catalogSource = ClinicalCatalogSource.global;
  List<ClinicalCatalogOption> _results = const <ClinicalCatalogOption>[];
  final Set<String> _addedIds = <String>{};
  bool _isSearching = false;
  bool _didAdd = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_searchCatalog(''));
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.tenantFacilityCatalogBrowseTitle),
      icon: const Icon(Icons.manage_search_outlined),
      scrollable: true,
      maxWidth: 840,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          ClinicalCatalogLayerSelector(
            value: _catalogSource,
            enabled: widget.enabled,
            onChanged: (ClinicalCatalogSource source) {
              setState(() => _catalogSource = source);
              unawaited(_searchCatalog(_searchController.text));
            },
          ),
          SizedBox(height: theme.spacing.sm),
          AppTextField(
            controller: _searchController,
            labelText: l10n.settingsWorkspaceSearchLabel,
            enabled: widget.enabled,
            prefixIcon: const Icon(Icons.manage_search_outlined),
            onChanged: _scheduleSearch,
          ),
          if (_isSearching) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            const LinearProgressIndicator(),
          ],
          SizedBox(height: theme.spacing.md),
          if (_results.isEmpty)
            Text(l10n.settingsWorkspaceEmptyStatus)
          else
            for (final ClinicalCatalogOption option in _results)
              ListTile(
                dense: true,
                title: Text(option.displayTitle),
                subtitle: option.displaySubtitle == null
                    ? null
                    : Text(option.displaySubtitle!),
                trailing: AppButton.secondary(
                  label: _addedIds.contains(option.apiId)
                      ? l10n.tenantFacilityStatusActive
                      : l10n.clinicalLabRequestAddSelectionAction,
                  enabled:
                      widget.enabled && !_addedIds.contains(option.apiId),
                  onPressed: () => unawaited(_addOffering(option)),
                ),
              ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(_didAdd),
        ),
      ],
    );
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) {
        return;
      }
      unawaited(_searchCatalog(value));
    });
  }

  Future<void> _searchCatalog(String query) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSearching = true;
      _failure = null;
    });
    final Result<List<ClinicalCatalogOption>> result = await ref
        .read(clinicalRepositoryProvider)
        .searchClinicalCatalog(
          termType: widget.termType.apiValue,
          query: query.trim().isEmpty ? null : query.trim(),
          limit: _searchLimit,
          source: _catalogSource.apiValue,
          facilityId: widget.facilityId,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _results = result.when(
        success: (List<ClinicalCatalogOption> value) => value,
        failure: (_) => const <ClinicalCatalogOption>[],
      );
      _failure = result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      _isSearching = false;
    });
  }

  Future<void> _addOffering(ClinicalCatalogOption option) async {
    if (!widget.enabled) {
      return;
    }
    final Result<void> result = await ref
        .read(clinicalRepositoryProvider)
        .upsertFacilityCatalogOffering(<String, Object?>{
          'facility_id': widget.facilityId,
          'term_type': widget.termType.apiValue,
          'item_id': option.id,
        });
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) {
        setState(() {
          _didAdd = true;
          _addedIds.add(option.apiId);
        });
      },
      failure: (AppFailure failure) {
        setState(() => _failure = failure);
      },
    );
  }
}
