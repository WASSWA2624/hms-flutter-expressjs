import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// General ledger table embedded in the Accounts workspace (`?section=gl`).
class AccountsGlPanel extends ConsumerStatefulWidget {
  const AccountsGlPanel({
    super.key,
    this.initialAccountId = '',
    this.initialSearch = '',
  });

  final String initialAccountId;
  final String initialSearch;

  @override
  ConsumerState<AccountsGlPanel> createState() => _AccountsGlPanelState();
}

class _AccountsGlPanelState extends ConsumerState<AccountsGlPanel> {
  static const String _typeFilterKey = 'account_type';
  static const String _periodFilterKey = 'period';
  static const String _activityFilterKey = 'has_activity';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<AccountsGlAccount>
  _columnController = AppListTableColumnVisibilityController<AccountsGlAccount>(
    storageKey: accountsGlTableSettingsKey,
  );

  AppPage<AccountsGlAccount> _page = const AppPage<AccountsGlAccount>(
    items: <AccountsGlAccount>[],
    request: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    totalItemCount: 0,
  );
  bool _loading = true;
  AppFailure? _failure;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue();
  Timer? _searchDebounce;
  bool _handledAccountDeepLink = false;

  String? get _facilityId =>
      ref.read(sessionStateProvider).session?.user?.facilityId;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch.trim().isNotEmpty) {
      _searchController.text = widget.initialSearch.trim();
    } else if (widget.initialAccountId.trim().isNotEmpty) {
      _searchController.text = widget.initialAccountId.trim();
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
    return (_filterValue.option(_typeFilterKey) ?? '').isNotEmpty ||
        (_filterValue.text(_periodFilterKey) ?? '').trim().isNotEmpty ||
        (_filterValue.option(_activityFilterKey) ?? '').isNotEmpty ||
        _searchController.text.trim().isNotEmpty;
  }

  Future<void> _reload({bool openDeepLink = false}) async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final String activity = _filterValue.option(_activityFilterKey) ?? '';
    final bool? hasActivity = activity.isEmpty ? null : activity == 'true';

    final Result<AppPage<AccountsGlAccount>> result = await ref
        .read(accountsRepositoryProvider)
        .listGlAccounts(
          AccountsGlQuery(
            search: _searchController.text.trim(),
            accountType: _filterValue.option(_typeFilterKey) ?? '',
            period: (_filterValue.text(_periodFilterKey) ?? '').trim(),
            hasActivity: hasActivity,
            accountId: widget.initialAccountId.trim(),
          ),
          facilityId: _facilityId,
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<AccountsGlAccount> page) {
        setState(() {
          _page = page;
          _loading = false;
        });
        if (!_hasActiveFilters) {
          final int withActivity = page.items
              .where((AccountsGlAccount a) => a.hasActivity)
              .length;
          ref.read(accountsGlActivityCountProvider.notifier).state =
              withActivity;
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

  Future<void> _maybeOpenDeepLink(List<AccountsGlAccount> items) async {
    if (_handledAccountDeepLink) {
      return;
    }
    final String accountId = widget.initialAccountId.trim();
    if (accountId.isEmpty) {
      return;
    }
    AccountsGlAccount? match;
    for (final AccountsGlAccount item in items) {
      if (item.id == accountId ||
          item.effectiveId == accountId ||
          item.code == accountId) {
        match = item;
        break;
      }
    }
    if (match == null || !mounted) {
      return;
    }
    _handledAccountDeepLink = true;
    // Defer so the table frame settles before the dialog route pushes.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    await _openLedger(match);
  }

  Future<void> _openLedger(AccountsGlAccount account) async {
    await showAccountsGlDialog(context, ref, account: account);
  }

  @override
  Widget build(BuildContext context) {
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final l10n = context.l10n;

    return AppListTable<AccountsGlAccount>(
      page: _page,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: accountsGlTableSettingsKey,
      columnWidthStorageKey: '${accountsGlTableSettingsKey}_cw',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      onRowSelected: (AccountsGlAccount item) => unawaited(_openLedger(item)),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: AccountsStrings.glEmpty,
        body: AccountsStrings.glEmpty,
      ),
      search: AppListTableSearch<AccountsGlAccount>(
        controller: _searchController,
        semanticLabel: AccountsStrings.searchHint,
        hintText: AccountsStrings.searchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsGlAccount item, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          return <String>[
            item.accountLabel,
            item.code,
            item.name,
            item.type,
            item.period,
            item.effectiveId,
          ].any((String value) => value.toLowerCase().contains(needle));
        },
        onSubmitted: (_) => unawaited(_reload()),
        onClear: () {
          _searchController.clear();
          setState(() => _filterValue = const AppSearchBarFilterValue());
          unawaited(_reload());
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: AccountsStrings.filtersLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: AccountsStrings.clearFilters,
        allFieldsLabel: AccountsStrings.allFields,
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _periodFilterKey,
            label: AccountsStrings.periodColumn,
            hintText: AccountsStrings.periodColumn,
            icon: Icons.calendar_month_outlined,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _typeFilterKey,
            label: AccountsStrings.typeColumn,
            allLabel: AccountsStrings.allFields,
            choices: const <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(value: 'ASSET', label: 'Asset'),
              AppSearchBarFilterChoice(value: 'LIABILITY', label: 'Liability'),
              AppSearchBarFilterChoice(value: 'EQUITY', label: 'Equity'),
              AppSearchBarFilterChoice(value: 'REVENUE', label: 'Revenue'),
              AppSearchBarFilterChoice(value: 'EXPENSE', label: 'Expense'),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _activityFilterKey,
            label: AccountsStrings.activityFilter,
            allLabel: AccountsStrings.allFields,
            choices: const <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'true',
                label: AccountsStrings.activityWith,
              ),
              AppSearchBarFilterChoice(
                value: 'false',
                label: AccountsStrings.activityWithout,
              ),
            ],
          ),
        ],
        filterValue: _filterValue,
        hasActiveFilters: _hasActiveFilters,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() => _filterValue = value);
          unawaited(_reload());
        },
        trailingActions: const <AppSearchBarAction>[],
      ),
      columns: accountsGlDefaultColumns(
        context: context,
        showNext: (AccountsGlAccount account) =>
            canOpenAccountsGlNext(accessPolicy, account),
        onOpenGl: (AccountsGlAccount account) =>
            unawaited(_openLedger(account)),
      ),
      columnChoices: accountsGlOptionalColumns(context),
      mobileItemBuilder: (BuildContext context, AccountsGlAccount item) {
        return ListTile(
          title: Text(item.accountLabel),
          subtitle: Text(accountsMoney(context, item.balance, item.currency)),
          onTap: () => unawaited(_openLedger(item)),
        );
      },
    );
  }
}
