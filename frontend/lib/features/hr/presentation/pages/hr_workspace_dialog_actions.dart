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

/// Selects a staff profile by id and opens Staff Details when successful.
Future<void> openHrStaffDetailById(
  BuildContext context,
  WidgetRef ref,
  String staffProfileId,
) async {
  final AppFailure? failure = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .selectStaffByDisplayId(staffProfileId);
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    showHrMutationSnackBar(context, failure);
    return;
  }
  if (readHrWorkspaceState(ref)?.selectedStaff == null) {
    return;
  }
  await showHrStaffDetailDialog(context, ref);
}

/// Opens the canonical Staff Details dialog for an HR directory user.
///
/// Always returns `true` so [ManageUsersPanel] does not fall through to Access
/// Admin User Details.
Future<bool> openHrStaffDetailForDirectoryUser(
  BuildContext context,
  WidgetRef ref,
  AccessAdminItem item,
) async {
  final AppFailure? failure = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .openStaffDetailForDirectoryUser(
        userId: item.mutationId,
        tenantId: item.tenantId,
        position: item.positionTitle,
        existingStaffProfileId: item.staffProfileId,
      );
  if (!context.mounted) {
    return true;
  }
  if (failure != null) {
    showHrMutationSnackBar(context, failure);
    return true;
  }
  await showHrStaffDetailDialog(context, ref, directoryUser: item);
  return true;
}

/// Opens the selected staff detail dialog.
Future<void> showHrStaffDetailDialog(
  BuildContext context,
  WidgetRef ref, {
  AccessAdminItem? directoryUser,
}) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return Consumer(
        builder: (BuildContext context, WidgetRef dialogRef, _) {
          final HrWorkspaceState? dialogState =
              _hrStateFromAsync(
                dialogRef.watch(hrWorkspaceControllerProvider),
              ) ??
              state;
          final HrStaffDetail? detail = dialogState?.selectedStaff;
          final AppAccessPolicy policy = dialogRef.watch(
            appAccessPolicyProvider,
          );
          final ColorScheme colorScheme = Theme.of(context).colorScheme;
          final bool isMutating = dialogState?.isMutating ?? false;
          final bool canWrite =
              HrHumanResourcesAtomPermissions.write.isAllowed(policy);
          final bool canEdit =
              canWrite &&
              detail != null &&
              !detail.profile.isSeparated &&
              !isMutating;
          final bool canDelete =
              directoryUser != null &&
              !isMutating &&
              canSoftDeleteAccessAdminUser(directoryUser, policy: policy);

          return AppDialog(
            title: Text(l10n.hrStaffDetailTitle),
            icon: const Icon(Icons.badge_outlined),
            scrollable: true,
            pinActionsToBottom: true,
            maxWidth: 980,
            actions: <Widget>[
              if (canEdit)
                AppButton.secondary(
                  label: l10n.hrEditStaffAction,
                  leadingIcon: Icons.edit_outlined,
                  onPressed: () => showHrStaffOnboardingDialog(
                    context,
                    dialogRef,
                    staff: detail.profile,
                  ),
                ),
              if (canDelete)
                AppButton.secondary(
                  label: l10n.accessAdminDeleteUserAction,
                  leadingIcon: Icons.delete_outline,
                  color: colorScheme.error,
                  onPressed: () async {
                    final bool deleted = await confirmSoftDeleteAccessAdminUser(
                      context,
                      repository: dialogRef.read(
                        accessAdminRepositoryProvider,
                      ),
                      user: directoryUser,
                    );
                    if (!deleted || !context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                    await dialogRef
                        .read(hrWorkspaceControllerProvider.notifier)
                        .refresh();
                  },
                ),
              if (detail != null)
                AppButton.primary(
                  label: l10n.commonPrintActionLabel,
                  leadingIcon: Icons.print_outlined,
                  onPressed: () => unawaited(
                    showHrStaffPrintPreview(
                      context: context,
                      ref: dialogRef,
                      detail: detail,
                    ),
                  ),
                ),
            ],
            content: dialogState == null
                ? const SizedBox.shrink()
                : _HrStaffDetailPanel(state: dialogState),
          );
        },
      );
    },
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
