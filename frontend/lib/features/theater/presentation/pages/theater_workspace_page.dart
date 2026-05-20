import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/presentation/controllers/theater_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class TheaterWorkspacePage extends ConsumerWidget {
  const TheaterWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return _TheaterWorkspaceContent(state: state);
      },
    );
  }
}

class _TheaterWorkspaceContent extends ConsumerWidget {
  const _TheaterWorkspaceContent({required this.state});

  final TheaterWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final controller = ref.read(theaterWorkspaceControllerProvider.notifier);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = accessPolicy.grants(AppPermissions.clinicalWrite);
    final AppFailure? lastFailure = state.lastFailure;

    return AppWorkspace(
      title: l10n.theaterTitle,
      status: AppWorkspaceStatus(
        label: state.isMutating
            ? l10n.theaterSavingStatus
            : l10n.theaterLiveStatus,
        tone: state.isMutating
            ? AppWorkspaceStatusTone.warning
            : AppWorkspaceStatusTone.success,
        icon: state.isMutating ? Icons.sync_outlined : Icons.sensors_outlined,
      ),
      primaryAction: canWrite
          ? AppButton.primary(
              label: l10n.theaterScheduleCaseAction,
              leadingIcon: Icons.add,
              enabled: !state.isMutating,
              onPressed: () => _showScheduleCaseDialog(context, ref),
            )
          : null,
      secondaryActions: <Widget>[
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          isLoading: state.isRefreshing,
          onPressed: state.isRefreshing ? null : controller.refresh,
        ),
      ],
      compactSummaryCards: true,
      summaryCards: <Widget>[
        AppWorkspaceSummaryCard(
          label: l10n.theaterScheduledSummaryLabel,
          value: state.scheduledCount.toString(),
          icon: Icons.event_available_outlined,
          compact: true,
        ),
        AppWorkspaceSummaryCard(
          label: l10n.theaterInTheaterSummaryLabel,
          value: state.inTheaterCount.toString(),
          icon: Icons.meeting_room_outlined,
          tone: AppWorkspaceStatusTone.info,
          compact: true,
        ),
        AppWorkspaceSummaryCard(
          label: l10n.theaterReadySummaryLabel,
          value: state.readyCount.toString(),
          icon: Icons.fact_check_outlined,
          tone: AppWorkspaceStatusTone.success,
          compact: true,
        ),
        AppWorkspaceSummaryCard(
          label: l10n.theaterCompletedSummaryLabel,
          value: state.completedCount.toString(),
          icon: Icons.task_alt_outlined,
          compact: true,
        ),
      ],
      filters: _TheaterFilterBar(state: state),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (lastFailure != null) ...<Widget>[
            AppFailureStateView(
              failure: lastFailure,
              onRetry: controller.refresh,
            ),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          _TheaterCaseBoard(
            state: state,
            onSelected: controller.selectCase,
            onPageChanged: controller.changePage,
          ),
        ],
      ),
      detail: _TheaterCaseDetail(
        theaterCase: state.selectedCase,
        isLoading: state.isRefreshingDetail,
        isMutating: state.isMutating,
        canWrite: canWrite,
      ),
    );
  }
}

class _TheaterFilterBar extends ConsumerStatefulWidget {
  const _TheaterFilterBar({required this.state});

  final TheaterWorkspaceState state;

  @override
  ConsumerState<_TheaterFilterBar> createState() => _TheaterFilterBarState();
}

class _TheaterFilterBarState extends ConsumerState<_TheaterFilterBar> {
  late final TextEditingController _searchController;
  late final TextEditingController _roomController;
  late final TextEditingController _surgeonController;
  late final TextEditingController _anesthetistController;

  @override
  void initState() {
    super.initState();
    final TheaterCaseQuery query = widget.state.query;
    _searchController = TextEditingController(text: query.search);
    _roomController = TextEditingController(text: query.roomId);
    _surgeonController = TextEditingController(text: query.surgeonUserId);
    _anesthetistController = TextEditingController(
      text: query.anesthetistUserId,
    );
  }

