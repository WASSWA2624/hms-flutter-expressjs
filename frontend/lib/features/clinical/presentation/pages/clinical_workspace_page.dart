import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/presentation/controllers/clinical_workspace_controller.dart';
import 'package:hosspi_hms/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart';
import 'package:hosspi_hms/shared/workflow_actions/workflow_action_registry.dart';

class ClinicalWorkspacePage extends ConsumerWidget {
  const ClinicalWorkspacePage({this.initialQuery, super.key});

  final ClinicalWorkspaceQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    ref.listen<AsyncValue<Result<ClinicalWorkspaceState>>>(
      clinicalWorkspaceControllerProvider,
      (
        AsyncValue<Result<ClinicalWorkspaceState>>? previous,
        AsyncValue<Result<ClinicalWorkspaceState>> next,
      ) {
        final String? notice = next.asData?.value.when(
          success: (ClinicalWorkspaceState value) => value.realtimeNotice,
          failure: (_) => null,
        );
        if (notice == null || notice.isEmpty) {
          return;
        }
        final List<String> parts = notice.split('::');
        if (parts.length < 2) {
          return;
        }
        final String patientName = parts.sublist(1).join('::');
        final String message = switch (parts.first) {
          'LAB_RESULT_CRITICAL' => l10n.clinicalLabResultCriticalNotice(
            patientName,
          ),
          'LAB_RESULT_READY' => l10n.clinicalLabResultReadyNotice(patientName),
          _ => l10n.clinicalLabResultUpdatedNotice(patientName),
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        ref
            .read(clinicalWorkspaceControllerProvider.notifier)
            .clearRealtimeNotice();
      },
    );
    final AsyncValue<Result<ClinicalWorkspaceState>> state = ref.watch(
      clinicalWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<ClinicalWorkspaceState>(
      value: state,
      loadingTitle: l10n.clinicalLoadingTitle,
      loadingBody: l10n.clinicalLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(clinicalWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, ClinicalWorkspaceState data) {
        return _ClinicalWorkspaceContent(
          state: data,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _ClinicalWorkspaceContent extends ConsumerStatefulWidget {
  const _ClinicalWorkspaceContent({required this.state, this.initialQuery});

  final ClinicalWorkspaceState state;
  final ClinicalWorkspaceQuery? initialQuery;

  @override
  ConsumerState<_ClinicalWorkspaceContent> createState() =>
      _ClinicalWorkspaceContentState();
}

class _ClinicalWorkspaceContentState
    extends ConsumerState<_ClinicalWorkspaceContent> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.systemAdmin,
    ],
    activeModules: <String>['encounters-vitals'],
  );

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<ClinicalWorklistEntry>
  _tableColumnController;
  Timer? _searchDebounce;
  String? _appliedRouteSignature;
  late ClinicalWorkspaceSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialQuery?.section ?? ClinicalWorkspaceSection.all;
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<ClinicalWorklistEntry>();
    _scheduleRouteQuery(widget.initialQuery);
    if (_section != ClinicalWorkspaceSection.all) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(clinicalWorkspaceControllerProvider.notifier)
            .applyScope(_clinicalSectionScope(_section));
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ClinicalWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
    if (oldWidget.initialQuery?.signature != widget.initialQuery?.signature) {
      _scheduleRouteQuery(widget.initialQuery);
    }
  }

  void _scheduleRouteQuery(ClinicalWorkspaceQuery? query) {
    if (query == null || !query.hasRouteTargeting) return;
    if (_appliedRouteSignature == query.signature) return;
    _appliedRouteSignature = query.signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_applyRouteQuery(query));
    });
  }

  Future<void> _applyRouteQuery(ClinicalWorkspaceQuery query) async {
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    if (query.section != ClinicalWorkspaceSection.all &&
        query.section != _section) {
      _handleTabChanged(query.section);
    }
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
      await controller.applySearch(query.search);
    }
    if (query.encounterId.isNotEmpty) {
      final ClinicalWorklistEntry? entry = _findEntryByEncounterId(
        query.encounterId,
      );
      if (entry != null) {
        await controller.selectEntry(entry);
      }
    }
  }

  ClinicalWorklistEntry? _findEntryByEncounterId(String encounterId) {
    for (final ClinicalWorklistEntry entry in widget.state.worklist.items) {
      if (entry.encounterId == encounterId ||
          entry.encounterPublicId == encounterId ||
          entry.id == encounterId) {
        return entry;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  void _handleTabChanged(ClinicalWorkspaceSection section) {
    if (section == _section) {
      return;
    }
    setState(() => _section = section);
    _updateUrlForSection(section);
    _searchController.clear();
    final ClinicalQueueScope scope = _clinicalSectionScope(section);
    ref.read(clinicalWorkspaceControllerProvider.notifier).applyScope(scope);
  }

  void _updateUrlForSection(ClinicalWorkspaceSection section) {
    if (!mounted) {
      return;
    }
    final String tab = _clinicalSectionQueryValue(section);
    final String location = AppRoutes.clinical.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    GoRouter.of(context).replace<void>(location);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClinicalWorkspaceState state = widget.state;

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final ClinicalWorkspaceSection section
                    in ClinicalWorkspaceSection.values)
                  AppTabItem(
                    id: section.name,
                    icon: _clinicalSectionIcon(section),
                    label: _clinicalSectionLabel(l10n, section),
                    count: _clinicalSectionCount(state, section),
                    countTone: _clinicalSectionCountTone(section),
                  ),
              ],
              selectedId: _section.name,
              onTabTapped: (String tabId) {
                for (final ClinicalWorkspaceSection section
                    in ClinicalWorkspaceSection.values) {
                  if (section.name == tabId) {
                    _handleTabChanged(section);
                    break;
                  }
                }
              },
              primaryAction: _clinicalPrimaryAction(context, state),
              secondaryActions: _clinicalSecondaryActions(context),
            ),
            SizedBox(height: theme.spacing.sm),
            _ClinicalWorklistPanel(
              state: state,
              section: _section,
              searchController: _searchController,
              columnVisibilityController: _tableColumnController,
              onSearchChanged: _applySearch,
              onSearchSubmitted: _applySearchImmediately,
            ),
          ],
        ),
      ),
    );
  }

  void _applySearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      ref
          .read(clinicalWorkspaceControllerProvider.notifier)
          .applySearch(value, showLoading: false);
    });
  }

  void _applySearchImmediately(String value) {
    _searchDebounce?.cancel();
    ref
        .read(clinicalWorkspaceControllerProvider.notifier)
        .applySearch(value, showLoading: false);
  }

  Widget _clinicalPrimaryAction(
    BuildContext context,
    ClinicalWorkspaceState state,
  ) {
    final AppLocalizations l10n = context.l10n;
    return switch (_section) {
      ClinicalWorkspaceSection.all ||
      ClinicalWorkspaceSection.waitingReview ||
      ClinicalWorkspaceSection.urgent ||
      ClinicalWorkspaceSection.resultsReady ||
      ClinicalWorkspaceSection.inConsultation ||
      ClinicalWorkspaceSection.completed => AppTabToolbarPrimary(
        label: l10n.commonRefreshActionLabel,
        icon: Icons.refresh,
        isLoading: state.isRefreshing,
        semanticLabel: l10n.commonRefreshActionLabel,
        tooltip: l10n.commonRefreshActionLabel,
        onPressed: state.isRefreshing
            ? null
            : () async {
                final AppFailure? failure = await ref
                    .read(clinicalWorkspaceControllerProvider.notifier)
                    .refresh();
                if (context.mounted) {
                  _showFailureIfNeeded(context, failure);
                }
              },
      ),
    };
  }

  List<Widget> _clinicalSecondaryActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return switch (_section) {
      ClinicalWorkspaceSection.all => const <Widget>[],
      ClinicalWorkspaceSection.waitingReview ||
      ClinicalWorkspaceSection.urgent ||
      ClinicalWorkspaceSection.inConsultation => <Widget>[
        AppTabToolbarAction(
          label: l10n.navigationOpdShortLabel,
          icon: Icons.local_hospital_outlined,
          semanticLabel: l10n.navigationOpdShortLabel,
          tooltip: l10n.navigationOpdShortLabel,
          onPressed: () => context.go(AppRoutes.opd.location()),
        ),
      ],
      ClinicalWorkspaceSection.resultsReady => <Widget>[
        AppTabToolbarAction(
          label: l10n.navigationLabShortLabel,
          icon: Icons.science_outlined,
          semanticLabel: l10n.navigationLabShortLabel,
          tooltip: l10n.navigationLabShortLabel,
          onPressed: () => context.go(AppRoutes.lab.location()),
        ),
      ],
      ClinicalWorkspaceSection.completed => <Widget>[
        AppTabToolbarAction(
          label: l10n.navigationDischargeShortLabel,
          icon: Icons.logout_outlined,
          semanticLabel: l10n.navigationDischargeShortLabel,
          tooltip: l10n.navigationDischargeShortLabel,
          onPressed: () => context.go(AppRoutes.discharge.location()),
        ),
      ],
    };
  }
}

ClinicalQueueScope _clinicalSectionScope(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.all => ClinicalQueueScope.all,
    ClinicalWorkspaceSection.waitingReview => ClinicalQueueScope.waitingReview,
    ClinicalWorkspaceSection.urgent => ClinicalQueueScope.urgent,
    ClinicalWorkspaceSection.resultsReady => ClinicalQueueScope.resultsReady,
    ClinicalWorkspaceSection.inConsultation =>
      ClinicalQueueScope.inConsultation,
    ClinicalWorkspaceSection.completed => ClinicalQueueScope.completed,
  };
}

IconData _clinicalSectionIcon(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.all => Icons.inventory_2_outlined,
    ClinicalWorkspaceSection.waitingReview => Icons.rate_review_outlined,
    ClinicalWorkspaceSection.urgent => Icons.priority_high_outlined,
    ClinicalWorkspaceSection.resultsReady => Icons.science_outlined,
    ClinicalWorkspaceSection.inConsultation =>
      Icons.medical_information_outlined,
    ClinicalWorkspaceSection.completed => Icons.task_alt_outlined,
  };
}

String _clinicalSectionLabel(
  AppLocalizations l10n,
  ClinicalWorkspaceSection section,
) {
  return switch (section) {
    ClinicalWorkspaceSection.all => l10n.clinicalSectionAllLabel,
    ClinicalWorkspaceSection.waitingReview =>
      l10n.clinicalSectionWaitingReviewLabel,
    ClinicalWorkspaceSection.urgent => l10n.clinicalSectionUrgentLabel,
    ClinicalWorkspaceSection.resultsReady =>
      l10n.clinicalSectionResultsReadyLabel,
    ClinicalWorkspaceSection.inConsultation =>
      l10n.clinicalSectionInConsultationLabel,
    ClinicalWorkspaceSection.completed => l10n.clinicalSectionCompletedLabel,
  };
}

int _clinicalSectionCount(
  ClinicalWorkspaceState state,
  ClinicalWorkspaceSection section,
) {
  return switch (section) {
    ClinicalWorkspaceSection.all => _pageTotal(state.worklist),
    ClinicalWorkspaceSection.waitingReview => state.waitingReviewCount,
    ClinicalWorkspaceSection.urgent => state.urgentCount,
    ClinicalWorkspaceSection.resultsReady => state.resultsReadyCount,
    ClinicalWorkspaceSection.inConsultation => state.inConsultationCount,
    ClinicalWorkspaceSection.completed => state.completedCount,
  };
}

