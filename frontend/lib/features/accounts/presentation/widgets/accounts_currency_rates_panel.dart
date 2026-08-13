import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/idempotency.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_currency_rate_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_currency_rate.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_currency_rate_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

const String accountsCurrencyRatesTableSettingsKey =
    'accounts_currency_rates_v1';
const String accountsCurrencyRatesColumnWidthKey =
    'accounts_currency_rates_cw_v1';

const String accountsCurrencyCodeColumnId = 'currency_code';
const String accountsCurrencyNameColumnId = 'currency_name';
const String accountsCurrencySymbolColumnId = 'symbol';
const String accountsCurrencyDecimalPlacesColumnId = 'decimal_places';
const String accountsCurrencyBaseColumnId = 'base_currency';
const String accountsCurrencyRateTypeColumnId = 'rate_type';
const String accountsCurrencyExchangeRateColumnId = 'exchange_rate';
const String accountsCurrencyEffectiveDateColumnId = 'effective_date';
const String accountsCurrencySourceColumnId = 'source';
const String accountsCurrencyBuyRateColumnId = 'buy_rate';
const String accountsCurrencySellRateColumnId = 'sell_rate';
const String accountsCurrencyLastUpdatedAtColumnId = 'last_updated_at';
const String accountsCurrencyUpdatedByColumnId = 'updated_by';
const String accountsCurrencyStatusColumnId = 'currency_status';
const String accountsCurrencyActionsColumnId = 'actions';

/// The 14 documented columns plus Actions, in source-of-truth order.
const List<String> accountsCurrencyRateColumnIds = <String>[
  accountsCurrencyCodeColumnId,
  accountsCurrencyNameColumnId,
  accountsCurrencySymbolColumnId,
  accountsCurrencyDecimalPlacesColumnId,
  accountsCurrencyBaseColumnId,
  accountsCurrencyRateTypeColumnId,
  accountsCurrencyExchangeRateColumnId,
  accountsCurrencyEffectiveDateColumnId,
  accountsCurrencySourceColumnId,
  accountsCurrencyBuyRateColumnId,
  accountsCurrencySellRateColumnId,
  accountsCurrencyLastUpdatedAtColumnId,
  accountsCurrencyUpdatedByColumnId,
  accountsCurrencyStatusColumnId,
];

/// Columns painted before the accountant opens Settings.
///
/// [AppListTable] caps this seed list at five entries and then re-adds every
/// `alwaysVisible` column (Currency Code, Currency Name, Base Currency,
/// Currency Status, Actions), so the opening view stays readable on a laptop.
const List<String> accountsCurrencyRateDefaultColumnIds = <String>[
  accountsCurrencyCodeColumnId,
  accountsCurrencyNameColumnId,
  accountsCurrencyRateTypeColumnId,
  accountsCurrencyExchangeRateColumnId,
  accountsCurrencyEffectiveDateColumnId,
];

/// Columns hidden by default but available in Settings, export, and print.
const Set<String> accountsCurrencyRateOptionalColumnIds = <String>{
  accountsCurrencySymbolColumnId,
  accountsCurrencyDecimalPlacesColumnId,
  accountsCurrencySourceColumnId,
  accountsCurrencyBuyRateColumnId,
  accountsCurrencySellRateColumnId,
  accountsCurrencyLastUpdatedAtColumnId,
  accountsCurrencyUpdatedByColumnId,
};

/// `Accounts & Finance → Setup & Controls → Currencies & Exchange Rates`
/// (`?section=currencies-and-exchange-rates`).
class AccountsCurrencyRatesPanel extends ConsumerStatefulWidget {
  const AccountsCurrencyRatesPanel({super.key});

  @override
  ConsumerState<AccountsCurrencyRatesPanel> createState() =>
      _AccountsCurrencyRatesPanelState();
}