  @override
  void didUpdateWidget(covariant _TheaterFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final TheaterCaseQuery query = widget.state.query;
    _syncController(_searchController, query.search);
    _syncController(_roomController, query.roomId ?? '');
    _syncController(_surgeonController, query.surgeonUserId ?? '');
    _syncController(_anesthetistController, query.anesthetistUserId ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _roomController.dispose();
    _surgeonController.dispose();
    _anesthetistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final controller = ref.read(theaterWorkspaceControllerProvider.notifier);
    final TheaterCaseQuery query = widget.state.query;

    return AppWorkspaceFilterBar(
      semanticLabel: l10n.theaterFiltersLabel,
      expandSearch: true,
      search: AppSearchBar(
        controller: _searchController,
        semanticLabel: l10n.theaterSearchLabel,
        hintText: l10n.theaterSearchHint,
        clearLabel: l10n.theaterClearFiltersAction,
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
      ),
      filters: <Widget>[
        AppDateField(
          value: query.scheduledDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          labelText: l10n.theaterScheduleDateFilterLabel,
          pickerButtonLabel: l10n.theaterPickScheduleDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          hintText: l10n.appDateFormatHint,
          onChanged: controller.applyScheduledDate,
        ),
        AppSelectField<String>(
          value: query.status,
          labelText: l10n.theaterStatusFilterLabel,
          options: <AppSelectOption<String>>[
            for (final String status in theaterCaseStatuses)
              AppSelectOption<String>(
                value: status,
                label: _caseStatusLabel(l10n, status),
              ),
          ],
          onChanged: controller.applyStatus,
        ),
        AppSelectField<String>(
          value: query.stage,
          labelText: l10n.theaterStageFilterLabel,
          options: <AppSelectOption<String>>[
            for (final String stage in theaterWorkflowStages)
              AppSelectOption<String>(
                value: stage,
                label: _stageLabel(l10n, stage),
              ),
          ],
          onChanged: controller.applyStage,
        ),
      ],
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.theaterResourceFiltersAction,
          leadingIcon: Icons.tune,
          onPressed: () => _showResourceFilterDialog(context, ref),
        ),
        AppButton.tertiary(
          label: l10n.theaterClearFiltersAction,
          leadingIcon: Icons.clear,
          onPressed: controller.clearFilters,
        ),
      ],
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.text = value;
    }
  }
}

class _TheaterCaseBoard extends StatelessWidget {
  const _TheaterCaseBoard({
    required this.state,
    required this.onSelected,
    required this.onPageChanged,
  });

