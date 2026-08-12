import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/claims/data/repositories/insurance_catalog_repository.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/clinical/presentation/controllers/clinical_workspace_controller.dart';
import 'package:hosspi_hms/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart';
import 'package:hosspi_hms/features/clinical/presentation/widgets/clinical_workspace_print_helpers.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_prescription_catalog.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/routing/workspace_location_sync.dart';
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
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<ClinicalWorklistEntry>
  _tableColumnController;
  Timer? _searchDebounce;
  String? _appliedRouteSignature;
  late ClinicalWorkspaceSection _section;
  int? _followUpsNarrowedCount;

  @override
  void initState() {
    super.initState();
    _section = widget.initialQuery?.section ?? ClinicalWorkspaceSection.all;
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<ClinicalWorklistEntry>();
    _scheduleRouteQuery(widget.initialQuery);
    if (_section != ClinicalWorkspaceSection.all &&
        !_section.isFollowUps) {
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
    } else {
      // Canonicalize alias deep-links (e.g. ?section=mine → assigned-to-me)
      // without dropping search / encounter / panel params.
      _canonicalizeSectionQuery(_section);
    }
    if (query.search.isNotEmpty) {
      _searchController.text = query.search;
      await controller.applySearch(query.search);
    }
    if (query.encounterId.isNotEmpty) {
      final ClinicalWorklistEntry? entry = _findEntryByEncounterId(
        query.encounterId,
      );
      if (entry != null && mounted) {
        await _openClinicalEntryDialog(
          context,
          ref,
          entry,
          initialPanel: query.panel.trim().isEmpty ? null : query.panel.trim(),
        );
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
    setState(() {
      _section = section;
      if (!section.isFollowUps) {
        _followUpsNarrowedCount = null;
      }
    });
    _updateUrlForSection(section);
    if (section.isFollowUps) {
      return;
    }
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
    syncWorkspaceLocation(context, location);
  }

  void _canonicalizeSectionQuery(ClinicalWorkspaceSection section) {
    if (!mounted) {
      return;
    }
    final Uri uri = GoRouterState.of(context).uri;
    final String expected = _clinicalSectionQueryValue(section);
    final String current =
        (uri.queryParameters['section'] ?? uri.queryParameters['tab'] ?? '')
            .trim();
    if (current.toLowerCase() == expected.toLowerCase()) {
      return;
    }
    final Map<String, String> params =
        Map<String, String>.from(uri.queryParameters);
    params.remove('tab');
    if (expected.isEmpty) {
      params.remove('section');
    } else {
      params['section'] = expected;
    }
    syncWorkspaceLocation(
      context,
      AppRoutes.clinical.location(queryParameters: params),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ClinicalWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<ClinicalWorkspaceSection> visibleSections =
        _clinicalVisibleSections(accessPolicy);
    if (visibleSections.isEmpty) {
      return const SizedBox.shrink();
    }
    if (!visibleSections.contains(_section)) {
      final ClinicalWorkspaceSection fallback = visibleSections.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.contains(_section)) {
          return;
        }
        _handleTabChanged(fallback);
      });
    }

    return ResponsivePage(
      padding: ResponsiveSpacing.workspacePagePaddingFor(
        spacing: Theme.of(context).spacing,
      ),
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final ClinicalWorkspaceSection section in visibleSections)
                  AppTabItem(
                    id: section.name,
                    icon: _clinicalSectionIcon(section),
                    label: _clinicalSectionLabel(l10n, section),
                    count: section.isFollowUps
                        ? (_followUpsNarrowedCount ??
                              ref.watch(
                                followUpTabCountProvider(
                                  const FollowUpWorklistScope(),
                                ),
                              ))
                        : _clinicalSectionCount(
                            state,
                            section,
                            activeSection: _section,
                          ),
                    countTone: _clinicalSectionCountTone(section),
                  ),
              ],
              selectedId: _section.name,
              onTabTapped: (String tabId) {
                for (final ClinicalWorkspaceSection section
                    in visibleSections) {
                  if (section.name == tabId) {
                    _handleTabChanged(section);
                    break;
                  }
                }
              },
            ),
            SizedBox(height: theme.spacing.sm),
            Expanded(
              child: _section.isFollowUps
                  ? FollowUpWorklistPanel(
                      scope: const FollowUpWorklistScope(),
                      storageKeyPrefix: 'clinical_follow_ups',
                      readRequirement: clinicalFollowUpsRequirement,
                      writeRequirement: clinicalFollowUpsWriteRequirement,
                      showAdvancedFilterButton: true,
                      advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
                      advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
                      advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                      advancedFilterResetLabel: l10n.opdClearFiltersAction,
                      advancedFilterCloseLabel: l10n.commonCloseActionLabel,
                      enableDateFilter: true,
                      dateFilterLabel: l10n.opdFollowUpDateLabel,
                      dateFromLabel: l10n.opdDateFromLabel,
                      dateToLabel: l10n.opdDateToLabel,
                      filterGroups: <AppSearchBarFilterGroup>[
                        AppSearchBarFilterGroup(
                          key: 'follow_up_status',
                          label: l10n.receptionStatusLabel,
                          choices: <AppSearchBarFilterChoice>[
                            AppSearchBarFilterChoice(
                              value: 'pending',
                              label: l10n
                                  .patientsActiveWorkStatusAppointmentScheduled,
                            ),
                            AppSearchBarFilterChoice(
                              value: 'completed',
                              label: l10n.opdCompletedFlowSummaryLabel,
                            ),
                          ],
                        ),
                      ],
                      canExport: canExportClinicalWorkspace(accessPolicy),
                      enablePrint: true,
                      canPrint: canPrintClinicalWorkspace(accessPolicy),
                      printLabel: l10n.commonPrintActionLabel,
                      onPrint: (List<ReceptionFollowUpEntry> entries) =>
                          _printClinicalFollowUpsList(
                            context,
                            ref,
                            entries: entries,
                            l10n: l10n,
                          ),
                      onNarrowedCountChanged: (int? narrowedCount) {
                        if (_followUpsNarrowedCount == narrowedCount) {
                          return;
                        }
                        setState(() {
                          _followUpsNarrowedCount = narrowedCount;
                        });
                      },
                    )
                  : _ClinicalWorklistPanel(
                      state: state,
                      section: _section,
                      searchController: _searchController,
                      columnVisibilityController: _tableColumnController,
                      onSearchChanged: _applySearch,
                      onSearchSubmitted: _applySearchImmediately,
                    ),
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
}

ClinicalQueueScope _clinicalSectionScope(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.followUps => ClinicalQueueScope.all,
    ClinicalWorkspaceSection.all => ClinicalQueueScope.all,
    ClinicalWorkspaceSection.assignedToMe => ClinicalQueueScope.assignedToMe,
    ClinicalWorkspaceSection.urgent => ClinicalQueueScope.urgent,
    ClinicalWorkspaceSection.resultsReady => ClinicalQueueScope.resultsReady,
    ClinicalWorkspaceSection.completed => ClinicalQueueScope.completed,
  };
}

List<ClinicalWorkspaceSection> _clinicalVisibleSections(
  AppAccessPolicy policy,
) {
  return clinicalAllowedSections(policy);
}

IconData _clinicalSectionIcon(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.followUps => Icons.phone_callback_outlined,
    ClinicalWorkspaceSection.all => Icons.inventory_2_outlined,
    ClinicalWorkspaceSection.assignedToMe => Icons.person_outline,
    ClinicalWorkspaceSection.urgent => Icons.priority_high_outlined,
    ClinicalWorkspaceSection.resultsReady => Icons.science_outlined,
    ClinicalWorkspaceSection.completed => Icons.task_alt_outlined,
  };
}

