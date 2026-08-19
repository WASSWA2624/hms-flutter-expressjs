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

const String accountsFiscalReferenceColumnId = 'reference';
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

/// The 14 documented columns in source-of-truth order.
///
/// Settings and export preserve this order; visibility follows
/// [accountsFiscalPeriodOptionalColumnIds].
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

/// Columns the specification marks `Optional`: selectable and exportable, but
/// hidden until the operator turns them on in Settings.
///
/// The baseline human-friendly Reference column joins them so the default view
/// stays the source-of-truth default set.
const List<String> accountsFiscalPeriodOptionalColumnIds = <String>[
  accountsFiscalReferenceColumnId,
  accountsFiscalLockDateColumnId,
  accountsFiscalReopenedAtColumnId,
  accountsFiscalReopenedByColumnId,
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
  static const String _facilityFilterKey = 'facility';
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

  /// Facilities seen in this tenant/facility scope, keyed by public reference.
  ///
  /// Accumulated across loads so narrowing to one facility never removes the
  /// choice that produced the narrowing. The backend still re-resolves the
  /// requested facility inside the caller's tenant, so this list can only
  /// narrow scope, never widen it.
  final Map<String, String> _facilityChoices = <String, String>{};

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
      facilityId: (_filterValue.option(_facilityFilterKey) ?? '').trim(),
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
          for (final AccountsFiscalPeriod period in page.items) {
            final String reference = (period.facilityHumanFriendlyId ?? '')
                .trim();
            final String label = (period.entityAndFacility ?? '').trim();
            if (reference.isNotEmpty && label.isNotEmpty) {
              _facilityChoices[reference] = label;
            }
          }
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

    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: _bulkTitle(l10n, action),
        body: l10n.accountsFiscalBulkConfirmBody(eligible.length),
        submitLabel: accountsFiscalPeriodActionLabel(l10n, action),
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
              : l10n.accountsFiscalBulkPartialFailure(failed),
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

  static String _bulkTitle(
    AppLocalizations l10n,
    AccountsFiscalPeriodAction action,
  ) {
    return switch (action) {
      AccountsFiscalPeriodAction.activate =>
        l10n.accountsFiscalBulkActivateAction,
      AccountsFiscalPeriodAction.deactivate =>
        l10n.accountsFiscalBulkDeactivateAction,
      AccountsFiscalPeriodAction.archive =>
        l10n.accountsFiscalBulkArchiveAction,
      AccountsFiscalPeriodAction.restore => l10n.accountsFiscalRestoreAction,
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
    final AppLocalizations l10n = context.l10n;
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
            label: l10n.accountsFiscalViewAction,
            tooltip: l10n.accountsFiscalViewAction,
            dense: true,
            onPressed: () => unawaited(_openDetail(period)),
          ),
          if (canWrite && period.canEdit)
            AppButton.tertiary(
              leadingIcon: Icons.edit_outlined,
              label: l10n.commonEditActionLabel,
              tooltip: l10n.commonEditActionLabel,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openEdit(period)),
            ),
          if (canWrite && period.canClone)
            AppButton.tertiary(
              leadingIcon: Icons.copy_all_outlined,
              label: l10n.accountsFiscalCloneAction,
              tooltip: l10n.accountsFiscalCloneAction,
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
              label: accountsFiscalPeriodActionLabel(l10n, toggle),
              tooltip: accountsFiscalPeriodActionLabel(l10n, toggle),
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
              label: l10n.accountsFiscalArchiveAction,
              tooltip: l10n.accountsFiscalArchiveAction,
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

  /// Optional columns: available in Settings, exports, and print, hidden until
  /// the operator enables them (specification marks these `Optional`).
  List<AppListTableColumn<AccountsFiscalPeriod>> _optionalColumns(
    AppLocalizations l10n,
  ) {
    return <AppListTableColumn<AccountsFiscalPeriod>>[
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalReferenceColumnId,
        label: l10n.accountsFiscalReferenceColumn,
        preferredWidth: 150,
        cellBuilder: (_, AccountsFiscalPeriod period) => AppCopyableIdentifier(
          value:
              accountsPublicLabel(period.humanFriendlyId) ??
              accountsUnknownValue(),
        ),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            a.humanFriendlyId.compareTo(b.humanFriendlyId),
        exportValue: (AccountsFiscalPeriod period) =>
            accountsPublicLabel(period.humanFriendlyId) ?? '',
      ),
      _dateColumn(
        id: accountsFiscalLockDateColumnId,
        label: l10n.accountsFiscalLockDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.lockDate,
      ),
      _dateColumn(
        id: accountsFiscalReopenedAtColumnId,
        label: l10n.accountsFiscalReopenedAtColumn,
        valueOf: (AccountsFiscalPeriod period) => period.reopenedAt,
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalReopenedByColumnId,
        label: l10n.accountsFiscalReopenedByColumn,
        preferredWidth: 150,
        cellBuilder: (_, AccountsFiscalPeriod period) => Text(
          period.reopenedBy ?? accountsUnknownValue(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            (a.reopenedBy ?? '').compareTo(b.reopenedBy ?? ''),
        exportValue: (AccountsFiscalPeriod period) => period.reopenedBy ?? '',
      ),
    ];
  }

  static AppListTableColumn<AccountsFiscalPeriod> _dateColumn({
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
      sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
          _compareDates(valueOf(a), valueOf(b)),
      exportValue: (AccountsFiscalPeriod period) =>
          valueOf(period)?.toIso8601String() ?? '',
    );
  }

  List<AppListTableColumn<AccountsFiscalPeriod>> _columns({
    required AppLocalizations l10n,
    required bool canWrite,
  }) {
    return <AppListTableColumn<AccountsFiscalPeriod>>[
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalYearColumnId,
        label: l10n.accountsFiscalYearColumn,
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
        label: l10n.accountsFiscalPeriodNoColumn,
        numeric: true,
        preferredWidth: 100,
        cellBuilder: (_, AccountsFiscalPeriod period) =>
            Text('${period.periodNo}'),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            a.periodNo.compareTo(b.periodNo),
        exportValue: (AccountsFiscalPeriod period) => period.periodNo,
      ),
      // One fact per cell: the human-friendly reference has its own optional
      // Reference column rather than riding along with the name.
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalPeriodNameColumnId,
        label: l10n.accountsFiscalPeriodNameColumn,
        alwaysVisible: true,
        preferredWidth: 180,
        cellBuilder: (_, AccountsFiscalPeriod period) => Text(
          period.periodName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            a.periodName.compareTo(b.periodName),
        exportValue: (AccountsFiscalPeriod period) => period.periodName,
      ),
      _dateColumn(
        id: accountsFiscalStartDateColumnId,
        label: l10n.accountsFiscalStartDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.startDate,
      ),
      _dateColumn(
        id: accountsFiscalEndDateColumnId,
        label: l10n.accountsFiscalEndDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.endDate,
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalEntityColumnId,
        label: l10n.accountsFiscalEntityAndFacilityColumn,
        preferredWidth: 160,
        cellBuilder: (_, AccountsFiscalPeriod period) => Text(
          period.entityAndFacility ?? accountsUnknownValue(),
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
        label: l10n.accountsFiscalModuleColumn,
        preferredWidth: 110,
        cellBuilder: (_, AccountsFiscalPeriod period) =>
            Text(period.module ?? accountsUnknownValue()),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            (a.module ?? '').compareTo(b.module ?? ''),
        exportValue: (AccountsFiscalPeriod period) => period.module ?? '',
      ),
      _dateColumn(
        id: accountsFiscalOpenDateColumnId,
        label: l10n.accountsFiscalOpenDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.openDate,
      ),
      _dateColumn(
        id: accountsFiscalSoftCloseDateColumnId,
        label: l10n.accountsFiscalSoftCloseDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.softCloseDate,
      ),
      _dateColumn(
        id: accountsFiscalCloseDateColumnId,
        label: l10n.accountsFiscalCloseDateColumn,
        valueOf: (AccountsFiscalPeriod period) => period.closeDate,
      ),
      AppListTableColumn<AccountsFiscalPeriod>(
        id: accountsFiscalStatusColumnId,
        label: l10n.accountsFiscalPeriodStatusColumn,
        alwaysVisible: true,
        preferredWidth: 130,
        cellBuilder: (_, AccountsFiscalPeriod period) =>
            AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: accountsFiscalPeriodStatusLabel(l10n, period.status),
                tone: accountsFiscalPeriodStatusTone(period.status),
                icon: accountsFiscalPeriodStatusIcon(period.status),
              ),
            ),
        sortComparator: (AccountsFiscalPeriod a, AccountsFiscalPeriod b) =>
            a.status.index.compareTo(b.status.index),
        exportValue: (AccountsFiscalPeriod period) =>
            accountsFiscalPeriodStatusLabel(l10n, period.status),
      ),
      if (canWrite)
        AppListTableColumn<AccountsFiscalPeriod>(
          id: accountsFiscalActionsColumnId,
          label: l10n.accountsFiscalActionsColumn,
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
      l10n: l10n,
      canWrite: canWrite,
    );
    final List<AppListTableColumn<AccountsFiscalPeriod>> optionalColumns =
        _optionalColumns(l10n);

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
        sheetName: l10n.accountsFiscalPeriodsLabel,
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
            title: l10n.accountsFiscalPeriodsLabel,
            // Print offers the full source-of-truth column inventory, not only
            // the columns currently visible.
            columns: <AppListTableColumn<AccountsFiscalPeriod>>[
              ...columns,
              ...optionalColumns,
            ],
            items: items,
            emptyText: l10n.accountsFiscalPeriodsEmpty,
          ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      onRowSelected: (AccountsFiscalPeriod period) =>
          unawaited(_openDetail(period)),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.accountsFiscalPeriodsEmpty,
        body: l10n.accountsFiscalPeriodsEmptyBody,
      ),
      search: AppListTableSearch<AccountsFiscalPeriod>(
        controller: _searchController,
        semanticLabel: l10n.accountsFiscalPeriodsSearchHint,
        hintText: l10n.accountsFiscalPeriodsSearchHint,
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
        dateFilterLabel: l10n.accountsFiscalDateRangeFilterLabel,
        dateFromLabel: l10n.accountsFiscalStartDateColumn,
        dateToLabel: l10n.accountsFiscalEndDateColumn,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _fiscalYearFilterKey,
            label: l10n.accountsFiscalYearColumn,
            hintText: l10n.accountsFiscalYearColumn,
            icon: Icons.calendar_today_outlined,
          ),
          AppSearchBarTextFilter(
            key: _moduleFilterKey,
            label: l10n.accountsFiscalModuleColumn,
            hintText: l10n.accountsFiscalModuleColumn,
            icon: Icons.widgets_outlined,
          ),
          AppSearchBarTextFilter(
            key: _periodNameFilterKey,
            label: l10n.accountsFiscalPeriodNameColumn,
            hintText: l10n.accountsFiscalPeriodNameColumn,
            icon: Icons.event_note_outlined,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.accountsFiscalPeriodStatusColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsFiscalPeriodStatus status
                  in AccountsFiscalPeriodStatus.values)
                AppSearchBarFilterChoice(
                  value: status.wireValue,
                  label: accountsFiscalPeriodStatusLabel(l10n, status),
                  icon: accountsFiscalPeriodStatusIcon(status),
                ),
            ],
          ),
          // Offered only where the caller's ABAC scope actually spans more than
          // one facility; a single-facility operator gets no dead control.
          if (_facilityChoices.length > 1)
            AppSearchBarFilterGroup(
              key: _facilityFilterKey,
              label: l10n.accountsFiscalFacilityFilterLabel,
              allLabel: AccountsStrings.allFields,
              choices: <AppSearchBarFilterChoice>[
                for (final MapEntry<String, String> facility
                    in _sortedFacilityChoices)
                  AppSearchBarFilterChoice(
                    value: facility.key,
                    label: facility.value,
                    icon: Icons.apartment_outlined,
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
                  label: l10n.accountsFiscalNewRecordAction,
                  icon: Icons.add_outlined,
                  enabled: !_isMutating,
                  onPressed: () => unawaited(_openCreate()),
                ),
                AppSearchBarAction(
                  label: l10n.accountsFiscalBulkActivateAction,
                  icon: Icons.check_circle_outline,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsFiscalPeriodAction.activate),
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsFiscalPeriodAction.activate),
                  ),
                ),
                AppSearchBarAction(
                  label: l10n.accountsFiscalBulkDeactivateAction,
                  icon: Icons.pause_circle_outline,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsFiscalPeriodAction.deactivate),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsFiscalPeriodAction.deactivate),
                  ),
                ),
                AppSearchBarAction(
                  label: l10n.accountsFiscalBulkArchiveAction,
                  icon: Icons.inventory_2_outlined,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsFiscalPeriodAction.archive),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsFiscalPeriodAction.archive),
                  ),
                ),
              ]
            : const <AppSearchBarAction>[],
      ),
      columns: columns,
      columnChoices: optionalColumns,
      mobileItemBuilder: (BuildContext context, AccountsFiscalPeriod period) {
        return AppListTableMobileItem(
          title: period.periodName,
          caption: l10n.accountsFiscalMobileCaption(
            period.fiscalYear,
            period.periodNo,
          ),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: l10n.accountsFiscalMobileDateRange(
                accountsDate(context, period.startDate),
                accountsDate(context, period.endDate),
              ),
              icon: Icons.date_range_outlined,
            ),
            AppListTableMobileMeta(
              label: accountsFiscalPeriodStatusLabel(l10n, period.status),
              icon: accountsFiscalPeriodStatusIcon(period.status),
            ),
            if (period.isLocked)
              AppListTableMobileMeta(
                label: l10n.accountsFiscalStatusLocked,
                icon: Icons.lock_outline,
              ),
          ],
        );
      },
    );
  }

  /// Facility choices in stable label order so the filter list never reshuffles
  /// between loads.
  List<MapEntry<String, String>> get _sortedFacilityChoices {
    final List<MapEntry<String, String>> entries = _facilityChoices.entries
        .toList(growable: false);
    entries.sort(
      (MapEntry<String, String> a, MapEntry<String, String> b) =>
          a.value.toLowerCase().compareTo(b.value.toLowerCase()),
    );
    return entries;
  }

  bool _hasEligible(AccountsFiscalPeriodAction action) {
    return _page.items.any(
      (AccountsFiscalPeriod period) => _supportsAction(period, action),
    );
  }
}
