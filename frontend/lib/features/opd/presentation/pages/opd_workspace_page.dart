import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/platform/app_print.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

class OpdWorkspacePage extends ConsumerWidget {
  const OpdWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<Result<OpdWorkspaceState>> state = ref.watch(
      opdWorkspaceControllerProvider,
    );

    return AsyncStateScaffold<OpdWorkspaceState>(
      value: state,
      loadingTitle: l10n.opdLoadingTitle,
      loadingBody: l10n.opdLoadingBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(opdWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, OpdWorkspaceState data) {
        return _OpdWorkspaceContent(state: data);
      },
    );
  }
}

class _OpdWorkspaceContent extends ConsumerStatefulWidget {
  const _OpdWorkspaceContent({required this.state});

  final OpdWorkspaceState state;

  @override
  ConsumerState<_OpdWorkspaceContent> createState() =>
      _OpdWorkspaceContentState();
}

class _OpdWorkspaceContentState extends ConsumerState<_OpdWorkspaceContent> {
  static const AccessRequirement _writeRequirement = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.patientWrite,
      AppPermissions.clinicalWrite,
      AppPermissions.billingWrite,
      AppPermissions.operationsWrite,
      AppPermissions.emergencyWrite,
    ],
    activeModules: <String>['scheduling-queue'],
  );

  final ValueNotifier<_OpdTableFilter> _filterNotifier =
      ValueNotifier<_OpdTableFilter>(const _OpdTableFilter());
  late final TextEditingController _searchController;
  final ValueNotifier<List<_OpdTableColumnId>> _columnNotifier =
      ValueNotifier<List<_OpdTableColumnId>>(
        List<_OpdTableColumnId>.unmodifiable(_defaultOpdTableColumns),
      );
  final ValueNotifier<AppPageRequest> _tablePageNotifier =
      ValueNotifier<AppPageRequest>(const AppPageRequest(pageSize: 12));

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_resetTablePage);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_resetTablePage)
      ..dispose();
    _filterNotifier.dispose();
    _columnNotifier.dispose();
    _tablePageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final OpdWorkspaceState state = widget.state;
    final OpdWorkspaceController controller = ref.read(
      opdWorkspaceControllerProvider.notifier,
    );
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool iconOnly =
        breakpoint == AppBreakpoint.xs || breakpoint == AppBreakpoint.sm;

    return AppWorkspace(
      title: l10n.opdTitle,
      compactSummaryCards: true,
      primaryAction: AppAccessActionGate(
        requirement: _writeRequirement,
        builder: (BuildContext context, bool isAllowed) {
          if (iconOnly) {
            return AppIconButton(
              icon: Icons.person_add_alt_1_outlined,
              semanticLabel: l10n.opdStartWalkInAction,
              tooltip: l10n.opdStartWalkInAction,
              enabled: isAllowed,
              onPressed: () {
                _openStartWalkInDialog(context, ref);
              },
            );
          }

          return AppButton.primary(
            label: l10n.opdStartWalkInAction,
            leadingIcon: Icons.person_add_alt_1_outlined,
            enabled: isAllowed,
            onPressed: () {
              _openStartWalkInDialog(context, ref);
            },
          );
        },
      ),
      secondaryActions: <Widget>[
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: l10n.commonRefreshActionLabel,
          tooltip: l10n.commonRefreshActionLabel,
          isLoading:
              state.isRefreshingAppointments ||
              state.isRefreshingQueue ||
              state.isRefreshingFlows ||
              state.isRefreshingTriageQueue,
          onPressed: () async {
            final AppFailure? failure = await controller.refresh();
            if (context.mounted) {
              _showFailureIfNeeded(context, failure);
            }
          },
        ),
      ],
      summaryCards: <Widget>[
        AppWorkspaceSummaryCard(
          label: l10n.opdArrivalsSummaryLabel,
          value: AppFormatters.compactNumber(
            _summaryPatientCount(state, _OpdSummaryPatientListType.arrivals),
            Localizations.localeOf(context),
          ),
          icon: Icons.event_available_outlined,
          tone: _categoryTone(_opdCategoryArrival),
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              type: _OpdSummaryPatientListType.arrivals,
              title: l10n.opdArrivalsSummaryLabel,
              emptyTitle: l10n.opdNoArrivalsTitle,
              emptyBody: l10n.opdNoArrivalsBody,
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.opdQueueSummaryLabel,
          value: AppFormatters.compactNumber(
            _summaryPatientCount(state, _OpdSummaryPatientListType.queue),
            Localizations.localeOf(context),
          ),
          icon: Icons.queue_outlined,
          tone: _categoryTone(_opdCategoryQueue),
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              type: _OpdSummaryPatientListType.queue,
              title: l10n.opdQueueSummaryLabel,
              emptyTitle: l10n.opdNoQueueTitle,
              emptyBody: l10n.opdNoQueueBody,
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.opdWorkflowTriageTitle,
          value: AppFormatters.compactNumber(
            state.triageQueueCount,
            Localizations.localeOf(context),
          ),
          icon: Icons.monitor_heart_outlined,
          tone: AppWorkspaceStatusTone.warning,
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              type: _OpdSummaryPatientListType.triage,
              title: l10n.opdWorkflowTriageTitle,
              emptyTitle: l10n.opdNoFlowsTitle,
              emptyBody: l10n.opdNoFlowsBody,
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.opdActiveFlowSummaryLabel,
          value: AppFormatters.compactNumber(
            _summaryPatientCount(state, _OpdSummaryPatientListType.activeFlows),
            Localizations.localeOf(context),
          ),
          icon: Icons.medical_services_outlined,
          tone: _categoryTone(_opdCategoryActiveFlow),
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              type: _OpdSummaryPatientListType.activeFlows,
              title: l10n.opdActiveFlowSummaryLabel,
              emptyTitle: l10n.opdNoFlowsTitle,
              emptyBody: l10n.opdNoFlowsBody,
            );
          },
        ),
        AppWorkspaceSummaryCard(
          label: l10n.opdCompletedFlowSummaryLabel,
          value: AppFormatters.compactNumber(
            _summaryPatientCount(
              state,
              _OpdSummaryPatientListType.completedFlows,
            ),
            Localizations.localeOf(context),
          ),
          icon: Icons.task_alt_outlined,
          tone: AppWorkspaceStatusTone.neutral,
          compact: true,
          onPressed: () {
            _openSummaryPatientList(
              context,
              type: _OpdSummaryPatientListType.completedFlows,
              title: l10n.opdCompletedFlowSummaryLabel,
              emptyTitle: l10n.opdNoSummaryPatientsTitle,
              emptyBody: l10n.opdNoSummaryPatientsBody,
            );
          },
        ),
      ],
      body: ValueListenableBuilder<_OpdTableFilter>(
        valueListenable: _filterNotifier,
        builder: (BuildContext context, _OpdTableFilter filter, _) {
          return ValueListenableBuilder<List<_OpdTableColumnId>>(
            valueListenable: _columnNotifier,
            builder:
                (BuildContext context, List<_OpdTableColumnId> columns, _) {
                  return ValueListenableBuilder<AppPageRequest>(
                    valueListenable: _tablePageNotifier,
                    builder:
                        (
                          BuildContext context,
                          AppPageRequest tablePageRequest,
                          _,
                        ) {
                          return _OpdWorkspaceBody(
                            state: state,
                            filter: filter,
                            searchController: _searchController,
                            columns: columns,
                            pageRequest: tablePageRequest,
                            onColumnsChanged: _setColumns,
                            onPageChanged: _setTablePage,
                            onFilterChanged: _setFilter,
                          );
                        },
                  );
                },
          );
        },
      ),
    );
  }

  void _setFilter(_OpdTableFilter filter) {
    if (_filterNotifier.value == filter) {
      return;
    }
    _filterNotifier.value = filter;
    _tablePageNotifier.value = _tablePageNotifier.value.first();
  }

  void _setColumns(List<_OpdTableColumnId> columns) {
    final List<_OpdTableColumnId> normalized = _normalizeTableColumns(columns);
    if (listEquals(_columnNotifier.value, normalized)) {
      return;
    }
    _columnNotifier.value = List<_OpdTableColumnId>.unmodifiable(normalized);
  }

  void _setTablePage(AppPageRequest request) {
    if (_tablePageNotifier.value == request) {
      return;
    }
    _tablePageNotifier.value = request;
  }

  void _resetTablePage() {
    final AppPageRequest firstPage = _tablePageNotifier.value.first();
    if (_tablePageNotifier.value != firstPage) {
      _tablePageNotifier.value = firstPage;
    }
  }

  Future<void> _openStartWalkInDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StartWalkInDialog(
        providerSchedules: widget.state.providerSchedules,
        appointments: widget.state.appointments.items,
        onSubmit: (Map<String, Object?> payload) {
          return ref
              .read(opdWorkspaceControllerProvider.notifier)
              .startWalkIn(payload);
        },
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }

  Future<void> _openSummaryPatientList(
    BuildContext context, {
    required _OpdSummaryPatientListType type,
    required String title,
    required String emptyTitle,
    required String emptyBody,
  }) async {
    await showAppDialog<void>(
      context: context,
      builder: (_) => _OpdSummaryPatientListDialog(
        type: type,
        title: title,
        emptyTitle: emptyTitle,
        emptyBody: emptyBody,
      ),
    );
  }
}

enum _OpdSummaryPatientListType {
  arrivals,
  queue,
  triage,
  activeFlows,
  completedFlows,
}

@immutable
final class _OpdPatientSummaryItem {
  const _OpdPatientSummaryItem({
    required this.id,
    required this.category,
    required this.title,
    this.subtitle,
    this.status,
    this.provider,
    this.time,
    this.appointment,
    this.queueEntry,
    this.flow,
  });

  final String id;
  final String category;
  final String title;
  final String? subtitle;
  final String? status;
  final String? provider;
  final DateTime? time;
  final OpdAppointment? appointment;
  final OpdQueueEntry? queueEntry;
  final OpdFlowSummary? flow;

  bool matches(String search) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return <String?>[
      id,
      category,
      title,
      subtitle,
      status,
      provider,
      appointment?.patientId,
      appointment?.patientIdentifier,
      appointment?.patientPhone,
      appointment?.reason,
      queueEntry?.patientId,
      queueEntry?.patientIdentifier,
      queueEntry?.patientPhone,
      queueEntry?.appointmentReason,
      flow?.patientId,
      flow?.patientIdentifier,
      flow?.patientPhone,
      flow?.stage,
      flow?.nextStep,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }
}

int _summaryPatientCount(
  OpdWorkspaceState state,
  _OpdSummaryPatientListType type,
) {
  return _summaryItemsForType(state, type).length;
}

List<_OpdPatientSummaryItem> _summaryItemsForType(
  OpdWorkspaceState state,
  _OpdSummaryPatientListType type,
) {
  return switch (type) {
    _OpdSummaryPatientListType.arrivals => _summaryItemsFromAppointments(
      state.appointments.items.where(
        (OpdAppointment item) => !_isCompletedStatus(item.status),
      ),
    ),
    _OpdSummaryPatientListType.queue => _summaryItemsFromQueue(
      state.queueEntries.items.where(
        (OpdQueueEntry item) => !_isCompletedStatus(item.status),
      ),
    ),
    _OpdSummaryPatientListType.triage => _summaryItemsFromFlows(
      state.triageQueue.items.where(
        (OpdFlowSummary item) =>
            !item.isTerminal && !_isCompletedStatus(item.status ?? item.stage),
      ),
      category: _opdCategoryTriage,
    ),
    _OpdSummaryPatientListType.activeFlows => _summaryItemsFromFlows(
      state.flows.items.where(
        (OpdFlowSummary item) =>
            !item.isTerminal && !_isCompletedStatus(item.status ?? item.stage),
      ),
    ),
    _OpdSummaryPatientListType.completedFlows => _summaryItemsFromFlows(
      state.flows.items.where(
        (OpdFlowSummary item) => item.isTerminal && _isCompletedToday(item),
      ),
    ),
  };
}

List<_OpdPatientSummaryItem> _summaryItemsFromAppointments(
  Iterable<OpdAppointment> appointments,
) {
  return appointments
      .map(
        (OpdAppointment item) => _OpdPatientSummaryItem(
          id: item.id,
          category: _opdCategoryArrival,
          title: item.displayTitle,
          subtitle: _joinDisplay(<String?>[
            item.patientIdentifier,
            item.patientPhone,
            item.reason,
          ]),
          status: item.status,
          provider: item.providerDisplayName,
          time: item.scheduledStart,
          appointment: item,
        ),
      )
      .toList(growable: false);
}

List<_OpdPatientSummaryItem> _summaryItemsFromQueue(
  Iterable<OpdQueueEntry> entries,
) {
  return entries
      .map(
        (OpdQueueEntry item) => _OpdPatientSummaryItem(
          id: item.id,
          category: _opdCategoryQueue,
          title: item.displayTitle,
          subtitle: _joinDisplay(<String?>[
            item.patientIdentifier,
            item.patientPhone,
            item.appointmentReason,
          ]),
          status: item.status,
          provider: item.providerDisplayName,
          time: item.queuedAt,
          queueEntry: item,
        ),
      )
      .toList(growable: false);
}

List<_OpdPatientSummaryItem> _summaryItemsFromFlows(
  Iterable<OpdFlowSummary> flows, {
  String category = _opdCategoryActiveFlow,
}) {
  return flows
      .map(
        (OpdFlowSummary item) => _OpdPatientSummaryItem(
          id: item.id,
          category: category,
          title: item.displayTitle,
          subtitle: _joinDisplay(<String?>[
            item.patientIdentifier,
            item.patientPhone,
            item.nextStep == null ? null : _apiLabel(item.nextStep!),
          ]),
          status: item.stage,
          provider: item.providerDisplayName,
          time: item.endedAt ?? item.startedAt,
          flow: item,
        ),
      )
      .toList(growable: false);
}

class _OpdSummaryPatientListDialog extends ConsumerStatefulWidget {
  const _OpdSummaryPatientListDialog({
    required this.type,
    required this.title,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final _OpdSummaryPatientListType type;
  final String title;
  final String emptyTitle;
  final String emptyBody;

  @override
  ConsumerState<_OpdSummaryPatientListDialog> createState() =>
      _OpdSummaryPatientListDialogState();
}

class _OpdSummaryPatientListDialogState
    extends ConsumerState<_OpdSummaryPatientListDialog> {
  late final TextEditingController _searchController;
  late final ValueNotifier<AppSearchBarFilterValue> _filterController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filterController = ValueNotifier<AppSearchBarFilterValue>(
      AppSearchBarFilterValue.empty,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Result<OpdWorkspaceState>? result = ref
        .watch(opdWorkspaceControllerProvider)
        .asData
        ?.value;
    final OpdWorkspaceState? state = result?.when(
      success: (OpdWorkspaceState value) => value,
      failure: (_) => null,
    );
    final List<_OpdPatientSummaryItem> patients = state == null
        ? const <_OpdPatientSummaryItem>[]
        : _summaryItemsForType(state, widget.type);

    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.groups_outlined),
      maxWidth: 920,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _OpdSummaryPatientResults(
            patients: patients,
            searchController: _searchController,
            filterController: _filterController,
            emptyTitle: widget.emptyTitle,
            emptyBody: widget.emptyBody,
            onPatientPressed: _openPatientActions,
          ),
        ],
      ),
    );
  }

  Future<void> _openPatientActions(_OpdPatientSummaryItem item) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final OpdAppointment? appointment = item.appointment;
        if (appointment != null) {
          return AppointmentActionsDialog(appointment: appointment);
        }

        final OpdQueueEntry? queueEntry = item.queueEntry;
        if (queueEntry != null) {
          return QueueActionsDialog(entry: queueEntry);
        }

        return FlowActionsDialog(flow: item.flow!);
      },
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }
}

class _OpdSummaryPatientResults extends StatelessWidget {
  const _OpdSummaryPatientResults({
    required this.patients,
    required this.searchController,
    required this.filterController,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onPatientPressed,
  });

