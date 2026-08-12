import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_similarity.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_similarity_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_work_actions.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_table_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/routing/workspace_location_sync.dart';

/// Open work desk (`?section=work`) — cross-queue items needing action.
class AccountsOpenWorkPanel extends ConsumerStatefulWidget {
  const AccountsOpenWorkPanel({super.key, required this.state});

  final AccountsWorkspaceState state;

  @override
  ConsumerState<AccountsOpenWorkPanel> createState() =>
      _AccountsOpenWorkPanelState();
}

class _AccountsOpenWorkPanelState extends ConsumerState<AccountsOpenWorkPanel> {
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
  void didUpdateWidget(covariant AccountsOpenWorkPanel oldWidget) {
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
      unawaited(
        ref
            .read(accountsWorkspaceControllerProvider.notifier)
            .applySearch(_searchController.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AccountsWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteAccounts(accessPolicy);
    final bool canApprove = canApproveAccounts(accessPolicy);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
    final AccountsWorkspaceController controller = ref.read(
      accountsWorkspaceControllerProvider.notifier,
    );
    const AccountsDeskSection section = AccountsDeskSection.work;
    final List<AppListTableColumn<AccountsWorkItem>> columns =
        accountsColumnsForSection(
          context,
          section,
          ref: ref,
          accessPolicy: accessPolicy,
          isSaving: state.isSaving,
          onNextAction: runAccountsNextAction,
        );

    return AppListTable<AccountsWorkItem>(
      page: state.workItems,
      isLoading: state.isRefreshing,
      error: () {
        final Object? failure = state.lastFailure;
        if (failure is! AppFailure) {
          return null;
        }
        return context.l10n.failureMessage(failure);
      }(),
      columnVisibilityController: _columnVisibilityController,
      columnVisibilityStorageKey: accountsTableSettingsKey(section),
      columnWidthStorageKey: '${accountsTableSettingsKey(section)}_cw',
      columnVisibilityLabel: context.l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: context.l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: context.l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: context.l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: context.l10n.commonCloseActionLabel,
      enableExport: true,
      canExport: canExport,
      exportLabel: context.l10n.commonTableExportActionLabel,
      exportDialogTitle: context.l10n.commonTableExportDialogTitle,
      exportCancelLabel: context.l10n.commonCancelActionLabel,
      exportColumnsSectionLabel: context.l10n.commonTableExportColumnsSectionLabel,
      exportFiltersSectionLabel: context.l10n.commonTableExportFiltersSectionLabel,
      exportEmptyColumnsMessage: context.l10n.commonTableExportEmptyColumnsMessage,
      exportEmptyRowsMessage: context.l10n.commonTableExportEmptyRowsMessage,
      exportSuccessMessage: context.l10n.commonTableExportSuccessMessage,
      exportFailureMessage: context.l10n.commonTableExportFailureMessage,
      exportInvalidDateMessage: context.l10n.opdInvalidDateMessage,
      enablePrint: true,
      canPrint: canPrint,
      printLabel: context.l10n.commonPrintActionLabel,
      onPrint: (items) => printAccountsListTable<AccountsWorkItem>(
        ref: ref,
        context: context,
        title: AccountsStrings.openWorkLabel,
        columns: columns,
        items: items,
        emptyText: AccountsStrings.openWorkEmpty,
      ),
      goToTopLabel: context.l10n.commonGoToTopActionLabel,
      loadingMoreLabel: context.l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: context.l10n.commonAllRowsLoadedLabel,
      exportConfig: AppListTableExportConfig<AccountsWorkItem>(
        fileNameStem: 'accounts_open_work',
        dateOf: (AccountsWorkItem item) => item.timelineAt,
        sheetName: AccountsStrings.openWorkLabel,
        dateFromLabel: context.l10n.commonTableExportDateFromLabel,
        dateToLabel: context.l10n.commonTableExportDateToLabel,
      ),
      search: AppListTableSearch<AccountsWorkItem>(
        controller: _searchController,
        semanticLabel: AccountsStrings.searchSemantic,
        hintText: AccountsStrings.searchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsWorkItem item, String query) =>
            accountsWorkItemMatchesSearch(context, item, query),
        onSubmitted: controller.applySearch,
        onClear: () => controller.applySearch(''),
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: context.l10n.commonFiltersActionLabel,
        advancedFilterTitle: context.l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: context.l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: context.l10n.opdClearFiltersAction,
        advancedFilterCloseLabel: context.l10n.commonCloseActionLabel,
        enableDateFilter: true,
        dateFilterLabel: AccountsStrings.postedDateFilterLabel,
        dateFromLabel: context.l10n.opdDateFromLabel,
        dateToLabel: context.l10n.opdDateToLabel,
        allFieldsLabel: AccountsStrings.allFields,
        textFilters: <AppSearchBarTextFilter>[
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
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: 'source',
            label: AccountsStrings.sourceFilterLabel,
            allLabel: AccountsStrings.anySource,
            choices: const <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'Manual',
                label: AccountsStrings.sourceManual,
              ),
              AppSearchBarFilterChoice(
                value: 'Billing',
                label: AccountsStrings.sourceBilling,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: 'status',
            label: AccountsStrings.statusFilterLabel,
            allLabel: AccountsStrings.anyStatus,
            choices: const <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'DRAFT',
                label: AccountsStrings.statusDraft,
              ),
              AppSearchBarFilterChoice(
                value: 'PENDING',
                label: AccountsStrings.statusPending,
              ),
              AppSearchBarFilterChoice(
                value: 'POSTED',
                label: AccountsStrings.statusPosted,
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
              'source': state.query.source.trim(),
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
                source: value.option('source') ?? '',
                status: value.option('status') ?? '',
                from: value.dateFrom,
                to: value.dateTo,
                clearFrom: value.dateFrom == null,
                clearTo: value.dateTo == null,
                clearAccountId: (value.text('accountId') ?? '').isEmpty,
                clearPeriodId: (value.text('periodId') ?? '').isEmpty,
                clearId: (value.text('journal') ?? '').isEmpty,
                clearSource: (value.option('source') ?? '').isEmpty,
                clearStatus: (value.option('status') ?? '').isEmpty,
                pageRequest: state.query.pageRequest.first(),
              ),
            ),
          );
        },
        trailingActions: canWrite
            ? <AppSearchBarAction>[
                AppSearchBarAction(
                  icon: Icons.post_add_outlined,
                  label: AccountsStrings.journalAction,
                  tooltip: AccountsStrings.journalActionTooltip,
                  enabled: !state.isSaving,
                  onPressed: state.isSaving
                      ? null
                      : () => unawaited(_createJournal(context, ref)),
                ),
              ]
            : const <AppSearchBarAction>[],
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
        title: AccountsStrings.openWorkEmpty,
        body: '',
      ),
      columns: columns,
      columnChoices: accountsColumnChoicesForSection(
        context,
        section,
        ref: ref,
        accessPolicy: accessPolicy,
        isSaving: state.isSaving,
        onNextAction: runAccountsNextAction,
      ),
      mobileItemBuilder: (BuildContext context, AccountsWorkItem item) {
        return AppListTableMobileItem(
          title: item.effectiveDisplayId,
          caption: item.source.isEmpty
              ? AccountsStrings.unknownValue
              : item.source,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: accountsStatusLabel(item.status),
              icon: accountsWorkItemStatusIcon(item),
            ),
            AppListTableMobileMeta(
              label: accountsMoney(context, item.amount, item.currency),
              icon: Icons.payments_outlined,
            ),
          ],
          trailing: AccountsNextActionButton(
            item: item,
            canWrite: canWrite,
            canApprove: canApprove,
            canEnter: canEnterAccounts(accessPolicy),
            isSaving: state.isSaving,
            onPressed: () => runAccountsNextAction(context, ref, item),
          ),
        );
      },
    );
  }
}

