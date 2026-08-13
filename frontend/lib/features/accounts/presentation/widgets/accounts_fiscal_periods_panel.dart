import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_fiscal_period_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_fiscal_period.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_fiscal_period_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

const String accountsFiscalPeriodsTableSettingsKey = 'accounts_fiscal_periods_v1';
const String accountsFiscalPeriodsColumnWidthKey = 'accounts_fiscal_periods_cw_v1';

const String accountsFiscalYearColumnId = 'fiscal_year';
const String accountsFiscalPeriodNoColumnId = 'period_no';
const String accountsFiscalPeriodNameColumnId = 'period_name';
const String accountsFiscalStartDateColumnId = 'start_date';
const String accountsFiscalEndDateColumnId = 'end_date';
const String accountsFiscalEntityColumnId = 'entity_and_facility';
const String accountsFiscalModuleColumnId = 'module';
const String accountsFiscalOpenDateColumnId = 'open_date';
const String accountsFiscalSoftCloseDateColumnId = 'soft_close_date';
const String accountsFiscalCloseDateColumnId = 'close_date';
const String accountsFiscalLockDateColumnId = 'lock_date';
const String accountsFiscalReopenedAtColumnId = 'reopened_at';
const String accountsFiscalReopenedByColumnId = 'reopened_by';
const String accountsFiscalStatusColumnId = 'period_status';
const String accountsFiscalActionsColumnId = 'actions';

/// The 14 documented columns plus Actions, in source-of-truth order.
const List<String> accountsFiscalPeriodColumnIds = <String>[
  accountsFiscalYearColumnId,
  accountsFiscalPeriodNoColumnId,
  accountsFiscalPeriodNameColumnId,
  accountsFiscalStartDateColumnId,
  accountsFiscalEndDateColumnId,
  accountsFiscalEntityColumnId,
  accountsFiscalModuleColumnId,
  accountsFiscalOpenDateColumnId,
  accountsFiscalSoftCloseDateColumnId,
  accountsFiscalCloseDateColumnId,
  accountsFiscalLockDateColumnId,
  accountsFiscalReopenedAtColumnId,
  accountsFiscalReopenedByColumnId,
  accountsFiscalStatusColumnId,
];

/// `Accounts & Finance → Setup & Controls → Fiscal Years & Periods`
/// (`?section=fiscal-years-and-periods`).
class AccountsFiscalPeriodsPanel extends ConsumerStatefulWidget {
  const AccountsFiscalPeriodsPanel({super.key});

  @override
  ConsumerState<AccountsFiscalPeriodsPanel> createState() =>
      _AccountsFiscalPeriodsPanelState();
}

