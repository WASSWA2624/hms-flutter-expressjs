import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/presentation/controllers/theater_workspace_controller.dart';
import 'package:hosspi_hms/features/theater/presentation/theater_access.dart';
import 'package:hosspi_hms/features/theater/presentation/theater_next_action.dart';
import 'package:hosspi_hms/features/theater/presentation/widgets/theater_schedule_case_form.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

part '../widgets/theater_workspace_widgets.dart';

class TheaterWorkspacePage extends ConsumerStatefulWidget {
  const TheaterWorkspacePage({super.key, this.initialQuery});

  final TheaterBoardQuery? initialQuery;

  @override
  ConsumerState<TheaterWorkspacePage> createState() =>
      _TheaterWorkspacePageState();
}

class _TheaterWorkspacePageState extends ConsumerState<TheaterWorkspacePage> {
  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _scheduleDeepLink();
  }

  void _scheduleDeepLink() {
    final TheaterBoardQuery? query = widget.initialQuery;
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

  Future<void> _handleDeepLink(TheaterBoardQuery query) async {
    final TheaterWorkspaceController controller = ref.read(
      theaterWorkspaceControllerProvider.notifier,
    );
    await ref.read(theaterWorkspaceControllerProvider.future);
    if (!mounted) {
      return;
    }
    if (query.focusCaseId == null && query.search.isNotEmpty) {
      await controller.applyBoardQuery(query);
    }
    final String? focusId = query.focusCaseId?.trim();
    if (focusId == null || focusId.isEmpty) {
      return;
    }
    final AppFailure? failure = await controller.selectCaseByDisplayId(focusId);
    if (!mounted || failure != null) {
      return;
    }
    final TheaterWorkspaceState? state = _readTheaterState(ref);
    if (state?.selectedCase == null) {
      return;
    }
    final bool canWrite = canWriteTheaterClinical(
      ref.read(appAccessPolicyProvider),
    );
    // Panel-focused deep links open the mutation dialog directly (no empty
    // detail shell). Bare case links open detail with the stage next-action
    // omitted so it is not duplicated inside Quick Actions.
    if (query.focusPanel != null && canWrite) {
      await _openTheaterFocusedAction(
        context,
        ref,
        state!.selectedCase!,
        query.focusPanel!,
      );
      return;
    }
    await _openTheaterCaseDialog(
      context,
      ref,
      state!,
      state.selectedCase!,
      canWrite,
      omitNextActionKind: theaterResolveNextActionKind(state.selectedCase!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<TheaterWorkspaceState>> workspace = ref.watch(
      theaterWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<TheaterWorkspaceState>(
      value: workspace,
      appBarTitle: l10n.theaterTitle,
      loadingTitle: l10n.theaterLoadingTitle,
      loadingBody: l10n.theaterLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(theaterWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, TheaterWorkspaceState state) {
        return _TheaterWorkspaceContent(
          state: state,
          initialQuery: widget.initialQuery,
        );
      },
    );
  }
}

TheaterWorkspaceState? _readTheaterState(WidgetRef ref) {
  return ref
      .read(theaterWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (TheaterWorkspaceState value) => value,
        failure: (_) => null,
      );
}

class _TheaterWorkspaceContent extends ConsumerStatefulWidget {
  const _TheaterWorkspaceContent({required this.state, this.initialQuery});

  final TheaterWorkspaceState state;
  final TheaterBoardQuery? initialQuery;

  @override
  ConsumerState<_TheaterWorkspaceContent> createState() =>
      _TheaterWorkspaceContentState();
}

class _TheaterWorkspaceContentState
    extends ConsumerState<_TheaterWorkspaceContent> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<TheaterCase>
  _tableColumnController;
  late TheaterSection _section;
  bool _scheduleDialogHandled = false;

  @override
  void initState() {
    super.initState();
    _section = TheaterSectionX.fromQuery(widget.initialQuery?.section);
    _searchController = TextEditingController(text: widget.state.query.search);
    _tableColumnController =
        AppListTableColumnVisibilityController<TheaterCase>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_section != TheaterSection.all && !_section.isFollowUps) {
        _applyTabFilter(_section);
      }
      unawaited(_maybeOpenScheduleDialog());
    });
  }

  Future<void> _maybeOpenScheduleDialog() async {
    if (_scheduleDialogHandled) {
      return;
    }
    final TheaterBoardQuery? query = widget.initialQuery;
    if (query == null || !query.shouldOpenScheduleDialog) {
      return;
    }
    _scheduleDialogHandled = true;
    if (!mounted) {
      return;
    }
    final AppAccessPolicy accessPolicy = ref.read(appAccessPolicyProvider);
    if (!canScheduleTheaterCase(accessPolicy)) {
      return;
    }
    await _showScheduleCaseDialog(
      context,
      ref,
      initialPatientId: query.initialPatientId,
      initialEncounterId: query.initialEncounterId,
      initialEmergencyCaseId: query.initialEmergencyCaseId,
    );
  }

  @override
  void didUpdateWidget(covariant _TheaterWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String search = widget.state.query.search;
    if (_searchController.text != search) {
      _searchController.text = search;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableColumnController.dispose();
    super.dispose();
  }

  void _updateUrlForSection(TheaterSection section) {
    if (!mounted) {
      return;
    }
    final String tab = section.queryValue;
    final String location = AppRoutes.theater.location(
      queryParameters: <String, String>{if (tab != 'all') 'section': tab},
    );
    GoRouter.of(context).replace<void>(location);
  }

  void _applyTabFilter(TheaterSection section) {
    final TheaterWorkspaceController controller = ref.read(
      theaterWorkspaceControllerProvider.notifier,
    );
    switch (section) {
      case TheaterSection.scheduled:
        unawaited(controller.applyStatus('SCHEDULED', clearStage: true));
      case TheaterSection.inTheater:
        unawaited(controller.applyStatus('IN_PROGRESS', clearStage: true));
      case TheaterSection.recovery:
        unawaited(controller.applyStage('POST_OP', clearStatus: true));
      case TheaterSection.all:
        unawaited(controller.clearFilters());
      case TheaterSection.followUps:
        break;
    }
  }

  static IconData _sectionIcon(TheaterSection section) {
    return switch (section) {
      TheaterSection.scheduled => Icons.event_available_outlined,
      TheaterSection.inTheater => Icons.meeting_room_outlined,
      TheaterSection.recovery => Icons.monitor_heart_outlined,
      TheaterSection.all => Icons.inventory_2_outlined,
      TheaterSection.followUps => Icons.phone_callback_outlined,
    };
  }

  String _sectionLabel(AppLocalizations l10n, TheaterSection section) {
    return switch (section) {
      TheaterSection.scheduled => l10n.theaterScheduledSummaryLabel,
      TheaterSection.inTheater => l10n.theaterInTheaterSummaryLabel,
      TheaterSection.recovery => l10n.theaterRecoverySectionLabel,
      TheaterSection.all => l10n.theaterAllCasesSummaryLabel,
      TheaterSection.followUps => l10n.opdFollowUpsTitle,
    };
  }

  int? _sectionCount(TheaterWorkspaceState state, TheaterSection section) {
    if (section.isFollowUps) {
      return null;
    }
    return switch (section) {
      TheaterSection.scheduled => state.scheduledCount,
      TheaterSection.inTheater => state.inTheaterCount,
      TheaterSection.recovery => state.recoveryCount,
      TheaterSection.all => _pageTotal(state.cases),
      TheaterSection.followUps => null,
    };
  }

  static AppTabCountTone _sectionCountTone(TheaterSection section) {
    return switch (section) {
      TheaterSection.scheduled ||
      TheaterSection.inTheater ||
      TheaterSection.recovery => AppTabCountTone.warning,
      TheaterSection.all || TheaterSection.followUps => AppTabCountTone.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final TheaterWorkspaceState state = widget.state;
    final controller = ref.read(theaterWorkspaceControllerProvider.notifier);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite =
        theaterWriteRequirementForSection(_section).isAllowed(accessPolicy);
    final bool showNextAction = theaterBoardShowsNextActionColumn(
      accessPolicy,
      _section,
    );
    final List<TheaterSection> visibleSections = theaterAllowedBoardSections(
      accessPolicy,
    );
    final AppFailure? lastFailure = state.lastFailure;

    if (visibleSections.isEmpty) {
      return const SizedBox.shrink();
    }
    if (!visibleSections.contains(_section)) {
      final TheaterSection fallback =
          theaterFallbackSection(accessPolicy) ?? visibleSections.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visibleSections.contains(_section)) {
          return;
        }
        setState(() => _section = fallback);
        _updateUrlForSection(fallback);
        if (!fallback.isFollowUps) {
          _applyTabFilter(fallback);
        }
      });
    }

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final TheaterSection section in visibleSections)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: section == TheaterSection.followUps
                        ? ref.watch(
                            followUpTabCountProvider(
                              const FollowUpWorklistScope(
                                encounterType: 'THEATRE',
                              ),
                            ),
                          )
                        : _sectionCount(state, section),
                    countTone: _sectionCountTone(section),
                  ),
              ],
              selectedId: _section.name,
              onTabTapped: (String tabId) {
                final TheaterSection section = visibleSections.firstWhere(
                  (TheaterSection s) => s.name == tabId,
                  orElse: () => visibleSections.first,
                );
                setState(() => _section = section);
                _updateUrlForSection(section);
                if (!section.isFollowUps) {
                  _applyTabFilter(section);
                }
              },
            ),
            SizedBox(height: theme.spacing.sm),
            if (lastFailure != null && !_section.isFollowUps) ...<Widget>[
              AppFailureStateView(
                failure: lastFailure,
                onRetry: controller.refresh,
              ),
              SizedBox(height: theme.spacing.md),
            ],
            if (_section.isFollowUps)
              const FollowUpWorklistPanel(
                scope: FollowUpWorklistScope(encounterType: 'THEATRE'),
                storageKeyPrefix: 'theater_follow_ups',
                readRequirement: TheaterFollowUpsAtomPermissions.tab,
                writeRequirement: TheaterFollowUpsAtomPermissions.write,
              )
            else
              _TheaterCaseBoard(
                state: state,
                section: _section,
                canWrite: canWrite,
                showNextAction: showNextAction,
                searchController: _searchController,
                columnVisibilityController: _tableColumnController,
                onPageChanged: controller.changePage,
                initialQuery: widget.initialQuery,
              ),
          ],
        ),
      ),
    );
  }
}