  final List<_OpdPatientSummaryItem> patients;
  final TextEditingController searchController;
  final ValueNotifier<AppSearchBarFilterValue> filterController;
  final String emptyTitle;
  final String emptyBody;
  final ValueChanged<_OpdPatientSummaryItem> onPatientPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final double maxHeight = (MediaQuery.sizeOf(context).height * 0.56).clamp(
      280.0,
      520.0,
    );
    final List<AppSearchBarFilterGroup> filterGroups =
        _summaryPatientFilterGroups(context, patients);
    return ValueListenableBuilder<AppSearchBarFilterValue>(
      valueListenable: filterController,
      builder: (BuildContext context, AppSearchBarFilterValue filterValue, _) {
        final List<_OpdPatientSummaryItem> filteredPatients =
            _filterSummaryPatients(patients, filterValue);
        return SizedBox(
          height: maxHeight,
          child: AppListTable<_OpdPatientSummaryItem>(
            items: filteredPatients,
            displayMode: AppListTableDisplayMode.list,
            emptyBuilder: (_) =>
                _EmptyPanel(title: emptyTitle, body: emptyBody),
            columns: <AppListTableColumn<_OpdPatientSummaryItem>>[
              AppListTableColumn<_OpdPatientSummaryItem>(
                label: l10n.opdPatientColumnLabel,
                cellBuilder:
                    (BuildContext context, _OpdPatientSummaryItem item) {
                      return _PatientText(
                        title: item.title,
                        subtitle: item.subtitle,
                      );
                    },
              ),
              AppListTableColumn<_OpdPatientSummaryItem>(
                label: l10n.opdStatusColumnLabel,
                cellBuilder:
                    (BuildContext context, _OpdPatientSummaryItem item) {
                      return _StatusText(value: item.status);
                    },
              ),
            ],
            mobileItemBuilder:
                (BuildContext context, _OpdPatientSummaryItem item) {
                  return _OpdSummaryPatientRow(
                    item: item,
                    onPressed: () => onPatientPressed(item),
                  );
                },
            onRowSelected: onPatientPressed,
            itemKeyBuilder: (_OpdPatientSummaryItem item) =>
                ValueKey<String>('${item.category}-${item.id}'),
            search: AppListTableSearch<_OpdPatientSummaryItem>(
              controller: searchController,
              semanticLabel: l10n.opdSearchLabel,
              hintText: l10n.opdSearchHint,
              clearLabel: l10n.opdClearFiltersAction,
              matcher: (_OpdPatientSummaryItem item, String query) =>
                  item.matches(query),
              showAdvancedFilterButton: filterGroups.isNotEmpty,
              advancedFilterButtonLabel: l10n.opdFilterAction,
              advancedFilterTitle: l10n.opdFiltersLabel,
              advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
              advancedFilterResetLabel: l10n.opdClearFiltersAction,
              advancedFilterCancelLabel: l10n.commonCancelActionLabel,
              enableDateFilter: false,
              filterGroups: filterGroups,
              filterValue: filterValue,
              onFilterChanged: (AppSearchBarFilterValue value) {
                filterController.value = value;
              },
              hasActiveFilters: filterValue.isActive,
            ),
          ),
        );
      },
    );
  }

  List<_OpdPatientSummaryItem> _filterSummaryPatients(
    List<_OpdPatientSummaryItem> items,
    AppSearchBarFilterValue filter,
  ) {
    final String? status = filter.option(_opdFilterKeyStatus);
    if (status == null) {
      return items;
    }
    return items
        .where((_OpdPatientSummaryItem item) => item.status == status)
        .toList(growable: false);
  }

  List<AppSearchBarFilterGroup> _summaryPatientFilterGroups(
    BuildContext context,
    List<_OpdPatientSummaryItem> patients,
  ) {
    final l10n = context.l10n;
    final Set<String> statusSet = <String>{};
    for (final _OpdPatientSummaryItem patient in patients) {
      final String? status = patient.status;
      if (status == null || status.trim().isEmpty) {
        continue;
      }
      statusSet.add(status);
    }
    final List<String> statuses = statusSet.toList()..sort();
    if (statuses.isEmpty) {
      return const <AppSearchBarFilterGroup>[];
    }
    return <AppSearchBarFilterGroup>[
      AppSearchBarFilterGroup(
        key: _opdFilterKeyStatus,
        label: l10n.opdStatusFilterLabel,
        allLabel: l10n.opdAllStatusesOption,
        choices: <AppSearchBarFilterChoice>[
          for (final String status in statuses)
            AppSearchBarFilterChoice(value: status, label: _apiLabel(status)),
        ],
      ),
    ];
  }
}

class _OpdSummaryPatientRow extends StatelessWidget {
  const _OpdSummaryPatientRow({required this.item, required this.onPressed});

  final _OpdPatientSummaryItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stacked =
                !constraints.hasBoundedWidth || constraints.maxWidth < 620;
            final Widget patient = _PatientText(
              title: item.title,
              subtitle: item.subtitle,
            );
            final Widget meta = Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _StatusBadge(value: item.status),
                _OpdInlineMeta(
                  icon: Icons.badge_outlined,
                  label: item.provider ?? context.l10n.profileUnknownValue,
                ),
                _OpdInlineMeta(
                  icon: Icons.schedule_outlined,
                  label: _formatDateTime(context, item.time),
                ),
                const Icon(Icons.chevron_right),
              ],
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  patient,
                  SizedBox(height: theme.spacing.sm),
                  meta,
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: patient),
                SizedBox(width: theme.spacing.md),
                Flexible(child: meta),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OpdWorkspaceBody extends StatelessWidget {
  const _OpdWorkspaceBody({
    required this.state,
    required this.filter,
    required this.searchController,
    required this.columns,
    required this.pageRequest,
    required this.onColumnsChanged,
    required this.onPageChanged,
    required this.onFilterChanged,
  });

  final OpdWorkspaceState state;
  final _OpdTableFilter filter;
  final TextEditingController searchController;
  final List<_OpdTableColumnId> columns;
  final AppPageRequest pageRequest;
  final ValueChanged<List<_OpdTableColumnId>> onColumnsChanged;
  final ValueChanged<AppPageRequest> onPageChanged;
  final ValueChanged<_OpdTableFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final List<_OpdTableItem> items = _tableItems(context, state)
        .where((_OpdTableItem item) => filter.matches(item))
        .toList(growable: false);

    return _OpdMainTable(
      page: _tablePage(items, pageRequest),
      searchController: searchController,
      filter: filter,
      statuses: _tableStatuses(context, state),
      columns: columns,
      onColumnsChanged: onColumnsChanged,
      onPageChanged: onPageChanged,
      onFilterChanged: onFilterChanged,
      isLoading:
          state.isRefreshingAppointments ||
          state.isRefreshingQueue ||
          state.isRefreshingFlows ||
          state.isRefreshingTriageQueue,
    );
  }
}

AppPage<_OpdTableItem> _tablePage(
  List<_OpdTableItem> items,
  AppPageRequest request,
) {
  final int total = items.length;
  final int start = request.offset.clamp(0, total).toInt();
  final int end = (start + request.pageSize).clamp(start, total).toInt();

  return AppPage<_OpdTableItem>(
    items: items.sublist(start, end),
    request: request,
    totalItemCount: total,
  );
}

List<String> _tableStatuses(BuildContext context, OpdWorkspaceState state) {
  return _tableItems(context, state)
      .map((_OpdTableItem item) => item.status)
      .whereType<String>()
      .where((String value) => value.trim().isNotEmpty)
      .toSet()
      .toList(growable: false)
    ..sort();
}

List<AppSelectOption<String>> _categoryFilterOptions(BuildContext context) {
  final l10n = context.l10n;
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _opdFilterAll,
      label: l10n.opdAllCategoriesOption,
    ),
    AppSelectOption<String>(
      value: _opdCategoryArrival,
      label: l10n.opdArrivalsSummaryLabel,
    ),
    AppSelectOption<String>(
      value: _opdCategoryQueue,
      label: l10n.opdQueueSummaryLabel,
    ),
    AppSelectOption<String>(
      value: _opdCategoryTriage,
      label: l10n.opdWorkflowTriageTitle,
    ),
    AppSelectOption<String>(
      value: _opdCategoryActiveFlow,
      label: l10n.opdActiveFlowSummaryLabel,
    ),
  ];
}

List<AppSelectOption<String>> _triageScopeFilterOptions(BuildContext context) {
  final l10n = context.l10n;
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _opdFilterAll,
      label: l10n.opdAllTriageScopesOption,
    ),
    AppSelectOption<String>(
      value: _triageScopeWaiting,
      label: l10n.opdTriageScopeWaiting,
    ),
    AppSelectOption<String>(
      value: _triageScopeUrgent,
      label: l10n.opdTriageScopeUrgent,
    ),
    AppSelectOption<String>(
      value: _triageScopeEmergency,
      label: l10n.opdTriageScopeEmergency,
    ),
    AppSelectOption<String>(
      value: _triageScopeRoutine,
      label: l10n.opdTriageScopeRoutine,
    ),
    AppSelectOption<String>(
      value: _triageScopeServiceOnly,
      label: l10n.opdTriageScopeServiceOnly,
    ),
  ];
}

@immutable
final class _OpdTableFilter {
  const _OpdTableFilter({
    this.search = '',
    this.category,
    this.status,
    this.triageScope,
  });

  final String search;
  final String? category;
  final String? status;
  final String? triageScope;

  bool get isActive =>
      search.trim().isNotEmpty ||
      _isNonEmpty(category) ||
      _isNonEmpty(status) ||
      _isNonEmpty(triageScope);

  bool get hasAdvancedFilters =>
      _isNonEmpty(category) || _isNonEmpty(status) || _isNonEmpty(triageScope);

  AppSearchBarFilterValue toSearchBarValue() {
    return AppSearchBarFilterValue(
      options: <String, String>{
        if (_isNonEmpty(category)) _opdFilterKeyCategory: category!,
        if (_isNonEmpty(status)) _opdFilterKeyStatus: status!,
        if (_isNonEmpty(triageScope)) _opdFilterKeyTriageScope: triageScope!,
      },
    );
  }

  static _OpdTableFilter fromSearchBarValue(AppSearchBarFilterValue value) {
    return _OpdTableFilter(
      category: value.option(_opdFilterKeyCategory),
      status: value.option(_opdFilterKeyStatus),
      triageScope: value.option(_opdFilterKeyTriageScope),
    );
  }

  _OpdTableFilter copyWith({
    String? search,
    String? category,
    String? status,
    String? triageScope,
    bool clearSearch = false,
    bool clearCategory = false,
    bool clearStatus = false,
    bool clearTriageScope = false,
  }) {
    return _OpdTableFilter(
      search: clearSearch ? '' : search ?? this.search,
      category: clearCategory ? null : category ?? this.category,
      status: clearStatus ? null : status ?? this.status,
      triageScope: clearTriageScope ? null : triageScope ?? this.triageScope,
    );
  }

  bool matches(_OpdTableItem item) {
    if (!item.matches(search)) {
      return false;
    }
    if (_isNonEmpty(category) && item.category != category) {
      return false;
    }
    if (_isNonEmpty(status) && item.status != status) {
      return false;
    }
    if (_isNonEmpty(triageScope) && !_matchesTriageScope(item, triageScope!)) {
      return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    return other is _OpdTableFilter &&
        other.search == search &&
        other.category == category &&
        other.status == status &&
        other.triageScope == triageScope;
  }

  @override
  int get hashCode => Object.hash(search, category, status, triageScope);
}

List<AppSearchBarFilterGroup> _opdTableFilterGroups(
  BuildContext context,
  List<String> statuses,
) {
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: _opdFilterKeyCategory,
      label: context.l10n.opdCategoryFilterLabel,
      choices: _categoryFilterOptions(context)
          .where(
            (AppSelectOption<String> option) => option.value != _opdFilterAll,
          )
          .map(
            (AppSelectOption<String> option) => AppSearchBarFilterChoice(
              value: option.value,
              label: option.label,
            ),
          )
          .toList(growable: false),
    ),
    AppSearchBarFilterGroup(
      key: _opdFilterKeyStatus,
      label: context.l10n.opdStatusFilterLabel,
      choices: statuses
          .map(
            (String status) => AppSearchBarFilterChoice(
              value: status,
              label: _apiLabel(status),
            ),
          )
          .toList(growable: false),
    ),
    AppSearchBarFilterGroup(
      key: _opdFilterKeyTriageScope,
      label: context.l10n.opdTriageScopeFilterLabel,
      choices: _triageScopeFilterOptions(context)
          .where(
            (AppSelectOption<String> option) => option.value != _opdFilterAll,
          )
          .map(
            (AppSelectOption<String> option) => AppSearchBarFilterChoice(
              value: option.value,
              label: option.label,
            ),
          )
          .toList(growable: false),
    ),
  ];
}

@immutable
final class _OpdTableItem {
  const _OpdTableItem({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    this.subtitle,
    this.provider,
    this.nextStep,
    this.time,
    this.urgencyRank = _defaultUrgencyRank,
    this.appointment,
    this.queueEntry,
    this.flow,
  });

  final String id;
  final String title;
  final String category;
  final String? status;
  final String? subtitle;
  final String? provider;
  final String? nextStep;
  final DateTime? time;
  final int urgencyRank;
  final OpdAppointment? appointment;
  final OpdQueueEntry? queueEntry;
  final OpdFlowSummary? flow;

  String get categoryKey {
    final OpdFlowSummary? activeFlow = flow;
    final OpdQueueEntry? activeQueue = queueEntry;
    final OpdAppointment? activeAppointment = appointment;
    return activeFlow?.patientId ??
        activeQueue?.patientId ??
        activeAppointment?.patientId ??
        id;
  }

  bool matches(String search) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return <String?>[
      id,
      title,
      category,
      status,
      subtitle,
      provider,
      nextStep,
      appointment?.patientId,
      appointment?.patientIdentifier,
      appointment?.patientPhone,
      appointment?.reason,
      queueEntry?.patientId,
      queueEntry?.patientIdentifier,
      queueEntry?.patientPhone,
      queueEntry?.appointmentReason,
      flow?.patientId,
      flow?.patientIdentifier,
      flow?.patientPhone,
      flow?.stage,
      flow?.status,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }
}

List<_OpdTableItem> _tableItems(BuildContext context, OpdWorkspaceState state) {
  final Set<String> usedPatientKeys = <String>{};
  final List<_OpdTableItem> items = <_OpdTableItem>[];

  for (final OpdFlowSummary flow in state.triageQueue.items) {
    if (flow.isTerminal || _isCompletedStatus(flow.status ?? flow.stage)) {
      continue;
    }
    final _OpdTableItem item = _OpdTableItem(
      id: flow.id,
      title: flow.displayTitle,
      category: _opdCategoryTriage,
      status: flow.triageLevel ?? flow.stage,
      subtitle: _joinDisplay(<String?>[
        flow.patientIdentifier,
        flow.patientPhone,
        _arrivalTypeLabel(context, flow),
        _flowWaitLabel(context, flow),
        flow.chiefComplaint,
      ]),
      provider: flow.providerDisplayName,
      nextStep: _triageNextStep(flow),
      time: flow.queuedAt ?? flow.startedAt,
      urgencyRank: _flowUrgencyRank(flow),
      flow: flow,
    );
    usedPatientKeys.add(item.categoryKey);
    items.add(item);
  }

  for (final OpdFlowSummary flow in state.flows.items) {
    if (flow.isTerminal || _isCompletedStatus(flow.status ?? flow.stage)) {
      continue;
    }
    final _OpdTableItem item = _OpdTableItem(
      id: flow.id,
      title: flow.displayTitle,
      category: _opdCategoryActiveFlow,
      status: flow.stage,
      subtitle: _joinDisplay(<String?>[
        flow.patientIdentifier,
        flow.patientPhone,
        _arrivalTypeLabel(context, flow),
        _flowWaitLabel(context, flow),
        flow.lastRouteTo == null ? null : _apiLabel(flow.lastRouteTo!),
      ]),
      provider: flow.providerDisplayName,
      nextStep: flow.nextStep,
      time: flow.queuedAt ?? flow.startedAt,
      urgencyRank: _flowUrgencyRank(flow),
      flow: flow,
    );
    usedPatientKeys.add(item.categoryKey);
    items.add(item);
  }

  for (final OpdQueueEntry entry in state.queueEntries.items) {
    if (_isCompletedStatus(entry.status)) {
      continue;
    }
    final _OpdTableItem item = _OpdTableItem(
      id: entry.id,
      title: entry.displayTitle,
      category: _opdCategoryQueue,
      status: entry.status,
      subtitle: _joinDisplay(<String?>[
        entry.patientIdentifier,
        entry.patientPhone,
        entry.appointmentReason,
      ]),
      provider: entry.providerDisplayName,
      time: entry.queuedAt,
      urgencyRank: _statusUrgencyRank(entry.status),
      queueEntry: entry,
    );
    if (usedPatientKeys.add(item.categoryKey)) {
      items.add(item);
    }
  }

  for (final OpdAppointment appointment in state.appointments.items) {
    if (_isCompletedStatus(appointment.status)) {
      continue;
    }
    final _OpdTableItem item = _OpdTableItem(
      id: appointment.id,
      title: appointment.displayTitle,
      category: _opdCategoryArrival,
      status: appointment.status,
      subtitle: _joinDisplay(<String?>[
        appointment.patientIdentifier,
        appointment.patientPhone,
        appointment.reason,
      ]),
      provider: appointment.providerDisplayName,
      time: _appointmentArrivalTime(appointment),
      urgencyRank: _statusUrgencyRank(appointment.status),
      appointment: appointment,
    );
    if (usedPatientKeys.add(item.categoryKey)) {
      items.add(item);
    }
  }

  items.sort((_OpdTableItem left, _OpdTableItem right) {
    final int urgencyCompare = left.urgencyRank.compareTo(right.urgencyRank);
    if (urgencyCompare != 0) {
      return urgencyCompare;
    }
    final int timeCompare = (left.time ?? _unknownArrivalTime).compareTo(
      right.time ?? _unknownArrivalTime,
    );
    if (timeCompare != 0) {
      return timeCompare;
    }
    return _categorySort(
      left.category,
    ).compareTo(_categorySort(right.category));
  });
  return items;
}

DateTime? _appointmentArrivalTime(OpdAppointment appointment) {
  final String status = (appointment.status ?? '').toUpperCase();
  if (status == 'IN_PROGRESS') {
    return appointment.updatedAt ?? appointment.scheduledStart;
  }
  return appointment.scheduledStart ?? appointment.updatedAt;
}

int _flowUrgencyRank(OpdFlowSummary flow) {
  final int? triageRank = flow.triagePriorityRank;
  if (triageRank != null) {
    return triageRank;
  }
  if (_isEmergencyFlow(flow)) {
    return 0;
  }
  return _statusUrgencyRank(flow.stage ?? flow.status);
}

