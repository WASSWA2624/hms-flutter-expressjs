import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_ledgers_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_patient_ledger_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Patient ledgers table for `/accounts?section=ledgers`.
class AccountsLedgersPanel extends ConsumerStatefulWidget {
  const AccountsLedgersPanel({
    super.key,
    this.initialPatientId = '',
    this.initialSearch = '',
  });

  final String initialPatientId;
  final String initialSearch;

  @override
  ConsumerState<AccountsLedgersPanel> createState() =>
      _AccountsLedgersPanelState();
}

class _AccountsLedgersPanelState extends ConsumerState<AccountsLedgersPanel> {
  static const String _clearanceFilterKey = 'clearance';
  static const String _patientFilterKey = 'patient_id';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<AccountsPatientBalance>
  _columnController =
      AppListTableColumnVisibilityController<AccountsPatientBalance>(
        storageKey: accountsLedgersTableSettingsKey,
      );

  AppPage<AccountsPatientBalance> _page = const AppPage<AccountsPatientBalance>(
    items: <AccountsPatientBalance>[],
    request: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    totalItemCount: 0,
  );
  bool _loading = true;
  AppFailure? _failure;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue();
  Timer? _searchDebounce;
  bool _handledPatientDeepLink = false;

  String? get _facilityId =>
      ref.read(sessionStateProvider).session?.user?.facilityId;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch.trim().isNotEmpty) {
      _searchController.text = widget.initialSearch.trim();
    }
    if (widget.initialPatientId.trim().isNotEmpty) {
      _filterValue = AppSearchBarFilterValue(
        texts: <String, String>{
          _patientFilterKey: widget.initialPatientId.trim(),
        },
      );
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
    return (_filterValue.option(_clearanceFilterKey) ?? '').isNotEmpty ||
        (_filterValue.text(_patientFilterKey) ?? '').trim().isNotEmpty ||
        _searchController.text.trim().isNotEmpty;
  }

  Future<void> _reload({bool openDeepLink = false}) async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final Result<AppPage<AccountsPatientBalance>> result = await ref
        .read(accountsRepositoryProvider)
        .listPatientLedgers(
          AccountsPatientLedgerQuery(
            search: _searchController.text.trim(),
            patientId: (_filterValue.text(_patientFilterKey) ?? '').trim(),
            clearance: AccountsClearanceState.fromServer(
              _filterValue.option(_clearanceFilterKey),
            ),
          ),
          facilityId: _facilityId,
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<AccountsPatientBalance> page) {
        setState(() {
          _page = page;
          _loading = false;
        });
        if (_hasActiveFilters) {
          ref
                  .read(accountsPatientLedgersBalanceCountProvider.notifier)
                  .state =
              page.totalItemCount ?? page.items.length;
        } else {
          // Fall back to workspace summary — do not badge from painted page.
          ref
                  .read(accountsPatientLedgersBalanceCountProvider.notifier)
                  .state =
              null;
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

  Future<void> _maybeOpenDeepLink(List<AccountsPatientBalance> items) async {
    final String patientId = widget.initialPatientId.trim();
    if (patientId.isEmpty || _handledPatientDeepLink) {
      return;
    }
    AccountsPatientBalance? match;
    for (final AccountsPatientBalance row in items) {
      if (row.patientId == patientId ||
          (row.patientDisplayId ?? '') == patientId ||
          (row.patientDisplayName ?? '') == patientId ||
          row.displayLabel == patientId) {
        match = row;
        break;
      }
    }
    if (match == null && items.isEmpty) {
      // Still loading / empty — allow a later reload to retry.
      return;
    }
    _handledPatientDeepLink = true;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    await _openLedger(
      patientId: match?.patientId ?? patientId,
      displayName: match?.patientDisplayName,
      currency: match?.currency,
    );
  }

  Future<void> _openLedger({
    required String patientId,
    String? displayName,
    String? currency,
  }) {
    return showAccountsPatientLedgerDialog(
      context,
      ref,
      patientId: patientId,
      patientDisplayName: displayName,
      currency: currency,
    );
  }

  void _pay(AccountsPatientBalance row) {
    context.go(
      AppRoutes.billing.location(
        queryParameters: <String, String>{
          'section': 'collect',
          'action': 'pay',
          'patientId': row.patientId,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
    final List<AppListTableColumn<AccountsPatientBalance>> columns =
        accountsLedgersColumns(
          context: context,
          policy: accessPolicy,
          onOpenLedger: (AccountsPatientBalance row) {
            unawaited(
              _openLedger(
                patientId: row.patientId,
                displayName: row.patientDisplayName,
                currency: row.currency,
              ),
            );
          },
          onPay: _pay,
        );

    return AppListTable<AccountsPatientBalance>(
      page: _page,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: accountsLedgersTableSettingsKey,
      columnWidthStorageKey: '${accountsLedgersTableSettingsKey}_cw',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      enableExport: true,
      canExport: canExport,
      enablePrint: true,
      canPrint: canPrint,
      printLabel: AccountsStrings.printAction,
      onPrint: () => printAccountsListTable<AccountsPatientBalance>(
        ref: ref,
        context: context,
        title: AccountsStrings.patientLedgersLabel,
        columns: columns,
        items: _page.items,
        emptyText: AccountsStrings.patientLedgersEmpty,
      ),
      columns: columns,
      columnChoices: accountsLedgersColumnChoices(
        context: context,
        policy: accessPolicy,
        onOpenLedger: (AccountsPatientBalance row) {
          unawaited(
            _openLedger(
              patientId: row.patientId,
              displayName: row.patientDisplayName,
              currency: row.currency,
            ),
          );
        },
        onPay: _pay,
      ),
      search: AppListTableSearch<AccountsPatientBalance>(
        controller: _searchController,
        semanticLabel: AccountsStrings.patientLedgersSearchSemantic,
        hintText: AccountsStrings.patientLedgersSearchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsPatientBalance item, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          return item.displayLabel.toLowerCase().contains(needle) ||
              (item.patientDisplayId ?? '')
                  .toLowerCase()
                  .contains(needle) ||
              (item.patientDisplayName ?? '')
                  .toLowerCase()
                  .contains(needle);
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
        filterGroups: const <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _clearanceFilterKey,
            label: AccountsStrings.clearanceColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'CLEARED',
                label: AccountsStrings.clearanceCleared,
              ),
              AppSearchBarFilterChoice(
                value: 'PARTIAL',
                label: AccountsStrings.clearancePartial,
              ),
              AppSearchBarFilterChoice(
                value: 'OUTSTANDING',
                label: AccountsStrings.clearanceOutstanding,
              ),
            ],
          ),
        ],
        textFilters: const <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _patientFilterKey,
            label: AccountsStrings.patientColumn,
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
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: AccountsStrings.patientLedgersEmpty,
        body: '',
      ),
      onRowSelected: (AccountsPatientBalance row) {
        unawaited(
          _openLedger(
            patientId: row.patientId,
            displayName: row.patientDisplayName,
            currency: row.currency,
          ),
        );
      },
      mobileItemBuilder: (BuildContext context, AccountsPatientBalance row) {
        final String? next = accountsPatientLedgerNextActionLabel(
          policy: accessPolicy,
          row: row,
        );
        return AppListTableMobileItem(
          title: row.displayLabel,
          caption: accountsClearanceLabel(row.clearance),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: accountsMoney(context, row.balance, row.currency),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
          trailing: next == null
              ? null
              : TextButton(
                  onPressed: () {
                    if (next == AccountsStrings.payAction) {
                      _pay(row);
                    } else {
                      unawaited(
                        _openLedger(
                          patientId: row.patientId,
                          displayName: row.patientDisplayName,
                          currency: row.currency,
                        ),
                      );
                    }
                  },
                  child: Text(next),
                ),
        );
      },
    );
  }
}