class _TheaterCaseBoard extends ConsumerWidget {
  const _TheaterCaseBoard({
    required this.state,
    required this.section,
    required this.canWrite,
    required this.showNextAction,
    required this.searchController,
    required this.columnVisibilityController,
    required this.onPageChanged,
    this.initialQuery,
  });

  final TheaterWorkspaceState state;
  final TheaterSection section;
  final bool canWrite;
  final bool showNextAction;
  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<TheaterCase>
  columnVisibilityController;
  final ValueChanged<AppPageRequest> onPageChanged;
  final TheaterBoardQuery? initialQuery;

  /// Schedule case lives after Export in the search bar (not the tab toolbar).
  List<AppSearchBarAction> _scheduleCaseSearchActions(
    BuildContext context,
    WidgetRef ref,
  ) {
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (!canScheduleTheaterCase(policy)) {
      return const <AppSearchBarAction>[];
    }
    final String label = context.l10n.theaterScheduleCaseAction;
    final bool enabled = !state.isMutating;
    return <AppSearchBarAction>[
      AppSearchBarAction(
        icon: Icons.add,
        label: label,
        tooltip: label,
        enabled: enabled,
        onPressed: enabled
            ? () => _showScheduleCaseDialog(
                context,
                ref,
                initialPatientId: initialQuery?.initialPatientId,
                initialEncounterId: initialQuery?.initialEncounterId,
                initialEmergencyCaseId: initialQuery?.initialEmergencyCaseId,
              )
            : null,
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TheaterWorkspaceController controller = ref.read(
      theaterWorkspaceControllerProvider.notifier,
    );

    return AppListTable<TheaterCase>(
      page: state.cases,
      isLoading: state.isRefreshing,
      columnVisibilityController: columnVisibilityController,
      columnVisibilityStorageKey: 'theater_${section.name}',
      columnWidthStorageKey: 'theater_cw_${section.name}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.theaterTableSettingsTitle,
      search: AppListTableSearch<TheaterCase>(
        controller: searchController,
        semanticLabel: l10n.theaterSearchLabel,
        hintText: l10n.theaterSearchHint,
        clearLabel: l10n.theaterClearFiltersAction,
        matcher: (TheaterCase item, String query) =>
            theaterTableSearchMatcher(context, item, query),
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.theaterFiltersLabel,
        advancedFilterTitle: l10n.theaterAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.theaterClearFiltersAction,
        dateFilterLabel: l10n.theaterScheduleDateFilterLabel,
        dateFromLabel: l10n.theaterScheduleDateFilterLabel,
        dateToLabel: l10n.opdDateToLabel,
        datePickerButtonLabel: l10n.theaterPickScheduleDateAction,
        invalidDateMessage: l10n.appDateInvalidMessage,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        currentDate: DateTime.now(),
        allFieldsLabel: l10n.opdAllFieldsFilterLabel,
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _theaterRoomFilterKey,
            label: l10n.theaterRoomIdLabel,
            icon: Icons.meeting_room_outlined,
            textInputAction: TextInputAction.next,
          ),
          AppSearchBarTextFilter(
            key: _theaterSurgeonFilterKey,
            label: l10n.theaterSurgeonIdLabel,
            icon: Icons.medical_services_outlined,
            textInputAction: TextInputAction.next,
          ),
          AppSearchBarTextFilter(
            key: _theaterAnesthetistFilterKey,
            label: l10n.theaterAnesthetistIdLabel,
            icon: Icons.masks_outlined,
            textInputAction: TextInputAction.done,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          if (section == TheaterSection.all) ...<AppSearchBarFilterGroup>[
            AppSearchBarFilterGroup(
              key: _theaterStatusFilterKey,
              label: l10n.theaterStatusFilterLabel,
              allLabel: l10n.opdAllFieldsFilterLabel,
              choices: _theaterStatusFilterChoices(l10n),
            ),
            AppSearchBarFilterGroup(
              key: _theaterStageFilterKey,
              label: l10n.theaterStageFilterLabel,
              allLabel: l10n.opdAllFieldsFilterLabel,
              choices: _theaterStageFilterChoices(l10n),
            ),
          ],
        ],
        filterValue: _theaterFilterValue(state.query, section),
        hasActiveFilters: _hasTheaterFilters(state.query, section),
        // Filters → Settings → Export → Schedule case.
        trailingActions: _scheduleCaseSearchActions(context, ref),
        onFilterChanged: (AppSearchBarFilterValue value) async {
          final String? nextStatus = value.option(_theaterStatusFilterKey);
          final String? nextStage = value.option(_theaterStageFilterKey);
          final DateTime? nextDate = value.dateFrom;
          final String? nextRoomId = value.text(_theaterRoomFilterKey);
          final String? nextSurgeonUserId = value.text(
            _theaterSurgeonFilterKey,
          );
          final String? nextAnesthetistUserId = value.text(
            _theaterAnesthetistFilterKey,
          );
          AppFailure? failure;
          // Tabs own status/stage on Scheduled / In theater / Recovery.
          if (section == TheaterSection.all) {
            if (nextStatus != state.query.status) {
              failure = await controller.applyStatus(nextStatus);
            }
            if (nextStage != state.query.stage) {
              failure ??= await controller.applyStage(nextStage);
            }
          }
          if (!_isSameTheaterFilterDate(nextDate, state.query.scheduledDate)) {
            failure ??= await controller.applyScheduledDate(nextDate);
          }
          if (nextRoomId != state.query.roomId ||
              nextSurgeonUserId != state.query.surgeonUserId ||
              nextAnesthetistUserId != state.query.anesthetistUserId) {
            failure ??= await controller.applyResourceFilters(
              roomId: nextRoomId,
              surgeonUserId: nextSurgeonUserId,
              anesthetistUserId: nextAnesthetistUserId,
            );
          }
          if (context.mounted) {
            _showFailureIfNeeded(context, failure);
          }
        },
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemKeyBuilder: (TheaterCase item) => ValueKey<String>(item.id),
      onRowSelected: (TheaterCase item) {
        unawaited(
          _openTheaterCaseDialog(
            context,
            ref,
            state,
            item,
            canWrite,
            omitNextActionKind: theaterResolveNextActionKind(item),
          ),
        );
      },
      previousPageLabel: l10n.opdPreviousPageLabel,
      nextPageLabel: l10n.opdNextPageLabel,
      pageLabelBuilder: (AppPage<TheaterCase> page) {
        return l10n.theaterPageLabel(
          page.firstItemNumber,
          page.lastItemNumber,
          page.totalItemCount ?? page.lastItemNumber,
        );
      },
      onPageChanged: onPageChanged,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.theaterNoCasesTitle,
        body: l10n.theaterNoCasesBody,
      ),
      columns: defaultTheaterColumnsForSection(
        context,
        section,
        showNextAction: showNextAction,
      ),
      columnChoices: theaterColumnChoicesForSection(
        context,
        section,
        showNextAction: showNextAction,
      ),
      mobileItemBuilder: (BuildContext context, TheaterCase item) {
        final AppLocalizations l10n = context.l10n;
        return AppListTableMobileItem(
          title: item.patientDisplayName ?? l10n.profileUnknownValue,
          caption: _joinDisplay(<String?>[
            item.patientDisplayId,
            item.encounterDisplayId,
          ]),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: item.procedureName ?? l10n.profileUnknownValue,
            ),
            AppListTableMobileMeta(
              label: _formatDateTime(context, item.scheduledAt),
              icon: AppActionIcons.calendar,
            ),
            AppListTableMobileMeta(
              label: _caseStatusLabel(l10n, item.status),
            ),
          ],
          trailing: showNextAction
              // Bounded width lets FittedBox scale long next-action labels
              // down instead of overflowing narrow mobile rows.
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 148),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: _TheaterNextActionButton(theaterCase: item),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _TheaterCaseDetail extends ConsumerWidget {
  const _TheaterCaseDetail({
    required this.theaterCase,
    required this.isLoading,
    required this.isMutating,
    required this.canWrite,
    this.omitNextActionKind,
  });

  final TheaterCase? theaterCase;
  final bool isLoading;
  final bool isMutating;
  final bool canWrite;
  final TheaterNextActionKind? omitNextActionKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TheaterCase? selected = theaterCase;
    if (selected == null) {
      final AppLocalizations l10n = context.l10n;
      return AppCollapsibleSection(
        title: l10n.theaterCaseDetailTitle,
        child: AppStateView(
          title: l10n.theaterNoCaseSelectedTitle,
          body: l10n.theaterNoCaseSelectedBody,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (isLoading) const LinearProgressIndicator(minHeight: 2),
        _TheaterCaseDetailBody(
          theaterCase: selected,
          canWrite: canWrite,
          isMutating: isMutating,
          omitNextActionKind: omitNextActionKind,
        ),
      ],
    );
  }
}

Future<void> _openTheaterCaseDialog(
  BuildContext context,
  WidgetRef ref,
  TheaterWorkspaceState fallbackState,
  TheaterCase theaterCase,
  bool canWrite, {
  TheaterNextActionKind? omitNextActionKind,
}) async {
  final TheaterWorkspaceController controller = ref.read(
    theaterWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectCase(theaterCase);
  if (context.mounted && failure != null) {
    _showMutationResult(context, failure);
  }
  if (failure != null || !context.mounted) {
    return;
  }

  final TheaterWorkspaceState state = _readTheaterState(ref) ?? fallbackState;
  final TheaterCase selected = state.selectedCase ?? theaterCase;

  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.theaterCaseDetailTitle),
      icon: const Icon(Icons.local_activity_outlined),
      scrollable: true,
      maxWidth: 980,
      content: Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final TheaterWorkspaceState current =
              _readTheaterState(ref) ?? state;
          return _TheaterCaseDetail(
            theaterCase: current.selectedCase ?? selected,
            isLoading: current.isRefreshingDetail,
            isMutating: current.isMutating,
            canWrite: canWrite,
            omitNextActionKind: omitNextActionKind,
          );
        },
      ),
    ),
  );
}

