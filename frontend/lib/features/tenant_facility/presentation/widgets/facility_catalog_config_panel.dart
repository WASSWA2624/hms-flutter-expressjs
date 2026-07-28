import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
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
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/facility_catalog/clinical_catalog_admin_dialogs.dart';
import 'package:hosspi_hms/shared/facility_catalog/clinical_catalog_configure_visibility.dart';
import 'package:hosspi_hms/shared/facility_catalog/facility_catalog_scope.dart';
import 'package:hosspi_hms/shared/facility_catalog/lab_catalog_mutate_visibility.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_details_dialog.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_dialogs.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_fields.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_offering_match.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/management/platform_management_list_sync.dart';
import 'package:hosspi_hms/shared/radiology_catalog/radiology_catalog_details_dialog.dart';
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
  static const int _pageSize = 40;
  static const int _radiologyFetchLimit = 7500;
  static const int _labFetchLimit = 7500;
  static const int _diagnosisFetchLimit = 1000;
  static const String _labTypeFilterKey = 'type';
  static const String _labCategoryFilterKey = 'category';
  static const String _labResultKindFilterKey = 'result_kind';
  static const String _labSpecimenFilterKey = 'specimen_type';
  static const String _labSourceFilterKey = 'source';
  static const String _modalityFilterKey = 'modality';
  static const String _diagnosisCategoryFilterKey = 'category';

  final TextEditingController _labSearchController = TextEditingController();
  final TextEditingController _radiologySearchController =
      TextEditingController();
  final TextEditingController _diagnosisSearchController =
      TextEditingController();

  _CatalogDeskTab _tab = _CatalogDeskTab.radiology;
  List<LabCatalogItem> _labItems = const <LabCatalogItem>[];
  List<RadiologyCatalogProcedure> _radiologyItems = const <RadiologyCatalogProcedure>[];
  List<ClinicalCatalogOption> _diagnosisItems = const <ClinicalCatalogOption>[];
  List<LabCatalogItem> _labVisibleItems = const <LabCatalogItem>[];
  List<RadiologyCatalogProcedure> _radiologyVisibleItems =
      const <RadiologyCatalogProcedure>[];
  List<ClinicalCatalogOption> _diagnosisVisibleItems =
      const <ClinicalCatalogOption>[];
  AppSearchBarFilterValue _labFilterValue = AppSearchBarFilterValue.empty;
  AppSearchBarFilterValue _radiologyFilterValue = AppSearchBarFilterValue.empty;
  AppSearchBarFilterValue _diagnosisFilterValue = AppSearchBarFilterValue.empty;
  bool _radiologyHydrated = false;
  bool _labHydrated = false;
  bool _diagnosisHydrated = false;
  bool _radiologyLoading = false;
  bool _labLoading = false;
  bool _diagnosisLoading = false;
  bool _radiologyLoadInFlight = false;
  bool _labLoadInFlight = false;
  bool _diagnosisLoadInFlight = false;
  List<String> _radiologyModalities = const <String>[];
  List<String> _labCategories = const <String>[];
  List<String> _labResultKinds = const <String>[];
  List<String> _labSpecimenTypes = const <String>[];
  List<String> _labSources = const <String>[];
  List<String> _diagnosisCategories = const <String>[];
  AppFailure? _radiologyFailure;
  AppFailure? _labFailure;
  AppFailure? _diagnosisFailure;
  PlatformManagementListSync? _radiologyRealtimeSync;
  PlatformManagementListSync? _labRealtimeSync;
  int _radiologyMutationDepth = 0;
  int _labMutationDepth = 0;

  static const Set<String> _radiologyCatalogRealtimeEvents = <String>{
    RealtimeEvents.radiologyCatalogUpdated,
  };

  static const Set<String> _labCatalogRealtimeEvents = <String>{
    RealtimeEvents.labCatalogUpdated,
  };

  String get _resolvedCurrency =>
      resolveFacilityDefaultCurrency(widget.defaultCurrency);

  AppFailure? get _activeFailure => switch (_tab) {
    _CatalogDeskTab.radiology => _radiologyFailure,
    _CatalogDeskTab.lab => _labFailure,
    _CatalogDeskTab.diagnoses => _diagnosisFailure,
  };

  List<LabCatalogItem> _computeFilteredLabItems() {
    final String? type = _labFilterValue.option(_labTypeFilterKey);
    final String? category = _labFilterValue.option(_labCategoryFilterKey);
    final String? resultKind = _labFilterValue.option(_labResultKindFilterKey);
    final String? specimen = _labFilterValue.option(_labSpecimenFilterKey);
    final String? source = _labFilterValue.option(_labSourceFilterKey);
    return _labItems.where((LabCatalogItem item) {
      if (type != null && type.isNotEmpty && item.type.name != type) {
        return false;
      }
      if (category != null &&
          category.isNotEmpty &&
          (item.category ?? '').trim() != category) {
        return false;
      }
      if (resultKind != null &&
          resultKind.isNotEmpty &&
          item.type == LabCatalogItemType.test &&
          (item.resultKind ?? '').trim().toUpperCase() !=
              resultKind.toUpperCase()) {
        return false;
      }
      if (specimen != null &&
          specimen.isNotEmpty &&
          (item.specimenType ?? '').trim() != specimen) {
        return false;
      }
      if (source != null &&
          source.isNotEmpty &&
          (item.source ?? '').trim() != source) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  List<RadiologyCatalogProcedure> _computeFilteredRadiologyItems() {
    final String? modality = _radiologyFilterValue.option(_modalityFilterKey);
    if (modality == null || modality.isEmpty) {
      return _radiologyItems;
    }
    return _radiologyItems
        .where(
          (RadiologyCatalogProcedure item) =>
              (item.modality ?? '').trim() == modality,
        )
        .toList(growable: false);
  }

  List<ClinicalCatalogOption> _computeFilteredDiagnosisItems() {
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

  List<String> _uniqueSortedFieldValues(
    Iterable<String?> values,
  ) {
    final List<String> result = values
        .map((String? value) => (value ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return result;
  }

  void _refreshRadiologyFilterOptions() {
    _radiologyModalities = _uniqueSortedFieldValues(
      _radiologyItems.map((RadiologyCatalogProcedure item) => item.modality),
    );
  }

  void _refreshLabFilterOptions() {
    _labCategories = _uniqueSortedFieldValues(
      _labItems.map((LabCatalogItem item) => item.category),
    );
    _labResultKinds = _uniqueSortedFieldValues(<String?>[
      'NUMERIC',
      'QUALITATIVE',
      'TEXT',
      for (final LabCatalogItem item in _labItems)
        if (item.type == LabCatalogItemType.test) item.resultKind,
    ]);
    _labSpecimenTypes = _uniqueSortedFieldValues(
      _labItems.map((LabCatalogItem item) => item.specimenType),
    );
    _labSources = _uniqueSortedFieldValues(
      _labItems.map((LabCatalogItem item) => item.source),
    );
  }

  void _refreshDiagnosisFilterOptions() {
    _diagnosisCategories = _uniqueSortedFieldValues(
      _diagnosisItems.map((ClinicalCatalogOption item) => item.category),
    );
  }

  void _recomputeRadiologyVisible() {
    final String query = _radiologySearchController.text.trim().toLowerCase();
    final List<RadiologyCatalogProcedure> filtered = _computeFilteredRadiologyItems();
    if (query.isEmpty) {
      _radiologyVisibleItems = filtered;
      return;
    }
    _radiologyVisibleItems = filtered
        .where((RadiologyCatalogProcedure item) {
          final String haystack =
              '${item.name} ${item.code ?? ''} ${item.modality ?? ''}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _recomputeLabVisible() {
    final List<LabCatalogItem> filtered = _computeFilteredLabItems();
    final String query = _labSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _labVisibleItems = filtered;
      return;
    }
    final List<LabCatalogItem> matched = filtered
        .where((LabCatalogItem item) => _labDeskSearchMatches(item, query))
        .toList();
    matched.sort((LabCatalogItem left, LabCatalogItem right) {
      final int rankCompare = _labDeskSearchRank(
        left,
        query,
      ).compareTo(_labDeskSearchRank(right, query));
      if (rankCompare != 0) {
        return rankCompare;
      }
      return left.displayTitle.toLowerCase().compareTo(
        right.displayTitle.toLowerCase(),
      );
    });
    _labVisibleItems = matched;
  }

  bool _labDeskSearchMatches(LabCatalogItem item, String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    // Name/code/category/id only — descriptions like "Pregnancy testing bundle"
    // must not drown out an exact catalog name such as "testing".
    final String haystack = <String?>[
      item.name,
      item.code,
      item.category,
      item.displayId,
      item.id,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(needle);
  }

  int _labDeskSearchRank(LabCatalogItem item, String query) {
    final String needle = query.trim().toLowerCase();
    final String name = (item.name ?? '').trim().toLowerCase();
    final String code = (item.code ?? '').trim().toLowerCase();
    if (name == needle || code == needle) {
      return 0;
    }
    if (name.startsWith(needle) || code.startsWith(needle)) {
      return 1;
    }
    final RegExp word = RegExp('\\b${RegExp.escape(needle)}\\b');
    if (word.hasMatch(name) || word.hasMatch(code)) {
      return 2;
    }
    return 3;
  }

  void _recomputeDiagnosisVisible() {
    final String query = _diagnosisSearchController.text.trim().toLowerCase();
    final List<ClinicalCatalogOption> filtered =
        _computeFilteredDiagnosisItems();
    if (query.isEmpty) {
      _diagnosisVisibleItems = filtered;
      return;
    }
    _diagnosisVisibleItems = filtered
        .where((ClinicalCatalogOption item) {
          final String haystack =
              '${item.name ?? ''} ${item.code ?? ''} ${item.category ?? ''}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _onRadiologySearchChanged() {
    if (!mounted) {
      return;
    }
    setState(_recomputeRadiologyVisible);
  }

  void _onLabSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(_recomputeLabVisible);
  }

  void _onDiagnosisSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(_recomputeDiagnosisVisible);
  }

  @override
  void initState() {
    super.initState();
    _radiologySearchController.addListener(_onRadiologySearchChanged);
    _labSearchController.addListener(_onLabSearchChanged);
    _diagnosisSearchController.addListener(_onDiagnosisSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_ensureTabLoaded(_tab, prefetchSiblings: false));
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
      unawaited(_ensureTabLoaded(_tab, force: true, prefetchSiblings: false));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _radiologyRealtimeSync ??= PlatformManagementListSync(
      ref: ref,
      events: _radiologyCatalogRealtimeEvents,
      onMutated: () {},
      reload: ({bool silent = false, RealtimeMessage? message}) async {
        if (_radiologyMutationDepth > 0) {
          return;
        }
        final bool applied = _applyRadiologyCatalogRealtimeMessage(message);
        if (!applied || !_radiologyHydrated) {
          await _loadRadiologyItems(force: true);
        }
      },
    )..attach();
    _labRealtimeSync ??= PlatformManagementListSync(
      ref: ref,
      events: _labCatalogRealtimeEvents,
      onMutated: () {},
      reload: ({bool silent = false, RealtimeMessage? message}) async {
        if (_labMutationDepth > 0) {
          return;
        }
        final bool applied = _applyLabCatalogRealtimeMessage(message);
        if (!applied || !_labHydrated) {
          await _loadLabItems(force: true);
        }
      },
    )..attach();
  }

  @override
  void dispose() {
    _radiologyRealtimeSync?.dispose();
    _labRealtimeSync?.dispose();
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
            setState(() => _tab = next);
            // Data is usually already warm; this is a no-op when hydrated.
            unawaited(_ensureTabLoaded(next, prefetchSiblings: false));
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
        Expanded(
          child: KeyedSubtree(
            key: ValueKey<_CatalogDeskTab>(_tab),
            child: _buildTableForTab(l10n, _tab),
          ),
        ),
      ],
    );
  }

  Widget _buildTableForTab(AppLocalizations l10n, _CatalogDeskTab tab) {
    return switch (tab) {
      _CatalogDeskTab.radiology => _buildRadiologyTable(l10n),
      _CatalogDeskTab.lab => _buildLabTable(l10n),
      _CatalogDeskTab.diagnoses => _buildDiagnosisTable(l10n),
    };
  }

  Widget _wrappedCellText(String value) {
    return Text(value, softWrap: true);
  }

  String _dashOr(String? value) {
    final String trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  String _labResultKindLabel(AppLocalizations l10n, String? value) {
    return switch ((value ?? '').toUpperCase()) {
      'NUMERIC' => l10n.labResultKindNumeric,
      'QUALITATIVE' => l10n.labResultKindQualitative,
      'TEXT' => l10n.labResultKindText,
      _ => _dashOr(value),
    };
  }

  String _labUnitRangeOrTestCount(
    AppLocalizations l10n,
    LabCatalogItem item,
  ) {
    if (item.type == LabCatalogItemType.panel) {
      return l10n.clinicalLabOrderItemCount(item.testCount);
    }
    final int rangeCount = item.referenceRangeCount > 0
        ? item.referenceRangeCount
        : item.referenceRanges.length;
    final List<String> parts = <String>[
      if ((item.unit ?? '').trim().isNotEmpty) item.unit!.trim(),
      if (rangeCount > 0)
        l10n.labReferenceRangeCount(rangeCount)
      else if ((item.referenceRange ?? '').trim().isNotEmpty)
        item.referenceRange!.trim(),
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  List<AppListTableColumn<RadiologyCatalogProcedure>> _radiologyColumnChoices(
    AppLocalizations l10n,
  ) {
    return <AppListTableColumn<RadiologyCatalogProcedure>>[
      AppListTableColumn<RadiologyCatalogProcedure>(
        id: 'body_region',
        label: l10n.radiologyBodyRegionLabel,
        sortComparator: (RadiologyCatalogProcedure a, RadiologyCatalogProcedure b) =>
            appListTableCompareText(a.bodyRegion, b.bodyRegion),
        cellBuilder: (_, RadiologyCatalogProcedure item) =>
            _wrappedCellText(_dashOr(item.bodyRegion)),
      ),
      AppListTableColumn<RadiologyCatalogProcedure>(
        id: 'laterality',
        label: l10n.radiologyLateralityLabel,
        sortComparator: (RadiologyCatalogProcedure a, RadiologyCatalogProcedure b) =>
            appListTableCompareText(a.laterality, b.laterality),
        cellBuilder: (_, RadiologyCatalogProcedure item) =>
            _wrappedCellText(_dashOr(item.laterality)),
      ),
      AppListTableColumn<RadiologyCatalogProcedure>(
        id: 'procedure_type',
        label: l10n.clinicalResultsModuleProcedureLabel,
        sortComparator: (RadiologyCatalogProcedure a, RadiologyCatalogProcedure b) =>
            appListTableCompareText(a.procedureType, b.procedureType),
        cellBuilder: (_, RadiologyCatalogProcedure item) =>
            _wrappedCellText(_dashOr(item.procedureType)),
      ),
      AppListTableColumn<RadiologyCatalogProcedure>(
        id: 'equipment',
        label: l10n.radiologyEquipmentColumnLabel,
        sortComparator: (RadiologyCatalogProcedure a, RadiologyCatalogProcedure b) =>
            appListTableCompareText(a.equipment, b.equipment),
        cellBuilder: (_, RadiologyCatalogProcedure item) =>
            _wrappedCellText(_dashOr(item.equipment)),
      ),
      AppListTableColumn<RadiologyCatalogProcedure>(
        id: 'status',
        label: l10n.radiologyStatusColumnLabel,
        sortComparator: (RadiologyCatalogProcedure a, RadiologyCatalogProcedure b) =>
            appListTableCompareText(a.status, b.status),
        cellBuilder: (_, RadiologyCatalogProcedure item) =>
            _wrappedCellText(_dashOr(item.status)),
      ),
      AppListTableColumn<RadiologyCatalogProcedure>(
        id: 'source',
        label: l10n.radiologySourceColumnLabel,
        sortComparator: (RadiologyCatalogProcedure a, RadiologyCatalogProcedure b) =>
            appListTableCompareText(a.source, b.source),
        cellBuilder: (_, RadiologyCatalogProcedure item) =>
            _wrappedCellText(_dashOr(item.source)),
      ),
    ];
  }

  List<AppListTableColumn<LabCatalogItem>> _labColumnChoices(
    AppLocalizations l10n,
  ) {
    return <AppListTableColumn<LabCatalogItem>>[
      AppListTableColumn<LabCatalogItem>(
        id: 'specimen',
        label: l10n.labSpecimenTypeLabel,
        sortComparator: (LabCatalogItem a, LabCatalogItem b) =>
            appListTableCompareText(a.specimenType, b.specimenType),
        cellBuilder: (_, LabCatalogItem item) =>
            _wrappedCellText(_dashOr(item.specimenType)),
      ),
      AppListTableColumn<LabCatalogItem>(
        id: 'result_kind',
        label: l10n.labResultKindLabel,
        sortComparator: (LabCatalogItem a, LabCatalogItem b) =>
            appListTableCompareText(a.resultKind, b.resultKind),
        cellBuilder: (_, LabCatalogItem item) =>
            _wrappedCellText(_labResultKindLabel(l10n, item.resultKind)),
      ),
      AppListTableColumn<LabCatalogItem>(
        id: 'unit_range',
        label: l10n.labUnitRangeCountColumnLabel,
        sortComparator: (LabCatalogItem a, LabCatalogItem b) =>
            appListTableCompareText(
              _labUnitRangeOrTestCount(l10n, a),
              _labUnitRangeOrTestCount(l10n, b),
            ),
        cellBuilder: (_, LabCatalogItem item) =>
            _wrappedCellText(_labUnitRangeOrTestCount(l10n, item)),
      ),
      AppListTableColumn<LabCatalogItem>(
        id: 'tests_count',
        label: l10n.labTestsColumnLabel,
        sortComparator: (LabCatalogItem a, LabCatalogItem b) =>
            a.testCount.compareTo(b.testCount),
        cellBuilder: (_, LabCatalogItem item) => _wrappedCellText(
          item.type == LabCatalogItemType.panel
              ? l10n.clinicalLabOrderItemCount(item.testCount)
              : '—',
        ),
      ),
      AppListTableColumn<LabCatalogItem>(
        id: 'description',
        label: l10n.labPanelDescriptionLabel,
        sortComparator: (LabCatalogItem a, LabCatalogItem b) =>
            appListTableCompareText(a.description, b.description),
        cellBuilder: (_, LabCatalogItem item) =>
            _wrappedCellText(_dashOr(item.description)),
      ),
    ];
  }

  List<AppListTableColumn<ClinicalCatalogOption>> _diagnosisColumnChoices(
    AppLocalizations l10n,
  ) {
    return <AppListTableColumn<ClinicalCatalogOption>>[
      AppListTableColumn<ClinicalCatalogOption>(
        id: 'status',
        label: l10n.accessAdminColumnStatus,
        sortComparator: (ClinicalCatalogOption a, ClinicalCatalogOption b) =>
            appListTableCompareText(a.status, b.status),
        cellBuilder: (_, ClinicalCatalogOption item) =>
            _wrappedCellText(_dashOr(item.status)),
      ),
      AppListTableColumn<ClinicalCatalogOption>(
        id: 'details',
        label: l10n.accessAdminColumnDetails,
        sortComparator: (ClinicalCatalogOption a, ClinicalCatalogOption b) =>
            appListTableCompareText(a.secondaryText, b.secondaryText),
        cellBuilder: (_, ClinicalCatalogOption item) =>
            _wrappedCellText(_dashOr(item.secondaryText)),
      ),
    ];
  }

  Widget _buildRadiologyTable(AppLocalizations l10n) {
    final bool canMutateRadiology = _canMutateRadiologyCatalog;
    return AppListTable<RadiologyCatalogProcedure>(
      items: _radiologyVisibleItems,
      maxVisibleItems: _pageSize,
      isLoading: _radiologyLoading && _radiologyItems.isEmpty,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'admin_catalog_radiology',
      columnChoices: _radiologyColumnChoices(l10n),
      onRowSelected: canMutateRadiology
          ? (RadiologyCatalogProcedure item) {
              if (item.isDeleted || item.isStandard) {
                return;
              }
              unawaited(_openRadiologyEditDialog(item));
            }
          : null,
      search: AppListTableSearch<RadiologyCatalogProcedure>(
        controller: _radiologySearchController,
        semanticLabel: l10n.tenantFacilityCatalogTabRadiology,
        hintText: l10n.tenantFacilityCatalogSearchHint,
        matcher: (_, _) => true,
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.radiologyModalityLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        enableDateFilter: false,
        filterGroups: <AppSearchBarFilterGroup>[
          if (_radiologyModalities.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _modalityFilterKey,
              label: l10n.radiologyModalityLabel,
              allLabel: l10n.commonAllLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final String m in _radiologyModalities)
                  AppSearchBarFilterChoice(value: m, label: m),
              ],
            ),
        ],
        filterValue: _radiologyFilterValue,
        hasActiveFilters: _radiologyFilterValue.isActive,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() {
            _radiologyFilterValue = value;
            _recomputeRadiologyVisible();
          });
        },
        trailingActions: <AppSearchBarAction>[
          if (widget.enabled)
            AppSearchBarAction(
              icon: Icons.settings_suggest_outlined,
              label: l10n.tenantFacilityCatalogConfigureAction,
              onPressed: () => unawaited(_openConfigureFlow()),
            ),
          if (canMutateRadiology)
            AppSearchBarAction(
              icon: Icons.add_circle_outline,
              label: l10n.radiologyCreateProcedureAction,
              onPressed: () => unawaited(_openRadiologyAddDialog()),
            ),
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilityCatalogTabRadiology,
        body: l10n.tenantFacilityCatalogEmptyCatalog,
        action: canMutateRadiology
            ? AppButton.primary(
                label: l10n.radiologyCreateProcedureAction,
                leadingIcon: Icons.add_circle_outline,
                onPressed: () => unawaited(_openRadiologyAddDialog()),
              )
            : null,
      ),
      columns: <AppListTableColumn<RadiologyCatalogProcedure>>[
        AppListTableColumn<RadiologyCatalogProcedure>(
          id: 'name',
          label: l10n.radiologyProcedureNameLabel,
          sortComparator: (RadiologyCatalogProcedure a, RadiologyCatalogProcedure b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          cellBuilder: (_, RadiologyCatalogProcedure item) =>
              _wrappedCellText(item.name),
        ),
        AppListTableColumn<RadiologyCatalogProcedure>(
          id: 'code',
          label: l10n.labTestCodeLabel,
          sortComparator: (RadiologyCatalogProcedure a, RadiologyCatalogProcedure b) =>
              (a.code ?? '').toLowerCase().compareTo(
                (b.code ?? '').toLowerCase(),
              ),
          cellBuilder: (_, RadiologyCatalogProcedure item) => _wrappedCellText(
            item.code?.trim().isNotEmpty == true ? item.code! : '—',
          ),
        ),
        AppListTableColumn<RadiologyCatalogProcedure>(
          id: 'modality',
          label: l10n.radiologyModalityLabel,
          sortComparator: (RadiologyCatalogProcedure a, RadiologyCatalogProcedure b) =>
              (a.modality ?? '').toLowerCase().compareTo(
                (b.modality ?? '').toLowerCase(),
              ),
          cellBuilder: (_, RadiologyCatalogProcedure item) => _wrappedCellText(
            item.modality?.trim().isNotEmpty == true ? item.modality! : '—',
          ),
        ),
        AppListTableColumn<RadiologyCatalogProcedure>(
          id: 'deletion_status',
          label: l10n.radiologyDeletionStatusColumnLabel,
          sortComparator: (RadiologyCatalogProcedure a, RadiologyCatalogProcedure b) =>
              a.isDeleted == b.isDeleted
                  ? 0
                  : (a.isDeleted ? 1 : -1),
          cellBuilder: (_, RadiologyCatalogProcedure item) => _wrappedCellText(
            item.isDeleted
                ? l10n.radiologyDeletionStatusSoftDeleted
                : l10n.radiologyDeletionStatusActive,
          ),
        ),
        if (canMutateRadiology)
          AppListTableColumn<RadiologyCatalogProcedure>(
            id: 'actions',
            label: l10n.accessAdminColumnActions,
            alwaysVisible: true,
            cellBuilder: (BuildContext context, RadiologyCatalogProcedure item) =>
                _CatalogRowActions(
                  editLabel: l10n.clinicalLabRequestEditSelectionAction,
                  deleteLabel: l10n.clinicalRadiologyDeleteSelectionAction,
                  restoreLabel: l10n.radiologyRestoreProcedureAction,
                  permanentDeleteLabel:
                      l10n.radiologyPermanentDeleteProcedureAction,
                  isDeleted: item.isDeleted,
                  onEdit: item.isDeleted || item.isStandard
                      ? null
                      : () => unawaited(_openRadiologyEditDialog(item)),
                  onDelete: item.isDeleted || item.isStandard
                      ? null
                      : () => unawaited(_openRadiologyDeleteDialog(item)),
                  onRestore: item.isDeleted && !item.isStandard
                      ? () => unawaited(_openRadiologyRestoreDialog(item))
                      : null,
                  onPermanentDelete: item.isDeleted && !item.isStandard
                      ? () =>
                            unawaited(_openRadiologyPermanentDeleteDialog(item))
                      : null,
                ),
          ),
      ],
      mobileItemBuilder: (BuildContext context, RadiologyCatalogProcedure item) =>
          AppListTableMobileItem(
            title: item.name,
            caption: item.modality,
            meta: <AppListTableMobileMeta>[
              if (item.code?.trim().isNotEmpty == true)
                AppListTableMobileMeta(label: item.code!),
              AppListTableMobileMeta(
                label: item.isDeleted
                    ? l10n.radiologyDeletionStatusSoftDeleted
                    : l10n.radiologyDeletionStatusActive,
              ),
            ],
          ),
    );
  }

  Widget _buildLabTable(AppLocalizations l10n) {
    final bool canMutateLab = labCatalogMutateControlsVisible(
      panelEnabled: widget.enabled,
      canMutateLabCatalog: _canMutateLabCatalog,
    );
    return AppListTable<LabCatalogItem>(
      items: _labVisibleItems,
      maxVisibleItems: _pageSize,
      isLoading: _labLoading && _labItems.isEmpty,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'admin_catalog_lab',
      columnChoices: _labColumnChoices(l10n),
      onRowSelected: (LabCatalogItem item) {
        unawaited(_openLabDetailsDialog(item));
      },
      search: AppListTableSearch<LabCatalogItem>(
        controller: _labSearchController,
        semanticLabel: l10n.tenantFacilityCatalogTabLab,
        hintText: l10n.tenantFacilityCatalogSearchHint,
        matcher: _labDeskSearchMatches,
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
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
          if (_labCategories.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _labCategoryFilterKey,
              label: l10n.labCategoryLabel,
              allLabel: l10n.commonAllLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final String category in _labCategories)
                  AppSearchBarFilterChoice(
                    value: category,
                    label: category,
                    icon: labCatalogCategoryIcon(category),
                  ),
              ],
            ),
          if (_labResultKinds.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _labResultKindFilterKey,
              label: l10n.labResultKindLabel,
              allLabel: l10n.commonAllLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final String kind in _labResultKinds)
                  AppSearchBarFilterChoice(
                    value: kind,
                    label: _labResultKindLabel(l10n, kind),
                  ),
              ],
            ),
          if (_labSpecimenTypes.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _labSpecimenFilterKey,
              label: l10n.labSpecimenTypeLabel,
              allLabel: l10n.commonAllLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final String specimen in _labSpecimenTypes)
                  AppSearchBarFilterChoice(value: specimen, label: specimen),
              ],
            ),
          if (_labSources.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _labSourceFilterKey,
              label: l10n.radiologySourceColumnLabel,
              allLabel: l10n.commonAllLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final String source in _labSources)
                  AppSearchBarFilterChoice(value: source, label: source),
              ],
            ),
        ],
        filterValue: _labFilterValue,
        hasActiveFilters: _labFilterValue.isActive,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() {
            _labFilterValue = value;
            _recomputeLabVisible();
          });
        },
        trailingActions: <AppSearchBarAction>[
          if (widget.enabled) ...<AppSearchBarAction>[
            AppSearchBarAction(
              icon: Icons.settings_suggest_outlined,
              label: l10n.tenantFacilityCatalogConfigureAction,
              onPressed: () => unawaited(_openConfigureFlow()),
            ),
            if (canMutateLab) ...<AppSearchBarAction>[
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
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilityCatalogTabLab,
        body: l10n.tenantFacilityCatalogEmptyCatalog,
        action: canMutateLab
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
          cellBuilder: (_, LabCatalogItem item) =>
              _wrappedCellText(item.displayTitle),
        ),
        AppListTableColumn<LabCatalogItem>(
          id: 'type',
          label: l10n.clinicalRequestSelectedTypeColumnLabel,
          sortComparator: (LabCatalogItem a, LabCatalogItem b) =>
              a.type.name.compareTo(b.type.name),
          cellBuilder: (_, LabCatalogItem item) => _wrappedCellText(
            item.type == LabCatalogItemType.panel
                ? l10n.clinicalLabRequestPanelTypeLabel
                : l10n.clinicalLabRequestTestTypeLabel,
          ),
        ),
        AppListTableColumn<LabCatalogItem>(
          id: 'code',
          label: l10n.labTestCodeLabel,
          sortComparator: (LabCatalogItem a, LabCatalogItem b) =>
              (a.code ?? '').toLowerCase().compareTo(
                (b.code ?? '').toLowerCase(),
              ),
          cellBuilder: (_, LabCatalogItem item) => _wrappedCellText(
            item.code?.trim().isNotEmpty == true ? item.code! : '—',
          ),
        ),
        AppListTableColumn<LabCatalogItem>(
          id: 'category',
          label: l10n.labCategoryLabel,
          sortComparator: (LabCatalogItem a, LabCatalogItem b) =>
              (a.category ?? '').toLowerCase().compareTo(
                (b.category ?? '').toLowerCase(),
              ),
          cellBuilder: (_, LabCatalogItem item) => _wrappedCellText(
            item.category?.trim().isNotEmpty == true ? item.category! : '—',
          ),
        ),
        if (canMutateLab)
          AppListTableColumn<LabCatalogItem>(
            id: 'actions',
            label: l10n.accessAdminColumnActions,
            alwaysVisible: true,
            cellBuilder: (BuildContext context, LabCatalogItem item) =>
                _CatalogRowActions(
                  editLabel: l10n.clinicalLabRequestEditSelectionAction,
                  deleteLabel: l10n.tenantFacilityDeleteAction,
                  onEdit: item.isStandard
                      ? null
                      : () => unawaited(_openLabEditDialog(item)),
                  onDelete: item.isStandard
                      ? null
                      : () => unawaited(_openLabDeleteDialog(item)),
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
    final bool canConfigureDiagnoses = clinicalCatalogConfigureVisible(
      panelEnabled: widget.enabled,
      canMutateClinicalCatalog: _canMutateClinicalCatalog,
    );
    return AppListTable<ClinicalCatalogOption>(
      items: _diagnosisVisibleItems,
      maxVisibleItems: _pageSize,
      isLoading: _diagnosisLoading && _diagnosisItems.isEmpty,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityStorageKey: 'admin_catalog_diagnoses',
      columnChoices: _diagnosisColumnChoices(l10n),
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
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.labCategoryLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        enableDateFilter: false,
        filterGroups: <AppSearchBarFilterGroup>[
          if (_diagnosisCategories.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _diagnosisCategoryFilterKey,
              label: l10n.labCategoryLabel,
              allLabel: l10n.commonAllLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final String category in _diagnosisCategories)
                  AppSearchBarFilterChoice(value: category, label: category),
              ],
            ),
        ],
        filterValue: _diagnosisFilterValue,
        hasActiveFilters: _diagnosisFilterValue.isActive,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() {
            _diagnosisFilterValue = value;
            _recomputeDiagnosisVisible();
          });
        },
        trailingActions: <AppSearchBarAction>[
          if (canConfigureDiagnoses)
            AppSearchBarAction(
              icon: Icons.settings_suggest_outlined,
              label: l10n.tenantFacilityCatalogConfigureAction,
              onPressed: () => unawaited(_openConfigureFlow()),
            ),
          if (widget.enabled)
            AppSearchBarAction(
              icon: Icons.add_circle_outline,
              label: l10n.clinicalCreateDiagnosisAction,
              onPressed: () => unawaited(_openDiagnosisAddDialog()),
            ),
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilityCatalogTabDiagnoses,
        body: l10n.tenantFacilityCatalogEmptyCatalog,
        action: widget.enabled
            ? AppButton.primary(
                label: l10n.clinicalCreateDiagnosisAction,
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
              _wrappedCellText(item.displayTitle),
        ),
        AppListTableColumn<ClinicalCatalogOption>(
          id: 'code',
          label: l10n.labTestCodeLabel,
          sortComparator: (ClinicalCatalogOption a, ClinicalCatalogOption b) =>
              (a.code ?? '').toLowerCase().compareTo(
                (b.code ?? '').toLowerCase(),
              ),
          cellBuilder: (_, ClinicalCatalogOption item) => _wrappedCellText(
            item.code?.trim().isNotEmpty == true ? item.code! : '—',
          ),
        ),
        AppListTableColumn<ClinicalCatalogOption>(
          id: 'category',
          label: l10n.labCategoryLabel,
          sortComparator: (ClinicalCatalogOption a, ClinicalCatalogOption b) =>
              (a.category ?? '').toLowerCase().compareTo(
                (b.category ?? '').toLowerCase(),
              ),
          cellBuilder: (_, ClinicalCatalogOption item) => _wrappedCellText(
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
    bool prefetchSiblings = false,
  }) async {
    await switch (tab) {
      _CatalogDeskTab.radiology => _loadRadiologyItems(force: force),
      _CatalogDeskTab.lab => _loadLabItems(force: force),
      _CatalogDeskTab.diagnoses => _loadDiagnosisItems(force: force),
    };
    if (!prefetchSiblings || !mounted) {
      return;
    }
    for (final _CatalogDeskTab other in _CatalogDeskTab.values) {
      if (other == tab) {
        continue;
      }
      unawaited(_ensureTabLoaded(other, prefetchSiblings: false));
    }
  }

  void _setTabLoading(_CatalogDeskTab tab, {required bool loading}) {
    switch (tab) {
      case _CatalogDeskTab.radiology:
        _radiologyLoading = loading;
        if (loading) {
          _radiologyFailure = null;
        }
      case _CatalogDeskTab.lab:
        _labLoading = loading;
        if (loading) {
          _labFailure = null;
        }
      case _CatalogDeskTab.diagnoses:
        _diagnosisLoading = loading;
        if (loading) {
          _diagnosisFailure = null;
        }
    }
  }

  void _notifyTabChanged(_CatalogDeskTab tab) {
    if (!mounted) {
      return;
    }
    // Rebuild immediately for the active tab; inactive catalogs stay warm in
    // memory and paint instantly on the next tab switch.
    if (_tab == tab) {
      setState(() {});
    }
  }

  Future<void> _loadRadiologyItems({bool force = false}) async {
    if (!mounted) {
      return;
    }
    if ((_radiologyHydrated && !force) || (_radiologyLoadInFlight && !force)) {
      return;
    }
    _radiologyLoadInFlight = true;
    final bool notifyLoading = _tab == _CatalogDeskTab.radiology;
    _setTabLoading(_CatalogDeskTab.radiology, loading: true);
    if (notifyLoading) {
      setState(() {});
    }
    try {
      final Result<List<RadiologyCatalogProcedure>> result = await ref
          .read(radiologyRepositoryProvider)
          .listRadiologyCatalogProcedures(
            includeStandardCatalog: true,
            includeDeleted: true,
            search: null,
            limit: _radiologyFetchLimit,
          );
      if (!mounted) {
        return;
      }
      result.when(
        success: (List<RadiologyCatalogProcedure> items) {
          _radiologyItems = items;
          _radiologyHydrated = true;
          _refreshRadiologyFilterOptions();
          _recomputeRadiologyVisible();
          _radiologyFailure = null;
        },
        failure: (AppFailure failure) {
          _radiologyFailure = failure;
        },
      );
      _radiologyLoading = false;
      _notifyTabChanged(_CatalogDeskTab.radiology);
    } finally {
      _radiologyLoadInFlight = false;
    }
  }

  Future<void> _loadLabItems({bool force = false}) async {
    if (!mounted) {
      return;
    }
    if ((_labHydrated && !force) || (_labLoadInFlight && !force)) {
      return;
    }
    _labLoadInFlight = true;
    final bool notifyLoading = _tab == _CatalogDeskTab.lab;
    _setTabLoading(_CatalogDeskTab.lab, loading: true);
    if (notifyLoading) {
      setState(() {});
    }
    try {
      final LabRepository repository = ref.read(labRepositoryProvider);
      // Tenant-only loads are authoritative for custom catalog rows. The
      // include_standard responses can truncate late-alphabet tenant names when
      // merging thousands of LOINC standards — never rely on them alone.
      final List<Result<List<LabCatalogItem>>> results =
          await Future.wait(<Future<Result<List<LabCatalogItem>>>>[
            repository.listTests(
              includeStandardCatalog: false,
              tenantId: widget.tenantId,
              limit: _labFetchLimit,
            ),
            repository.listPanels(
              includeStandardCatalog: false,
              tenantId: widget.tenantId,
              limit: _labFetchLimit,
            ),
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
      final List<LabCatalogItem> tenantItems = <LabCatalogItem>[];
      final List<LabCatalogItem> standardItems = <LabCatalogItem>[];
      for (int index = 0; index < results.length; index++) {
        results[index].when(
          success: (List<LabCatalogItem> items) {
            if (index < 2) {
              tenantItems.addAll(items);
            } else {
              standardItems.addAll(
                items.where((LabCatalogItem item) => item.isStandard),
              );
            }
          },
          failure: (AppFailure f) => failure ??= f,
        );
      }
      final List<LabCatalogItem> merged = _mergeLabDeskCatalogItems(
        tenantItems: tenantItems,
        standardItems: standardItems,
      );
      _labItems = merged;
      _labFailure = failure;
      _labLoading = false;
      if (failure == null || merged.isNotEmpty) {
        _labHydrated = failure == null;
        _refreshLabFilterOptions();
        _recomputeLabVisible();
      }
      _notifyTabChanged(_CatalogDeskTab.lab);
    } finally {
      _labLoadInFlight = false;
    }
  }

  List<LabCatalogItem> _mergeLabDeskCatalogItems({
    required List<LabCatalogItem> tenantItems,
    required List<LabCatalogItem> standardItems,
  }) {
    final Map<String, LabCatalogItem> byPrimaryKey = <String, LabCatalogItem>{};
    final Set<String> seenCodes = <String>{};

    String primaryKey(LabCatalogItem item) {
      final String apiId = item.apiId.trim();
      if (apiId.isNotEmpty) {
        return apiId;
      }
      return item.id.trim();
    }

    void putTenant(LabCatalogItem item) {
      final String key = primaryKey(item);
      if (key.isEmpty) {
        return;
      }
      byPrimaryKey[key] = item;
      final String code = (item.code ?? '').trim().toUpperCase();
      if (code.isNotEmpty) {
        seenCodes.add('${item.type.name}:$code');
      }
    }

    void putStandard(LabCatalogItem item) {
      final String key = primaryKey(item);
      if (key.isEmpty || byPrimaryKey.containsKey(key)) {
        return;
      }
      final String code = (item.code ?? '').trim().toUpperCase();
      if (code.isNotEmpty && seenCodes.contains('${item.type.name}:$code')) {
        return;
      }
      byPrimaryKey[key] = item;
      if (code.isNotEmpty) {
        seenCodes.add('${item.type.name}:$code');
      }
    }

    for (final LabCatalogItem item in tenantItems) {
      putTenant(item);
    }
    for (final LabCatalogItem item in standardItems) {
      putStandard(item);
    }

    final List<LabCatalogItem> merged = byPrimaryKey.values.toList();
    merged.sort(
      (LabCatalogItem a, LabCatalogItem b) => a.displayTitle
          .toLowerCase()
          .compareTo(b.displayTitle.toLowerCase()),
    );
    return merged;
  }

  Future<void> _loadDiagnosisItems({bool force = false}) async {
    if (!mounted) {
      return;
    }
    if ((_diagnosisHydrated && !force) ||
        (_diagnosisLoadInFlight && !force)) {
      return;
    }
    _diagnosisLoadInFlight = true;
    final bool notifyLoading = _tab == _CatalogDeskTab.diagnoses;
    _setTabLoading(_CatalogDeskTab.diagnoses, loading: true);
    if (notifyLoading) {
      setState(() {});
    }
    try {
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
      result.when(
        success: (List<ClinicalCatalogOption> items) {
          _diagnosisItems = items;
          _diagnosisHydrated = true;
          _refreshDiagnosisFilterOptions();
          _recomputeDiagnosisVisible();
          _diagnosisFailure = null;
        },
        failure: (AppFailure failure) {
          _diagnosisFailure = failure;
        },
      );
      _diagnosisLoading = false;
      _notifyTabChanged(_CatalogDeskTab.diagnoses);
    } finally {
      _diagnosisLoadInFlight = false;
    }
  }

  Future<void> _openConfigureFlow() async {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (_tab == _CatalogDeskTab.diagnoses &&
        !clinicalCatalogConfigureVisible(
          panelEnabled: widget.enabled,
          canMutateClinicalCatalog: policy.canMutateClinicalCatalog(),
        )) {
      return;
    }
    final CatalogConfigureScopeVisibility visibility =
        CatalogConfigureScopeVisibility.fromPolicy(policy);
    final TenantFacilityRepository tenantRepo = ref.read(
      tenantFacilityRepositoryProvider,
    );

    Future<List<TenantProfile>> loadTenants() async {
      final Result<AppPage<TenantProfile>> result = await tenantRepo.listTenants(
        request: const AppPageRequest(pageSize: 100),
      );
      return result.when(
        success: (AppPage<TenantProfile> page) => page.items,
        failure: (_) => const <TenantProfile>[],
      );
    }

    Future<List<FacilityProfile>> loadFacilities(String? tenantId) async {
      final Result<AppPage<FacilityProfile>> result = await tenantRepo
          .listFacilities(
            request: const AppPageRequest(pageSize: 100),
            tenantId: tenantId,
          );
      return result.when(
        success: (AppPage<FacilityProfile> page) => page.items,
        failure: (_) => const <FacilityProfile>[],
      );
    }

    FacilityCatalogScopePick? pick;
    final bool showScopeStep = !visibility.skipPicker;

    if (!showScopeStep) {
      final String? tenantId =
          (policy.tenantId ?? widget.tenantId)?.trim();
      final String? facilityId =
          (policy.facilityId ?? widget.facilityId)?.trim();
      final FacilityCatalogScope scope = FacilityCatalogScope(
        tenantId: tenantId,
        facilityId: facilityId,
      );
      if (!scope.isReady) {
        return;
      }
      pick = FacilityCatalogScopePick(
        scope: scope,
        tenantCurrency: null,
        facilityCurrency: widget.defaultCurrency,
      );
    }

    while (mounted) {
      if (showScopeStep) {
        pick = await showCatalogFacilityScopePicker(
          context: context,
          loadTenants: loadTenants,
          loadFacilities: loadFacilities,
          initialTenantId: pick?.tenantId ??
              policy.tenantId ??
              widget.tenantId,
          initialFacilityId: pick?.facilityId ??
              (visibility.showFacilitySelector
                  ? widget.facilityId
                  : policy.facilityId ?? widget.facilityId),
          showTenantSelector: visibility.showTenantSelector,
          showFacilitySelector: visibility.showFacilitySelector,
          lockTenant: !visibility.showTenantSelector &&
              visibility.showFacilitySelector,
        );
        if (!mounted || pick == null || !pick.isReady) {
          return;
        }
      }

      final FacilityCatalogScopePick resolved = pick!;
      final Object? outcome = switch (_tab) {
        _CatalogDeskTab.radiology => await _openRadiologyConfigureDialog(
          resolved,
          showBackAction: showScopeStep,
        ),
        _CatalogDeskTab.lab => await _openLabConfigureDialog(
          resolved.scope,
          defaultCurrency: resolved.defaultCurrency,
          showBackAction: showScopeStep,
        ),
        _CatalogDeskTab.diagnoses =>
          await _openDiagnosisConfigureDialog(resolved.scope),
      };

      if (!mounted) {
        return;
      }
      if ((identical(
                outcome,
                RadiologyEnableFacilityOfferingDialog.backResult,
              ) ||
              identical(
                outcome,
                LabEnableFacilityOfferingDialog.backResult,
              )) &&
          showScopeStep) {
        continue;
      }
      if (outcome == true) {
        final String message = switch (_tab) {
          _CatalogDeskTab.radiology =>
            context.l10n.radiologySaveConfigurationAction,
          _CatalogDeskTab.lab ||
          _CatalogDeskTab.diagnoses => context.l10n.labSavedMessage,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        await _ensureTabLoaded(_tab, force: true);
      }
      return;
    }
  }

  Future<Object?> _openRadiologyConfigureDialog(
    FacilityCatalogScopePick pick, {
    required bool showBackAction,
  }) async {
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final FacilityCatalogScope scope = pick.scope;
    final String currency = pick.facilityCurrency?.trim().isNotEmpty == true ||
            pick.tenantCurrency?.trim().isNotEmpty == true
        ? pick.defaultCurrency
        : _resolvedCurrency;
    return showAppDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyEnableFacilityOfferingDialog(
        scope: scope,
        defaultCurrency: currency,
        showBackAction: showBackAction,
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
          final Result<RadiologyCatalogProcedure> result = await repository
              .upsertFacilityRadiologyProcedureOffering(
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
  }

  Future<Object?> _openLabConfigureDialog(
    FacilityCatalogScope scope, {
    String? defaultCurrency,
    bool showBackAction = false,
  }) async {
    final LabRepository repository = ref.read(labRepositoryProvider);
    return showAppDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabEnableFacilityOfferingDialog(
        kind: LabEnableOfferingKind.all,
        scope: scope,
        defaultCurrency: defaultCurrency ?? _resolvedCurrency,
        showBackAction: showBackAction,
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
        onEnable: (LabCatalogItem item, Map<String, Object?> payload) async {
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
  }

  Future<bool?> _openDiagnosisConfigureDialog(FacilityCatalogScope scope) async {
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
    return saved;
  }

  Future<List<RadiologyCatalogProcedure>> _loadRadiologySimilarityCandidates({
    String? tenantId,
  }) async {
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final Result<List<RadiologyCatalogProcedure>> candidatesResult =
        await repository.listRadiologyCatalogProcedures(
          tenantId: tenantId,
          limit: 7500,
        );
    return candidatesResult.when(
      success: (List<RadiologyCatalogProcedure> items) => items,
      failure: (_) => _radiologyItems,
    );
  }

  RadiologyCatalogProcedure _resolveRadiologyCatalogItem(
    RadiologyCatalogProcedure item,
  ) {
    for (final RadiologyCatalogProcedure candidate in _radiologyItems) {
      if (candidate.apiId == item.apiId || candidate.id == item.id) {
        return candidate;
      }
    }
    return item;
  }

  bool get _canMutateRadiologyCatalog =>
      ref.watch(appAccessPolicyProvider).canMutateRadiologyCatalog();

  bool get _canMutateLabCatalog =>
      ref.watch(appAccessPolicyProvider).canMutateLabCatalog();

  bool get _canMutateClinicalCatalog =>
      ref.watch(appAccessPolicyProvider).canMutateClinicalCatalog();

  Future<List<LabCatalogItem>> _loadLabSimilarityCandidates({
    String? tenantId,
    LabCatalogItemType kind = LabCatalogItemType.test,
  }) async {
    final LabRepository repository = ref.read(labRepositoryProvider);
    final Result<List<LabCatalogItem>> candidatesResult =
        kind == LabCatalogItemType.panel
        ? await repository.listPanels(
            tenantId: tenantId,
            limit: 7500,
            includeStandardCatalog: true,
          )
        : await repository.listTests(
            tenantId: tenantId,
            // Match backend lab catalog max page limit + uniqueness scan size.
            limit: 7500,
            includeStandardCatalog: true,
            // Uniqueness includes pending-review rows; similarity must too.
            includePendingReview: true,
          );
    return candidatesResult.when(
      success: (List<LabCatalogItem> items) {
        final List<LabCatalogItem> filtered = items
            .where((LabCatalogItem item) => item.type == kind)
            .toList(growable: false);
        // Merge desk rows so a just-saved local upsert is never dropped if the
        // list response is momentarily stale.
        return _mergeLabSimilarityCandidates(
          filtered,
          _labItems,
          kind: kind,
        );
      },
      failure: (_) => _labItems
          .where((LabCatalogItem item) => item.type == kind)
          .toList(growable: false),
    );
  }

  List<LabCatalogItem> _mergeLabSimilarityCandidates(
    List<LabCatalogItem> primary,
    List<LabCatalogItem> fallback, {
    LabCatalogItemType kind = LabCatalogItemType.test,
  }) {
    final Map<String, LabCatalogItem> byKey = <String, LabCatalogItem>{};
    void put(LabCatalogItem item) {
      if (item.type != kind) {
        return;
      }
      final String apiId = item.apiId.trim();
      final String id = item.id.trim();
      if (apiId.isNotEmpty) {
        byKey[apiId] = item;
      }
      if (id.isNotEmpty && id != apiId) {
        byKey.putIfAbsent(id, () => item);
      }
    }

    for (final LabCatalogItem item in primary) {
      put(item);
    }
    for (final LabCatalogItem item in fallback) {
      put(item);
    }
    return byKey.values.toList(growable: false);
  }

  LabCatalogItem _resolveLabCatalogItem(LabCatalogItem item) {
    for (final LabCatalogItem candidate in _labItems) {
      if (candidate.apiId == item.apiId || candidate.id == item.id) {
        return candidate;
      }
    }
    return item;
  }

  void _upsertLabItemLocally(LabCatalogItem item) {
    final List<LabCatalogItem> next = List<LabCatalogItem>.of(_labItems);
    final int index = next.indexWhere(
      (LabCatalogItem candidate) =>
          candidate.apiId == item.apiId || candidate.id == item.id,
    );
    if (index >= 0) {
      next[index] = item;
    } else {
      next.insert(0, item);
    }
    _labItems = next;
    _refreshLabFilterOptions();
    _recomputeLabVisible();
  }

  void _removeLabItemLocally(LabCatalogItem item) {
    _labItems = _labItems
        .where(
          (LabCatalogItem candidate) =>
              candidate.apiId != item.apiId && candidate.id != item.id,
        )
        .toList(growable: false);
    _refreshLabFilterOptions();
    _recomputeLabVisible();
  }

  bool _matchesLabItemId(LabCatalogItem item, String id) {
    final String normalized = id.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return item.apiId == normalized ||
        item.id == normalized ||
        (item.displayId ?? '') == normalized;
  }

  String? _labResourceIdFromMessage(RealtimeMessage message) {
    for (final String key in const <String>[
      'resource_id',
      'lab_test_id',
      'human_friendly_id',
      'id',
    ]) {
      final Object? value = message.payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  bool _applyLabCatalogRealtimeMessage(RealtimeMessage? message) {
    if (message == null || message.event != RealtimeEvents.labCatalogUpdated) {
      return false;
    }
    final String action =
        (message.payload['action'] as String?)?.trim().toUpperCase() ?? '';
    final String? testId = _labResourceIdFromMessage(message);
    if (testId == null) {
      return false;
    }

    final String? scopedTenantId = widget.tenantId?.trim();
    final String? eventTenantId =
        (message.payload['tenant_id'] as String?)?.trim();
    if (scopedTenantId != null &&
        scopedTenantId.isNotEmpty &&
        eventTenantId != null &&
        eventTenantId.isNotEmpty &&
        scopedTenantId != eventTenantId) {
      return true;
    }

    switch (action) {
      case 'SOFT_DELETED':
      case 'PERMANENTLY_DELETED':
        final int index = _labItems.indexWhere(
          (LabCatalogItem item) => _matchesLabItemId(item, testId),
        );
        if (index < 0) {
          return action == 'PERMANENTLY_DELETED';
        }
        setState(() => _removeLabItemLocally(_labItems[index]));
        return true;
      case 'CREATED':
      case 'UPDATED':
        return false;
      default:
        return false;
    }
  }

  Future<T> _withLabMutationGuard<T>(Future<T> Function() action) async {
    _labMutationDepth += 1;
    try {
      return await action();
    } finally {
      _labMutationDepth = (_labMutationDepth - 1).clamp(0, 1 << 30);
    }
  }

  void _upsertRadiologyItemLocally(RadiologyCatalogProcedure item) {
    final List<RadiologyCatalogProcedure> next =
        List<RadiologyCatalogProcedure>.of(_radiologyItems);
    final int index = next.indexWhere(
      (RadiologyCatalogProcedure candidate) =>
          candidate.apiId == item.apiId || candidate.id == item.id,
    );
    if (index >= 0) {
      next[index] = item;
    } else {
      next.insert(0, item);
    }
    _radiologyItems = next;
    _refreshRadiologyFilterOptions();
    _recomputeRadiologyVisible();
  }

  void _removeRadiologyItemLocally(RadiologyCatalogProcedure item) {
    _radiologyItems = _radiologyItems
        .where(
          (RadiologyCatalogProcedure candidate) =>
              candidate.apiId != item.apiId && candidate.id != item.id,
        )
        .toList(growable: false);
    _refreshRadiologyFilterOptions();
    _recomputeRadiologyVisible();
  }

  Future<void> _openRadiologyAddDialog() async {
    if (!_canMutateRadiologyCatalog) {
      return;
    }
    final String? tenantId = await _resolveTenantIdForCreate();
    if (!mounted || tenantId == null) {
      return;
    }
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    RadiologyCatalogProcedure? createdProcedure;
    final Object? result = await showAppDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyCatalogMutationDialog(
        tenantId: tenantId,
        existingItems: _radiologyItems,
        loadExistingItems: () =>
            _loadRadiologySimilarityCandidates(tenantId: tenantId),
        onSubmit: (Map<String, Object?> payload) async {
          final Result<RadiologyCatalogProcedure> created = await repository
              .createRadiologyCatalogProcedure(payload);
          return created.when(
            success: (RadiologyCatalogProcedure item) {
              createdProcedure = item;
              return null;
            },
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted) {
      return;
    }
    if (result is RadiologyCatalogProcedure) {
      final RadiologyCatalogProcedure existing =
          _resolveRadiologyCatalogItem(result);
      await showRadiologyCatalogProcedureDetailsDialog(
        context,
        procedure: existing,
      );
      return;
    }
    if (result != true) {
      return;
    }
    final RadiologyCatalogProcedure? saved = createdProcedure;
    if (saved != null) {
      setState(() => _upsertRadiologyItemLocally(saved));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.radiologySaveConfigurationAction)),
    );
    await _ensureTabLoaded(_tab, force: true);
    if (!mounted || saved == null) {
      return;
    }
    await showRadiologyCatalogProcedureDetailsDialog(
      context,
      procedure: saved,
    );
  }

  Future<void> _openRadiologyEditDialog(RadiologyCatalogProcedure item) async {
    if (!_canMutateRadiologyCatalog || item.isDeleted || item.isStandard) {
      return;
    }
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final String? tenantId = widget.tenantId?.trim();
    RadiologyCatalogProcedure? updatedProcedure;
    final Object? result = await showAppDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyCatalogMutationDialog(
        item: item,
        tenantId: tenantId,
        existingItems: _radiologyItems,
        loadExistingItems: () =>
            _loadRadiologySimilarityCandidates(tenantId: tenantId),
        onSubmit: (Map<String, Object?> payload) async {
          final Result<RadiologyCatalogProcedure> updated = await repository
              .updateRadiologyCatalogProcedure(item.apiId, payload);
          return updated.when(
            success: (RadiologyCatalogProcedure next) {
              updatedProcedure = next;
              return null;
            },
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted) {
      return;
    }
    if (result is RadiologyCatalogProcedure) {
      final RadiologyCatalogProcedure selected =
          _resolveRadiologyCatalogItem(result);
      await showRadiologyCatalogProcedureDetailsDialog(
        context,
        procedure: selected,
      );
      return;
    }
    if (result != true) {
      return;
    }
    final RadiologyCatalogProcedure? saved = updatedProcedure;
    if (saved != null) {
      setState(() => _upsertRadiologyItemLocally(saved));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.radiologySaveConfigurationAction)),
    );
    await _ensureTabLoaded(_tab, force: true);
    if (!mounted) {
      return;
    }
    final RadiologyCatalogProcedure detailsItem =
        saved ?? _resolveRadiologyCatalogItem(item);
    await showRadiologyCatalogProcedureDetailsDialog(
      context,
      procedure: detailsItem,
    );
  }

  void _markRadiologyItemSoftDeletedLocally(RadiologyCatalogProcedure item) {
    setState(() {
      _upsertRadiologyItemLocally(
        item.copyWith(deletedAt: item.deletedAt ?? DateTime.now()),
      );
    });
  }

  bool _matchesRadiologyItemId(RadiologyCatalogProcedure item, String id) {
    final String normalized = id.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return item.apiId == normalized ||
        item.id == normalized ||
        (item.displayId ?? '') == normalized;
  }

  String? _radiologyResourceIdFromMessage(RealtimeMessage message) {
    for (final String key in const <String>[
      'resource_id',
      'radiology_procedure_id',
      'id',
    ]) {
      final Object? value = message.payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  bool _applyRadiologyCatalogRealtimeMessage(RealtimeMessage? message) {
    if (message == null ||
        message.event != RealtimeEvents.radiologyCatalogUpdated) {
      return false;
    }
    final String action =
        (message.payload['action'] as String?)?.trim().toUpperCase() ?? '';
    final String? procedureId = _radiologyResourceIdFromMessage(message);
    if (procedureId == null) {
      return false;
    }

    final String? scopedTenantId = widget.tenantId?.trim();
    final String? eventTenantId =
        (message.payload['tenant_id'] as String?)?.trim();
    if (scopedTenantId != null &&
        scopedTenantId.isNotEmpty &&
        eventTenantId != null &&
        eventTenantId.isNotEmpty &&
        scopedTenantId != eventTenantId) {
      return true;
    }

    switch (action) {
      case 'SOFT_DELETED':
        final int index = _radiologyItems.indexWhere(
          (RadiologyCatalogProcedure item) =>
              _matchesRadiologyItemId(item, procedureId),
        );
        if (index < 0) {
          return false;
        }
        final Object? deletedAtRaw = message.payload['deleted_at'];
        final DateTime deletedAt = deletedAtRaw is String
            ? (DateTime.tryParse(deletedAtRaw) ?? DateTime.now().toUtc())
            : DateTime.now().toUtc();
        setState(() {
          _upsertRadiologyItemLocally(
            _radiologyItems[index].copyWith(deletedAt: deletedAt),
          );
        });
        return true;
      case 'RESTORED':
        final int index = _radiologyItems.indexWhere(
          (RadiologyCatalogProcedure item) =>
              _matchesRadiologyItemId(item, procedureId),
        );
        if (index < 0) {
          return false;
        }
        setState(() {
          _upsertRadiologyItemLocally(
            _radiologyItems[index].copyWith(clearDeletedAt: true),
          );
        });
        return true;
      case 'PERMANENTLY_DELETED':
        final int index = _radiologyItems.indexWhere(
          (RadiologyCatalogProcedure item) =>
              _matchesRadiologyItemId(item, procedureId),
        );
        if (index < 0) {
          return true;
        }
        setState(() => _removeRadiologyItemLocally(_radiologyItems[index]));
        return true;
      case 'CREATED':
      case 'UPDATED':
        return false;
      default:
        return false;
    }
  }

  Future<T> _withRadiologyMutationGuard<T>(Future<T> Function() action) async {
    _radiologyMutationDepth += 1;
    try {
      return await action();
    } finally {
      _radiologyMutationDepth = (_radiologyMutationDepth - 1).clamp(0, 1 << 30);
    }
  }

  Future<void> _openRadiologyDeleteDialog(RadiologyCatalogProcedure item) async {
    await _withRadiologyMutationGuard(() async {
    if (!_canMutateRadiologyCatalog || item.isDeleted || item.isStandard) {
      return;
    }
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final AppLocalizations l10n = context.l10n;
    final String scope = item.catalogScopeLabel;
    RadiologyCatalogProcedure? softDeleted;
    final bool? deleted = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppConfirmActionDialog(
        title: l10n.radiologySoftDeleteProcedureDialogTitle,
        body: scope.isEmpty
            ? l10n.radiologySoftDeleteProcedureDialogBodyNoScope(item.name)
            : l10n.radiologySoftDeleteProcedureDialogBody(item.name, scope),
        highlightedText: item.name,
        submitLabel: l10n.clinicalRadiologyDeleteSelectionAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final Result<RadiologyCatalogProcedure> result = await repository
              .deleteRadiologyCatalogProcedure(item.apiId);
          return result.when(
            success: (RadiologyCatalogProcedure value) {
              softDeleted = value;
              return null;
            },
            failure: (AppFailure failure) {
              if (failure.category == AppFailureCategory.notFound) {
                return null;
              }
              return failure;
            },
          );
        },
      ),
    );
    if (!mounted || deleted != true) {
      return;
    }
    final RadiologyCatalogProcedure applied =
        softDeleted ??
        item.copyWith(deletedAt: item.deletedAt ?? DateTime.now());
    _markRadiologyItemSoftDeletedLocally(applied);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.radiologyProcedureSoftDeletedMessage)),
    );
    await _ensureTabLoaded(_tab, force: true);
    if (mounted) {
      _markRadiologyItemSoftDeletedLocally(applied);
    }
    });
  }

  Future<void> _openRadiologyRestoreDialog(RadiologyCatalogProcedure item) async {
    await _withRadiologyMutationGuard(() async {
    if (!_canMutateRadiologyCatalog || !item.isDeleted || item.isStandard) {
      return;
    }
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final AppLocalizations l10n = context.l10n;
    RadiologyCatalogProcedure? restored;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppConfirmActionDialog(
        title: l10n.radiologyRestoreProcedureDialogTitle,
        body: l10n.radiologyRestoreProcedureDialogBody(item.name),
        highlightedText: item.name,
        submitLabel: l10n.radiologyRestoreProcedureAction,
        icon: const Icon(Icons.restore_outlined),
        onConfirm: () async {
          final Result<RadiologyCatalogProcedure> result = await repository
              .restoreRadiologyCatalogProcedure(item.apiId);
          return result.when(
            success: (RadiologyCatalogProcedure value) {
              restored = value;
              return null;
            },
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final RadiologyCatalogProcedure applied =
        restored ?? item.copyWith(clearDeletedAt: true);
    setState(() => _upsertRadiologyItemLocally(applied));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.radiologyProcedureRestoredMessage)),
    );
    await _ensureTabLoaded(_tab, force: true);
    if (mounted) {
      setState(() => _upsertRadiologyItemLocally(applied));
    }
    });
  }

  Future<void> _openRadiologyPermanentDeleteDialog(
    RadiologyCatalogProcedure item,
  ) async {
    await _withRadiologyMutationGuard(() async {
    if (!_canMutateRadiologyCatalog || !item.isDeleted || item.isStandard) {
      return;
    }
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final AppLocalizations l10n = context.l10n;
    final String? typed = await showAppDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppTextInputActionDialog(
        title: l10n.radiologyPermanentDeleteProcedureDialogTitle,
        description: l10n.radiologyPermanentDeleteProcedureWarningBody(
          item.name,
        ),
        fieldLabel: l10n.tenantFacilityPermanentDeleteConfirmFieldLabel(
          item.name,
        ),
        submitLabel: l10n.tenantFacilityPermanentDeleteConfirmAction,
        cancelLabel: l10n.commonCancelActionLabel,
        requiredMessage: l10n.validationRequired,
        confirmExactValue: item.name,
        confirmMismatchMessage:
            l10n.tenantFacilityPermanentDeleteConfirmFieldLabel(item.name),
        destructive: true,
        minLines: 1,
        maxLines: 1,
        icon: const Icon(Icons.delete_forever_outlined),
      ),
    );
    if (!mounted || typed == null) {
      return;
    }
    if (typed.trim().toLowerCase() != item.name.trim().toLowerCase()) {
      return;
    }

    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppConfirmActionDialog(
        title: l10n.radiologyPermanentDeleteProcedureDialogTitle,
        body: l10n.radiologyPermanentDeleteProcedureConfirmationBody(item.name),
        highlightedText: item.name,
        submitLabel: l10n.tenantFacilityPermanentDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_forever_outlined),
        onConfirm: () async {
          final Result<void> result = await repository
              .permanentDeleteRadiologyCatalogProcedure(item.apiId);
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) {
              if (failure.category == AppFailureCategory.notFound) {
                return null;
              }
              return failure;
            },
          );
        },
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() => _removeRadiologyItemLocally(item));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.radiologyProcedurePermanentlyDeletedMessage)),
    );
    unawaited(_ensureTabLoaded(_tab, force: true));
    });
  }

  Future<void> _openLabDetailsDialog(LabCatalogItem item) async {
    if (!mounted) {
      return;
    }
    final bool canMutate = labCatalogMutateControlsVisible(
      panelEnabled: widget.enabled,
      canMutateLabCatalog: _canMutateLabCatalog,
    );
    final bool showMutateActions = labCatalogItemMutateActionsVisible(
      canMutateLabCatalog: canMutate,
      isStandard: item.isStandard,
    );
    final LabCatalogItemDetailsAction? action =
        await showLabCatalogItemDetailsDialog(
          context,
          item: item,
          showMutateActions: showMutateActions,
        );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case LabCatalogItemDetailsAction.edit:
        await _openLabEditDialog(item);
      case LabCatalogItemDetailsAction.delete:
        await _openLabDeleteDialog(item);
    }
  }

  Future<void> _openLabAddDialog(LabCatalogItemType kind) async {
    if (!_canMutateLabCatalog) {
      return;
    }
    final String? tenantId = await _resolveTenantIdForCreate();
    if (!mounted || tenantId == null) {
      return;
    }
    await _withLabMutationGuard(() async {
      final LabRepository repository = ref.read(labRepositoryProvider);
      LabCatalogItem? createdItem;
      final Object? result = await showAppDialog<Object>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LabCatalogItemMutationDialog(
          kind: kind,
          tenantId: tenantId,
          catalogItems: _labItems,
          loadExistingItems: () => _loadLabSimilarityCandidates(
            tenantId: tenantId,
            kind: kind,
          ),
          onSubmit: (Map<String, Object?> payload) async {
            final Result<LabCatalogItem> createResult =
                kind == LabCatalogItemType.panel
                ? await repository.createLabPanel(payload)
                : await repository.createLabTest(payload);
            return createResult.when(
              success: (LabCatalogItem item) {
                createdItem = item;
                return null;
              },
              failure: (AppFailure failure) => failure,
            );
          },
        ),
      );
      if (!mounted) {
        return;
      }
      if (result is LabCatalogItem) {
        final LabCatalogItem existing = _resolveLabCatalogItem(result);
        await _openLabDetailsDialog(existing);
        return;
      }
      if (result != true) {
        return;
      }
      final LabCatalogItem? saved = createdItem;
      if (saved != null) {
        setState(() => _upsertLabItemLocally(saved));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.labSavedMessage)),
      );
      await _ensureTabLoaded(_tab, force: true);
      // Reload can omit a just-created row when the standard-catalog merge
      // truncates; keep the saved entity visible either way.
      if (!mounted || saved == null) {
        return;
      }
      final bool present = _labItems.any(
        (LabCatalogItem item) =>
            item.apiId == saved.apiId || item.id == saved.id,
      );
      if (!present) {
        setState(() => _upsertLabItemLocally(saved));
      }
      if (!mounted) {
        return;
      }
      await _openLabDetailsDialog(saved);
    });
  }

  Future<void> _openLabEditDialog(LabCatalogItem item) async {
    if (!_canMutateLabCatalog || item.isStandard) {
      return;
    }
    await _withLabMutationGuard(() async {
      final LabRepository repository = ref.read(labRepositoryProvider);
      final String? tenantId = widget.tenantId?.trim();
      LabCatalogItem? updatedItem;
      final Object? result = await showAppDialog<Object>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LabCatalogItemMutationDialog(
          kind: item.type,
          item: item,
          catalogItems: _labItems,
          loadExistingItems: () => _loadLabSimilarityCandidates(
            tenantId: tenantId,
            kind: item.type,
          ),
          onSubmit: (Map<String, Object?> payload) async {
            final Result<LabCatalogItem> updateResult =
                item.type == LabCatalogItemType.panel
                ? await repository.updateLabPanel(item.apiId, payload)
                : await repository.updateLabTest(item.apiId, payload);
            return updateResult.when(
              success: (LabCatalogItem next) {
                updatedItem = next;
                return null;
              },
              failure: (AppFailure failure) => failure,
            );
          },
        ),
      );
      if (!mounted) {
        return;
      }
      if (result is LabCatalogItem) {
        final LabCatalogItem existing = _resolveLabCatalogItem(result);
        await _openLabDetailsDialog(existing);
        return;
      }
      if (result != true) {
        return;
      }
      final LabCatalogItem? saved = updatedItem;
      if (saved != null) {
        setState(() => _upsertLabItemLocally(saved));
      }
      await _ensureTabLoaded(_tab, force: true);
      if (!mounted) {
        return;
      }
      final LabCatalogItem detailsItem = saved ?? _resolveLabCatalogItem(item);
      await _openLabDetailsDialog(detailsItem);
    });
  }

  Future<void> _openLabDeleteDialog(LabCatalogItem item) async {
    if (!_canMutateLabCatalog || item.isStandard) {
      return;
    }
    await _withLabMutationGuard(() async {
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
      setState(() => _removeLabItemLocally(item));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.labDeletedMessage)),
      );
      await _ensureTabLoaded(_tab, force: true);
    });
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
    final FacilityCatalogScopePick? scope = await showCatalogFacilityScopePicker(
      context: context,
      loadTenants: () async {
        final Result<AppPage<TenantProfile>> result = await tenantRepo
            .listTenants(request: const AppPageRequest(pageSize: 100));
        return result.when(
          success: (AppPage<TenantProfile> page) => page.items,
          failure: (_) => const <TenantProfile>[],
        );
      },
      loadFacilities: (String? tenantId) async {
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
    if (kind == LabEnableOfferingKind.all) {
      final List<Result<List<LabCatalogItem>>> combined =
          await Future.wait(<Future<Result<List<LabCatalogItem>>>>[
            _searchLabCatalog(
              repository: repository,
              kind: LabEnableOfferingKind.test,
              scope: scope,
              query: query,
              limit: limit,
            ),
            _searchLabCatalog(
              repository: repository,
              kind: LabEnableOfferingKind.panel,
              scope: scope,
              query: query,
              limit: limit,
            ),
          ]);
      final List<LabCatalogItem> items = <LabCatalogItem>[];
      AppFailure? failure;
      for (final Result<List<LabCatalogItem>> result in combined) {
        result.when(
          success: items.addAll,
          failure: (AppFailure value) {
            failure ??= value;
          },
        );
      }
      if (items.isEmpty && failure != null) {
        return Result<List<LabCatalogItem>>.failure(failure!);
      }
      final Map<String, LabCatalogItem> byKey = <String, LabCatalogItem>{};
      for (final LabCatalogItem item in items) {
        final String apiId = item.apiId.trim();
        final String key = apiId.isNotEmpty
            ? '${item.type.name}:$apiId'
            : '${item.type.name}:id:${item.id.trim()}';
        byKey.putIfAbsent(key, () => item);
      }
      return Result<List<LabCatalogItem>>.success(
        byKey.values.toList(growable: false),
      );
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
            search: query,
            offeredOnly: true,
            limit: labEnableOfferedMatchLimit,
          )
        : repository.listFacilityLabPanels(
            tenantId: scope.tenantId,
            facilityId: scope.facilityId,
            search: query,
            offeredOnly: true,
            limit: labEnableOfferedMatchLimit,
          );
    final List<Result<List<LabCatalogItem>>> results = await Future.wait(
      <Future<Result<List<LabCatalogItem>>>>[platformFuture, offeredFuture],
    );
    return results[0].when(
      success: (List<LabCatalogItem> platformItems) {
        final List<LabCatalogItem> offeredItems = results[1].when(
          success: (List<LabCatalogItem> items) => items,
          failure: (_) => const <LabCatalogItem>[],
        );
        return Result<List<LabCatalogItem>>.success(
          markLabCatalogItemsOfferedAtFacility(
            platformItems: platformItems,
            offeredItems: offeredItems,
          ),
        );
      },
      failure: (AppFailure failure) =>
          Result<List<LabCatalogItem>>.failure(failure),
    );
  }

  Future<Result<List<RadiologyCatalogProcedure>>> _searchRadiologyCatalog({
    required RadiologyRepository repository,
    required RadiologyCatalogScope scope,
    String? query,
    int limit = 100,
  }) async {
    if (!scope.isReady) {
      return const Result<List<RadiologyCatalogProcedure>>.success(
        <RadiologyCatalogProcedure>[],
      );
    }
    final Future<Result<List<RadiologyCatalogProcedure>>> platformFuture = repository
        .listRadiologyCatalogProcedures(search: query, limit: limit);
    final Future<Result<List<RadiologyCatalogProcedure>>> offeredFuture = repository
        .listFacilityRadiologyProcedures(
          tenantId: scope.tenantId,
          facilityId: scope.facilityId,
          offeredOnly: true,
          limit: limit,
        );
    final List<Result<List<RadiologyCatalogProcedure>>> results = await Future.wait(
      <Future<Result<List<RadiologyCatalogProcedure>>>>[
        platformFuture,
        offeredFuture,
      ],
    );
    return results[0].when(
      success: (List<RadiologyCatalogProcedure> platformItems) {
        final Set<String> offeredIds = <String>{};
        final Set<String> offeredCodes = <String>{};
        results[1].when(
          success: (List<RadiologyCatalogProcedure> offeredItems) {
            for (final RadiologyCatalogProcedure item in offeredItems) {
              offeredIds.add(item.apiId);
              final String? code = item.code?.trim();
              if (code != null && code.isNotEmpty) {
                offeredCodes.add(code.toUpperCase());
              }
            }
          },
          failure: (_) {},
        );
        return Result<List<RadiologyCatalogProcedure>>.success(
          platformItems
              .map((RadiologyCatalogProcedure item) {
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
          Result<List<RadiologyCatalogProcedure>>.failure(failure),
    );
  }
}

class _CatalogRowActions extends StatelessWidget {
  const _CatalogRowActions({
    required this.editLabel,
    required this.deleteLabel,
    this.restoreLabel,
    this.permanentDeleteLabel,
    this.isDeleted = false,
    this.onEdit,
    this.onDelete,
    this.onRestore,
    this.onPermanentDelete,
  });

  final String editLabel;
  final String deleteLabel;
  final String? restoreLabel;
  final String? permanentDeleteLabel;
  final bool isDeleted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onPermanentDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (isDeleted) {
      if (onRestore == null && onPermanentDelete == null) {
        return const SizedBox.shrink();
      }
      return Wrap(
        spacing: theme.spacing.sm,
        runSpacing: theme.spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (onRestore != null)
            AppButton.tertiary(
              label: restoreLabel ?? '',
              leadingIcon: Icons.restore_outlined,
              semanticLabel: restoreLabel,
              tooltip: restoreLabel,
              onPressed: onRestore,
            ),
          if (onPermanentDelete != null)
            AppButton.tertiary(
              label: permanentDeleteLabel ?? '',
              leadingIcon: Icons.delete_forever_outlined,
              semanticLabel: permanentDeleteLabel,
              tooltip: permanentDeleteLabel,
              color: theme.colorScheme.error,
              onPressed: onPermanentDelete,
            ),
        ],
      );
    }

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (onEdit != null)
          AppButton.tertiary(
            label: editLabel,
            leadingIcon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
        if (onDelete != null)
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