String _clinicalSectionLabel(
  AppLocalizations l10n,
  ClinicalWorkspaceSection section,
) {
  return switch (section) {
    ClinicalWorkspaceSection.followUps => l10n.opdFollowUpsTitle,
    ClinicalWorkspaceSection.all => l10n.clinicalSectionPendingLabel,
    ClinicalWorkspaceSection.assignedToMe =>
      l10n.clinicalSectionAssignedToMeLabel,
    ClinicalWorkspaceSection.urgent => l10n.clinicalSectionUrgentLabel,
    ClinicalWorkspaceSection.resultsReady =>
      l10n.clinicalSectionResultsReadyLabel,
    ClinicalWorkspaceSection.completed =>
      l10n.clinicalSectionCompletedLabel,
  };
}

int? _clinicalSectionCount(
  ClinicalWorkspaceState state,
  ClinicalWorkspaceSection section, {
  ClinicalWorkspaceSection? activeSection,
}) {
  if (section.isFollowUps) {
    return null;
  }
  final int? scopeTotal = switch (section) {
    ClinicalWorkspaceSection.all => state.pendingCount,
    ClinicalWorkspaceSection.assignedToMe => state.assignedToMeCount,
    ClinicalWorkspaceSection.urgent => state.urgentCount,
    ClinicalWorkspaceSection.resultsReady => state.resultsReadyCount,
    ClinicalWorkspaceSection.completed => state.completedCount,
    ClinicalWorkspaceSection.followUps => null,
  };
  if (activeSection == null || section != activeSection) {
    return scopeTotal;
  }
  final bool narrowed =
      state.query.search.trim().isNotEmpty || state.query.filters.isActive;
  if (!narrowed) {
    return scopeTotal;
  }
  return state.worklist.totalItemCount ?? scopeTotal;
}

AppTabCountTone _clinicalSectionCountTone(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.urgent => AppTabCountTone.danger,
    ClinicalWorkspaceSection.assignedToMe => AppTabCountTone.warning,
    ClinicalWorkspaceSection.all ||
    ClinicalWorkspaceSection.resultsReady ||
    ClinicalWorkspaceSection.completed ||
    ClinicalWorkspaceSection.followUps => AppTabCountTone.info,
  };
}