/// Panel deep links open the mutation dialog directly (no empty detail shell).
Future<void> _openTheaterFocusedAction(
  BuildContext context,
  WidgetRef ref,
  TheaterCase theaterCase,
  TheaterDetailPanel panel,
) async {
  switch (panel) {
    case TheaterDetailPanel.checklist:
      await _showChecklistDialog(context, ref);
    case TheaterDetailPanel.anesthesia:
      await _showAnesthesiaDialog(context, ref, theaterCase);
    case TheaterDetailPanel.postop:
      await _showPostOpDialog(context, ref, theaterCase);
    case TheaterDetailPanel.resources:
      await _showAssignResourceDialog(context, ref);
  }
}

class _TheaterCaseDetailBody extends StatelessWidget {
  const _TheaterCaseDetailBody({
    required this.theaterCase,
    required this.canWrite,
    required this.isMutating,
    this.omitNextActionKind,
  });

  final TheaterCase theaterCase;
  final bool canWrite;
  final bool isMutating;
  final TheaterNextActionKind? omitNextActionKind;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool hasSourceContext = _sourceContextLabel(l10n, theaterCase) != null;
    final List<Widget> detailSections = <Widget>[
      if (hasSourceContext)
        AppCollapsibleSection(
          title: l10n.theaterSourceContextLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _sourceContextLabel(l10n, theaterCase)!,
                style: theme.textTheme.bodyMedium,
              ),
              if (theaterCase.procedureName != null)
                _DetailLine(
                  label: l10n.theaterProcedureColumnLabel,
                  value: theaterCase.procedureName,
                ),
              if (theaterCase.admissionDisplayId != null)
                AppButton.tertiary(
                  label: l10n.theaterOpenInIpdAction,
                  leadingIcon: Icons.local_hospital_outlined,
                  onPressed: () => _openIpdWorkspace(
                    context,
                    theaterCase.admissionDisplayId!,
                  ),
                ),
              if (theaterCase.emergencyCaseDisplayId != null)
                AppButton.tertiary(
                  label: l10n.theaterOpenInEmergencyAction,
                  leadingIcon: Icons.emergency_outlined,
                  onPressed: () => _openEmergencyWorkspace(
                    context,
                    theaterCase.emergencyCaseDisplayId!,
                  ),
                ),
            ],
          ),
        ),
      AppCollapsibleSection(
        title: l10n.theaterTeamTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _DetailLine(
              label: l10n.theaterSurgeonLabel,
              value:
                  theaterCase.surgeonDisplayName ??
                  theaterCase.surgeonUserDisplayId,
            ),
            _DetailLine(
              label: l10n.theaterAnesthetistLabel,
              value:
                  theaterCase.anesthetistDisplayName ??
                  theaterCase.anesthetistUserDisplayId,
            ),
            _DetailLine(
              label: l10n.theaterStageLabel,
              value: _stageLabel(l10n, theaterCase.workflowStage),
            ),
            _DetailLine(
              label: l10n.theaterStageNotesLabel,
              value: theaterCase.stageNotes,
            ),
          ],
        ),
      ),
      _ChecklistSection(theaterCase: theaterCase),
      _RecordsSection(theaterCase: theaterCase),
      _ResourceSection(theaterCase: theaterCase),
      _TimelineSection(theaterCase: theaterCase),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPatientDetails(
          patientName:
              theaterCase.patientDisplayName ?? l10n.profileUnknownValue,
          patientNumber:
              theaterCase.patientDisplayId ?? l10n.profileUnknownValue,
          showAvatar: false,
          status: AppWorkspaceStatus(
            label: _caseStatusLabel(l10n, theaterCase.status),
            tone: _statusTone(theaterCase.status),
          ),
          expandedFields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.theaterEncounterLabel,
              value: theaterCase.encounterDisplayId ?? '',
              icon: Icons.assignment_outlined,
              copyable: true,
              copyTooltip: l10n.opdCopyEncounterIdAction,
              copiedMessage: l10n.opdEncounterIdCopiedMessage,
            ),
            AppWorkspacePatientContextField(
              label: l10n.theaterScheduledAtLabel,
              value: _formatDateTime(context, theaterCase.scheduledAt),
              icon: Icons.schedule,
            ),
            AppWorkspacePatientContextField(
              label: l10n.theaterRoomLabel,
              value: _roomLabel(context, theaterCase),
              icon: Icons.meeting_room_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.theaterReadinessLabel,
              value: _readinessLabel(context, theaterCase),
              icon: Icons.fact_check_outlined,
              tone: theaterCase.isReady
                  ? AppWorkspaceStatusTone.success
                  : AppWorkspaceStatusTone.warning,
            ),
          ],
        ),
        if (canWrite) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          _TheaterActionBar(
            theaterCase: theaterCase,
            isMutating: isMutating,
            omitNextActionKind: omitNextActionKind,
          ),
        ],
        for (var index = 0; index < detailSections.length; index += 1) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          detailSections[index],
        ],
      ],
    );
  }
}