AppTabCountTone _clinicalSectionCountTone(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.urgent => AppTabCountTone.danger,
    ClinicalWorkspaceSection.waitingReview ||
    ClinicalWorkspaceSection.inConsultation => AppTabCountTone.warning,
    ClinicalWorkspaceSection.all ||
    ClinicalWorkspaceSection.resultsReady ||
    ClinicalWorkspaceSection.completed => AppTabCountTone.info,
  };
}

String _clinicalSectionQueryValue(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.all => '',
    ClinicalWorkspaceSection.waitingReview => 'waiting-review',
    ClinicalWorkspaceSection.urgent => 'urgent',
    ClinicalWorkspaceSection.resultsReady => 'results-ready',
    ClinicalWorkspaceSection.inConsultation => 'in-consultation',
    ClinicalWorkspaceSection.completed => 'completed',
  };
}

List<_ClinicalTableColumnId> _clinicalDefaultColumnsForSection(
  ClinicalWorkspaceSection section,
) {
  const List<_ClinicalTableColumnId> standardDefaults =
      <_ClinicalTableColumnId>[
        _ClinicalTableColumnId.patient,
        _ClinicalTableColumnId.queue,
        _ClinicalTableColumnId.provider,
        _ClinicalTableColumnId.status,
        _ClinicalTableColumnId.nextAction,
      ];
  return switch (section) {
    ClinicalWorkspaceSection.all => standardDefaults,
    ClinicalWorkspaceSection.waitingReview => standardDefaults,
    ClinicalWorkspaceSection.urgent => standardDefaults,
    ClinicalWorkspaceSection.resultsReady => const <_ClinicalTableColumnId>[
      _ClinicalTableColumnId.patient,
      _ClinicalTableColumnId.encounterType,
      _ClinicalTableColumnId.queue,
      _ClinicalTableColumnId.status,
      _ClinicalTableColumnId.nextAction,
    ],
    ClinicalWorkspaceSection.inConsultation => const <_ClinicalTableColumnId>[
      _ClinicalTableColumnId.patient,
      _ClinicalTableColumnId.location,
      _ClinicalTableColumnId.provider,
      _ClinicalTableColumnId.status,
      _ClinicalTableColumnId.nextAction,
    ],
    ClinicalWorkspaceSection.completed => const <_ClinicalTableColumnId>[
      _ClinicalTableColumnId.patient,
      _ClinicalTableColumnId.queue,
      _ClinicalTableColumnId.encounterType,
      _ClinicalTableColumnId.status,
      _ClinicalTableColumnId.nextAction,
    ],
  };
}

class _ClinicalWorklistPanel extends ConsumerWidget {
  const _ClinicalWorklistPanel({
    required this.state,
    required this.section,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final ClinicalWorkspaceState state;
  final ClinicalWorkspaceSection section;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<ClinicalWorklistEntry>
  columnVisibilityController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    return AppListTable<ClinicalWorklistEntry>(
      key: ValueKey<String>('clinical_table_${section.name}'),
      page: state.worklist,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'clinical_${section.name}',
      columnWidthStorageKey: 'clinical_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      displayMode: AppListTableDisplayMode.adaptive,
      isLoading: state.isRefreshing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      previousPageLabel: l10n.opdPreviousPageLabel,
      nextPageLabel: l10n.opdNextPageLabel,
      pageLabelBuilder: (AppPage<ClinicalWorklistEntry> page) {
        return _pageLabel(context, page);
      },
      onPageChanged: controller.changePage,
      onRowSelected: (ClinicalWorklistEntry entry) {
        _openClinicalEntryDialog(context, ref, entry);
      },
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.clinicalNoWorklistTitle,
        body: l10n.clinicalNoWorklistBody,
        icon: Icons.assignment_outlined,
      ),
      search: _worklistSearch(
        context,
        ref,
        controller,
        searchController,
        filters: state.query.filters,
        scope: state.query.scope,
        filterEntries: state.worklist.items,
        onSearchChanged: onSearchChanged,
        onSearchSubmitted: onSearchSubmitted,
      ),
      columns: <AppListTableColumn<ClinicalWorklistEntry>>[
        for (final _ClinicalTableColumnId column
            in _clinicalDefaultColumnsForSection(section))
          _clinicalDataColumn(context, column),
      ],
      columnChoices: <AppListTableColumn<ClinicalWorklistEntry>>[
        for (final _ClinicalTableColumnId column
            in _availableClinicalTableColumns)
          _clinicalDataColumn(context, column),
      ],
      mobileItemBuilder: _clinicalWorklistMobileItemBuilderFor(section),
      itemKeyBuilder: _clinicalWorklistItemKey,
      rowColorBuilder: _clinicalRowColor,
    );
  }
}