int _statusUrgencyRank(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'CRITICAL' || 'IMMEDIATE' || 'LEVEL_1' || 'EMERGENCY' => 0,
    'URGENT' || 'HIGH' || 'LEVEL_2' => 1,
    'IN_PROGRESS' || 'WAITING_DOCTOR_REVIEW' || 'WAITING_DISPOSITION' => 20,
    'CONFIRMED' ||
    'WAITING_VITALS' ||
    'WAITING_DOCTOR_ASSIGNMENT' ||
    'WAITING_CONSULTATION_PAYMENT' => 30,
    _ => _defaultUrgencyRank,
  };
}

bool _matchesTriageScope(_OpdTableItem item, String scope) {
  final String normalized = scope.toUpperCase();
  final OpdFlowSummary? flow = item.flow;
  if (normalized == _triageScopeWaiting) {
    return item.category == _opdCategoryTriage &&
        _isWaitingTriageStage(flow?.stage);
  }
  if (normalized == _triageScopeUrgent) {
    return flow != null && _flowUrgencyRank(flow) <= 1;
  }
  if (normalized == _triageScopeEmergency) {
    return flow != null && _isEmergencyFlow(flow);
  }
  if (normalized == _triageScopeRoutine) {
    return flow != null && _isRoutineTriageFlow(flow);
  }
  if (normalized == _triageScopeServiceOnly) {
    return flow != null && _isServiceOnlyFlow(flow);
  }
  return true;
}

bool _isWaitingTriageStage(String? stage) {
  return switch ((stage ?? '').toUpperCase()) {
    'WAITING_VITALS' || 'WAITING_DOCTOR_ASSIGNMENT' => true,
    _ => false,
  };
}

bool _isEmergencyFlow(OpdFlowSummary flow) {
  return flow.emergencyIndicator ||
      (flow.encounterType ?? '').toUpperCase() == 'EMERGENCY' ||
      (flow.triageLevel ?? '').toUpperCase() == 'LEVEL_1' ||
      (flow.triageLevel ?? '').toUpperCase() == 'IMMEDIATE';
}

bool _isRoutineTriageFlow(OpdFlowSummary flow) {
  return switch ((flow.triageLevel ?? '').toUpperCase()) {
    'LEVEL_3' ||
    'LEVEL_4' ||
    'LEVEL_5' ||
    'LESS_URGENT' ||
    'NON_URGENT' => true,
    _ =>
      !_isEmergencyFlow(flow) &&
          !_isServiceOnlyFlow(flow) &&
          _isWaitingTriageStage(flow.stage),
  };
}

bool _isServiceOnlyFlow(OpdFlowSummary flow) {
  final String stage = (flow.stage ?? '').toUpperCase();
  final String route = (flow.lastRouteTo ?? '').toUpperCase();
  return _serviceOnlyStages.contains(stage) ||
      _serviceOnlyRoutes.contains(route);
}

String _triageNextStep(OpdFlowSummary flow) {
  final String route = flow.lastRouteTo ?? '';
  if (route.isNotEmpty) {
    return route;
  }
  return flow.nextStep ?? flow.stage ?? '';
}

String? _arrivalTypeLabel(BuildContext context, OpdFlowSummary flow) {
  if (_isEmergencyFlow(flow)) {
    return context.l10n.opdTriageScopeEmergency;
  }
  final String encounterType = _apiLabel(flow.encounterType ?? '');
  return encounterType.isEmpty ? null : encounterType;
}

String? _flowWaitLabel(BuildContext context, OpdFlowSummary flow) {
  final DateTime? queuedAt = flow.queuedAt ?? flow.startedAt;
  if (queuedAt == null || flow.isTerminal) {
    return null;
  }

  final Duration duration = DateTime.now().difference(queuedAt.toLocal());
  if (duration.isNegative) {
    return null;
  }
  return context.l10n.opdWaitDurationShort(_formatShortDuration(duration));
}

String _formatShortDuration(Duration duration) {
  final int minutes = duration.inMinutes;
  if (minutes < 60) {
    return '${minutes}m';
  }
  final int hours = duration.inHours;
  final int remainingMinutes = minutes.remainder(60);
  if (remainingMinutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${remainingMinutes}m';
}

List<_OpdTableColumnId> _normalizeTableColumns(
  List<_OpdTableColumnId> columns,
) {
  final List<_OpdTableColumnId> normalized = <_OpdTableColumnId>[];
  for (final _OpdTableColumnId column in columns) {
    if (_availableOpdTableColumns.contains(column) &&
        !normalized.contains(column)) {
      normalized.add(column);
    }
    if (normalized.length == _maxOpdTableColumns) {
      break;
    }
  }

  for (final _OpdTableColumnId column in _defaultOpdTableColumns) {
    if (normalized.length == _maxOpdTableColumns) {
      break;
    }
    if (!normalized.contains(column)) {
      normalized.add(column);
    }
  }

  return normalized;
}

List<_OpdTableColumnId> _replaceTableColumn(
  List<_OpdTableColumnId> columns,
  int index,
  _OpdTableColumnId column,
) {
  final List<_OpdTableColumnId> next = _normalizeTableColumns(
    columns,
  ).toList(growable: true);
  if (index < 0 || index >= next.length || next[index] == column) {
    return next;
  }

  final int existingIndex = next.indexOf(column);
  if (existingIndex >= 0) {
    next[existingIndex] = next[index];
  }
  next[index] = column;
  return _normalizeTableColumns(next);
}

String _opdTableColumnLabel(BuildContext context, _OpdTableColumnId column) {
  final l10n = context.l10n;
  return switch (column) {
    _OpdTableColumnId.patient => l10n.opdPatientColumnLabel,
    _OpdTableColumnId.status => l10n.opdStatusColumnLabel,
    _OpdTableColumnId.provider => l10n.opdProviderColumnLabel,
    _OpdTableColumnId.arrivalTime => l10n.opdTimeColumnLabel,
    _OpdTableColumnId.nextStep => l10n.opdNextStepColumnLabel,
  };
}

AppListTableColumn<_OpdTableItem> _opdDataColumn(
  BuildContext context,
  List<_OpdTableColumnId> selectedColumns,
  int index,
  ValueChanged<List<_OpdTableColumnId>> onColumnsChanged,
) {
  final _OpdTableColumnId column = selectedColumns[index];
  final String label = _opdTableColumnLabel(context, column);

  return AppListTableColumn<_OpdTableItem>(
    label: label,
    headerBuilder: (BuildContext context) => _OpdColumnHeader(
      column: column,
      selectedColumns: selectedColumns,
      onChanged: (_OpdTableColumnId value) {
        onColumnsChanged(_replaceTableColumn(selectedColumns, index, value));
      },
    ),
    cellBuilder: (BuildContext context, _OpdTableItem item) {
      return switch (column) {
        _OpdTableColumnId.patient => _PatientText(
          title: item.title,
          subtitle: item.subtitle,
        ),
        _OpdTableColumnId.status => _StatusText(value: item.status),
        _OpdTableColumnId.provider => _ProviderCell(item: item),
        _OpdTableColumnId.arrivalTime => Text(
          _formatDateTime(context, item.time),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        _OpdTableColumnId.nextStep => Text(
          _nextStepLabel(context, item),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      };
    },
    tooltip: label,
  );
}

enum _OpdTableColumnId { patient, status, provider, arrivalTime, nextStep }

const int _maxOpdTableColumns = 4;
const int _defaultUrgencyRank = 99;
final DateTime _unknownArrivalTime = DateTime(9999);

const List<_OpdTableColumnId> _defaultOpdTableColumns = <_OpdTableColumnId>[
  _OpdTableColumnId.patient,
  _OpdTableColumnId.status,
  _OpdTableColumnId.provider,
  _OpdTableColumnId.arrivalTime,
];

const List<_OpdTableColumnId> _availableOpdTableColumns = <_OpdTableColumnId>[
  _OpdTableColumnId.patient,
  _OpdTableColumnId.status,
  _OpdTableColumnId.provider,
  _OpdTableColumnId.arrivalTime,
  _OpdTableColumnId.nextStep,
];

class _OpdColumnHeader extends StatelessWidget {
  const _OpdColumnHeader({
    required this.column,
    required this.selectedColumns,
    required this.onChanged,
  });

  final _OpdTableColumnId column;
  final List<_OpdTableColumnId> selectedColumns;
  final ValueChanged<_OpdTableColumnId> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String label = _opdTableColumnLabel(context, column);

    return PopupMenuButton<_OpdTableColumnId>(
      tooltip: label,
      padding: EdgeInsets.zero,
      onSelected: onChanged,
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<_OpdTableColumnId>>[
          for (final _OpdTableColumnId option in _availableOpdTableColumns)
            if (option == column || !selectedColumns.contains(option))
              CheckedPopupMenuItem<_OpdTableColumnId>(
                value: option,
                checked: option == column,
                child: Text(_opdTableColumnLabel(context, option)),
              ),
        ];
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(width: theme.spacing.xs),
          Icon(Icons.arrow_drop_down, size: theme.appTokens.listIconSize),
        ],
      ),
    );
  }
}

int _categorySort(String category) {
  return switch (category) {
    _opdCategoryTriage => 0,
    _opdCategoryActiveFlow => 1,
    _opdCategoryQueue => 2,
    _opdCategoryArrival => 3,
    _ => 4,
  };
}

bool _isCompletedStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'DISCHARGED' ||
    'ADMITTED' ||
    'CLOSED' => true,
    _ => false,
  };
}

bool _isCompletedToday(OpdFlowSummary flow) {
  final DateTime? completedAt = flow.endedAt ?? flow.startedAt;
  if (completedAt == null) {
    return false;
  }
  return _isSameLocalDate(completedAt, DateTime.now());
}

bool _isSameLocalDate(DateTime left, DateTime right) {
  final DateTime localLeft = left.toLocal();
  final DateTime localRight = right.toLocal();
  return localLeft.year == localRight.year &&
      localLeft.month == localRight.month &&
      localLeft.day == localRight.day;
}

class _OpdMainTable extends ConsumerWidget {
  const _OpdMainTable({
    required this.page,
    required this.searchController,
    required this.filter,
    required this.statuses,
    required this.columns,
    required this.onColumnsChanged,
    required this.onPageChanged,
    required this.onFilterChanged,
    required this.isLoading,
  });

  final AppPage<_OpdTableItem> page;
  final TextEditingController searchController;
  final _OpdTableFilter filter;
  final List<String> statuses;
  final List<_OpdTableColumnId> columns;
  final ValueChanged<List<_OpdTableColumnId>> onColumnsChanged;
  final ValueChanged<AppPageRequest> onPageChanged;
  final ValueChanged<_OpdTableFilter> onFilterChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final List<_OpdTableColumnId> visibleColumns = _normalizeTableColumns(
      columns,
    );

    return SizedBox(
      width: double.infinity,
      child: AppPaginatedListTable<_OpdTableItem>(
        page: page,
        isLoading: isLoading,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        emptyBuilder: (_) =>
            _EmptyPanel(title: l10n.opdNoFlowsTitle, body: l10n.opdNoFlowsBody),
        columns: <AppListTableColumn<_OpdTableItem>>[
          for (int index = 0; index < visibleColumns.length; index += 1)
            _opdDataColumn(context, visibleColumns, index, onColumnsChanged),
        ],
        onRowSelected: (_OpdTableItem item) =>
            _openTableItemActions(context, item),
        onPageChanged: onPageChanged,
        pageLabelBuilder: (AppPage<_OpdTableItem> page) =>
            _opdPageLabel(context, page),
        previousPageLabel: l10n.opdPreviousPageLabel,
        nextPageLabel: l10n.opdNextPageLabel,
        search: AppListTableSearch<_OpdTableItem>(
          controller: searchController,
          semanticLabel: l10n.opdSearchLabel,
          hintText: l10n.opdSearchHint,
          clearLabel: l10n.opdClearFiltersAction,
          matcher: (_OpdTableItem item, String query) => item.matches(query),
          showAdvancedFilterButton: true,
          advancedFilterButtonLabel: l10n.opdFilterAction,
          advancedFilterTitle: l10n.opdFiltersLabel,
          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
          advancedFilterResetLabel: l10n.opdClearFiltersAction,
          advancedFilterCancelLabel: l10n.commonCancelActionLabel,
          enableDateFilter: false,
          filterGroups: _opdTableFilterGroups(context, statuses),
          filterValue: filter.toSearchBarValue(),
          onFilterChanged: (AppSearchBarFilterValue value) {
            onFilterChanged(_OpdTableFilter.fromSearchBarValue(value));
          },
          hasActiveFilters: filter.hasAdvancedFilters,
        ),
        mobileItemBuilder: (_, _OpdTableItem item) =>
            _OpdTableMobileRow(item: item),
        itemKeyBuilder: (_OpdTableItem item) =>
            ValueKey<String>('${item.category}-${item.id}'),
        rowColorBuilder: _opdTableRowColor,
      ),
    );
  }

  Future<void> _openTableItemActions(
    BuildContext context,
    _OpdTableItem item,
  ) async {
    final OpdAppointment? appointment = item.appointment;
    final OpdQueueEntry? queueEntry = item.queueEntry;
    final OpdFlowSummary? flow = item.flow;

    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        if (appointment != null) {
          return AppointmentActionsDialog(appointment: appointment);
        }
        if (queueEntry != null) {
          return QueueActionsDialog(entry: queueEntry);
        }
        return FlowActionsDialog(flow: flow!);
      },
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));
    }
  }
}

String _opdPageLabel(BuildContext context, AppPage<_OpdTableItem> page) {
  final int total = page.totalItemCount ?? page.items.length;
  if (total == 0) {
    return context.l10n.opdPageLabel(0, 0, 0);
  }

  final int from = page.request.offset + 1;
  final int to = (page.request.offset + page.items.length).clamp(from, total);
  return context.l10n.opdPageLabel(from, to, total);
}

class _OpdTableMobileRow extends StatelessWidget {
  const _OpdTableMobileRow({required this.item});

  final _OpdTableItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title, style: theme.textTheme.titleSmall),
                SizedBox(height: theme.spacing.xs),
                Text(
                  _joinDisplay(<String?>[
                    item.subtitle,
                    _apiLabel(item.status ?? ''),
                    item.provider,
                    _nextStepLabel(context, item),
                    _formatDateTime(context, item.time),
                  ]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      variant: AppStateViewVariant.empty,
      title: title,
      body: body,
      crossAxisAlignment: CrossAxisAlignment.center,
      textAlign: TextAlign.center,
    );
  }
}