class _TheaterActionBar extends ConsumerWidget {
  const _TheaterActionBar({
    required this.theaterCase,
    required this.isMutating,
    this.omitNextActionKind,
  });

  final TheaterCase theaterCase;
  final bool isMutating;
  final TheaterNextActionKind? omitNextActionKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TheaterNextActionKind? omit = omitNextActionKind;
    final bool isTerminal =
        theaterCase.normalizedStatus == 'CANCELLED' ||
        theaterCase.normalizedStatus == 'COMPLETED';

    if (isTerminal) {
      return const SizedBox.shrink();
    }

    return AppQuickActions(
      title: l10n.patientsQuickActionsTitle,
      presentation: AppQuickActionsPresentation.detailPanel,
      actions: <AppActionItem>[
        AppActionItem(
          label: l10n.theaterRescheduleAction,
          leadingIcon: Icons.edit_calendar_outlined,
          enabled: !isMutating,
          onPressed: () => _showRescheduleDialog(context, ref, theaterCase),
        ),
        if (omit != TheaterNextActionKind.startCase)
          AppActionItem(
            label: l10n.theaterUpdateStageAction,
            leadingIcon: Icons.alt_route_outlined,
            enabled: !isMutating,
            onPressed: () => _showStageDialog(context, ref, theaterCase),
          ),
        AppActionItem(
          label: l10n.theaterAssignResourceAction,
          leadingIcon: Icons.meeting_room_outlined,
          enabled: !isMutating,
          onPressed: () => _showAssignResourceDialog(context, ref),
        ),
        if (omit != TheaterNextActionKind.updateReadiness)
          AppActionItem(
            label: l10n.theaterUpdateReadinessAction,
            leadingIcon: Icons.fact_check_outlined,
            enabled: !isMutating,
            onPressed: () => _showChecklistDialog(context, ref),
          ),
        if (omit != TheaterNextActionKind.anesthesia)
          AppActionItem(
            label: l10n.theaterAnesthesiaAction,
            leadingIcon: Icons.monitor_heart_outlined,
            enabled: !isMutating,
            onPressed: () =>
                _showAnesthesiaDialog(context, ref, theaterCase),
          ),
        if (omit != TheaterNextActionKind.postOp)
          AppActionItem(
            label: l10n.theaterPostOpAction,
            leadingIcon: Icons.note_add_outlined,
            enabled: !isMutating,
            onPressed: () => _showPostOpDialog(context, ref, theaterCase),
          ),
        if (omit != TheaterNextActionKind.handover)
          AppActionItem(
            label: l10n.theaterHandoverAction,
            leadingIcon: Icons.output_outlined,
            enabled: !isMutating,
            onPressed: () => _showHandoverDialog(context, ref),
          ),
        AppActionItem(
          label: l10n.theaterFinalizeAction,
          leadingIcon: Icons.verified_outlined,
          enabled: !isMutating,
          onPressed: () => _showFinalizeDialog(context, ref),
        ),
        AppActionItem(
          label: l10n.theaterCancelCaseAction,
          leadingIcon: Icons.cancel_outlined,
          enabled: !isMutating,
          variant: AppActionVariant.tertiary,
          onPressed: () => _showCancelDialog(context, ref),
        ),
      ],
    );
  }
}

