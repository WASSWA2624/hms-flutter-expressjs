import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_document_sequence_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_document_sequence.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_document_sequence_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

const String accountsDocumentNumberingTableSettingsKey =
    'accounts_document_numbering_v1';
const String accountsDocumentNumberingColumnWidthKey =
    'accounts_document_numbering_cw_v1';

const String accountsDocumentSequenceReferenceColumnId = 'reference';
const String accountsDocumentSequenceCodeColumnId = 'sequence_code';
const String accountsDocumentSequenceTypeColumnId = 'document_type';
const String accountsDocumentSequenceModuleColumnId = 'module';
const String accountsDocumentSequenceFacilityColumnId = 'facility';
const String accountsDocumentSequencePrefixColumnId = 'prefix';
const String accountsDocumentSequenceSuffixColumnId = 'suffix';
const String accountsDocumentSequenceDatePatternColumnId = 'date_pattern';
const String accountsDocumentSequenceNextNumberColumnId = 'next_number';
const String accountsDocumentSequenceMinimumLengthColumnId = 'minimum_length';
const String accountsDocumentSequenceResetColumnId = 'reset_frequency';
const String accountsDocumentSequenceLastIssuedNumberColumnId =
    'last_issued_number';
const String accountsDocumentSequenceLastIssuedAtColumnId = 'last_issued_at';
const String accountsDocumentSequenceGapPolicyColumnId = 'gap_policy';
const String accountsDocumentSequenceStatusColumnId = 'sequence_status';
const String accountsDocumentSequenceActionsColumnId = 'actions';

/// The 14 documented columns in source-of-truth order.
///
/// Settings and export preserve this order; visibility follows
/// [accountsDocumentSequenceOptionalColumnIds].
const List<String> accountsDocumentSequenceColumnIds = <String>[
  accountsDocumentSequenceCodeColumnId,
  accountsDocumentSequenceTypeColumnId,
  accountsDocumentSequenceModuleColumnId,
  accountsDocumentSequenceFacilityColumnId,
  accountsDocumentSequencePrefixColumnId,
  accountsDocumentSequenceSuffixColumnId,
  accountsDocumentSequenceDatePatternColumnId,
  accountsDocumentSequenceNextNumberColumnId,
  accountsDocumentSequenceMinimumLengthColumnId,
  accountsDocumentSequenceResetColumnId,
  accountsDocumentSequenceLastIssuedNumberColumnId,
  accountsDocumentSequenceLastIssuedAtColumnId,
  accountsDocumentSequenceGapPolicyColumnId,
  accountsDocumentSequenceStatusColumnId,
];

/// Columns the specification marks `Optional`: selectable and exportable, but
/// hidden until the operator turns them on in Settings.
///
/// The baseline human-friendly Reference column joins them so the default view
/// stays the source-of-truth default set.
const List<String> accountsDocumentSequenceOptionalColumnIds = <String>[
  accountsDocumentSequenceReferenceColumnId,
  accountsDocumentSequenceLastIssuedNumberColumnId,
  accountsDocumentSequenceLastIssuedAtColumnId,
  accountsDocumentSequenceGapPolicyColumnId,
];

/// `Accounts & Finance → Setup & Controls → Document Numbering`
/// (`?section=document-numbering`).
class AccountsDocumentNumberingPanel extends ConsumerStatefulWidget {
  const AccountsDocumentNumberingPanel({super.key});

  @override
  ConsumerState<AccountsDocumentNumberingPanel> createState() =>
      _AccountsDocumentNumberingPanelState();
}