AppListTableSearch<ClinicalWorklistEntry> _worklistSearch(
  BuildContext context,
  WidgetRef ref,
  ClinicalWorkspaceController controller,
  TextEditingController searchController, {
  required ClinicalWorklistFilters filters,
  required ClinicalQueueScope scope,
  required List<ClinicalWorklistEntry> filterEntries,
  required ValueChanged<String> onSearchChanged,
  required ValueChanged<String> onSearchSubmitted,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableSearch<ClinicalWorklistEntry>(
    controller: searchController,
    semanticLabel: l10n.clinicalSearchLabel,
    hintText: l10n.clinicalSearchHint,
    clearLabel: l10n.opdClearFiltersAction,
    matcher: (ClinicalWorklistEntry item, String query) {
      if (item.matchesSearch(query, filters: filters)) {
        return true;
      }
      final String needle = query.trim().toLowerCase();
      if (needle.isEmpty) {
        return true;
      }
      return clinicalWorklistSearchHaystack(
        context,
        ref,
        item,
      ).any((String value) => value.toLowerCase().contains(needle));
    },
    onChanged: onSearchChanged,
    onSubmitted: onSearchSubmitted,
    showAdvancedFilterButton: true,
    advancedFilterButtonLabel: l10n.clinicalFiltersLabel,
    advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
    advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
    advancedFilterResetLabel: l10n.opdClearFiltersAction,
    textFilters: _clinicalTextFilters(l10n),
    searchFieldLabel: l10n.clinicalSearchLabel,
    allFieldsLabel: l10n.opdAllFieldsFilterLabel,
    dateFilterLabel: l10n.clinicalLastUpdatedLabel,
    dateFromLabel: l10n.opdDateFromLabel,
    dateToLabel: l10n.opdDateToLabel,
    datePickerButtonLabel: l10n.opdDatePickerButtonLabel,
    invalidDateMessage: l10n.opdInvalidDateMessage,
    filterGroups: _clinicalFilterGroups(l10n, filterEntries),
    filterValue: _filterValueFromQuery(filters, search: searchController.text),
    hasActiveFilters: _hasActiveClinicalFilters(
      filters,
      search: searchController.text,
    ),
    onFilterChanged: (AppSearchBarFilterValue value) {
      final String search = _searchFromValue(value);
      if (searchController.text != search) {
        searchController.text = search;
      }
      // Scope is owned by the tab strip; preserve the active tab scope.
      controller.applyWorklistFilters(
        scope: scope,
        filters: _filtersFromValue(value),
        search: search,
      );
    },
  );
}

enum _ClinicalTableColumnId {
  patient,
  patientId,
  phone,
  ageSex,
  queue,
  status,
  nextAction,
  provider,
  lastUpdated,
  encounter,
  admission,
  encounterType,
  location,
}

const List<_ClinicalTableColumnId> _availableClinicalTableColumns =
    <_ClinicalTableColumnId>[
      _ClinicalTableColumnId.patient,
      _ClinicalTableColumnId.patientId,
      _ClinicalTableColumnId.phone,
      _ClinicalTableColumnId.ageSex,
      _ClinicalTableColumnId.queue,
      _ClinicalTableColumnId.status,
      _ClinicalTableColumnId.nextAction,
      _ClinicalTableColumnId.provider,
      _ClinicalTableColumnId.lastUpdated,
      _ClinicalTableColumnId.encounter,
      _ClinicalTableColumnId.admission,
      _ClinicalTableColumnId.encounterType,
      _ClinicalTableColumnId.location,
    ];

String _clinicalTableColumnLabel(
  BuildContext context,
  _ClinicalTableColumnId column,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (column) {
    _ClinicalTableColumnId.patient => l10n.opdPatientColumnLabel,
    _ClinicalTableColumnId.patientId => l10n.opdPatientIdLabel,
    _ClinicalTableColumnId.phone => l10n.patientsPhoneLabel,
    _ClinicalTableColumnId.ageSex => l10n.patientsAgeSexColumnLabel,
    _ClinicalTableColumnId.queue => l10n.clinicalSourceQueueLabel,
    _ClinicalTableColumnId.status => l10n.opdStatusColumnLabel,
    _ClinicalTableColumnId.nextAction => l10n.clinicalNextActionColumnLabel,
    _ClinicalTableColumnId.provider => l10n.opdProviderColumnLabel,
    _ClinicalTableColumnId.lastUpdated => l10n.clinicalLastUpdatedLabel,
    _ClinicalTableColumnId.encounter => l10n.clinicalEncounterNumberLabel,
    _ClinicalTableColumnId.admission => l10n.clinicalAdmissionNumberLabel,
    _ClinicalTableColumnId.encounterType => l10n.clinicalEncounterTypeLabel,
    _ClinicalTableColumnId.location => l10n.clinicalLocationLabel,
  };
}

AppListTableColumn<ClinicalWorklistEntry> _clinicalDataColumn(
  BuildContext context,
  _ClinicalTableColumnId column,
) {
  final String label = _clinicalTableColumnLabel(context, column);
  final AppLocalizations l10n = context.l10n;

  return AppListTableColumn<ClinicalWorklistEntry>(
    id: column.name,
    label: label,
    alwaysVisible:
        column == _ClinicalTableColumnId.status ||
        column == _ClinicalTableColumnId.nextAction,
    sortComparator: _clinicalSortComparator(column),
    cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
      return switch (column) {
        _ClinicalTableColumnId.patient => AppListItemText(
          title: item.displayTitle,
          subtitle: item.worklistPatientSecondaryLine,
        ),
        _ClinicalTableColumnId.patientId => Text(
          item.apiPatientId ?? l10n.profileUnknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _ClinicalTableColumnId.phone => Text(
          item.patientPhone ?? l10n.profileUnknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _ClinicalTableColumnId.ageSex => Text(
          _clinicalWorklistAgeSexLabel(context, item),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _ClinicalTableColumnId.queue => _ClinicalQueueCell(item: item),
        _ClinicalTableColumnId.status => _ClinicalStatusColumnCell(item: item),
        _ClinicalTableColumnId.nextAction => _ClinicalWorklistNextActionCell(
          item: item,
        ),
        _ClinicalTableColumnId.provider => Text(
          _clinicalProviderLabel(l10n, item),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _ClinicalTableColumnId.lastUpdated => Text(
          _dateTimeLabel(context, item.updatedAt ?? item.startedAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _ClinicalTableColumnId.encounter => Text(
          item.apiEncounterId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _ClinicalTableColumnId.admission => Text(
          item.apiAdmissionId ?? l10n.profileUnknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _ClinicalTableColumnId.encounterType => Text(
          _apiLabel(item.encounterType ?? ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        _ClinicalTableColumnId.location => Text(
          item.currentLocation ?? l10n.profileUnknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      };
    },
    tooltip: label,
  );
}

AppListTableSortComparator<ClinicalWorklistEntry> _clinicalSortComparator(
  _ClinicalTableColumnId column,
) {
  return (ClinicalWorklistEntry left, ClinicalWorklistEntry right) {
    return switch (column) {
      _ClinicalTableColumnId.patient => appListTableCompareText(
        left.displayTitle,
        right.displayTitle,
      ),
      _ClinicalTableColumnId.patientId => appListTableCompareText(
        left.apiPatientId,
        right.apiPatientId,
      ),
      _ClinicalTableColumnId.phone => appListTableCompareText(
        left.patientPhone,
        right.patientPhone,
      ),
      _ClinicalTableColumnId.ageSex => appListTableCompareText(
        left.patientAgeSex,
        right.patientAgeSex,
      ),
      _ClinicalTableColumnId.queue => appListTableCompareText(
        left.sourceQueue,
        right.sourceQueue,
      ),
      _ClinicalTableColumnId.status => appListTableCompareText(
        left.stage ?? left.status,
        right.stage ?? right.status,
      ),
      _ClinicalTableColumnId.nextAction => appListTableCompareText(
        left.nextStep,
        right.nextStep,
      ),
      _ClinicalTableColumnId.provider => appListTableCompareText(
        left.providerDisplayName,
        right.providerDisplayName,
      ),
      _ClinicalTableColumnId.lastUpdated => appListTableCompareDateTime(
        left.updatedAt ?? left.startedAt,
        right.updatedAt ?? right.startedAt,
      ),
      _ClinicalTableColumnId.encounter => appListTableCompareText(
        left.apiEncounterId,
        right.apiEncounterId,
      ),
      _ClinicalTableColumnId.admission => appListTableCompareText(
        left.apiAdmissionId,
        right.apiAdmissionId,
      ),
      _ClinicalTableColumnId.encounterType => appListTableCompareText(
        left.encounterType,
        right.encounterType,
      ),
      _ClinicalTableColumnId.location => appListTableCompareText(
        left.currentLocation,
        right.currentLocation,
      ),
    };
  };
}

String _clinicalProviderLabel(
  AppLocalizations l10n,
  ClinicalWorklistEntry item,
) {
  final String? provider = item.providerDisplayName?.trim();
  if (provider != null && provider.isNotEmpty) {
    return provider;
  }
  return l10n.clinicalNotAssignedLabel;
}

String _clinicalWorklistAgeSexLabel(
  BuildContext context,
  ClinicalWorklistEntry item,
) {
  final AppLocalizations l10n = context.l10n;
  final String ageSex = item.patientAgeSex?.trim() ?? '';
  if (ageSex.isNotEmpty) {
    return ageSex;
  }
  final String age = _clinicalAgeLabel(item.patientDateOfBirth);
  final String gender = _clinicalGenderLabel(l10n, item.patientGender);
  return _joinDisplay(<String?>[age, gender]);
}

class _ClinicalQueueCell extends StatelessWidget {
  const _ClinicalQueueCell({required this.item});

  final ClinicalWorklistEntry item;

  @override
  Widget build(BuildContext context) {
    return _ClinicalStatusText(
      status: AppWorkspaceStatus(
        label: _apiLabel(item.sourceQueue),
        tone: _sourceQueueTone(item.sourceQueue),
      ),
    );
  }
}

class _ClinicalStatusColumnCell extends StatelessWidget {
  const _ClinicalStatusColumnCell({required this.item});

  final ClinicalWorklistEntry item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        AppWorkspaceStatusBadge(status: _entryStatus(item)),
        if (item.isUrgent)
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: l10n.clinicalUrgentSummaryLabel,
              tone: AppWorkspaceStatusTone.error,
              icon: Icons.priority_high_outlined,
            ),
          ),
        if (item.resultsReady)
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: l10n.clinicalResultsReadySummaryLabel,
              tone: AppWorkspaceStatusTone.success,
              icon: Icons.science_outlined,
            ),
          ),
      ],
    );
  }
}

class _ClinicalWorklistNextActionCell extends ConsumerWidget {
  const _ClinicalWorklistNextActionCell({required this.item});

  final ClinicalWorklistEntry item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String encounterId = item.apiEncounterId.trim();
    if (encounterId.isNotEmpty) {
      final WorkflowActionContext actionContext = WorkflowActionContext(
        encounterId: encounterId,
        patientId: item.apiPatientId,
        admissionId: item.apiAdmissionId,
        stage: item.stage ?? item.status,
        nextStep: item.nextStep,
        sourceModule: _clinicalWorkflowSourceModule(item.sourceQueue),
      );
      final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
      final WorkflowAction? action = WorkflowActionRegistry.instance.resolve(
        context,
        actionContext,
        policy: policy,
      );
      if (action != null) {
        return WorkflowActionButton(
          encounterId: encounterId,
          patientId: item.apiPatientId,
          admissionId: item.apiAdmissionId,
          stage: item.stage ?? item.status,
          nextStep: item.nextStep,
          sourceModule: _clinicalWorkflowSourceModule(item.sourceQueue),
          compact: true,
        );
      }
    }

    final String dispositionLabel = clinicalDispositionActionLabel(
      l10n,
      sourceQueue: item.sourceQueue,
      status: item.status,
      stage: item.stage,
      location: item.currentLocation,
      hasAdmission: item.admissionId?.trim().isNotEmpty ?? false,
    );
    final bool canCompleteDisposition =
        !item.isTerminal &&
        isClinicalDispositionActionAvailable(
          sourceQueue: item.sourceQueue,
          status: item.status,
          stage: item.stage,
          location: item.currentLocation,
          hasAdmission: item.admissionId?.trim().isNotEmpty ?? false,
          hasOpdFlow: item.opdFlowApiId?.trim().isNotEmpty ?? false,
        );
    if (canCompleteDisposition) {
      return AppAccessActionGate(
        requirement: _ClinicalWorkspaceContentState._writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          return _ClinicalCompactFallbackAction(
            label: dispositionLabel,
            icon: Icons.task_alt_outlined,
            enabled: isAllowed,
            onPressed: isAllowed
                ? () => _openCompleteDispositionDialog(
                    context,
                    ref,
                    ref.read(clinicalWorkspaceControllerProvider.notifier),
                    entry: item,
                    actionLabel: dispositionLabel,
                  )
                : null,
          );
        },
      );
    }

    return _ClinicalCompactFallbackAction(
      label: l10n.clinicalOpenEncounterAction,
      icon: Icons.open_in_new,
      onPressed: () => _openClinicalEntryDialog(context, ref, item),
    );
  }
}

class _ClinicalCompactFallbackAction extends StatelessWidget {
  const _ClinicalCompactFallbackAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.xs,
              vertical: 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 14, color: primaryColor),
                SizedBox(width: theme.spacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!enabled) ...<Widget>[
                  SizedBox(width: theme.spacing.xs),
                  Icon(
                    Icons.lock_outlined,
                    size: 10,
                    color: primaryColor.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _clinicalWorkflowSourceModule(String sourceQueue) {
  return switch (sourceQueue.toUpperCase()) {
    'OPD' => 'opd',
    'TRIAGE' => 'triage',
    'IPD' || 'ADMISSION' => 'ipd',
    _ => null,
  };
}

List<String> clinicalWorklistSearchHaystack(
  BuildContext context,
  WidgetRef ref,
  ClinicalWorklistEntry item,
) {
  final AppLocalizations l10n = context.l10n;
  final List<String> values = <String>[
    item.displayTitle,
    item.worklistPatientSecondaryLine ?? '',
    item.apiPatientId ?? '',
    item.patientPhone ?? '',
    _clinicalWorklistAgeSexLabel(context, item),
    _apiLabel(item.sourceQueue),
    _entryStatus(item).label,
    _clinicalProviderLabel(l10n, item),
    _dateTimeLabel(context, item.updatedAt ?? item.startedAt),
    item.apiEncounterId,
    item.apiAdmissionId ?? '',
    _apiLabel(item.encounterType ?? ''),
    item.currentLocation ?? '',
    if (item.isUrgent) l10n.clinicalUrgentSummaryLabel,
    if (item.resultsReady) l10n.clinicalResultsReadySummaryLabel,
    l10n.clinicalOpenEncounterAction,
  ];

  final String encounterId = item.apiEncounterId.trim();
  if (encounterId.isNotEmpty) {
    final String workflowLabel = workflowActionLabel(
      context,
      ref,
      WorkflowActionContext(
        encounterId: encounterId,
        patientId: item.apiPatientId,
        admissionId: item.apiAdmissionId,
        stage: item.stage ?? item.status,
        nextStep: item.nextStep,
        sourceModule: _clinicalWorkflowSourceModule(item.sourceQueue),
      ),
    );
    if (workflowLabel != l10n.profileUnknownValue) {
      values.add(workflowLabel);
    }
  }

  if (!item.isTerminal &&
      isClinicalDispositionActionAvailable(
        sourceQueue: item.sourceQueue,
        status: item.status,
        stage: item.stage,
        location: item.currentLocation,
        hasAdmission: item.admissionId?.trim().isNotEmpty ?? false,
        hasOpdFlow: item.opdFlowApiId?.trim().isNotEmpty ?? false,
      )) {
    values.add(
      clinicalDispositionActionLabel(
        l10n,
        sourceQueue: item.sourceQueue,
        status: item.status,
        stage: item.stage,
        location: item.currentLocation,
        hasAdmission: item.admissionId?.trim().isNotEmpty ?? false,
      ),
    );
  }

  return values
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}

Widget Function(BuildContext context, ClinicalWorklistEntry item)
_clinicalWorklistMobileItemBuilderFor(ClinicalWorkspaceSection section) {
  return (BuildContext context, ClinicalWorklistEntry item) {
    return _ClinicalWorklistMobileItem(section: section, item: item);
  };
}

class _ClinicalWorklistMobileItem extends ConsumerWidget {
  const _ClinicalWorklistMobileItem({
    required this.section,
    required this.item,
  });

  final ClinicalWorkspaceSection section;
  final ClinicalWorklistEntry item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppListItemText(
                  title: item.displayTitle,
                  subtitle: item.worklistPatientSecondaryLine,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppWorkspaceStatusBadge(status: _entryStatus(item)),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          ..._clinicalMobileDetailWidgets(context, l10n, section, item),
          SizedBox(height: theme.spacing.xs),
          _ClinicalWorklistNextActionCell(item: item),
        ],
      ),
    );
  }
}

List<Widget> _clinicalMobileDetailWidgets(
  BuildContext context,
  AppLocalizations l10n,
  ClinicalWorkspaceSection section,
  ClinicalWorklistEntry item,
) {
  final ThemeData theme = Theme.of(context);
  final TextStyle? detailStyle = theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );

  return switch (section) {
    ClinicalWorkspaceSection.resultsReady => <Widget>[
      Text(_apiLabel(item.encounterType ?? ''), style: detailStyle),
      _ClinicalQueueCell(item: item),
    ],
    ClinicalWorkspaceSection.inConsultation => <Widget>[
      Text(
        item.currentLocation ?? l10n.profileUnknownValue,
        style: detailStyle,
      ),
      Text(_clinicalProviderLabel(l10n, item), style: detailStyle),
    ],
    ClinicalWorkspaceSection.completed => <Widget>[
      _ClinicalQueueCell(item: item),
      Text(_apiLabel(item.encounterType ?? ''), style: detailStyle),
    ],
    _ => <Widget>[
      _ClinicalQueueCell(item: item),
      Text(_clinicalProviderLabel(l10n, item), style: detailStyle),
    ],
  };
}

class _ClinicalStatusText extends StatelessWidget {
  const _ClinicalStatusText({required this.status, this.textStyle});

