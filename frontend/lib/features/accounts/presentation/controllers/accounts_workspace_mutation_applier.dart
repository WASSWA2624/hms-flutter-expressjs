import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract final class AccountsWorkspaceMutationApplier {
  static AccountsWorkspaceState apply(
    AccountsWorkspaceState state,
    AccountsMutationResult mutation,
  ) {
    final AccountsWorkItem? item = mutation.item;
    if (item == null) {
      return state.copyWith(
        lastActionPendingApproval: mutation.approvalRequired,
      );
    }

    final bool removeFromApprovals =
        state.query.section == AccountsDeskSection.approvals &&
        !item.canApproveOrReject;
    final bool removeFromToPost =
        state.query.section == AccountsDeskSection.journals && !item.canPost;
    final bool removeFromQueue = removeFromApprovals || removeFromToPost;

    final List<AccountsWorkItem> items = state.workItems.items
        .where(
          (AccountsWorkItem existing) =>
              !(removeFromQueue && existing.id == item.id),
        )
        .map(
          (AccountsWorkItem existing) =>
              existing.id == item.id ? item : existing,
        )
        .toList(growable: false);

    final bool wasPending = state.workItems.items.any(
      (AccountsWorkItem existing) =>
          existing.id == item.id && existing.canApproveOrReject,
    );
    final bool nowPending = item.canApproveOrReject;
    var needApproval = state.overview.summary.needApproval;
    if (wasPending && !nowPending) {
      needApproval = (needApproval - 1).clamp(0, 1 << 30);
    } else if (!wasPending && nowPending) {
      needApproval += 1;
    }

    final bool wasDraft = state.workItems.items.any(
      (AccountsWorkItem existing) => existing.id == item.id && existing.canPost,
    );
    final bool nowDraft = item.canPost;
    var toPost = state.overview.summary.toPost;
    var openWork = state.overview.summary.openWork;
    if (wasDraft && !nowDraft) {
      toPost = (toPost - 1).clamp(0, 1 << 30);
      openWork = (openWork - 1).clamp(0, 1 << 30);
    } else if (!wasDraft && nowDraft) {
      toPost += 1;
      openWork += 1;
    }

    final AccountsSummary summary = state.overview.summary.copyWith(
      needApproval: needApproval,
      toPost: toPost,
      openWork: openWork,
    );

    return state.copyWith(
      overview: AccountsWorkspaceOverview(summary: summary),
      workItems: AppPage<AccountsWorkItem>(
        items: items,
        request: state.workItems.request,
        totalItemCount: removeFromQueue
            ? ((state.workItems.totalItemCount ?? items.length) - 1).clamp(
                0,
                1 << 30,
              )
            : state.workItems.totalItemCount,
      ),
      selectedItem: removeFromQueue && state.selectedItem?.id == item.id
          ? null
          : (state.selectedItem?.id == item.id ? item : state.selectedItem),
      clearSelectedItem: removeFromQueue && state.selectedItem?.id == item.id,
      lastActionPendingApproval: mutation.approvalRequired,
    );
  }
}
