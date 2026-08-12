import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_action_dialogs.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_bed_board_panel.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_board_filters.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_board_panel.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_workspace_print_helpers.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/routing/workspace_location_sync.dart';

class IcuWorkspacePage extends ConsumerStatefulWidget {
  const IcuWorkspacePage({super.key, this.initialQuery});

  final IcuBoardQuery? initialQuery;

  @override
  ConsumerState<IcuWorkspacePage> createState() => _IcuWorkspacePageState();
}

class _IcuWorkspacePageState extends ConsumerState<IcuWorkspacePage> {
  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _scheduleDeepLink();
  }

  void _scheduleDeepLink() {
    final IcuBoardQuery? query = widget.initialQuery;
    if (query == null || !query.hasRouteTargeting || _deepLinkHandled) {
      return;
    }
    _deepLinkHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_handleDeepLink(query));
    });
  }

  Future<void> _handleDeepLink(IcuBoardQuery query) async {
    final String? focusId = query.focusAdmissionId?.trim();
    if (focusId == null || focusId.isEmpty) {
      return;
    }

    final Result<IcuWorkspaceState> loadResult = await ref.read(
      icuWorkspaceControllerProvider.future,
    );
    if (!mounted || loadResult.isFailure) {
      return;
    }

    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = await controller.selectPatientByDisplayId(
      focusId,
    );
    if (!mounted || failure != null) {
      return;
    }
    final IcuWorkspaceState? state = readIcuWorkspaceState(ref);
    if (state?.selectedDetail == null) {
      return;
    }
    final IcuPatientSummary summary = state!.selectedDetail!.summary;
    final IcuWorkspaceSection section =
        IcuWorkspaceSectionX.fromQueryParam(query.section);
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final AccessRequirement writeRequirement =
        icuWriteRequirementForSection(section);

    // Panel-focused deep links open the mutation dialog directly (no empty
    // detail shell). Unauthorized write panels fall back to read-only detail.
    if (query.focusPanel != null) {
      await openIcuFocusedAction(
        context,
        ref,
        state,
        summary,
        query.focusPanel!,
        writeRequirement: writeRequirement,
        readRequirement: icuDetailReadRequirement(section),
      );
      return;
    }

    if (!icuDetailReadRequirement(section).isAllowed(policy)) {
      return;
    }

    await openIcuDetailDialog(
      context,
      ref,
      state,
      summary,
      writeRequirement,
      readRequirement: icuDetailReadRequirement(section),
      omitNextActionKind: icuBoardNextActionKind(summary, section),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Result<IcuWorkspaceState>> state = ref.watch(
      icuWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return AsyncStateScaffold<IcuWorkspaceState>(
      value: state,
      loadingTitle: l10n.icuLoadingBoardTitle,
      loadingBody: l10n.icuLoadingBoardBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(icuWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, IcuWorkspaceState data) {
        return _IcuWorkspaceContent(
          state: data,
          initialQuery: widget.initialQuery,
        );
      },
    );
  }
}

class _IcuWorkspaceContent extends ConsumerStatefulWidget {
  const _IcuWorkspaceContent({required this.state, this.initialQuery});

  final IcuWorkspaceState state;
  final IcuBoardQuery? initialQuery;

  @override
  ConsumerState<_IcuWorkspaceContent> createState() =>
      _IcuWorkspaceContentState();
}

class _IcuWorkspaceContentState extends ConsumerState<_IcuWorkspaceContent> {
  late final TextEditingController _searchController;
  late IcuWorkspaceSection _section;
  late final AppListTableColumnVisibilityController<IcuPatientSummary>
  _columnVisibilityController;
  AppSearchBarFilterValue _boardFilterValue = AppSearchBarFilterValue.empty;
  int? _followUpsNarrowedCount;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _section = IcuWorkspaceSectionX.fromQueryParam(widget.initialQuery?.section);
    _columnVisibilityController =
        AppListTableColumnVisibilityController<IcuPatientSummary>();

    final IcuBoardScope? scope = _section.toBoardScope();
    if (scope != null && scope != widget.state.query.scope) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(icuWorkspaceControllerProvider.notifier).applyScope(scope);
      });
    }
    if (_section.isBedBoard && widget.state.bedBoard.beds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(icuWorkspaceControllerProvider.notifier).loadBedBoard();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _IcuWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  void _updateUrlForSection(IcuWorkspaceSection section) {
    if (!mounted) return;
    final Map<String, String> params = icuWorkspaceSectionQueryParams(
      current: GoRouterState.of(context).uri.queryParameters,
      section: section,
      search: widget.state.query.search,
    );
    final String location = AppRoutes.icu.location(
      queryParameters: params,
    );
    syncWorkspaceLocation(context, location);
  }

  String _sectionLabel(AppLocalizations l10n, IcuWorkspaceSection section) {
    return switch (section) {
      IcuWorkspaceSection.active => l10n.icuActiveIcuLabel,
      IcuWorkspaceSection.critical => l10n.icuCriticalAlertsLabel,
      IcuWorkspaceSection.transfers => l10n.icuTransfersLabel,
      IcuWorkspaceSection.discharge => l10n.icuDischargeReadyLabel,
      IcuWorkspaceSection.ended => l10n.icuEndedStaysLabel,
      IcuWorkspaceSection.all => l10n.icuAllIcuLabel,
      IcuWorkspaceSection.beds => l10n.icuViewBedBoard,
      IcuWorkspaceSection.followUps => l10n.opdFollowUpsTitle,
    };
  }

  static IconData _sectionIcon(IcuWorkspaceSection section) {
    return switch (section) {
      IcuWorkspaceSection.active => Icons.bed_outlined,
      IcuWorkspaceSection.critical => Icons.priority_high_outlined,
      IcuWorkspaceSection.transfers => Icons.compare_arrows_outlined,
      IcuWorkspaceSection.discharge => Icons.fact_check_outlined,
      IcuWorkspaceSection.ended => Icons.output_outlined,
      IcuWorkspaceSection.all => Icons.inventory_2_outlined,
      IcuWorkspaceSection.beds => Icons.bed_outlined,
      IcuWorkspaceSection.followUps => Icons.phone_callback_outlined,
    };
  }

  /// Sibling-count model: dedicated unfiltered scope totals from [scopeCounts].
  /// Active patient tab with search/advanced filters uses the filtered
  /// membership length for that tab only.
  int? _sectionCount(
    IcuWorkspaceState state,
    IcuWorkspaceSection section, {
    required IcuWorkspaceSection activeSection,
    required AppSearchBarFilterValue filter,
    int? followUpsNarrowedCount,
  }) {
    if (section.isFollowUps) {
      return followUpsNarrowedCount;
    }
    final int? scopeTotal = _sectionScopeTotal(state, section);
    if (scopeTotal == null) {
      return null;
    }
    if (section != activeSection) {
      return scopeTotal;
    }
    if (section.isBedBoard) {
      // When Beds is active, badge tracks the same ward/status/search model as
      // the table (`visibleBeds`). Sibling badge stays the unfiltered catalog.
      if (section == activeSection) {
        return state.bedBoard.visibleBeds.length;
      }
      return scopeTotal;
    }
    final bool hasSearch = state.query.search.trim().isNotEmpty;
    if (!filter.isActive && !hasSearch) {
      return scopeTotal;
    }
    if (filter.isActive) {
      return filterIcuBoardItems(state.board.items, filter).length;
    }
    return state.board.totalItemCount ?? scopeTotal;
  }

  static int? _sectionScopeTotal(
    IcuWorkspaceState state,
    IcuWorkspaceSection section,
  ) {
    return switch (section) {
      IcuWorkspaceSection.active => state.activeCount,
      IcuWorkspaceSection.critical => state.criticalCount,
      IcuWorkspaceSection.transfers => state.transferCount,
      IcuWorkspaceSection.discharge => state.dischargeReadyCount,
      IcuWorkspaceSection.ended => state.endedCount,
      IcuWorkspaceSection.all => state.allCount,
      IcuWorkspaceSection.beds => state.bedBoard.beds.length,
      IcuWorkspaceSection.followUps => null,
    };
  }

  static AppTabCountTone _sectionCountTone(IcuWorkspaceSection section) {
    return switch (section) {
      IcuWorkspaceSection.critical => AppTabCountTone.danger,
      IcuWorkspaceSection.active ||
      IcuWorkspaceSection.transfers ||
      IcuWorkspaceSection.discharge ||
      IcuWorkspaceSection.followUps => AppTabCountTone.warning,
      IcuWorkspaceSection.ended ||
      IcuWorkspaceSection.all ||
      IcuWorkspaceSection.beds => AppTabCountTone.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final IcuWorkspaceState state = widget.state;
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<IcuWorkspaceSection> visibleSections = icuAllowedSections(
      accessPolicy,
    );
    if (visibleSections.isEmpty) {
      return const SizedBox.shrink();
    }
    if (!visibleSections.contains(_section)) {
      final IcuWorkspaceSection fallback =
          icuFallbackSection(accessPolicy) ?? visibleSections.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.contains(_section)) {
          return;
        }
        setState(() => _section = fallback);
        _updateUrlForSection(fallback);
        if (fallback.isFollowUps) {
          return;
        }
        final IcuBoardScope? scope = fallback.toBoardScope();
        if (scope != null) {
          controller.applyScope(scope);
        }
        if (fallback.isBedBoard && state.bedBoard.beds.isEmpty) {
          controller.loadBedBoard();
        }
      });
    }
    final bool isBedView = _section.isBedBoard;
    final bool isFollowUpsView = _section.isFollowUps;
    final AccessRequirement writeRequirement =
        icuWriteRequirementForSection(_section);
    final bool showNextAction = icuBoardShowsNextActionColumn(
      accessPolicy,
      _section,
    );
    final bool canManageBeds = canManageIcuBedBoard(accessPolicy);

    return ResponsivePage(
      padding: ResponsiveSpacing.workspacePagePaddingFor(
        spacing: Theme.of(context).spacing,
      ),
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final IcuWorkspaceSection section in visibleSections)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: section.isFollowUps
                        ? (_followUpsNarrowedCount ??
                            ref.watch(
                              followUpTabCountProvider(
                                const FollowUpWorklistScope(
                                  encounterType: 'ICU',
                                ),
                              ),
                            ))
                        : _sectionCount(
                            state,
                            section,
                            activeSection: _section,
                            filter: _boardFilterValue,
                            followUpsNarrowedCount: _followUpsNarrowedCount,
                          ),
                    countTone: _sectionCountTone(section),
                  ),
              ],
              selectedId: _section.name,
              primaryAction: isBedView && canManageBeds
                  ? AppTabToolbarPrimary(
                      label: l10n.ipdBedBoardManageBedsAction,
                      icon: Icons.open_in_new,
                      tooltip: l10n.ipdBedBoardManageBedsAction,
                      semanticLabel: l10n.ipdBedBoardManageBedsAction,
                      onPressed: () => context.go(AppRoutes.roomsBeds.path),
                    )
                  : null,
              onTabTapped: (String tabId) {
                for (final IcuWorkspaceSection section in visibleSections) {
                  if (section.name == tabId) {
                    setState(() => _section = section);
                    _updateUrlForSection(section);
                    if (section.isFollowUps) {
                      break;
                    }
                    final IcuBoardScope? scope = section.toBoardScope();
                    if (scope != null) {
                      controller.applyScope(scope);
                    }
                    if (section.isBedBoard && state.bedBoard.beds.isEmpty) {
                      controller.loadBedBoard();
                    }
                    break;
                  }
                }
              },
            ),
            SizedBox(height: theme.spacing.sm),
            Expanded(
              child: isFollowUpsView
                  ? FollowUpWorklistPanel(
                      scope: const FollowUpWorklistScope(encounterType: 'ICU'),
                      storageKeyPrefix: 'icu_follow_ups',
                      readRequirement: IcuFollowUpsAtomPermissions.tab,
                      writeRequirement: IcuFollowUpsAtomPermissions.write,
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
                      canExport: canExportIcuWorkspace(accessPolicy),
                      enablePrint: true,
                      canPrint: canPrintIcuWorkspace(accessPolicy),
                      printLabel: l10n.commonPrintActionLabel,
                      onPrint: (List<ReceptionFollowUpEntry> entries) =>
                          _printIcuFollowUpsList(
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
                  : isBedView
                  ? IcuBedBoardPanel(state: state)
                  : IcuBoardPanel(
                      state: state,
                      section: _section,
                      writeRequirement: writeRequirement,
                      readRequirement: icuDetailReadRequirement(_section),
                      showNextAction: showNextAction,
                      searchController: _searchController,
                      columnVisibilityController: _columnVisibilityController,
                      filterValue: _boardFilterValue,
                      onFilterChanged: (AppSearchBarFilterValue value) {
                        setState(() => _boardFilterValue = value);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds ICU in-desk query params for a tab change.
///
/// Preserves existing `id` / `panel` (and other) keys while syncing `section`
/// and `search` (convention gap #9 / screens.mdc URL sync).
@visibleForTesting
Map<String, String> icuWorkspaceSectionQueryParams({
  required Map<String, String> current,
  required IcuWorkspaceSection section,
  required String search,
}) {
  final Map<String, String> params = <String, String>{...current};
  final String tab = section.queryValue;
  if (tab == 'active') {
    params.remove('section');
  } else {
    params['section'] = tab;
  }
  final String trimmedSearch = search.trim();
  if (trimmedSearch.isNotEmpty) {
    params['search'] = trimmedSearch;
    params.remove('q');
  } else {
    params.remove('search');
    params.remove('q');
  }
  return params;
}

Future<void> _printIcuFollowUpsList(
  BuildContext context,
  WidgetRef ref, {
  required List<ReceptionFollowUpEntry> entries,
  required AppLocalizations l10n,
}) async {
  final Locale locale = Localizations.localeOf(context);
  final List<IcuWorkspacePrintColumn> printColumns =
      <IcuWorkspacePrintColumn>[
        IcuWorkspacePrintColumn(id: 'patient', label: l10n.opdPatientNameLabel),
        IcuWorkspacePrintColumn(
          id: 'phone',
          label: l10n.patientsPhoneIdentifierColumnLabel,
        ),
        IcuWorkspacePrintColumn(id: 'status', label: l10n.receptionStatusLabel),
        IcuWorkspacePrintColumn(id: 'date', label: l10n.opdFollowUpDateLabel),
        IcuWorkspacePrintColumn(id: 'time', label: l10n.opdFollowUpTimeLabel),
        IcuWorkspacePrintColumn(id: 'patient_id', label: l10n.opdPatientIdLabel),
        IcuWorkspacePrintColumn(id: 'email', label: l10n.patientsEmailLabel),
        IcuWorkspacePrintColumn(id: 'notes', label: l10n.opdNotesLabel),
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
  await printIcuWorkspaceList(
    ref: ref,
    context: context,
    title: l10n.receptionSectionFollowUps,
    columns: printColumns,
    rows: printRows,
    emptyText: l10n.receptionFollowUpsEmptyTitle,
  );
}