class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<TheaterChecklistItem> items = theaterCase.checklistItems;

    return AppCollapsibleSection(
      title: l10n.theaterChecklistTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.isEmpty
            ? <Widget>[AppMutedText(l10n.theaterNoChecklistItemsLabel)]
            : <Widget>[
                for (final TheaterChecklistItem item in items)
                  _StatusLine(
                    icon: item.isChecked
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    tone: item.isChecked
                        ? AppWorkspaceStatusTone.success
                        : AppWorkspaceStatusTone.warning,
                    title:
                        item.itemLabel ??
                        item.itemCode ??
                        l10n.profileUnknownValue,
                    subtitle: _joinDisplay(<String?>[
                      _stageLabel(l10n, item.phase),
                      _formatDateTimeOrNull(context, item.checkedAt),
                      item.notes,
                    ]),
                  ),
              ],
      ),
    );
  }
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppCollapsibleSection(
      title: l10n.theaterRecordsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DetailLine(
            label: l10n.theaterAnesthesiaStatusLabel,
            value: _recordStatusLabel(l10n, theaterCase.anesthesiaStatus),
          ),
          _DetailLine(
            label: l10n.theaterPostOpStatusLabel,
            value: _recordStatusLabel(l10n, theaterCase.postOpStatus),
          ),
          _DetailLine(
            label: l10n.theaterAnesthesiaNotesLabel,
            value: theaterCase.latestAnesthesiaRecord?.notes,
          ),
          _DetailLine(
            label: l10n.theaterPostOpNoteLabel,
            value: theaterCase.latestPostOpNote?.notes,
          ),
          if (theaterCase.anesthesiaObservations.isEmpty)
            AppMutedText(l10n.theaterNoObservationsLabel)
          else
            for (final TheaterAnesthesiaObservation observation
                in theaterCase.anesthesiaObservations.take(6))
              _StatusLine(
                icon: Icons.monitor_heart_outlined,
                tone: AppWorkspaceStatusTone.info,
                title:
                    _joinDisplay(<String?>[
                      observation.metricKey,
                      observation.metricValue,
                      observation.unit,
                    ]).ifEmpty(
                      observation.observationType ?? l10n.profileUnknownValue,
                    ),
                subtitle: _joinDisplay(<String?>[
                  _formatDateTimeOrNull(context, observation.observedAt),
                  observation.notes,
                ]),
              ),
        ],
      ),
    );
  }
}

