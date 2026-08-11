import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_books_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_form_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_period_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Close books fiscal-period table for `/accounts?section=books`.
class AccountsBooksPanel extends ConsumerStatefulWidget {
  const AccountsBooksPanel({
    super.key,
    this.initialPeriodId = '',
    this.initialAction = '',
    this.initialSearch = '',
  });

  final String initialPeriodId;
  final String initialAction;
  final String initialSearch;

  @override
  ConsumerState<AccountsBooksPanel> createState() => _AccountsBooksPanelState();
}

class _AccountsBooksPanelState extends ConsumerState<AccountsBooksPanel> {
  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<AccountsFiscalPeriod>
  _columnController =
      AppListTableColumnVisibilityController<AccountsFiscalPeriod>(
        storageKey: accountsBooksTableSettingsKey,
      );

  AppPage<AccountsFiscalPeriod> _page = const AppPage<AccountsFiscalPeriod>(
    items: <AccountsFiscalPeriod>[],
    request: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    totalItemCount: 0,
  );
  bool _loading = true;
  AppFailure? _failure;
  bool _openOnly = false;
  bool _overdueOnly = false;
  Timer? _searchDebounce;
  bool _handledDeepLink = false;
  AccountsFiscalPeriod? _contextPeriod;
  bool _mutating = false;