Future<void> _createJournal(BuildContext context, WidgetRef ref) async {
  final AccountsJournalDraft? draft = await showAccountsJournalDialog(context);
  if (draft == null || !context.mounted) {
    return;
  }

  final AccountsWorkspaceState? workspace = ref
      .read(accountsWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (AccountsWorkspaceState value) => value,
        failure: (_) => null,
      );
  final List<AccountsWorkItem> candidates = <AccountsWorkItem>[
    ...?workspace?.workItems.items,
  ];
  final AccountsJournalSimilarityResult check = checkAccountsJournalSimilarity(
    draft: draft,
    candidates: candidates,
  );
  if (check.hasMatches && context.mounted) {
    final AccountsJournalSimilarityDialogResult review =
        await showAccountsJournalSimilarityDialog(
          context,
          draft: draft,
          check: check,
        );
    if (!context.mounted) {
      return;
    }
    switch (review.action) {
      case AccountsJournalSimilarityAction.cancel:
        return;
      case AccountsJournalSimilarityAction.useExisting:
        final AccountsWorkItem? existing = review.selectedItem;
        if (existing == null) {
          return;
        }
        ref
            .read(accountsWorkspaceControllerProvider.notifier)
            .selectItem(existing);
        await showAccountsWorkItemDetailDialog(
          context,
          ref,
          existing,
          canWrite: canWriteAccounts(ref.read(appAccessPolicyProvider)),
          canApprove: canApproveAccounts(ref.read(appAccessPolicyProvider)),
        );
        return;
      case AccountsJournalSimilarityAction.proceed:
        break;
    }
  }

  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .createJournal(draft);
  if (!context.mounted) {
    return;
  }
  showAccountsMutationSnackBar(
    context,
    ref,
    failure,
    successMessage: AccountsStrings.saved,
  );
  if (failure != null) {
    return;
  }
  syncWorkspaceLocation(
    context,
    AppRoutes.accounts.location(
      queryParameters: const <String, String>{'section': 'journals'},
    ),
  );
  unawaited(
    ref
        .read(accountsWorkspaceControllerProvider.notifier)
        .applySection(AccountsDeskSection.journals),
  );
}