class _ResourceSection extends StatelessWidget {
  const _ResourceSection({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<TheaterResourceAllocation> allocations =
        theaterCase.resourceAllocations;

    return AppCollapsibleSection(
      title: l10n.theaterResourcesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: allocations.isEmpty
            ? <Widget>[AppMutedText(l10n.theaterNoResourcesLabel)]
            : <Widget>[
                for (final TheaterResourceAllocation allocation in allocations)
                  _StatusLine(
                    icon: allocation.isActive
                        ? Icons.link_outlined
                        : Icons.link_off_outlined,
                    tone: allocation.isActive
                        ? AppWorkspaceStatusTone.success
                        : AppWorkspaceStatusTone.neutral,
                    title: _joinDisplay(<String?>[
                      _apiLabel(allocation.resourceType),
                      allocation.resourceLabel,
                      allocation.resourceDisplayId,
                    ]),
                    subtitle: _joinDisplay(<String?>[
                      _formatDateTimeOrNull(context, allocation.assignedAt),
                      allocation.notes,
                    ]),
                  ),
              ],
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppCollapsibleSection(
      title: l10n.theaterTimelineTitle,
      child: AppTimeline(
        emptyTitle: l10n.theaterNoTimelineLabel,
        emptyBody: '',
        maxItems: 8,
        items: <AppTimelineItem>[
          for (final TheaterTimelineItem item in theaterCase.timeline)
            AppTimelineItem(
              title: item.label,
              occurredAt: item.occurredAt,
              icon: Icons.history_outlined,
            ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              value == null || value!.trim().isEmpty
                  ? context.l10n.profileUnknownValue
                  : value!,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final AppWorkspaceStatusTone tone;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: _emptyTheaterStatusLabel,
              tone: tone,
              icon: icon,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.bodyMedium),
                if (subtitle.trim().isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        if (subtitle.trim().isNotEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

Future<void> _showScheduleCaseDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialPatientId,
  String? initialEncounterId,
  String? initialEmergencyCaseId,
}) async {
  final Map<String, Object?>? payload = await showTheaterScheduleCaseDialog(
    context: context,
    title: context.l10n.theaterScheduleCaseDialogTitle,
    icon: const Icon(Icons.add),
    initialPatientId: initialPatientId,
    initialEncounterId: initialEncounterId,
    initialEmergencyCaseId: initialEmergencyCaseId,
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .scheduleCase(payload);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showRescheduleDialog(
  BuildContext context,
  WidgetRef ref,
  TheaterCase theaterCase,
) async {
  final Map<String, Object?>? payload = await showTheaterScheduleCaseDialog(
    context: context,
    title: context.l10n.theaterRescheduleDialogTitle,
    icon: const Icon(Icons.edit_calendar_outlined),
    theaterCase: theaterCase,
    rescheduleOnly: true,
  );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .updateCaseSchedule(payload);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showStageDialog(
  BuildContext context,
  WidgetRef ref,
  TheaterCase theaterCase,
) async {
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterUpdateStageDialogTitle),
        icon: const Icon(Icons.alt_route_outlined),
        content: _StageForm(theaterCase: theaterCase),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .updateStage(payload);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

/// Minimal start path: confirm sign-in / in-theater without re-picking stage.
Future<void> _showStartCaseDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppConfirmActionDialog(
      title: l10n.theaterStartCaseAction,
      body: l10n.theaterStartCaseBody,
      submitLabel: l10n.theaterStartCaseAction,
      icon: const Icon(Icons.play_arrow_outlined),
      submitLeadingIcon: Icons.play_arrow_outlined,
      onConfirm: () => ref
          .read(theaterWorkspaceControllerProvider.notifier)
          .updateStage(<String, Object?>{
            'workflow_stage': 'SIGN_IN',
            'status': 'IN_PROGRESS',
            'started_at': DateTime.now().toUtc().toIso8601String(),
          }),
    ),
  );
  if (saved == true && context.mounted) {
    _showMutationResult(context, null);
  }
}

Future<void> _showHandoverDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterHandoverDialogTitle),
        icon: const Icon(Icons.output_outlined),
        content: const _HandoverForm(),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .updateStage(payload);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showCancelDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterCancelCaseDialogTitle),
        icon: const Icon(Icons.cancel_outlined),
        content: _NotesOnlyForm(
          notesLabel: context.l10n.theaterCancellationReasonLabel,
          submitLabel: context.l10n.theaterCancelCaseAction,
          isRequired: true,
          buildPayload: (String notes) => <String, Object?>{
            'status': 'CANCELLED',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
            'stage_notes': notes,
          },
        ),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .updateStage(payload);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showAssignResourceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterAssignResourceDialogTitle),
        icon: const Icon(Icons.meeting_room_outlined),
        content: const _ResourceForm(),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .assignResource(payload);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showChecklistDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterReadinessDialogTitle),
        icon: const Icon(Icons.fact_check_outlined),
        content: const _ChecklistForm(),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .toggleChecklistItem(payload);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showAnesthesiaDialog(
  BuildContext context,
  WidgetRef ref,
  TheaterCase theaterCase,
) async {
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterAnesthesiaDialogTitle),
        icon: const Icon(Icons.monitor_heart_outlined),
        content: _AnesthesiaForm(theaterCase: theaterCase),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .upsertAnesthesiaRecord(payload);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showPostOpDialog(
  BuildContext context,
  WidgetRef ref,
  TheaterCase theaterCase,
) async {
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterPostOpDialogTitle),
        icon: const Icon(Icons.note_add_outlined),
        content: _PostOpForm(theaterCase: theaterCase),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .upsertPostOpNote(payload);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

Future<void> _showFinalizeDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterFinalizeDialogTitle),
        icon: const Icon(Icons.verified_outlined),
        content: const _FinalizeForm(),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .finalizeRecord(payload);
  if (!context.mounted) {
    return;
  }
  _showMutationResult(context, failure);
}

class _StageForm extends StatefulWidget {
  const _StageForm({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  State<_StageForm> createState() => _StageFormState();
}

class _StageFormState extends State<_StageForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  String? _stage;
  String? _status;

  @override
  void initState() {
    super.initState();
    _stage = widget.theaterCase.workflowStage;
    _status = widget.theaterCase.status;
    _notesController = TextEditingController(
      text: widget.theaterCase.stageNotes,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _stage,
          labelText: l10n.theaterStageLabel,
          options: <AppSelectOption<String>>[
            for (final String stage in theaterWorkflowStages)
              AppSelectOption<String>(
                value: stage,
                label: _stageLabel(l10n, stage),
              ),
          ],
          onChanged: (String? value) => setState(() => _stage = value),
        ),
        AppSelectField<String>(
          value: _status,
          labelText: l10n.theaterStatusLabel,
          options: <AppSelectOption<String>>[
            for (final String status in theaterCaseStatuses)
              AppSelectOption<String>(
                value: status,
                label: _caseStatusLabel(l10n, status),
              ),
          ],
          onChanged: (String? value) => setState(() => _status = value),
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.theaterStageNotesLabel,
          maxLines: 4,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.theaterUpdateStageAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            Navigator.of(context).pop(<String, Object?>{
              'workflow_stage': _stage,
              'status': _status,
              'stage_notes': _notesController.text.trim(),
              if (_status == 'IN_PROGRESS')
                'started_at':
                    widget.theaterCase.startedAt?.toUtc().toIso8601String() ??
                    DateTime.now().toUtc().toIso8601String(),
              if (_status == 'COMPLETED')
                'completed_at':
                    widget.theaterCase.completedAt?.toUtc().toIso8601String() ??
                    DateTime.now().toUtc().toIso8601String(),
            });
          },
        ),
      ],
    );
  }
}

class _ResourceForm extends StatefulWidget {
  const _ResourceForm();

  @override
  State<_ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends State<_ResourceForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _resourceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _resourceType = 'ROOM';
  String? _staffRole;