class _InlineSuccessPanel extends StatelessWidget {
  const _InlineSuccessPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
        border: Border.all(color: theme.colorScheme.primary),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          children: <Widget>[
            Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
            SizedBox(width: theme.spacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _PatientText extends StatelessWidget {
  const _PatientText({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final String label = _apiLabel(value ?? '');
    final AppWorkspaceStatusTone tone = _stageTone(value);

    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(label: label, tone: tone),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final String label = _apiLabel(value ?? '');
    final ThemeData theme = Theme.of(context);
    return Text(
      label.isEmpty ? context.l10n.profileUnknownValue : label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: _stageTextColor(theme, value),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ProviderCell extends StatelessWidget {
  const _ProviderCell({required this.item});

  final _OpdTableItem item;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.provider ?? context.l10n.profileUnknownValue,
      child: Text(
        item.provider ?? context.l10n.profileUnknownValue,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _OpdInlineMeta extends StatelessWidget {
  const _OpdInlineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: theme.appTokens.listIconSize * 0.78,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: theme.spacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

String _nextStepLabel(BuildContext context, _OpdTableItem item) {
  final String label = _apiLabel(item.nextStep ?? item.status ?? '');
  return label.isEmpty ? context.l10n.profileUnknownValue : label;
}

String _opdRequiredFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldRequiredLabel(label);
}

String _opdOptionalFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldOptionalLabel(label);
}

Color _opdTableRowColor(BuildContext context, _OpdTableItem item) {
  final ThemeData theme = Theme.of(context);
  final AppStatusColors statusColors = theme.statusColors;
  final Color color = switch (item.category) {
    _opdCategoryArrival => statusColors.infoContainer,
    _opdCategoryQueue => statusColors.warningContainer,
    _opdCategoryTriage => statusColors.errorContainer,
    _opdCategoryActiveFlow => statusColors.successContainer,
    _ => theme.colorScheme.surfaceContainerHighest,
  };
  return color.withValues(alpha: 0.42);
}

Color _stageTextColor(ThemeData theme, String? value) {
  final AppStatusColors statusColors = theme.statusColors;
  return switch (_stageTone(value)) {
    AppWorkspaceStatusTone.success => statusColors.success,
    AppWorkspaceStatusTone.warning => statusColors.warning,
    AppWorkspaceStatusTone.error => statusColors.error,
    AppWorkspaceStatusTone.info => statusColors.info,
    AppWorkspaceStatusTone.neutral => theme.colorScheme.onSurfaceVariant,
  };
}

enum _OpdVitalIndicatorState { normal, abnormal, critical }

int _abnormalVitalCount(
  OpdFlowDetail? detail,
  List<OpdClinicalAlertThreshold> thresholds,
) {
  if (detail == null) {
    return 0;
  }
  return detail.vitalMeasurements
      .where(
        (OpdVitalSign vital) =>
            _vitalIndicatorState(
              vital,
              thresholds,
              detail.clinicalAlertDetails,
            ) !=
            _OpdVitalIndicatorState.normal,
      )
      .length;
}

_OpdVitalIndicatorState _vitalIndicatorState(
  OpdVitalSign vital,
  List<OpdClinicalAlertThreshold> thresholds,
  List<OpdClinicalAlert> alerts,
) {
  final bool hasCriticalAlert = alerts.any(
    (OpdClinicalAlert alert) =>
        alert.vitalSignId == vital.id &&
        (alert.status ?? '').toUpperCase() != 'RESOLVED' &&
        (alert.severity ?? '').toUpperCase() == 'CRITICAL',
  );
  if (hasCriticalAlert) {
    return _OpdVitalIndicatorState.critical;
  }

  var state = _OpdVitalIndicatorState.normal;
  for (final OpdVitalComponentValue component in vital.componentValues) {
    final OpdClinicalAlertThreshold? threshold = _matchingThreshold(
      component,
      thresholds,
    );
    if (threshold == null) {
      continue;
    }

    final _OpdVitalIndicatorState next = _stateForThreshold(
      component.value,
      threshold,
    );
    if (next == _OpdVitalIndicatorState.critical) {
      return next;
    }
    if (next == _OpdVitalIndicatorState.abnormal) {
      state = next;
    }
  }

  if (state == _OpdVitalIndicatorState.normal) {
    final bool hasOpenAlert = alerts.any(
      (OpdClinicalAlert alert) =>
          alert.vitalSignId == vital.id &&
          (alert.status ?? '').toUpperCase() != 'RESOLVED',
    );
    if (hasOpenAlert) {
      return _OpdVitalIndicatorState.abnormal;
    }
  }

  return state;
}

OpdClinicalAlertThreshold? _matchingThreshold(
  OpdVitalComponentValue component,
  List<OpdClinicalAlertThreshold> thresholds,
) {
  for (final String ageBand in const <String>['ADULT', '']) {
    for (final OpdClinicalAlertThreshold threshold in thresholds) {
      if (!threshold.isActive) {
        continue;
      }
      if (threshold.vitalType != component.vitalType ||
          threshold.component != component.component) {
        continue;
      }
      if (ageBand.isNotEmpty && threshold.ageBand != ageBand) {
        continue;
      }
      return threshold;
    }
  }
  return null;
}

_OpdVitalIndicatorState _stateForThreshold(
  num value,
  OpdClinicalAlertThreshold threshold,
) {
  final num? criticalLow = threshold.criticalLow;
  final num? criticalHigh = threshold.criticalHigh;
  final num? normalMin = threshold.normalMin;
  final num? normalMax = threshold.normalMax;

  if (criticalLow != null && value < criticalLow) {
    return _OpdVitalIndicatorState.critical;
  }
  if (criticalHigh != null && value > criticalHigh) {
    return _OpdVitalIndicatorState.critical;
  }
  if (normalMin != null && value < normalMin) {
    return _OpdVitalIndicatorState.abnormal;
  }
  if (normalMax != null && value > normalMax) {
    return _OpdVitalIndicatorState.abnormal;
  }
  return _OpdVitalIndicatorState.normal;
}

AppWorkspaceStatusTone _alertTone(String? severity) {
  return switch ((severity ?? '').toUpperCase()) {
    'CRITICAL' => AppWorkspaceStatusTone.error,
    'HIGH' => AppWorkspaceStatusTone.warning,
    'MEDIUM' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _categoryLabel(BuildContext context, String category) {
  final l10n = context.l10n;
  return switch (category) {
    _opdCategoryArrival => l10n.opdArrivalsSummaryLabel,
    _opdCategoryQueue => l10n.opdQueueSummaryLabel,
    _opdCategoryTriage => l10n.opdWorkflowTriageTitle,
    _opdCategoryActiveFlow => l10n.opdActiveFlowSummaryLabel,
    _ => _apiLabel(category),
  };
}

AppWorkspaceStatusTone _categoryTone(String category) {
  return switch (category) {
    _opdCategoryArrival => AppWorkspaceStatusTone.info,
    _opdCategoryQueue => AppWorkspaceStatusTone.warning,
    _opdCategoryTriage => AppWorkspaceStatusTone.warning,
    _opdCategoryActiveFlow => AppWorkspaceStatusTone.success,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

class _ProviderSelectField extends StatelessWidget {
  const _ProviderSelectField({
    required this.value,
    required this.providers,
    required this.schedules,
    required this.labelText,
    required this.helperText,
    required this.emptyHelperText,
    required this.enabled,
    required this.isLoading,
    required this.onChanged,
  });

  final String? value;
  final List<OpdProviderOption> providers;
  final List<OpdProviderSchedule> schedules;
  final String labelText;
  final String helperText;
  final String emptyHelperText;
  final bool enabled;
  final bool isLoading;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<AppSelectOption<String>> options = _providerSelectOptions(
      providers: providers,
      schedules: schedules,
    );

    return AppSelectField<String>.searchable(
      value: value,
      options: options,
      labelText: labelText,
      helperText: options.isEmpty && !isLoading ? emptyHelperText : helperText,
      semanticLabel: labelText,
      enabled: enabled,
      isLoading: isLoading,
      onChanged: onChanged,
    );
  }
}

enum _WalkInPatientMode { existing, appointment, newPatient }

class _WalkInModeSelector extends StatelessWidget {
  const _WalkInModeSelector({
    required this.value,
    required this.enabled,
    required this.existingLabel,
    required this.appointmentLabel,
    required this.newPatientLabel,
    required this.onChanged,
  });

  final _WalkInPatientMode value;
  final bool enabled;
  final String existingLabel;
  final String appointmentLabel;
  final String newPatientLabel;
  final ValueChanged<_WalkInPatientMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SegmentedButton<_WalkInPatientMode>(
      expandedInsets: EdgeInsets.zero,
      segments: <ButtonSegment<_WalkInPatientMode>>[
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.existing,
          label: _WalkInTabLabel(existingLabel),
          icon: const Icon(Icons.badge_outlined),
        ),
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.appointment,
          label: _WalkInTabLabel(appointmentLabel),
          icon: const Icon(Icons.event_available_outlined),
        ),
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.newPatient,
          label: _WalkInTabLabel(newPatientLabel),
          icon: const Icon(Icons.person_add_alt_1_outlined),
        ),
      ],
      selected: <_WalkInPatientMode>{value},
      showSelectedIcon: false,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(Size(theme.spacing.none, 44)),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(),
        ),
      ),
      onSelectionChanged: enabled
          ? (Set<_WalkInPatientMode> selected) => onChanged(selected.first)
          : null,
    );
  }
}

class _WalkInTabLabel extends StatelessWidget {
  const _WalkInTabLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _WalkInSection extends StatelessWidget {
  const _WalkInSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: AppFormSection(
          title: title,
          density: AppFormSectionDensity.compact,
          children: children,
        ),
      ),
    );
  }
}

class _WalkInFieldRow extends StatelessWidget {
  const _WalkInFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked =
            !constraints.hasBoundedWidth || constraints.maxWidth < 560;
        if (stacked) {
          return Column(
            children: <Widget>[
              for (var index = 0; index < children.length; index += 1) ...[
                children[index],
                if (index < children.length - 1)
                  SizedBox(height: theme.appTokens.formGapCompact),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var index = 0; index < children.length; index += 1) ...[
              Expanded(child: children[index]),
              if (index < children.length - 1)
                SizedBox(width: theme.spacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _WalkInLowerSections extends StatelessWidget {
  const _WalkInLowerSections({
    required this.routingSection,
    required this.billingSection,
  });

  final Widget routingSection;
  final Widget billingSection;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked =
            !constraints.hasBoundedWidth || constraints.maxWidth < 760;
        if (stacked) {
          return AppFormSection(
            density: AppFormSectionDensity.compact,
            children: <Widget>[routingSection, billingSection],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: routingSection),
            SizedBox(width: theme.spacing.md),
            Expanded(child: billingSection),
          ],
        );
      },
    );
  }
}

typedef OpdPayloadSubmit =
    Future<AppFailure?> Function(Map<String, Object?> payload);

class StartWalkInDialog extends ConsumerStatefulWidget {
  const StartWalkInDialog({
    required this.providerSchedules,
    required this.appointments,
    required this.onSubmit,
    super.key,
  });

  final List<OpdProviderSchedule> providerSchedules;
  final List<OpdAppointment> appointments;
  final OpdPayloadSubmit onSubmit;

  @override
  ConsumerState<StartWalkInDialog> createState() => _StartWalkInDialogState();
}

class _StartWalkInDialogState extends ConsumerState<StartWalkInDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _feeController;
  late final TextEditingController _notesController;
  List<Patient> _patientOptions = const <Patient>[];
  List<OpdAppointment> _appointmentOptions = const <OpdAppointment>[];
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  _WalkInPatientMode _patientMode = _WalkInPatientMode.existing;
  bool _isLoadingPatients = false;
  bool _isLoadingAppointments = false;
  bool _isLoadingProviders = false;
  String? _patientId;
  String? _appointmentId;
  String? _providerId;
  String _currency = appDefaultCurrencyCode;
  String _arrivalMode = 'WALK_IN';
  String _emergencySeverity = 'HIGH';
  String? _triageLevel;
  String? _gender;
  bool _requireConsultationPayment = true;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _feeController = TextEditingController();
    _notesController = TextEditingController();
    _appointmentOptions = _eligibleAppointmentOptions(widget.appointments);
    unawaited(_loadPatientOptions());
    unawaited(_loadAppointmentOptions());
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.opdWalkInDialogTitle),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      scrollable: true,
      maxWidth: 880,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        formStatus: _failure == null
            ? null
            : AppFailureStateView(failure: _failure!),
        children: <Widget>[
          _WalkInSection(
            title: l10n.opdPatientSectionTitle,
            children: <Widget>[
              _WalkInModeSelector(
                value: _patientMode,
                enabled: !_isSaving,
                existingLabel: l10n.opdExistingPatientModeLabel,
                appointmentLabel: l10n.opdAppointmentPatientModeLabel,
                newPatientLabel: l10n.opdNewPatientModeLabel,
                onChanged: _setPatientMode,
              ),
              _patientModeContent(l10n),
            ],
          ),
          _WalkInLowerSections(
            routingSection: _routingSection(l10n),
            billingSection: _billingSection(l10n),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdStartWalkInAction,
          leadingIcon: Icons.play_arrow_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _routingSection(AppLocalizations l10n) {
    return _WalkInSection(
      title: l10n.opdRoutingSectionTitle,
      children: <Widget>[
        if (_patientMode != _WalkInPatientMode.appointment)
          AppSelectField<String>.searchable(
            value: _arrivalMode,
            labelText: _opdRequiredFieldLabel(l10n, l10n.opdArrivalModeLabel),
            semanticLabel: _opdRequiredFieldLabel(
              l10n,
              l10n.opdArrivalModeLabel,
            ),
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() {
                _arrivalMode = value ?? 'WALK_IN';
                _requireConsultationPayment = _arrivalMode != 'EMERGENCY';
              });
            },
            options: _statusOptions(_arrivalModeOptions),
          ),
        if (_arrivalMode == 'EMERGENCY' &&
            _patientMode != _WalkInPatientMode.appointment)
          _WalkInFieldRow(
            children: <Widget>[
              AppSelectField<String>.searchable(
                value: _emergencySeverity,
                labelText: _opdRequiredFieldLabel(
                  l10n,
                  l10n.opdEmergencySeverityLabel,
                ),
                semanticLabel: _opdRequiredFieldLabel(
                  l10n,
                  l10n.opdEmergencySeverityLabel,
                ),
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _emergencySeverity = value ?? _emergencySeverity;
                  });
                },
                options: _statusOptions(_emergencySeverityOptions),
              ),
              AppSelectField<String>.searchable(
                value: _triageLevel,
                labelText: _opdOptionalFieldLabel(
                  l10n,
                  l10n.opdTriageLevelLabel,
                ),
                semanticLabel: _opdOptionalFieldLabel(
                  l10n,
                  l10n.opdTriageLevelLabel,
                ),
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _triageLevel = value;
                  });
                },
                options: _statusOptions(_triageLevelOptions),
              ),
            ],
          ),
        _ProviderSelectField(
          value: _providerId,
          providers: _providerOptionsForDialog(),
          schedules: widget.providerSchedules,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdSearchProviderLabel),
          helperText: l10n.opdSearchProviderHelper,
          emptyHelperText: l10n.opdNoProvidersHelper,
          enabled: !_isSaving,
          isLoading: _isLoadingProviders,
          onChanged: (String? value) {
            setState(() {
              _providerId = value;
            });
          },
        ),
      ],
    );
  }

  Widget _billingSection(AppLocalizations l10n) {
    return _WalkInSection(
      title: l10n.opdBillingSectionTitle,
      children: <Widget>[
        AppCurrencyAmountField(
          amountController: _feeController,
          currency: _currency,
          amountLabelText: _opdOptionalFieldLabel(
            l10n,
            l10n.opdConsultationFeeLabel,
          ),
          currencyLabelText: _opdRequiredFieldLabel(
            l10n,
            l10n.opdCurrencyLabel,
          ),
          enabled: !_isSaving,
          onCurrencyChanged: (String? value) {
            setState(() {
              _currency = value ?? appDefaultCurrencyCode;
            });
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
          enabled: !_isSaving,
          maxLines: 3,
        ),
        AppSwitchField(
          title: l10n.opdPaymentRequiredLabel,
          value: _requireConsultationPayment,
          enabled: !_isSaving,
          secondary: const Icon(Icons.payments_outlined),
          onChanged: (bool value) {
            setState(() {
              _requireConsultationPayment = value;
            });
          },
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final AppFailure? failure = await widget.onSubmit(_payload());
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

  void _setPatientMode(_WalkInPatientMode mode) {
    setState(() {
      _patientMode = mode;
      if (mode == _WalkInPatientMode.appointment) {
        _arrivalMode = 'ONLINE_APPOINTMENT';
        _requireConsultationPayment = true;
      } else if (_arrivalMode == 'ONLINE_APPOINTMENT') {
        _arrivalMode = 'WALK_IN';
        _requireConsultationPayment = true;
      }
    });
  }

  Widget _patientModeContent(AppLocalizations l10n) {
    return switch (_patientMode) {
      _WalkInPatientMode.existing => AppSelectField<String>.searchable(
        value: _patientId,
        options: _patientOptions
            .map(_patientSelectOption)
            .whereType<AppSelectOption<String>>()
            .toList(growable: false),
        labelText: _opdRequiredFieldLabel(l10n, l10n.opdSearchPatientLabel),
        semanticLabel: _opdRequiredFieldLabel(l10n, l10n.opdSearchPatientLabel),
        isLoading: _isLoadingPatients,
        enabled: !_isSaving,
        onChanged: (String? value) {
          setState(() {
            _patientId = value;
          });
        },
        validator: (String? value) =>
            _patientMode != _WalkInPatientMode.existing || _isNonEmpty(value)
            ? null
            : l10n.validationRequired,
      ),
      _WalkInPatientMode.appointment => AppSelectField<String>.searchable(
        value: _appointmentId,
        options: _appointmentOptions
            .map(_appointmentSelectOption)
            .whereType<AppSelectOption<String>>()
            .toList(growable: false),
        labelText: _opdRequiredFieldLabel(
          l10n,
          l10n.opdAppointmentPatientLabel,
        ),
        helperText: l10n.opdAppointmentPatientHelper,
        semanticLabel: _opdRequiredFieldLabel(
          l10n,
          l10n.opdAppointmentPatientLabel,
        ),
        isLoading: _isLoadingAppointments,
        enabled: !_isSaving,
        onChanged: (String? value) {
          setState(() {
            _appointmentId = value;
            final OpdAppointment? appointment = _appointmentByApiId(value);
            _providerId = appointment?.providerUserId ?? _providerId;
          });
        },
        validator: (String? value) =>
            _patientMode != _WalkInPatientMode.appointment || _isNonEmpty(value)
            ? null
            : l10n.validationRequired,
      ),
      _WalkInPatientMode.newPatient => AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          _WalkInFieldRow(
            children: <Widget>[
              AppTextField(
                controller: _firstNameController,
                labelText: _opdRequiredFieldLabel(l10n, l10n.opdFirstNameLabel),
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                validator: (String? value) =>
                    _patientMode != _WalkInPatientMode.newPatient ||
                        _isNonEmpty(value)
                    ? null
                    : l10n.validationRequired,
              ),
              AppTextField(
                controller: _lastNameController,
                labelText: _opdRequiredFieldLabel(l10n, l10n.opdLastNameLabel),
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                validator: (String? value) =>
                    _patientMode != _WalkInPatientMode.newPatient ||
                        _isNonEmpty(value)
                    ? null
                    : l10n.validationRequired,
              ),
            ],
          ),
          AppGenderField(
            value: _gender,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdGenderLabel),
            maleLabel: l10n.patientsGenderMale,
            femaleLabel: l10n.patientsGenderFemale,
            otherLabel: l10n.patientsGenderOther,
            unknownLabel: l10n.patientsGenderUnknown,
            enabled: !_isSaving,
            onChanged: (String? value) => setState(() => _gender = value),
          ),
        ],
      ),
    };
  }

  Future<void> _loadPatientOptions() async {
    setState(() {
      _isLoadingPatients = true;
    });
    final Result<AppPage<Patient>> result = await ref
        .read(patientRepositoryProvider)
        .listPatients(
          const PatientListQuery(
            isActive: true,
            pageRequest: AppPageRequest(pageSize: 50),
          ),
        );
    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<Patient> page) {
        setState(() {
          _patientOptions = page.items;
          _isLoadingPatients = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingPatients = false;
        });
      },
    );
  }

  Future<void> _loadAppointmentOptions() async {
    setState(() {
      _isLoadingAppointments = true;
    });
    final Result<AppPage<OpdAppointment>> result = await ref
        .read(opdRepositoryProvider)
        .listAppointments(
          const OpdAppointmentQuery(pageRequest: AppPageRequest(pageSize: 50)),
        );
    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<OpdAppointment> page) {
        setState(() {
          _appointmentOptions = _eligibleAppointmentOptions(page.items);
          _isLoadingAppointments = false;
        });
      },
      failure: (_) {
        setState(() {
          _isLoadingAppointments = false;
        });
      },
    );
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
    });
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providerOptions = providers;
          _isLoadingProviders = false;
        });
      },
      failure: (_) {
        setState(() {
          _isLoadingProviders = false;
        });
      },
    );
  }

  List<OpdProviderOption> _providerOptionsForDialog() {
    final Map<String, OpdProviderOption> options = <String, OpdProviderOption>{
      for (final OpdProviderOption provider in _providerOptions)
        provider.id: provider,
    };

    for (final OpdAppointment appointment in _appointmentOptions) {
      final String? id = appointment.providerUserId;
      if (!_isNonEmpty(id) || options.containsKey(id)) {
        continue;
      }
      options[id!] = OpdProviderOption(
        id: id,
        displayName: appointment.providerDisplayName,
        facilityId: appointment.facilityId,
      );
    }

    return options.values.toList(growable: false);
  }

  Map<String, Object?> _payload() {
    final String notes = _notesController.text.trim();
    final String consultationFee = normalizeCurrencyAmount(_feeController.text);
    final String arrivalMode = _patientMode == _WalkInPatientMode.appointment
        ? 'ONLINE_APPOINTMENT'
        : _arrivalMode;
    final bool hasConsultationFee = consultationFee.isNotEmpty;

    return <String, Object?>{
      if (_patientMode == _WalkInPatientMode.newPatient)
        'patient_registration': <String, Object?>{
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'gender': _gender,
        }
      else if (_patientMode == _WalkInPatientMode.appointment)
        'appointment_id': _appointmentId
      else
        'patient_id': _patientId,
      'provider_user_id': _providerId,
      'arrival_mode': arrivalMode,
      if (arrivalMode == 'EMERGENCY')
        'emergency': <String, Object?>{
          'severity': _emergencySeverity,
          'triage_level': _triageLevel,
          'notes': notes,
        },
      'consultation_fee': consultationFee,
      'currency': _currency,
      'require_consultation_payment': _requireConsultationPayment,
      'create_consultation_invoice':
          hasConsultationFee || _requireConsultationPayment,
      'notes': notes,
    };
  }

  OpdAppointment? _appointmentByApiId(String? value) {
    if (!_isNonEmpty(value)) {
      return null;
    }

    for (final OpdAppointment appointment in _appointmentOptions) {
      if (appointment.publicId == value || appointment.id == value) {
        return appointment;
      }
    }
    return null;
  }
}