  final AppWorkspaceStatus status;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _clinicalToneColor(theme, status.tone);
    final IconData icon = status.icon ?? _clinicalStatusIcon(status.tone);
    final TextStyle? effectiveStyle = (textStyle ?? theme.textTheme.labelLarge)
        ?.copyWith(color: color, fontWeight: FontWeight.w700);

    return Semantics(
      label: status.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Row(
          children: <Widget>[
            Icon(icon, size: theme.appTokens.listIconSize, color: color),
            SizedBox(width: theme.spacing.xs),
            Expanded(
              child: Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: effectiveStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

LocalKey _clinicalWorklistItemKey(ClinicalWorklistEntry item) {
  return ValueKey<String>('${item.sourceQueue}-${item.encounterId}');
}

Color? _clinicalRowColor(BuildContext context, ClinicalWorklistEntry item) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  if (item.isUrgent) {
    return colorScheme.errorContainer.withValues(alpha: 0.18);
  }
  if (item.resultsReady) {
    return colorScheme.tertiaryContainer.withValues(alpha: 0.16);
  }
  if (clinicalWorklistEntryMatchesScope(
    item,
    ClinicalQueueScope.waitingReview,
  )) {
    return colorScheme.secondaryContainer.withValues(alpha: 0.14);
  }
  if (clinicalWorklistEntryMatchesScope(
    item,
    ClinicalQueueScope.inConsultation,
  )) {
    return colorScheme.primaryContainer.withValues(alpha: 0.12);
  }
  return null;
}

Future<void> _openClinicalEntryDialog(
  BuildContext context,
  WidgetRef ref,
  ClinicalWorklistEntry entry,
) async {
  final ClinicalWorkspaceController controller = ref.read(
    clinicalWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectEntry(entry);
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    _showFailureIfNeeded(context, failure);
    return;
  }

  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ClinicalEncounterDialog(initialEntry: entry),
  );
  controller.clearSelection();
}

class _ClinicalEncounterDialog extends ConsumerWidget {
  const _ClinicalEncounterDialog({required this.initialEntry});

  final ClinicalWorklistEntry initialEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<ClinicalWorkspaceState>> asyncState = ref.watch(
      clinicalWorkspaceControllerProvider,
    );

    return AppDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.clinicalEncounterDetailsTitle(initialEntry.displayTitle)),
          Text(
            l10n.clinicalEncounterDetailsSubtitle(
              initialEntry.encounterPublicId ?? initialEntry.encounterId,
              _apiLabel(initialEntry.sourceQueue),
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      icon: const Icon(Icons.medical_services_outlined),
      scrollable: true,
      maxWidth: 1120,
      content: asyncState.when(
        data: (Result<ClinicalWorkspaceState> result) {
          return result.when(
            success: (ClinicalWorkspaceState state) {
              final ClinicalEncounterBundle? bundle = state.selectedBundle;
              if (bundle == null ||
                  !_isSameWorklistEntry(bundle.entry, initialEntry)) {
                if (!state.isRefreshingDetail && !state.isSaving) {
                  return AppWorkspaceStatePanel.state(
                    variant: AppStateViewVariant.empty,
                    title: l10n.clinicalNoSelectionTitle,
                    body: l10n.clinicalNoSelectionBody,
                    icon: Icons.medical_services_outlined,
                  );
                }
                return AppWorkspaceStatePanel.state(
                  variant: AppStateViewVariant.loading,
                  title: l10n.clinicalLoadingTitle,
                  body: l10n.clinicalLoadingBody,
                  icon: Icons.medical_services_outlined,
                );
              }
              return _ClinicalDetailPanel(state: state);
            },
            failure: (AppFailure failure) {
              return AppFailureStateView(
                failure: failure,
                onRetry: () {
                  ref
                      .read(clinicalWorkspaceControllerProvider.notifier)
                      .selectEntry(initialEntry);
                },
              );
            },
          );
        },
        error: (_, _) =>
            const AppFailureStateView(failure: AppFailure.unexpected()),
        loading: () => AppWorkspaceStatePanel.state(
          variant: AppStateViewVariant.loading,
          title: l10n.clinicalLoadingTitle,
          body: l10n.clinicalLoadingBody,
          icon: Icons.medical_services_outlined,
        ),
      ),
    );
  }
}

class _ClinicalDetailPanel extends ConsumerWidget {
  const _ClinicalDetailPanel({required this.state});

  final ClinicalWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalEncounterBundle? bundle = state.selectedBundle;
    if (bundle == null) {
      return AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.clinicalNoSelectionTitle,
        body: l10n.clinicalNoSelectionBody,
        icon: Icons.medical_services_outlined,
      );
    }

    final ClinicalWorklistEntry entry = bundle.entry;
    final AppWorkspaceStatus primaryStatus = _entryStatus(entry);
    final ClinicalTriageHandoff? triageHandoff = bundle.triageHandoff;
    final List<Widget> sections = <Widget>[
      _ClinicalEncounterContextPanel(
        entry: entry,
        status: primaryStatus,
        showPrimaryStatus: !_clinicalTriageShowsWorkflowStage(triageHandoff),
        omitSubtitleFields: true,
        alerts: <AppWorkspaceStatus>[
          if (entry.isUrgent)
            AppWorkspaceStatus(
              label: l10n.clinicalUrgentSummaryLabel,
              tone: AppWorkspaceStatusTone.error,
            ),
        ],
      ),
      if (triageHandoff?.hasContent ?? false)
        _ClinicalTriageHandoffPanel(handoff: triageHandoff!),
      _ClinicalActionBar(bundle: bundle, referenceData: state.referenceData),
      if (_clinicalResultsPreviewEntries(bundle) case final previewEntries
          when previewEntries.isNotEmpty)
        AppClinicalResultsPreview(
          title: l10n.clinicalResultsChronologyTitle,
          status: AppClinicalResultStatus.verified,
          encounterPublicId: bundle.entry.encounterPublicId,
          child: AppClinicalResultsPreviewList(
            entries: previewEntries,
            dense: true,
          ),
        ),
      if (bundle.labOrders.isNotEmpty)
        ClinicalLabOrdersTablePanel(
          orders: bundle.labOrders,
          onEdit: (BuildContext context, ClinicalRelatedRecord order) =>
              _openLabDialog(
                context,
                ref.read(clinicalWorkspaceControllerProvider.notifier),
                state.referenceData,
                existingOrder: order,
              ),
          onCancel: (BuildContext context, ClinicalRelatedRecord order) =>
              _confirmLabOrderMutation(
                context: context,
                title: l10n.clinicalCancelLabOrderDialogTitle,
                body: l10n.clinicalCancelLabOrderDialogBody,
                confirmLabel: l10n.clinicalCancelLabOrderAction,
                action: () => ref
                    .read(clinicalWorkspaceControllerProvider.notifier)
                    .cancelLabOrder(order.id),
              ),
          onDelete: (BuildContext context, ClinicalRelatedRecord order) =>
              _confirmLabOrderMutation(
                context: context,
                title: l10n.clinicalDeleteLabOrderDialogTitle,
                body: l10n.clinicalDeleteLabOrderDialogBody,
                confirmLabel: l10n.clinicalDeleteLabOrderAction,
                action: () => ref
                    .read(clinicalWorkspaceControllerProvider.notifier)
                    .deleteLabOrder(order.id),
              ),
        ),
      if (bundle.radiologyOrders.isNotEmpty)
        ClinicalRadiologyOrdersTablePanel(
          orders: bundle.radiologyOrders,
          onCancel: (BuildContext context, ClinicalRelatedRecord order) =>
              _confirmLabOrderMutation(
                context: context,
                title: l10n.clinicalCancelRadiologyOrderDialogTitle,
                body: l10n.clinicalCancelRadiologyOrderDialogBody,
                confirmLabel: l10n.clinicalCancelRadiologyOrderAction,
                action: () => ref
                    .read(clinicalWorkspaceControllerProvider.notifier)
                    .cancelRadiologyOrder(order.id),
              ),
          onDelete: (BuildContext context, ClinicalRelatedRecord order) =>
              _confirmLabOrderMutation(
                context: context,
                title: l10n.clinicalDeleteRadiologyOrderDialogTitle,
                body: l10n.clinicalDeleteRadiologyOrderDialogBody,
                confirmLabel: l10n.clinicalDeleteRadiologyOrderAction,
                action: () => ref
                    .read(clinicalWorkspaceControllerProvider.notifier)
                    .deleteRadiologyOrder(order.id),
              ),
        ),
      if (_clinicalHasRecordSections(bundle))
        _ClinicalRecordSections(bundle: bundle),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withClinicalSectionSpacing(context, sections),
    );
  }
}

class _ClinicalEncounterContextPanel extends StatelessWidget {
  const _ClinicalEncounterContextPanel({
    required this.entry,
    required this.status,
    this.showPrimaryStatus = true,
    this.omitSubtitleFields = false,
    this.alerts = const <AppWorkspaceStatus>[],
  });

  final ClinicalWorklistEntry entry;
  final AppWorkspaceStatus status;
  final bool showPrimaryStatus;
  final bool omitSubtitleFields;
  final List<AppWorkspaceStatus> alerts;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String patientNumber = _clinicalPatientNumber(entry);
    final String genderLabel = _clinicalGenderLabel(l10n, entry.patientGender);

    return AppPatientDetails(
      patientName: entry.displayTitle,
      patientNumber: patientNumber,
      patientNumberLabel: l10n.opdPatientIdLabel,
      ageLabel: entry.patientDateOfBirth == null
          ? null
          : formatPatientAge(l10n, entry.patientDateOfBirth),
      genderLabel: genderLabel.isEmpty ? null : genderLabel,
      genderIcon: patientGenderIcon(entry.patientGender),
      compactSupportingText:
          entry.patientDateOfBirth == null && genderLabel.isEmpty
          ? entry.patientAgeSex?.trim()
          : null,
      showAvatar: false,
      semanticLabel: l10n.patientsDetailTitle,
      status: showPrimaryStatus && status.label.isNotEmpty ? status : null,
      alerts: alerts,
      fieldStyle: AppWorkspacePatientContextFieldStyle.tiles,
      expandedFields: _clinicalPatientContextFields(
        context,
        l10n,
        entry,
        omitSubtitleFields: omitSubtitleFields,
      ),
    );
  }
}

class _ClinicalInfoGrid extends StatelessWidget {
  const _ClinicalInfoGrid({required this.fields});

  final List<AppWorkspacePatientContextField> fields;

  @override
  Widget build(BuildContext context) {
    final List<AppWorkspacePatientContextField> visibleFields = fields
        .where((AppWorkspacePatientContextField field) => field.hasValue)
        .toList(growable: false);
    if (visibleFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppInfoTileGrid(
      minItemWidth: 180,
      borderedTiles: false,
      items: <AppInfoTileData>[
        for (final AppWorkspacePatientContextField field in visibleFields)
          AppInfoTileData(
            label: field.label,
            value: field.value,
            icon: field.icon,
            copyable: field.copyable,
            copyTooltip: field.copyTooltip,
            copiedMessage: field.copiedMessage,
            copySemanticLabel: field.copySemanticLabel,
            showCopyIcon: field.showCopyIcon,
            copyPlaceholderValues: field.copyPlaceholderValues,
          ),
      ],
    );
  }
}

class _ClinicalTriageHandoffPanel extends StatelessWidget {
  const _ClinicalTriageHandoffPanel({required this.handoff});