String _clinicalSectionQueryValue(ClinicalWorkspaceSection section) {
  return switch (section) {
    ClinicalWorkspaceSection.followUps => 'follow-ups',
    ClinicalWorkspaceSection.all => '',
    ClinicalWorkspaceSection.assignedToMe => 'assigned-to-me',
    ClinicalWorkspaceSection.urgent => 'urgent',
    ClinicalWorkspaceSection.resultsReady => 'results-ready',
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
    ClinicalWorkspaceSection.assignedToMe => standardDefaults,
    ClinicalWorkspaceSection.urgent => standardDefaults,
    ClinicalWorkspaceSection.resultsReady => const <_ClinicalTableColumnId>[
      _ClinicalTableColumnId.patient,
      _ClinicalTableColumnId.encounterType,
      _ClinicalTableColumnId.queue,
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
    ClinicalWorkspaceSection.followUps => standardDefaults,
  };
}

/// Defaults for a section after Next-action RBAC omit, still preferring **5**
/// visible columns by promoting from the optional pool.
List<_ClinicalTableColumnId> _clinicalResolvedDefaultColumnsForSection(
  ClinicalWorkspaceSection section, {
  required bool showNextAction,
}) {
  final List<_ClinicalTableColumnId> defaults =
      _clinicalDefaultColumnsForSection(section)
          .where(
            (_ClinicalTableColumnId column) =>
                showNextAction || column != _ClinicalTableColumnId.nextAction,
          )
          .toList();
  if (defaults.length >= 5) {
    return defaults;
  }
  final List<_ClinicalTableColumnId> resolved =
      List<_ClinicalTableColumnId>.of(defaults);
  for (final _ClinicalTableColumnId choice
      in _clinicalOptionalColumnPoolForSection(section)) {
    if (resolved.length >= 5) {
      break;
    }
    if (choice == _ClinicalTableColumnId.nextAction && !showNextAction) {
      continue;
    }
    if (!resolved.contains(choice)) {
      resolved.add(choice);
    }
  }
  return resolved;
}

List<_ClinicalTableColumnId> _clinicalResolvedColumnChoicesForSection(
  ClinicalWorkspaceSection section, {
  required bool showNextAction,
  required List<_ClinicalTableColumnId> defaults,
}) {
  final Set<_ClinicalTableColumnId> defaultSet = defaults.toSet();
  return _clinicalOptionalColumnPoolForSection(section)
      .where(
        (_ClinicalTableColumnId column) =>
            !defaultSet.contains(column) &&
            (showNextAction || column != _ClinicalTableColumnId.nextAction),
      )
      .toList(growable: false);
}

List<_ClinicalTableColumnId> _clinicalOptionalColumnPoolForSection(
  ClinicalWorkspaceSection section,
) {
  final Set<_ClinicalTableColumnId> defaults =
      _clinicalDefaultColumnsForSection(section).toSet();
  return _availableClinicalTableColumns
      .where((_ClinicalTableColumnId column) => !defaults.contains(column))
      .toList(growable: false);
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
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canExport = canExportClinicalWorkspace(policy);
    final bool canPrint = canPrintClinicalWorkspace(policy);
    final bool showNextAction = clinicalBoardShowsNextActionColumn(
      policy,
      section,
    );
    final List<_ClinicalTableColumnId> defaultColumns =
        _clinicalResolvedDefaultColumnsForSection(
          section,
          showNextAction: showNextAction,
        );
    final List<_ClinicalTableColumnId> columnChoices =
        _clinicalResolvedColumnChoicesForSection(
          section,
          showNextAction: showNextAction,
          defaults: defaultColumns,
        );
    return AppListTable<ClinicalWorklistEntry>(
      key: ValueKey<String>('clinical_table_${section.name}'),
      page: state.worklist,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'clinical_${section.name}',
      columnWidthStorageKey: 'clinical_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
      displayMode: AppListTableDisplayMode.adaptive,
      isLoading: state.isRefreshing,
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
      enableExport: true,
      canExport: canExport,
      exportLabel: l10n.commonTableExportActionLabel,
      exportDialogTitle: l10n.commonTableExportDialogTitle,
      exportCancelLabel: l10n.commonCancelActionLabel,
      exportColumnsSectionLabel: l10n.commonTableExportColumnsSectionLabel,
      exportFiltersSectionLabel: l10n.commonTableExportFiltersSectionLabel,
      exportEmptyColumnsMessage: l10n.commonTableExportEmptyColumnsMessage,
      exportEmptyRowsMessage: l10n.commonTableExportEmptyRowsMessage,
      exportSuccessMessage: l10n.commonTableExportSuccessMessage,
      exportFailureMessage: l10n.commonTableExportFailureMessage,
      exportInvalidDateMessage: l10n.opdInvalidDateMessage,
      enablePrint: true,
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      printFailureMessage: l10n.commonTablePrintFailureMessage,
      loadMatchingItems: () => matchingItemsOrThrow(
        controller.loadMatchingWorklistItems(),
      ),
      onPrint: (List<ClinicalWorklistEntry> items) => _printClinicalWorklist(
        context,
        ref,
        items: items,
        section: section,
        showNextAction: showNextAction,
        l10n: l10n,
      ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      exportConfig: AppListTableExportConfig<ClinicalWorklistEntry>(
        fileNameStem: 'clinical_${section.name}',
        dateOf: (ClinicalWorklistEntry item) =>
            item.updatedAt ?? item.startedAt,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
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
        for (final _ClinicalTableColumnId column in defaultColumns)
          _clinicalDataColumn(context, column),
      ],
      columnChoices: <AppListTableColumn<ClinicalWorklistEntry>>[
        for (final _ClinicalTableColumnId column in columnChoices)
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
    advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
    advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
    advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
    advancedFilterResetLabel: l10n.opdClearFiltersAction,
    advancedFilterCloseLabel: l10n.commonCloseActionLabel,
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
    exportValue: (ClinicalWorklistEntry item) =>
        _clinicalPrintCellValue(context, item, column),
    cellBuilder: (BuildContext context, ClinicalWorklistEntry item) {
      return switch (column) {
        _ClinicalTableColumnId.patient => AppListItemText(
          title: item.displayTitle,
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
  final String? providerUserId = item.providerUserId?.trim();
  if (providerUserId != null && providerUserId.isNotEmpty) {
    return l10n.clinicalAssignedLabel;
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
    // Atomic status only — urgent / results-ready are row tint + dedicated tabs.
    return AppWorkspaceStatusBadge(status: _entryStatus(item));
  }
}

class _ClinicalWorklistNextActionCell extends ConsumerWidget {
  const _ClinicalWorklistNextActionCell({required this.item});

  final ClinicalWorklistEntry item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteClinical(policy);
    final String encounterId = item.apiEncounterId.trim();
    final String nextActionCode = WorkflowActionRegistry.instance.canonicalize(
      item.nextStep ?? item.stage ?? item.status ?? '',
    );
    if (canWrite &&
        nextActionCode == 'RECORD_VITALS' &&
        clinicalOpdFlowApiId(item) != null &&
        !item.isTerminal) {
      return _ClinicalCompactFallbackAction(
        label: l10n.opdRecordVitalsAction,
        icon: Icons.monitor_heart_outlined,
        onPressed: () async {
          final ClinicalWorkspaceController controller = ref.read(
            clinicalWorkspaceControllerProvider.notifier,
          );
          final AppFailure? selectFailure = await controller.selectEntry(item);
          if (!context.mounted) {
            return;
          }
          if (selectFailure != null) {
            _showFailureIfNeeded(context, selectFailure);
            return;
          }
          await _openVitalsDialog(context, controller);
        },
      );
    }
    if (encounterId.isNotEmpty) {
      final WorkflowActionContext actionContext = WorkflowActionContext(
        encounterId: encounterId,
        patientId: item.apiPatientId,
        admissionId: item.apiAdmissionId,
        stage: item.stage ?? item.status,
        nextStep: item.nextStep,
        sourceModule: _clinicalWorkflowSourceModule(item.sourceQueue),
      );
      final WorkflowAction? action = WorkflowActionRegistry.instance.resolve(
        context,
        actionContext,
        policy: policy,
      );
      // Hide permission-denied workflow affordances (no disabled lock UI).
      if (action != null && action.isAvailable) {
        return WorkflowActionButton(
          encounterId: encounterId,
          patientId: item.apiPatientId,
          admissionId: item.apiAdmissionId,
          stage: item.stage ?? item.status,
          nextStep: item.nextStep,
          sourceModule: _clinicalWorkflowSourceModule(item.sourceQueue),
          compact: false,
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
        canWrite &&
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
      return _ClinicalCompactFallbackAction(
        label: dispositionLabel,
        icon: Icons.task_alt_outlined,
        onPressed: () => _openCompleteDispositionDialog(
          context,
          ref,
          ref.read(clinicalWorkspaceControllerProvider.notifier),
          entry: item,
          actionLabel: dispositionLabel,
        ),
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
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 18, color: primaryColor),
                SizedBox(width: theme.spacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: primaryColor,
                      decoration: TextDecoration.underline,
                      decorationColor: primaryColor,
                    ),
                  ),
                ),
                if (!enabled) ...<Widget>[
                  SizedBox(width: theme.spacing.xs),
                  Icon(
                    Icons.lock_outlined,
                    size: 14,
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
    final AppLocalizations l10n = context.l10n;
    return AppListTableMobileItem(
      title: item.displayTitle,
      caption: item.worklistPatientSecondaryLine,
      meta: <AppListTableMobileMeta>[
        AppListTableMobileMeta(label: _entryStatus(item).label),
        ...switch (section) {
          ClinicalWorkspaceSection.resultsReady => <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: _apiLabel(item.encounterType ?? ''),
            ),
            AppListTableMobileMeta(label: _apiLabel(item.sourceQueue)),
          ],
          ClinicalWorkspaceSection.completed => <AppListTableMobileMeta>[
            AppListTableMobileMeta(label: _apiLabel(item.sourceQueue)),
            AppListTableMobileMeta(
              label: _apiLabel(item.encounterType ?? ''),
            ),
          ],
          _ => <AppListTableMobileMeta>[
            AppListTableMobileMeta(label: _apiLabel(item.sourceQueue)),
            AppListTableMobileMeta(
              label: _clinicalProviderLabel(l10n, item),
            ),
          ],
        },
      ],
    );
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
    final TextStyle? effectiveStyle = (textStyle ?? theme.textTheme.bodyMedium)
        ?.copyWith(color: color);

    return Semantics(
      label: status.label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: theme.appTokens.listIconSize, color: color),
          SizedBox(width: theme.spacing.xs),
          Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: effectiveStyle,
          ),
        ],
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
  return null;
}

Future<void> _openClinicalEntryDialog(
  BuildContext context,
  WidgetRef ref,
  ClinicalWorklistEntry entry, {
  String? initialPanel,
}) async {
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
    builder: (_) => _ClinicalEncounterDialog(
      initialEntry: entry,
      initialPanel: initialPanel,
    ),
  );
  controller.clearSelection();
}

class _ClinicalEncounterDialog extends ConsumerWidget {
  const _ClinicalEncounterDialog({
    required this.initialEntry,
    this.initialPanel,
  });

  final ClinicalWorklistEntry initialEntry;
  final String? initialPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<ClinicalWorkspaceState>> asyncState = ref.watch(
      clinicalWorkspaceControllerProvider,
    );

    return AppDialog(
      title: Text(l10n.clinicalEncounterDetailsTitle),
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
              return _ClinicalDetailPanel(
                state: state,
                initialPanel: initialPanel,
              );
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
  const _ClinicalDetailPanel({
    required this.state,
    this.initialPanel,
  });

  final ClinicalWorkspaceState state;
  final String? initialPanel;

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

    // Deep-link ?panel= notes|vitals|lab|radiology|pharmacy|diagnoses.
    final String panel = (initialPanel ?? '').trim().toLowerCase();
    final ClinicalWorklistEntry entry = bundle.entry;
    final AppWorkspaceStatus primaryStatus = _entryStatus(entry);
    final ClinicalTriageHandoff? triageHandoff = bundle.triageHandoff;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canViewLabResults = canViewClinicalLabResultsPanel(accessPolicy);
    final bool canViewRadiologyResults =
        canViewClinicalRadiologyResultsPanel(accessPolicy);
    final bool showUrgentAlert =
        entry.isUrgent &&
        ClinicalUrgentAtomPermissions.urgentChip.isAllowed(accessPolicy);
    final bool canWrite = canWriteClinical(accessPolicy);
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    final List<ClinicalRelatedRecord> clinicalNotes =
        sortClinicalRecordsNewestFirst(clinicalNotesForDisplay(bundle.clinicalNotes));
    final List<ClinicalRelatedRecord> diagnoses =
        deduplicateClinicalRelatedRecords(bundle.diagnoses, diagnoses: true);
    final List<ClinicalRelatedRecord> pharmacyOrders =
        deduplicateClinicalRelatedRecords(bundle.pharmacyOrders);
    final Key? panelAnchorKey =
        panel.isEmpty ? null : ValueKey<String>('clinical_panel_$panel');
    final List<Widget> sections = <Widget>[
      if (panelAnchorKey != null) SizedBox(key: panelAnchorKey, height: 0),
      _ClinicalEncounterContextPanel(
        entry: entry,
        status: primaryStatus,
        showPrimaryStatus: !_clinicalTriageShowsWorkflowStage(triageHandoff),
        alerts: <AppWorkspaceStatus>[
          if (showUrgentAlert)
            AppWorkspaceStatus(
              label: l10n.clinicalUrgentSummaryLabel,
              tone: AppWorkspaceStatusTone.error,
            ),
        ],
      ),
      _ClinicalActionBar(
        bundle: bundle,
        referenceData: state.referenceData,
      ),
      if (triageHandoff?.hasTriageDetails ?? false)
        _ClinicalTriageHandoffPanel(
          handoff: triageHandoff!,
          onEditVitals: canWrite &&
                  !entry.isTerminal &&
                  clinicalOpdFlowApiId(entry) != null
              ? () => _openVitalsDialog(
                    context,
                    controller,
                    hasExistingVitals: triageHandoff.vitalSigns.isNotEmpty,
                  )
              : null,
        ),
      if (clinicalNotes.isNotEmpty)
        _ClinicalNotesSection(
          records: clinicalNotes,
          canEdit: canWrite,
          onEditClinicalNotes: canWrite
              ? () => _openEditNotesDialog(context, controller, clinicalNotes)
              : null,
        ),
      if (pharmacyOrders.isNotEmpty)
        ClinicalPharmacyOrdersTablePanel(
          orders: pharmacyOrders,
          onCancel: (BuildContext context, ClinicalRelatedRecord order) =>
              _confirmLabOrderMutation(
                context: context,
                title: l10n.clinicalCancelPharmacyOrderDialogTitle,
                body: l10n.clinicalCancelPharmacyOrderDialogBody,
                confirmLabel: l10n.clinicalCancelPharmacyOrderAction,
                action: () => ref
                    .read(clinicalWorkspaceControllerProvider.notifier)
                    .cancelPharmacyOrder(order.id),
              ),
          onDelete: (BuildContext context, ClinicalRelatedRecord order) =>
              _confirmLabOrderMutation(
                context: context,
                title: l10n.clinicalDeletePharmacyOrderDialogTitle,
                body: l10n.clinicalDeletePharmacyOrderDialogBody,
                confirmLabel: l10n.clinicalDeletePharmacyOrderAction,
                action: () => ref
                    .read(clinicalWorkspaceControllerProvider.notifier)
                    .deletePharmacyOrder(order.id),
              ),
          onCancelSelected:
              (BuildContext context, List<ClinicalRelatedRecord> orders) =>
                  _confirmLabOrderMutation(
                    context: context,
                    title:
                        l10n.clinicalCancelSelectedPharmacyOrdersDialogTitle,
                    body: l10n.clinicalCancelSelectedPharmacyOrdersDialogBody(
                      orders.length,
                    ),
                    confirmLabel:
                        l10n.clinicalCancelSelectedPharmacyOrdersAction,
                    action: () async {
                      AppFailure? failure;
                      for (final ClinicalRelatedRecord order in orders) {
                        failure = await ref
                            .read(clinicalWorkspaceControllerProvider.notifier)
                            .cancelPharmacyOrder(order.id);
                        if (failure != null) {
                          return failure;
                        }
                      }
                      return null;
                    },
                  ),
          onDeleteSelected:
              (BuildContext context, List<ClinicalRelatedRecord> orders) =>
                  _confirmLabOrderMutation(
                    context: context,
                    title:
                        l10n.clinicalDeleteSelectedPharmacyOrdersDialogTitle,
                    body: l10n.clinicalDeleteSelectedPharmacyOrdersDialogBody(
                      orders.length,
                    ),
                    confirmLabel:
                        l10n.clinicalDeleteSelectedPharmacyOrdersAction,
                    action: () async {
                      AppFailure? failure;
                      for (final ClinicalRelatedRecord order in orders) {
                        failure = await ref
                            .read(clinicalWorkspaceControllerProvider.notifier)
                            .deletePharmacyOrder(order.id);
                        if (failure != null) {
                          return failure;
                        }
                      }
                      return null;
                    },
                  ),
        ),
      if (diagnoses.isNotEmpty)
        ClinicalDiagnosesTablePanel(
          diagnoses: diagnoses,
          onAdd: canWrite
              ? () => _openDiagnosisDialog(
                    context,
                    controller,
                    existingDiagnoses: diagnoses,
                  )
              : null,
          onEditSelected: canWrite
              ? (BuildContext context, List<ClinicalRelatedRecord> selected) =>
                    _openEditDiagnosisDialog(
                      context,
                      ref.read(clinicalWorkspaceControllerProvider.notifier),
                      selected,
                    )
              : null,
          onRemove: (BuildContext context, ClinicalRelatedRecord diagnosis) =>
              _confirmLabOrderMutation(
                context: context,
                title: l10n.clinicalRemoveDiagnosisDialogTitle,
                body: l10n.clinicalRemoveDiagnosisDialogBody,
                confirmLabel: l10n.clinicalRemoveDiagnosisAction,
                action: () => ref
                    .read(clinicalWorkspaceControllerProvider.notifier)
                    .deleteDiagnosis(diagnosis.id),
              ),
          onRemoveSelected:
              (BuildContext context, List<ClinicalRelatedRecord> selected) =>
                  _confirmLabOrderMutation(
                    context: context,
                    title: l10n.clinicalRemoveSelectedDiagnosesDialogTitle,
                    body: l10n.clinicalRemoveSelectedDiagnosesDialogBody(
                      selected.length,
                    ),
                    confirmLabel: l10n.clinicalRemoveSelectedDiagnosesAction,
                    action: () async {
                      AppFailure? failure;
                      for (final ClinicalRelatedRecord diagnosis
                          in selected) {
                        failure = await ref
                            .read(clinicalWorkspaceControllerProvider.notifier)
                            .deleteDiagnosis(diagnosis.id);
                        if (failure != null) {
                          return failure;
                        }
                      }
                      return null;
                    },
                  ),
        ),
      if (canViewLabResults && bundle.labOrders.isNotEmpty)
        ClinicalLabOrdersTablePanel(
          orders: deduplicateClinicalRelatedRecords(bundle.labOrders),
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
          onCancelItem:
              (
                BuildContext context,
                ClinicalRelatedRecord order,
                ClinicalLabOrderItem item,
              ) => _confirmLabOrderMutation(
                context: context,
                title: l10n.clinicalCancelLabTestDialogTitle,
                body: l10n.clinicalCancelLabTestDialogBody(item.displayTitle),
                confirmLabel: l10n.clinicalCancelLabTestAction,
                action: () => ref
                    .read(clinicalWorkspaceControllerProvider.notifier)
                    .cancelLabOrderItem(
                      labOrderId: order.id,
                      item: item,
                      orderItems: order.labOrderItems,
                      reason: l10n.clinicalCancelLabTestReason,
                    ),
              ),
          onCancelSelected:
              (BuildContext context, List<ClinicalRelatedRecord> orders) =>
                  _confirmLabOrderMutation(
                    context: context,
                    title: l10n.clinicalCancelSelectedLabOrdersDialogTitle,
                    body: l10n.clinicalCancelSelectedLabOrdersDialogBody(
                      orders.length,
                    ),
                    confirmLabel: l10n.clinicalCancelSelectedLabOrdersAction,
                    action: () async {
                      AppFailure? failure;
                      for (final ClinicalRelatedRecord order in orders) {
                        failure = await ref
                            .read(clinicalWorkspaceControllerProvider.notifier)
                            .cancelLabOrder(order.id);
                        if (failure != null) {
                          return failure;
                        }
                      }
                      return null;
                    },
                  ),
          onDeleteSelected:
              (BuildContext context, List<ClinicalRelatedRecord> orders) =>
                  _confirmLabOrderMutation(
                    context: context,
                    title: l10n.clinicalDeleteSelectedLabOrdersDialogTitle,
                    body: l10n.clinicalDeleteSelectedLabOrdersDialogBody(
                      orders.length,
                    ),
                    confirmLabel: l10n.clinicalDeleteSelectedLabOrdersAction,
                    action: () async {
                      AppFailure? failure;
                      for (final ClinicalRelatedRecord order in orders) {
                        failure = await ref
                            .read(clinicalWorkspaceControllerProvider.notifier)
                            .deleteLabOrder(order.id);
                        if (failure != null) {
                          return failure;
                        }
                      }
                      return null;
                    },
                  ),
        ),
      if (canViewRadiologyResults && bundle.radiologyOrders.isNotEmpty)
        ClinicalRadiologyOrdersTablePanel(
          orders: deduplicateClinicalRelatedRecords(bundle.radiologyOrders),
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
          onCancelSelected:
              (BuildContext context, List<ClinicalRelatedRecord> orders) =>
                  _confirmLabOrderMutation(
                    context: context,
                    title: l10n.clinicalCancelSelectedRadiologyOrdersDialogTitle,
                    body: l10n.clinicalCancelSelectedRadiologyOrdersDialogBody(
                      orders.length,
                    ),
                    confirmLabel:
                        l10n.clinicalCancelSelectedRadiologyOrdersAction,
                    action: () async {
                      AppFailure? failure;
                      for (final ClinicalRelatedRecord order in orders) {
                        failure = await ref
                            .read(clinicalWorkspaceControllerProvider.notifier)
                            .cancelRadiologyOrder(order.id);
                        if (failure != null) {
                          return failure;
                        }
                      }
                      return null;
                    },
                  ),
          onDeleteSelected:
              (BuildContext context, List<ClinicalRelatedRecord> orders) =>
                  _confirmLabOrderMutation(
                    context: context,
                    title: l10n.clinicalDeleteSelectedRadiologyOrdersDialogTitle,
                    body: l10n.clinicalDeleteSelectedRadiologyOrdersDialogBody(
                      orders.length,
                    ),
                    confirmLabel:
                        l10n.clinicalDeleteSelectedRadiologyOrdersAction,
                    action: () async {
                      AppFailure? failure;
                      for (final ClinicalRelatedRecord order in orders) {
                        failure = await ref
                            .read(clinicalWorkspaceControllerProvider.notifier)
                            .deleteRadiologyOrder(order.id);
                        if (failure != null) {
                          return failure;
                        }
                      }
                      return null;
                    },
                  ),
        ),
      if (bundle.procedures.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.opdProceduresSummaryLabel,
          records: sortClinicalRecordsNewestFirst(
            deduplicateClinicalRelatedRecords(bundle.procedures),
          ),
        ),
      if (bundle.referrals.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.opdReferralsTitle,
          records: sortClinicalRecordsNewestFirst(
            deduplicateClinicalRelatedRecords(bundle.referrals),
          ),
        ),
      if (bundle.followUps.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.opdFollowUpsTitle,
          records: sortClinicalRecordsNewestFirst(
            deduplicateClinicalRelatedRecords(bundle.followUps),
          ),
        ),
      if (bundle.admissions.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.patientsAdmissionsSectionTitle,
          records: sortClinicalRecordsNewestFirst(
            deduplicateClinicalRelatedRecords(bundle.admissions),
          ),
        ),
      if (bundle.carePlans.isNotEmpty)
        _ClinicalRecordSection(
          title: l10n.clinicalCarePlansTitle,
          records: sortClinicalRecordsNewestFirst(
            deduplicateClinicalRelatedRecords(bundle.carePlans),
          ),
        ),
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
    this.alerts = const <AppWorkspaceStatus>[],
  });

  final ClinicalWorklistEntry entry;
  final AppWorkspaceStatus status;
  final bool showPrimaryStatus;
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
      phoneLabel: entry.patientPhone,
      compactSupportingText:
          entry.patientDateOfBirth == null && genderLabel.isEmpty
          ? entry.patientAgeSex?.trim()
          : null,
      showAvatar: false,
      semanticLabel: l10n.patientsDetailTitle,
      persistExpandPreference: false,
      initiallyExpanded: false,
      status: showPrimaryStatus && status.label.isNotEmpty ? status : null,
      alerts: alerts,
      expandedFields: _clinicalPatientContextFields(
        context,
        l10n,
        entry,
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
  const _ClinicalTriageHandoffPanel({
    required this.handoff,
    this.onEditVitals,
  });

  final ClinicalTriageHandoff handoff;
  final VoidCallback? onEditVitals;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final int criticalVitalCount = handoff.vitalSigns
        .where(
          (ClinicalVitalSummary vital) =>
              vital.status.toUpperCase() == 'CRITICAL',
        )
        .length;
    final int abnormalVitalCount = handoff.vitalSigns.where((
      ClinicalVitalSummary vital,
    ) {
      final String status = vital.status.toUpperCase();
      return status == 'HIGH' ||
          status == 'LOW' ||
          status == 'ABNORMAL' ||
          status == 'CRITICAL';
    }).length;
    final AppWorkspaceStatus vitalStatus = AppWorkspaceStatus(
      label: criticalVitalCount > 0
          ? l10n.clinicalResultsFlagCriticalLabel
          : abnormalVitalCount > 0
          ? l10n.opdAbnormalVitalsSummaryLabel
          : l10n.patientsVitalNormalLabel,
      tone: criticalVitalCount > 0
          ? AppWorkspaceStatusTone.error
          : abnormalVitalCount > 0
          ? AppWorkspaceStatusTone.warning
          : AppWorkspaceStatusTone.success,
    );
    final List<AppWorkspacePatientContextField> triageFacts =
        <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: l10n.opdTriageLevelLabel,
            value: triageLevelDisplayLabel(
              l10n,
              handoff.triageLevel,
              emptyAsPending: false,
            ),
            icon: Icons.health_and_safety_outlined,
            tone: appTriageToneForValue(handoff.triageLevel),
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdRouteDecisionLabel,
            value: _apiLabel(handoff.routeTo ?? ''),
            icon: AppActionIcons.route,
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdChiefComplaintLabel,
            value: handoff.chiefComplaint ?? '',
            icon: Icons.medical_information_outlined,
          ),
          AppWorkspacePatientContextField(
            label: l10n.opdTimeColumnLabel,
            value: handoff.queuedAt == null
                ? ''
                : _dateTimeLabel(context, handoff.queuedAt),
            icon: AppActionIcons.time,
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
            icon: Icons.sticky_note_2_outlined,
          ),
        ];
    final List<AppWorkspacePatientContextField> vitalFacts =
        <AppWorkspacePatientContextField>[
          for (final ClinicalVitalSummary vital in handoff.vitalSigns)
            AppWorkspacePatientContextField(
              label: _apiLabel(vital.vitalType),
              value: vital.displayValue,
              icon: appVitalTypeIcon(vital.vitalType),
              tone: _clinicalVitalTone(vital.status),
            ),
        ];

    return AppCollapsibleSection(
      titleWidget: Row(
        children: <Widget>[
          Text(
            l10n.clinicalVitalsSectionTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppFontWeight.strong,
            ),
          ),
          if (vitalFacts.isNotEmpty) ...<Widget>[
            SizedBox(width: theme.spacing.md),
            Flexible(child: _ClinicalVitalsLegend()),
          ],
        ],
      ),
      headerActions: onEditVitals == null
          ? const <Widget>[]
          : <Widget>[
              AppButton.secondary(
                label: handoff.vitalSigns.isNotEmpty
                    ? l10n.opdEditVitalsAction
                    : l10n.opdRecordVitalsAction,
                leadingIcon: handoff.vitalSigns.isNotEmpty
                    ? AppActionIcons.edit
                    : Icons.monitor_heart_outlined,
                dense: true,
                onPressed: onEditVitals,
              ),
            ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppPatientContextFactsRow(
            leading: vitalFacts.isEmpty
                ? const <Widget>[]
                : <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '${l10n.opdVitalsSummaryLabel}:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: AppFontWeight.emphasis,
                          ),
                        ),
                        SizedBox(width: theme.spacing.xs),
                        _ClinicalStatusText(status: vitalStatus),
                      ],
                    ),
                  ],
            fields: triageFacts,
          ),
          if (vitalFacts.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            AppPatientContextFactsRow(fields: vitalFacts),
          ],
        ],
      ),
    );
  }
}