  @override
  void dispose() {
    _resourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool needsStaffRole = _resourceType == 'STAFF';

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _resourceType,
          labelText: l10n.theaterResourceTypeLabel,
          isRequired: true,
          options: <AppSelectOption<String>>[
            for (final String type in theaterResourceTypes)
              AppSelectOption<String>(value: type, label: _apiLabel(type)),
          ],
          onChanged: (String? value) => setState(() => _resourceType = value),
        ),
        AppTextField(
          controller: _resourceController,
          labelText: l10n.theaterResourceIdLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.theaterFieldRequiredLabel(l10n.theaterResourceIdLabel),
          ),
        ),
        if (needsStaffRole)
          AppSelectField<String>(
            value: _staffRole,
            labelText: l10n.theaterStaffRoleLabel,
            isRequired: true,
            options: <AppSelectOption<String>>[
              for (final String role in theaterStaffRoles)
                AppSelectOption<String>(value: role, label: _apiLabel(role)),
            ],
            validator: AppValidators.requiredValue(
              l10n.theaterFieldRequiredLabel(l10n.theaterStaffRoleLabel),
            ),
            onChanged: (String? value) => setState(() => _staffRole = value),
          ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.theaterNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.theaterAssignResourceAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'resource_type': _resourceType,
              'resource_id': _resourceController.text.trim(),
              'staff_role': needsStaffRole ? _staffRole : null,
              'notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

class _ChecklistForm extends StatefulWidget {
  const _ChecklistForm();

  @override
  State<_ChecklistForm> createState() => _ChecklistFormState();
}

class _ChecklistFormState extends State<_ChecklistForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _phase = 'PRE_OP';
  bool _isChecked = true;

  @override
  void dispose() {
    _codeController.dispose();
    _labelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _phase,
          labelText: l10n.theaterChecklistPhaseLabel,
          isRequired: true,
          options: <AppSelectOption<String>>[
            for (final String phase in theaterChecklistPhases)
              AppSelectOption<String>(
                value: phase,
                label: _stageLabel(l10n, phase),
              ),
          ],
          onChanged: (String? value) => setState(() => _phase = value),
        ),
        AppTextField(
          controller: _codeController,
          labelText: l10n.theaterChecklistItemCodeLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.theaterFieldRequiredLabel(l10n.theaterChecklistItemCodeLabel),
          ),
        ),
        AppTextField(
          controller: _labelController,
          labelText: l10n.theaterChecklistItemLabel,
        ),
        AppCheckboxField(
          title: l10n.theaterChecklistCheckedLabel,
          value: _isChecked,
          onChanged: (bool value) => setState(() => _isChecked = value),
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.theaterNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.theaterUpdateReadinessAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'phase': _phase,
              'item_code': _codeController.text.trim(),
              'item_label': _labelController.text.trim(),
              'is_checked': _isChecked,
              'notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

class _AnesthesiaForm extends StatefulWidget {
  const _AnesthesiaForm({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  State<_AnesthesiaForm> createState() => _AnesthesiaFormState();
}

class _AnesthesiaFormState extends State<_AnesthesiaForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _anesthetistController;
  late final TextEditingController _notesController;
  String _recordStatus = 'DRAFT';

  @override
  void initState() {
    super.initState();
    _anesthetistController = TextEditingController(
      text: widget.theaterCase.anesthetistUserDisplayId,
    );
    _notesController = TextEditingController(
      text: widget.theaterCase.latestAnesthesiaRecord?.notes,
    );
    _recordStatus =
        widget.theaterCase.latestAnesthesiaRecord?.recordStatus ?? 'DRAFT';
  }

  @override
  void dispose() {
    _anesthetistController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _anesthetistController,
          labelText: l10n.theaterAnesthetistIdLabel,
        ),
        AppSelectField<String>(
          value: _recordStatus,
          labelText: l10n.theaterRecordStatusLabel,
          options: <AppSelectOption<String>>[
            for (final String status in theaterRecordStatuses)
              AppSelectOption<String>(
                value: status,
                label: _recordStatusLabel(l10n, status),
              ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _recordStatus = value);
            }
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.theaterAnesthesiaNotesLabel,
          isRequired: true,
          maxLines: 5,
          validator: AppValidators.requiredText(
            l10n.theaterFieldRequiredLabel(l10n.theaterAnesthesiaNotesLabel),
          ),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.theaterSaveRecordAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'anesthesia_record_id':
                  widget.theaterCase.anesthesiaRecordDisplayId,
              'anesthetist_user_id': _anesthetistController.text.trim(),
              'record_status': _recordStatus,
              'notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

class _PostOpForm extends StatefulWidget {
  const _PostOpForm({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  State<_PostOpForm> createState() => _PostOpFormState();
}

class _PostOpFormState extends State<_PostOpForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _noteController;
  String _recordStatus = 'DRAFT';

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.theaterCase.latestPostOpNote?.notes,
    );
    _recordStatus =
        widget.theaterCase.latestPostOpNote?.recordStatus ?? 'DRAFT';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _recordStatus,
          labelText: l10n.theaterRecordStatusLabel,
          options: <AppSelectOption<String>>[
            for (final String status in theaterRecordStatuses)
              AppSelectOption<String>(
                value: status,
                label: _recordStatusLabel(l10n, status),
              ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _recordStatus = value);
            }
          },
        ),
        AppTextField(
          controller: _noteController,
          labelText: l10n.theaterPostOpNoteLabel,
          isRequired: true,
          maxLines: 5,
          validator: AppValidators.requiredText(
            l10n.theaterFieldRequiredLabel(l10n.theaterPostOpNoteLabel),
          ),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.theaterSaveRecordAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'post_op_note_id': widget.theaterCase.postOpNoteDisplayId,
              'record_status': _recordStatus,
              'note': _noteController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

class _FinalizeForm extends StatefulWidget {
  const _FinalizeForm();

  @override
  State<_FinalizeForm> createState() => _FinalizeFormState();
}

class _FinalizeFormState extends State<_FinalizeForm> {
  String _recordType = 'ALL';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return AppFormShell(
      formKey: formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _recordType,
          labelText: l10n.theaterRecordTypeLabel,
          options: <AppSelectOption<String>>[
            for (final String type in theaterFinalizeRecordTypes)
              AppSelectOption<String>(value: type, label: _apiLabel(type)),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _recordType = value);
            }
          },
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.theaterFinalizeAction,
          submitIcon: Icons.verified_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            Navigator.of(
              context,
            ).pop(<String, Object?>{'record_type': _recordType});
          },
        ),
      ],
    );
  }
}

class _NotesOnlyForm extends StatefulWidget {
  const _NotesOnlyForm({
    required this.notesLabel,
    required this.submitLabel,
    required this.buildPayload,
    this.isRequired = false,
  });

  final String notesLabel;
  final String submitLabel;
  final bool isRequired;
  final Map<String, Object?> Function(String notes) buildPayload;

  @override
  State<_NotesOnlyForm> createState() => _NotesOnlyFormState();
}

class _NotesOnlyFormState extends State<_NotesOnlyForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _notesController,
          labelText: widget.notesLabel,
          isRequired: widget.isRequired,
          maxLines: 4,
          validator: widget.isRequired
              ? AppValidators.requiredText(
                  l10n.theaterFieldRequiredLabel(widget.notesLabel),
                )
              : null,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.submitLabel,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(
              context,
            ).pop(widget.buildPayload(_notesController.text.trim()));
          },
        ),
      ],
    );
  }
}

void _showMutationResult(BuildContext context, AppFailure? failure) {
  if (!context.mounted) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? l10n.theaterSavedMessage
            : l10n.failureMessage(failure),
      ),
    ),
  );
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

const String _theaterStatusFilterKey = 'status';
const String _theaterStageFilterKey = 'stage';
const String _theaterRoomFilterKey = 'room';
const String _theaterSurgeonFilterKey = 'surgeon';
const String _theaterAnesthetistFilterKey = 'anesthetist';

AppSearchBarFilterValue _theaterFilterValue(
  TheaterCaseQuery query,
  TheaterSection section,
) {
  final bool includeStatusStage = section == TheaterSection.all;
  return AppSearchBarFilterValue(
    dateFrom: query.scheduledDate,
    texts: <String, String>{
      if (query.roomId != null) _theaterRoomFilterKey: query.roomId!,
      if (query.surgeonUserId != null)
        _theaterSurgeonFilterKey: query.surgeonUserId!,
      if (query.anesthetistUserId != null)
        _theaterAnesthetistFilterKey: query.anesthetistUserId!,
    },
    options: <String, String>{
      if (includeStatusStage && query.status != null)
        _theaterStatusFilterKey: query.status!,
      if (includeStatusStage && query.stage != null)
        _theaterStageFilterKey: query.stage!,
    },
  );
}