class _AccountsDocumentNumberingPanelState
    extends ConsumerState<AccountsDocumentNumberingPanel> {
  static const String _statusFilterKey = 'status';
  static const String _facilityFilterKey = 'facility';
  static const String _documentTypeFilterKey = 'document_type';
  static const String _moduleFilterKey = 'module';
  static const String _resetFrequencyFilterKey = 'reset_frequency';
  static const String _gapPolicyFilterKey = 'gap_policy';
  static const String _sequenceCodeFilterKey = 'sequence_code';
  static const String _prefixFilterKey = 'prefix';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<AccountsDocumentSequence>
  _columnController =
      AppListTableColumnVisibilityController<AccountsDocumentSequence>(
        storageKey: accountsDocumentNumberingTableSettingsKey,
      );

  AppPage<AccountsDocumentSequence> _page =
      const AppPage<AccountsDocumentSequence>(
        items: <AccountsDocumentSequence>[],
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

  AccountsDocumentSequenceQuery get _query {
    final AccountsDocumentSequenceStatus? status =
        AccountsDocumentSequenceStatus.fromWire(
          _filterValue.option(_statusFilterKey),
        );
    final AccountsDocumentType? type = AccountsDocumentType.fromWire(
      _filterValue.option(_documentTypeFilterKey),
    );
    final AccountsDocumentSequenceResetFrequency? frequency =
        AccountsDocumentSequenceResetFrequency.fromWire(
          _filterValue.option(_resetFrequencyFilterKey),
        );
    final AccountsDocumentSequenceGapPolicy? gapPolicy =
        AccountsDocumentSequenceGapPolicy.fromWire(
          _filterValue.option(_gapPolicyFilterKey),
        );
    return AccountsDocumentSequenceQuery(
      search: _searchController.text.trim(),
      statuses: status == null
          ? const <AccountsDocumentSequenceStatus>{}
          : <AccountsDocumentSequenceStatus>{status},
      documentTypes: type == null
          ? const <AccountsDocumentType>{}
          : <AccountsDocumentType>{type},
      resetFrequencies: frequency == null
          ? const <AccountsDocumentSequenceResetFrequency>{}
          : <AccountsDocumentSequenceResetFrequency>{frequency},
      gapPolicies: gapPolicy == null
          ? const <AccountsDocumentSequenceGapPolicy>{}
          : <AccountsDocumentSequenceGapPolicy>{gapPolicy},
      module: (_filterValue.option(_moduleFilterKey) ?? '').trim(),
      sequenceCode: (_filterValue.text(_sequenceCodeFilterKey) ?? '').trim(),
      prefix: (_filterValue.text(_prefixFilterKey) ?? '').trim(),
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

    final AccountsDocumentSequenceQuery query = _query;
    final Result<AppPage<AccountsDocumentSequence>> result = await ref
        .read(accountsDocumentSequenceRepositoryProvider)
        .listDocumentSequences(query);

    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<AccountsDocumentSequence> page) {
        setState(() {
          _page = page;
          _loading = false;
          _revision++;
          for (final AccountsDocumentSequence sequence in page.items) {
            final String reference = (sequence.facilityHumanFriendlyId ?? '')
                .trim();
            final String label = (sequence.facility ?? '').trim();
            if (reference.isNotEmpty && label.isNotEmpty) {
              _facilityChoices[reference] = label;
            }
          }
        });
        // Badge from the server total when narrowed; otherwise defer to the
        // workspace summary so it never reflects only the painted page.
        ref
                .read<StateController<int?>>(
                  accountsDocumentSequenceCountProvider.notifier,
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

  Future<void> _openCreate({AccountsDocumentSequence? cloneOf}) async {
    final bool saved = await showAccountsDocumentSequenceDialog(
      context: context,
      ref: ref,
      mode: cloneOf == null
          ? AccountsDocumentSequenceDialogMode.create
          : AccountsDocumentSequenceDialogMode.clone,
      source: cloneOf,
    );
    if (saved && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  Future<void> _openEdit(AccountsDocumentSequence sequence) async {
    if (!sequence.canEdit) {
      return;
    }
    final bool saved = await showAccountsDocumentSequenceDialog(
      context: context,
      ref: ref,
      mode: AccountsDocumentSequenceDialogMode.edit,
      source: sequence,
    );
    if (saved && mounted) {
      _notifySaved();
      await _reload();
    }
  }

  Future<void> _openDetail(AccountsDocumentSequence sequence) async {
    await showAccountsDocumentSequenceDetail(
      context: context,
      ref: ref,
      sequence: sequence,
    );
  }

  Future<void> _applyAction(
    AccountsDocumentSequence sequence,
    AccountsDocumentSequenceAction action,
  ) async {
    final bool applied = await confirmAccountsDocumentSequenceAction(
      context: context,
      ref: ref,
      sequence: sequence,
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
  Future<void> _applyBulkAction(AccountsDocumentSequenceAction action) async {
    final List<AccountsDocumentSequence> eligible = _page.items
        .where(
          (AccountsDocumentSequence sequence) =>
              _supportsAction(sequence, action),
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
        body: l10n.accountsDocumentSequenceBulkConfirmBody(eligible.length),
        submitLabel: accountsDocumentSequenceActionLabel(l10n, action),
        destructive: action != AccountsDocumentSequenceAction.activate,
        icon: const Icon(Icons.playlist_add_check_outlined),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isMutating = true);
    int failed = 0;
    for (final AccountsDocumentSequence sequence in eligible) {
      final Result<AccountsDocumentSequence> result = await ref
          .read(accountsDocumentSequenceRepositoryProvider)
          .applyAction(
            sequence.humanFriendlyId,
            action,
            version: sequence.version,
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
              accountsDocumentSequenceRevisionProvider.notifier,
            )
            .state++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? AccountsStrings.saved
              : l10n.accountsDocumentSequenceBulkPartialFailure(failed),
        ),
      ),
    );
    await _reload();
  }

  static bool _supportsAction(
    AccountsDocumentSequence sequence,
    AccountsDocumentSequenceAction action,
  ) {
    return switch (action) {
      AccountsDocumentSequenceAction.activate => sequence.canActivate,
      AccountsDocumentSequenceAction.deactivate => sequence.canDeactivate,
      AccountsDocumentSequenceAction.archive => sequence.canArchive,
      AccountsDocumentSequenceAction.restore => sequence.canRestore,
    };
  }

  static String _bulkTitle(
    AppLocalizations l10n,
    AccountsDocumentSequenceAction action,
  ) {
    return switch (action) {
      AccountsDocumentSequenceAction.activate =>
        l10n.accountsDocumentSequenceBulkActivateAction,
      AccountsDocumentSequenceAction.deactivate =>
        l10n.accountsDocumentSequenceBulkDeactivateAction,
      AccountsDocumentSequenceAction.archive =>
        l10n.accountsDocumentSequenceBulkArchiveAction,
      AccountsDocumentSequenceAction.restore =>
        l10n.accountsDocumentSequenceRestoreAction,
    };
  }

  void _notifySaved() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AccountsStrings.saved)));
  }

  Widget _actionsCell(BuildContext context, AccountsDocumentSequence sequence) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final bool canWrite = canWriteAccountsDocumentSequences(
      ref.watch(appAccessPolicyProvider),
    );
    final AccountsDocumentSequenceAction? toggle = sequence.toggleAction;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: theme.spacing.md,
        runSpacing: theme.spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          AppButton.tertiary(
            leadingIcon: Icons.visibility_outlined,
            label: l10n.accountsDocumentSequenceViewAction,
            tooltip: l10n.accountsDocumentSequenceViewAction,
            dense: true,
            onPressed: () => unawaited(_openDetail(sequence)),
          ),
          if (canWrite && sequence.canEdit)
            AppButton.tertiary(
              leadingIcon: Icons.edit_outlined,
              label: l10n.commonEditActionLabel,
              tooltip: l10n.commonEditActionLabel,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openEdit(sequence)),
            ),
          if (canWrite && sequence.canClone)
            AppButton.tertiary(
              leadingIcon: Icons.copy_all_outlined,
              label: l10n.accountsDocumentSequenceCloneAction,
              tooltip: l10n.accountsDocumentSequenceCloneAction,
              dense: true,
              enabled: !_isMutating,
              onPressed: () => unawaited(_openCreate(cloneOf: sequence)),
            ),
          if (canWrite && toggle != null)
            AppButton.tertiary(
              leadingIcon: switch (toggle) {
                AccountsDocumentSequenceAction.restore => Icons.restore_outlined,
                AccountsDocumentSequenceAction.deactivate =>
                  Icons.pause_circle_outline,
                _ => Icons.check_circle_outline,
              },
              label: accountsDocumentSequenceActionLabel(l10n, toggle),
              tooltip: accountsDocumentSequenceActionLabel(l10n, toggle),
              dense: true,
              enabled: !_isMutating,
              color: toggle == AccountsDocumentSequenceAction.deactivate
                  ? colors.error
                  : null,
              onPressed: () => unawaited(_applyAction(sequence, toggle)),
            ),
          if (canWrite && sequence.canArchive)
            AppButton.tertiary(
              leadingIcon: Icons.inventory_2_outlined,
              label: l10n.accountsDocumentSequenceArchiveAction,
              tooltip: l10n.accountsDocumentSequenceArchiveAction,
              dense: true,
              enabled: !_isMutating,
              color: colors.error,
              onPressed: () => unawaited(
                _applyAction(sequence, AccountsDocumentSequenceAction.archive),
              ),
            ),
        ],
      ),
    );
  }

  static AppListTableColumn<AccountsDocumentSequence> _textColumn({
    required String id,
    required String label,
    required String? Function(AccountsDocumentSequence sequence) valueOf,
    double preferredWidth = 150,
  }) {
    return AppListTableColumn<AccountsDocumentSequence>(
      id: id,
      label: label,
      preferredWidth: preferredWidth,
      cellBuilder: (_, AccountsDocumentSequence sequence) => Text(
        valueOf(sequence) ?? accountsUnknownValue(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      sortComparator:
          (AccountsDocumentSequence a, AccountsDocumentSequence b) =>
              (valueOf(a) ?? '').compareTo(valueOf(b) ?? ''),
      exportValue: (AccountsDocumentSequence sequence) =>
          valueOf(sequence) ?? '',
    );
  }

  /// A counter-derived number, right-aligned and padded to the policy width.
  static AppListTableColumn<AccountsDocumentSequence> _numberColumn({
    required String id,
    required String label,
    required int? Function(AccountsDocumentSequence sequence) valueOf,
  }) {
    return AppListTableColumn<AccountsDocumentSequence>(
      id: id,
      label: label,
      preferredWidth: 140,
      numeric: true,
      cellBuilder: (_, AccountsDocumentSequence sequence) => Text(
        accountsDocumentSequenceNumber(
          valueOf(sequence),
          sequence.minimumLength,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      sortComparator:
          (AccountsDocumentSequence a, AccountsDocumentSequence b) =>
              (valueOf(a) ?? -1).compareTo(valueOf(b) ?? -1),
      exportValue: (AccountsDocumentSequence sequence) =>
          accountsDocumentSequenceNumber(
            valueOf(sequence),
            sequence.minimumLength,
          ),
    );
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

  /// Optional columns: available in Settings, exports, and print, hidden until
  /// the operator enables them (specification marks these `Optional`).
  List<AppListTableColumn<AccountsDocumentSequence>> _optionalColumns(
    AppLocalizations l10n,
  ) {
    return <AppListTableColumn<AccountsDocumentSequence>>[
      AppListTableColumn<AccountsDocumentSequence>(
        id: accountsDocumentSequenceReferenceColumnId,
        label: l10n.accountsDocumentSequenceReferenceColumn,
        preferredWidth: 150,
        cellBuilder: (_, AccountsDocumentSequence sequence) =>
            AppCopyableIdentifier(
              value:
                  accountsPublicLabel(sequence.humanFriendlyId) ??
                  accountsUnknownValue(),
            ),
        sortComparator:
            (AccountsDocumentSequence a, AccountsDocumentSequence b) =>
                a.humanFriendlyId.compareTo(b.humanFriendlyId),
        exportValue: (AccountsDocumentSequence sequence) =>
            accountsPublicLabel(sequence.humanFriendlyId) ?? '',
      ),
      _numberColumn(
        id: accountsDocumentSequenceLastIssuedNumberColumnId,
        label: l10n.accountsDocumentSequenceLastIssuedNumberColumn,
        valueOf: (AccountsDocumentSequence sequence) =>
            sequence.lastIssuedNumber,
      ),
      AppListTableColumn<AccountsDocumentSequence>(
        id: accountsDocumentSequenceLastIssuedAtColumnId,
        label: l10n.accountsDocumentSequenceLastIssuedAtColumn,
        preferredWidth: 170,
        cellBuilder: (BuildContext context, AccountsDocumentSequence sequence) =>
            Text(accountsDateTime(context, sequence.lastIssuedAt)),
        sortComparator:
            (AccountsDocumentSequence a, AccountsDocumentSequence b) =>
                _compareDates(a.lastIssuedAt, b.lastIssuedAt),
        exportValue: (AccountsDocumentSequence sequence) =>
            sequence.lastIssuedAt?.toIso8601String() ?? '',
      ),
      _textColumn(
        id: accountsDocumentSequenceGapPolicyColumnId,
        label: l10n.accountsDocumentSequenceGapPolicyColumn,
        valueOf: (AccountsDocumentSequence sequence) =>
            accountsDocumentGapPolicyLabel(l10n, sequence.gapPolicy),
        preferredWidth: 170,
      ),
    ];
  }

  List<AppListTableColumn<AccountsDocumentSequence>> _columns({
    required AppLocalizations l10n,
    required bool canWrite,
  }) {
    return <AppListTableColumn<AccountsDocumentSequence>>[
      AppListTableColumn<AccountsDocumentSequence>(
        id: accountsDocumentSequenceCodeColumnId,
        label: l10n.accountsDocumentSequenceCodeColumn,
        alwaysVisible: true,
        preferredWidth: 160,
        cellBuilder: (_, AccountsDocumentSequence sequence) => Text(
          sequence.sequenceCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        sortComparator:
            (AccountsDocumentSequence a, AccountsDocumentSequence b) =>
                a.sequenceCode.compareTo(b.sequenceCode),
        exportValue: (AccountsDocumentSequence sequence) =>
            sequence.sequenceCode,
      ),
      // Localized document family; the raw enum never reaches the table.
      _textColumn(
        id: accountsDocumentSequenceTypeColumnId,
        label: l10n.accountsDocumentSequenceTypeColumn,
        valueOf: (AccountsDocumentSequence sequence) =>
            accountsDocumentTypeLabel(l10n, sequence.documentType),
        preferredWidth: 170,
      ),
      _textColumn(
        id: accountsDocumentSequenceModuleColumnId,
        label: l10n.accountsDocumentSequenceModuleColumn,
        valueOf: (AccountsDocumentSequence sequence) =>
            accountsFiscalModuleLabel(l10n, sequence.module),
      ),
      _textColumn(
        id: accountsDocumentSequenceFacilityColumnId,
        label: l10n.accountsDocumentSequenceFacilityColumn,
        valueOf: (AccountsDocumentSequence sequence) => sequence.facility,
        preferredWidth: 170,
      ),
      _textColumn(
        id: accountsDocumentSequencePrefixColumnId,
        label: l10n.accountsDocumentSequencePrefixColumn,
        valueOf: (AccountsDocumentSequence sequence) => sequence.prefix,
        preferredWidth: 120,
      ),
      _textColumn(
        id: accountsDocumentSequenceSuffixColumnId,
        label: l10n.accountsDocumentSequenceSuffixColumn,
        valueOf: (AccountsDocumentSequence sequence) => sequence.suffix,
        preferredWidth: 120,
      ),
      _textColumn(
        id: accountsDocumentSequenceDatePatternColumnId,
        label: l10n.accountsDocumentSequenceDatePatternColumn,
        valueOf: (AccountsDocumentSequence sequence) => sequence.datePattern,
      ),
      _numberColumn(
        id: accountsDocumentSequenceNextNumberColumnId,
        label: l10n.accountsDocumentSequenceNextNumberColumn,
        valueOf: (AccountsDocumentSequence sequence) => sequence.nextNumber,
      ),
      _numberColumn(
        id: accountsDocumentSequenceMinimumLengthColumnId,
        label: l10n.accountsDocumentSequenceMinimumLengthColumn,
        valueOf: (AccountsDocumentSequence sequence) => sequence.minimumLength,
      ),
      _textColumn(
        id: accountsDocumentSequenceResetColumnId,
        label: l10n.accountsDocumentSequenceResetColumn,
        valueOf: (AccountsDocumentSequence sequence) =>
            accountsDocumentResetFrequencyLabel(l10n, sequence.resetFrequency),
        preferredWidth: 160,
      ),
      AppListTableColumn<AccountsDocumentSequence>(
        id: accountsDocumentSequenceStatusColumnId,
        label: l10n.accountsDocumentSequenceStatusColumn,
        alwaysVisible: true,
        preferredWidth: 140,
        cellBuilder: (_, AccountsDocumentSequence sequence) =>
            AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: accountsDocumentSequenceStatusLabel(
                  l10n,
                  sequence.status,
                ),
                tone: accountsDocumentSequenceStatusTone(sequence.status),
                icon: accountsDocumentSequenceStatusIcon(sequence.status),
              ),
            ),
        sortComparator:
            (AccountsDocumentSequence a, AccountsDocumentSequence b) =>
                a.status.index.compareTo(b.status.index),
        exportValue: (AccountsDocumentSequence sequence) =>
            accountsDocumentSequenceStatusLabel(l10n, sequence.status),
      ),
      if (canWrite)
        AppListTableColumn<AccountsDocumentSequence>(
          id: accountsDocumentSequenceActionsColumnId,
          label: l10n.accountsDocumentSequenceActionsColumn,
          alwaysVisible: true,
          exportable: false,
          preferredWidth: 260,
          cellBuilder: _actionsCell,
        ),
    ];
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
    final bool canWrite = canWriteAccountsDocumentSequences(accessPolicy);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
    final List<AppListTableColumn<AccountsDocumentSequence>> columns = _columns(
      l10n: l10n,
      canWrite: canWrite,
    );
    final List<AppListTableColumn<AccountsDocumentSequence>> optionalColumns =
        _optionalColumns(l10n);

    // Mutations elsewhere (detail dialog, other panels) invalidate this list.
    ref.listen<int>(accountsDocumentSequenceRevisionProvider, (_, _) {
      unawaited(_reload());
    });

    return AppListTable<AccountsDocumentSequence>(
      page: _page,
      rowsVersion: _revision,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      itemKeyBuilder: (AccountsDocumentSequence sequence) =>
          ValueKey<String>(sequence.humanFriendlyId),
      initialSortColumnKey: accountsDocumentSequenceCodeColumnId,
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: accountsDocumentNumberingTableSettingsKey,
      columnWidthStorageKey: accountsDocumentNumberingColumnWidthKey,
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
      exportConfig: AppListTableExportConfig<AccountsDocumentSequence>(
        fileNameStem: 'accounts_document_numbering',
        sheetName: l10n.accountsDocumentNumberingLabel,
        dateOf: (AccountsDocumentSequence sequence) => sequence.lastIssuedAt,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      enablePrint: true,
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      onPrint: (List<AccountsDocumentSequence> items) =>
          printAccountsListTable<AccountsDocumentSequence>(
            ref: ref,
            context: context,
            title: l10n.accountsDocumentNumberingLabel,
            // Print offers the full source-of-truth column inventory, not only
            // the columns currently visible.
            columns: <AppListTableColumn<AccountsDocumentSequence>>[
              ...columns,
              ...optionalColumns,
            ],
            items: items,
            emptyText: l10n.accountsDocumentNumberingEmpty,
          ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      onRowSelected: (AccountsDocumentSequence sequence) =>
          unawaited(_openDetail(sequence)),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.accountsDocumentNumberingEmpty,
        body: l10n.accountsDocumentNumberingEmptyBody,
      ),
      search: AppListTableSearch<AccountsDocumentSequence>(
        controller: _searchController,
        semanticLabel: l10n.accountsDocumentNumberingSearchHint,
        hintText: l10n.accountsDocumentNumberingSearchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsDocumentSequence sequence, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) {
            return true;
          }
          final String reference =
              accountsPublicLabel(sequence.humanFriendlyId) ?? '';
          return reference.toLowerCase().contains(needle) ||
              sequence.sequenceCode.toLowerCase().contains(needle) ||
              sequence.prefix.toLowerCase().contains(needle) ||
              (sequence.suffix ?? '').toLowerCase().contains(needle) ||
              sequence.module.toLowerCase().contains(needle);
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
        dateFilterLabel: l10n.accountsDocumentSequenceDateRangeFilterLabel,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: _sequenceCodeFilterKey,
            label: l10n.accountsDocumentSequenceCodeColumn,
            hintText: l10n.accountsDocumentSequenceCodeColumn,
            icon: Icons.tag_outlined,
          ),
          AppSearchBarTextFilter(
            key: _prefixFilterKey,
            label: l10n.accountsDocumentSequencePrefixColumn,
            hintText: l10n.accountsDocumentSequencePrefixColumn,
            icon: Icons.text_fields_outlined,
          ),
        ],
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.accountsDocumentSequenceStatusColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsDocumentSequenceStatus status
                  in AccountsDocumentSequenceStatus.values)
                AppSearchBarFilterChoice(
                  value: status.wireValue,
                  label: accountsDocumentSequenceStatusLabel(l10n, status),
                  icon: accountsDocumentSequenceStatusIcon(status),
                ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _documentTypeFilterKey,
            label: l10n.accountsDocumentSequenceTypeColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsDocumentType type
                  in AccountsDocumentType.values)
                AppSearchBarFilterChoice(
                  value: type.wireValue,
                  label: accountsDocumentTypeLabel(l10n, type),
                  icon: Icons.description_outlined,
                ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _moduleFilterKey,
            label: l10n.accountsDocumentSequenceModuleColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final String value in accountsFiscalModuleWireValues)
                AppSearchBarFilterChoice(
                  value: value,
                  label: accountsFiscalModuleLabel(l10n, value),
                  icon: Icons.widgets_outlined,
                ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _resetFrequencyFilterKey,
            label: l10n.accountsDocumentSequenceResetColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsDocumentSequenceResetFrequency frequency
                  in AccountsDocumentSequenceResetFrequency.values)
                AppSearchBarFilterChoice(
                  value: frequency.wireValue,
                  label: accountsDocumentResetFrequencyLabel(l10n, frequency),
                  icon: Icons.restart_alt_outlined,
                ),
            ],
          ),
          AppSearchBarFilterGroup(
            key: _gapPolicyFilterKey,
            label: l10n.accountsDocumentSequenceGapPolicyColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              for (final AccountsDocumentSequenceGapPolicy policy
                  in AccountsDocumentSequenceGapPolicy.values)
                AppSearchBarFilterChoice(
                  value: policy.wireValue,
                  label: accountsDocumentGapPolicyLabel(l10n, policy),
                  icon: Icons.rule_outlined,
                ),
            ],
          ),
          // Offered only where the caller's ABAC scope actually spans more than
          // one facility; a single-facility operator gets no dead control.
          if (_facilityChoices.length > 1)
            AppSearchBarFilterGroup(
              key: _facilityFilterKey,
              label: l10n.accountsDocumentSequenceFacilityColumn,
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
                  label: l10n.accountsDocumentSequenceNewRecordAction,
                  icon: Icons.add_outlined,
                  enabled: !_isMutating,
                  onPressed: () => unawaited(_openCreate()),
                ),
                AppSearchBarAction(
                  label: l10n.accountsDocumentSequenceBulkActivateAction,
                  icon: Icons.check_circle_outline,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsDocumentSequenceAction.activate),
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsDocumentSequenceAction.activate),
                  ),
                ),
                AppSearchBarAction(
                  label: l10n.accountsDocumentSequenceBulkDeactivateAction,
                  icon: Icons.pause_circle_outline,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsDocumentSequenceAction.deactivate),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsDocumentSequenceAction.deactivate),
                  ),
                ),
                AppSearchBarAction(
                  label: l10n.accountsDocumentSequenceBulkArchiveAction,
                  icon: Icons.inventory_2_outlined,
                  enabled:
                      !_isMutating &&
                      _hasEligible(AccountsDocumentSequenceAction.archive),
                  destructive: true,
                  onPressed: () => unawaited(
                    _applyBulkAction(AccountsDocumentSequenceAction.archive),
                  ),
                ),
              ]
            : const <AppSearchBarAction>[],
      ),
      columns: columns,
      columnChoices: optionalColumns,
      mobileItemBuilder:
          (BuildContext context, AccountsDocumentSequence sequence) {
            return AppListTableMobileItem(
              title: sequence.sequenceCode,
              caption: l10n.accountsDocumentSequenceMobileCaption(
                accountsDocumentTypeLabel(l10n, sequence.documentType),
                sequence.prefix,
              ),
              meta: <AppListTableMobileMeta>[
                AppListTableMobileMeta(
                  label: accountsDocumentSequenceNumber(
                    sequence.nextNumber,
                    sequence.minimumLength,
                  ),
                  icon: Icons.tag_outlined,
                ),
                AppListTableMobileMeta(
                  label: accountsDocumentSequenceStatusLabel(
                    l10n,
                    sequence.status,
                  ),
                  icon: accountsDocumentSequenceStatusIcon(sequence.status),
                ),
              ],
            );
          },
    );
  }

  bool _hasEligible(AccountsDocumentSequenceAction action) {
    return _page.items.any(
      (AccountsDocumentSequence sequence) =>
          _supportsAction(sequence, action),
    );
  }
}