  final ClinicalTriageHandoff handoff;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final int abnormalVitalCount = handoff.vitalSigns.where((
      ClinicalVitalSummary vital,
    ) {
      final String status = vital.status.toUpperCase();
      return status == 'ABNORMAL' || status == 'CRITICAL';
    }).length;
    final AppWorkspaceStatus vitalStatus = AppWorkspaceStatus(
      label: _apiLabel(abnormalVitalCount > 0 ? 'ABNORMAL' : 'NORMAL'),
      tone: abnormalVitalCount > 0
          ? AppWorkspaceStatusTone.warning
          : AppWorkspaceStatusTone.success,
    );
    final List<AppWorkspacePatientContextField> facts =
        <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: l10n.opdTriageLevelLabel,
            value: triageLevelDisplayLabel(
              l10n,
              handoff.triageLevel,
              emptyAsPending: false,
            ),
            icon: Icons.priority_high_outlined,
            tone: appTriageToneForValue(handoff.triageLevel),
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdRouteDecisionLabel,
            value: _apiLabel(handoff.routeTo ?? ''),
            icon: Icons.alt_route_outlined,
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdChiefComplaintLabel,
            value: handoff.chiefComplaint ?? '',
            icon: Icons.sick_outlined,
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdTimeColumnLabel,
            value: handoff.queuedAt == null
                ? ''
                : _dateTimeLabel(context, handoff.queuedAt),
            icon: Icons.schedule_outlined,
          ),
          if (handoff.emergencyIndicator)
            AppWorkspacePatientContextField(
              label: l10n.opdEmergencyIndicatorsLabel,
              value: l10n.opdTriageScopeEmergency,
              icon: Icons.emergency_outlined,
              tone: AppWorkspaceStatusTone.error,
            ),
          AppWorkspacePatientContextField(
            label: l10n.opdTriageNotesLabel,
            value: handoff.triageNotes ?? '',
            icon: Icons.notes_outlined,
          ),
        ];

    return AppWorkspaceDetailPanel(
      title: l10n.opdWorkflowTriageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClinicalWorkflowProgressStrip(handoff: handoff),
          SizedBox(height: theme.spacing.md),
          _ClinicalInfoGrid(fields: facts),
          if (handoff.vitalSigns.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  l10n.opdVitalsSummaryLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _ClinicalStatusText(status: vitalStatus),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            _ClinicalVitalsGrid(vitals: handoff.vitalSigns),
          ],
          if (handoff.alerts.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            Text(
              l10n.opdClinicalAlertsSummaryLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            _ClinicalAlertsWrap(alerts: handoff.alerts),
          ],
        ],
      ),
    );
  }
}

class _ClinicalVitalsGrid extends StatelessWidget {
  const _ClinicalVitalsGrid({required this.vitals});

  final List<ClinicalVitalSummary> vitals;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 620
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        final double gap = theme.spacing.md;
        final double itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            for (final ClinicalVitalSummary vital in vitals)
              SizedBox(
                width: itemWidth,
                child: _ClinicalVitalSummary(vital: vital),
              ),
          ],
        );
      },
    );
  }
}

class _ClinicalVitalSummary extends StatelessWidget {
  const _ClinicalVitalSummary({required this.vital});

  final ClinicalVitalSummary vital;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color valueColor = _clinicalToneColor(
      theme,
      _clinicalVitalTone(vital.status),
    );
    final String recordedAtLabel = vital.recordedAt == null
        ? ''
        : _dateTimeLabel(context, vital.recordedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          _apiLabel(vital.vitalType),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          vital.displayValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (recordedAtLabel.isNotEmpty)
          Text(
            recordedAtLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _ClinicalAlertsWrap extends StatelessWidget {
  const _ClinicalAlertsWrap({required this.alerts});

  final List<ClinicalAlertSummary> alerts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: theme.spacing.md,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (final ClinicalAlertSummary alert in alerts)
          _ClinicalStatusText(
            status: AppWorkspaceStatus(
              label: _joinDisplay(<String?>[
                _apiLabel(alert.severity ?? ''),
                alert.message,
                alert.createdAt == null
                    ? null
                    : _dateTimeLabel(context, alert.createdAt),
              ]),
              tone: _clinicalAlertTone(alert.severity),
              icon: Icons.warning_amber_outlined,
            ),
            textStyle: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _ClinicalActionBar extends ConsumerWidget {
  const _ClinicalActionBar({required this.bundle, required this.referenceData});

  final ClinicalEncounterBundle bundle;
  final ClinicalReferenceData referenceData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    final String dispositionActionLabel = clinicalDispositionActionLabel(
      l10n,
      sourceQueue: bundle.entry.sourceQueue,
      status: bundle.entry.status,
      stage: bundle.entry.stage,
      location: bundle.entry.currentLocation,
      hasAdmission: bundle.entry.admissionId?.trim().isNotEmpty ?? false,
    );
    final bool canCompleteDisposition = isClinicalDispositionActionAvailable(
      sourceQueue: bundle.entry.sourceQueue,
      status: bundle.entry.status,
      stage: bundle.entry.stage,
      location: bundle.entry.currentLocation,
      hasAdmission: bundle.entry.admissionId?.trim().isNotEmpty ?? false,
      hasOpdFlow: bundle.entry.opdFlowApiId?.trim().isNotEmpty ?? false,
    );
    return AppAccessActionGate(
      requirement: _ClinicalWorkspaceContentState._writeRequirement,
      builder: (BuildContext context, bool isAllowed) {
        return AppQuickActions(
          title: l10n.clinicalActionsTitle,
          presentation: AppQuickActionsPresentation.detailPanel,
          actions: <AppActionItem>[
            AppActionItem(
              label: l10n.clinicalAddNoteAction,
              leadingIcon: Icons.note_add_outlined,
              enabled: isAllowed,
              onPressed: () => _openNoteDialog(context, controller),
            ),
            AppActionItem(
              label: l10n.clinicalAddDiagnosisAction,
              leadingIcon: Icons.rule_outlined,
              enabled: isAllowed,
              onPressed: () => _openDiagnosisDialog(context, controller),
            ),
            AppActionItem(
              label: l10n.clinicalRequestLabAction,
              leadingIcon: Icons.science_outlined,
              enabled: isAllowed,
              onPressed: () =>
                  _openLabDialog(context, controller, referenceData),
            ),
            AppActionItem(
              label: l10n.clinicalRequestRadiologyAction,
              leadingIcon: Icons.biotech_outlined,
              enabled: isAllowed,
              onPressed: () =>
                  _openRadiologyDialog(context, controller, referenceData),
            ),
            AppActionItem(
              label: l10n.clinicalPrescribeAction,
              leadingIcon: Icons.medication_outlined,
              enabled: isAllowed,
              onPressed: () =>
                  _openPrescriptionDialog(context, controller, referenceData),
            ),
            AppActionItem(
              label: l10n.clinicalRequestProcedureAction,
              leadingIcon: Icons.healing_outlined,
              enabled: isAllowed,
              onPressed: () => _openProcedureDialog(context, controller),
            ),
            AppActionItem(
              label: l10n.opdReferAction,
              leadingIcon: Icons.alt_route_outlined,
              enabled: isAllowed,
              onPressed: () => _openReferralDialog(context, controller),
            ),
            AppActionItem(
              label: l10n.clinicalRequestAdmissionAction,
              leadingIcon: Icons.bed_outlined,
              enabled: isAllowed,
              onPressed: () =>
                  _openAdmissionDialog(context, controller, referenceData),
            ),
            AppActionItem(
              label: l10n.opdFollowUpAction,
              leadingIcon: Icons.event_repeat_outlined,
              enabled: isAllowed,
              onPressed: () => _openFollowUpDialog(context, controller),
            ),
            AppActionItem(
              label: dispositionActionLabel,
              leadingIcon: Icons.task_alt_outlined,
              enabled:
                  isAllowed &&
                  !bundle.entry.isTerminal &&
                  canCompleteDisposition,
              onPressed: () => _openCompleteDispositionDialog(
                context,
                ref,
                controller,
                entry: bundle.entry,
                actionLabel: dispositionActionLabel,
              ),
            ),
            AppActionItem(
              label: l10n.clinicalPrintSummaryAction,
              leadingIcon: Icons.print_outlined,
              onPressed: () async {
                await printFormTemplateDocument(
                  ref: ref,
                  context: context,
                  title: l10n.clinicalConsultationSummaryTitle,
                  patientContext: buildPrintFormPatientContext(
                    l10n,
                    patientName: bundle.entry.displayTitle,
                    patientId: bundle.entry.apiPatientId,
                    encounterId: bundle.entry.encounterPublicId,
                  ),
                  bodyHtml: _consultationSummaryHtml(context, bundle),
                  includeSignatures: true,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ClinicalRecordSections extends StatelessWidget {
  const _ClinicalRecordSections({required this.bundle});

  final ClinicalEncounterBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<Widget> sections = <Widget>[
      if (bundle.clinicalNotes.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.clinicalPatientNotesTitle,
          records: sortClinicalRecordsNewestFirst(bundle.clinicalNotes),
        ),
      if (bundle.diagnoses.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.clinicalPatientDiagnosesTitle,
          records: sortClinicalRecordsNewestFirst(bundle.diagnoses),
        ),
      if (bundle.procedures.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.opdProceduresSummaryLabel,
          records: sortClinicalRecordsNewestFirst(bundle.procedures),
        ),
      if (bundle.carePlans.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.clinicalCarePlansTitle,
          records: sortClinicalRecordsNewestFirst(bundle.carePlans),
        ),
      if (bundle.pharmacyOrders.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.clinicalPharmacyOrdersTitle,
          records: sortClinicalRecordsNewestFirst(bundle.pharmacyOrders),
        ),
      if (bundle.referrals.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.opdReferralsTitle,
          records: sortClinicalRecordsNewestFirst(bundle.referrals),
        ),
      if (bundle.followUps.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.opdFollowUpsTitle,
          records: sortClinicalRecordsNewestFirst(bundle.followUps),
        ),
      if (bundle.admissions.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.patientsAdmissionsSectionTitle,
          records: sortClinicalRecordsNewestFirst(bundle.admissions),
        ),
    ];

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withClinicalSectionSpacing(context, sections),
    );
  }
}

class _ClinicalRecordSection extends StatelessWidget {
  const _ClinicalRecordSection({required this.title, required this.records});

  final String title;
  final List<ClinicalRelatedRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppWorkspaceDetailPanel(
      title: title,
      child: _ClinicalRecordList(records: records),
    );
  }
}

class _ClinicalRecordList extends StatelessWidget {
  const _ClinicalRecordList({required this.records});

  final List<ClinicalRelatedRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        for (var index = 0; index < records.length; index += 1) ...<Widget>[
          if (index > 0) const Divider(height: 1),
          _ClinicalRecordRow(record: records[index]),
        ],
      ],
    );
  }
}

class _ClinicalRecordRow extends StatelessWidget {
  const _ClinicalRecordRow({required this.record});

  final ClinicalRelatedRecord record;

  @override
  Widget build(BuildContext context) {
    return switch (record.kind) {
      'pharmacy_order' => _ClinicalPharmacyOrderRow(record: record),
      _ => _ClinicalGenericRecordRow(record: record),
    };
  }
}

class _ClinicalGenericRecordRow extends StatelessWidget {
  const _ClinicalGenericRecordRow({required this.record});

  final ClinicalRelatedRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? status = record.status;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Icon(
              _recordIcon(record.kind),
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _joinDisplay(<String?>[record.title, record.subtitle]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      _joinDisplay(<String?>[
                        _apiLabel(record.kind),
                        _dateTimeLabel(context, record.occurredAt),
                      ]),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_hasText(status))
                      _ClinicalStatusText(
                        status: AppWorkspaceStatus(
                          label: _apiLabel(status!),
                          tone: _statusTone(status),
                        ),
                        textStyle: theme.textTheme.labelMedium,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicalPharmacyOrderRow extends ConsumerWidget {
  const _ClinicalPharmacyOrderRow({required this.record});

  final ClinicalRelatedRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    final String status = record.status ?? '';
    final bool canCancel = _canCancelPharmacyOrder(status);
    final bool canDelete = _canDeletePharmacyOrder(status);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Icon(
              Icons.medication_outlined,
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      record.title ?? record.id,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_hasText(status))
                      _ClinicalStatusText(
                        status: AppWorkspaceStatus(
                          label: _apiLabel(status),
                          tone: _statusTone(status),
                        ),
                        textStyle: theme.textTheme.labelMedium,
                      ),
                  ],
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  _joinDisplay(<String?>[
                    l10n.clinicalPharmacyOrderItemCount(record.itemCount),
                    _dateTimeLabel(context, record.occurredAt),
                  ]),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (record.pharmacyOrderItems.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  Column(
                    children: <Widget>[
                      for (
                        var index = 0;
                        index < record.pharmacyOrderItems.length;
                        index += 1
                      )
                        _ClinicalPharmacyOrderItemRow(
                          item: record.pharmacyOrderItems[index],
                        ),
                    ],
                  ),
                ] else if (_hasText(record.subtitle)) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    record.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          AppAccessActionGate(
            requirement: _ClinicalWorkspaceContentState._writeRequirement,
            builder: (BuildContext context, bool isAllowed) {
              return Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  AppButton(
                    iconOnly: true,
                    leadingIcon: Icons.block_outlined,
                    label: l10n.clinicalCancelPharmacyOrderAction,

                    semanticLabel: l10n.clinicalCancelPharmacyOrderAction,
                    tooltip: l10n.clinicalCancelPharmacyOrderAction,
                    enabled: isAllowed && canCancel,
                    onPressed: () => _confirmLabOrderMutation(
                      context: context,
                      title: l10n.clinicalCancelPharmacyOrderDialogTitle,
                      body: l10n.clinicalCancelPharmacyOrderDialogBody,
                      confirmLabel: l10n.clinicalCancelPharmacyOrderAction,
                      action: () => controller.cancelPharmacyOrder(record.id),
                    ),
                  ),
                  AppButton(
                    iconOnly: true,
                    leadingIcon: Icons.delete_outline,
                    label: l10n.clinicalDeletePharmacyOrderAction,

                    semanticLabel: l10n.clinicalDeletePharmacyOrderAction,
                    tooltip: l10n.clinicalDeletePharmacyOrderAction,
                    enabled: isAllowed && canDelete,
                    onPressed: () => _confirmLabOrderMutation(
                      context: context,
                      title: l10n.clinicalDeletePharmacyOrderDialogTitle,
                      body: l10n.clinicalDeletePharmacyOrderDialogBody,
                      confirmLabel: l10n.clinicalDeletePharmacyOrderAction,
                      action: () => controller.deletePharmacyOrder(record.id),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClinicalPharmacyOrderItemRow extends StatelessWidget {
  const _ClinicalPharmacyOrderItemRow({required this.item});

  final ClinicalPharmacyOrderItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String readableSummary = clinicalPrescriptionItemReadableSummary(
      item,
    );
    final List<AppWorkspacePatientContextField> facts =
        <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: l10n.pharmacyDoseColumnLabel,
            value: item.doseLabel ?? '',
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdMedicationRouteLabel,
            value: _apiLabel(item.route ?? ''),
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdFrequencyLabel,
            value: _apiLabel(item.frequency ?? ''),
          ),
          AppWorkspacePatientContextField(
            label: l10n.clinicalDurationValueLabel,
            value: item.durationLabel ?? '',
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdDrugQuantityLabel,
            value: item.quantityLabel ?? '',
          ),
          AppWorkspacePatientContextField(
            label: l10n.clinicalInstructionsLabel,
            value: item.instructions ?? '',
          ),
        ];
    final String status = item.status ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.displayTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(readableSummary, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (_hasText(status))
                _ClinicalStatusText(
                  status: AppWorkspaceStatus(
                    label: _apiLabel(status),
                    tone: _statusTone(status),
                  ),
                  textStyle: theme.textTheme.labelMedium,
                ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          _ClinicalInfoGrid(fields: facts),
        ],
      ),
    );
  }
}

const List<String> _clinicalDispositionReasons = <String>[
  'TREATMENT_COMPLETED',
  'SYMPTOMS_RESOLVED',
  'STABLE_FOR_HOME_CARE',
  'REFERRED_FOR_SPECIALIST_CARE',
  'FOLLOW_UP_SCHEDULED',
  'ADMISSION_NOT_REQUIRED',
  'PATIENT_TRANSFERRED',
  'PATIENT_DECLINED_CARE',
  'OTHER',
];

Future<void> _openNoteDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: context.l10n.clinicalAddNoteTitle,
        sectionTitle: context.l10n.clinicalPatientNotesTitle,
        label: context.l10n.opdClinicalNoteLabel,
        submitLabel: context.l10n.clinicalAddNoteAction,
        prefixIcon: const Icon(Icons.notes_outlined),
        minLines: 5,
        maxLines: 6,
        onSubmit: controller.addClinicalNote,
      ),
    ),
  );
}

Future<void> _openCompleteDispositionDialog(
  BuildContext context,
  WidgetRef ref,
  ClinicalWorkspaceController controller, {
  required ClinicalWorklistEntry entry,
  required String actionLabel,
}) async {
  if (isClinicalAdmissionDischargeContext(
    sourceQueue: entry.sourceQueue,
    status: entry.status,
    stage: entry.stage,
    location: entry.currentLocation,
    hasAdmission: entry.admissionId?.trim().isNotEmpty ?? false,
  )) {
    final String? admissionId = entry.apiAdmissionId?.trim();
    if (admissionId == null || admissionId.isEmpty) {
      return;
    }

    final bool? saved = await showDischargePlanningDialog(
      context: context,
      ref: ref,
      admissionId: admissionId,
      title: Text(actionLabel),
    );
    if (saved != true || !context.mounted) {
      return;
    }

    await ref.read(clinicalWorkspaceControllerProvider.notifier).refresh();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.clinicalSavedMessage)));
    Navigator.of(context).pop(true);
    return;
  }

  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ClinicalDispositionActionDialog(
      title: actionLabel,
      reasons: _clinicalDispositionReasons,
      submitLabel: actionLabel,
      onSubmit: ({required String reason, required String notes}) {
        return controller.completeDisposition(reason: reason, notes: notes);
      },
    ),
  );
  if (saved != true || !context.mounted) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.clinicalSavedMessage)));
  Navigator.of(context).pop(true);
}