class AppointmentActionsDialog extends ConsumerStatefulWidget {
  const AppointmentActionsDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<AppointmentActionsDialog> createState() =>
      _AppointmentActionsDialogState();
}

class _AppointmentActionsDialogState
    extends ConsumerState<AppointmentActionsDialog> {
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String status = (widget.appointment.status ?? '').toUpperCase();
    final bool terminal = _isCompletedStatus(status);
    final bool canQueue =
        !terminal &&
        status != 'IN_PROGRESS' &&
        widget.appointment.patientId != null;
    final bool canCheckIn =
        !terminal && status != 'IN_PROGRESS' && status != 'COMPLETED';
    final bool canReschedule = !terminal;
    final bool canCancel = !terminal && status != 'CANCELLED';

    return AppDialog(
      title: Text(widget.appointment.displayTitle),
      icon: const Icon(Icons.event_available_outlined),
      scrollable: true,
      maxWidth: 680,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          _OpdWorkflowPanel(
            children: <Widget>[
              _OpdWorkflowInfoPill(
                label: l10n.opdStatusColumnLabel,
                value: _apiLabel(widget.appointment.status ?? ''),
              ),
              _OpdWorkflowInfoPill(
                label: l10n.opdProviderColumnLabel,
                value:
                    widget.appointment.providerDisplayName ??
                    l10n.profileUnknownValue,
              ),
              _OpdWorkflowInfoPill(
                label: l10n.opdTimeColumnLabel,
                value: _formatDateTime(
                  context,
                  widget.appointment.scheduledStart,
                ),
              ),
              _OpdWorkflowInfoPill(
                label: l10n.opdReasonLabel,
                value: widget.appointment.reason ?? l10n.profileUnknownValue,
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        if (canQueue)
          AppButton.secondary(
            label: l10n.opdQueueAction,
            leadingIcon: Icons.queue_outlined,
            isLoading: _isSaving,
            onPressed: () => _run(
              () => ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .assignAppointmentToQueue(widget.appointment),
            ),
          ),
        if (canReschedule)
          AppButton.secondary(
            label: l10n.opdRescheduleAction,
            leadingIcon: Icons.edit_calendar_outlined,
            enabled: !_isSaving,
            onPressed: _openReschedule,
          ),
        if (canCancel)
          AppButton.secondary(
            label: l10n.opdCancelAction,
            leadingIcon: Icons.cancel_outlined,
            isLoading: _isSaving,
            onPressed: _openCancel,
          ),
        if (canCheckIn)
          AppButton.primary(
            label: l10n.opdCheckInAction,
            leadingIcon: Icons.login_outlined,
            isLoading: _isSaving,
            onPressed: () => _run(
              () => ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .checkInAppointment(widget.appointment),
            ),
          ),
      ],
    );
  }

  Future<void> _openReschedule() async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          RescheduleAppointmentDialog(appointment: widget.appointment),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openCancel() async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CancelAppointmentDialog(appointment: widget.appointment),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _run(Future<AppFailure?> Function() action) async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await action();
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

class RescheduleAppointmentDialog extends ConsumerStatefulWidget {
  const RescheduleAppointmentDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<RescheduleAppointmentDialog> createState() =>
      _RescheduleAppointmentDialogState();
}

class _RescheduleAppointmentDialogState
    extends ConsumerState<RescheduleAppointmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late DateTime? _date;
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final DateTime start =
        widget.appointment.scheduledStart?.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));
    final DateTime end =
        widget.appointment.scheduledEnd?.toLocal() ??
        start.add(const Duration(minutes: 30));
    _date = DateTime(start.year, start.month, start.day);
    _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
    _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.opdRescheduleAction),
      icon: const Icon(Icons.edit_calendar_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppDateField(
              value: _date,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.patientsAppointmentDateLabel,
              ),
              pickerButtonLabel: l10n.patientsDatePickerAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              enabled: !_isSaving,
              isRequired: true,
              validator: (DateTime? value) =>
                  value == null ? l10n.validationRequired : null,
              onChanged: (DateTime? value) {
                setState(() => _date = value);
              },
            ),
            _WalkInFieldRow(
              children: <Widget>[
                AppTimeField(
                  value: _startTime,
                  labelText: _opdRequiredFieldLabel(
                    l10n,
                    l10n.opdAppointmentStartLabel,
                  ),
                  pickerButtonLabel: l10n.appTimePickerAction,
                  invalidTimeMessage: l10n.patientsTimeInvalidMessage,
                  hintText: l10n.patientsTimeHint,
                  enabled: !_isSaving,
                  isRequired: true,
                  validator: (TimeOfDay? value) =>
                      value == null ? l10n.validationRequired : null,
                  onChanged: (TimeOfDay? value) {
                    setState(() => _startTime = value);
                  },
                ),
                AppTimeField(
                  value: _endTime,
                  labelText: _opdRequiredFieldLabel(
                    l10n,
                    l10n.opdAppointmentEndLabel,
                  ),
                  pickerButtonLabel: l10n.appTimePickerAction,
                  invalidTimeMessage: l10n.patientsTimeInvalidMessage,
                  hintText: l10n.patientsTimeHint,
                  enabled: !_isSaving,
                  isRequired: true,
                  validator: (TimeOfDay? value) =>
                      value == null ? l10n.validationRequired : null,
                  onChanged: (TimeOfDay? value) {
                    setState(() => _endTime = value);
                  },
                ),
              ],
            ),
            AppButton.secondary(
              label: l10n.opdCancelAction,
              leadingIcon: Icons.cancel_outlined,
              enabled: !_isSaving,
              onPressed: _cancelPatient,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.opdRescheduleAction,
          leadingIcon: Icons.edit_calendar_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _cancelPatient() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .cancelAppointment(widget.appointment, null);
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final DateTime? start = _combineDateAndTime(_date, _startTime);
    final DateTime? end = _combineDateAndTime(_date, _endTime);
    if (start == null || end == null || !end.isAfter(start)) {
      setState(() {
        _failure = AppFailure.validation();
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .rescheduleAppointment(widget.appointment, start, end);
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

  DateTime? _combineDateAndTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class CancelAppointmentDialog extends ConsumerStatefulWidget {
  const CancelAppointmentDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<CancelAppointmentDialog> createState() =>
      _CancelAppointmentDialogState();
}

class _CancelAppointmentDialogState
    extends ConsumerState<CancelAppointmentDialog> {
  late final TextEditingController _reasonController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.opdCancelAction),
      icon: const Icon(Icons.cancel_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppTextField(
            controller: _reasonController,
            labelText: _opdOptionalFieldLabel(
              l10n,
              l10n.opdCancellationReasonLabel,
            ),
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdCancelAction,
          leadingIcon: Icons.cancel_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .cancelAppointment(widget.appointment, _reasonController.text.trim());
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

class QueueActionsDialog extends ConsumerStatefulWidget {
  const QueueActionsDialog({required this.entry, super.key});

  final OpdQueueEntry entry;

  @override
  ConsumerState<QueueActionsDialog> createState() => _QueueActionsDialogState();
}

class _QueueActionsDialogState extends ConsumerState<QueueActionsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  String? _status;
  String? _providerId;
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _status = widget.entry.status;
    _providerId = widget.entry.providerUserId;
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool terminal = _isCompletedStatus(widget.entry.status);

    return AppDialog(
      title: Text(widget.entry.displayTitle),
      icon: const Icon(Icons.queue_outlined),
      scrollable: true,
      maxWidth: 680,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            if (_successMessage != null)
              _InlineSuccessPanel(message: _successMessage!),
            _OpdWorkflowPanel(
              children: <Widget>[
                _OpdWorkflowInfoPill(
                  label: l10n.opdQueueStatusLabel,
                  value: _apiLabel(_status ?? widget.entry.status ?? ''),
                ),
                _OpdWorkflowInfoPill(
                  label: l10n.opdProviderColumnLabel,
                  value:
                      widget.entry.providerDisplayName ??
                      l10n.profileUnknownValue,
                ),
                _OpdWorkflowInfoPill(
                  label: l10n.opdTimeColumnLabel,
                  value: _formatDateTime(context, widget.entry.queuedAt),
                ),
              ],
            ),
            AppSelectField<String>(
              value: _status,
              labelText: _opdRequiredFieldLabel(l10n, l10n.opdQueueStatusLabel),
              enabled: !terminal && !_isSaving,
              onChanged: (String? value) => setState(() => _status = value),
              options: _statusOptions(_queueStatuses),
            ),
            _ProviderSelectField(
              value: _providerId,
              providers: _providerOptions,
              schedules: const <OpdProviderSchedule>[],
              labelText: _opdOptionalFieldLabel(
                l10n,
                l10n.opdSearchProviderLabel,
              ),
              helperText: l10n.opdSearchProviderHelper,
              emptyHelperText: l10n.opdNoProvidersHelper,
              enabled: !_isSaving,
              isLoading: _isLoadingProviders,
              onChanged: (String? value) {
                setState(() {
                  _providerId = value;
                });
              },
            ),
            AppTextField(
              controller: _reasonController,
              labelText: _opdOptionalFieldLabel(l10n, l10n.opdReasonLabel),
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (!terminal)
          AppButton.secondary(
            label: l10n.opdPrioritizeAction,
            leadingIcon: Icons.priority_high_outlined,
            isLoading: _isSaving,
            onPressed: () => _runInModal(
              action: () => ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .prioritizeQueueEntry(
                    widget.entry,
                    _reasonController.text.trim(),
                  ),
              successMessage: l10n.opdSavedMessage,
              successStatus: 'CONFIRMED',
            ),
          ),
        if (!terminal)
          AppButton.secondary(
            label: l10n.opdMoveQueueAction,
            leadingIcon: Icons.sync_alt_outlined,
            isLoading: _isSaving,
            onPressed: _submitMove,
          ),
        if (!terminal)
          AppButton.primary(
            label: l10n.opdStartConsultationAction,
            leadingIcon: Icons.play_arrow_outlined,
            isLoading: _isSaving,
            onPressed: () => _runInModal(
              action: () => ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .startOpdFromQueue(widget.entry),
              successMessage: l10n.opdStartConsultationAction,
              successStatus: 'IN_PROGRESS',
            ),
          ),
      ],
    );
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
    });
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providerOptions = providers;
          _isLoadingProviders = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingProviders = false;
        });
      },
    );
  }

  Future<void> _submitMove() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _runInModal(
      action: () => ref
          .read(opdWorkspaceControllerProvider.notifier)
          .moveQueueEntry(widget.entry, <String, Object?>{
            'status': _status,
            'provider_user_id': _providerId,
          }),
      successMessage: context.l10n.opdSavedMessage,
      successStatus: _status,
    );
  }

  Future<void> _runInModal({
    required Future<AppFailure?> Function() action,
    required String successMessage,
    String? successStatus,
  }) async {
    setState(() {
      _isSaving = true;
      _failure = null;
      _successMessage = null;
    });
    final AppFailure? failure = await action();
    if (!mounted) {
      return;
    }
    if (failure == null) {
      setState(() {
        _successMessage = successMessage;
        _status = successStatus ?? _status;
        _isSaving = false;
      });
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

const AccessRequirement _opdReceptionRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientWrite,
    AppPermissions.operationsWrite,
    AppPermissions.clinicalWrite,
    AppPermissions.emergencyWrite,
  ],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement _opdTriageRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.emergencyWrite,
  ],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement _opdDoctorRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement _opdBillingRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.billingWrite,
    AppPermissions.patientWrite,
  ],
  activeModules: <String>['scheduling-queue'],
);

class FlowActionsDialog extends ConsumerStatefulWidget {
  const FlowActionsDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<FlowActionsDialog> createState() => _FlowActionsDialogState();
}