class _AccountsFiscalPeriodsPanelState
    extends ConsumerState<AccountsFiscalPeriodsPanel> {
  static const String _statusFilterKey = 'period_status';
  static const String _fiscalYearFilterKey = 'fiscal_year';
  static const String _moduleFilterKey = 'module';
  static const String _periodNameFilterKey = 'period_name';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<AccountsFiscalPeriod>
  _columnController =
      AppListTableColumnVisibilityController<AccountsFiscalPeriod>(
        storageKey: accountsFiscalPeriodsTableSettingsKey,
      );

  AppPage<AccountsFiscalPeriod> _page = const AppPage<AccountsFiscalPeriod>(
    items: <AccountsFiscalPeriod>[],
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

  AccountsFiscalPeriodQuery get _query {
    final String status = _filterValue.option(_statusFilterKey) ?? '';
    final AccountsFiscalPeriodStatus? parsed =
        AccountsFiscalPeriodStatus.fromWire(status);
    return AccountsFiscalPeriodQuery(
      search: _searchController.text.trim(),
      statuses: parsed == null
          ? const <AccountsFiscalPeriodStatus>{}
          : <AccountsFiscalPeriodStatus>{parsed},
      fiscalYear: (_filterValue.text(_fiscalYearFilterKey) ?? '').trim(),
      module: (_filterValue.text(_moduleFilterKey) ?? '').trim(),
      periodName: (_filterValue.text(_periodNameFilterKey) ?? '').trim(),
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

    final AccountsFiscalPeriodQuery query = _query;
    final Result<AppPage<AccountsFiscalPeriod>> result = await ref
        .read(accountsFiscalPeriodRepositoryProvider)
        .listPeriods(query);

    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<AccountsFiscalPeriod> page) {
        setState(() {
          _page = page;
          _loading = false;
          _revision++;
        });
        // Badge from the server total when narrowed; otherwise defer to the
        // workspace summary so it never reflects only the painted page.
        ref
                .read<StateController<int?>>(
                  accountsFiscalPeriodCountProvider.notifier,
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

  Future<void> _openCreate({AccountsFiscalPeriod? cloneOf}) async {
    final bool saved = await showAccountsFiscalPeriodDialog(
      context: context,
      ref: ref,
      mode: cloneOf == null
          ? AccountsFiscalPeriodDialogMode.create
          : AccountsFiscalPeriodDialogMode.clone,
      source: cloneOf,
    );
    if (saved && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  Future<void> _openEdit(AccountsFiscalPeriod period) async {
    if (!period.canEdit) {
      return;
    }
    final bool saved = await showAccountsFiscalPeriodDialog(
      context: context,
      ref: ref,
      mode: AccountsFiscalPeriodDialogMode.edit,
      source: period,
    );
    if (saved && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  Future<void> _openDetail(AccountsFiscalPeriod period) async {
    await showAccountsFiscalPeriodDetail(
      context: context,
      ref: ref,
      period: period,
    );
  }

  Future<void> _applyAction(
    AccountsFiscalPeriod period,
    AccountsFiscalPeriodAction action,
  ) async {
    final bool applied = await confirmAccountsFiscalPeriodAction(
      context: context,
      ref: ref,
      period: period,
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
  Future<void> _applyBulkAction(AccountsFiscalPeriodAction action) async {
    final List<AccountsFiscalPeriod> eligible = _page.items
        .where((AccountsFiscalPeriod period) => _supportsAction(period, action))
        .toList(growable: false);
    if (eligible.isEmpty) {
      return;
    }

    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: _bulkTitle(action),
        body: AccountsStrings.fiscalBulkConfirmBody(
          eligible.length,
          accountsFiscalPeriodActionLabel(action).toLowerCase(),
        ),
        submitLabel: accountsFiscalPeriodActionLabel(action),
        destructive: action != AccountsFiscalPeriodAction.activate,
        icon: const Icon(Icons.playlist_add_check_outlined),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isMutating = true);
    int failed = 0;
    for (final AccountsFiscalPeriod period in eligible) {
      final Result<AccountsFiscalPeriod> result = await ref
          .read(accountsFiscalPeriodRepositoryProvider)
          .applyAction(
            period.humanFriendlyId,
            action,
            version: period.version,
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
              accountsFiscalPeriodRevisionProvider.notifier,
            )
            .state++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? AccountsStrings.saved
              : AccountsStrings.fiscalBulkPartialFailure(failed),
        ),
      ),
    );
    await _reload();
  }

  static bool _supportsAction(
    AccountsFiscalPeriod period,
    AccountsFiscalPeriodAction action,
  ) {
    return switch (action) {
      AccountsFiscalPeriodAction.activate => period.canActivate,
      AccountsFiscalPeriodAction.deactivate => period.canDeactivate,
      AccountsFiscalPeriodAction.archive => period.canArchive,
      AccountsFiscalPeriodAction.restore => period.canRestore,
    };
  }

  static String _bulkTitle(AccountsFiscalPeriodAction action) {
    return switch (action) {
      AccountsFiscalPeriodAction.activate =>
        AccountsStrings.fiscalBulkActivateAction,
      AccountsFiscalPeriodAction.deactivate =>
        AccountsStrings.fiscalBulkDeactivateAction,
      AccountsFiscalPeriodAction.archive =>
        AccountsStrings.fiscalBulkArchiveAction,
      AccountsFiscalPeriodAction.restore =>
        AccountsStrings.fiscalRestoreAction,
    };
  }

  void _notifySaved() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AccountsStrings.saved)));
  }

  Widget _actionsCell(BuildContext context, AccountsFiscalPeriod period) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool canWrite = canWriteAccountsFiscalPeriods(
      ref.watch(appAccessPolicyProvider),
    );
    final AccountsFiscalPeriodAction? toggle = period.toggleAction;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: theme.spacing.md,
        runSpacing: theme.spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          AppButton.tertiary(
            leadingIcon: Icons.visibility_outlined,
            label: AccountsStrings.fiscalViewAction,
            tooltip: AccountsStrings.fiscalViewAction,
            dense: true,
            onPressed: () => unawaited(_openDetail(period)),
          ),
          if (canWrite && period.canEdit)
            AppButton.tertiary(
              leadingIcon: Icons.edit_outlined,
              label: context.l10n.commonEditActionLabel,
              tooltip: context.l10n.commonEditActionLabel,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openEdit(period)),
            ),
          if (canWrite && period.canClone)
            AppButton.tertiary(
              leadingIcon: Icons.copy_all_outlined,
              label: AccountsStrings.fiscalCloneAction,
              tooltip: AccountsStrings.fiscalCloneAction,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openCreate(cloneOf: period)),
            ),
          if (canWrite && toggle != null)
            AppButton.tertiary(
              leadingIcon: switch (toggle) {
                AccountsFiscalPeriodAction.restore => Icons.restore_outlined,
                AccountsFiscalPeriodAction.deactivate =>
                  Icons.pause_circle_outline,
                _ => Icons.check_circle_outline,
              },
              label: accountsFiscalPeriodActionLabel(toggle),
              tooltip: accountsFiscalPeriodActionLabel(toggle),
              dense: true,
              enabled: !_isMutating,
              color: toggle == AccountsFiscalPeriodAction.deactivate
                  ? colors.error
                  : null,
              onPressed: () => unawaited(_applyAction(period, toggle)),
            ),
          if (canWrite && period.canArchive)
            AppButton.tertiary(
              leadingIcon: Icons.inventory_2_outlined,
              label: AccountsStrings.fiscalArchiveAction,
              tooltip: AccountsStrings.fiscalArchiveAction,
              dense: true,
              enabled: !_isMutating,
              color: colors.error,
              onPressed: () => unawaited(
                _applyAction(period, AccountsFiscalPeriodAction.archive),
              ),
            ),
        ],
      ),
    );
  }

  List<AppListTableColumn<AccountsFiscalPeriod>> _columns({
    required bool canWrite,
  }) {
    AppListTableColumn<AccountsFiscalPeriod> dateColumn({
      required String id,
      required String label,
      required DateTime? Function(AccountsFiscalPeriod period) valueOf,
    }) {
      return AppListTableColumn<AccountsFiscalPeriod>(
        id: id,
        label: label,
        preferredWidth: 130,
        cellBuilder: (BuildContext context, AccountsFiscalPeriod period) =>
            Text(accountsDate(context, valueOf(period))),
        sortComparator:
            (AccountsFiscalPeriod a, AccountsFiscalPeriod b) => _compareDates(
              valueOf(a),
              valueOf(b),
            ),
        exportValue: (AccountsFiscalPeriod period) =>
            valueOf(period)?.toIso8601String() ?? '',
      );
    }

    return <AppListTableColumn<AccountsFiscalPeriod>>[
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalYearColumnId,
        label: AccountsStrings.fiscalYearColumn,
        alwaysVisible: true,
        preferredWidth: 120,
        cellBuilder: (_, AccountsFiscalPeriod period) => Text(
          period.fiscalYear,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            a.fiscalYear.compareTo(b.fiscalYear),
        exportValue: (AccountsFiscalPeriod period) => period.fiscalYear,
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalPeriodNoColumnId,
        label: AccountsStrings.fiscalPeriodNoColumn,
        numeric: true,
        preferredWidth: 100,
        cellBuilder: (_, AccountsFiscalPeriod period) =>
            Text('${period.periodNo}'),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            a.periodNo.compareTo(b.periodNo),
        exportValue: (AccountsFiscalPeriod period) => period.periodNo,
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalPeriodNameColumnId,
        label: AccountsStrings.fiscalPeriodNameColumn,
        alwaysVisible: true,
        preferredWidth: 180,
        cellBuilder: (_, AccountsFiscalPeriod period) => AppCopyableIdentifierCell(
          title: period.periodName,
          identifier: accountsPublicLabel(period.humanFriendlyId),
        ),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            a.periodName.compareTo(b.periodName),
        exportValue: (AccountsFiscalPeriod period) => period.periodName,
      ),
      dateColumn(
        id: accountsFiscalStartDateColumnId,
        label: AccountsStrings.fiscalStartDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.startDate,
      ),
      dateColumn(
        id: accountsFiscalEndDateColumnId,
        label: AccountsStrings.fiscalEndDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.endDate,
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalEntityColumnId,
        label: AccountsStrings.fiscalEntityAndFacilityColumn,
        preferredWidth: 160,
        cellBuilder: (_, AccountsFiscalPeriod period) => Text(
          period.entityAndFacility ?? AccountsStrings.unknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            (a.entityAndFacility ?? '').compareTo(b.entityAndFacility ?? ''),
        exportValue: (AccountsFiscalPeriod period) =>
            period.entityAndFacility ?? '',
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalModuleColumnId,
        label: AccountsStrings.fiscalModuleColumn,
        preferredWidth: 110,
        cellBuilder: (_, AccountsFiscalPeriod period) =>
            Text(period.module ?? AccountsStrings.unknownValue),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            (a.module ?? '').compareTo(b.module ?? ''),
        exportValue: (AccountsFiscalPeriod period) => period.module ?? '',
      ),
      dateColumn(
        id: accountsFiscalOpenDateColumnId,
        label: AccountsStrings.fiscalOpenDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.openDate,
      ),
      dateColumn(
        id: accountsFiscalSoftCloseDateColumnId,
        label: AccountsStrings.fiscalSoftCloseDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.softCloseDate,
      ),
      dateColumn(
        id: accountsFiscalCloseDateColumnId,
        label: AccountsStrings.fiscalCloseDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.closeDate,
      ),
      dateColumn(
        id: accountsFiscalLockDateColumnId,
        label: AccountsStrings.fiscalLockDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.lockDate,
      ),
      dateColumn(
        id: accountsFiscalReopenedAtColumnId,
        label: AccountsStrings.fiscalReopenedAtColumn,
        valueOf: (AccountsFiscalPeriod period) => period.reopenedAt,
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalReopenedByColumnId,
        label: AccountsStrings.fiscalReopenedByColumn,
        preferredWidth: 150,
        cellBuilder: (_, AccountsFiscalPeriod period) => Text(
          period.reopenedBy ?? AccountsStrings.unknownValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            (a.reopenedBy ?? '').compareTo(b.reopenedBy ?? ''),
        exportValue: (AccountsFiscalPeriod period) => period.reopenedBy ?? '',
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalStatusColumnId,
        label: AccountsStrings.fiscalPeriodStatusColumn,
        alwaysVisible: true,
        preferredWidth: 130,
        cellBuilder: (_, AccountsFiscalPeriod period) => AppStatusBadge(
          label: accountsFiscalPeriodStatusLabel(period.status),
          tone: accountsFiscalPeriodStatusTone(period.status),
          icon: accountsFiscalPeriodStatusIcon(period.status),
        ),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            a.status.index.compareTo(b.status.index),
        exportValue: (AccountsFiscalPeriod period) =>
            accountsFiscalPeriodStatusLabel(period.status),
      ),
      if (canWrite)
        AppListTableColumn<AccountsFiscalPeriod>(
          id: accountsFiscalActionsColumnId,
          label: AccountsStrings.fiscalActionsColumn,
          alwaysVisible: true,
          exportable: false,
          preferredWidth: 260,
          cellBuilder: _actionsCell,
        ),
    ];
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteAccountsFiscalPeriods(accessPolicy);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
    final List<AppListTableColumn<AccountsFiscalPeriod>> columns = _columns(
      canWrite: canWrite,
    );

    // Mutations elsewhere (detail dialog, other panels) invalidate this list.
    ref.listen<int>(accountsFiscalPeriodRevisionProvider, (_, _) {
      unawaited(_reload());
    });

    return AppListTable<AccountsFiscalPeriod>(
      page: _page,
      rowsVersion: _revision,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      itemKeyBuilder: (AccountsFiscalPeriod period) =>
          ValueKey<String>(period.humanFriendlyId),
      initialSortColumnKey: accountsFiscalStartDateColumnId,
      initialSortAscending: false,
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: accountsFiscalPeriodsTableSettingsKey,
      columnWidthStorageKey: accountsFiscalPeriodsColumnWidthKey,
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
      exportConfig: AppListTableExportConfig<AccountsFiscalPeriod>(
        fileNameStem: 'accounts_fiscal_periods',
        sheetName: AccountsStrings.fiscalPeriodsLabel,
        dateOf: (AccountsFiscalPeriod period) => period.startDate,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      enablePrint: true,
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      onPrint: (List<AccountsFiscalPeriod> items) =>
          printAccountsListTable<AccountsFiscalPeriod>(
            ref: ref,
            context: context,
            title: AccountsStrings.fiscalPeriodsLabel,
            columns: columns,
            items: items,
            emptyText: AccountsStrings.fiscalPeriodsEmpty,
          ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      onRowSelected: (AccountsFiscalPeriod period) =>
          unawaited(_openDetail(period)),
      emptyBuilder: (_) => const AppWorkspaceStatePanel.empty(
        title: AccountsStrings.fiscalPeriodsEmpty,
        body: AccountsStrings.fiscalPeriodsEmptyBody,
      ),
      search: AppListTableSearch<AccountsFiscalPeriod>(
        controller: _searchController,
        semanticLabel: AccountsStrings.fiscalPeriodsSearchHint,
        hintText: AccountsStrings.fiscalPeriodsSearchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsFiscalPeriod period, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          final String reference =
              accountsPublicLabel(period.humanFriendlyId) ?? '';
          return reference.toLowerCase().contains(needle) ||
              period.fiscalYear.toLowerCase().contains(needle) ||
              period.periodName.toLowerCase().contains(needle) ||
              (period.module ?? '').toLowerCase().contains(needle);
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
        dateFilterLabel: AccountsStrings.fiscalDateRangeFilterLabel,
        dateFromLabel: AccountsStrings.fiscalStartDateColumn,
        dateToLabel: AccountsStrings.fiscalEndDateColumn,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        textFilters: const <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _fiscalYearFilterKey,
            label: AccountsStrings.fiscalYearColumn,
            hintText: AccountsStrings.fiscalYearColumn,
            icon: Icons.calendar_today_outlined,
          ),
          AppSearchBarTextFilter(
            key: _moduleFilterKey,
            label: AccountsStrings.fiscalModuleColumn,
            hintText: AccountsStrings.fiscalModuleColumn,
            icon: Icons.widgets_outlined,
          ),
          AppSearchBarTextFilter(
            key: _periodNameFilterKey,
            label: AccountsStrings.fiscalPeriodNameColumn,
            hintText: AccountsStrings.fiscalPeriodNameColumn,
            icon: Icons.event_note_outlined,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: AccountsStrings.fiscalPeriodStatusColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsFiscalPeriodStatus status
                  in AccountsFiscalPeriodStatus.values)
                AppSearchBarFilterChoice(
                  value: status.wireValue,
                  label: accountsFiscalPeriodStatusLabel(status),
                  icon: accountsFiscalPeriodStatusIcon(status),
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
                  label: AccountsStrings.fiscalNewRecordAction,
                  icon: Icons.add_outlined,
                  enabled: !_isMutating,
                  onPressed: () => unawaited(_openCreate()),
                ),
                AppSearchBarAction(
                  label: AccountsStrings.fiscalBulkActivateAction,
                  icon: Icons.check_circle_outline,
                  enabled: !_isMutating && _hasEligible(
                    AccountsFiscalPeriodAction.activate,
                  ),
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsFiscalPeriodAction.activate),
                  ),
                ),
                AppSearchBarAction(
                  label: AccountsStrings.fiscalBulkDeactivateAction,
                  icon: Icons.pause_circle_outline,
                  enabled: !_isMutating && _hasEligible(
                    AccountsFiscalPeriodAction.deactivate,
                  ),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsFiscalPeriodAction.deactivate),
                  ),
                ),
                AppSearchBarAction(
                  label: AccountsStrings.fiscalBulkArchiveAction,
                  icon: Icons.inventory_2_outlined,
                  enabled: !_isMutating && _hasEligible(
                    AccountsFiscalPeriodAction.archive,
                  ),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsFiscalPeriodAction.archive),
                  ),
                ),
              ]
            : const <AppSearchBarAction>[],
      ),
      columns: columns,
      mobileItemBuilder: (BuildContext context, AccountsFiscalPeriod period) {
        return AppListTableMobileItem(
          title: period.periodName,
          caption:
              '${period.fiscalYear} · ${AccountsStrings.fiscalPeriodNoColumn} '
              '${period.periodNo}',
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label:
                  '${accountsDate(context, period.startDate)} – '
                  '${accountsDate(context, period.endDate)}',
              icon: Icons.date_range_outlined,
            ),
            AppListTableMobileMeta(
              label: accountsFiscalPeriodStatusLabel(period.status),
              icon: accountsFiscalPeriodStatusIcon(period.status),
            ),
            if (period.isLocked)
              const AppListTableMobileMeta(
                label: AccountsStrings.fiscalStatusLocked,
                icon: Icons.lock_outline,
              ),
          ],
        );
      },
    );
  }

  bool _hasEligible(AccountsFiscalPeriodAction action) {
    return _page.items.any(
      (AccountsFiscalPeriod period) => _supportsAction(period, action),
    );
  }
}
