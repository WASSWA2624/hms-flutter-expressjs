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
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_detail_widgets.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_form_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_patient_ledger_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_table_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

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
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (!canWriteAccounts(policy)) {
      return;
    }
    _handledDeepLink = true;

    final String targetId = widget.initialId.trim();
    AccountsWorkItem? target;
    for (final AccountsWorkItem item in widget.state.workItems.items) {
      if (!item.canPost) {
        continue;
      }
      if (targetId.isEmpty ||
          item.id == targetId ||
          item.effectiveDisplayId == targetId ||
          (item.journalDisplayId ?? '') == targetId) {
        target = item;
        break;
      }
    }
    if (target == null) {
      return;
    }
    ref.read(accountsWorkspaceControllerProvider.notifier).selectItem(target);
    await showAccountsPostDialog(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final AccountsWorkspaceState state = widget.state;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteAccounts(accessPolicy);
    final bool canApprove = canDecideAccountsApproval(accessPolicy);
    final bool canEnter = canEnterAccounts(accessPolicy);
    final AccountsWorkspaceController controller = ref.read(
      accountsWorkspaceControllerProvider.notifier,
    );
    const AccountsDeskSection section = AccountsDeskSection.journals;

    return AppListTable<AccountsWorkItem>(
      page: state.workItems,
      isLoading: state.isRefreshing,
      columnVisibilityController: _columnVisibilityController,
      columnVisibilityStorageKey: accountsTableSettingsKey(section),
      columnWidthStorageKey: '${accountsTableSettingsKey(section)}_cw',
      columnVisibilityLabel: context.l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: context.l10n.commonTableSettingsTitle,
      enableExport: true,
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
        advancedFilterButtonLabel: AccountsStrings.filtersLabel,
        advancedFilterTitle: context.l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: context.l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: AccountsStrings.clearFilters,
        allFieldsLabel: AccountsStrings.allFields,
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
          options: <String, String>{
            if (state.query.status.trim().isNotEmpty)
              'status': state.query.status.trim(),
            if (state.query.source.trim().isNotEmpty)
              'source': state.query.source.trim(),
          },
        ),
        hasActiveFilters: state.query.hasActiveFilters,
        onFilterChanged: (AppSearchBarFilterValue value) {
          if (!value.isActive) {
            unawaited(controller.clearFilters());
            return;
          }
          final String status = (value.options['status'] ?? '').trim();
          final String source = (value.options['source'] ?? '').trim();
          unawaited(
            controller.applyQuery(
              state.query.copyWith(
                section: section,
                status: status,
                source: source,
                clearStatus: status.isEmpty,
                clearSource: source.isEmpty,
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
      columns: accountsColumnsForSection(
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

Future<void> showAccountsPostDialog(BuildContext context, WidgetRef ref) async {
  final AccountsOptionalNotesResult? result =
      await showAppDialog<AccountsOptionalNotesResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AccountsNotesForm(
          dialogTitle: const Text(AccountsStrings.postDialogTitle),
          dialogIcon: const Icon(Icons.publish_outlined),
          submitLabel: AccountsStrings.postAction,
        ),
      );
  if (result == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .postSelectedJournal(notes: result.notes);
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

Future<void> runAccountsNextAction(
  BuildContext context,
  WidgetRef ref,
  AccountsWorkItem item,
) async {
  if (!item.canPost) {
    return;
  }
  if (!canWriteAccounts(ref.read(appAccessPolicyProvider))) {
    return;
  }
  ref.read(accountsWorkspaceControllerProvider.notifier).selectItem(item);
  if (!context.mounted) {
    return;
  }
  await showAccountsPostDialog(context, ref);
}

Future<void> showAccountsWorkItemDetailDialog(
  BuildContext context,
  WidgetRef ref,
  AccountsWorkItem item, {
  required bool canWrite,
  required bool canApprove,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final AppAccessPolicy accessPolicy = ref.watch(
            appAccessPolicyProvider,
          );
          final AccountsWorkspaceState? workspace = ref
              .watch(accountsWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (AccountsWorkspaceState value) => value,
                failure: (_) => null,
              );
          final AccountsWorkItem live = workspace?.selectedItem?.id == item.id
              ? workspace!.selectedItem!
              : item;
          final bool isSaving = workspace?.isSaving ?? false;
          return AppDialog(
            title: Text(accountsDetailTitle(context, live)),
            icon: const Icon(Icons.receipt_long_outlined),
            scrollable: true,
            maxWidth: 860,
            content: AccountsDetailBody(
              item: live,
              canWrite: canWrite,
              canApprove: canApprove,
              isSaving: isSaving,
              onPost: canWrite && live.canPost
                  ? () => unawaited(showAccountsPostDialog(context, ref))
                  : null,
              onReverse: canWrite && live.canReverse ? () {} : null,
              onVoid: canWrite && live.canVoid ? () {} : null,
              onSend: canWrite && live.isJournal ? () {} : null,
              onOpenGl: live.canOpenGl && canViewAccountsGl(accessPolicy)
                  ? () {}
                  : null,
              onOpenLedger:
                  live.canOpenLedger &&
                      canReadAccountsPatientLedgers(accessPolicy)
                  ? () => unawaited(
                      showAccountsPatientLedgerDialog(
                        context,
                        ref,
                        patientId: live.patientId ?? '',
                        patientDisplayName: live.patientDisplayName,
                        currency: live.currency,
                      ),
                    )
                  : null,
            ),
          );
        },
      );
    },
  );
}

void showAccountsMutationSnackBar(
  BuildContext context,
  WidgetRef ref,
  AppFailure? failure, {
  String? successMessage,
}) {
  if (!context.mounted) {
    return;
  }
  final bool pendingApproval =
      ref
          .read(accountsWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (AccountsWorkspaceState state) =>
                state.lastActionPendingApproval,
            failure: (_) => false,
          ) ??
      false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? (successMessage ??
                  (pendingApproval
                      ? AccountsStrings.submittedForApproval
                      : AccountsStrings.saved))
            : context.l10n.failureMessage(failure),
      ),
    ),
  );
}
