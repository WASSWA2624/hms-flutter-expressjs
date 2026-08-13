import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_invoice_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_invoice_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

const String accountsInvoicesTableSettingsKey = 'accounts_invoices_v1';
const String accountsInvoicesColumnWidthKey = 'accounts_invoices_cw_v1';
const String accountsInvoicesNumberColumnId = 'invoice';
const String accountsInvoicesPayeeColumnId = 'payee';
const String accountsInvoicesDateColumnId = 'date';
const String accountsInvoicesStatusColumnId = 'status';
const String accountsInvoicesTotalColumnId = 'total';
const String accountsInvoicesActionsColumnId = 'actions';

/// Facility outflow invoices desk (`?section=invoices`).
class AccountsInvoicesPanel extends ConsumerStatefulWidget {
  const AccountsInvoicesPanel({super.key});

  @override
  ConsumerState<AccountsInvoicesPanel> createState() =>
      _AccountsInvoicesPanelState();
}

class _AccountsInvoicesPanelState extends ConsumerState<AccountsInvoicesPanel> {
  static const String _statusFilterKey = 'status';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<AccountsInvoice>
  _columnController =
      AppListTableColumnVisibilityController<AccountsInvoice>(
        storageKey: accountsInvoicesTableSettingsKey,
      );

  AppPage<AccountsInvoice> _page = const AppPage<AccountsInvoice>(
    items: <AccountsInvoice>[],
    request: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    totalItemCount: 0,
  );
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

