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
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_work_actions.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_table_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

export 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_work_actions.dart'
    show
        runAccountsNextAction,
        showAccountsMutationSnackBar,
        showAccountsPostDialog,
        showAccountsWorkItemDetailDialog;

/// To post desk (`?section=journals`) - draft journals ready to post.
class AccountsToPostPanel extends ConsumerStatefulWidget {
  const AccountsToPostPanel({
    super.key,
    required this.state,
    this.initialAction = '',
    this.initialId = '',
  });

  final AccountsWorkspaceState state;
  final String initialAction;
  final String initialId;

  @override
  ConsumerState<AccountsToPostPanel> createState() =>
      _AccountsToPostPanelState();
}

class _AccountsToPostPanelState extends ConsumerState<AccountsToPostPanel> {
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<AccountsWorkItem>
  _columnVisibilityController;
  Timer? _searchDebounce;
  bool _handledDeepLink = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _columnVisibilityController =
        AppListTableColumnVisibilityController<AccountsWorkItem>();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeOpenDeepLink());
    });
  }

  @override
  void didUpdateWidget(covariant AccountsToPostPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
    if (oldWidget.initialAction != widget.initialAction ||
        oldWidget.initialId != widget.initialId) {
      _handledDeepLink = false;
    }
    final bool listChanged =
        oldWidget.state.workItems.items.length !=
            widget.state.workItems.items.length ||
        oldWidget.state.isRefreshing != widget.state.isRefreshing ||
        oldWidget.state.query.section != widget.state.query.section;
    if (!_handledDeepLink &&
        (listChanged ||
            oldWidget.initialAction != widget.initialAction ||
            oldWidget.initialId != widget.initialId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeOpenDeepLink());
      });
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

  Future<void> _maybeOpenDeepLink() async {
    if (_handledDeepLink || !mounted) {
      return;
    }
    final String action = widget.initialAction.trim().toLowerCase();
    if (action != 'post') {
      return;
    }
    // Wait until the journals section query has settled (avoid work-section race).
    if (widget.state.query.section != AccountsDeskSection.journals ||
        widget.state.isRefreshing) {
      return;
    }
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (!canWriteAccounts(policy)) {
      _handledDeepLink = true;
      return;
    }

    final String targetId = widget.initialId.trim();
    AccountsWorkItem? target;
    for (final AccountsWorkItem item in widget.state.workItems.items) {
      if (!item.canPost) {
        continue;
      }
      if (targetId.isEmpty ||
          item.id == targetId ||
          item.effectiveDisplayId == targetId ||
          (item.journalDisplayId ?? '') == targetId ||
          (item.displayId ?? '') == targetId) {
        target = item;
        break;
      }
    }
    if (target == null) {
      // List loaded but no match — stop retrying so we do not loop forever.
      if (!widget.state.isRefreshing) {
        _handledDeepLink = true;
      }
      return;
    }
    _handledDeepLink = true;
    ref.read(accountsWorkspaceControllerProvider.notifier).selectItem(target);
    if (!context.mounted) {
      return;
    }
    await showAccountsPostDialog(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final AccountsWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteAccounts(accessPolicy);
    final bool canApprove = canDecideAccountsApproval(accessPolicy);
    final bool canEnter = canEnterAccounts(accessPolicy);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
    final AccountsWorkspaceController controller = ref.read(
      accountsWorkspaceControllerProvider.notifier,
    );
    const AccountsDeskSection section = AccountsDeskSection.journals;
    final Object? failure = state.lastFailure;
    final List<AppListTableColumn<AccountsWorkItem>> columns =
        accountsColumnsForSection(
          context,
          section,
          ref: ref,
          accessPolicy: accessPolicy,
          isSaving: state.isSaving,
          onNextAction:
              (BuildContext _, WidgetRef actionRef, AccountsWorkItem item) {
            return runAccountsNextAction(context, actionRef, item);
          },
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
      onPrint: () => printAccountsListTable<AccountsWorkItem>(
        ref: ref,
        context: context,
        title: AccountsStrings.toPostLabel,
        columns: columns,
        items: state.workItems.items,
        emptyText: AccountsStrings.toPostEmpty,
      ),
      goToTopLabel: context.l10n.commonGoToTopActionLabel,
      loadingMoreLabel: context.l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: context.l10n.commonAllRowsLoadedLabel,
      exportConfig: AppListTableExportConfig<AccountsWorkItem>(
        fileNameStem: 'accounts_to_post',
        dateOf: (AccountsWorkItem item) => item.timelineAt,
        sheetName: AccountsStrings.toPostLabel,
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
            key: 'source',
            label: AccountsStrings.sourceFilterLabel,
            allLabel: AccountsStrings.anySource,
            choices: <AppSearchBarFilterChoice>[
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
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'DRAFT',
                label: AccountsStrings.statusDraft,
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
        trailingActions: _trailingActions(
          context,
          canWrite: canWrite,
          enabled: !state.isSaving,
          postable: state.workItems.items
              .where((AccountsWorkItem item) => item.canPost)
              .toList(growable: false),
        ),
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
        title: AccountsStrings.toPostEmpty,
        body: '',
      ),
      columns: columns,
      columnChoices: accountsColumnChoicesForSection(
        context,
        section,
        ref: ref,
        accessPolicy: accessPolicy,
        isSaving: state.isSaving,
        onNextAction:
            (BuildContext _, WidgetRef actionRef, AccountsWorkItem item) {
          return runAccountsNextAction(context, actionRef, item);
        },
      ),
      mobileItemBuilder: (BuildContext context, AccountsWorkItem item) {
        return AppListTableMobileItem(
          title: item.effectiveDisplayId,
          caption: (item.periodLabel ?? '').trim().isEmpty
              ? AccountsStrings.unknownValue
              : item.periodLabel!,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: accountsWorkItemStatusLabel(context, item),
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
            canEnter: canEnter,
            isSaving: state.isSaving,
            section: section,
            onPressed: () => runAccountsNextAction(context, ref, item),
          ),
        );
      },
    );
  }

  List<AppSearchBarAction> _trailingActions(
    BuildContext context, {
    required bool canWrite,
    required bool enabled,
    required List<AccountsWorkItem> postable,
  }) {
    if (!canWrite) {
      return const <AppSearchBarAction>[];
    }
    final bool canPostAll = enabled && postable.isNotEmpty;
    return <AppSearchBarAction>[
      AppSearchBarAction(
        icon: Icons.publish_outlined,
        label: AccountsStrings.postAllAction,
        tooltip: AccountsStrings.postAllAction,
        enabled: canPostAll,
        onPressed: canPostAll
            ? () => unawaited(showAccountsPostAllDialog(context, ref, postable))
            : null,
      ),
    ];
  }
}

Future<void> showAccountsPostAllDialog(
  BuildContext context,
  WidgetRef ref,
  List<AccountsWorkItem> postable,
) async {
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => const AppConfirmActionDialog(
      title: AccountsStrings.postAllConfirmTitle,
      body: AccountsStrings.postAllConfirmBody,
      submitLabel: AccountsStrings.postAllAction,
      icon: Icon(Icons.publish_outlined),
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .postJournals(
        postable.map((AccountsWorkItem item) => item.id).toList(growable: false),
      );
  if (!context.mounted) {
    return;
  }
  showAccountsMutationSnackBar(
    context,
    ref,
    failure,
    successMessage: AccountsStrings.posted,
  );
}