bool _hasTheaterFilters(TheaterCaseQuery query, TheaterSection section) {
  final bool includeStatusStage = section == TheaterSection.all;
  return (includeStatusStage && query.status != null) ||
      (includeStatusStage && query.stage != null) ||
      query.scheduledDate != null ||
      query.roomId != null ||
      query.surgeonUserId != null ||
      query.anesthetistUserId != null;
}

List<AppSearchBarFilterChoice> _theaterStatusFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final String status in theaterCaseStatuses)
      AppSearchBarFilterChoice(
        value: status,
        label: _caseStatusLabel(l10n, status),
        icon: _caseStatusIcon(status),
      ),
  ];
}

List<AppSearchBarFilterChoice> _theaterStageFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    for (final String stage in theaterWorkflowStages)
      AppSearchBarFilterChoice(
        value: stage,
        label: _stageLabel(l10n, stage),
        icon: _stageIcon(stage),
      ),
  ];
}

IconData _caseStatusIcon(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'SCHEDULED' => Icons.event_available_outlined,
    'IN_PROGRESS' => Icons.meeting_room_outlined,
    'COMPLETED' => Icons.task_alt_outlined,
    'CANCELLED' => Icons.cancel_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

IconData _stageIcon(String? stage) {
  return switch ((stage ?? '').trim().toUpperCase()) {
    'PRE_OP' => Icons.assignment_outlined,
    'SIGN_IN' => Icons.login_outlined,
    'TIME_OUT' => Icons.fact_check_outlined,
    'INTRA_OP' => Icons.monitor_heart_outlined,
    'SIGN_OUT' => Icons.output_outlined,
    'POST_OP' => Icons.note_add_outlined,
    'PACU_HANDOFF' => Icons.output_outlined,
    'COMPLETED' => Icons.verified_outlined,
    _ => Icons.timeline_outlined,
  };
}

bool _isSameTheaterFilterDate(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == null && right == null;
  }
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _caseStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'SCHEDULED' => l10n.theaterStatusScheduled,
    'IN_PROGRESS' => l10n.theaterStatusInTheater,
    'COMPLETED' => l10n.theaterStatusCompleted,
    'CANCELLED' => l10n.theaterStatusCancelled,
    _ => l10n.profileUnknownValue,
  };
}

const String _emptyTheaterStatusLabel = '';

String _stageLabel(AppLocalizations l10n, String? stage) {
  return switch ((stage ?? '').trim().toUpperCase()) {
    'PRE_OP' => l10n.theaterStagePreOp,
    'SIGN_IN' => l10n.theaterStageSignIn,
    'TIME_OUT' => l10n.theaterStageTimeOut,
    'INTRA_OP' => l10n.theaterStageIntraOp,
    'SIGN_OUT' => l10n.theaterStageSignOut,
    'POST_OP' => l10n.theaterStagePostOp,
    'PACU_HANDOFF' => l10n.theaterStagePacuHandoff,
    'COMPLETED' => l10n.theaterStageCompleted,
    _ => l10n.profileUnknownValue,
  };
}

String _recordStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'DRAFT' => l10n.theaterRecordDraft,
    'FINAL' => l10n.theaterRecordFinal,
    _ => l10n.profileUnknownValue,
  };
}

AppWorkspaceStatusTone _statusTone(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'COMPLETED' => AppWorkspaceStatusTone.success,
    'CANCELLED' => AppWorkspaceStatusTone.error,
    'IN_PROGRESS' => AppWorkspaceStatusTone.info,
    'SCHEDULED' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _readinessLabel(BuildContext context, TheaterCase theaterCase) {
  final AppLocalizations l10n = context.l10n;
  if (theaterCase.checklistTotal == 0) {
    return l10n.theaterReadinessNotStarted;
  }
  return l10n.theaterReadinessProgress(
    theaterCase.checklistCompleted,
    theaterCase.checklistTotal,
  );
}

String _roomLabel(BuildContext context, TheaterCase theaterCase) {
  return _joinDisplay(<String?>[
    theaterCase.roomDisplayLabel,
    theaterCase.roomDisplayId,
  ]).ifEmpty(context.l10n.profileUnknownValue);
}

String _formatDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

class _HandoverForm extends StatefulWidget {
  const _HandoverForm();

  @override
  State<_HandoverForm> createState() => _HandoverFormState();
}

class _HandoverFormState extends State<_HandoverForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  String _destination = 'WARD';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppSelectField<String>(
          value: _destination,
          labelText: l10n.theaterHandoverDestinationLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'WARD',
              label: l10n.theaterHandoverToWard,
            ),
            AppSelectOption<String>(
              value: 'ICU',
              label: l10n.theaterHandoverToIcu,
            ),
            AppSelectOption<String>(
              value: 'OPD',
              label: l10n.theaterHandoverToOpd,
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _destination = value);
            }
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.theaterHandoverNotesLabel,
          maxLines: 4,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.theaterHandoverAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            Navigator.of(context).pop(<String, Object?>{
              'workflow_stage': 'PACU_HANDOFF',
              'status': 'IN_PROGRESS',
              'handover_destination': _destination,
              'stage_notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

String? _sourceContextLabel(AppLocalizations l10n, TheaterCase theaterCase) {
  return switch ((theaterCase.sourceKind ?? '').toUpperCase()) {
    'EMERGENCY' => l10n.theaterSourceEmergency,
    'OPD' => l10n.theaterSourceOpd,
    'IPD' => l10n.theaterSourceIpd,
    _ => null,
  };
}

void _openIpdWorkspace(BuildContext context, String admissionDisplayId) {
  context.go(
    AppRoutes.ipd.location(
      queryParameters: <String, String>{'id': admissionDisplayId},
    ),
  );
}

void _openEmergencyWorkspace(BuildContext context, String caseDisplayId) {
  context.go(
    AppRoutes.emergency.location(
      queryParameters: <String, String>{'id': caseDisplayId},
    ),
  );
}

String _responsibleRoleLabel(AppLocalizations l10n, TheaterCase theaterCase) {
  return switch (theaterCase.responsibleRoleLabel) {
    'NURSE' => l10n.theaterRoleNurse,
    'SURGEON' => l10n.theaterRoleSurgeon,
    'ANESTHETIST' => l10n.theaterRoleAnesthetist,
    'TEAM' => l10n.theaterRoleTeam,
    _ => l10n.theaterRoleCoordinator,
  };
}

int _pageTotal<T>(AppPage<T> page) => page.totalItemCount ?? page.items.length;

String? _formatDateTimeOrNull(BuildContext context, DateTime? value) {
  return value == null
      ? null
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _apiLabel(String? value) {
  final String normalized = value?.trim() ?? '';
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
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
