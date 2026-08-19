import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_department_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_department.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_department_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

const String accountsDepartmentsTableSettingsKey = 'accounts_departments_v1';
const String accountsDepartmentsColumnWidthKey = 'accounts_departments_cw_v1';

const String accountsDepartmentReferenceColumnId = 'reference';
const String accountsDepartmentCodeColumnId = 'department_code';
const String accountsDepartmentNameColumnId = 'department_name';
const String accountsDepartmentCostCentreCodeColumnId = 'cost_centre_code';
const String accountsDepartmentCostCentreNameColumnId = 'cost_centre_name';
const String accountsDepartmentParentColumnId = 'parent';
const String accountsDepartmentFacilityColumnId = 'facility';
const String accountsDepartmentManagerColumnId = 'manager';
const String accountsDepartmentRevenueAccountColumnId =
    'default_revenue_account';
const String accountsDepartmentExpenseAccountColumnId =
    'default_expense_account';
const String accountsDepartmentBudgetOwnerColumnId = 'budget_owner';
const String accountsDepartmentEffectiveFromColumnId = 'effective_from';
const String accountsDepartmentEffectiveToColumnId = 'effective_to';
const String accountsDepartmentStatusColumnId = 'status';
const String accountsDepartmentActionsColumnId = 'actions';

/// The 13 documented columns in source-of-truth order.
///
/// Settings and export preserve this order; visibility follows
/// [accountsDepartmentOptionalColumnIds].
const List<String> accountsDepartmentColumnIds = <String>[
  accountsDepartmentCodeColumnId,
  accountsDepartmentNameColumnId,
  accountsDepartmentCostCentreCodeColumnId,
  accountsDepartmentCostCentreNameColumnId,
  accountsDepartmentParentColumnId,
  accountsDepartmentFacilityColumnId,
  accountsDepartmentManagerColumnId,
  accountsDepartmentRevenueAccountColumnId,
  accountsDepartmentExpenseAccountColumnId,
  accountsDepartmentBudgetOwnerColumnId,
  accountsDepartmentEffectiveFromColumnId,
  accountsDepartmentEffectiveToColumnId,
  accountsDepartmentStatusColumnId,
];

/// Columns the specification marks `Optional`: selectable and exportable, but
/// hidden until the operator turns them on in Settings.
///
/// The baseline human-friendly Reference column joins them so the default view
/// stays the source-of-truth default set.
const List<String> accountsDepartmentOptionalColumnIds = <String>[
  accountsDepartmentReferenceColumnId,
  accountsDepartmentEffectiveFromColumnId,
  accountsDepartmentEffectiveToColumnId,
];

/// `Accounts & Finance → Setup & Controls → Departments & Cost Centres`
/// (`?section=departments-and-cost-centres`).
class AccountsDepartmentsAndCostCentresPanel extends ConsumerStatefulWidget {
  const AccountsDepartmentsAndCostCentresPanel({super.key});

  @override
  ConsumerState<AccountsDepartmentsAndCostCentresPanel> createState() =>
      _AccountsDepartmentsAndCostCentresPanelState();
}