  final TheaterWorkspaceState state;
  final ValueChanged<TheaterCase> onSelected;
  final ValueChanged<AppPageRequest> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppWorkspaceDetailPanel(
      title: l10n.theaterCasesTitle,
      description: l10n.theaterCasesDescription,
      child: AppPaginatedListTable<TheaterCase>(
        page: state.cases,
        isLoading: state.isRefreshing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemKeyBuilder: (TheaterCase item) => ValueKey<String>(item.id),
        onRowSelected: onSelected,
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
        emptyBuilder: (BuildContext context) {
          return AppStateView(
            title: l10n.theaterNoCasesTitle,
            body: l10n.theaterNoCasesBody,
            variant: AppStateViewVariant.empty,
          );
        },
        columns: <AppListTableColumn<TheaterCase>>[
          AppListTableColumn<TheaterCase>(
            label: l10n.theaterPatientColumnLabel,
            cellBuilder: (BuildContext context, TheaterCase item) {
              return _TwoLineCell(
                title: item.patientDisplayName ?? l10n.profileUnknownValue,
                subtitle: _joinDisplay(<String?>[
                  item.patientDisplayId,
                  item.encounterDisplayId,
                ]),
              );
            },
          ),
          AppListTableColumn<TheaterCase>(
            label: l10n.theaterTimeColumnLabel,
            cellBuilder: (BuildContext context, TheaterCase item) {
              return Text(_formatDateTime(context, item.scheduledAt));
            },
          ),
          AppListTableColumn<TheaterCase>(
            label: l10n.theaterRoomColumnLabel,
            cellBuilder: (BuildContext context, TheaterCase item) {
              return Text(_roomLabel(context, item));
            },
          ),
          AppListTableColumn<TheaterCase>(
            label: l10n.theaterStatusColumnLabel,
            cellBuilder: (BuildContext context, TheaterCase item) {
              return _TheaterStatusBadge(status: item.status);
            },
          ),
          AppListTableColumn<TheaterCase>(
            label: l10n.theaterReadinessColumnLabel,
            cellBuilder: (BuildContext context, TheaterCase item) {
              return Text(_readinessLabel(context, item));
            },
          ),
          AppListTableColumn<TheaterCase>(
            label: l10n.theaterNextActionColumnLabel,
            cellBuilder: (BuildContext context, TheaterCase item) {
              return Text(_nextActionLabel(context, item));
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, TheaterCase item) {
          return _TheaterCaseListTile(theaterCase: item);
        },
      ),
    );
  }
}

class _TheaterCaseDetail extends ConsumerWidget {
  const _TheaterCaseDetail({
    required this.theaterCase,
    required this.isLoading,
    required this.isMutating,
    required this.canWrite,
  });

  final TheaterCase? theaterCase;
  final bool isLoading;
  final bool isMutating;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TheaterCase? selected = theaterCase;
    if (selected == null) {
      return AppWorkspaceDetailPanel(
        title: l10n.theaterCaseDetailTitle,
        child: AppStateView(
          title: l10n.theaterNoCaseSelectedTitle,
          body: l10n.theaterNoCaseSelectedBody,
        ),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.theaterCaseDetailTitle,
      description: selected.effectiveDisplayId,
      actions: canWrite
          ? <Widget>[
              AppIconButton(
                icon: Icons.edit_calendar_outlined,
                semanticLabel: l10n.theaterRescheduleAction,
                tooltip: l10n.theaterRescheduleAction,
                onPressed: isMutating
                    ? null
                    : () => _showRescheduleDialog(context, ref, selected),
              ),
              AppIconButton(
                icon: Icons.alt_route_outlined,
                semanticLabel: l10n.theaterUpdateStageAction,
                tooltip: l10n.theaterUpdateStageAction,
                onPressed: isMutating
                    ? null
                    : () => _showStageDialog(context, ref, selected),
              ),
            ]
          : const <Widget>[],
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _TheaterCaseDetailBody(
              theaterCase: selected,
              canWrite: canWrite,
              isMutating: isMutating,
            ),
    );
  }
}

class _TheaterCaseDetailBody extends ConsumerWidget {
  const _TheaterCaseDetailBody({
    required this.theaterCase,
    required this.canWrite,
    required this.isMutating,
  });

  final TheaterCase theaterCase;
  final bool canWrite;
  final bool isMutating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName:
              theaterCase.patientDisplayName ?? l10n.profileUnknownValue,
          patientNumber:
              theaterCase.patientDisplayId ??
              theaterCase.encounterDisplayId ??
              theaterCase.effectiveDisplayId,
          status: AppWorkspaceStatus(
            label: _caseStatusLabel(l10n, theaterCase.status),
            tone: _statusTone(theaterCase.status),
          ),
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.theaterEncounterLabel,
              value: theaterCase.encounterDisplayId ?? l10n.profileUnknownValue,
              icon: Icons.assignment_outlined,
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
        SizedBox(height: theme.spacing.md),
        if (canWrite)
          _TheaterActionBar(theaterCase: theaterCase, isMutating: isMutating),
        if (canWrite) SizedBox(height: theme.spacing.md),
        _DetailSection(
          title: l10n.theaterTeamTitle,
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
        SizedBox(height: theme.spacing.md),
        _ChecklistSection(theaterCase: theaterCase),
        SizedBox(height: theme.spacing.md),
        _RecordsSection(theaterCase: theaterCase),
        SizedBox(height: theme.spacing.md),
        _ResourceSection(theaterCase: theaterCase),
        SizedBox(height: theme.spacing.md),
        _TimelineSection(theaterCase: theaterCase),
      ],
    );
  }
}