class _AccountsCurrencyRatesPanelState
    extends ConsumerState<AccountsCurrencyRatesPanel> {
  static const String _statusFilterKey = 'currency_status';
  static const String _rateTypeFilterKey = 'rate_type';
  static const String _baseFilterKey = 'base_currency';
  static const String _currencyFilterKey = 'currency_code';
  static const String _sourceFilterKey = 'source';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<AccountsCurrencyRate>
  _columnController =
      AppListTableColumnVisibilityController<AccountsCurrencyRate>(
        storageKey: accountsCurrencyRatesTableSettingsKey,
      );

  AppPage<AccountsCurrencyRate> _page = const AppPage<AccountsCurrencyRate>(
    items: <AccountsCurrencyRate>[],
    request: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    totalItemCount: 0,
  );
  bool _loading = true;
  bool _isMutating = false;
  AppFailure? _failure;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue();
  Timer? _searchDebounce;
  int _revision = 0;

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

  AccountsCurrencyRateQuery get _query {
    final AccountsCurrencyStatus? status = AccountsCurrencyStatus.fromWire(
      _filterValue.option(_statusFilterKey) ?? '',
    );
    final AccountsCurrencyRateType? rateType =
        AccountsCurrencyRateType.fromWire(
          _filterValue.option(_rateTypeFilterKey) ?? '',
        );
    final String base = _filterValue.option(_baseFilterKey) ?? '';
    return AccountsCurrencyRateQuery(
      search: _searchController.text.trim(),
      statuses: status == null
          ? const <AccountsCurrencyStatus>{}
          : <AccountsCurrencyStatus>{status},
      rateTypes: rateType == null
          ? const <AccountsCurrencyRateType>{}
          : <AccountsCurrencyRateType>{rateType},
      baseCurrencyOnly: base.isEmpty ? null : base == 'true',
      currencyCode: (_filterValue.text(_currencyFilterKey) ?? '').trim(),
      source: (_filterValue.text(_sourceFilterKey) ?? '').trim(),
      from: _filterValue.dateFrom,
      to: _filterValue.dateTo,
      pageRequest: const AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    );
  }

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _failure = null;
    });

    final AccountsCurrencyRateQuery query = _query;
    final Result<AppPage<AccountsCurrencyRate>> result = await ref
        .read(accountsCurrencyRateRepositoryProvider)
        .listRates(query);

    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<AccountsCurrencyRate> page) {
        setState(() {
          _page = page;
          _loading = false;
          _revision++;
        });
        // Badge from the server total when narrowed; otherwise defer to the
        // workspace summary so it never reflects only the painted page.
        ref
                .read<StateController<int?>>(
                  accountsCurrencyRateCountProvider.notifier,
                )
                .state =
            query.isNarrowed
            ? (page.totalItemCount ?? page.items.length)
            : null;
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loading = false;
        });
      },
    );
  }

  bool get _hasActiveFilters =>
      _query.hasActiveFilters || _searchController.text.trim().isNotEmpty;

  Future<void> _openCreate({AccountsCurrencyRate? cloneOf}) async {
    final bool saved = await showAccountsCurrencyRateDialog(
      context: context,
      ref: ref,
      mode: cloneOf == null
          ? AccountsCurrencyRateDialogMode.create
          : AccountsCurrencyRateDialogMode.clone,
      source: cloneOf,
    );
    if (saved && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  Future<void> _openEdit(AccountsCurrencyRate rate) async {
    if (!rate.canEdit) {
      return;
    }
    final bool saved = await showAccountsCurrencyRateDialog(
      context: context,
      ref: ref,
      mode: AccountsCurrencyRateDialogMode.edit,
      source: rate,
    );
    if (saved && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  Future<void> _openDetail(AccountsCurrencyRate rate) async {
    await showAccountsCurrencyRateDetail(
      context: context,
      ref: ref,
      rate: rate,
    );
  }

  Future<void> _applyAction(
    AccountsCurrencyRate rate,
    AccountsCurrencyRateAction action,
  ) async {
    final bool applied = await confirmAccountsCurrencyRateAction(
      context: context,
      ref: ref,
      rate: rate,
      action: action,
    );
    if (applied && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  /// Bulk workflow over every eligible row in the current filtered result.
  ///
  /// The table has no row-selection chrome, so "selected" means "matching the
  /// active filters" — the same set Export and Print operate on.
  Future<void> _applyBulkAction(AccountsCurrencyRateAction action) async {
    final List<AccountsCurrencyRate> eligible = _page.items
        .where((AccountsCurrencyRate rate) => _supportsAction(rate, action))
        .toList(growable: false);
    if (eligible.isEmpty) {
      return;
    }

    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: _bulkTitle(action),
        body: AccountsStrings.currencyBulkConfirmBody(
          eligible.length,
          accountsCurrencyRateActionLabel(action).toLowerCase(),
        ),
        submitLabel: accountsCurrencyRateActionLabel(action),
        destructive: action != AccountsCurrencyRateAction.activate,
        icon: const Icon(Icons.playlist_add_check_outlined),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isMutating = true);
    int failed = 0;
    for (final AccountsCurrencyRate rate in eligible) {
      final Result<AccountsCurrencyRate> result = await ref
          .read(accountsCurrencyRateRepositoryProvider)
          .applyAction(
            rate.humanFriendlyId,
            action,
            version: rate.version,
            idempotencyKey: createIdempotencyKey(),
          );
      result.when(
        success: (_) {},
        failure: (_) => failed++,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() => _isMutating = false);
    ref
            .read<StateController<int>>(
              accountsCurrencyRateRevisionProvider.notifier,
            )
            .state++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? AccountsStrings.saved
              : AccountsStrings.currencyBulkPartialFailure(failed),
        ),
      ),
    );
    await _reload();
  }

  static bool _supportsAction(
    AccountsCurrencyRate rate,
    AccountsCurrencyRateAction action,
  ) {
    return switch (action) {
      AccountsCurrencyRateAction.activate => rate.canActivate,
      AccountsCurrencyRateAction.deactivate => rate.canDeactivate,
      AccountsCurrencyRateAction.archive => rate.canArchive,
      AccountsCurrencyRateAction.restore => rate.canRestore,
    };
  }

  static String _bulkTitle(AccountsCurrencyRateAction action) {
    return switch (action) {
      AccountsCurrencyRateAction.activate =>
        AccountsStrings.currencyBulkActivateAction,
      AccountsCurrencyRateAction.deactivate =>
        AccountsStrings.currencyBulkDeactivateAction,
      AccountsCurrencyRateAction.archive =>
        AccountsStrings.currencyBulkArchiveAction,
      AccountsCurrencyRateAction.restore =>
        AccountsStrings.currencyRestoreAction,
    };
  }

  void _notifySaved() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AccountsStrings.saved)));
  }

  Widget _actionsCell(BuildContext context, AccountsCurrencyRate rate) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool canWrite = canWriteAccountsCurrencyRates(
      ref.watch(appAccessPolicyProvider),
    );
    final AccountsCurrencyRateAction? toggle = rate.toggleAction;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: theme.spacing.md,
        runSpacing: theme.spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          AppButton.tertiary(
            leadingIcon: Icons.visibility_outlined,
            label: AccountsStrings.currencyViewAction,
            tooltip: AccountsStrings.currencyViewAction,
            dense: true,
            onPressed: () => unawaited(_openDetail(rate)),
          ),
          if (canWrite && rate.canEdit)
            AppButton.tertiary(
              leadingIcon: Icons.edit_outlined,
              label: context.l10n.commonEditActionLabel,
              tooltip: context.l10n.commonEditActionLabel,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openEdit(rate)),
            ),
          if (canWrite && rate.canClone)
            AppButton.tertiary(
              leadingIcon: Icons.copy_all_outlined,
              label: AccountsStrings.currencyCloneAction,
              tooltip: AccountsStrings.currencyCloneAction,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openCreate(cloneOf: rate)),
            ),
          if (canWrite && toggle != null)
            AppButton.tertiary(
              leadingIcon: switch (toggle) {
                AccountsCurrencyRateAction.restore => Icons.restore_outlined,
                AccountsCurrencyRateAction.deactivate =>
                  Icons.pause_circle_outline,
                _ => Icons.check_circle_outline,
              },
              label: accountsCurrencyRateActionLabel(toggle),
              tooltip: accountsCurrencyRateActionLabel(toggle),
              dense: true,
              enabled: !_isMutating,
              color: toggle == AccountsCurrencyRateAction.deactivate
                  ? colors.error
                  : null,
              onPressed: () => unawaited(_applyAction(rate, toggle)),
            ),
          if (canWrite && rate.canArchive)
            AppButton.tertiary(
              leadingIcon: Icons.inventory_2_outlined,
              label: AccountsStrings.currencyArchiveAction,
              tooltip: AccountsStrings.currencyArchiveAction,
              dense: true,
              enabled: !_isMutating,
              color: colors.error,
              onPressed: () => unawaited(
                _applyAction(rate, AccountsCurrencyRateAction.archive),
              ),
            ),
        ],
      ),
    );
  }

  List<AppListTableColumn<AccountsCurrencyRate>> _columns({
    required bool canWrite,
  }) {
    AppListTableColumn<AccountsCurrencyRate> rateColumn({
      required String id,
      required String label,
      required double? Function(AccountsCurrencyRate rate) valueOf,
    }) {
      return AppListTableColumn<AccountsCurrencyRate>(
        id: id,
        label: label,
        numeric: true,
        preferredWidth: 130,
        cellBuilder: (BuildContext context, AccountsCurrencyRate rate) => Text(
          accountsRate(
            context,
            valueOf(rate),
            decimalPlaces: rate.decimalPlaces,
          ),
        ),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            _compareRates(valueOf(a), valueOf(b)),
        exportValue: (AccountsCurrencyRate rate) => valueOf(rate) ?? '',
      );
    }

    return <AppListTableColumn<AccountsCurrencyRate>>[
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencyCodeColumnId,
        label: AccountsStrings.currencyCodeColumn,
        alwaysVisible: true,
        preferredWidth: 150,
        cellBuilder: (_, AccountsCurrencyRate rate) =>
            AppCopyableIdentifierCell(
              title: rate.currencyCode,
              identifier: accountsPublicLabel(rate.humanFriendlyId),
            ),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            a.currencyCode.compareTo(b.currencyCode),
        exportValue: (AccountsCurrencyRate rate) => rate.currencyCode,
      ),
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencyNameColumnId,
        label: AccountsStrings.currencyNameColumn,
        alwaysVisible: true,
        preferredWidth: 180,
        cellBuilder: (_, AccountsCurrencyRate rate) => Text(
          rate.currencyName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            a.currencyName.compareTo(b.currencyName),
        exportValue: (AccountsCurrencyRate rate) => rate.currencyName,
      ),
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencySymbolColumnId,
        label: AccountsStrings.currencySymbolColumn,
        preferredWidth: 90,
        cellBuilder: (_, AccountsCurrencyRate rate) => Text(
          rate.symbol.isEmpty ? AccountsStrings.unknownValue : rate.symbol,
        ),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            a.symbol.compareTo(b.symbol),
        exportValue: (AccountsCurrencyRate rate) => rate.symbol,
      ),
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencyDecimalPlacesColumnId,
        label: AccountsStrings.currencyDecimalPlacesColumn,
        numeric: true,
        preferredWidth: 120,
        cellBuilder: (_, AccountsCurrencyRate rate) =>
            Text('${rate.decimalPlaces}'),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            a.decimalPlaces.compareTo(b.decimalPlaces),
        exportValue: (AccountsCurrencyRate rate) => rate.decimalPlaces,
      ),
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencyBaseColumnId,
        label: AccountsStrings.currencyBaseColumn,
        alwaysVisible: true,
        preferredWidth: 120,
        cellBuilder: (_, AccountsCurrencyRate rate) => AppStatusBadge(
          label: rate.baseCurrency
              ? AccountsStrings.currencyBaseYes
              : AccountsStrings.currencyBaseNo,
          tone: rate.baseCurrency
              ? AppWorkspaceStatusTone.info
              : AppWorkspaceStatusTone.neutral,
          icon: rate.baseCurrency ? Icons.star_outline : Icons.circle_outlined,
        ),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            (a.baseCurrency ? 1 : 0).compareTo(b.baseCurrency ? 1 : 0),
        exportValue: (AccountsCurrencyRate rate) => rate.baseCurrency
            ? AccountsStrings.currencyBaseYes
            : AccountsStrings.currencyBaseNo,
      ),
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencyRateTypeColumnId,
        label: AccountsStrings.currencyRateTypeColumn,
        preferredWidth: 120,
        cellBuilder: (_, AccountsCurrencyRate rate) =>
            Text(accountsCurrencyRateTypeLabel(rate.rateType)),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            a.rateType.index.compareTo(b.rateType.index),
        exportValue: (AccountsCurrencyRate rate) =>
            accountsCurrencyRateTypeLabel(rate.rateType),
      ),
      rateColumn(
        id: accountsCurrencyExchangeRateColumnId,
        label: AccountsStrings.currencyExchangeRateColumn,
        valueOf: (AccountsCurrencyRate rate) => rate.exchangeRate,
      ),
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencyEffectiveDateColumnId,
        label: AccountsStrings.currencyEffectiveDateColumn,
        preferredWidth: 140,
        cellBuilder: (BuildContext context, AccountsCurrencyRate rate) =>
            Text(accountsDate(context, rate.effectiveDate)),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            a.effectiveDate.compareTo(b.effectiveDate),
        exportValue: (AccountsCurrencyRate rate) =>
            rate.effectiveDate.toIso8601String(),
      ),
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencySourceColumnId,
        label: AccountsStrings.currencySourceColumn,
        preferredWidth: 160,
        cellBuilder: (_, AccountsCurrencyRate rate) => Text(
          rate.source ?? AccountsStrings.unknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            (a.source ?? '').compareTo(b.source ?? ''),
        exportValue: (AccountsCurrencyRate rate) => rate.source ?? '',
      ),
      rateColumn(
        id: accountsCurrencyBuyRateColumnId,
        label: AccountsStrings.currencyBuyRateColumn,
        valueOf: (AccountsCurrencyRate rate) => rate.buyRate,
      ),
      rateColumn(
        id: accountsCurrencySellRateColumnId,
        label: AccountsStrings.currencySellRateColumn,
        valueOf: (AccountsCurrencyRate rate) => rate.sellRate,
      ),
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencyLastUpdatedAtColumnId,
        label: AccountsStrings.currencyLastUpdatedAtColumn,
        preferredWidth: 170,
        cellBuilder: (BuildContext context, AccountsCurrencyRate rate) =>
            Text(accountsDateTime(context, rate.lastUpdatedAt)),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            _compareDates(a.lastUpdatedAt, b.lastUpdatedAt),
        exportValue: (AccountsCurrencyRate rate) =>
            rate.lastUpdatedAt?.toIso8601String() ?? '',
      ),
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencyUpdatedByColumnId,
        label: AccountsStrings.currencyUpdatedByColumn,
        preferredWidth: 150,
        cellBuilder: (_, AccountsCurrencyRate rate) => Text(
          rate.updatedBy ?? AccountsStrings.unknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            (a.updatedBy ?? '').compareTo(b.updatedBy ?? ''),
        exportValue: (AccountsCurrencyRate rate) => rate.updatedBy ?? '',
      ),
      AppListTableColumn<AccountsCurrencyRate>(
        id: accountsCurrencyStatusColumnId,
        label: AccountsStrings.currencyStatusColumn,
        alwaysVisible: true,
        preferredWidth: 130,
        cellBuilder: (_, AccountsCurrencyRate rate) => AppStatusBadge(
          label: accountsCurrencyStatusLabel(rate.status),
          tone: accountsCurrencyStatusTone(rate.status),
          icon: accountsCurrencyStatusIcon(rate.status),
        ),
        sortComparator: (AccountsCurrencyRate a, AccountsCurrencyRate b) =>
            a.status.index.compareTo(b.status.index),
        exportValue: (AccountsCurrencyRate rate) =>
            accountsCurrencyStatusLabel(rate.status),
      ),
      if (canWrite)
        AppListTableColumn<AccountsCurrencyRate>(
          id: accountsCurrencyActionsColumnId,
          label: AccountsStrings.currencyActionsColumn,
          alwaysVisible: true,
          exportable: false,
          preferredWidth: 260,
          cellBuilder: _actionsCell,
        ),
    ];
  }

  static int _compareRates(double? a, double? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return a.compareTo(b);
  }

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return a.compareTo(b);
  }

  /// Server-filtered totals, not just the painted page.
  Widget _footer(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int total = _page.totalItemCount ?? _page.items.length;
    final int active = _page.items
        .where(
          (AccountsCurrencyRate rate) =>
              rate.status == AccountsCurrencyStatus.active,
        )
        .length;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            AccountsStrings.currencyRowsTotal(total),
            style: theme.textTheme.labelLarge,
          ),
          Text(
            AccountsStrings.currencyActiveTotal(active),
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteAccountsCurrencyRates(accessPolicy);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
    final List<AppListTableColumn<AccountsCurrencyRate>> columnChoices =
        _columns(canWrite: canWrite);
    final List<AppListTableColumn<AccountsCurrencyRate>> columns =
        <AppListTableColumn<AccountsCurrencyRate>>[
          for (final String id in accountsCurrencyRateDefaultColumnIds)
            columnChoices.firstWhere(
              (AppListTableColumn<AccountsCurrencyRate> column) =>
                  column.key == id,
            ),
        ];

    // Mutations elsewhere (detail dialog, other panels) invalidate this list.
    ref.listen<int>(accountsCurrencyRateRevisionProvider, (_, _) {
      unawaited(_reload());
    });

    return AppListTable<AccountsCurrencyRate>(
      page: _page,
      rowsVersion: _revision,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      itemKeyBuilder: (AccountsCurrencyRate rate) =>
          ValueKey<String>(rate.humanFriendlyId),
      initialSortColumnKey: accountsCurrencyEffectiveDateColumnId,
      initialSortAscending: false,
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: accountsCurrencyRatesTableSettingsKey,
      columnWidthStorageKey: accountsCurrencyRatesColumnWidthKey,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
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
      exportConfig: AppListTableExportConfig<AccountsCurrencyRate>(
        fileNameStem: 'accounts_currency_rates',
        sheetName: AccountsStrings.currenciesLabel,
        dateOf: (AccountsCurrencyRate rate) => rate.effectiveDate,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      enablePrint: true,
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      onPrint: (List<AccountsCurrencyRate> items) =>
          printAccountsListTable<AccountsCurrencyRate>(
            ref: ref,
            context: context,
            title: AccountsStrings.currenciesLabel,
            columns: columnChoices,
            items: items,
            emptyText: AccountsStrings.currenciesEmpty,
          ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      onRowSelected: (AccountsCurrencyRate rate) =>
          unawaited(_openDetail(rate)),
      footer: _footer(context),
      emptyBuilder: (_) => const AppWorkspaceStatePanel.empty(
        title: AccountsStrings.currenciesEmpty,
        body: AccountsStrings.currenciesEmptyBody,
      ),
      search: AppListTableSearch<AccountsCurrencyRate>(
        controller: _searchController,
        semanticLabel: AccountsStrings.currenciesSearchHint,
        hintText: AccountsStrings.currenciesSearchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsCurrencyRate rate, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          final String reference =
              accountsPublicLabel(rate.humanFriendlyId) ?? '';
          return reference.toLowerCase().contains(needle) ||
              rate.currencyCode.toLowerCase().contains(needle) ||
              rate.currencyName.toLowerCase().contains(needle) ||
              (rate.source ?? '').toLowerCase().contains(needle);
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
        dateFilterLabel: AccountsStrings.currencyDateRangeFilterLabel,
        dateFromLabel: AccountsStrings.currencyEffectiveDateColumn,
        dateToLabel: AccountsStrings.currencyEffectiveDateColumn,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        textFilters: const <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _currencyFilterKey,
            label: AccountsStrings.currencyCodeColumn,
            hintText: AccountsStrings.currencyCodeColumn,
            icon: Icons.paid_outlined,
          ),
          AppSearchBarTextFilter(
            key: _sourceFilterKey,
            label: AccountsStrings.currencySourceColumn,
            hintText: AccountsStrings.currencySourceColumn,
            icon: Icons.source_outlined,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: AccountsStrings.currencyStatusColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsCurrencyStatus status
                  in AccountsCurrencyStatus.values)
                AppSearchBarFilterChoice(
                  value: status.wireValue,
                  label: accountsCurrencyStatusLabel(status),
                  icon: accountsCurrencyStatusIcon(status),
                ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _rateTypeFilterKey,
            label: AccountsStrings.currencyRateTypeColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsCurrencyRateType type
                  in AccountsCurrencyRateType.values)
                AppSearchBarFilterChoice(
                  value: type.wireValue,
                  label: accountsCurrencyRateTypeLabel(type),
                  icon: Icons.category_outlined,
                ),
            ],
          ),
          const AppSearchBarFilterGroup(
            key: _baseFilterKey,
            label: AccountsStrings.currencyBaseFilterLabel,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'true',
                label: AccountsStrings.currencyBaseFilterOnly,
                icon: Icons.star_outline,
              ),
              AppSearchBarFilterChoice(
                value: 'false',
                label: AccountsStrings.currencyBaseFilterExclude,
                icon: Icons.circle_outlined,
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
                  label: AccountsStrings.currencyNewRecordAction,
                  icon: Icons.add_outlined,
                  enabled: !_isMutating,
                  onPressed: () => unawaited(_openCreate()),
                ),
                AppSearchBarAction(
                  label: AccountsStrings.currencyBulkActivateAction,
                  icon: Icons.check_circle_outline,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsCurrencyRateAction.activate),
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsCurrencyRateAction.activate),
                  ),
                ),
                AppSearchBarAction(
                  label: AccountsStrings.currencyBulkDeactivateAction,
                  icon: Icons.pause_circle_outline,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsCurrencyRateAction.deactivate),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsCurrencyRateAction.deactivate),
                  ),
                ),
                AppSearchBarAction(
                  label: AccountsStrings.currencyBulkArchiveAction,
                  icon: Icons.inventory_2_outlined,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsCurrencyRateAction.archive),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsCurrencyRateAction.archive),
                  ),
                ),
              ]
            : const <AppSearchBarAction>[],
      ),
      columns: columns,
      columnChoices: columnChoices,
      mobileItemBuilder: (BuildContext context, AccountsCurrencyRate rate) {
        return AppListTableMobileItem(
          title: '${rate.currencyCode} · ${rate.currencyName}',
          caption:
              '${accountsCurrencyRateTypeLabel(rate.rateType)} · '
              '${accountsRate(context, rate.exchangeRate, decimalPlaces: rate.decimalPlaces)}',
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: accountsDate(context, rate.effectiveDate),
              icon: Icons.event_available_outlined,
            ),
            AppListTableMobileMeta(
              label: accountsCurrencyStatusLabel(rate.status),
              icon: accountsCurrencyStatusIcon(rate.status),
            ),
            if (rate.baseCurrency)
              const AppListTableMobileMeta(
                label: AccountsStrings.currencyBaseYes,
                icon: Icons.star_outline,
              ),
          ],
        );
      },
    );
  }

  bool _hasEligible(AccountsCurrencyRateAction action) {
    return _page.items.any(
      (AccountsCurrencyRate rate) => _supportsAction(rate, action),
    );
  }
}
