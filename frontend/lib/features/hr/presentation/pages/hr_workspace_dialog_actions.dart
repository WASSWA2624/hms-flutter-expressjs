part of 'hr_workspace_page.dart';

/// Opens the HR work-queue dialog (shared by `/hr` and the workforce dashboard).
Future<void> showHrWorkQueueDialog(
  BuildContext context,
  WidgetRef ref, {
  bool maximize = false,
  AppListTableColumnVisibilityController<HrWorkItem>?
  columnVisibilityController,
}) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final TextEditingController searchController = TextEditingController(
    text: state?.workItemsQuery.search ?? '',
  );
  final AppListTableColumnVisibilityController<HrWorkItem> columns =
      columnVisibilityController ??
      AppListTableColumnVisibilityController<HrWorkItem>();

  try {
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AppDialog(
        title: Text(l10n.hrWorkQueuesTitle),
        icon: const Icon(Icons.pending_actions_outlined),
        scrollable: true,
        maxWidth: 980,
        initialMaximized: maximize,
        content: _HrWorkQueuePanel(
          searchController: searchController,
          columnVisibilityController: columns,
          onPageChanged: ref
              .read(hrWorkspaceControllerProvider.notifier)
              .changeWorkItemsPage,
        ),
      ),
    );
  } finally {
    searchController.dispose();
    if (columnVisibilityController == null) {
      columns.dispose();
    }
  }
}

/// Applies a queue filter then opens the work-queue dialog.
Future<void> applyHrQueueAndShow(
  BuildContext context,
  WidgetRef ref,
  HrQueue queue, {
  bool maximize = false,
  String? status,
  DateTime? from,
  DateTime? to,
}) async {
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = status != null || from != null || to != null
      ? await controller.applyWorkItemsScope(
          queue: queue,
          status: status,
          from: from,
          to: to,
        )
      : await controller.applyQueue(queue);
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    showHrMutationSnackBar(context, failure);
    return;
  }
  await showHrWorkQueueDialog(context, ref, maximize: maximize);
}

/// Opens the Users CRUD dialog (identical to Facility setup Users /
/// [ManageUsersPanel] / [showManageUsersDialog]).
Future<void> showHrStaffDirectoryDialog(
  BuildContext context,
  WidgetRef ref, {
  String? statusFilter,
  bool maximize = false,
}) async {
  // statusFilter / maximize are retained for call-site compatibility; Users
  // CRUD owns its own filters and dialog chrome via ManageUsersPanel.
  await showManageUsersDialog(context, ref);
}

/// Opens the leave queue filtered to requests awaiting decision.
Future<void> showHrPendingLeaveDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await applyHrQueueAndShow(
    context,
    ref,
    HrQueue.leaveRequests,
    maximize: true,
    status: 'REQUESTED',
  );
}

/// Opens the selected staff detail dialog.
Future<void> showHrStaffDetailDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AppDialog(
      title: Text(l10n.hrStaffDetailTitle),
      icon: const Icon(Icons.badge_outlined),
      scrollable: true,
      maxWidth: 980,
      content: Consumer(
        builder: (BuildContext context, WidgetRef dialogRef, _) {
          final HrWorkspaceState? dialogState =
              _hrStateFromAsync(
                dialogRef.watch(hrWorkspaceControllerProvider),
              ) ??
              state;
          if (dialogState == null) {
            return const SizedBox.shrink();
          }
          return _HrStaffDetailPanel(state: dialogState);
        },
      ),
    ),
  );
}

/// Shifts scheduled for today.
Future<void> showHrTodayShiftsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final DateTime from = HrWorkspaceController.startOfLocalDay();
  final DateTime to = HrWorkspaceController.endOfLocalDay();
  await applyHrQueueAndShow(
    context,
    ref,
    HrQueue.unassignedShifts,
    maximize: true,
    from: from,
    to: to,
  );
}

/// Staff on approved leave today.
Future<void> showHrOnLeaveTodayDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final DateTime from = HrWorkspaceController.startOfLocalDay();
  final DateTime to = HrWorkspaceController.endOfLocalDay();
  await applyHrQueueAndShow(
    context,
    ref,
    HrQueue.leaveRequests,
    maximize: true,
    status: 'APPROVED',
    from: from,
    to: to,
  );
}

/// Shifts marked attended today.
Future<void> showHrAttendedTodayDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final DateTime from = HrWorkspaceController.startOfLocalDay();
  final DateTime to = HrWorkspaceController.endOfLocalDay();
  await applyHrQueueAndShow(
    context,
    ref,
    HrQueue.unassignedShifts,
    maximize: true,
    status: 'COMPLETED',
    from: from,
    to: to,
  );
}