class _TheaterActionBar extends ConsumerWidget {
  const _TheaterActionBar({
    required this.theaterCase,
    required this.isMutating,
  });

  final TheaterCase theaterCase;
  final bool isMutating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return AppActionList(
      actions: <AppActionItem>[
        AppActionItem(
          label: l10n.theaterAssignResourceAction,
          leadingIcon: Icons.meeting_room_outlined,
          enabled: !isMutating,
          onPressed: () => _showAssignResourceDialog(context, ref),
        ),
        AppActionItem(
          label: l10n.theaterUpdateReadinessAction,
          leadingIcon: Icons.fact_check_outlined,
          enabled: !isMutating,
          onPressed: () => _showChecklistDialog(context, ref),
        ),
        AppActionItem(
          label: l10n.theaterAnesthesiaAction,
          leadingIcon: Icons.monitor_heart_outlined,
          enabled: !isMutating,
          onPressed: () => _showAnesthesiaDialog(context, ref, theaterCase),
        ),
        AppActionItem(
          label: l10n.theaterPostOpAction,
          leadingIcon: Icons.note_add_outlined,
          enabled: !isMutating,
          onPressed: () => _showPostOpDialog(context, ref, theaterCase),
        ),
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

    return _DetailSection(
      title: l10n.theaterChecklistTitle,
      children: items.isEmpty
          ? <Widget>[_EmptyDetailLine(label: l10n.theaterNoChecklistItemsLabel)]
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
    );
  }
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return _DetailSection(
      title: l10n.theaterRecordsTitle,
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
          _EmptyDetailLine(label: l10n.theaterNoObservationsLabel)
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

    return _DetailSection(
      title: l10n.theaterResourcesTitle,
      children: allocations.isEmpty
          ? <Widget>[_EmptyDetailLine(label: l10n.theaterNoResourcesLabel)]
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
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<TheaterTimelineItem> timeline = theaterCase.timeline;

    return _DetailSection(
      title: l10n.theaterTimelineTitle,
      children: timeline.isEmpty
          ? <Widget>[_EmptyDetailLine(label: l10n.theaterNoTimelineLabel)]
          : <Widget>[
              for (final TheaterTimelineItem item in timeline.take(8))
                _StatusLine(
                  icon: Icons.history_outlined,
                  tone: AppWorkspaceStatusTone.neutral,
                  title: item.label,
                  subtitle: _formatDateTime(context, item.occurredAt),
                ),
            ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleSmall),
            SizedBox(height: theme.spacing.sm),
            ...children,
          ],
        ),
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
                fontWeight: FontWeight.w700,
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

class _EmptyDetailLine extends StatelessWidget {
  const _EmptyDetailLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _TheaterCaseListTile extends StatelessWidget {
  const _TheaterCaseListTile({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.all(Theme.of(context).spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _TwoLineCell(
                  title:
                      theaterCase.patientDisplayName ??
                      l10n.profileUnknownValue,
                  subtitle: _joinDisplay(<String?>[
                    theaterCase.patientDisplayId,
                    theaterCase.encounterDisplayId,
                  ]),
                ),
              ),
              SizedBox(width: Theme.of(context).spacing.sm),
              _TheaterStatusBadge(status: theaterCase.status),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.xs),
          Text(_formatDateTime(context, theaterCase.scheduledAt)),
          Text(
            _joinDisplay(<String?>[
              _roomLabel(context, theaterCase),
              _stageLabel(l10n, theaterCase.workflowStage),
              _readinessLabel(context, theaterCase),
            ]),
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
            fontWeight: FontWeight.w700,
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

class _TheaterStatusBadge extends StatelessWidget {
  const _TheaterStatusBadge({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _caseStatusLabel(context.l10n, status),
        tone: _statusTone(status),
      ),
    );
  }
}

Future<void> _showScheduleCaseDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterScheduleCaseDialogTitle),
        icon: const Icon(Icons.add),
        content: const _ScheduleCaseForm(),
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
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterRescheduleDialogTitle),
        icon: const Icon(Icons.edit_calendar_outlined),
        content: _ScheduleCaseForm(
          theaterCase: theaterCase,
          rescheduleOnly: true,
        ),
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

Future<void> _showHandoverDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterHandoverDialogTitle),
        icon: const Icon(Icons.output_outlined),
        content: _NotesOnlyForm(
          notesLabel: context.l10n.theaterHandoverNotesLabel,
          submitLabel: context.l10n.theaterHandoverAction,
          buildPayload: (String notes) => <String, Object?>{
            'workflow_stage': 'PACU_HANDOFF',
            'status': 'IN_PROGRESS',
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

Future<void> _showResourceFilterDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final TheaterWorkspaceState? state = ref
      .read(theaterWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (TheaterWorkspaceState value) => value,
        failure: (_) => null,
      );
  final Map<String, Object?>? payload =
      await showAppWorkspaceActionDialog<Map<String, Object?>>(
        context: context,
        title: Text(context.l10n.theaterResourceFiltersDialogTitle),
        icon: const Icon(Icons.tune),
        content: _ResourceFilterForm(query: state?.query),
      );
  if (payload == null) {
    return;
  }
  await ref
      .read(theaterWorkspaceControllerProvider.notifier)
      .applyResourceFilters(
        roomId: payload['room_id'] as String?,
        surgeonUserId: payload['surgeon_user_id'] as String?,
        anesthetistUserId: payload['anesthetist_user_id'] as String?,
      );
}

class _ScheduleCaseForm extends StatefulWidget {
  const _ScheduleCaseForm({this.theaterCase, this.rescheduleOnly = false});

  final TheaterCase? theaterCase;
  final bool rescheduleOnly;

  @override
  State<_ScheduleCaseForm> createState() => _ScheduleCaseFormState();
}

class _ScheduleCaseFormState extends State<_ScheduleCaseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _encounterController;
  late final TextEditingController _scheduledAtController;
  late final TextEditingController _roomController;
  late final TextEditingController _surgeonController;
  late final TextEditingController _anesthetistController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final TheaterCase? theaterCase = widget.theaterCase;
    _encounterController = TextEditingController(
      text: theaterCase?.encounterDisplayId,
    );
    _scheduledAtController = TextEditingController(
      text: theaterCase?.scheduledAt?.toUtc().toIso8601String(),
    );
    _roomController = TextEditingController(text: theaterCase?.roomDisplayId);
    _surgeonController = TextEditingController(
      text: theaterCase?.surgeonUserDisplayId,
    );
    _anesthetistController = TextEditingController(
      text: theaterCase?.anesthetistUserDisplayId,
    );
    _notesController = TextEditingController(text: theaterCase?.stageNotes);
  }

  @override
  void dispose() {
    _encounterController.dispose();
    _scheduledAtController.dispose();
    _roomController.dispose();
    _surgeonController.dispose();
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
        if (!widget.rescheduleOnly)
          AppTextField(
            controller: _encounterController,
            labelText: l10n.theaterEncounterIdLabel,
            hintText: l10n.theaterEncounterIdHint,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.theaterFieldRequiredLabel(l10n.theaterEncounterIdLabel),
            ),
          ),
        AppTextField(
          controller: _scheduledAtController,
          labelText: l10n.theaterScheduledAtLabel,
          hintText: l10n.theaterDateTimeHint,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.theaterFieldRequiredLabel(l10n.theaterScheduledAtLabel),
          ),
        ),
        AppTextField(
          controller: _roomController,
          labelText: l10n.theaterRoomIdLabel,
        ),
        AppTextField(
          controller: _surgeonController,
          labelText: l10n.theaterSurgeonIdLabel,
        ),
        AppTextField(
          controller: _anesthetistController,
          labelText: l10n.theaterAnesthetistIdLabel,
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.theaterStageNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: widget.rescheduleOnly
              ? l10n.theaterRescheduleAction
              : l10n.theaterScheduleCaseAction,
          submitIcon: Icons.save_outlined,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            if (!validateAndSaveAppForm(_formKey)) {
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              if (!widget.rescheduleOnly)
                'encounter_id': _encounterController.text.trim(),
              'scheduled_at': _scheduledAtController.text.trim(),
              'room_id': _roomController.text.trim(),
              'surgeon_user_id': _surgeonController.text.trim(),
              'anesthetist_user_id': _anesthetistController.text.trim(),
              'workflow_stage': widget.rescheduleOnly ? null : 'PRE_OP',
              'stage_notes': _notesController.text.trim(),
            });
          },
        ),
      ],
    );
  }
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