class _FlowActionsDialogState extends ConsumerState<FlowActionsDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(opdWorkspaceControllerProvider.notifier)
            .selectFlow(widget.flow),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Result<OpdWorkspaceState>? workspaceResult = ref
        .watch(opdWorkspaceControllerProvider)
        .asData
        ?.value;
    final OpdWorkspaceState? workspaceState = workspaceResult?.when(
      success: (OpdWorkspaceState state) => state,
      failure: (_) => null,
    );
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    final OpdFlowDetail? detail =
        selected == null || !_isSameFlow(selected.summary, widget.flow)
        ? null
        : selected;
    final OpdFlowSummary flow = detail?.summary ?? widget.flow;

    return AppDialog(
      title: Text(flow.displayTitle),
      icon: const Icon(Icons.medical_services_outlined),
      maxWidth: 860,
      scrollable: true,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (detail == null) const LinearProgressIndicator(),
          _PatientText(
            title: _categoryLabel(context, _opdCategoryActiveFlow),
            subtitle: _joinDisplay(<String?>[
              _apiLabel(flow.stage ?? ''),
              flow.providerDisplayName,
              flow.patientPhone,
            ]),
          ),
          _OpdWorkflowStatusSummary(flow: flow, detail: detail),
          _OpdWorkflowRecordSummary(
            detail: detail,
            thresholds:
                workspaceState?.clinicalAlertThresholds ??
                const <OpdClinicalAlertThreshold>[],
          ),
          _OpdVitalIndicatorsPanel(
            detail: detail,
            thresholds:
                workspaceState?.clinicalAlertThresholds ??
                const <OpdClinicalAlertThreshold>[],
          ),
          ..._actionSections(context, flow, detail),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  List<Widget> _actionSections(
    BuildContext context,
    OpdFlowSummary flow,
    OpdFlowDetail? detail,
  ) {
    final l10n = context.l10n;
    final String stage = _normalizedStage(flow.stage);
    final bool terminal = flow.isTerminal;
    final bool consultationPaid = detail?.consultationPaid ?? false;
    final bool consultationPaymentRequired =
        detail?.consultationPaymentRequired ??
        stage == 'WAITING_CONSULTATION_PAYMENT';
    final bool canPay =
        !terminal &&
        !consultationPaid &&
        (stage == 'WAITING_CONSULTATION_PAYMENT' ||
            consultationPaymentRequired);

    final List<Widget> sections = <Widget>[];

    void addSection(String title, List<Widget> actions) {
      if (actions.isEmpty) {
        return;
      }
      sections.add(_OpdWorkflowSection(title: title, children: actions));
    }

    addSection(l10n.opdWorkflowReceptionTitle, <Widget>[
      if (canPay)
        _OpdWorkflowAction(
          requirement: _opdBillingRequirement,
          label: l10n.opdPayConsultationAction,
          icon: Icons.payments_outlined,
          onPressed: () =>
              _openNested(context, ConsultationPaymentDialog(flow: flow)),
        ),
      if (!terminal && _canAssignDoctor(stage))
        _OpdWorkflowAction(
          requirement: _opdReceptionRequirement,
          label: l10n.opdAssignDoctorAction,
          icon: Icons.assignment_ind_outlined,
          onPressed: () => _openNested(context, AssignDoctorDialog(flow: flow)),
        ),
    ]);

    addSection(l10n.opdWorkflowTriageTitle, <Widget>[
      if (!terminal && _canRecordVitals(stage))
        _OpdWorkflowAction(
          requirement: _opdTriageRequirement,
          label: l10n.opdRecordVitalsAction,
          icon: Icons.monitor_heart_outlined,
          onPressed: () => _openNested(context, RecordVitalsDialog(flow: flow)),
        ),
      if (!terminal && stage == 'WAITING_DOCTOR_ASSIGNMENT')
        _OpdWorkflowAction(
          requirement: _opdTriageRequirement,
          label: l10n.opdAssignDoctorAction,
          icon: Icons.assignment_ind_outlined,
          onPressed: () => _openNested(context, AssignDoctorDialog(flow: flow)),
        ),
      if (!terminal && stage == 'WAITING_DOCTOR_ASSIGNMENT')
        _OpdWorkflowAction(
          requirement: _opdTriageRequirement,
          label: l10n.opdRouteDecisionLabel,
          icon: Icons.alt_route_outlined,
          onPressed: () =>
              _openNested(context, RoutingDecisionDialog(flow: flow)),
        ),
    ]);

    addSection(l10n.opdWorkflowDoctorTitle, <Widget>[
      if (!terminal && stage == 'WAITING_DOCTOR_REVIEW')
        _OpdWorkflowAction(
          requirement: _opdDoctorRequirement,
          label: l10n.opdDoctorReviewAction,
          icon: Icons.edit_note_outlined,
          onPressed: () => _openNested(context, DoctorReviewDialog(flow: flow)),
        ),
      if (!terminal && _canDispose(stage))
        _OpdWorkflowAction(
          requirement: _opdDoctorRequirement,
          label: l10n.opdDispositionAction,
          icon: Icons.task_alt_outlined,
          onPressed: () => _openNested(
            context,
            OpdDispositionDialog(
              flow: flow,
              hasPharmacyOrder:
                  detail?.pharmacyOrders.isNotEmpty ??
                  stage == 'PHARMACY_REQUESTED',
            ),
          ),
        ),
      if (!terminal && (stage == 'WAITING_DOCTOR_REVIEW' || _canDispose(stage)))
        _OpdWorkflowAction(
          requirement: _opdDoctorRequirement,
          label: l10n.opdReferAction,
          icon: Icons.alt_route_outlined,
          onPressed: () => _openNested(context, ReferralDialog(flow: flow)),
        ),
      if (!terminal && (stage == 'WAITING_DOCTOR_REVIEW' || _canDispose(stage)))
        _OpdWorkflowAction(
          requirement: _opdDoctorRequirement,
          label: l10n.opdFollowUpAction,
          icon: Icons.event_repeat_outlined,
          onPressed: () => _openNested(context, FollowUpDialog(flow: flow)),
        ),
      _OpdWorkflowAction(
        requirement: _opdDoctorRequirement,
        label: l10n.opdCorrectStageAction,
        icon: Icons.sync_alt_outlined,
        onPressed: () => _openNested(context, CorrectStageDialog(flow: flow)),
      ),
    ]);

    addSection(l10n.opdWorkflowPrintTitle, <Widget>[
      _OpdWorkflowAction(
        requirement: _opdTriageRequirement,
        label: l10n.opdPrintSummaryAction,
        icon: Icons.print_outlined,
        onPressed: () => _openNested(
          context,
          PrintOpdSummaryDialog(flow: flow, detail: detail),
          closeParentOnChange: false,
        ),
      ),
    ]);

    return sections;
  }

  Future<void> _openNested(
    BuildContext context,
    Widget dialog, {
    bool closeParentOnChange = true,
  }) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
    if (changed == true && closeParentOnChange && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _OpdWorkflowStatusSummary extends StatelessWidget {
  const _OpdWorkflowStatusSummary({required this.flow, required this.detail});

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<Widget> children = <Widget>[
      _OpdWorkflowInfoPill(
        label: l10n.opdStageLabel,
        value: _apiLabel(flow.stage ?? ''),
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdNextStepColumnLabel,
        value: _apiLabel(flow.nextStep ?? ''),
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdPaymentStatusLabel,
        value: detail == null
            ? l10n.profileUnknownValue
            : detail!.consultationPaid
            ? l10n.opdPaymentPaidLabel
            : detail!.consultationPaymentRequired
            ? l10n.opdPaymentRequiredLabel
            : l10n.opdPaymentNotRequiredLabel,
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdProviderColumnLabel,
        value: flow.providerDisplayName ?? l10n.profileUnknownValue,
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdTriageLevelLabel,
        value: _apiLabel(flow.triageLevel ?? ''),
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdRouteDecisionLabel,
        value: _apiLabel(flow.lastRouteTo ?? ''),
      ),
      if (_isNonEmpty(flow.chiefComplaint))
        _OpdWorkflowInfoPill(
          label: l10n.opdChiefComplaintLabel,
          value: flow.chiefComplaint!,
        ),
    ];

    return _OpdWorkflowPanel(children: children);
  }
}

class _OpdWorkflowRecordSummary extends StatelessWidget {
  const _OpdWorkflowRecordSummary({
    required this.detail,
    required this.thresholds,
  });

  final OpdFlowDetail? detail;
  final List<OpdClinicalAlertThreshold> thresholds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final OpdFlowDetail? value = detail;
    final List<Widget> children = <Widget>[
      _OpdWorkflowInfoPill(
        label: l10n.opdVitalsSummaryLabel,
        value: '${value?.vitalSigns.length ?? 0}',
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdAbnormalVitalsSummaryLabel,
        value: '${_abnormalVitalCount(value, thresholds)}',
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdClinicalAlertsSummaryLabel,
        value: '${value?.clinicalAlerts.length ?? 0}',
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdServicesSummaryLabel,
        value:
            '${(value?.labOrders.length ?? 0) + (value?.radiologyOrders.length ?? 0) + (value?.pharmacyOrders.length ?? 0)}',
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdClinicalNotesSummaryLabel,
        value: '${value?.clinicalNotes.length ?? 0}',
      ),
      _OpdWorkflowInfoPill(
        label: l10n.opdProceduresSummaryLabel,
        value: '${value?.procedures.length ?? 0}',
      ),
    ];

    return _OpdWorkflowPanel(children: children);
  }
}

class _OpdWorkflowPanel extends StatelessWidget {
  const _OpdWorkflowPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double tileWidth = _responsiveTileWidth(
              availableWidth: constraints.maxWidth,
              itemCount: children.length,
              maxColumns: 4,
              spacing: theme.spacing.md,
              minWidth: 150,
            );
            return Wrap(
              spacing: theme.spacing.md,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                for (final Widget child in children)
                  SizedBox(width: tileWidth, child: child),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OpdVitalIndicatorsPanel extends StatelessWidget {
  const _OpdVitalIndicatorsPanel({
    required this.detail,
    required this.thresholds,
  });

  final OpdFlowDetail? detail;
  final List<OpdClinicalAlertThreshold> thresholds;

  @override
  Widget build(BuildContext context) {
    final OpdFlowDetail? value = detail;
    if (value == null ||
        (value.vitalMeasurements.isEmpty &&
            value.clinicalAlertDetails.isEmpty)) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final List<OpdVitalSign> vitals = value.vitalMeasurements;
    final List<OpdClinicalAlert> alerts = value.clinicalAlertDetails;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  context.l10n.opdVitalsSummaryLabel,
                  style: theme.textTheme.titleSmall,
                ),
                _StatusBadge(
                  value: _abnormalVitalCount(value, thresholds) > 0
                      ? 'ABNORMAL'
                      : 'NORMAL',
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            for (final OpdVitalSign vital in vitals)
              _OpdVitalIndicatorRow(
                vital: vital,
                state: _vitalIndicatorState(vital, thresholds, alerts),
              ),
            if (alerts.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Text(
                context.l10n.opdClinicalAlertsSummaryLabel,
                style: theme.textTheme.labelMedium,
              ),
              SizedBox(height: theme.spacing.xs),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  for (final OpdClinicalAlert alert in alerts)
                    AppWorkspaceStatusBadge(
                      status: AppWorkspaceStatus(
                        label: _joinDisplay(<String?>[
                          _apiLabel(alert.severity ?? ''),
                          alert.message,
                        ]),
                        tone: _alertTone(alert.severity),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OpdVitalIndicatorRow extends StatelessWidget {
  const _OpdVitalIndicatorRow({required this.vital, required this.state});

  final OpdVitalSign vital;
  final _OpdVitalIndicatorState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _joinDisplay(<String?>[
                _apiLabel(vital.vitalType),
                vital.displayValue,
              ]),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: _apiLabel(state.name.toUpperCase()),
              tone: switch (state) {
                _OpdVitalIndicatorState.critical =>
                  AppWorkspaceStatusTone.error,
                _OpdVitalIndicatorState.abnormal =>
                  AppWorkspaceStatusTone.warning,
                _OpdVitalIndicatorState.normal =>
                  AppWorkspaceStatusTone.success,
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OpdWorkflowInfoPill extends StatelessWidget {
  const _OpdWorkflowInfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelMedium),
        SizedBox(height: theme.spacing.xs),
        Text(
          value.isEmpty ? context.l10n.profileUnknownValue : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OpdWorkflowSection extends StatelessWidget {
  const _OpdWorkflowSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleSmall),
            SizedBox(height: theme.spacing.sm),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double tileWidth = _responsiveTileWidth(
                  availableWidth: constraints.maxWidth,
                  itemCount: children.length,
                  maxColumns: 3,
                  spacing: theme.spacing.sm,
                  minWidth: 190,
                );
                return Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.sm,
                  children: <Widget>[
                    for (final Widget child in children)
                      SizedBox(width: tileWidth, child: child),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OpdWorkflowAction extends StatelessWidget {
  const _OpdWorkflowAction({
    required this.requirement,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final AccessRequirement requirement;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppAccessActionGate(
      requirement: requirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return const SizedBox.shrink();
        }
        return AppButton.secondary(
          label: label,
          leadingIcon: icon,
          fullWidth: true,
          onPressed: onPressed,
        );
      },
    );
  }
}

double _responsiveTileWidth({
  required double availableWidth,
  required int itemCount,
  required int maxColumns,
  required double spacing,
  required double minWidth,
}) {
  if (!availableWidth.isFinite || availableWidth <= 0) {
    return minWidth;
  }

  final int maxUsableColumns = itemCount.clamp(1, maxColumns).toInt();
  int columns = maxUsableColumns;
  while (columns > 1) {
    final double candidate =
        (availableWidth - spacing * (columns - 1)) / columns;
    if (candidate >= minWidth) {
      return candidate;
    }
    columns -= 1;
  }
  return availableWidth;
}

bool _isSameFlow(OpdFlowSummary left, OpdFlowSummary right) {
  return left.id == right.id ||
      (left.publicId != null && left.publicId == right.publicId);
}

String _normalizedStage(String? stage) {
  return (stage ?? '').trim().toUpperCase();
}

bool _canRecordVitals(String stage) {
  return stage == 'WAITING_VITALS' || stage == 'WAITING_DOCTOR_ASSIGNMENT';
}

bool _canAssignDoctor(String stage) {
  return stage == 'WAITING_DOCTOR_ASSIGNMENT' ||
      stage == 'WAITING_DOCTOR_REVIEW';
}

bool _canDispose(String stage) {
  return stage == 'WAITING_DISPOSITION' ||
      stage == 'LAB_REQUESTED' ||
      stage == 'RADIOLOGY_REQUESTED' ||
      stage == 'LAB_AND_RADIOLOGY_REQUESTED' ||
      stage == 'PHARMACY_REQUESTED';
}

class RecordVitalsDialog extends ConsumerStatefulWidget {
  const RecordVitalsDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<RecordVitalsDialog> createState() => _RecordVitalsDialogState();
}

class _RecordVitalsDialogState extends ConsumerState<RecordVitalsDialog> {
  late final TextEditingController _chiefComplaintController;
  late final TextEditingController _symptomsController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _oxygenSaturationController;
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;
  String? _triageLevel;
  String? _painSeverity;
  String? _routeDecision;
  String? _providerId;
  final Set<String> _riskFlags = <String>{};
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  bool _emergencyIndicator = false;
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _chiefComplaintController = TextEditingController(
      text: widget.flow.chiefComplaint ?? '',
    );
    _symptomsController = TextEditingController();
    _allergiesController = TextEditingController();
    _temperatureController = TextEditingController();
    _systolicController = TextEditingController();
    _diastolicController = TextEditingController();
    _heartRateController = TextEditingController();
    _respiratoryRateController = TextEditingController();
    _oxygenSaturationController = TextEditingController();
    _weightController = TextEditingController();
    _notesController = TextEditingController();
    _triageLevel = widget.flow.triageLevel;
    _providerId = widget.flow.providerUserId;
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _symptomsController.dispose();
    _allergiesController.dispose();
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdRecordVitalsAction),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          Text(
            l10n.opdVitalsAtLeastOneRequiredHelper,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          AppTextField(
            controller: _chiefComplaintController,
            labelText: _opdOptionalFieldLabel(
              l10n,
              l10n.opdChiefComplaintLabel,
            ),
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppTextField(
            controller: _symptomsController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdSymptomsLabel),
            enabled: !_isSaving,
            maxLines: 2,
          ),
          _WalkInFieldRow(
            children: <Widget>[
              AppSelectField<String>.searchable(
                value: _painSeverity,
                labelText: _opdOptionalFieldLabel(
                  l10n,
                  l10n.opdPainSeverityLabel,
                ),
                semanticLabel: _opdOptionalFieldLabel(
                  l10n,
                  l10n.opdPainSeverityLabel,
                ),
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() => _painSeverity = value);
                },
                options: _painSeverityOptions,
              ),
              AppTextField(
                controller: _allergiesController,
                labelText: _opdOptionalFieldLabel(l10n, l10n.opdAllergiesLabel),
                enabled: !_isSaving,
              ),
            ],
          ),
          AppSwitchField(
            title: l10n.opdEmergencyIndicatorsLabel,
            value: _emergencyIndicator,
            enabled: !_isSaving,
            secondary: const Icon(Icons.emergency_outlined),
            onChanged: (bool value) {
              setState(() {
                _emergencyIndicator = value;
                if (value && _triageLevel == null) {
                  _triageLevel = 'LEVEL_1';
                }
                if (value && _routeDecision == null) {
                  _routeDecision = 'EMERGENCY';
                }
              });
            },
          ),
          _TriageRiskFlags(
            selected: _riskFlags,
            enabled: !_isSaving,
            onChanged: _setRiskFlag,
          ),
          AppSelectField<String>.searchable(
            value: _triageLevel,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdTriageLevelLabel),
            semanticLabel: _opdOptionalFieldLabel(
              l10n,
              l10n.opdTriageLevelLabel,
            ),
            enabled: !_isSaving,
            onChanged: (String? value) => setState(() => _triageLevel = value),
            options: _statusOptions(_triageLevelOptions),
          ),
          AppSelectField<String>.searchable(
            value: _routeDecision ?? _opdNoRouteDecisionValue,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdRouteDecisionLabel),
            semanticLabel: _opdOptionalFieldLabel(
              l10n,
              l10n.opdRouteDecisionLabel,
            ),
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() {
                _routeDecision =
                    value == null || value == _opdNoRouteDecisionValue
                    ? null
                    : value;
              });
            },
            options: _routeDecisionOptions(context),
          ),
          if (_routeDecision == 'CONSULTATION')
            _ProviderSelectField(
              value: _providerId,
              providers: _providerOptions,
              schedules: const <OpdProviderSchedule>[],
              labelText: _opdOptionalFieldLabel(
                l10n,
                l10n.opdSearchProviderLabel,
              ),
              helperText: l10n.opdSearchProviderHelper,
              emptyHelperText: l10n.opdNoProvidersHelper,
              enabled: !_isSaving,
              isLoading: _isLoadingProviders,
              onChanged: (String? value) {
                setState(() => _providerId = value);
              },
            ),
          AppVitalsForm(
            temperatureController: _temperatureController,
            systolicController: _systolicController,
            diastolicController: _diastolicController,
            heartRateController: _heartRateController,
            respiratoryRateController: _respiratoryRateController,
            oxygenSaturationController: _oxygenSaturationController,
            weightController: _weightController,
            temperatureLabel: _opdOptionalFieldLabel(
              l10n,
              l10n.opdTemperatureLabel,
            ),
            systolicLabel: _opdOptionalFieldLabel(l10n, l10n.opdSystolicLabel),
            diastolicLabel: _opdOptionalFieldLabel(
              l10n,
              l10n.opdDiastolicLabel,
            ),
            heartRateLabel: _opdOptionalFieldLabel(
              l10n,
              l10n.opdHeartRateLabel,
            ),
            respiratoryRateLabel: _opdOptionalFieldLabel(
              l10n,
              l10n.opdRespiratoryRateLabel,
            ),
            oxygenSaturationLabel: _opdOptionalFieldLabel(
              l10n,
              l10n.opdOxygenSaturationLabel,
            ),
            weightLabel: _opdOptionalFieldLabel(l10n, l10n.opdWeightLabel),
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _notesController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdTriageNotesLabel),
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdRecordVitalsAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final List<Map<String, Object?>> vitals = _vitalsPayload();
    if (vitals.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    if (!_hasCompleteBloodPressureInput()) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    if (_routeDecision == 'CONSULTATION' &&
        !_isNonEmpty(_providerId ?? widget.flow.providerUserId)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final String triageNotes = _triageNotesPayload(context.l10n);
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .recordVitals(widget.flow, <String, Object?>{
          'vitals': vitals,
          'triage_level': _triageLevel,
          'triage_priority': _triageLevel,
          'chief_complaint': _chiefComplaintController.text.trim(),
          'emergency': _emergencyIndicator,
          'triage_notes': triageNotes,
        });
    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _failure = failure;
        _isSaving = false;
      });
      return;
    }

    final String? routeDecision = _routeDecision;
    if (_isNonEmpty(routeDecision)) {
      final AppFailure? routeFailure = await ref
          .read(opdWorkspaceControllerProvider.notifier)
          .disposeFlow(
            widget.flow,
            routeDecision!.trim(),
            triageNotes,
            providerUserId: _providerId,
            triageLevel: _triageLevel,
            emergency: _emergencyIndicator,
          );
      if (!mounted) {
        return;
      }
      if (routeFailure != null) {
        setState(() {
          _failure = routeFailure;
          _isSaving = false;
        });
        return;
      }
    }

    Navigator.of(context).pop(true);
  }

  List<Map<String, Object?>> _vitalsPayload() {
    final List<Map<String, Object?>> vitals = <Map<String, Object?>>[];
    void addSimpleVital(
      TextEditingController controller,
      String type,
      String unit,
    ) {
      final String value = controller.text.trim();
      if (value.isEmpty) {
        return;
      }
      vitals.add(<String, Object?>{
        'vital_type': type,
        'value': value,
        'unit': unit,
      });
    }

    addSimpleVital(_temperatureController, 'TEMPERATURE', 'C');
    final String systolic = _systolicController.text.trim();
    final String diastolic = _diastolicController.text.trim();
    if (systolic.isNotEmpty && diastolic.isNotEmpty) {
      vitals.add(<String, Object?>{
        'vital_type': 'BLOOD_PRESSURE',
        'value': '$systolic/$diastolic',
        'unit': 'mmHg',
        'systolic_value': systolic,
        'diastolic_value': diastolic,
      });
    }
    addSimpleVital(_heartRateController, 'HEART_RATE', 'bpm');
    addSimpleVital(
      _respiratoryRateController,
      'RESPIRATORY_RATE',
      'breaths/min',
    );
    addSimpleVital(_oxygenSaturationController, 'OXYGEN_SATURATION', '%');
    addSimpleVital(_weightController, 'WEIGHT', 'kg');
    return vitals;
  }

  bool _hasCompleteBloodPressureInput() {
    final bool hasSystolic = _systolicController.text.trim().isNotEmpty;
    final bool hasDiastolic = _diastolicController.text.trim().isNotEmpty;
    return hasSystolic == hasDiastolic;
  }

  void _setRiskFlag(String flag, bool selected) {
    setState(() {
      if (selected) {
        _riskFlags.add(flag);
      } else {
        _riskFlags.remove(flag);
      }
    });
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
    });
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providerOptions = providers;
          _isLoadingProviders = false;
        });
      },
      failure: (_) {
        setState(() {
          _isLoadingProviders = false;
        });
      },
    );
  }

  String _triageNotesPayload(AppLocalizations l10n) {
    final List<String> lines = <String>[];
    void add(String label, String value) {
      final String normalized = value.trim();
      if (normalized.isNotEmpty) {
        lines.add('$label: $normalized');
      }
    }

    add(l10n.opdSymptomsLabel, _symptomsController.text);
    add(l10n.opdPainSeverityLabel, _painSeverity ?? '');
    add(l10n.opdAllergiesLabel, _allergiesController.text);
    if (_riskFlags.isNotEmpty) {
      lines.add(
        '${l10n.opdRiskFlagsLabel}: ${_riskFlags.map((String flag) => _riskFlagLabel(l10n, flag)).join(', ')}',
      );
    }
    add(l10n.opdTriageNotesLabel, _notesController.text);
    return lines.join('\n');
  }
}

