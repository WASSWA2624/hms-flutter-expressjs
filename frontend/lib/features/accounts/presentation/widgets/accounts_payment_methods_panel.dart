import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_payment_method_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_payment_method.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_payment_method_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

const String accountsPaymentMethodsTableSettingsKey =
    'accounts_payment_methods_v1';
const String accountsPaymentMethodsColumnWidthKey =
    'accounts_payment_methods_cw_v1';

const String accountsPaymentMethodReferenceColumnId = 'reference';
const String accountsPaymentMethodCodeColumnId = 'method_code';
const String accountsPaymentMethodNameColumnId = 'method_name';
const String accountsPaymentMethodTypeColumnId = 'method_type';
const String accountsPaymentMethodDirectionColumnId = 'incoming_and_outgoing';
const String accountsPaymentMethodProviderColumnId = 'provider';
const String accountsPaymentMethodSettlementAccountColumnId =
    'settlement_account';
const String accountsPaymentMethodClearingAccountColumnId = 'clearing_account';
const String accountsPaymentMethodRequiresReferenceColumnId =
    'requires_external_reference';
const String accountsPaymentMethodRequiresApprovalColumnId =
    'requires_approval';
const String accountsPaymentMethodFeeRuleColumnId = 'fee_rule';
const String accountsPaymentMethodFacilityScopeColumnId = 'facility_scope';
const String accountsPaymentMethodEffectiveFromColumnId = 'effective_from';
const String accountsPaymentMethodEffectiveToColumnId = 'effective_to';
const String accountsPaymentMethodStatusColumnId = 'status';
const String accountsPaymentMethodActionsColumnId = 'actions';

/// The 14 documented columns in source-of-truth order.
///
/// Settings and export preserve this order; visibility follows
/// [accountsPaymentMethodOptionalColumnIds].
const List<String> accountsPaymentMethodColumnIds = <String>[
  accountsPaymentMethodCodeColumnId,
  accountsPaymentMethodNameColumnId,
  accountsPaymentMethodTypeColumnId,
  accountsPaymentMethodDirectionColumnId,
  accountsPaymentMethodProviderColumnId,
  accountsPaymentMethodSettlementAccountColumnId,
  accountsPaymentMethodClearingAccountColumnId,
  accountsPaymentMethodRequiresReferenceColumnId,
  accountsPaymentMethodRequiresApprovalColumnId,
  accountsPaymentMethodFeeRuleColumnId,
  accountsPaymentMethodFacilityScopeColumnId,
  accountsPaymentMethodEffectiveFromColumnId,
  accountsPaymentMethodEffectiveToColumnId,
  accountsPaymentMethodStatusColumnId,
];

/// Columns the specification marks `Optional`: selectable and exportable, but
/// hidden until the operator turns them on in Settings.
///
/// The baseline human-friendly Reference column joins them so the default view
/// stays the source-of-truth default set.
const List<String> accountsPaymentMethodOptionalColumnIds = <String>[
  accountsPaymentMethodReferenceColumnId,
  accountsPaymentMethodFacilityScopeColumnId,
  accountsPaymentMethodEffectiveFromColumnId,
  accountsPaymentMethodEffectiveToColumnId,
];

/// `Accounts & Finance → Setup & Controls → Payment Methods`
/// (`?section=payment-methods`).
class AccountsPaymentMethodsPanel extends ConsumerStatefulWidget {
  const AccountsPaymentMethodsPanel({super.key});

  @override
  ConsumerState<AccountsPaymentMethodsPanel> createState() =>
      _AccountsPaymentMethodsPanelState();
}