class _AccountsDepartmentsAndCostCentresPanelState
    extends ConsumerState<AccountsDepartmentsAndCostCentresPanel> {
  static const String _statusFilterKey = 'status';
  static const String _facilityFilterKey = 'facility';
  static const String _costCentreFilterKey = 'cost_centre';
  static const String _ownerFilterKey = 'owner';
  static const String _departmentCodeFilterKey = 'department_code';
  static const String _departmentNameFilterKey = 'department_name';
  static const String _costCentreNameFilterKey = 'cost_centre_name';
  static const String _revenueAccountFilterKey = 'revenue_account';
  static const String _expenseAccountFilterKey = 'expense_account';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<AccountsDepartment>
  _columnController =
      AppListTableColumnVisibilityController<AccountsDepartment>(
        storageKey: accountsDepartmentsTableSettingsKey,
      );

  AppPage<AccountsDepartment> _page = const AppPage<AccountsDepartment>(
    items: <AccountsDepartment>[],
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

  /// Cost centres seen in scope, keyed by code. Backs the hierarchical
  /// department / cost centre picker with controlled reference data rather
  /// than free text.
  final Map<String, String> _costCentreChoices = <String, String>{};

  /// Managers and budget owners seen in scope, keyed by public reference.
  final Map<String, String> _ownerChoices = <String, String>{};

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

  AccountsDepartmentQuery get _query {
    final String status = _filterValue.option(_statusFilterKey) ?? '';
    final AccountsDepartmentStatus? parsed = AccountsDepartmentStatus.fromWire(
      status,
    );
    final String costCentre =
        (_filterValue.option(_costCentreFilterKey) ?? '').trim();
    return AccountsDepartmentQuery(
      search: _searchController.text.trim(),
      statuses: parsed == null
          ? const <AccountsDepartmentStatus>{}
          : <AccountsDepartmentStatus>{parsed},
      departmentCode: (_filterValue.text(_departmentCodeFilterKey) ?? '').trim(),
      departmentName: (_filterValue.text(_departmentNameFilterKey) ?? '').trim(),
      costCentreCodes: costCentre.isEmpty
          ? const <String>{}
          : <String>{costCentre},
      costCentreName: (_filterValue.text(_costCentreNameFilterKey) ?? '').trim(),
      facilityId: (_filterValue.option(_facilityFilterKey) ?? '').trim(),
      ownerId: (_filterValue.option(_ownerFilterKey) ?? '').trim(),
      revenueAccountId: (_filterValue.text(_revenueAccountFilterKey) ?? '')
          .trim(),
      expenseAccountId: (_filterValue.text(_expenseAccountFilterKey) ?? '')
          .trim(),
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

    final AccountsDepartmentQuery query = _query;
    final Result<AppPage<AccountsDepartment>> result = await ref
        .read(accountsDepartmentRepositoryProvider)
        .listDepartments(query);

    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<AccountsDepartment> page) {
        setState(() {
          _page = page;
          _loading = false;
          _revision++;
          _rememberFilterChoices(page.items);
        });
        // Badge from the server total when narrowed; otherwise defer to the
        // workspace summary so it never reflects only the painted page.
        ref
                .read<StateController<int?>>(
                  accountsDepartmentCountProvider.notifier,
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

  /// Controlled reference data for the facility, cost centre, and owner
  /// filters, harvested from rows the caller is already permitted to see.
  void _rememberFilterChoices(List<AccountsDepartment> items) {
    for (final AccountsDepartment department in items) {
      final String facilityRef = (department.facilityHumanFriendlyId ?? '')
          .trim();
      final String facilityLabel = (department.facility ?? '').trim();
      if (facilityRef.isNotEmpty && facilityLabel.isNotEmpty) {
        _facilityChoices[facilityRef] = facilityLabel;
      }

      final String costCentreCode = department.costCentreCode.trim();
      if (costCentreCode.isNotEmpty) {
        final String costCentreName = department.costCentreName.trim();
        _costCentreChoices[costCentreCode] = costCentreName.isEmpty
            ? costCentreCode
            : costCentreName;
      }

      final String managerRef = (department.managerHumanFriendlyId ?? '').trim();
      final String managerLabel = (department.manager ?? '').trim();
      if (managerRef.isNotEmpty && managerLabel.isNotEmpty) {
        _ownerChoices[managerRef] = managerLabel;
      }
      final String ownerRef = (department.budgetOwnerHumanFriendlyId ?? '')
          .trim();
      final String ownerLabel = (department.budgetOwner ?? '').trim();
      if (ownerRef.isNotEmpty && ownerLabel.isNotEmpty) {
        _ownerChoices[ownerRef] = ownerLabel;
      }
    }
  }

  bool get _hasActiveFilters =>
      _query.hasActiveFilters || _searchController.text.trim().isNotEmpty;

  Future<void> _openCreate({AccountsDepartment? cloneOf}) async {
    final bool saved = await showAccountsDepartmentDialog(
      context: context,
      ref: ref,
      mode: cloneOf == null
          ? AccountsDepartmentDialogMode.create
          : AccountsDepartmentDialogMode.clone,
      source: cloneOf,
    );
    if (saved && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  Future<void> _openEdit(AccountsDepartment department) async {
    if (!department.canEdit) {
      return;
    }
    final bool saved = await showAccountsDepartmentDialog(
      context: context,
      ref: ref,
      mode: AccountsDepartmentDialogMode.edit,
      source: department,
    );
    if (saved && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  Future<void> _openDetail(AccountsDepartment department) async {
    await showAccountsDepartmentDetail(
      context: context,
      ref: ref,
      department: department,
    );
  }

  Future<void> _applyAction(
    AccountsDepartment department,
    AccountsDepartmentAction action,
  ) async {
    final bool applied = await confirmAccountsDepartmentAction(
      context: context,
      ref: ref,
      department: department,
      action: action,
    );
    if (applied && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  /// Bulk workflow over every eligible row in the current filtered result.
  ///
  /// The shared table has no row-selection chrome, so "selected" means
  /// "matching the active filters" — the same set Export and Print operate on.
  Future<void> _applyBulkAction(AccountsDepartmentAction action) async {
    final List<AccountsDepartment> eligible = _page.items
        .where(
          (AccountsDepartment department) => _supportsAction(department, action),
        )
        .toList(growable: false);
    if (eligible.isEmpty) {
      return;
    }

    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: _bulkTitle(l10n, action),
        body: l10n.accountsDepartmentBulkConfirmBody(eligible.length),
        submitLabel: accountsDepartmentActionLabel(l10n, action),
        destructive: action != AccountsDepartmentAction.activate,
        icon: const Icon(Icons.playlist_add_check_outlined),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isMutating = true);
    int failed = 0;
    for (final AccountsDepartment department in eligible) {
      final Result<AccountsDepartment> result = await ref
          .read(accountsDepartmentRepositoryProvider)
          .applyAction(
            department.humanFriendlyId,
            action,
            version: department.version,
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
              accountsDepartmentRevisionProvider.notifier,
            )
            .state++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? AccountsStrings.saved
              : l10n.accountsDepartmentBulkPartialFailure(failed),
        ),
      ),
    );
    await _reload();
  }

  static bool _supportsAction(
    AccountsDepartment department,
    AccountsDepartmentAction action,
  ) {
    return switch (action) {
      AccountsDepartmentAction.activate => department.canActivate,
      AccountsDepartmentAction.deactivate => department.canDeactivate,
      AccountsDepartmentAction.archive => department.canArchive,
      AccountsDepartmentAction.restore => department.canRestore,
    };
  }

  static String _bulkTitle(
    AppLocalizations l10n,
    AccountsDepartmentAction action,
  ) {
    return switch (action) {
      AccountsDepartmentAction.activate =>
        l10n.accountsDepartmentBulkActivateAction,
      AccountsDepartmentAction.deactivate =>
        l10n.accountsDepartmentBulkDeactivateAction,
      AccountsDepartmentAction.archive =>
        l10n.accountsDepartmentBulkArchiveAction,
      AccountsDepartmentAction.restore => l10n.accountsDepartmentRestoreAction,
    };
  }

  void _notifySaved() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AccountsStrings.saved)));
  }

  Widget _actionsCell(BuildContext context, AccountsDepartment department) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final bool canWrite = canWriteAccountsDepartments(
      ref.watch(appAccessPolicyProvider),
    );
    final AccountsDepartmentAction? toggle = department.toggleAction;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: theme.spacing.md,
        runSpacing: theme.spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          AppButton.tertiary(
            leadingIcon: Icons.visibility_outlined,
            label: l10n.accountsDepartmentViewAction,
            tooltip: l10n.accountsDepartmentViewAction,
            dense: true,
            onPressed: () => unawaited(_openDetail(department)),
          ),
          if (canWrite && department.canEdit)
            AppButton.tertiary(
              leadingIcon: Icons.edit_outlined,
              label: l10n.commonEditActionLabel,
              tooltip: l10n.commonEditActionLabel,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openEdit(department)),
            ),
          if (canWrite && department.canClone)
            AppButton.tertiary(
              leadingIcon: Icons.copy_all_outlined,
              label: l10n.accountsDepartmentCloneAction,
              tooltip: l10n.accountsDepartmentCloneAction,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openCreate(cloneOf: department)),
            ),
          if (canWrite && toggle != null)
            AppButton.tertiary(
              leadingIcon: switch (toggle) {
                AccountsDepartmentAction.restore => Icons.restore_outlined,
                AccountsDepartmentAction.deactivate =>
                  Icons.pause_circle_outline,
                _ => Icons.check_circle_outline,
              },
              label: accountsDepartmentActionLabel(l10n, toggle),
              tooltip: accountsDepartmentActionLabel(l10n, toggle),
              dense: true,
              enabled: !_isMutating,
              color: toggle == AccountsDepartmentAction.deactivate
                  ? colors.error
                  : null,
              onPressed: () => unawaited(_applyAction(department, toggle)),
            ),
          if (canWrite && department.canArchive)
            AppButton.tertiary(
              leadingIcon: Icons.inventory_2_outlined,
              label: l10n.accountsDepartmentArchiveAction,
              tooltip: l10n.accountsDepartmentArchiveAction,
              dense: true,
              enabled: !_isMutating,
              color: colors.error,
              onPressed: () => unawaited(
                _applyAction(department, AccountsDepartmentAction.archive),
              ),
            ),
        ],
      ),
    );
  }

  static AppListTableColumn<AccountsDepartment> _textColumn({
    required String id,
    required String label,
    required String? Function(AccountsDepartment department) valueOf,
    double preferredWidth = 150,
  }) {
    return AppListTableColumn<AccountsDepartment>(
      id: id,
      label: label,
      preferredWidth: preferredWidth,
      cellBuilder: (_, AccountsDepartment department) => Text(
        valueOf(department) ?? accountsUnknownValue(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      sortComparator: (AccountsDepartment a, AccountsDepartment b) =>
          (valueOf(a) ?? '').compareTo(valueOf(b) ?? ''),
      exportValue: (AccountsDepartment department) => valueOf(department) ?? '',
    );
  }

  static AppListTableColumn<AccountsDepartment> _dateColumn({
    required String id,
    required String label,
    required DateTime? Function(AccountsDepartment department) valueOf,
  }) {
    return AppListTableColumn<AccountsDepartment>(
      id: id,
      label: label,
      preferredWidth: 130,
      cellBuilder: (BuildContext context, AccountsDepartment department) =>
          Text(accountsDate(context, valueOf(department))),
      sortComparator: (AccountsDepartment a, AccountsDepartment b) =>
          _compareDates(valueOf(a), valueOf(b)),
      exportValue: (AccountsDepartment department) =>
          valueOf(department)?.toIso8601String() ?? '',
    );
  }

  /// Optional columns: available in Settings, exports, and print, hidden until
  /// the operator enables them (specification marks these `Optional`).
  List<AppListTableColumn<AccountsDepartment>> _optionalColumns(
    AppLocalizations l10n,
  ) {
    return <AppListTableColumn<AccountsDepartment>>[
      AppListTableColumn<AccountsDepartment>(
        id: accountsDepartmentReferenceColumnId,
        label: l10n.accountsDepartmentReferenceColumn,
        preferredWidth: 150,
        cellBuilder: (_, AccountsDepartment department) => AppCopyableIdentifier(
          value:
              accountsPublicLabel(department.humanFriendlyId) ??
              accountsUnknownValue(),
        ),
        sortComparator: (AccountsDepartment a, AccountsDepartment b) =>
            a.humanFriendlyId.compareTo(b.humanFriendlyId),
        exportValue: (AccountsDepartment department) =>
            accountsPublicLabel(department.humanFriendlyId) ?? '',
      ),
      _dateColumn(
        id: accountsDepartmentEffectiveFromColumnId,
        label: l10n.accountsDepartmentEffectiveFromColumn,
        valueOf: (AccountsDepartment department) => department.effectiveFrom,
      ),
      _dateColumn(
        id: accountsDepartmentEffectiveToColumnId,
        label: l10n.accountsDepartmentEffectiveToColumn,
        valueOf: (AccountsDepartment department) => department.effectiveTo,
      ),
    ];
  }

  List<AppListTableColumn<AccountsDepartment>> _columns({
    required AppLocalizations l10n,
    required bool canWrite,
  }) {
    return <AppListTableColumn<AccountsDepartment>>[
      AppListTableColumn<AccountsDepartment>(
        id: accountsDepartmentCodeColumnId,
        label: l10n.accountsDepartmentCodeColumn,
        alwaysVisible: true,
        preferredWidth: 140,
        cellBuilder: (_, AccountsDepartment department) => Text(
          department.departmentCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsDepartment a, AccountsDepartment b) =>
            a.departmentCode.compareTo(b.departmentCode),
        exportValue: (AccountsDepartment department) =>
            department.departmentCode,
      ),
      AppListTableColumn<AccountsDepartment>(
        id: accountsDepartmentNameColumnId,
        label: l10n.accountsDepartmentNameColumn,
        alwaysVisible: true,
        preferredWidth: 180,
        cellBuilder: (_, AccountsDepartment department) => Text(
          department.departmentName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsDepartment a, AccountsDepartment b) =>
            a.departmentName.compareTo(b.departmentName),
        exportValue: (AccountsDepartment department) =>
            department.departmentName,
      ),
      _textColumn(
        id: accountsDepartmentCostCentreCodeColumnId,
        label: l10n.accountsDepartmentCostCentreCodeColumn,
        valueOf: (AccountsDepartment department) => department.costCentreCode,
        preferredWidth: 140,
      ),
      _textColumn(
        id: accountsDepartmentCostCentreNameColumnId,
        label: l10n.accountsDepartmentCostCentreNameColumn,
        valueOf: (AccountsDepartment department) => department.costCentreName,
        preferredWidth: 180,
      ),
      _textColumn(
        id: accountsDepartmentParentColumnId,
        label: l10n.accountsDepartmentParentColumn,
        valueOf: (AccountsDepartment department) => department.parent,
      ),
      _textColumn(
        id: accountsDepartmentFacilityColumnId,
        label: l10n.accountsDepartmentFacilityColumn,
        valueOf: (AccountsDepartment department) => department.facility,
        preferredWidth: 160,
      ),
      _textColumn(
        id: accountsDepartmentManagerColumnId,
        label: l10n.accountsDepartmentManagerColumn,
        valueOf: (AccountsDepartment department) => department.manager,
      ),
      _textColumn(
        id: accountsDepartmentRevenueAccountColumnId,
        label: l10n.accountsDepartmentRevenueAccountColumn,
        valueOf: (AccountsDepartment department) =>
            department.defaultRevenueAccount,
        preferredWidth: 190,
      ),
      _textColumn(
        id: accountsDepartmentExpenseAccountColumnId,
        label: l10n.accountsDepartmentExpenseAccountColumn,
        valueOf: (AccountsDepartment department) =>
            department.defaultExpenseAccount,
        preferredWidth: 190,
      ),
      _textColumn(
        id: accountsDepartmentBudgetOwnerColumnId,
        label: l10n.accountsDepartmentBudgetOwnerColumn,
        valueOf: (AccountsDepartment department) => department.budgetOwner,
      ),
      AppListTableColumn<AccountsDepartment>(
        id: accountsDepartmentStatusColumnId,
        label: l10n.accountsDepartmentStatusColumn,
        alwaysVisible: true,
        preferredWidth: 130,
        cellBuilder: (_, AccountsDepartment department) =>
            AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: accountsDepartmentStatusLabel(l10n, department.status),
                tone: accountsDepartmentStatusTone(department.status),
                icon: accountsDepartmentStatusIcon(department.status),
              ),
            ),
        sortComparator: (AccountsDepartment a, AccountsDepartment b) =>
            a.status.index.compareTo(b.status.index),
        exportValue: (AccountsDepartment department) =>
            accountsDepartmentStatusLabel(l10n, department.status),
      ),
      if (canWrite)
        AppListTableColumn<AccountsDepartment>(
          id: accountsDepartmentActionsColumnId,
          label: l10n.accountsDepartmentActionsColumn,
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

  /// Filter choices in stable label order so the lists never reshuffle between
  /// loads.
  static List<MapEntry<String, String>> _sorted(Map<String, String> source) {
    final List<MapEntry<String, String>> entries = source.entries.toList(
      growable: false,
    );
    entries.sort(
      (MapEntry<String, String> a, MapEntry<String, String> b) =>
          a.value.toLowerCase().compareTo(b.value.toLowerCase()),
    );
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteAccountsDepartments(accessPolicy);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
    final List<AppListTableColumn<AccountsDepartment>> columns = _columns(
      l10n: l10n,
      canWrite: canWrite,
    );
    final List<AppListTableColumn<AccountsDepartment>> optionalColumns =
        _optionalColumns(l10n);

    // Mutations elsewhere (detail dialog, other panels) invalidate this list.
    ref.listen<int>(accountsDepartmentRevisionProvider, (_, _) {
      unawaited(_reload());
    });

    return AppListTable<AccountsDepartment>(
      page: _page,
      rowsVersion: _revision,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      itemKeyBuilder: (AccountsDepartment department) =>
          ValueKey<String>(department.humanFriendlyId),
      initialSortColumnKey: accountsDepartmentCodeColumnId,
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: accountsDepartmentsTableSettingsKey,
      columnWidthStorageKey: accountsDepartmentsColumnWidthKey,
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
      exportConfig: AppListTableExportConfig<AccountsDepartment>(
        fileNameStem: 'accounts_departments_and_cost_centres',
        sheetName: l10n.accountsDepartmentsLabel,
        dateOf: (AccountsDepartment department) => department.effectiveFrom,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      enablePrint: true,
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      onPrint: (List<AccountsDepartment> items) =>
          printAccountsListTable<AccountsDepartment>(
            ref: ref,
            context: context,
            title: l10n.accountsDepartmentsLabel,
            // Print offers the full source-of-truth column inventory, not only
            // the columns currently visible.
            columns: <AppListTableColumn<AccountsDepartment>>[
              ...columns,
              ...optionalColumns,
            ],
            items: items,
            emptyText: l10n.accountsDepartmentsEmpty,
          ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      onRowSelected: (AccountsDepartment department) =>
          unawaited(_openDetail(department)),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.accountsDepartmentsEmpty,
        body: l10n.accountsDepartmentsEmptyBody,
      ),
      search: AppListTableSearch<AccountsDepartment>(
        controller: _searchController,
        semanticLabel: l10n.accountsDepartmentsSearchHint,
        hintText: l10n.accountsDepartmentsSearchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsDepartment department, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          final String reference =
              accountsPublicLabel(department.humanFriendlyId) ?? '';
          return reference.toLowerCase().contains(needle) ||
              department.departmentCode.toLowerCase().contains(needle) ||
              department.departmentName.toLowerCase().contains(needle) ||
              department.costCentreCode.toLowerCase().contains(needle) ||
              department.costCentreName.toLowerCase().contains(needle);
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
        dateFilterLabel: l10n.accountsDepartmentDateRangeFilterLabel,
        dateFromLabel: l10n.accountsDepartmentEffectiveFromColumn,
        dateToLabel: l10n.accountsDepartmentEffectiveToColumn,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _departmentCodeFilterKey,
            label: l10n.accountsDepartmentCodeColumn,
            hintText: l10n.accountsDepartmentCodeColumn,
            icon: Icons.tag_outlined,
          ),
          AppSearchBarTextFilter(
            key: _departmentNameFilterKey,
            label: l10n.accountsDepartmentNameColumn,
            hintText: l10n.accountsDepartmentNameColumn,
            icon: Icons.badge_outlined,
          ),
          AppSearchBarTextFilter(
            key: _costCentreNameFilterKey,
            label: l10n.accountsDepartmentCostCentreNameColumn,
            hintText: l10n.accountsDepartmentCostCentreNameColumn,
            icon: Icons.account_balance_wallet_outlined,
          ),
          AppSearchBarTextFilter(
            key: _revenueAccountFilterKey,
            label: l10n.accountsDepartmentRevenueAccountColumn,
            hintText: l10n.accountsDepartmentRevenueAccountColumn,
            icon: Icons.trending_up_outlined,
          ),
          AppSearchBarTextFilter(
            key: _expenseAccountFilterKey,
            label: l10n.accountsDepartmentExpenseAccountColumn,
            hintText: l10n.accountsDepartmentExpenseAccountColumn,
            icon: Icons.trending_down_outlined,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.accountsDepartmentStatusColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsDepartmentStatus status
                  in AccountsDepartmentStatus.values)
                AppSearchBarFilterChoice(
                  value: status.wireValue,
                  label: accountsDepartmentStatusLabel(l10n, status),
                  icon: accountsDepartmentStatusIcon(status),
                ),
            ],
          ),
          // Offered only where the caller's ABAC scope actually spans more than
          // one facility; a single-facility operator gets no dead control.
          if (_facilityChoices.length > 1)
            AppSearchBarFilterGroup(
              key: _facilityFilterKey,
              label: l10n.accountsDepartmentFacilityFilterLabel,
              allLabel: AccountsStrings.allFields,
              choices: <AppSearchBarFilterChoice>[
                for (final MapEntry<String, String> facility
                    in _sorted(_facilityChoices))
                  AppSearchBarFilterChoice(
                    value: facility.key,
                    label: facility.value,
                    icon: Icons.apartment_outlined,
                  ),
              ],
            ),
          if (_costCentreChoices.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _costCentreFilterKey,
              label: l10n.accountsDepartmentCostCentreFilterLabel,
              allLabel: AccountsStrings.allFields,
              choices: <AppSearchBarFilterChoice>[
                for (final MapEntry<String, String> centre
                    in _sorted(_costCentreChoices))
                  AppSearchBarFilterChoice(
                    value: centre.key,
                    label: centre.value,
                    icon: Icons.account_tree_outlined,
                  ),
              ],
            ),
          if (_ownerChoices.isNotEmpty)
            AppSearchBarFilterGroup(
              key: _ownerFilterKey,
              label: l10n.accountsDepartmentOwnerFilterLabel,
              allLabel: AccountsStrings.allFields,
              choices: <AppSearchBarFilterChoice>[
                for (final MapEntry<String, String> owner
                    in _sorted(_ownerChoices))
                  AppSearchBarFilterChoice(
                    value: owner.key,
                    label: owner.value,
                    icon: Icons.person_outline,
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
                  label: l10n.accountsDepartmentNewRecordAction,
                  icon: Icons.add_outlined,
                  enabled: !_isMutating,
                  onPressed: () => unawaited(_openCreate()),
                ),
                AppSearchBarAction(
                  label: l10n.accountsDepartmentBulkActivateAction,
                  icon: Icons.check_circle_outline,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsDepartmentAction.activate),
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsDepartmentAction.activate),
                  ),
                ),
                AppSearchBarAction(
                  label: l10n.accountsDepartmentBulkDeactivateAction,
                  icon: Icons.pause_circle_outline,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsDepartmentAction.deactivate),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsDepartmentAction.deactivate),
                  ),
                ),
                AppSearchBarAction(
                  label: l10n.accountsDepartmentBulkArchiveAction,
                  icon: Icons.inventory_2_outlined,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsDepartmentAction.archive),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsDepartmentAction.archive),
                  ),
                ),
              ]
            : const <AppSearchBarAction>[],
      ),
      columns: columns,
      columnChoices: optionalColumns,
      mobileItemBuilder: (BuildContext context, AccountsDepartment department) {
        return AppListTableMobileItem(
          title: department.departmentName,
          caption: l10n.accountsDepartmentMobileCaption(
            department.departmentCode,
            department.costCentreCode,
          ),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: department.costCentreName,
              icon: Icons.account_balance_wallet_outlined,
            ),
            AppListTableMobileMeta(
              label: accountsDepartmentStatusLabel(l10n, department.status),
              icon: accountsDepartmentStatusIcon(department.status),
            ),
          ],
        );
      },
    );
  }

  bool _hasEligible(AccountsDepartmentAction action) {
    return _page.items.any(
      (AccountsDepartment department) => _supportsAction(department, action),
    );
  }
}
