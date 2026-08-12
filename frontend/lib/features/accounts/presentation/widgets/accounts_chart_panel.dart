import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_chart_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_chart_account.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

const String accountsChartTableSettingsKey = 'accounts_chart_v1';
const String accountsChartColumnWidthKey = 'accounts_chart_cw_v1';

const String accountsChartAccountColumnId = 'account';
const String accountsChartTypeColumnId = 'type';
const String accountsChartCodeColumnId = 'code';
const String accountsChartStatusColumnId = 'status';
const String accountsChartActionsColumnId = 'actions';
const String accountsChartParentColumnId = 'parent';
const String accountsChartCurrencyColumnId = 'currency';
const String accountsChartEffectiveColumnId = 'effective';

/// Defaults when chart write is allowed (Actions present). Without write → 4.
const List<String> accountsChartDefaultColumnIds = <String>[
  accountsChartAccountColumnId,
  accountsChartTypeColumnId,
  accountsChartCodeColumnId,
  accountsChartStatusColumnId,
  accountsChartActionsColumnId,
];

/// Account chart CRUD table embedded in the Accounts workspace (`?section=chart`).
class AccountsChartPanel extends ConsumerStatefulWidget {
  const AccountsChartPanel({super.key});

  @override
  ConsumerState<AccountsChartPanel> createState() => _AccountsChartPanelState();
}

class _AccountsChartPanelState extends ConsumerState<AccountsChartPanel> {
  static const String _statusFilterKey = 'is_active';
  static const String _typeFilterKey = 'account_type';
  static const String _parentFilterKey = 'parent';
  static const String _currencyFilterKey = 'currency';
  static const String _effectiveFilterKey = 'effective';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<AccountsChartAccount>
  _columnController =
      AppListTableColumnVisibilityController<AccountsChartAccount>(
        storageKey: accountsChartTableSettingsKey,
      );

  AppPage<AccountsChartAccount> _page = const AppPage<AccountsChartAccount>(
    items: <AccountsChartAccount>[],
    request: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    totalItemCount: 0,
  );
  List<AccountsChartAccount> _allForParents = const <AccountsChartAccount>[];
  bool _loading = true;
  AppFailure? _failure;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue();
  Timer? _searchDebounce;