Future<void> _openDiagnosisDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalDiagnosisActionDialog(
        onSearchClinicalTerms:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 25,
                source: source,
              );
            },
        onSubmit: controller.addDiagnosis,
      ),
    ),
  );
}

Future<void> _openProcedureDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalProcedureActionDialog(
        onSearchClinicalTerms:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 25,
                source: source,
              );
            },
        onSubmit: controller.addProcedures,
      ),
    ),
  );
}

Future<void> _openLabDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
  ClinicalReferenceData referenceData, {
  ClinicalRelatedRecord? existingOrder,
}) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalLabOrderActionDialog(
        referenceData: referenceData,
        patientContext: _clinicalLabOrderPatientContext(context),
        existingOrder: existingOrder == null
            ? null
            : _clinicalActionLabOrderRecord(existingOrder),
        onSearchLabTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 80,
                source: source,
              );
            },
        onRequest: controller.requestLab,
        onUpdate: controller.updateLabOrder,
      ),
    ),
  );
}

ClinicalActionLabOrderRecord _clinicalActionLabOrderRecord(
  ClinicalRelatedRecord record,
) {
  return ClinicalActionLabOrderRecord(
    id: record.id,
    labOrderItems: <ClinicalActionLabOrderItem>[
      for (final ClinicalLabOrderItem item in record.labOrderItems)
        ClinicalActionLabOrderItem(
          id: item.id,
          status: item.status,
          resultStatus: item.resultStatus,
          labTestId: item.labTestId,
          testDisplayName: item.testDisplayName,
          testCode: item.testCode,
          category: item.category,
          specimenType: item.specimenType,
          unit: item.unit,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        ),
    ],
  );
}

Future<void> _confirmLabOrderMutation({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  required Future<AppFailure?> Function() action,
}) async {
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppConfirmActionDialog(
      title: title,
      body: body,
      submitLabel: confirmLabel,
      icon: const Icon(Icons.science_outlined),
      onConfirm: action,
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.clinicalSavedMessage)));
}

Future<void> _openRadiologyDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
  ClinicalReferenceData referenceData,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalRadiologyOrderActionDialog(
        referenceData: referenceData,
        patientContext: _clinicalLabOrderPatientContext(context),
        onSearchRadiologyTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 80,
                source: source,
              );
            },
        onSubmit: controller.requestRadiology,
      ),
    ),
  );
}

Future<void> _openPrescriptionDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
  ClinicalReferenceData referenceData,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalPrescriptionActionDialog(
        referenceData: referenceData,
        onSubmit: controller.prescribe,
      ),
    ),
  );
}

Future<void> _openReferralDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalReferralActionDialog(onSubmit: controller.refer),
    ),
  );
}

Future<void> _openFollowUpDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ClinicalFollowUpActionDialog(onSubmit: controller.scheduleFollowUp),
    ),
  );
}

Future<void> _openAdmissionDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
  ClinicalReferenceData referenceData,
) async {
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => ClinicalAdmissionActionDialog(
        referenceData: referenceData,
        requiresBed: false,
        reasonLabel: dialogContext.l10n.patientsAdmissionReasonLabel,
        reasonRequired: true,
        notesLabel: dialogContext.l10n.opdFieldOptionalLabel(
          dialogContext.l10n.patientsNotesLabel,
        ),
        onSubmit: (ClinicalActionAdmissionInput input) => controller
            .requestAdmission(reason: input.reason, notes: input.notes),
      ),
    ),
  );
}

Future<void> _showActionResult(
  BuildContext context,
  Future<bool?> future,
) async {
  final bool? saved = await future;
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.clinicalSavedMessage)));
  }
}

AppSearchBarFilterValue _filterValueFromQuery(
  ClinicalWorklistFilters filters, {
  String search = '',
}) {
  return AppSearchBarFilterValue(
    field: filters.searchField,
    dateFrom: filters.dateFrom,
    dateTo: filters.dateTo,
    texts: <String, String>{
      if (_hasText(search)) _clinicalTextGeneral: search.trim(),
      if (_hasText(filters.patient)) _clinicalTextPatient: filters.patient!,
      if (_hasText(filters.patientIdentifier))
        _clinicalTextPatientIdentifier: filters.patientIdentifier!,
      if (_hasText(filters.patientPhone))
        _clinicalTextPatientPhone: filters.patientPhone!,
      if (_hasText(filters.encounter))
        _clinicalTextEncounter: filters.encounter!,
      if (_hasText(filters.queue)) _clinicalTextQueue: filters.queue!,
      if (_hasText(filters.providerText))
        _clinicalTextProvider: filters.providerText!,
      if (_hasText(filters.statusText))
        _clinicalTextStatus: filters.statusText!,
      if (_hasText(filters.location)) _clinicalTextLocation: filters.location!,
    },
    options: <String, String>{
      if (_hasText(filters.sourceQueue))
        _clinicalFilterSource: filters.sourceQueue!,
      if (_hasText(filters.status)) _clinicalFilterStatus: filters.status!,
      if (_hasText(filters.provider))
        _clinicalFilterProvider: filters.provider!,
      if (_hasText(filters.encounterType))
        _clinicalFilterEncounterType: filters.encounterType!,
      if (_hasText(filters.locationOption))
        _clinicalFilterLocation: filters.locationOption!,
    },
  );
}