class _ClinicalVitalsLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: theme.spacing.md,
      runSpacing: theme.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _ClinicalVitalLegendItem(
          color: _clinicalVitalValueColor(theme, 'LOW'),
          label: l10n.labStatusLow,
        ),
        _ClinicalVitalLegendItem(
          color: _clinicalVitalValueColor(theme, 'NORMAL'),
          label: l10n.patientsVitalNormalLabel,
        ),
        _ClinicalVitalLegendItem(
          color: _clinicalVitalValueColor(theme, 'HIGH'),
          label: l10n.labStatusHigh,
        ),
        _ClinicalVitalLegendItem(
          color: _clinicalVitalValueColor(theme, 'CRITICAL'),
          label: l10n.labStatusCritical,
        ),
      ],
    );
  }
}

class _ClinicalVitalLegendItem extends StatelessWidget {
  const _ClinicalVitalLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: theme.spacing.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: AppFontWeight.regular,
          ),
        ),
      ],
    );
  }
}

class _ClinicalActionBar extends ConsumerWidget {
  const _ClinicalActionBar({
    required this.bundle,
    required this.referenceData,
  });

  final ClinicalEncounterBundle bundle;
  final ClinicalReferenceData referenceData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ClinicalWorkspaceController controller = ref.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteClinical(policy);
    final bool canLab = canWriteClinicalLabOrder(policy);
    final bool canRadiology = canWriteClinicalRadiologyOrder(policy);
    final bool canPharmacy = canWriteClinicalPharmacyOrder(policy);
    final bool canAdmission = canRequestClinicalAdmission(policy);
    final bool canPrint = canPrintClinicalWorkspace(policy);
    final String dispositionActionLabel = clinicalDispositionActionLabel(
      l10n,
      sourceQueue: bundle.entry.sourceQueue,
      status: bundle.entry.status,
      stage: bundle.entry.stage,
      location: bundle.entry.currentLocation,
      hasAdmission: bundle.entry.admissionId?.trim().isNotEmpty ?? false,
    );
    final bool canCompleteDisposition =
        canWrite &&
        !bundle.entry.isTerminal &&
        isClinicalDispositionActionAvailable(
          sourceQueue: bundle.entry.sourceQueue,
          status: bundle.entry.status,
          stage: bundle.entry.stage,
          location: bundle.entry.currentLocation,
          hasAdmission: bundle.entry.admissionId?.trim().isNotEmpty ?? false,
          hasOpdFlow: bundle.entry.opdFlowApiId?.trim().isNotEmpty ?? false,
        );
    final List<AppActionItem> actions = <AppActionItem>[
      if (canWrite &&
          !bundle.entry.isTerminal &&
          clinicalOpdFlowApiId(bundle.entry) != null)
        AppActionItem(
          label: (bundle.triageHandoff?.vitalSigns.isNotEmpty ?? false)
              ? l10n.opdEditVitalsAction
              : l10n.opdRecordVitalsAction,
          leadingIcon: Icons.monitor_heart_outlined,
          onPressed: () => _openVitalsDialog(
            context,
            controller,
            hasExistingVitals:
                bundle.triageHandoff?.vitalSigns.isNotEmpty ?? false,
          ),
        ),
      if (canWrite)
        AppActionItem(
          label: clinicalNotesForDisplay(bundle.clinicalNotes).isEmpty
              ? l10n.clinicalAddNoteAction
              : l10n.clinicalEditNotesAction,
          leadingIcon: clinicalNotesForDisplay(bundle.clinicalNotes).isEmpty
              ? Icons.note_add_outlined
              : AppActionIcons.edit,
          onPressed: () {
            final List<ClinicalRelatedRecord> notes =
                sortClinicalRecordsNewestFirst(
                  clinicalNotesForDisplay(bundle.clinicalNotes),
                );
            if (notes.isEmpty) {
              _openNoteDialog(context, controller);
              return;
            }
            _openEditNotesDialog(
              context,
              controller,
              notes,
            );
          },
        ),
      if (canWrite)
        AppActionItem(
          label: l10n.clinicalAddDiagnosisAction,
          leadingIcon: AppActionIcons.triage,
          onPressed: () => _openDiagnosisDialog(
            context,
            controller,
            existingDiagnoses: deduplicateClinicalRelatedRecords(
              bundle.diagnoses,
              diagnoses: true,
            ),
          ),
        ),
      if (canLab)
        AppActionItem(
          label: l10n.clinicalRequestLabAction,
          leadingIcon: Icons.science_outlined,
          onPressed: () =>
              _openLabDialog(context, controller, referenceData),
        ),
      if (canRadiology)
        AppActionItem(
          label: l10n.clinicalRequestRadiologyAction,
          leadingIcon: Icons.biotech_outlined,
          onPressed: () =>
              _openRadiologyDialog(
                context,
                controller,
                referenceData,
                existingRadiologyOrders: bundle.radiologyOrders,
              ),
        ),
      if (canPharmacy)
        AppActionItem(
          label: l10n.clinicalPrescribeAction,
          leadingIcon: Icons.medication_outlined,
          onPressed: () => _openPrescriptionDialog(
            context,
            ref,
            controller,
            referenceData,
          ),
        ),
      if (canWrite)
        AppActionItem(
          label: l10n.clinicalRequestProcedureAction,
          leadingIcon: Icons.healing_outlined,
          onPressed: () => _openProcedureDialog(context, controller),
        ),
      if (canWrite)
        AppActionItem(
          label: l10n.opdReferAction,
          leadingIcon: AppActionIcons.referral,
          onPressed: () => _openReferralDialog(context, controller),
        ),
      if (canWrite)
        AppActionItem(
          label: l10n.opdFollowUpAction,
          leadingIcon: AppActionIcons.followUp,
          onPressed: () => _openFollowUpDialog(context, controller),
        ),
      if (canCompleteDisposition)
        AppActionItem(
          label: dispositionActionLabel,
          leadingIcon: AppActionIcons.complete,
          onPressed: () => _openCompleteDispositionDialog(
            context,
            ref,
            controller,
            entry: bundle.entry,
            actionLabel: dispositionActionLabel,
          ),
        ),
      if (canAdmission)
        AppActionItem(
          label: l10n.clinicalRequestAdmissionAction,
          leadingIcon: AppActionIcons.bed,
          onPressed: () =>
              _openAdmissionDialog(context, controller, referenceData),
        ),
      if (canPrint)
        AppActionItem(
          label: l10n.commonPrintActionLabel,
          leadingIcon: AppActionIcons.print,
          onPressed: () async {
            await showClinicalPrintSummaryDialog(
              context: context,
              bundle: bundle,
            );
          },
        ),
    ];
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppQuickActions(
      title: l10n.clinicalActionsTitle,
      presentation: AppQuickActionsPresentation.detailPanel,
      actions: actions,
    );
  }
}