  String? get _tenantId =>
      ref.read(sessionStateProvider).session?.user?.tenantId ??
      ref.read(appAccessPolicyProvider).tenantId;
  String? get _facilityId =>
      ref.read(sessionStateProvider).session?.user?.facilityId ??
      ref.read(appAccessPolicyProvider).facilityId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reload());
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
    return (_filterValue.option(_statusFilterKey) ?? '').isNotEmpty ||
        (_filterValue.option(_typeFilterKey) ?? '').isNotEmpty ||
        (_filterValue.text(_parentFilterKey) ?? '').trim().isNotEmpty ||
        (_filterValue.text(_currencyFilterKey) ?? '').trim().isNotEmpty ||
        (_filterValue.option(_effectiveFilterKey) ?? '').isNotEmpty ||
        _searchController.text.trim().isNotEmpty;
  }

  bool get _hasLocalFilters {
    return (_filterValue.text(_parentFilterKey) ?? '').trim().isNotEmpty ||
        (_filterValue.option(_effectiveFilterKey) ?? '').isNotEmpty;
  }

  Future<void> _reload() async {
    final String? tenantId = _tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() {
        _loading = false;
        _failure = AppFailure.validation();
      });
      return;
    }

    setState(() {
      _loading = true;
      _failure = null;
    });

    final String? activeFilter = _filterValue.option(_statusFilterKey);
    final bool? isActive = activeFilter == null || activeFilter.isEmpty
        ? null
        : activeFilter == 'true';

    final Result<AppPage<AccountsChartAccount>> result = await ref
        .read(accountsChartRepositoryProvider)
        .listAccounts(
          AccountsChartQuery(
            search: _searchController.text.trim(),
            accountType: _filterValue.option(_typeFilterKey) ?? '',
            currency: (_filterValue.text(_currencyFilterKey) ?? '').trim(),
            isActive: isActive,
          ),
          tenantId: tenantId,
          facilityId: _facilityId,
        );

    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<AccountsChartAccount> page) {
        final List<AccountsChartAccount> filtered = _applyLocalFilters(
          page.items,
        );
        // Parent / Effective are client-side; otherwise prefer API total.
        final int totalItemCount = _hasLocalFilters
            ? filtered.length
            : (page.totalItemCount ?? filtered.length);
        setState(() {
          _allForParents = page.items;
          _page = AppPage<AccountsChartAccount>(
            items: filtered,
            request: page.request,
            totalItemCount: totalItemCount,
          );
          _loading = false;
        });
        if (!_hasActiveFilters) {
          // Fall back to workspace summary — do not badge from painted page.
          ref
                  .read<StateController<int?>>(
                    accountsChartActiveCountProvider.notifier,
                  )
                  .state =
              null;
        } else {
          ref
                  .read<StateController<int?>>(
                    accountsChartActiveCountProvider.notifier,
                  )
                  .state =
              totalItemCount;
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

  List<AccountsChartAccount> _applyLocalFilters(
    List<AccountsChartAccount> items,
  ) {
    Iterable<AccountsChartAccount> filtered = items;
    final String parentNeedle =
        (_filterValue.text(_parentFilterKey) ?? '').trim().toLowerCase();
    if (parentNeedle.isNotEmpty) {
      filtered = filtered.where((AccountsChartAccount item) {
        final String parentCode =
            accountsPublicLabel(item.parentCode) ?? '';
        return item.parentLabel.toLowerCase().contains(parentNeedle) ||
            parentCode.toLowerCase().contains(parentNeedle);
      });
    }
    final String? effective = _filterValue.option(_effectiveFilterKey);
    if (effective != null && effective.isNotEmpty) {
      final DateTime now = DateTime.now().toUtc();
      filtered = filtered.where((AccountsChartAccount item) {
        final DateTime? from = item.effectiveFrom?.toUtc();
        final bool isCurrent = from == null || !from.isAfter(now);
        return effective == 'current' ? isCurrent : !isCurrent;
      });
    }
    return filtered.toList(growable: false);
  }

  Future<void> _openCreateOrEdit({AccountsChartAccount? editing}) async {
    AccountsChartAccount? current = editing;
    while (mounted) {
      final AccountsChartDialogResult result =
          await showAccountsChartAccountDialog(
            context: context,
            ref: ref,
            editing: current,
            parentChoices: _allForParents,
          );
      if (!mounted) {
        return;
      }
      switch (result.outcome) {
        case AccountsChartDialogOutcome.cancelled:
          return;
        case AccountsChartDialogOutcome.saved:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AccountsStrings.saved)),
          );
          await _reload();
          return;
        case AccountsChartDialogOutcome.openExisting:
          current = result.existing;
          if (current == null) {
            return;
          }
      }
    }
  }

  Future<void> _deactivate(AccountsChartAccount entry) async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: AccountsStrings.chartDeactivateTitle,
        body: AccountsStrings.chartDeactivateBody(entry.accountLabel),
        highlightedText: entry.accountLabel,
        submitLabel: AccountsStrings.chartDeactivateAction,
        destructive: true,
        icon: const Icon(Icons.pause_circle_outline),
        onConfirm: () async {
          final Result<void> result = await ref
              .read(accountsChartRepositoryProvider)
              .deactivateAccount(entry.id);
          return result.when(
            success: (_) {
              ref
                  .read<StateController<int>>(
                    accountsChartRevisionProvider.notifier,
                  )
                  .state++;
              return null;
            },
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AccountsStrings.saved)),
      );
      await _reload();
    }
  }

  Widget _actionsCell(BuildContext context, AccountsChartAccount item) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: theme.spacing.md,
        runSpacing: theme.spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          AppButton.tertiary(
            leadingIcon: Icons.edit_outlined,
            label: context.l10n.commonEditActionLabel,
            tooltip: context.l10n.commonEditActionLabel,
            dense: true,
            onPressed: () => unawaited(_openCreateOrEdit(editing: item)),
          ),
          if (item.isActive)
            AppButton.tertiary(
              leadingIcon: Icons.pause_circle_outline,
              label: AccountsStrings.chartDeactivateAction,
              tooltip: AccountsStrings.chartDeactivateAction,
              dense: true,
              color: colors.error,
              onPressed: () => unawaited(_deactivate(item)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteAccountsChart(accessPolicy);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
    final List<AppListTableColumn<AccountsChartAccount>> columns =
        <AppListTableColumn<AccountsChartAccount>>[
          AppListTableColumn<AccountsChartAccount>(
            id: accountsChartAccountColumnId,
            label: AccountsStrings.accountColumn,
            alwaysVisible: true,
            preferredWidth: 220,
            cellBuilder: (_, AccountsChartAccount item) => Text(
              item.accountLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            sortComparator: (AccountsChartAccount a, AccountsChartAccount b) =>
                a.accountLabel.compareTo(b.accountLabel),
            exportValue: (AccountsChartAccount item) => item.accountLabel,
          ),
          AppListTableColumn<AccountsChartAccount>(
            id: accountsChartTypeColumnId,
            label: AccountsStrings.typeColumn,
            preferredWidth: 120,
            cellBuilder: (_, AccountsChartAccount item) =>
                Text(accountsChartTypeLabel(item.accountType)),
            sortComparator: (AccountsChartAccount a, AccountsChartAccount b) =>
                a.accountType.compareTo(b.accountType),
            exportValue: (AccountsChartAccount item) =>
                accountsChartTypeLabel(item.accountType),
          ),
          AppListTableColumn<AccountsChartAccount>(
            id: accountsChartCodeColumnId,
            label: AccountsStrings.chartCodeColumn,
            preferredWidth: 120,
            cellBuilder: (_, AccountsChartAccount item) => Text(
              accountsPublicLabel(item.code) ?? AccountsStrings.unknownValue,
            ),
            sortComparator: (AccountsChartAccount a, AccountsChartAccount b) =>
                a.code.compareTo(b.code),
            exportValue: (AccountsChartAccount item) =>
                accountsPublicLabel(item.code) ?? '',
          ),
          AppListTableColumn<AccountsChartAccount>(
            id: accountsChartStatusColumnId,
            label: AccountsStrings.statusColumn,
            preferredWidth: 110,
            cellBuilder: (_, AccountsChartAccount item) => AppStatusBadge(
              label: item.isActive
                  ? AccountsStrings.chartStatusActive
                  : AccountsStrings.chartStatusInactive,
              tone: item.isActive
                  ? AppWorkspaceStatusTone.success
                  : AppWorkspaceStatusTone.neutral,
              icon: item.isActive
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
            ),
            sortComparator: (AccountsChartAccount a, AccountsChartAccount b) =>
                (a.isActive == b.isActive) ? 0 : (a.isActive ? -1 : 1),
            exportValue: (AccountsChartAccount item) => item.isActive
                ? AccountsStrings.chartStatusActive
                : AccountsStrings.chartStatusInactive,
          ),
          if (canWrite)
            AppListTableColumn<AccountsChartAccount>(
              id: accountsChartActionsColumnId,
              label: AccountsStrings.chartActionsColumn,
              alwaysVisible: true,
              exportable: false,
              preferredWidth: 200,
              cellBuilder: (BuildContext context, AccountsChartAccount item) =>
                  _actionsCell(context, item),
            ),
        ];

    return AppListTable<AccountsChartAccount>(
      page: _page,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: accountsChartTableSettingsKey,
      columnWidthStorageKey: accountsChartColumnWidthKey,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
      enableExport: true,
      canExport: canExport,
      exportLabel: l10n.commonTableExportActionLabel,
      exportDialogTitle: l10n.commonTableExportDialogTitle,
      exportCancelLabel: l10n.commonCancelActionLabel,
      exportColumnsSectionLabel: l10n.commonTableExportColumnsSectionLabel,
      exportFiltersSectionLabel: l10n.commonTableExportFiltersSectionLabel,
      exportEmptyColumnsMessage: l10n.commonTableExportEmptyColumnsMessage,
      exportEmptyRowsMessage: l10n.commonTableExportEmptyRowsMessage,
      exportSuccessMessage: l10n.commonTableExportSuccessMessage,
      exportFailureMessage: l10n.commonTableExportFailureMessage,
      exportInvalidDateMessage: l10n.opdInvalidDateMessage,
      enablePrint: true,
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      onPrint: (items) => printAccountsListTable<AccountsChartAccount>(
        ref: ref,
        context: context,
        title: AccountsStrings.accountChartLabel,
        columns: columns,
        items: items,
        emptyText: AccountsStrings.chartEmpty,
      ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      exportConfig: AppListTableExportConfig<AccountsChartAccount>(
        fileNameStem: 'accounts_chart',
        dateOf: (AccountsChartAccount item) => item.effectiveFrom,
        sheetName: AccountsStrings.accountChartLabel,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      onRowSelected: canWrite
          ? (AccountsChartAccount item) =>
                unawaited(_openCreateOrEdit(editing: item))
          : null,
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: AccountsStrings.chartEmpty,
        body: AccountsStrings.chartEmptyBody,
      ),
      search: AppListTableSearch<AccountsChartAccount>(
        controller: _searchController,
        semanticLabel: AccountsStrings.chartSearchHint,
        hintText: AccountsStrings.chartSearchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsChartAccount item, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          final String code = accountsPublicLabel(item.code) ?? '';
          return item.accountLabel.toLowerCase().contains(needle) ||
              code.toLowerCase().contains(needle) ||
              item.accountType.toLowerCase().contains(needle) ||
              item.parentLabel.toLowerCase().contains(needle);
        },
        onSubmitted: (_) => unawaited(_reload()),
        onClear: () {
          _searchController.clear();
          setState(() => _filterValue = const AppSearchBarFilterValue());
          unawaited(_reload());
        },
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        advancedFilterCloseLabel: l10n.commonCloseActionLabel,
        allFieldsLabel: AccountsStrings.allFields,
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _parentFilterKey,
            label: AccountsStrings.chartParentLabel,
            hintText: AccountsStrings.chartParentLabel,
            icon: Icons.account_tree_outlined,
          ),
          AppSearchBarTextFilter(
            key: _currencyFilterKey,
            label: AccountsStrings.chartCurrencyLabel,
            hintText: AccountsStrings.chartCurrencyLabel,
            icon: Icons.payments_outlined,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: AccountsStrings.statusColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'true',
                label: AccountsStrings.chartStatusActive,
                icon: Icons.check_circle_outline,
              ),
              AppSearchBarFilterChoice(
                value: 'false',
                label: AccountsStrings.chartStatusInactive,
                icon: Icons.pause_circle_outline,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _typeFilterKey,
            label: AccountsStrings.chartTypeLabel,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'ASSET',
                label: AccountsStrings.chartTypeAsset,
              ),
              AppSearchBarFilterChoice(
                value: 'LIABILITY',
                label: AccountsStrings.chartTypeLiability,
              ),
              AppSearchBarFilterChoice(
                value: 'EQUITY',
                label: AccountsStrings.chartTypeEquity,
              ),
              AppSearchBarFilterChoice(
                value: 'REVENUE',
                label: AccountsStrings.chartTypeRevenue,
              ),
              AppSearchBarFilterChoice(
                value: 'EXPENSE',
                label: AccountsStrings.chartTypeExpense,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _effectiveFilterKey,
            label: AccountsStrings.chartEffectiveLabel,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'current',
                label: AccountsStrings.chartEffectiveCurrent,
              ),
              AppSearchBarFilterChoice(
                value: 'other',
                label: AccountsStrings.chartEffectiveOther,
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
        trailingActions: canWrite
            ? <AppSearchBarAction>[
                AppSearchBarAction(
                  label: l10n.commonAddActionLabel,
                  icon: Icons.add_outlined,
                  onPressed: () => unawaited(_openCreateOrEdit()),
                ),
              ]
            : const <AppSearchBarAction>[],
      ),
      columns: columns,
      columnChoices: <AppListTableColumn<AccountsChartAccount>>[
        AppListTableColumn<AccountsChartAccount>(
          id: accountsChartParentColumnId,
          label: AccountsStrings.chartParentColumn,
          preferredWidth: 160,
          cellBuilder: (_, AccountsChartAccount item) {
            final String parent = item.parentLabel;
            return Text(parent.isEmpty ? '—' : parent);
          },
          exportValue: (AccountsChartAccount item) => item.parentLabel,
        ),
        AppListTableColumn<AccountsChartAccount>(
          id: accountsChartCurrencyColumnId,
          label: AccountsStrings.chartCurrencyColumn,
          preferredWidth: 100,
          cellBuilder: (_, AccountsChartAccount item) => Text(
            accountsPublicLabel(item.currency) ?? AccountsStrings.unknownValue,
          ),
          exportValue: (AccountsChartAccount item) =>
              accountsPublicLabel(item.currency) ?? '',
        ),
        AppListTableColumn<AccountsChartAccount>(
          id: accountsChartEffectiveColumnId,
          label: AccountsStrings.chartEffectiveColumn,
          preferredWidth: 140,
          cellBuilder: (BuildContext context, AccountsChartAccount item) {
            if (item.effectiveFrom == null) {
              return const Text('—');
            }
            return Text(
              AppFormatters.dateTime(
                item.effectiveFrom!,
                Localizations.localeOf(context),
              ),
            );
          },
          exportValue: (AccountsChartAccount item) =>
              item.effectiveFrom?.toIso8601String() ?? '',
        ),
      ],
      mobileItemBuilder: (BuildContext context, AccountsChartAccount item) {
        return AppListTableMobileItem(
          title: item.accountLabel,
          caption: accountsPublicLabel(item.code) ?? AccountsStrings.unknownValue,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: accountsChartTypeLabel(item.accountType),
              icon: Icons.category_outlined,
            ),
            AppListTableMobileMeta(
              label: item.isActive
                  ? AccountsStrings.chartStatusActive
                  : AccountsStrings.chartStatusInactive,
              icon: item.isActive
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
            ),
          ],
        );
      },
    );
  }
}
