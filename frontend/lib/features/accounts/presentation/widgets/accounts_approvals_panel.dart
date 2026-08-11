import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_approvals_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_detail_widgets.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_form_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Need approval desk (`?section=approvals`) — self-contained work queue.
class AccountsApprovalsPanel extends ConsumerStatefulWidget {
  const AccountsApprovalsPanel({
    super.key,
    required this.state,
  });

  final AccountsWorkspaceState state;

  @override
  ConsumerState<AccountsApprovalsPanel> createState() =>
      _AccountsApprovalsPanelState();
}

class _AccountsApprovalsPanelState extends ConsumerState<AccountsApprovalsPanel> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<AccountsWorkItem>
  _columnVisibilityController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _columnVisibilityController =
        AppListTableColumnVisibilityController<AccountsWorkItem>();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant AccountsApprovalsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final String query = _searchController.text.trim();
      if (query == widget.state.query.search) {
        return;
      }
      unawaited(
        ref
            .read(accountsWorkspaceControllerProvider.notifier)
            .applySearch(query),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AccountsWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final AccountsWorkspaceController controller = ref.read(
      accountsWorkspaceControllerProvider.notifier,
    );
    final bool canApprove = canDecideAccountsApproval(accessPolicy);

    return AppListTable<AccountsWorkItem>(
      page: state.workItems,
      isLoading: state.isRefreshing,
      columnVisibilityController: _columnVisibilityController,
      columnVisibilityStorageKey: accountsApprovalsTableSettingsKey,
      columnWidthStorageKey: '${accountsApprovalsTableSettingsKey}_cw',
      columnVisibilityLabel: context.l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: context.l10n.commonTableSettingsTitle,
      enableExport: true,
      search: AppListTableSearch<AccountsWorkItem>(
        controller: _searchController,
        semanticLabel: AccountsStrings.searchSemantic,
        hintText: AccountsStrings.searchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsWorkItem item, String query) =>
            accountsApprovalsMatchesSearch(item, query),
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: AccountsStrings.filtersLabel,
        advancedFilterTitle: context.l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: context.l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: AccountsStrings.clearFilters,
        allFieldsLabel: AccountsStrings.allFields,
        filterGroups: const <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: 'approval_type',
            label: AccountsStrings.typeFilterLabel,
            allLabel: AccountsStrings.anyApprovalType,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'JOURNAL_POST',
                label: AccountsStrings.approvalTypeJournalPost,
              ),
              AppSearchBarFilterChoice(
                value: 'VOID',
                label: AccountsStrings.approvalTypeVoid,
              ),
              AppSearchBarFilterChoice(
                value: 'REVERSAL',
                label: AccountsStrings.approvalTypeReversal,
              ),
              AppSearchBarFilterChoice(
                value: 'PERIOD_CLOSE',
                label: AccountsStrings.approvalTypePeriodClose,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: 'status',
            label: AccountsStrings.statusFilterLabel,
            allLabel: AccountsStrings.anyStatus,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'PENDING',
                label: AccountsStrings.statusPending,
              ),
            ],
          ),
        ],
        filterValue: AppSearchBarFilterValue(
          options: <String, String>{
            if (state.query.status.trim().isNotEmpty)
              'status': state.query.status.trim(),
            if (state.query.source.trim().isNotEmpty)
              'approval_type': state.query.source.trim(),
          },
        ),
        hasActiveFilters: state.query.hasActiveFilters,
        onFilterChanged: (AppSearchBarFilterValue value) {
          if (!value.isActive) {
            unawaited(controller.clearFilters());
            return;
          }
          final String status = (value.options['status'] ?? '').trim();
          final String type = (value.options['approval_type'] ?? '').trim();
          unawaited(
            controller.applyQuery(
              state.query.copyWith(
                status: status,
                source: type,
                clearStatus: status.isEmpty,
                clearSource: type.isEmpty,
                pageRequest: state.query.pageRequest.first(),
              ),
            ),
          );
        },
        trailingActions: const <AppSearchBarAction>[],
      ),
      itemKeyBuilder: (AccountsWorkItem item) => ValueKey<String>(item.id),
      onRowSelected: (AccountsWorkItem item) {
        controller.selectItem(item);
        unawaited(_showDetail(context, ref, item, canApprove: canApprove));
      },
      previousPageLabel: context.l10n.billingPreviousPageLabel,
      nextPageLabel: context.l10n.billingNextPageLabel,
      pageLabelBuilder: (AppPage<AccountsWorkItem> page) {
        final int total = page.totalItemCount ?? page.lastItemNumber;
        return '${page.firstItemNumber}-${page.lastItemNumber} of $total';
      },
      onPageChanged: controller.changePage,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: AccountsStrings.needApprovalEmpty,
        body: '',
      ),
      columns: accountsApprovalsColumns(
        context: context,
        ref: ref,
        accessPolicy: accessPolicy,
        isSaving: state.isSaving,
        onNextAction: _runApprove,
      ),
      columnChoices: accountsApprovalsColumnChoices(
        context: context,
        ref: ref,
        accessPolicy: accessPolicy,
        isSaving: state.isSaving,
        onNextAction: _runApprove,
      ),
      mobileItemBuilder: (BuildContext context, AccountsWorkItem item) {
        return AppListTableMobileItem(
          title: item.effectiveDisplayId,
          caption: accountsApprovalsTypeLabel(item.approvalType),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: accountsApprovalsStatusLabel(item),
              icon: Icons.rule_outlined,
            ),
            AppListTableMobileMeta(
              label: accountsMoney(context, item.amount, item.currency),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
          trailing: AccountsApprovalsNextButton(
            item: item,
            canApprove: canApprove,
            isSaving: state.isSaving,
            onPressed: () => _runApprove(context, ref, item),
          ),
        );
      },
    );
  }

  Future<void> _runApprove(
    BuildContext context,
    WidgetRef ref,
    AccountsWorkItem item,
  ) async {
    if (!canDecideAccountsApproval(ref.read(appAccessPolicyProvider)) ||
        !item.canApproveOrReject) {
      return;
    }
    ref.read(accountsWorkspaceControllerProvider.notifier).selectItem(item);
    await _showApprove(context, ref);
  }
}