  bool get _hasActiveFilters =>
      (_filterValue.option(_statusFilterKey) ?? '').trim().isNotEmpty ||
      _filterValue.dateFrom != null ||
      _filterValue.dateTo != null;

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
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_reload());
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    final Result<AppPage<AccountsInvoice>> result = await ref
        .read(accountsInvoiceRepositoryProvider)
        .listInvoices(
          AccountsInvoiceQuery(
            search: _searchController.text,
            status: (_filterValue.option(_statusFilterKey) ?? '').trim(),
            dateFrom: _filterValue.dateFrom,
            dateTo: _filterValue.dateTo,
          ),
          tenantId: _tenantId,
          facilityId: _facilityId,
        );
    if (!mounted) return;
    result.when(
      success: (AppPage<AccountsInvoice> page) {
        setState(() {
          _page = page;
          _loading = false;
        });
        ref.read(accountsInvoicesCountProvider.notifier).state =
            page.totalItemCount ?? page.items.length;
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loading = false;
        });
        ref.read(accountsInvoicesCountProvider.notifier).state = null;
      },
    );
  }

  Future<void> _createOrEdit({AccountsInvoice? editing}) async {
    final AccountsInvoiceEditorResult outcome =
        await showAccountsInvoiceEditorDialog(
          context: context,
          ref: ref,
          editing: editing,
        );
    if (!outcome.saved || !mounted) {
      return;
    }
    await _reload();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AccountsStrings.saved)),
    );
    final AccountsInvoice? invoice = outcome.invoice;
    if (editing == null && invoice != null) {
      await _openDetails(invoice);
    }
  }

  Future<void> _openDetails(AccountsInvoice invoice) async {
    await showAccountsInvoiceDetailsDialog(
      context: context,
      ref: ref,
      invoice: invoice,
      onChanged: _reload,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteAccounts(accessPolicy);
    final bool canExport = canExportAccountsWorkspace(accessPolicy);
    final bool canPrint = canPrintAccountsWorkspace(accessPolicy);

    final List<AppListTableColumn<AccountsInvoice>> columns =
        <AppListTableColumn<AccountsInvoice>>[
          AppListTableColumn<AccountsInvoice>(
            id: accountsInvoicesNumberColumnId,
            label: AccountsStrings.invoiceNumberColumn,
            alwaysVisible: true,
            preferredWidth: 140,
            cellBuilder: (_, AccountsInvoice item) => Text(
              item.effectiveNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            sortComparator: (AccountsInvoice a, AccountsInvoice b) =>
                a.effectiveNumber.compareTo(b.effectiveNumber),
            exportValue: (AccountsInvoice item) => item.effectiveNumber,
          ),
          AppListTableColumn<AccountsInvoice>(
            id: accountsInvoicesPayeeColumnId,
            label: AccountsStrings.invoicePayeeColumn,
            preferredWidth: 200,
            cellBuilder: (_, AccountsInvoice item) => Text(
              item.payee,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            sortComparator: (AccountsInvoice a, AccountsInvoice b) =>
                a.payee.compareTo(b.payee),
            exportValue: (AccountsInvoice item) => item.payee,
          ),
          AppListTableColumn<AccountsInvoice>(
            id: accountsInvoicesDateColumnId,
            label: AccountsStrings.invoiceDateColumn,
            preferredWidth: 140,
            cellBuilder: (BuildContext context, AccountsInvoice item) => Text(
              AppFormatters.shortDate(
                item.invoiceDate,
                Localizations.localeOf(context),
              ),
            ),
            sortComparator: (AccountsInvoice a, AccountsInvoice b) =>
                a.invoiceDate.compareTo(b.invoiceDate),
            exportValue: (AccountsInvoice item) =>
                item.invoiceDate.toIso8601String(),
          ),
          AppListTableColumn<AccountsInvoice>(
            id: accountsInvoicesStatusColumnId,
            label: AccountsStrings.statusColumn,
            preferredWidth: 110,
            cellBuilder: (_, AccountsInvoice item) => AppStatusBadge(
              label: accountsStatusLabel(item.status),
              tone: item.isVoided
                  ? AppWorkspaceStatusTone.error
                  : item.status.toUpperCase() == 'ISSUED'
                  ? AppWorkspaceStatusTone.success
                  : AppWorkspaceStatusTone.warning,
              icon: item.isVoided
                  ? Icons.cancel_outlined
                  : Icons.receipt_long_outlined,
            ),
            exportValue: (AccountsInvoice item) =>
                accountsStatusLabel(item.status),
          ),
          AppListTableColumn<AccountsInvoice>(
            id: accountsInvoicesTotalColumnId,
            label: AccountsStrings.invoiceTotalColumn,
            preferredWidth: 120,
            cellBuilder: (BuildContext context, AccountsInvoice item) => Text(
              accountsMoney(context, item.totalAmount, item.currency),
            ),
            sortComparator: (AccountsInvoice a, AccountsInvoice b) =>
                a.totalAmount.compareTo(b.totalAmount),
            exportValue: (AccountsInvoice item) => item.totalAmount.toString(),
          ),
          if (canWrite)
            AppListTableColumn<AccountsInvoice>(
              id: accountsInvoicesActionsColumnId,
              label: AccountsStrings.invoiceActionsColumn,
              alwaysVisible: true,
              exportable: false,
              preferredWidth: 160,
              cellBuilder: (BuildContext context, AccountsInvoice item) {
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    spacing: Theme.of(context).spacing.md,
                    children: <Widget>[
                      if (item.canEdit)
                        AppButton.tertiary(
                          leadingIcon: Icons.edit_outlined,
                          label: l10n.commonEditActionLabel,
                          dense: true,
                          onPressed: () =>
                              unawaited(_createOrEdit(editing: item)),
                        ),
                    ],
                  ),
                );
              },
            ),
        ];

    return AppListTable<AccountsInvoice>(
      page: _page,
      isLoading: _loading,
      error: _failure == null ? null : l10n.failureMessage(_failure!),
      columnVisibilityController: _columnController,
      columnVisibilityStorageKey: accountsInvoicesTableSettingsKey,
      columnWidthStorageKey: accountsInvoicesColumnWidthKey,
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
      onPrint: (items) => printAccountsListTable<AccountsInvoice>(
        ref: ref,
        context: context,
        title: AccountsStrings.invoicesLabel,
        columns: columns,
        items: items,
        emptyText: AccountsStrings.invoicesEmpty,
      ),
      goToTopLabel: l10n.commonGoToTopActionLabel,
      loadingMoreLabel: l10n.commonLoadingMoreLabel,
      allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
      exportConfig: AppListTableExportConfig<AccountsInvoice>(
        fileNameStem: 'accounts_invoices',
        dateOf: (AccountsInvoice item) => item.invoiceDate,
        sheetName: AccountsStrings.invoicesLabel,
        dateFromLabel: l10n.commonTableExportDateFromLabel,
        dateToLabel: l10n.commonTableExportDateToLabel,
      ),
      onRowSelected: (AccountsInvoice item) => unawaited(_openDetails(item)),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: AccountsStrings.invoicesEmpty,
        body: AccountsStrings.invoicesEmptyBody,
      ),
      search: AppListTableSearch<AccountsInvoice>(
        controller: _searchController,
        semanticLabel: AccountsStrings.invoicesSearchHint,
        hintText: AccountsStrings.invoicesSearchHint,
        clearLabel: AccountsStrings.clearSearch,
        matcher: (AccountsInvoice item, String query) {
          final String needle = query.trim().toLowerCase();
          if (needle.isEmpty) return true;
          return item.effectiveNumber.toLowerCase().contains(needle) ||
              item.payee.toLowerCase().contains(needle) ||
              item.status.toLowerCase().contains(needle) ||
              (item.reference ?? '').toLowerCase().contains(needle);
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
        enableDateFilter: true,
        dateFromLabel: l10n.opdDateFromLabel,
        dateToLabel: l10n.opdDateToLabel,
        filterGroups: <AppSearchBarFilterGroup>[
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: AccountsStrings.statusColumn,
            allLabel: AccountsStrings.allFields,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: 'DRAFT',
                label: AccountsStrings.statusDraft,
              ),
              AppSearchBarFilterChoice(
                value: 'ISSUED',
                label: AccountsStrings.statusIssued,
              ),
              AppSearchBarFilterChoice(
                value: 'VOIDED',
                label: AccountsStrings.statusVoided,
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
                  label: AccountsStrings.createInvoiceAction,
                  icon: Icons.add_outlined,
                  onPressed: () => unawaited(_createOrEdit()),
                ),
              ]
            : const <AppSearchBarAction>[],
      ),
      columns: columns,
      mobileItemBuilder: (BuildContext context, AccountsInvoice item) {
        return AppListTableMobileItem(
          title: item.payee,
          caption: item.effectiveNumber,
          meta: <AppListTableMobileMeta>[
            AppListTableMobileMeta(
              label: accountsStatusLabel(item.status),
              icon: Icons.receipt_long_outlined,
            ),
            AppListTableMobileMeta(
              label: accountsMoney(context, item.totalAmount, item.currency),
              icon: Icons.payments_outlined,
            ),
          ],
        );
      },
    );
  }
}