class _ResourceFilterForm extends StatefulWidget {
  const _ResourceFilterForm({this.query});

  final TheaterCaseQuery? query;

  @override
  State<_ResourceFilterForm> createState() => _ResourceFilterFormState();
}

class _ResourceFilterFormState extends State<_ResourceFilterForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _roomController;
  late final TextEditingController _surgeonController;
  late final TextEditingController _anesthetistController;

  @override
  void initState() {
    super.initState();
    final TheaterCaseQuery? query = widget.query;
    _roomController = TextEditingController(text: query?.roomId);
    _surgeonController = TextEditingController(text: query?.surgeonUserId);
    _anesthetistController = TextEditingController(
      text: query?.anesthetistUserId,
    );
  }

  @override
  void dispose() {
    _roomController.dispose();
    _surgeonController.dispose();
    _anesthetistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _roomController,
          labelText: l10n.theaterRoomIdLabel,
        ),
        AppTextField(
          controller: _surgeonController,
          labelText: l10n.theaterSurgeonIdLabel,
        ),
        AppTextField(
          controller: _anesthetistController,
          labelText: l10n.theaterAnesthetistIdLabel,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.theaterApplyFiltersAction,
          submitIcon: Icons.tune,
          onCancel: () => Navigator.of(context).maybePop(),
          onSubmit: () {
            Navigator.of(context).pop(<String, Object?>{
              'room_id': _emptyToNull(_roomController.text),
              'surgeon_user_id': _emptyToNull(_surgeonController.text),
              'anesthetist_user_id': _emptyToNull(_anesthetistController.text),
            });
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

String _nextActionLabel(BuildContext context, TheaterCase theaterCase) {
  final AppLocalizations l10n = context.l10n;
  if (theaterCase.normalizedStatus == 'CANCELLED') {
    return l10n.theaterStatusCancelled;
  }
  if (theaterCase.normalizedStatus == 'COMPLETED') {
    return l10n.theaterStatusCompleted;
  }
  if (!theaterCase.isReady) {
    return l10n.theaterUpdateReadinessAction;
  }
  if (theaterCase.normalizedStatus == 'SCHEDULED') {
    return l10n.theaterStartCaseAction;
  }
  if (!theaterCase.hasFinalAnesthesia) {
    return l10n.theaterAnesthesiaAction;
  }
  if (!theaterCase.hasFinalPostOp) {
    return l10n.theaterPostOpAction;
  }
  return l10n.theaterHandoverAction;
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

String? _emptyToNull(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