class _TriageRiskFlags extends StatelessWidget {
  const _TriageRiskFlags({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final Set<String> selected;
  final bool enabled;
  final void Function(String flag, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: AppFormSection(
          title: l10n.opdRiskFlagsLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double tileWidth = _responsiveTileWidth(
                  availableWidth: constraints.maxWidth,
                  itemCount: _triageRiskFlagOptions.length,
                  maxColumns: 2,
                  spacing: theme.spacing.sm,
                  minWidth: 220,
                );
                return Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    for (final String flag in _triageRiskFlagOptions)
                      SizedBox(
                        width: tileWidth,
                        child: AppCheckboxField(
                          title: _riskFlagLabel(l10n, flag),
                          value: selected.contains(flag),
                          enabled: enabled,
                          onChanged: (bool value) => onChanged(flag, value),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _riskFlagLabel(AppLocalizations l10n, String flag) {
  return switch (flag) {
    _riskFlagFall => l10n.opdRiskFlagFall,
    _riskFlagPregnancy => l10n.opdRiskFlagPregnancy,
    _riskFlagInfection => l10n.opdRiskFlagInfection,
    _riskFlagAlteredMentalState => l10n.opdRiskFlagAlteredMentalState,
    _riskFlagBleeding => l10n.opdRiskFlagBleeding,
    _ => _apiLabel(flag),
  };
}

List<AppSelectOption<String>> _routeDecisionOptions(BuildContext context) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: _opdNoRouteDecisionValue,
      label: context.l10n.opdNoRouteDecisionLabel,
    ),
    ..._statusOptions(_triageRouteOptions),
  ];
}

final List<AppSelectOption<String>> _painSeverityOptions =
    List<AppSelectOption<String>>.unmodifiable(<AppSelectOption<String>>[
      for (int value = 0; value <= 10; value += 1)
        AppSelectOption<String>(value: '$value', label: value.toString()),
    ]);

class DoctorReviewDialog extends ConsumerStatefulWidget {
  const DoctorReviewDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<DoctorReviewDialog> createState() => _DoctorReviewDialogState();
}

class _DoctorReviewDialogState extends ConsumerState<DoctorReviewDialog> {
  late final TextEditingController _noteController;
  late final TextEditingController _diagnosisCodeController;
  late final TextEditingController _diagnosisController;
  late final TextEditingController _procedureCodeController;
  late final TextEditingController _procedureController;
  late final TextEditingController _labTestIdsController;
  late final TextEditingController _labPanelIdsController;
  late final TextEditingController _radiologyIdsController;
  late final TextEditingController _quantityController;
  late final TextEditingController _dosageController;
  late final TextEditingController _prescriptionNotesController;
  List<OpdDrugOption> _drugOptions = const <OpdDrugOption>[];
  bool _isLoadingDrugs = false;
  String _diagnosisType = 'PRIMARY';
  String? _drugId;
  String? _frequency;
  String? _route;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _diagnosisCodeController = TextEditingController();
    _diagnosisController = TextEditingController();
    _procedureCodeController = TextEditingController();
    _procedureController = TextEditingController();
    _labTestIdsController = TextEditingController();
    _labPanelIdsController = TextEditingController();
    _radiologyIdsController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _dosageController = TextEditingController();
    _prescriptionNotesController = TextEditingController();
    unawaited(_loadDrugs());
  }

  @override
  void dispose() {
    _noteController.dispose();
    _diagnosisCodeController.dispose();
    _diagnosisController.dispose();
    _procedureCodeController.dispose();
    _procedureController.dispose();
    _labTestIdsController.dispose();
    _labPanelIdsController.dispose();
    _radiologyIdsController.dispose();
    _quantityController.dispose();
    _dosageController.dispose();
    _prescriptionNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Result<OpdWorkspaceState>? workspaceResult = ref
        .watch(opdWorkspaceControllerProvider)
        .asData
        ?.value;
    final OpdWorkspaceState? workspaceState = workspaceResult?.when(
      success: (OpdWorkspaceState state) => state,
      failure: (_) => null,
    );
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    final OpdFlowDetail? detail =
        selected == null || !_isSameFlow(selected.summary, widget.flow)
        ? null
        : selected;
    final OpdFlowSummary flow = detail?.summary ?? widget.flow;

    return AppDialog(
      title: Text(l10n.opdDoctorReviewAction),
      icon: const Icon(Icons.edit_note_outlined),
      maxWidth: 760,
      scrollable: true,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          _OpdWorkflowStatusSummary(flow: flow, detail: detail),
          _OpdVitalIndicatorsPanel(
            detail: detail,
            thresholds:
                workspaceState?.clinicalAlertThresholds ??
                const <OpdClinicalAlertThreshold>[],
          ),
          AppTextField(
            controller: _noteController,
            labelText: _opdRequiredFieldLabel(l10n, l10n.opdClinicalNoteLabel),
            enabled: !_isSaving,
            maxLines: 4,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppSelectField<String>.searchable(
            value: _diagnosisType,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdDiagnosisTypeLabel),
            semanticLabel: _opdOptionalFieldLabel(
              l10n,
              l10n.opdDiagnosisTypeLabel,
            ),
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() => _diagnosisType = value ?? _diagnosisType);
            },
            options: _statusOptions(_diagnosisTypes),
          ),
          AppTextField(
            controller: _diagnosisController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdDiagnosisLabel),
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppTextField(
            controller: _diagnosisCodeController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdDiagnosisCodeLabel),
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _procedureController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdProcedureLabel),
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppTextField(
            controller: _procedureCodeController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdProcedureCodeLabel),
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _labTestIdsController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdLabTestIdsLabel),
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppTextField(
            controller: _labPanelIdsController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdLabPanelIdsLabel),
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppTextField(
            controller: _radiologyIdsController,
            labelText: _opdOptionalFieldLabel(
              l10n,
              l10n.opdRadiologyTestIdsLabel,
            ),
            enabled: !_isSaving,
            maxLines: 2,
          ),
          AppSelectField<String>.searchable(
            value: _drugId,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdDrugLabel),
            semanticLabel: _opdOptionalFieldLabel(l10n, l10n.opdDrugLabel),
            enabled: !_isSaving,
            isLoading: _isLoadingDrugs,
            onChanged: (String? value) => setState(() => _drugId = value),
            options: _drugOptions.map(_drugOption).toList(growable: false),
          ),
          _WalkInFieldRow(
            children: <Widget>[
              AppTextField(
                controller: _quantityController,
                labelText: _opdOptionalFieldLabel(
                  l10n,
                  l10n.opdDrugQuantityLabel,
                ),
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: _integerInputFormatters,
              ),
              AppTextField(
                controller: _dosageController,
                labelText: _opdOptionalFieldLabel(l10n, l10n.opdDosageLabel),
                enabled: !_isSaving,
              ),
            ],
          ),
          AppSelectField<String>.searchable(
            value: _frequency,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdFrequencyLabel),
            semanticLabel: _opdOptionalFieldLabel(l10n, l10n.opdFrequencyLabel),
            enabled: !_isSaving,
            onChanged: (String? value) => setState(() => _frequency = value),
            options: _statusOptions(_medicationFrequencies),
          ),
          AppSelectField<String>.searchable(
            value: _route,
            labelText: _opdOptionalFieldLabel(
              l10n,
              l10n.opdMedicationRouteLabel,
            ),
            semanticLabel: _opdOptionalFieldLabel(
              l10n,
              l10n.opdMedicationRouteLabel,
            ),
            enabled: !_isSaving,
            onChanged: (String? value) => setState(() => _route = value),
            options: _statusOptions(_medicationRoutes),
          ),
          AppTextField(
            controller: _prescriptionNotesController,
            labelText: _opdOptionalFieldLabel(
              l10n,
              l10n.opdPrescriptionNotesLabel,
            ),
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdDoctorReviewAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _loadDrugs() async {
    setState(() => _isLoadingDrugs = true);
    final Result<List<OpdDrugOption>> result = await ref
        .read(opdRepositoryProvider)
        .listAvailableDrugs();
    if (!mounted) {
      return;
    }
    result.when(
      success: (List<OpdDrugOption> drugs) {
        setState(() {
          _drugOptions = drugs;
          _isLoadingDrugs = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingDrugs = false;
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!_isNonEmpty(_noteController.text)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    final Map<String, Object?> payload = _payload();
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .doctorReview(widget.flow, payload);
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

  Map<String, Object?> _payload() {
    final List<Map<String, Object?>> labRequests = <Map<String, Object?>>[
      for (final String id in _splitTokens(_labTestIdsController.text))
        <String, Object?>{'lab_test_id': id, 'status': 'ORDERED'},
      for (final String id in _splitTokens(_labPanelIdsController.text))
        <String, Object?>{'lab_panel_id': id, 'status': 'ORDERED'},
    ];
    final List<Map<String, Object?>> radiologyRequests = <Map<String, Object?>>[
      for (final String id in _splitTokens(_radiologyIdsController.text))
        <String, Object?>{'radiology_test_id': id, 'status': 'ORDERED'},
    ];
    final String? drugId = _drugId;
    final int quantity = int.tryParse(_quantityController.text.trim()) ?? 1;

    return <String, Object?>{
      'note': _noteController.text.trim(),
      if (_isNonEmpty(_diagnosisController.text))
        'diagnoses': <Map<String, Object?>>[
          <String, Object?>{
            'diagnosis_type': _diagnosisType,
            'code': _diagnosisCodeController.text.trim(),
            'description': _diagnosisController.text.trim(),
          },
        ],
      if (_isNonEmpty(_procedureController.text))
        'procedures': <Map<String, Object?>>[
          <String, Object?>{
            'code': _procedureCodeController.text.trim(),
            'description': _procedureController.text.trim(),
            'performed_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      if (labRequests.isNotEmpty) 'lab_requests': labRequests,
      if (radiologyRequests.isNotEmpty) 'radiology_requests': radiologyRequests,
      if (_isNonEmpty(drugId))
        'medications': <Map<String, Object?>>[
          <String, Object?>{
            'drug_id': drugId,
            'quantity': quantity,
            'dosage': _dosageController.text.trim(),
            'frequency': _frequency,
            'route': _route,
            'status': 'ACTIVE',
          },
        ],
      'notes': _prescriptionNotesController.text.trim(),
    };
  }
}

class PrintOpdSummaryDialog extends StatelessWidget {
  const PrintOpdSummaryDialog({
    required this.flow,
    required this.detail,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String summary = _printSummary(context);
    return AppDialog(
      title: Text(l10n.opdPrintSummaryAction),
      icon: const Icon(Icons.print_outlined),
      maxWidth: 720,
      scrollable: true,
      content: AppReportPreviewPanel(
        selectable: true,
        child: Text(summary, style: Theme.of(context).textTheme.bodyMedium),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppReportActionButton.copy(
          label: l10n.opdCopySummaryAction,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: summary));
            if (context.mounted) {
              Navigator.of(context).pop(false);
            }
          },
        ),
        AppReportActionButton.print(
          label: l10n.opdPrintAction,
          onPressed: () {
            printCurrentWindow();
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }

  String _printSummary(BuildContext context) {
    final l10n = context.l10n;
    final OpdFlowDetail? value = detail;
    final List<String> lines = <String>[
      flow.displayTitle,
      _joinDisplay(<String?>[
        flow.patientIdentifier,
        flow.patientPhone,
        flow.providerDisplayName,
      ]),
      '${l10n.opdStageLabel}: ${_apiLabel(flow.stage ?? '')}',
      '${l10n.opdNextStepColumnLabel}: ${_apiLabel(flow.nextStep ?? '')}',
      '${l10n.opdTriageLevelLabel}: ${_apiLabel(flow.triageLevel ?? '')}',
      '${l10n.opdRouteDecisionLabel}: ${_apiLabel(flow.lastRouteTo ?? '')}',
      if (_isNonEmpty(flow.chiefComplaint))
        '${l10n.opdChiefComplaintLabel}: ${flow.chiefComplaint}',
      '${l10n.opdPaymentStatusLabel}: ${value == null
          ? l10n.profileUnknownValue
          : value.consultationPaid
          ? l10n.opdPaymentPaidLabel
          : value.consultationPaymentRequired
          ? l10n.opdPaymentRequiredLabel
          : l10n.opdPaymentNotRequiredLabel}',
      '${l10n.opdVitalsSummaryLabel}: ${value?.vitalSigns.length ?? 0}',
      '${l10n.opdClinicalNotesSummaryLabel}: ${value?.clinicalNotes.length ?? 0}',
      '${l10n.opdServicesSummaryLabel}: ${(value?.labOrders.length ?? 0) + (value?.radiologyOrders.length ?? 0) + (value?.pharmacyOrders.length ?? 0)}',
      if (value != null && value.vitalSigns.isNotEmpty) '',
      if (value != null && value.vitalSigns.isNotEmpty)
        l10n.opdVitalsSummaryLabel,
      if (value != null)
        for (final OpdRelatedRecord vital in value.vitalSigns)
          _joinDisplay(<String?>[vital.title, vital.subtitle]),
      if (value != null && value.timeline.isNotEmpty) '',
      if (value != null && value.timeline.isNotEmpty) l10n.opdTimelineTitle,
      if (value != null)
        for (final OpdTimelineItem item in value.timeline)
          _joinDisplay(<String?>[
            _apiLabel(item.action),
            _apiLabel(item.stage ?? ''),
            item.notes,
          ]),
    ];
    return lines.where((String line) => line.trim().isNotEmpty).join('\n');
  }
}

class AssignDoctorDialog extends ConsumerStatefulWidget {
  const AssignDoctorDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<AssignDoctorDialog> createState() => _AssignDoctorDialogState();
}

class _AssignDoctorDialogState extends ConsumerState<AssignDoctorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  String? _providerId;
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _providerId = widget.flow.providerUserId;
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdAssignDoctorAction),
      icon: const Icon(Icons.assignment_ind_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            _ProviderSelectField(
              value: _providerId,
              providers: _providerOptions,
              schedules: const <OpdProviderSchedule>[],
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdSearchProviderLabel,
              ),
              helperText: l10n.opdSearchProviderHelper,
              emptyHelperText: l10n.opdNoProvidersHelper,
              enabled: !_isSaving,
              isLoading: _isLoadingProviders,
              onChanged: (String? value) {
                setState(() {
                  _providerId = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdAssignDoctorAction,
          leadingIcon: Icons.assignment_ind_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
    });
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providerOptions = providers;
          _isLoadingProviders = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingProviders = false;
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? providerId = _providerId;
    if (!_isNonEmpty(providerId)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .assignDoctor(widget.flow, providerId!.trim());
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

class ConsultationPaymentDialog extends ConsumerStatefulWidget {
  const ConsultationPaymentDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<ConsultationPaymentDialog> createState() =>
      _ConsultationPaymentDialogState();
}

class _ConsultationPaymentDialogState
    extends ConsumerState<ConsultationPaymentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;
  String _currency = appDefaultCurrencyCode;
  String _method = 'CASH';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _referenceController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdPayConsultationAction),
      icon: const Icon(Icons.payments_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppCurrencyAmountField(
              amountController: _amountController,
              currency: _currency,
              amountLabelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdAmountLabel,
              ),
              currencyLabelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdCurrencyLabel,
              ),
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
            ),
            AppSelectField<String>(
              value: _method,
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdPaymentMethodLabel,
              ),
              enabled: !_isSaving,
              onChanged: (String? value) {
                setState(() => _method = value ?? _method);
              },
              options: _statusOptions(_paymentMethods),
            ),
            AppTextField(
              controller: _referenceController,
              labelText: _opdOptionalFieldLabel(
                l10n,
                l10n.opdTransactionReferenceLabel,
              ),
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _notesController,
              labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdPayConsultationAction,
          leadingIcon: Icons.payments_outlined,
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
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .payConsultation(widget.flow, <String, Object?>{
          'amount': normalizeCurrencyAmount(_amountController.text),
          'currency': _currency,
          'method': _method,
          'status': 'COMPLETED',
          'transaction_ref': _referenceController.text.trim(),
          'notes': _notesController.text.trim(),
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        });
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

class CorrectStageDialog extends ConsumerStatefulWidget {
  const CorrectStageDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<CorrectStageDialog> createState() => _CorrectStageDialogState();
}

class _CorrectStageDialogState extends ConsumerState<CorrectStageDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  String _stage = _flowStages.first;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _stage = widget.flow.stage ?? _flowStages.first;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdCorrectStageAction),
      icon: const Icon(Icons.edit_note_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _stage,
              labelText: _opdRequiredFieldLabel(l10n, l10n.opdStageLabel),
              enabled: !_isSaving,
              onChanged: (String? value) =>
                  setState(() => _stage = value ?? _stage),
              options: _flowStageOptions(),
            ),
            AppTextField(
              controller: _reasonController,
              labelText: _opdOptionalFieldLabel(l10n, l10n.opdReasonLabel),
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdSaveAction,
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
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .correctStage(widget.flow, _stage, _reasonController.text.trim());
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

class ReferralDialog extends ConsumerStatefulWidget {
  const ReferralDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<ReferralDialog> createState() => _ReferralDialogState();
}

class _ReferralDialogState extends ConsumerState<ReferralDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _facilityController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _facilityController = TextEditingController();
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _facilityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdReferAction),
      icon: const Icon(Icons.alt_route_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _facilityController,
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdExternalFacilityLabel,
              ),
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _reasonController,
              labelText: _opdRequiredFieldLabel(l10n, l10n.opdReasonLabel),
              enabled: !_isSaving,
              maxLines: 3,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _notesController,
              labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdReferAction,
          leadingIcon: Icons.alt_route_outlined,
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
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .createReferral(
          flow: widget.flow,
          externalFacilityName: _facilityController.text.trim(),
          reason: _reasonController.text.trim(),
          notes: _notesController.text.trim(),
        );
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

class FollowUpDialog extends ConsumerStatefulWidget {
  const FollowUpDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<FollowUpDialog> createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends ConsumerState<FollowUpDialog> {
  late final TextEditingController _dateController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdFollowUpAction),
      icon: const Icon(Icons.event_repeat_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppTextField(
            controller: _dateController,
            labelText: _opdRequiredFieldLabel(l10n, l10n.opdFollowUpDateLabel),
            hintText: l10n.opdDateTimeHint,
            enabled: !_isSaving,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
          AppTextField(
            controller: _notesController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdFollowUpAction,
          leadingIcon: Icons.event_repeat_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final DateTime? scheduledAt = DateTime.tryParse(
      _dateController.text.trim(),
    );
    if (scheduledAt == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .createFollowUp(
          flow: widget.flow,
          scheduledAt: scheduledAt,
          notes: _notesController.text.trim(),
        );
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

class RoutingDecisionDialog extends ConsumerStatefulWidget {
  const RoutingDecisionDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<RoutingDecisionDialog> createState() =>
      _RoutingDecisionDialogState();
}

class _RoutingDecisionDialogState extends ConsumerState<RoutingDecisionDialog> {
  late final TextEditingController _notesController;
  String _decision = 'CONSULTATION';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdRouteDecisionLabel),
      icon: const Icon(Icons.alt_route_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppSelectField<String>(
            value: _decision,
            labelText: _opdRequiredFieldLabel(l10n, l10n.opdRouteDecisionLabel),
            enabled: !_isSaving,
            onChanged: (String? value) =>
                setState(() => _decision = value ?? _decision),
            options: _statusOptions(_triageRouteOptions),
          ),
          AppTextField(
            controller: _notesController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdRouteDecisionLabel,
          leadingIcon: Icons.alt_route_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .disposeFlow(widget.flow, _decision, _notesController.text.trim());
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

class OpdDispositionDialog extends ConsumerStatefulWidget {
  const OpdDispositionDialog({
    required this.flow,
    required this.hasPharmacyOrder,
    super.key,
  });

  final OpdFlowSummary flow;
  final bool hasPharmacyOrder;

  @override
  ConsumerState<OpdDispositionDialog> createState() =>
      _OpdDispositionDialogState();
}

class _OpdDispositionDialogState extends ConsumerState<OpdDispositionDialog> {
  late final TextEditingController _notesController;
  String _decision = 'DISCHARGE';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    if (widget.hasPharmacyOrder) {
      _decision = 'SEND_TO_PHARMACY';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdDispositionAction),
      icon: const Icon(Icons.task_alt_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          AppSelectField<String>(
            value: _decision,
            labelText: _opdRequiredFieldLabel(l10n, l10n.opdDecisionLabel),
            enabled: !_isSaving,
            onChanged: (String? value) =>
                setState(() => _decision = value ?? _decision),
            options: _statusOptions(
              _opdDispositionOptions(hasPharmacyOrder: widget.hasPharmacyOrder),
            ),
          ),
          AppTextField(
            controller: _notesController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.opdDispositionAction,
          leadingIcon: Icons.task_alt_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .completeDisposition(widget.flow, <String, Object?>{
          'decision': _decision,
          'notes': _notesController.text.trim(),
        });
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

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

List<AppSelectOption<String>> _flowStageOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _flowStages)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: Icon(_flowStageIcon(value)),
      ),
  ];
}

AppSelectOption<String> _drugOption(OpdDrugOption drug) {
  return AppSelectOption<String>(
    value: drug.apiId,
    label: _joinDisplay(<String?>[
      drug.displayTitle,
      drug.form,
      drug.strength,
      drug.availableQuantity?.toString(),
    ]),
  );
}

AppSelectOption<String>? _patientSelectOption(Patient patient) {
  final String? value = patient.publicId;
  if (!_isNonEmpty(value)) {
    return null;
  }

  return AppSelectOption<String>(
    value: value!,
    label: _joinDisplay(<String?>[
      patient.effectiveDisplayName,
      patient.effectiveIdentifier,
      patient.primaryPhone,
    ]),
  );
}

AppSelectOption<String>? _appointmentSelectOption(OpdAppointment appointment) {
  final String value = appointment.publicId ?? appointment.id;
  if (!_isNonEmpty(value)) {
    return null;
  }

  return AppSelectOption<String>(
    value: value,
    label: _joinDisplay(<String?>[
      appointment.displayTitle,
      appointment.patientIdentifier,
      appointment.patientPhone,
      appointment.providerDisplayName,
      appointment.status,
    ]),
  );
}

List<OpdAppointment> _eligibleAppointmentOptions(
  Iterable<OpdAppointment> appointments,
) {
  final Map<String, OpdAppointment> options = <String, OpdAppointment>{};

  for (final OpdAppointment appointment in appointments) {
    final String value = appointment.publicId ?? appointment.id;
    if (!_isNonEmpty(value) ||
        _isTerminalAppointmentStatus(appointment.status)) {
      continue;
    }

    options[value] = appointment;
  }

  return options.values.toList(growable: false);
}

bool _isTerminalAppointmentStatus(String? status) {
  return switch (status?.toUpperCase()) {
    'CANCELLED' || 'NO_SHOW' || 'COMPLETED' => true,
    _ => false,
  };
}

List<AppSelectOption<String>> _providerSelectOptions({
  required List<OpdProviderOption> providers,
  required List<OpdProviderSchedule> schedules,
}) {
  final Map<String, AppSelectOption<String>> options =
      <String, AppSelectOption<String>>{};

  for (final OpdProviderOption provider in providers) {
    final String value = provider.id;
    if (!_isNonEmpty(value) || options.containsKey(value)) {
      continue;
    }
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[
        provider.displayTitle,
        provider.positionTitle,
        provider.practitionerType,
        provider.staffProfileId,
        value,
      ]),
    );
  }

  for (final OpdProviderSchedule schedule in schedules) {
    final String value = schedule.providerApiId;
    if (!_isNonEmpty(value) || options.containsKey(value)) {
      continue;
    }
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[
        schedule.providerDisplayName,
        value,
        schedule.facilityName,
      ]),
    );
  }

  return options.values.toList(growable: false);
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
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

String _formatDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

List<String> _splitTokens(String value) {
  return value
      .split(RegExp(r'[,;\n]+'))
      .map((String token) => token.trim())
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}

AppWorkspaceStatusTone _stageTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'COMPLETED' || 'DISCHARGED' || 'ADMITTED' => AppWorkspaceStatusTone.success,
    'NORMAL' || 'ROUTINE' => AppWorkspaceStatusTone.success,
    'CANCELLED' || 'NO_SHOW' => AppWorkspaceStatusTone.error,
    'CRITICAL' => AppWorkspaceStatusTone.error,
    'ABNORMAL' || 'SERVICE_ONLY' => AppWorkspaceStatusTone.warning,
    'WAITING_CONSULTATION_PAYMENT' ||
    'WAITING_VITALS' ||
    'WAITING_DOCTOR_ASSIGNMENT' => AppWorkspaceStatusTone.warning,
    'IN_PROGRESS' ||
    'WAITING_DOCTOR_REVIEW' ||
    'WAITING_DISPOSITION' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData _flowStageIcon(String value) {
  return switch (value.toUpperCase()) {
    'WAITING_CONSULTATION_PAYMENT' => Icons.payments_outlined,
    'WAITING_VITALS' => Icons.monitor_heart_outlined,
    'WAITING_DOCTOR_ASSIGNMENT' => Icons.assignment_ind_outlined,
    'WAITING_DOCTOR_REVIEW' => Icons.medical_services_outlined,
    'LAB_REQUESTED' => Icons.science_outlined,
    'RADIOLOGY_REQUESTED' => Icons.biotech_outlined,
    'LAB_AND_RADIOLOGY_REQUESTED' => Icons.hub_outlined,
    'PHARMACY_REQUESTED' => Icons.local_pharmacy_outlined,
    'WAITING_DISPOSITION' => Icons.task_alt_outlined,
    'ADMITTED' => Icons.bed_outlined,
    'DISCHARGED' => Icons.logout_outlined,
    _ => Icons.sync_alt_outlined,
  };
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

const String _opdCategoryArrival = 'ARRIVAL';
const String _opdCategoryQueue = 'QUEUE';
const String _opdCategoryTriage = 'TRIAGE';
const String _opdCategoryActiveFlow = 'ACTIVE_FLOW';
const String _opdFilterAll = 'ALL';
const String _opdFilterKeyCategory = 'category';
const String _opdFilterKeyStatus = 'status';
const String _opdFilterKeyTriageScope = 'triage_scope';
const String _triageScopeWaiting = 'WAITING';
const String _triageScopeUrgent = 'URGENT';
const String _triageScopeEmergency = 'EMERGENCY';
const String _triageScopeRoutine = 'ROUTINE';
const String _triageScopeServiceOnly = 'SERVICE_ONLY';
const String _opdNoRouteDecisionValue = 'NO_ROUTE_DECISION';
const String _riskFlagFall = 'FALL_RISK';
const String _riskFlagPregnancy = 'PREGNANCY';
const String _riskFlagInfection = 'INFECTION_RISK';
const String _riskFlagAlteredMentalState = 'ALTERED_MENTAL_STATE';
const String _riskFlagBleeding = 'BLEEDING';

const List<String> _triageRiskFlagOptions = <String>[
  _riskFlagFall,
  _riskFlagPregnancy,
  _riskFlagInfection,
  _riskFlagAlteredMentalState,
  _riskFlagBleeding,
];

const Set<String> _serviceOnlyStages = <String>{
  'LAB_REQUESTED',
  'RADIOLOGY_REQUESTED',
  'LAB_AND_RADIOLOGY_REQUESTED',
  'PHARMACY_REQUESTED',
};

const Set<String> _serviceOnlyRoutes = <String>{
  'LAB',
  'RADIOLOGY',
  'LAB_AND_RADIOLOGY',
  'PHYSIOTHERAPY',
  'OTHER_SERVICE',
  'MINOR_PROCEDURE',
};

const List<String> _queueStatuses = <String>[
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'NO_SHOW',
];

const List<String> _arrivalModeOptions = <String>['WALK_IN', 'EMERGENCY'];

const List<String> _emergencySeverityOptions = <String>[
  'LOW',
  'MEDIUM',
  'HIGH',
  'CRITICAL',
];

const List<String> _triageLevelOptions = <String>[
  'LEVEL_1',
  'LEVEL_2',
  'LEVEL_3',
  'LEVEL_4',
  'LEVEL_5',
  'IMMEDIATE',
  'URGENT',
  'LESS_URGENT',
  'NON_URGENT',
];

const List<String> _flowStages = <String>[
  'WAITING_CONSULTATION_PAYMENT',
  'WAITING_VITALS',
  'WAITING_DOCTOR_ASSIGNMENT',
  'WAITING_DOCTOR_REVIEW',
  'LAB_REQUESTED',
  'RADIOLOGY_REQUESTED',
  'LAB_AND_RADIOLOGY_REQUESTED',
  'PHARMACY_REQUESTED',
  'WAITING_DISPOSITION',
  'ADMITTED',
  'DISCHARGED',
];

const List<String> _paymentMethods = <String>[
  'CASH',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'CREDIT_CARD',
  'INSURANCE',
  'OTHER',
];

const List<String> _triageRouteOptions = <String>[
  'CONSULTATION',
  'EMERGENCY',
  'ADMIT',
  'THEATRE',
  'MINOR_PROCEDURE',
  'LAB',
  'RADIOLOGY',
  'LAB_AND_RADIOLOGY',
  'PHYSIOTHERAPY',
  'OTHER_SERVICE',
  'DISCHARGE',
];

List<String> _opdDispositionOptions({required bool hasPharmacyOrder}) {
  return <String>[
    'DISCHARGE',
    if (hasPharmacyOrder) 'SEND_TO_PHARMACY',
    'ADMIT',
  ];
}

const List<String> _diagnosisTypes = <String>[
  'PRIMARY',
  'SECONDARY',
  'DIFFERENTIAL',
];

const List<String> _medicationFrequencies = <String>[
  'ONCE',
  'BID',
  'TID',
  'QID',
  'PRN',
  'STAT',
  'CUSTOM',
];

const List<String> _medicationRoutes = <String>[
  'ORAL',
  'IV',
  'IM',
  'TOPICAL',
  'INHALATION',
  'OTHER',
];

final List<TextInputFormatter> _integerInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];