ClinicalWorklistFilters _filtersFromValue(AppSearchBarFilterValue value) {
  return ClinicalWorklistFilters(
    searchField: value.field,
    dateFrom: value.dateFrom,
    dateTo: value.dateTo,
    patient: value.text(_clinicalTextPatient),
    patientIdentifier: value.text(_clinicalTextPatientIdentifier),
    patientPhone: value.text(_clinicalTextPatientPhone),
    encounter: value.text(_clinicalTextEncounter),
    queue: value.text(_clinicalTextQueue),
    providerText: value.text(_clinicalTextProvider),
    statusText: value.text(_clinicalTextStatus),
    location: value.text(_clinicalTextLocation),
    sourceQueue: value.option(_clinicalFilterSource),
    status: value.option(_clinicalFilterStatus),
    provider: value.option(_clinicalFilterProvider),
    encounterType: value.option(_clinicalFilterEncounterType),
    locationOption: value.option(_clinicalFilterLocation),
  );
}

String _searchFromValue(AppSearchBarFilterValue value) {
  return value.text(_clinicalTextGeneral)?.trim() ?? '';
}

bool _hasActiveClinicalFilters(
  ClinicalWorklistFilters filters, {
  String search = '',
}) {
  return filters.isActive || _hasText(search);
}

List<AppSearchBarTextFilter> _clinicalTextFilters(AppLocalizations l10n) {
  return <AppSearchBarTextFilter>[
    AppSearchBarTextFilter(
      key: _clinicalTextGeneral,
      label: l10n.clinicalSearchLabel,
      hintText: l10n.clinicalSearchHint,
      icon: Icons.manage_search_outlined,
      textInputAction: TextInputAction.search,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextPatient,
      label: l10n.opdPatientColumnLabel,
      hintText: l10n.patientsSearchHint,
      icon: Icons.person_search_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextPatientIdentifier,
      label: l10n.patientsPatientIdFilterLabel,
      icon: Icons.badge_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextPatientPhone,
      label: l10n.profilePhoneLabel,
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextEncounter,
      label: l10n.clinicalEncounterNumberLabel,
      icon: Icons.tag_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextQueue,
      label: l10n.clinicalSourceQueueLabel,
      icon: Icons.queue_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextProvider,
      label: l10n.opdProviderColumnLabel,
      icon: Icons.medical_information_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextStatus,
      label: l10n.opdStatusColumnLabel,
      icon: Icons.task_alt_outlined,
      textInputAction: TextInputAction.next,
    ),
    AppSearchBarTextFilter(
      key: _clinicalTextLocation,
      label: l10n.clinicalLocationLabel,
      icon: Icons.location_on_outlined,
      textInputAction: TextInputAction.done,
    ),
  ];
}

List<AppSearchBarFilterGroup> _clinicalFilterGroups(
  AppLocalizations l10n,
  List<ClinicalWorklistEntry> entries,
) {
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: _clinicalFilterSource,
      label: l10n.clinicalSourceQueueLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: _filterChoices(
        entries.map((ClinicalWorklistEntry entry) => entry.sourceQueue),
        icon: Icons.queue_outlined,
      ),
    ),
    AppSearchBarFilterGroup(
      key: _clinicalFilterStatus,
      label: l10n.opdStatusColumnLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: _filterChoices(
        entries.map(
          (ClinicalWorklistEntry entry) =>
              entry.stage ?? entry.status ?? entry.nextStep,
        ),
        icon: Icons.task_alt_outlined,
      ),
    ),
    AppSearchBarFilterGroup(
      key: _clinicalFilterProvider,
      label: l10n.opdProviderColumnLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: clinicalUnassignedProviderFilterValue,
          label: l10n.operationsUnassignedValue,
          icon: Icons.person_off_outlined,
        ),
        ..._filterChoices(
          entries.map(
            (ClinicalWorklistEntry entry) => entry.providerDisplayName,
          ),
          icon: Icons.badge_outlined,
          formatApiLabel: false,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: _clinicalFilterEncounterType,
      label: l10n.clinicalEncounterTypeLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: _filterChoices(
        entries.map((ClinicalWorklistEntry entry) => entry.encounterType),
        icon: Icons.local_hospital_outlined,
      ),
    ),
    AppSearchBarFilterGroup(
      key: _clinicalFilterLocation,
      label: l10n.clinicalLocationLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: _filterChoices(
        entries.map((ClinicalWorklistEntry entry) => entry.currentLocation),
        icon: Icons.location_on_outlined,
        formatApiLabel: false,
      ),
    ),
  ];
}

List<AppSearchBarFilterChoice> _filterChoices(
  Iterable<String?> values, {
  required IconData icon,
  bool formatApiLabel = true,
}) {
  final List<String> normalized =
      values
          .map((String? value) => value?.trim() ?? '')
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort((String left, String right) => left.compareTo(right));

  return <AppSearchBarFilterChoice>[
    for (final String value in normalized)
      AppSearchBarFilterChoice(
        value: value,
        label: formatApiLabel ? _apiLabel(value) : value,
        icon: icon,
      ),
  ];
}

List<AppWorkspacePatientContextField> _clinicalPatientContextFields(
  BuildContext context,
  AppLocalizations l10n,
  ClinicalWorklistEntry entry, {
  bool omitSubtitleFields = false,
}) {
  final String dob = entry.patientDateOfBirth == null
      ? ''
      : AppFormatters.mediumDate(
          entry.patientDateOfBirth!,
          Localizations.localeOf(context),
        );
  final DateTime? lastUpdated = entry.updatedAt ?? entry.startedAt;

  // Compact AppPatientDetails already shows name, public ID, age, and gender.
  return <AppWorkspacePatientContextField>[
    if (!omitSubtitleFields)
      AppWorkspacePatientContextField(
        label: l10n.clinicalEncounterNumberLabel,
        value: entry.encounterPublicId ?? '',
        icon: Icons.tag_outlined,
        copyable: true,
        copyTooltip: l10n.opdCopyEncounterIdAction,
        copiedMessage: l10n.opdEncounterIdCopiedMessage,
      ),
    if (!omitSubtitleFields)
      AppWorkspacePatientContextField(
        label: l10n.clinicalEncounterQueueLabel,
        value: _apiLabel(entry.sourceQueue),
        icon: Icons.queue_outlined,
        tone: _sourceQueueTone(entry.sourceQueue),
      ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalEncounterTypeLabel,
      value: _apiLabel(entry.encounterType ?? ''),
      icon: Icons.local_hospital_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalLocationLabel,
      value: entry.currentLocation ?? '',
      icon: Icons.location_on_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.opdProviderColumnLabel,
      value: entry.providerDisplayName ?? '',
      icon: Icons.badge_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalLastUpdatedLabel,
      value: lastUpdated == null ? '' : _dateTimeLabel(context, lastUpdated),
      icon: Icons.schedule_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.clinicalAdmissionNumberLabel,
      value: entry.admissionPublicId ?? '',
      icon: Icons.bed_outlined,
      copyable: true,
      copyTooltip: l10n.copyAdmissionIdAction,
      copiedMessage: l10n.admissionIdCopiedMessage,
    ),
    AppWorkspacePatientContextField(
      label: l10n.patientsDobLabel,
      value: dob,
      icon: Icons.event_outlined,
    ),
    AppWorkspacePatientContextField(
      label: l10n.patientsPhoneLabel,
      value: entry.patientPhone ?? '',
      icon: Icons.phone_outlined,
    ),
  ];
}

String _clinicalPatientNumber(ClinicalWorklistEntry entry) {
  final String? publicId = entry.patientPublicId?.trim();
  if (publicId != null && publicId.isNotEmpty) {
    return publicId;
  }

  return '';
}

String _clinicalAgeLabel(DateTime? birthDate) {
  if (birthDate == null) {
    return '';
  }

  final DateTime today = DateTime.now();
  int age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age -= 1;
  }

  return age < 0 ? '' : age.toString();
}

String _clinicalGenderLabel(AppLocalizations l10n, String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'MALE' => l10n.patientsGenderMale,
    'FEMALE' => l10n.patientsGenderFemale,
    'OTHER' => l10n.patientsGenderOther,
    'UNKNOWN' => l10n.patientsGenderUnknown,
    final String normalized when normalized.isNotEmpty => _apiLabel(value!),
    _ => '',
  };
}

AppWorkspaceStatus _entryStatus(ClinicalWorklistEntry item) {
  final String value =
      item.stage ?? item.status ?? item.nextStep ?? item.sourceQueue;
  return AppWorkspaceStatus(label: _apiLabel(value), tone: _statusTone(value));
}

bool _isSameWorklistEntry(
  ClinicalWorklistEntry left,
  ClinicalWorklistEntry right,
) {
  return left.sourceQueue == right.sourceQueue &&
      left.encounterId == right.encounterId;
}

List<Widget> _withClinicalSectionSpacing(
  BuildContext context,
  List<Widget> sections,
) {
  final double spacing = Theme.of(context).spacing.md;
  return <Widget>[
    for (var index = 0; index < sections.length; index += 1) ...<Widget>[
      if (index > 0) SizedBox(height: spacing),
      sections[index],
    ],
  ];
}

bool _clinicalTriageShowsWorkflowStage(ClinicalTriageHandoff? handoff) {
  if (handoff == null || !handoff.hasContent) {
    return false;
  }
  final String stage = handoff.stage?.trim() ?? '';
  final String nextStep = handoff.nextStep?.trim() ?? '';
  return stage.isNotEmpty || nextStep.isNotEmpty || handoff.timeline.isNotEmpty;
}

bool _clinicalHasRecordSections(ClinicalEncounterBundle bundle) {
  return bundle.clinicalNotes.isNotEmpty ||
      bundle.diagnoses.isNotEmpty ||
      bundle.procedures.isNotEmpty ||
      bundle.carePlans.isNotEmpty ||
      bundle.pharmacyOrders.isNotEmpty ||
      bundle.referrals.isNotEmpty ||
      bundle.followUps.isNotEmpty ||
      bundle.admissions.isNotEmpty;
}

IconData _clinicalStatusIcon(AppWorkspaceStatusTone tone) {
  return switch (tone) {
    AppWorkspaceStatusTone.success => Icons.check_circle_outline,
    AppWorkspaceStatusTone.warning => Icons.warning_amber_outlined,
    AppWorkspaceStatusTone.error => Icons.error_outline,
    AppWorkspaceStatusTone.info => Icons.info_outline,
    AppWorkspaceStatusTone.neutral => Icons.radio_button_unchecked,
  };
}

Color _clinicalToneColor(ThemeData theme, AppWorkspaceStatusTone tone) {
  final ColorScheme colorScheme = theme.colorScheme;
  return switch (tone) {
    AppWorkspaceStatusTone.success => colorScheme.tertiary,
    AppWorkspaceStatusTone.warning => colorScheme.secondary,
    AppWorkspaceStatusTone.error => colorScheme.error,
    AppWorkspaceStatusTone.info => colorScheme.primary,
    AppWorkspaceStatusTone.neutral => colorScheme.onSurfaceVariant,
  };
}