class _AccountsPaymentMethodsPanelState
    extends ConsumerState<AccountsPaymentMethodsPanel> {
  static const String _statusFilterKey = 'status';
  static const String _facilityFilterKey = 'facility';
  static const String _methodTypeFilterKey = 'method_type';
  static const String _directionFilterKey = 'direction';
  static const String _requiresReferenceFilterKey = 'requires_reference';
  static const String _requiresApprovalFilterKey = 'requires_approval';
  static const String _methodCodeFilterKey = 'method_code';
  static const String _methodNameFilterKey = 'method_name';
  static const String _settlementAccountFilterKey = 'settlement_account';
  static const String _clearingAccountFilterKey = 'clearing_account';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<AccountsPaymentMethod>
  _columnController =
      AppListTableColumnVisibilityController<AccountsPaymentMethod>(
        storageKey: accountsPaymentMethodsTableSettingsKey,
      );

  AppPage<AccountsPaymentMethod> _page = const AppPage<AccountsPaymentMethod>(
    items: <AccountsPaymentMethod>[],
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

  static bool? _triState(String? raw) {
    return switch ((raw ?? '').trim()) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }

  AccountsPaymentMethodQuery get _query {
    final AccountsPaymentMethodStatus? status =
        AccountsPaymentMethodStatus.fromWire(
          _filterValue.option(_statusFilterKey),
        );
    final AccountsPaymentMethodType? type = AccountsPaymentMethodType.fromWire(
      _filterValue.option(_methodTypeFilterKey),
    );
    final AccountsPaymentMethodDirection? direction =
        AccountsPaymentMethodDirection.fromWire(
          _filterValue.option(_directionFilterKey),
        );
    return AccountsPaymentMethodQuery(
      search: _searchController.text.trim(),
      statuses: status == null
          ? const <AccountsPaymentMethodStatus>{}
          : <AccountsPaymentMethodStatus>{status},
      methodTypes: type == null
          ? const <AccountsPaymentMethodType>{}
          : <AccountsPaymentMethodType>{type},
      directions: direction == null
          ? const <AccountsPaymentMethodDirection>{}
          : <AccountsPaymentMethodDirection>{direction},
      methodCode: (_filterValue.text(_methodCodeFilterKey) ?? '').trim(),
      methodName: (_filterValue.text(_methodNameFilterKey) ?? '').trim(),
      facilityId: (_filterValue.option(_facilityFilterKey) ?? '').trim(),
      settlementAccountId: (_filterValue.text(_settlementAccountFilterKey) ?? '')
          .trim(),
      clearingAccountId: (_filterValue.text(_clearingAccountFilterKey) ?? '')
          .trim(),
      requiresExternalReference: _triState(
        _filterValue.option(_requiresReferenceFilterKey),
      ),
      requiresApproval: _triState(
        _filterValue.option(_requiresApprovalFilterKey),
      ),
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

    final AccountsPaymentMethodQuery query = _query;
    final Result<AppPage<AccountsPaymentMethod>> result = await ref
        .read(accountsPaymentMethodRepositoryProvider)
        .listPaymentMethods(query);

    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<AccountsPaymentMethod> page) {
        setState(() {
          _page = page;
          _loading = false;
          _revision++;
          for (final AccountsPaymentMethod method in page.items) {
            final String reference = (method.facilityHumanFriendlyId ?? '')
                .trim();
            final String label = (method.facilityScope ?? '').trim();
            if (reference.isNotEmpty && label.isNotEmpty) {
              _facilityChoices[reference] = label;
            }
          }
        });
        // Badge from the server total when narrowed; otherwise defer to the
        // workspace summary so it never reflects only the painted page.
        ref
                .read<StateController<int?>>(
                  accountsPaymentMethodCountProvider.notifier,
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

  Future<void> _openCreate({AccountsPaymentMethod? cloneOf}) async {
    final bool saved = await showAccountsPaymentMethodDialog(
      context: context,
      ref: ref,
      mode: cloneOf == null
          ? AccountsPaymentMethodDialogMode.create
          : AccountsPaymentMethodDialogMode.clone,
      source: cloneOf,
    );
    if (saved && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  Future<void> _openEdit(AccountsPaymentMethod method) async {
    if (!method.canEdit) {
      return;
    }
    final bool saved = await showAccountsPaymentMethodDialog(
      context: context,
      ref: ref,
      mode: AccountsPaymentMethodDialogMode.edit,
      source: method,
    );
    if (saved && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  Future<void> _openDetail(AccountsPaymentMethod method) async {
    await showAccountsPaymentMethodDetail(
      context: context,
      ref: ref,
      method: method,
    );
  }

  Future<void> _applyAction(
    AccountsPaymentMethod method,
    AccountsPaymentMethodAction action,
  ) async {
    final bool applied = await confirmAccountsPaymentMethodAction(
      context: context,
      ref: ref,
      method: method,
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
  Future<void> _applyBulkAction(AccountsPaymentMethodAction action) async {
    final List<AccountsPaymentMethod> eligible = _page.items
        .where((AccountsPaymentMethod method) => _supportsAction(method, action))
        .toList(growable: false);
    if (eligible.isEmpty) {
      return;
    }

    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: _bulkTitle(l10n, action),
        body: l10n.accountsPaymentMethodBulkConfirmBody(eligible.length),
        submitLabel: accountsPaymentMethodActionLabel(l10n, action),
        destructive: action != AccountsPaymentMethodAction.activate,
        icon: const Icon(Icons.playlist_add_check_outlined),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isMutating = true);
    int failed = 0;
    for (final AccountsPaymentMethod method in eligible) {
      final Result<AccountsPaymentMethod> result = await ref
          .read(accountsPaymentMethodRepositoryProvider)
          .applyAction(method.humanFriendlyId, action, version: method.version);
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
              accountsPaymentMethodRevisionProvider.notifier,
            )
            .state++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? AccountsStrings.saved
              : l10n.accountsPaymentMethodBulkPartialFailure(failed),
        ),
      ),
    );
    await _reload();
  }

  static bool _supportsAction(
    AccountsPaymentMethod method,
    AccountsPaymentMethodAction action,
  ) {
    return switch (action) {
      AccountsPaymentMethodAction.activate => method.canActivate,
      AccountsPaymentMethodAction.deactivate => method.canDeactivate,
      AccountsPaymentMethodAction.archive => method.canArchive,
      AccountsPaymentMethodAction.restore => method.canRestore,
    };
  }

  static String _bulkTitle(
    AppLocalizations l10n,
    AccountsPaymentMethodAction action,
  ) {
    return switch (action) {
      AccountsPaymentMethodAction.activate =>
        l10n.accountsPaymentMethodBulkActivateAction,
      AccountsPaymentMethodAction.deactivate =>
        l10n.accountsPaymentMethodBulkDeactivateAction,
      AccountsPaymentMethodAction.archive =>
        l10n.accountsPaymentMethodBulkArchiveAction,
      AccountsPaymentMethodAction.restore =>
        l10n.accountsPaymentMethodRestoreAction,
    };
  }

  void _notifySaved() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AccountsStrings.saved)));
  }

  Widget _actionsCell(BuildContext context, AccountsPaymentMethod method) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final bool canWrite = canWriteAccountsPaymentMethods(
      ref.watch(appAccessPolicyProvider),
    );
    final AccountsPaymentMethodAction? toggle = method.toggleAction;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: theme.spacing.md,
        runSpacing: theme.spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          AppButton.tertiary(
            leadingIcon: Icons.visibility_outlined,
            label: l10n.accountsPaymentMethodViewAction,
            tooltip: l10n.accountsPaymentMethodViewAction,
            dense: true,
            onPressed: () => unawaited(_openDetail(method)),
          ),
          if (canWrite && method.canEdit)
            AppButton.tertiary(
              leadingIcon: Icons.edit_outlined,
              label: l10n.commonEditActionLabel,
              tooltip: l10n.commonEditActionLabel,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openEdit(method)),
            ),
          if (canWrite && method.canClone)
            AppButton.tertiary(
              leadingIcon: Icons.copy_all_outlined,
              label: l10n.accountsPaymentMethodCloneAction,
              tooltip: l10n.accountsPaymentMethodCloneAction,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openCreate(cloneOf: method)),
            ),
          if (canWrite && toggle != null)
            AppButton.tertiary(
              leadingIcon: switch (toggle) {
                AccountsPaymentMethodAction.restore => Icons.restore_outlined,
                AccountsPaymentMethodAction.deactivate =>
                  Icons.pause_circle_outline,
                _ => Icons.check_circle_outline,
              },
              label: accountsPaymentMethodActionLabel(l10n, toggle),
              tooltip: accountsPaymentMethodActionLabel(l10n, toggle),
              dense: true,
              enabled: !_isMutating,
              color: toggle == AccountsPaymentMethodAction.deactivate
                  ? colors.error
                  : null,
              onPressed: () => unawaited(_applyAction(method, toggle)),
            ),
          if (canWrite && method.canArchive)
            AppButton.tertiary(
              leadingIcon: Icons.inventory_2_outlined,
              label: l10n.accountsPaymentMethodArchiveAction,
              tooltip: l10n.accountsPaymentMethodArchiveAction,
              dense: true,
              enabled: !_isMutating,
              color: colors.error,
              onPressed: () => unawaited(
                _applyAction(method, AccountsPaymentMethodAction.archive),
              ),
            ),
        ],
      ),
    );
  }

  static AppListTableColumn<AccountsPaymentMethod> _textColumn({
    required String id,
    required String label,
    required String? Function(AccountsPaymentMethod method) valueOf,
    double preferredWidth = 150,
  }) {
    return AppListTableColumn<AccountsPaymentMethod>(
      id: id,
      label: label,
      preferredWidth: preferredWidth,
      cellBuilder: (_, AccountsPaymentMethod method) => Text(
        valueOf(method) ?? accountsUnknownValue(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      sortComparator: (AccountsPaymentMethod a, AccountsPaymentMethod b) =>
          (valueOf(a) ?? '').compareTo(valueOf(b) ?? ''),
      exportValue: (AccountsPaymentMethod method) => valueOf(method) ?? '',
    );
  }

  static AppListTableColumn<AccountsPaymentMethod> _dateColumn({
    required String id,
    required String label,
    required DateTime? Function(AccountsPaymentMethod method) valueOf,
  }) {
    return AppListTableColumn<AccountsPaymentMethod>(
      id: id,
      label: label,
      preferredWidth: 130,
      cellBuilder: (BuildContext context, AccountsPaymentMethod method) =>
          Text(accountsDate(context, valueOf(method))),
      sortComparator: (AccountsPaymentMethod a, AccountsPaymentMethod b) =>
          _compareDates(valueOf(a), valueOf(b)),
      exportValue: (AccountsPaymentMethod method) =>
          valueOf(method)?.toIso8601String() ?? '',
    );
  }

  /// Yes/No chip for a requirement flag; never a raw boolean.
  AppListTableColumn<AccountsPaymentMethod> _flagColumn({
    required String id,
    required String label,
    required AppLocalizations l10n,
    required bool Function(AccountsPaymentMethod method) valueOf,
  }) {
    return AppListTableColumn<AccountsPaymentMethod>(
      id: id,
      label: label,
      preferredWidth: 170,
      cellBuilder: (_, AccountsPaymentMethod method) => AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: accountsPaymentMethodFlagLabel(l10n, valueOf(method)),
          tone: valueOf(method)
              ? AppWorkspaceStatusTone.info
              : AppWorkspaceStatusTone.neutral,
          icon: valueOf(method)
              ? Icons.check_circle_outline
              : Icons.remove_circle_outline,
        ),
      ),
      sortComparator: (AccountsPaymentMethod a, AccountsPaymentMethod b) =>
          valueOf(a) == valueOf(b) ? 0 : (valueOf(a) ? -1 : 1),
      exportValue: (AccountsPaymentMethod method) =>
          accountsPaymentMethodFlagLabel(l10n, valueOf(method)),
    );
  }

  /// Optional columns: available in Settings, exports, and print, hidden until
  /// the operator enables them (specification marks these `Optional`).
  List<AppListTableColumn<AccountsPaymentMethod>> _optionalColumns(
    AppLocalizations l10n,
  ) {
    return <AppListTableColumn<AccountsPaymentMethod>>[
      AppListTableColumn<AccountsPaymentMethod>(
        id: accountsPaymentMethodReferenceColumnId,
        label: l10n.accountsPaymentMethodReferenceColumn,
        preferredWidth: 150,
        cellBuilder: (_, AccountsPaymentMethod method) => AppCopyableIdentifier(
          value:
              accountsPublicLabel(method.humanFriendlyId) ??
              accountsUnknownValue(),
        ),
        sortComparator: (AccountsPaymentMethod a, AccountsPaymentMethod b) =>
            a.humanFriendlyId.compareTo(b.humanFriendlyId),
        exportValue: (AccountsPaymentMethod method) =>
            accountsPublicLabel(method.humanFriendlyId) ?? '',
      ),
      _textColumn(
        id: accountsPaymentMethodFacilityScopeColumnId,
        label: l10n.accountsPaymentMethodFacilityScopeColumn,
        valueOf: (AccountsPaymentMethod method) => method.facilityScope,
        preferredWidth: 160,
      ),
      _dateColumn(
        id: accountsPaymentMethodEffectiveFromColumnId,
        label: l10n.accountsPaymentMethodEffectiveFromColumn,
        valueOf: (AccountsPaymentMethod method) => method.effectiveFrom,
      ),
      _dateColumn(
        id: accountsPaymentMethodEffectiveToColumnId,
        label: l10n.accountsPaymentMethodEffectiveToColumn,
        valueOf: (AccountsPaymentMethod method) => method.effectiveTo,
      ),
    ];
  }

  List<AppListTableColumn<AccountsPaymentMethod>> _columns({
    required AppLocalizations l10n,
    required bool canWrite,
  }) {
    return <AppListTableColumn<AccountsPaymentMethod>>[
      AppListTableColumn<AccountsPaymentMethod>(
        id: accountsPaymentMethodCodeColumnId,
        label: l10n.accountsPaymentMethodCodeColumn,
        alwaysVisible: true,
        preferredWidth: 140,
        cellBuilder: (_, AccountsPaymentMethod method) => Text(
          method.methodCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsPaymentMethod a, AccountsPaymentMethod b) =>
            a.methodCode.compareTo(b.methodCode),
        exportValue: (AccountsPaymentMethod method) => method.methodCode,
      ),
      AppListTableColumn<AccountsPaymentMethod>(
        id: accountsPaymentMethodNameColumnId,
        label: l10n.accountsPaymentMethodNameColumn,
        alwaysVisible: true,
        preferredWidth: 180,
        cellBuilder: (_, AccountsPaymentMethod method) => Text(
          method.methodName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator: (AccountsPaymentMethod a, AccountsPaymentMethod b) =>
            a.methodName.compareTo(b.methodName),
        exportValue: (AccountsPaymentMethod method) => method.methodName,
      ),
      // Localized taxonomy label; the raw enum never reaches the table.
      _textColumn(
        id: accountsPaymentMethodTypeColumnId,
        label: l10n.accountsPaymentMethodTypeColumn,
        valueOf: (AccountsPaymentMethod method) =>
            accountsPaymentMethodTypeLabel(l10n, method.methodType),
      ),
      _textColumn(
        id: accountsPaymentMethodDirectionColumnId,
        label: l10n.accountsPaymentMethodDirectionColumn,
        valueOf: (AccountsPaymentMethod method) =>
            accountsPaymentMethodDirectionLabel(l10n, method.direction),
        preferredWidth: 160,
      ),
      _textColumn(
        id: accountsPaymentMethodProviderColumnId,
        label: l10n.accountsPaymentMethodProviderColumn,
        valueOf: (AccountsPaymentMethod method) => method.provider,
      ),
      _textColumn(
        id: accountsPaymentMethodSettlementAccountColumnId,
        label: l10n.accountsPaymentMethodSettlementAccountColumn,
        valueOf: (AccountsPaymentMethod method) => method.settlementAccount,
        preferredWidth: 190,
      ),
      _textColumn(
        id: accountsPaymentMethodClearingAccountColumnId,
        label: l10n.accountsPaymentMethodClearingAccountColumn,
        valueOf: (AccountsPaymentMethod method) => method.clearingAccount,
        preferredWidth: 190,
      ),
      _flagColumn(
        id: accountsPaymentMethodRequiresReferenceColumnId,
        label: l10n.accountsPaymentMethodRequiresReferenceColumn,
        l10n: l10n,
        valueOf: (AccountsPaymentMethod method) =>
            method.requiresExternalReference,
      ),
      _flagColumn(
        id: accountsPaymentMethodRequiresApprovalColumnId,
        label: l10n.accountsPaymentMethodRequiresApprovalColumn,
        l10n: l10n,
        valueOf: (AccountsPaymentMethod method) => method.requiresApproval,
      ),
      _textColumn(
        id: accountsPaymentMethodFeeRuleColumnId,
        label: l10n.accountsPaymentMethodFeeRuleColumn,
        valueOf: (AccountsPaymentMethod method) => method.feeRule,
      ),
      AppListTableColumn<AccountsPaymentMethod>(
        id: accountsPaymentMethodStatusColumnId,
        label: l10n.accountsPaymentMethodStatusColumn,
        alwaysVisible: true,
        preferredWidth: 130,
        cellBuilder: (_, AccountsPaymentMethod method) =>
            AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: accountsPaymentMethodStatusLabel(l10n, method.status),
                tone: accountsPaymentMethodStatusTone(method.status),
                icon: accountsPaymentMethodStatusIcon(method.status),
              ),
            ),
        sortComparator: (AccountsPaymentMethod a, AccountsPaymentMethod b) =>
            a.status.index.compareTo(b.status.index),
        exportValue: (AccountsPaymentMethod method) =>
            accountsPaymentMethodStatusLabel(l10n, method.status),
      ),
      if (canWrite)
        AppListTableColumn<AccountsPaymentMethod>(
          id: accountsPaymentMethodActionsColumnId,
          label: l10n.accountsPaymentMethodActionsColumn,
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteAccountsPaymentMethods(accessPolicy);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
    final List<AppListTableColumn<AccountsPaymentMethod>> columns = _columns(
      l10n: l10n,
      canWrite: canWrite,
    );
    final List<AppListTableColumn<AccountsPaymentMethod>> optionalColumns =
        _optionalColumns(l10n);

    // Mutations elsewhere (detail dialog, other panels) invalidate this list.
    ref.listen<int>(accountsPaymentMethodRevisionProvider, (_, _) {
      unawaited(_reload());
    });

    return AppListTable<AccountsPaymentMethod>(
      page: _page,
      rowsVersion: _revision,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      itemKeyBuilder: (AccountsPaymentMethod method) =>
          ValueKey<String>(method.humanFriendlyId),
      initialSortColumnKey: accountsPaymentMethodCodeColumnId,
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: accountsPaymentMethodsTableSettingsKey,
      columnWidthStorageKey: accountsPaymentMethodsColumnWidthKey,
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
      exportConfig: AppListTableExportConfig<AccountsPaymentMethod>(
        fileNameStem: 'accounts_payment_methods',
        sheetName: l10n.accountsPaymentMethodsLabel,
        dateOf: (AccountsPaymentMethod method) => method.effectiveFrom,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      enablePrint: true,
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      onPrint: (List<AccountsPaymentMethod> items) =>
          printAccountsListTable<AccountsPaymentMethod>(
            ref: ref,
            context: context,
            title: l10n.accountsPaymentMethodsLabel,
            // Print offers the full source-of-truth column inventory, not only
            // the columns currently visible.
            columns: <AppListTableColumn<AccountsPaymentMethod>>[
              ...columns,
              ...optionalColumns,
            ],
            items: items,
            emptyText: l10n.accountsPaymentMethodsEmpty,
          ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      onRowSelected: (AccountsPaymentMethod method) =>
          unawaited(_openDetail(method)),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.accountsPaymentMethodsEmpty,
        body: l10n.accountsPaymentMethodsEmptyBody,
      ),
      search: AppListTableSearch<AccountsPaymentMethod>(
        controller: _searchController,
        semanticLabel: l10n.accountsPaymentMethodsSearchHint,
        hintText: l10n.accountsPaymentMethodsSearchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsPaymentMethod method, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          final String reference =
              accountsPublicLabel(method.humanFriendlyId) ?? '';
          return reference.toLowerCase().contains(needle) ||
              method.methodCode.toLowerCase().contains(needle) ||
              method.methodName.toLowerCase().contains(needle) ||
              (method.provider ?? '').toLowerCase().contains(needle);
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
        dateFilterLabel: l10n.accountsPaymentMethodDateRangeFilterLabel,
        dateFromLabel: l10n.accountsPaymentMethodEffectiveFromColumn,
        dateToLabel: l10n.accountsPaymentMethodEffectiveToColumn,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _methodCodeFilterKey,
            label: l10n.accountsPaymentMethodCodeColumn,
            hintText: l10n.accountsPaymentMethodCodeColumn,
            icon: Icons.tag_outlined,
          ),
          AppSearchBarTextFilter(
            key: _methodNameFilterKey,
            label: l10n.accountsPaymentMethodNameColumn,
            hintText: l10n.accountsPaymentMethodNameColumn,
            icon: Icons.payments_outlined,
          ),
          AppSearchBarTextFilter(
            key: _settlementAccountFilterKey,
            label: l10n.accountsPaymentMethodSettlementAccountColumn,
            hintText: l10n.accountsPaymentMethodSettlementAccountColumn,
            icon: Icons.account_balance_outlined,
          ),
          AppSearchBarTextFilter(
            key: _clearingAccountFilterKey,
            label: l10n.accountsPaymentMethodClearingAccountColumn,
            hintText: l10n.accountsPaymentMethodClearingAccountColumn,
            icon: Icons.compare_arrows_outlined,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.accountsPaymentMethodStatusColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsPaymentMethodStatus status
                  in AccountsPaymentMethodStatus.values)
                AppSearchBarFilterChoice(
                  value: status.wireValue,
                  label: accountsPaymentMethodStatusLabel(l10n, status),
                  icon: accountsPaymentMethodStatusIcon(status),
                ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _methodTypeFilterKey,
            label: l10n.accountsPaymentMethodTypeColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsPaymentMethodType type
                  in AccountsPaymentMethodType.values)
                AppSearchBarFilterChoice(
                  value: type.wireValue,
                  label: accountsPaymentMethodTypeLabel(l10n, type),
                  icon: Icons.payments_outlined,
                ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _directionFilterKey,
            label: l10n.accountsPaymentMethodDirectionColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsPaymentMethodDirection direction
                  in AccountsPaymentMethodDirection.values)
                AppSearchBarFilterChoice(
                  value: direction.wireValue,
                  label: accountsPaymentMethodDirectionLabel(l10n, direction),
                  icon: Icons.swap_horiz_outlined,
                ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _requiresReferenceFilterKey,
            label: l10n.accountsPaymentMethodRequiresReferenceColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'true',
                label: l10n.accountsPaymentMethodYes,
                icon: Icons.check_circle_outline,
              ),
              AppSearchBarFilterChoice(
                value: 'false',
                label: l10n.accountsPaymentMethodNo,
                icon: Icons.remove_circle_outline,
              ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _requiresApprovalFilterKey,
            label: l10n.accountsPaymentMethodRequiresApprovalColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'true',
                label: l10n.accountsPaymentMethodYes,
                icon: Icons.check_circle_outline,
              ),
              AppSearchBarFilterChoice(
                value: 'false',
                label: l10n.accountsPaymentMethodNo,
                icon: Icons.remove_circle_outline,
              ),
            ],
          ),
          // Offered only where the caller's ABAC scope actually spans more than
          // one facility; a single-facility operator gets no dead control.
          if (_facilityChoices.length > 1)
            AppSearchBarFilterGroup(
              key: _facilityFilterKey,
              label: l10n.accountsPaymentMethodFacilityFilterLabel,
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
                  label: l10n.accountsPaymentMethodNewRecordAction,
                  icon: Icons.add_outlined,
                  enabled: !_isMutating,
                  onPressed: () => unawaited(_openCreate()),
                ),
                AppSearchBarAction(
                  label: l10n.accountsPaymentMethodBulkActivateAction,
                  icon: Icons.check_circle_outline,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsPaymentMethodAction.activate),
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsPaymentMethodAction.activate),
                  ),
                ),
                AppSearchBarAction(
                  label: l10n.accountsPaymentMethodBulkDeactivateAction,
                  icon: Icons.pause_circle_outline,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsPaymentMethodAction.deactivate),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsPaymentMethodAction.deactivate),
                  ),
                ),
                AppSearchBarAction(
                  label: l10n.accountsPaymentMethodBulkArchiveAction,
                  icon: Icons.inventory_2_outlined,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsPaymentMethodAction.archive),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsPaymentMethodAction.archive),
                  ),
                ),
              ]
            : const <AppSearchBarAction>[],
      ),
      columns: columns,
      columnChoices: optionalColumns,
      mobileItemBuilder: (BuildContext context, AccountsPaymentMethod method) {
        return AppListTableMobileItem(
          title: method.methodName,
          caption: l10n.accountsPaymentMethodMobileCaption(
            method.methodCode,
            accountsPaymentMethodTypeLabel(l10n, method.methodType),
          ),
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: accountsPaymentMethodDirectionLabel(l10n, method.direction),
              icon: Icons.swap_horiz_outlined,
            ),
            AppListTableMobileMeta(
              label: accountsPaymentMethodStatusLabel(l10n, method.status),
              icon: accountsPaymentMethodStatusIcon(method.status),
            ),
          ],
        );
      },
    );
  }

  bool _hasEligible(AccountsPaymentMethodAction action) {
    return _page.items.any(
      (AccountsPaymentMethod method) => _supportsAction(method, action),
    );
  }
}