class _ClinicalNotesSection extends StatelessWidget {
  const _ClinicalNotesSection({
    required this.records,
    required this.canEdit,
    this.onEditClinicalNotes,
  });

  final List<ClinicalRelatedRecord> records;
  final bool canEdit;
  final VoidCallback? onEditClinicalNotes;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DateTime? lastUpdated = records
        .map((ClinicalRelatedRecord note) => note.occurredAt)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (DateTime? latest, DateTime value) =>
              latest == null || value.isAfter(latest) ? value : latest,
        );

    return AppCollapsibleSection(
      titleWidget: Row(
        children: <Widget>[
          Text(
            l10n.clinicalPatientNotesTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppFontWeight.strong,
            ),
          ),
          if (lastUpdated != null) ...<Widget>[
            SizedBox(width: theme.spacing.md),
            Flexible(
              child: Text(
                '${l10n.clinicalLastUpdatedLabel}: '
                '${_dateTimeLabel(context, lastUpdated)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: AppFontWeight.regular,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      headerActions: canEdit && onEditClinicalNotes != null
          ? <Widget>[
              AppButton.secondary(
                label: l10n.commonEditActionLabel,
                leadingIcon: AppActionIcons.edit,
                dense: true,
                onPressed: onEditClinicalNotes,
              ),
            ]
          : const <Widget>[],
      child: _ClinicalNotesBody(records: records),
    );
  }
}

class _ClinicalNotesBody extends StatelessWidget {
  const _ClinicalNotesBody({required this.records});

  final List<ClinicalRelatedRecord> records;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < records.length; index += 1) ...<Widget>[
          if (index > 0) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            const Divider(height: 1),
            SizedBox(height: theme.spacing.sm),
          ],
          AppRichTextView(text: (records[index].title ?? '').trim()),
        ],
      ],
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

    return AppCollapsibleSection(
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
                    fontWeight: AppFontWeight.emphasis,
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
                        fontWeight: AppFontWeight.emphasis,
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
            requirement: clinicalPharmacyOrderWriteRequirement,
            builder: (BuildContext context, bool isAllowed) {
              if (!isAllowed) {
                return const SizedBox.shrink();
              }
              return Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  if (canCancel)
                    AppButton(
                      iconOnly: true,
                      leadingIcon: Icons.block_outlined,
                      label: l10n.clinicalCancelPharmacyOrderAction,

                      semanticLabel: l10n.clinicalCancelPharmacyOrderAction,
                      tooltip: l10n.clinicalCancelPharmacyOrderAction,
                      onPressed: () => _confirmLabOrderMutation(
                        context: context,
                        title: l10n.clinicalCancelPharmacyOrderDialogTitle,
                        body: l10n.clinicalCancelPharmacyOrderDialogBody,
                        confirmLabel: l10n.clinicalCancelPharmacyOrderAction,
                        action: () => controller.cancelPharmacyOrder(record.id),
                      ),
                    ),
                  if (canDelete)
                    AppButton(
                      iconOnly: true,
                      leadingIcon: Icons.delete_outline,
                      label: l10n.clinicalDeletePharmacyOrderAction,

                      semanticLabel: l10n.clinicalDeletePharmacyOrderAction,
                      tooltip: l10n.clinicalDeletePharmacyOrderAction,
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
    final String readableSummary = clinicalPrescriptionItemPaperLine(item);
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
                        fontWeight: AppFontWeight.emphasis,
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
      builder: (_) => ClinicalAddNotesActionDialog(
        onSubmit: controller.addClinicalNote,
      ),
    ),
  );
}

