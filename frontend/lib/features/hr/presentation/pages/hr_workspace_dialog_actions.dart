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
  final AppListTableColumnVisibilityController<HrWorkItem> columns =
      columnVisibilityController ??
      AppListTableColumnVisibilityController<HrWorkItem>();

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AppDialog(
      title: Text(l10n.hrWorkQueuesTitle),
      icon: const Icon(Icons.pending_actions_outlined),
      scrollable: true,
      maxWidth: 980,
      initialMaximized: maximize,
      content: _HrWorkQueuePanel(
        columnVisibilityController: columns,
        onPageChanged: ref
            .read(hrWorkspaceControllerProvider.notifier)
            .changeWorkItemsPage,
      ),
    ),
  );
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
    _showMutationResult(context, failure);
    return;
  }
  await showHrWorkQueueDialog(context, ref, maximize: maximize);
}

/// Opens the staff directory dialog (shared by `/hr` and the workforce dashboard).
Future<void> showHrStaffDirectoryDialog(
  BuildContext context,
  WidgetRef ref, {
  String? statusFilter,
  bool maximize = false,
}) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
  final TextEditingController searchController = TextEditingController(
    text: state?.staffQuery.search ?? '',
  );
  final AppListTableColumnVisibilityController<HrStaffProfile>
  columnController = AppListTableColumnVisibilityController<HrStaffProfile>();

  try {
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AppDialog(
        title: Text(l10n.hrStaffDirectoryTitle),
        icon: const Icon(Icons.people_outline),
        scrollable: true,
        maxWidth: 980,
        initialMaximized: maximize,
        content: _HrStaffDirectoryDialogContent(
          searchController: searchController,
          columnVisibilityController: columnController,
          statusFilter: statusFilter,
          onStaffSelected: (HrStaffProfile staff) {
            unawaited(_openStaffDetailFromDialog(context, ref, staff));
          },
        ),
      ),
    );
  } finally {
    searchController.dispose();
    columnController.dispose();
  }
}

Future<void> _openStaffDetailFromDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
) async {
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final AppFailure? failure = await controller.selectStaff(staff);
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    _showMutationResult(context, failure);
    return;
  }
  await showHrStaffDetailDialog(context, ref);
}

/// Opens the selected staff detail dialog.
Future<void> showHrStaffDetailDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = _readHrState(ref);
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

class _HrStaffDirectoryDialogContent extends ConsumerWidget {
  const _HrStaffDirectoryDialogContent({
    required this.searchController,
    required this.columnVisibilityController,
    required this.onStaffSelected,
    this.statusFilter,
  });

  final TextEditingController searchController;
  final AppListTableColumnVisibilityController<HrStaffProfile>
  columnVisibilityController;
  final ValueChanged<HrStaffProfile> onStaffSelected;
  final String? statusFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HrWorkspaceState? state = _hrStateFromAsync(
      ref.watch(hrWorkspaceControllerProvider),
    );
    if (state == null) {
      return const SizedBox.shrink();
    }

    return _HrStaffDirectory(
      state: state,
      searchController: searchController,
      columnVisibilityController: columnVisibilityController,
      onPageChanged: ref
          .read(hrWorkspaceControllerProvider.notifier)
          .changeStaffPage,
      onStaffSelected: onStaffSelected,
      statusFilter: statusFilter,
    );
  }
}