Future<void> _showDetail(
  BuildContext context,
  WidgetRef ref,
  AccountsWorkItem item, {
  required bool canApprove,
}) async {
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AppDialog(
        title: Text(accountsDetailTitleFor(item)),
        icon: const Icon(Icons.rule_outlined),
        scrollable: true,
        content: AccountsDetailBody(
          item: item,
          canWrite: false,
          canApprove: canApprove,
          isSaving: false,
          onApprove: canApprove && item.canApproveOrReject
              ? () {
                  Navigator.of(dialogContext).maybePop();
                  unawaited(_showApprove(context, ref));
                }
              : null,
          onReject: canApprove && item.canApproveOrReject
              ? () {
                  Navigator.of(dialogContext).maybePop();
                  unawaited(_showReject(context, ref));
                }
              : null,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(),
            child: const Text(AccountsStrings.closeAction),
          ),
        ],
      );
    },
  );
}

Future<void> _showApprove(BuildContext context, WidgetRef ref) async {
  final AccountsOptionalNotesResult? result =
      await showAppDialog<AccountsOptionalNotesResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AccountsNotesForm(
          dialogTitle: const Text(AccountsStrings.approveAction),
          dialogIcon: const Icon(Icons.check_circle_outline),
          submitLabel: AccountsStrings.approveAction,
        ),
      );
  if (result == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .approveSelectedApproval(
        AccountsApprovalDecisionDraft(notes: result.notes),
      );
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? AccountsStrings.saved
            : context.l10n.failureMessage(failure),
      ),
    ),
  );
}

Future<void> _showReject(BuildContext context, WidgetRef ref) async {
  final AccountsReasonDraft? draft = await showAppDialog<AccountsReasonDraft>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AccountsReasonForm(
      dialogTitle: const Text(AccountsStrings.rejectAction),
      dialogIcon: const Icon(Icons.cancel_outlined),
      submitLabel: AccountsStrings.rejectAction,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .rejectSelectedApproval(
        AccountsApprovalDecisionDraft(
          reason: draft.reason,
          notes: draft.notes,
        ),
      );
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? AccountsStrings.saved
            : context.l10n.failureMessage(failure),
      ),
    ),
  );
}