AppWorkspaceStatusTone _sourceQueueTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'OPD' => AppWorkspaceStatusTone.info,
    'TRIAGE' || 'EMERGENCY' => AppWorkspaceStatusTone.warning,
    'IPD' || 'ADMISSION' => AppWorkspaceStatusTone.success,
    'ICU' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _statusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'COMPLETED' ||
    'DISCHARGED' ||
    'CLOSED' ||
    'NORMAL' => AppWorkspaceStatusTone.success,
    'CANCELLED' || 'CRITICAL' => AppWorkspaceStatusTone.error,
    'URGENT' ||
    'ABNORMAL' ||
    'WAITING' ||
    'WAITING_REVIEW' ||
    'WAITING_DOCTOR_REVIEW' ||
    'WAITING_DISPOSITION' ||
    'ADMITTED' => AppWorkspaceStatusTone.warning,
    'IN_PROGRESS' ||
    'ORDERED' ||
    'COLLECTED' ||
    'IN_PROCESS' ||
    'RESULTS_READY' ||
    'OPEN' => AppWorkspaceStatusTone.info,
    'PENDING' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone _clinicalVitalTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'CRITICAL' => AppWorkspaceStatusTone.error,
    'ABNORMAL' => AppWorkspaceStatusTone.warning,
    'NORMAL' => AppWorkspaceStatusTone.success,
    'RECORDED' => AppWorkspaceStatusTone.info,
    _ => _statusTone(value),
  };
}

AppWorkspaceStatusTone _clinicalAlertTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'CRITICAL' || 'HIGH' => AppWorkspaceStatusTone.error,
    'MEDIUM' => AppWorkspaceStatusTone.warning,
    'LOW' => AppWorkspaceStatusTone.info,
    _ => _statusTone(value),
  };
}

IconData _recordIcon(String kind) {
  return switch (kind) {
    'clinical_note' => Icons.edit_note_outlined,
    'diagnosis' => Icons.rule_outlined,
    'procedure' => Icons.healing_outlined,
    'care_plan' => Icons.playlist_add_check_outlined,
    'lab_order' => Icons.science_outlined,
    'radiology_order' => Icons.biotech_outlined,
    'pharmacy_order' => Icons.medication_outlined,
    'referral' => Icons.alt_route_outlined,
    'follow_up' => Icons.event_repeat_outlined,
    'admission' => Icons.bed_outlined,
    _ => Icons.description_outlined,
  };
}

bool _canCancelPharmacyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'PARTIALLY_DISPENSED' => true,
    _ => false,
  };
}

bool _canDeletePharmacyOrder(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'ORDERED' || 'CANCELLED' => true,
    _ => false,
  };
}

int _pageTotal<T>(AppPage<T> page) => page.totalItemCount ?? page.items.length;

String _pageLabel(BuildContext context, AppPage<ClinicalWorklistEntry> page) {
  final int total = page.totalItemCount ?? page.items.length;
  if (total == 0) {
    return context.l10n.opdPageLabel(0, 0, 0);
  }
  final int from = page.request.pageIndex * page.request.pageSize + 1;
  final int to = (from + page.items.length - 1).clamp(from, total).toInt();
  return context.l10n.opdPageLabel(from, to, total);
}

String _dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _apiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

String _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined;
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

List<AppClinicalResultPreviewEntry> _clinicalResultsPreviewEntries(
  ClinicalEncounterBundle bundle,
) {
  final List<AppClinicalResultPreviewEntry> entries =
      <AppClinicalResultPreviewEntry>[];

  for (final ClinicalRelatedRecord order in bundle.labOrders) {
    for (final ClinicalLabOrderItem item in order.labOrderItems) {
      final String? value = _firstNonEmpty(<String?>[
        item.resultValue,
        item.resultText,
      ]);
      if (value == null) {
        continue;
      }
      entries.add(
        AppClinicalResultPreviewEntry(
          id: item.id,
          module: AppClinicalResultModule.laboratory,
          title: item.displayTitle,
          status: _clinicalResultStatusFromRecordStatus(
            item.resultStatus ?? item.status ?? order.status,
          ),
          occurredAt: item.updatedAt ?? item.createdAt ?? order.occurredAt,
          subtitle: item.displaySubtitle,
          laboratory: AppClinicalLaboratoryResultContent(
            value: value,
            unit: item.unit,
            flag: _clinicalResultFlagFromStatus(item.resultStatus),
            flagLabel: item.resultStatus,
          ),
        ),
      );
    }
  }

  for (final ClinicalRelatedRecord order in bundle.radiologyOrders) {
    final String status = (order.status ?? '').toUpperCase();
    if (status != 'COMPLETED' && status != 'FINAL' && status != 'AMENDED') {
      continue;
    }
    entries.add(
      AppClinicalResultPreviewEntry(
        id: order.id,
        module: AppClinicalResultModule.radiology,
        title: order.title ?? order.id,
        status: _clinicalResultStatusFromRecordStatus(order.status),
        occurredAt: order.occurredAt,
        subtitle: order.subtitle,
        radiology: AppClinicalRadiologyReportContent(
          reportText: order.subtitle,
          modality: order.radiologyOrderItems.isEmpty
              ? null
              : order.radiologyOrderItems.first.modality,
          bodyRegion: order.radiologyOrderItems.isEmpty
              ? null
              : order.radiologyOrderItems.first.bodyRegion,
        ),
      ),
    );
  }

  for (final ClinicalRelatedRecord procedure in bundle.procedures) {
    entries.add(
      AppClinicalResultPreviewEntry(
        id: procedure.id,
        module: AppClinicalResultModule.procedure,
        title: procedure.title ?? procedure.id,
        status: _clinicalResultStatusFromRecordStatus(procedure.status),
        occurredAt: procedure.occurredAt,
        subtitle: procedure.subtitle,
        procedure: AppClinicalProcedureResultContent(
          findings: procedure.subtitle,
          notes: procedure.status,
        ),
      ),
    );
  }

  for (final ClinicalRelatedRecord note in bundle.clinicalNotes) {
    entries.add(
      AppClinicalResultPreviewEntry(
        id: note.id,
        module: AppClinicalResultModule.clinicalAssessment,
        title: note.title ?? note.id,
        status: _clinicalResultStatusFromRecordStatus(note.status),
        occurredAt: note.occurredAt,
        subtitle: note.subtitle,
        assessment: AppClinicalAssessmentResultContent(
          summary: note.subtitle ?? note.title,
        ),
      ),
    );
  }

  return entries;
}

AppClinicalResultStatus _clinicalResultStatusFromRecordStatus(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'AMENDED' || 'CORRECTED' => AppClinicalResultStatus.corrected,
    'COMPLETED' ||
    'FINAL' ||
    'VERIFIED' ||
    'RELEASED' => AppClinicalResultStatus.verified,
    'DRAFT' ||
    'PRELIMINARY' ||
    'PENDING' ||
    'IN_PROCESS' => AppClinicalResultStatus.preliminary,
    'CANCELLED' ||
    'UNAVAILABLE' ||
    'REJECTED' => AppClinicalResultStatus.unavailable,
    _ => AppClinicalResultStatus.preliminary,
  };
}

AppClinicalResultFlag _clinicalResultFlagFromStatus(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'CRITICAL' => AppClinicalResultFlag.critical,
    'ABNORMAL' || 'HIGH' || 'LOW' => AppClinicalResultFlag.abnormal,
    'NORMAL' ||
    'NEGATIVE' ||
    'NON_REACTIVE' ||
    'POSITIVE' => AppClinicalResultFlag.normal,
    _ => AppClinicalResultFlag.unknown,
  };
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String _consultationSummaryHtml(
  BuildContext context,
  ClinicalEncounterBundle bundle,
) {
  final AppLocalizations l10n = context.l10n;
  final List<String> sections = <String>[];

  void addSection(String title, List<ClinicalRelatedRecord> records) {
    if (records.isEmpty) {
      return;
    }
    sections.add(
      PrintFormTemplate.section(title: title, bodyHtml: _recordsHtml(records)),
    );
  }

  addSection(l10n.clinicalPatientNotesTitle, bundle.clinicalNotes);
  addSection(l10n.clinicalPatientDiagnosesTitle, bundle.diagnoses);
  addSection(l10n.opdProceduresSummaryLabel, bundle.procedures);
  addSection(l10n.clinicalCarePlansTitle, bundle.carePlans);
  addSection(l10n.clinicalLabOrdersTitle, bundle.labOrders);
  addSection(l10n.clinicalRadiologyOrdersTitle, bundle.radiologyOrders);
  addSection(l10n.clinicalPharmacyOrdersTitle, bundle.pharmacyOrders);
  addSection(l10n.opdReferralsTitle, bundle.referrals);
  addSection(l10n.opdFollowUpsTitle, bundle.followUps);
  addSection(l10n.patientsAdmissionsSectionTitle, bundle.admissions);

  return sections.join();
}

String _recordsHtml(List<ClinicalRelatedRecord> records) {
  return PrintFormTemplate.unorderedList(<String>[
    for (final ClinicalRelatedRecord record in records)
      _clinicalRecordSummaryText(record),
  ], emptyText: 'No records.');
}

String _clinicalRecordSummaryText(ClinicalRelatedRecord record) {
  return _joinDisplay(<String?>[
    record.title,
    record.subtitle,
    if (record.labOrderItems.isNotEmpty)
      _joinDisplay(
        record.labOrderItems
            .take(4)
            .map((ClinicalLabOrderItem item) => item.displayTitle),
      ),
    if (record.radiologyOrderItems.isNotEmpty)
      _joinDisplay(
        record.radiologyOrderItems
            .take(4)
            .map((ClinicalRadiologyOrderItem item) => item.displayTitle),
      ),
    if (record.pharmacyOrderItems.isNotEmpty)
      _joinDisplay(
        record.pharmacyOrderItems
            .take(4)
            .map((ClinicalPharmacyOrderItem item) => item.displayTitle),
      ),
    record.status == null ? null : _apiLabel(record.status!),
  ]);
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

const String _clinicalTextGeneral = 'general';
const String _clinicalTextPatient = 'patient';
const String _clinicalTextPatientIdentifier = 'patient_identifier';
const String _clinicalTextPatientPhone = 'patient_phone';
const String _clinicalTextEncounter = 'encounter';
const String _clinicalTextQueue = 'queue';
const String _clinicalTextProvider = 'provider_text';
const String _clinicalTextStatus = 'status_text';
const String _clinicalTextLocation = 'location';
const String _clinicalFilterSource = 'source';
const String _clinicalFilterStatus = 'status';
const String _clinicalFilterProvider = 'provider';
const String _clinicalFilterEncounterType = 'encounter_type';
const String _clinicalFilterLocation = 'location_option';

ClinicalRequestPatientContext _clinicalLabOrderPatientContext(
  BuildContext context,
) {
  final ClinicalWorklistEntry? entry =
      ProviderScope.containerOf(context, listen: false)
          .read(clinicalWorkspaceControllerProvider)
          .value
          ?.when(
            success: (ClinicalWorkspaceState state) =>
                state.selectedBundle?.entry,
            failure: (_) => null,
          );
  if (entry == null) {
    return const ClinicalRequestPatientContext();
  }
  return ClinicalRequestPatientContext(
    patientName: entry.patientDisplayName,
    patientId: entry.apiPatientId,
    encounterId: entry.apiEncounterId,
  );
}