Future<void> _openEditNotesDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
  List<ClinicalRelatedRecord> notes,
) async {
  if (notes.isEmpty) {
    return;
  }

  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalEditNotesActionDialog(
        notes: <ClinicalNoteEditEntry>[
          for (final ClinicalRelatedRecord note in notes)
            ClinicalNoteEditEntry(
              id: note.id,
              text: (note.title ?? '').trim(),
              occurredAt: note.occurredAt,
            ),
        ],
        onSubmit: (Map<String, String> drafts) async {
          AppFailure? failure;
          for (final MapEntry<String, String> draft in drafts.entries) {
            failure = await controller.updateClinicalNote(
              noteId: draft.key,
              note: draft.value,
            );
            if (failure != null) {
              return failure;
            }
          }
          return null;
        },
      ),
    ),
  );
}

Future<void> _openVitalsDialog(
  BuildContext context,
  ClinicalWorkspaceController controller, {
  bool hasExistingVitals = false,
}) async {
  final Result<OpdFlowDetail> detailResult = await controller
      .loadSelectedOpdFlowDetail();
  if (!context.mounted) {
    return;
  }

  OpdFlowDetail? detail;
  AppFailure? loadFailure;
  detailResult.when(
    success: (OpdFlowDetail value) => detail = value,
    failure: (AppFailure failure) => loadFailure = failure,
  );

  if (detail == null) {
    _showFailureIfNeeded(context, loadFailure ?? AppFailure.validation());
    return;
  }

  final bool editing =
      hasExistingVitals || detail!.vitalMeasurements.isNotEmpty;

  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalVitalsActionDialog(
        detail: detail,
        editing: editing,
        onSubmit: (List<Map<String, Object?>> vitals) {
          return controller.recordEncounterVitals(
            vitals: vitals,
            updateExisting: editing,
          );
        },
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
  ClinicalWorkspaceController controller, {
  List<ClinicalRelatedRecord> existingDiagnoses = const <ClinicalRelatedRecord>[],
}) async {
  final Set<String> existingKeys = existingDiagnoses
      .map(
        (ClinicalRelatedRecord diagnosis) => clinicalDiagnosisDedupKey(
          code: diagnosis.code,
          description: diagnosis.title,
          fallbackId: diagnosis.id,
        ),
      )
      .where((String key) => key.isNotEmpty)
      .toSet();

  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalDiagnosisActionDialog(
        existingDiagnosisKeys: existingKeys,
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

Future<void> _openEditDiagnosisDialog(
  BuildContext context,
  ClinicalWorkspaceController controller,
  List<ClinicalRelatedRecord> diagnoses,
) async {
  if (diagnoses.isEmpty) {
    return;
  }
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalEditDiagnosisActionDialog(
        diagnoses: diagnoses,
        onSubmit: controller.updateDiagnosesType,
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
  ClinicalReferenceData referenceData, {
  List<ClinicalRelatedRecord> existingRadiologyOrders =
      const <ClinicalRelatedRecord>[],
}) async {
  final Set<String> alreadyOrderedProcedureIds =
      _clinicalRadiologyProceduresOrderedToday(existingRadiologyOrders);
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalRadiologyOrderActionDialog(
        referenceData: referenceData,
        patientContext: _clinicalLabOrderPatientContext(context),
        alreadyOrderedProcedureIds: alreadyOrderedProcedureIds,
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

/// Procedure IDs already requested for this encounter on the local calendar day.
Set<String> _clinicalRadiologyProceduresOrderedToday(
  List<ClinicalRelatedRecord> orders, {
  DateTime? now,
}) {
  final DateTime reference = now ?? DateTime.now();
  final Set<String> ids = <String>{};
  for (final ClinicalRelatedRecord order in orders) {
    final String status = order.status?.trim().toUpperCase() ?? '';
    if (status == 'CANCELLED') {
      continue;
    }
    final DateTime? orderedAt = order.occurredAt;
    if (orderedAt == null ||
        orderedAt.year != reference.year ||
        orderedAt.month != reference.month ||
        orderedAt.day != reference.day) {
      continue;
    }
    for (final ClinicalRadiologyOrderItem item in order.radiologyOrderItems) {
      final String? procedureId = item.radiologyProcedureId?.trim();
      if (procedureId != null && procedureId.isNotEmpty) {
        ids.add(procedureId.toLowerCase());
      }
    }
  }
  return ids;
}

Future<void> _openPrescriptionDialog(
  BuildContext context,
  WidgetRef ref,
  ClinicalWorkspaceController controller,
  ClinicalReferenceData referenceData,
) async {
  final String? patientId = _clinicalLabOrderPatientContext(context).patientId;
  final ClinicalRequestPayerContext? payerContext =
      await resolvePharmacyPrescriptionPayerContext(
        repository: ref.read(insuranceCatalogRepositoryProvider),
        patientId: patientId,
      );
  if (!context.mounted) {
    return;
  }
  final String? facilityId = ref
      .read(sessionStateProvider)
      .session
      ?.user
      ?.facilityId;
  await _showActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalPrescriptionActionDialog(
        referenceData: referenceData,
        payerContext: payerContext,
        loadCatalogDrugs: pharmacyPrescriptionCatalogLoader(
          repository: ref.read(pharmacyRepositoryProvider),
          facilityId: facilityId,
        ),
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
      if (_hasText(filters.urgency)) _clinicalFilterUrgency: filters.urgency!,
      if (_hasText(filters.resultsReady))
        _clinicalFilterResultsReady: filters.resultsReady!,
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
    urgency: value.option(_clinicalFilterUrgency),
    resultsReady: value.option(_clinicalFilterResultsReady),
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
    AppSearchBarFilterGroup(
      key: _clinicalFilterUrgency,
      label: l10n.clinicalSectionUrgentLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: clinicalUrgentFilterValue,
          label: l10n.clinicalSectionUrgentLabel,
          icon: Icons.priority_high_outlined,
        ),
        AppSearchBarFilterChoice(
          value: clinicalNotUrgentFilterValue,
          label: l10n.clinicalFilterNotUrgentLabel,
          icon: Icons.remove_outlined,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: _clinicalFilterResultsReady,
      label: l10n.clinicalSectionResultsReadyLabel,
      allLabel: l10n.opdAllFieldsFilterLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: clinicalResultsReadyFilterValue,
          label: l10n.clinicalSectionResultsReadyLabel,
          icon: Icons.science_outlined,
        ),
        AppSearchBarFilterChoice(
          value: clinicalResultsNotReadyFilterValue,
          label: l10n.clinicalFilterResultsNotReadyLabel,
          icon: Icons.hourglass_empty_outlined,
        ),
      ],
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
  ClinicalWorklistEntry entry,
) {
  final String dob = entry.patientDateOfBirth == null
      ? ''
      : AppFormatters.mediumDate(
          entry.patientDateOfBirth!,
          Localizations.localeOf(context),
        );
  final DateTime? lastUpdated = entry.updatedAt ?? entry.startedAt;

  // AppPatientDetails header shows name and public ID; age/gender are body fields.
  return <AppWorkspacePatientContextField>[
    AppWorkspacePatientContextField(
      label: l10n.clinicalEncounterNumberLabel,
      value: entry.encounterPublicId ?? entry.encounterId,
      icon: Icons.tag_outlined,
      copyable: true,
      copyTooltip: l10n.opdCopyEncounterIdAction,
      copiedMessage: l10n.opdEncounterIdCopiedMessage,
    ),
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
      value: _clinicalProviderLabel(l10n, entry),
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
  return appCollapsibleSectionSpacing(context, sections);
}

bool _clinicalTriageShowsWorkflowStage(ClinicalTriageHandoff? handoff) {
  if (handoff == null || !handoff.hasContent) {
    return false;
  }
  final String stage = handoff.stage?.trim() ?? '';
  final String nextStep = handoff.nextStep?.trim() ?? '';
  return stage.isNotEmpty || nextStep.isNotEmpty || handoff.timeline.isNotEmpty;
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
    'AWAITING_REPORT' ||
    'RESULTS_READY' ||
    'OPEN' => AppWorkspaceStatusTone.info,
    'PENDING' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

/// Low = blue, Normal = on-surface, High = amber, Critical = red.
Color _clinicalVitalValueColor(ThemeData theme, String? status) {
  final ColorScheme colorScheme = theme.colorScheme;
  return switch ((status ?? '').toUpperCase()) {
    'CRITICAL' => colorScheme.error,
    'HIGH' || 'ABNORMAL' => const Color(0xFFD97706),
    'LOW' => colorScheme.primary,
    'NORMAL' || 'RECORDED' => colorScheme.onSurface,
    _ => colorScheme.onSurface,
  };
}

AppWorkspaceStatusTone _clinicalVitalTone(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'CRITICAL' => AppWorkspaceStatusTone.error,
    'HIGH' || 'ABNORMAL' => AppWorkspaceStatusTone.warning,
    'LOW' => AppWorkspaceStatusTone.info,
    'NORMAL' || 'RECORDED' => AppWorkspaceStatusTone.success,
    _ => AppWorkspaceStatusTone.neutral,
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
const String _clinicalFilterUrgency = 'urgency';
const String _clinicalFilterResultsReady = 'results_ready';

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

Future<void> _printClinicalWorklist(
  BuildContext context,
  WidgetRef ref, {
  required List<ClinicalWorklistEntry> items,
  required ClinicalWorkspaceSection section,
  required bool showNextAction,
  required AppLocalizations l10n,
}) async {
  final List<_ClinicalTableColumnId> defaults =
      _clinicalResolvedDefaultColumnsForSection(
        section,
        showNextAction: showNextAction,
      );
  final List<_ClinicalTableColumnId> choices =
      _clinicalResolvedColumnChoicesForSection(
        section,
        showNextAction: showNextAction,
        defaults: defaults,
      );
  final List<_ClinicalTableColumnId> columnIds = <_ClinicalTableColumnId>[
    ...defaults,
    ...choices,
  ];
  final List<ClinicalWorkspacePrintColumn> printColumns =
      <ClinicalWorkspacePrintColumn>[
        for (final _ClinicalTableColumnId column in columnIds)
          ClinicalWorkspacePrintColumn(
            id: column.name,
            label: _clinicalTableColumnLabel(context, column),
          ),
      ];
  final List<Map<String, String>> printRows = <Map<String, String>>[
    for (final ClinicalWorklistEntry item in items)
      <String, String>{
        for (final _ClinicalTableColumnId column in columnIds)
          column.name: _clinicalPrintCellValue(context, item, column),
      },
  ];
  await printClinicalWorkspaceList(
    ref: ref,
    context: context,
    title: _clinicalSectionLabel(l10n, section),
    columns: printColumns,
    rows: printRows,
    emptyText: l10n.clinicalNoWorklistTitle,
  );
}

Future<void> _printClinicalFollowUpsList(
  BuildContext context,
  WidgetRef ref, {
  required List<ReceptionFollowUpEntry> entries,
  required AppLocalizations l10n,
}) async {
  final Locale locale = Localizations.localeOf(context);
  final List<ClinicalWorkspacePrintColumn> printColumns =
      <ClinicalWorkspacePrintColumn>[
        ClinicalWorkspacePrintColumn(
          id: 'patient',
          label: l10n.opdPatientNameLabel,
        ),
        ClinicalWorkspacePrintColumn(
          id: 'phone',
          label: l10n.patientsPhoneIdentifierColumnLabel,
        ),
        ClinicalWorkspacePrintColumn(
          id: 'status',
          label: l10n.receptionStatusLabel,
        ),
        ClinicalWorkspacePrintColumn(
          id: 'date',
          label: l10n.opdFollowUpDateLabel,
        ),
        ClinicalWorkspacePrintColumn(
          id: 'time',
          label: l10n.opdFollowUpTimeLabel,
        ),
        ClinicalWorkspacePrintColumn(
          id: 'patient_id',
          label: l10n.opdPatientIdLabel,
        ),
        ClinicalWorkspacePrintColumn(
          id: 'email',
          label: l10n.patientsEmailLabel,
        ),
        ClinicalWorkspacePrintColumn(id: 'notes', label: l10n.opdNotesLabel),
      ];
  final List<Map<String, String>> printRows = <Map<String, String>>[
    for (final ReceptionFollowUpEntry entry in entries)
      <String, String>{
        'patient': entry.patientDisplayName?.trim().isNotEmpty == true
            ? entry.patientDisplayName!.trim()
            : l10n.profileUnknownValue,
        'phone': entry.patientPhone?.trim() ?? '',
        'status': opdStageDisplayLabel(l10n, entry.status),
        'date': AppFormatters.shortDate(entry.scheduledAt.toLocal(), locale),
        'time': AppFormatters.time(entry.scheduledAt.toLocal(), locale),
        'patient_id': entry.patientIdentifier,
        'email': entry.patientEmail?.trim() ?? '',
        'notes': entry.notes?.trim() ?? '',
      },
  ];
  await printClinicalWorkspaceList(
    ref: ref,
    context: context,
    title: l10n.opdFollowUpsTitle,
    columns: printColumns,
    rows: printRows,
    emptyText: l10n.receptionFollowUpsEmptyTitle,
  );
}

String _clinicalPrintCellValue(
  BuildContext context,
  ClinicalWorklistEntry item,
  _ClinicalTableColumnId column,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (column) {
    _ClinicalTableColumnId.patient => item.displayTitle,
    _ClinicalTableColumnId.patientId =>
      item.apiPatientId ?? l10n.profileUnknownValue,
    _ClinicalTableColumnId.phone =>
      item.patientPhone ?? l10n.profileUnknownValue,
    _ClinicalTableColumnId.ageSex => _clinicalWorklistAgeSexLabel(context, item),
    _ClinicalTableColumnId.queue => item.sourceQueue,
    _ClinicalTableColumnId.status => item.status ?? '',
    _ClinicalTableColumnId.nextAction => item.nextStep ?? '',
    _ClinicalTableColumnId.provider => _clinicalProviderLabel(l10n, item),
    _ClinicalTableColumnId.lastUpdated =>
      _dateTimeLabel(context, item.updatedAt ?? item.startedAt),
    _ClinicalTableColumnId.encounter => item.apiEncounterId,
    _ClinicalTableColumnId.admission =>
      item.apiAdmissionId ?? l10n.profileUnknownValue,
    _ClinicalTableColumnId.encounterType =>
      _apiLabel(item.encounterType ?? ''),
    _ClinicalTableColumnId.location =>
      item.currentLocation ?? l10n.profileUnknownValue,
  };
}
