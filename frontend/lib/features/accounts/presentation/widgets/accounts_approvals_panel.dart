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
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_work_actions.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Need approval desk (`?section=approvals`) — pending GL / period decisions.
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
    final bool canWrite = canWriteAccounts(accessPolicy);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
    final Object? failure = state.lastFailure;
    const AccountsDeskSection section = AccountsDeskSection.approvals;
    final List<AppListTableColumn<AccountsWorkItem>> columns =
        accountsApprovalsColumns(
          context: context,
          ref: ref,
          accessPolicy: accessPolicy,
          isSaving: state.isSaving,
          onNextAction: _runApprove,
        );

    return AppListTable<AccountsWorkItem>(
      page: state.workItems,
      isLoading: state.isRefreshing,
      error: failure is AppFailure
          ? context.l10n.failureMessage(failure)
          : null,
      columnVisibilityController: _columnVisibilityController,
      columnVisibilityStorageKey: accountsTableSettingsKey(section),
      columnWidthStorageKey: '${accountsTableSettingsKey(section)}_cw',
      columnVisibilityLabel: context.l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: context.l10n.commonTableSettingsTitle,
      enableExport: true,
      canExport: canExport,
      enablePrint: true,
      canPrint: canPrint,
      printLabel: AccountsStrings.printAction,
      onPrint: () => printAccountsListTable<AccountsWorkItem>(
        ref: ref,
        context: context,
        title: AccountsStrings.needApprovalLabel,
        columns: columns,
        items: state.workItems.items,
        emptyText: AccountsStrings.needApprovalEmpty,
      ),
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
        dateFilterLabel: 'Posted date',
        dateFromLabel: context.l10n.opdDateFromLabel,
        dateToLabel: context.l10n.opdDateToLabel,
        allFieldsLabel: AccountsStrings.allFields,
        textFilters: const <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: 'accountId',
            label: AccountsStrings.accountColumn,
            icon: Icons.account_balance_outlined,
          ),
          AppSearchBarTextFilter(
            key: 'journal',
            label: AccountsStrings.journalColumn,
            icon: Icons.receipt_long_outlined,
          ),
          AppSearchBarTextFilter(
            key: 'periodId',
            label: AccountsStrings.periodFilterLabel,
            icon: Icons.date_range_outlined,
          ),
        ],
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
          texts: <String, String>{
            if (state.query.accountId.trim().isNotEmpty)
              'accountId': state.query.accountId.trim(),
            if (state.query.periodId.trim().isNotEmpty)
              'periodId': state.query.periodId.trim(),
            if (state.query.id.trim().isNotEmpty)
              'journal': state.query.id.trim(),
          },
          options: <String, String>{
            if (state.query.status.trim().isNotEmpty)
              'status': state.query.status.trim(),
            if (state.query.source.trim().isNotEmpty)
              'approval_type': state.query.source.trim(),
          },
          dateFrom: state.query.from,
          dateTo: state.query.to,
        ),
        hasActiveFilters: state.query.hasActiveFilters,
        onFilterChanged: (AppSearchBarFilterValue value) {
          if (!value.isActive) {
            unawaited(controller.clearFilters());
            return;
          }
          unawaited(
            controller.applyQuery(
              state.query.copyWith(
                section: section,
                accountId: value.text('accountId') ?? '',
                periodId: value.text('periodId') ?? '',
                id: value.text('journal') ?? '',
                status: value.option('status') ?? '',
                source: value.option('approval_type') ?? '',
                from: value.dateFrom,
                to: value.dateTo,
                clearFrom: value.dateFrom == null,
                clearTo: value.dateTo == null,
                clearAccountId: (value.text('accountId') ?? '').isEmpty,
                clearPeriodId: (value.text('periodId') ?? '').isEmpty,
                clearId: (value.text('journal') ?? '').isEmpty,
                clearStatus: (value.option('status') ?? '').isEmpty,
                clearSource: (value.option('approval_type') ?? '').isEmpty,
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
        unawaited(
          showAccountsWorkItemDetailDialog(
            context,
            ref,
            item,
            canWrite: canWrite,
            canApprove: canApprove,
          ),
        );
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
      columns: columns,
      columnChoices: accountsApprovalsColumnChoices(
        context: context,
        ref: ref,
        accessPolicy: accessPolicy,
        isSaving: state.isSaving,
        onNextAction: _runApprove,
      ),
      mobileItemBuilder: (BuildContext context, AccountsWorkItem item) {
        return AppListTableMobileItem(
          title: accountsWorkItemPublicId(item),
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
    await showAccountsApproveDialog(context, ref);
  }
}