  String? get _facilityId =>
      ref.read(sessionStateProvider).session?.user?.facilityId;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch.trim().isNotEmpty) {
      _searchController.text = widget.initialSearch.trim();
    }
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reload(openDeepLink: true));
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _columnController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_reload());
    });
  }

  bool get _hasActiveFilters {
    return _openOnly ||
        _overdueOnly ||
        _searchController.text.trim().isNotEmpty;
  }

  Future<void> _reload({bool openDeepLink = false}) async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final Result<AppPage<AccountsFiscalPeriod>> result = await ref
        .read(accountsRepositoryProvider)
        .listPeriods(
          AccountsPeriodQuery(
            search: _searchController.text.trim(),
            openOnly: _openOnly,
            overdueOnly: _overdueOnly,
          ),
          facilityId: _facilityId,
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<AccountsFiscalPeriod> page) {
        setState(() {
          _page = page;
          _loading = false;
          final AccountsFiscalPeriod? context = _contextPeriod;
          if (context != null) {
            for (final AccountsFiscalPeriod item in page.items) {
              if (item.id == context.id) {
                _contextPeriod = item;
                break;
              }
            }
          }
        });
        if (!_hasActiveFilters) {
          final int openCount = page.items
              .where((AccountsFiscalPeriod p) => p.isOpen)
              .length;
          ref.read(accountsOpenPeriodsCountProvider.notifier).state = openCount;
        }
        if (openDeepLink) {
          unawaited(_maybeOpenDeepLink(page.items));
        }
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loading = false;
        });
      },
    );
  }

  Future<AccountsFiscalPeriod?> _resolvePeriod(
    String periodId,
    List<AccountsFiscalPeriod> items,
  ) async {
    final String id = periodId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final AccountsFiscalPeriod item in items) {
      if (item.id == id ||
          (item.displayId ?? '').trim() == id ||
          item.label.trim() == id) {
        return item;
      }
    }
    final Result<AccountsFiscalPeriod> fetched = await ref
        .read(accountsRepositoryProvider)
        .getPeriod(id, facilityId: _facilityId);
    return fetched.when(
      success: (AccountsFiscalPeriod period) => period,
      failure: (_) => null,
    );
  }

  Future<void> _maybeOpenDeepLink(List<AccountsFiscalPeriod> items) async {
    if (_handledDeepLink) {
      return;
    }
    final String action = widget.initialAction.trim().toLowerCase();
    final String periodId = widget.initialPeriodId.trim();
    if (action.isEmpty && periodId.isEmpty) {
      return;
    }
    _handledDeepLink = true;

    final AccountsFiscalPeriod? match = await _resolvePeriod(periodId, items);
    if (!mounted) {
      return;
    }

    if (action == 'close') {
      await _closePeriod(match ?? _contextPeriod);
      return;
    }

    if (match != null) {
      await _openDetail(match);
    }
  }

  Future<void> _refreshAfterMutation({required bool approvalRequired}) async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approvalRequired
              ? AccountsStrings.submittedForApproval
              : AccountsStrings.saved,
        ),
      ),
    );
    await _reload();
    await ref.read(accountsWorkspaceControllerProvider.notifier).refresh();
  }

  Future<void> _openPeriod() async {
    final AccountsOpenPeriodDraft? draft =
        await showAccountsOpenPeriodDialog(context);
    if (draft == null || !mounted) {
      return;
    }
    setState(() => _mutating = true);
    final Result<AccountsMutationResult> result = await ref
        .read(accountsRepositoryProvider)
        .openPeriod(draft);
    if (!mounted) {
      return;
    }
    setState(() => _mutating = false);
    await result.when(
      success: (AccountsMutationResult mutation) async {
        await _refreshAfterMutation(
          approvalRequired: mutation.approvalRequired,
        );
      },
      failure: (AppFailure failure) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failureMessage(failure))),
        );
      },
    );
  }

  Future<void> _closePeriod(AccountsFiscalPeriod? period) async {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (!canWriteAccounts(policy)) {
      return;
    }

    AccountsFiscalPeriod? target = period ?? _contextPeriod;
    if (target == null) {
      for (final AccountsFiscalPeriod item in _page.items) {
        if (item.canClose) {
          target = item;
          break;
        }
      }
    }
    if (target == null) {
      return;
    }

    final AccountsNotesDraft? draft = await showAccountsClosePeriodDialog(
      context,
      period: target,
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() => _mutating = true);
    final Result<AccountsMutationResult> result = await ref
        .read(accountsRepositoryProvider)
        .closePeriod(target.id, notes: draft.notes);
    if (!mounted) {
      return;
    }
    setState(() => _mutating = false);
    await result.when(
      success: (AccountsMutationResult mutation) async {
        await _refreshAfterMutation(
          approvalRequired: mutation.approvalRequired,
        );
      },
      failure: (AppFailure failure) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failureMessage(failure))),
        );
      },
    );
  }

  Future<void> _approvePeriod(AccountsFiscalPeriod period) async {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final String approvalId = (period.pendingApprovalId ?? '').trim();
    if (approvalId.isEmpty || !canApproveAccountsMutations(policy)) {
      return;
    }

    final AccountsNotesDraft? draft = await showAppDialog<AccountsNotesDraft>(
      context: context,
      builder: (_) => const AccountsClosePeriodForm(
        dialogTitle: Text(AccountsStrings.approveAction),
        dialogIcon: Icon(Icons.check_circle_outline),
        submitLabel: AccountsStrings.approveAction,
      ),
    );
    if (draft == null || !mounted) {
      return;
    }

    setState(() => _mutating = true);
    final Result<AccountsMutationResult> result = await ref
        .read(accountsRepositoryProvider)
        .approveRequest(approvalId, notes: draft.notes);
    if (!mounted) {
      return;
    }
    setState(() => _mutating = false);
    await result.when(
      success: (AccountsMutationResult mutation) async {
        await _refreshAfterMutation(
          approvalRequired: mutation.approvalRequired,
        );
      },
      failure: (AppFailure failure) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failureMessage(failure))),
        );
      },
    );
  }

  void _viewUnposted() {
    GoRouter.of(context).go(
      AppRoutes.accounts.location(
        queryParameters: const <String, String>{'section': 'journals'},
      ),
    );
  }

  Future<void> _openDetail(AccountsFiscalPeriod period) async {
    setState(() => _contextPeriod = period);
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final bool canWrite = canWriteAccounts(policy);
    final bool canApprove = canApproveAccountsMutations(policy);

    await showAccountsBooksDetailDialog(
      context,
      period: period,
      onViewUnposted: _viewUnposted,
      onClose: canWrite && period.canClose
          ? () => unawaited(_closePeriod(period))
          : null,
      onApprove: canApprove && period.canApproveClose
          ? () => unawaited(_approvePeriod(period))
          : null,
    );
  }

  Future<void> _runNext(
    AppAccessPolicy policy,
    AccountsFiscalPeriod period,
  ) async {
    setState(() => _contextPeriod = period);
    final String? label = accountsBooksNextActionLabel(
      policy: policy,
      period: period,
    );
    if (label == 'Close') {
      await _closePeriod(period);
    } else if (label == 'Approve') {
      await _approvePeriod(period);
    } else if (label == 'Books') {
      await _openDetail(period);
    }
  }

  int get _openFilterCount =>
      _page.items.where((AccountsFiscalPeriod p) => p.isOpen).length;

  int get _overdueFilterCount =>
      _page.items.where((AccountsFiscalPeriod p) => p.isOverdue).length;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteAccounts(accessPolicy);
    final Color danger = workspaceStatusToneAccentColor(
      theme,
      AppWorkspaceStatusTone.error,
    );

    if (_failure != null && _page.items.isEmpty && !_loading) {
      return AppFailureStateView(
        failure: _failure!,
        onRetry: () => unawaited(_reload()),
      );
    }

    final Widget table = AppListTable<AccountsFiscalPeriod>(
      page: _page,
      isLoading: _loading || _mutating,
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: accountsBooksTableSettingsKey,
      columnWidthStorageKey: '${accountsBooksTableSettingsKey}_cw',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columns: _defaultColumns(accessPolicy),
      columnChoices: _optionalColumns(),
      search: AppListTableSearch<AccountsFiscalPeriod>(
        controller: _searchController,
        semanticLabel: AccountsStrings.booksSearchHint,
        hintText: AccountsStrings.booksSearchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsFiscalPeriod item, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          return <String>[
            item.effectiveLabel,
            item.label,
            item.status,
            item.facilityLabel ?? '',
            item.byLabel,
          ].any((String value) => value.toLowerCase().contains(needle));
        },
        onSubmitted: (_) => unawaited(_reload()),
        onClear: () {
          _searchController.clear();
          unawaited(_reload());
        },
        trailingActions: <AppSearchBarAction>[
          if (canWrite)
            AppSearchBarAction(
              label: AccountsStrings.openPeriodAction,
              tooltip: AccountsStrings.openPeriodAction,
              icon: Icons.lock_open_outlined,
              onPressed: _mutating ? null : () => unawaited(_openPeriod()),
            ),
          if (canWrite)
            AppSearchBarAction(
              label: AccountsStrings.closePeriodAction,
              tooltip: AccountsStrings.closePeriodAction,
              icon: Icons.lock_clock_outlined,
              onPressed: _mutating
                  ? null
                  : () => unawaited(_closePeriod(_contextPeriod)),
            ),
        ],
      ),
      emptyBuilder: (_) => const AppWorkspaceStatePanel.empty(
        title: AccountsStrings.booksEmpty,
        body: AccountsStrings.booksEmpty,
      ),
      onRowSelected: (AccountsFiscalPeriod period) {
        unawaited(_openDetail(period));
      },
      mobileItemBuilder: (BuildContext context, AccountsFiscalPeriod period) {
        final String? next = accountsBooksNextActionLabel(
          policy: accessPolicy,
          period: period,
        );
        return AppListTableMobileItem(
          title: period.effectiveLabel,
          caption: accountsPeriodStatusLabel(period),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: accountsDateTime(context, period.openedAt),
              icon: Icons.event_available_outlined,
            ),
          ],
          trailing: next == null
              ? null
              : AppButton.tertiary(
                  label: next,
                  dense: true,
                  onPressed: () => unawaited(_runNext(accessPolicy, period)),
                ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                FilterChip(
                  selected: _openOnly,
                  showCheckmark: false,
                  label: Text(
                    _openFilterCount > 0
                        ? '${AccountsStrings.booksOpenFilter} ($_openFilterCount)'
                        : AccountsStrings.booksOpenFilter,
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      _openOnly = selected;
                      if (selected) {
                        _overdueOnly = false;
                      }
                    });
                    unawaited(_reload());
                  },
                ),
                FilterChip(
                  selected: _overdueOnly,
                  showCheckmark: false,
                  avatar: Icon(
                    Icons.warning_amber_outlined,
                    size: 18,
                    color: danger,
                  ),
                  label: Text(
                    _overdueFilterCount > 0
                        ? '${AccountsStrings.booksOverdueFilter} ($_overdueFilterCount)'
                        : AccountsStrings.booksOverdueFilter,
                    style: TextStyle(color: danger),
                  ),
                  selectedColor: danger.withValues(alpha: 0.16),
                  side: BorderSide(color: danger.withValues(alpha: 0.45)),
                  onSelected: (bool selected) {
                    setState(() {
                      _overdueOnly = selected;
                      if (selected) {
                        _openOnly = false;
                      }
                    });
                    unawaited(_reload());
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(child: table),
      ],
    );
  }

  List<AppListTableColumn<AccountsFiscalPeriod>> _defaultColumns(
    AppAccessPolicy accessPolicy,
  ) {
    return <AppListTableColumn<AccountsFiscalPeriod>>[
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsBooksPeriodColumnId,
        label: AccountsStrings.periodColumn,
        alwaysVisible: true,
        preferredWidth: 200,
        cellBuilder: (_, AccountsFiscalPeriod item) => Text(
          item.effectiveLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            a.effectiveLabel.compareTo(b.effectiveLabel),
        exportValue: (AccountsFiscalPeriod item) => item.effectiveLabel,
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsBooksStatusColumnId,
        label: AccountsStrings.statusColumn,
        preferredWidth: 140,
        cellBuilder: (BuildContext context, AccountsFiscalPeriod item) {
          final AppWorkspaceStatusTone tone = item.isOverdue
              ? AppWorkspaceStatusTone.error
              : item.isPendingApproval || item.isOpen
              ? AppWorkspaceStatusTone.warning
              : AppWorkspaceStatusTone.neutral;
          return AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: accountsPeriodStatusLabel(item),
              tone: tone,
              icon: item.isClosed
                  ? Icons.lock_outlined
                  : Icons.lock_open_outlined,
            ),
          );
        },
        exportValue: (AccountsFiscalPeriod item) =>
            accountsPeriodStatusLabel(item),
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsBooksOpenedColumnId,
        label: AccountsStrings.openedColumn,
        preferredWidth: 160,
        cellBuilder: (BuildContext context, AccountsFiscalPeriod item) =>
            Text(accountsDateTime(context, item.openedAt)),
        exportValue: (AccountsFiscalPeriod item) =>
            item.openedAt?.toIso8601String(),
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsBooksClosedColumnId,
        label: AccountsStrings.closedColumn,
        preferredWidth: 160,
        cellBuilder: (BuildContext context, AccountsFiscalPeriod item) =>
            Text(accountsDateTime(context, item.closedAt)),
        exportValue: (AccountsFiscalPeriod item) =>
            item.closedAt?.toIso8601String(),
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsBooksNextColumnId,
        label: AccountsStrings.nextColumn,
        preferredWidth: 100,
        exportable: false,
        cellBuilder: (BuildContext context, AccountsFiscalPeriod item) {
          final String? label = accountsBooksNextActionLabel(
            policy: accessPolicy,
            period: item,
          );
          if (label == null) {
            return const SizedBox.shrink();
          }
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.tertiary(
              label: label,
              tooltip: accountsBooksNextActionTooltip(
                policy: accessPolicy,
                period: item,
              ),
              dense: true,
              onPressed: _mutating
                  ? null
                  : () => unawaited(_runNext(accessPolicy, item)),
            ),
          );
        },
      ),
    ];
  }

  List<AppListTableColumn<AccountsFiscalPeriod>> _optionalColumns() {
    return <AppListTableColumn<AccountsFiscalPeriod>>[
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsBooksFacilityColumnId,
        label: AccountsStrings.facilityColumn,
        preferredWidth: 160,
        cellBuilder: (_, AccountsFiscalPeriod item) => Text(
          (item.facilityLabel ?? '').trim().isEmpty
              ? AccountsStrings.unknownValue
              : item.facilityLabel!,
        ),
        exportValue: (AccountsFiscalPeriod item) => item.facilityLabel ?? '',
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsBooksByColumnId,
        label: AccountsStrings.byColumn,
        preferredWidth: 140,
        cellBuilder: (_, AccountsFiscalPeriod item) => Text(
          item.byLabel.isEmpty ? AccountsStrings.unknownValue : item.byLabel,
        ),
        exportValue: (AccountsFiscalPeriod item) => item.byLabel,
      ),
    ];
  }
}
