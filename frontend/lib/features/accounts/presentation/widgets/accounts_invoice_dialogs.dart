import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_invoice_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_form_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart'
    hide accountsEmptyToNull;
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Result of create/edit invoice dialog. [invoice] is set when save succeeded.
final class AccountsInvoiceEditorResult {
  const AccountsInvoiceEditorResult.cancelled()
    : invoice = null,
      saved = false;

  const AccountsInvoiceEditorResult.saved(this.invoice) : saved = true;

  final bool saved;
  final AccountsInvoice? invoice;
}

Future<AccountsInvoiceEditorResult> showAccountsInvoiceEditorDialog({
  required BuildContext context,
  required WidgetRef ref,
  AccountsInvoice? editing,
}) async {
  if (!canWriteAccounts(ref.read(appAccessPolicyProvider))) {
    return const AccountsInvoiceEditorResult.cancelled();
  }
  final AccountsInvoiceEditorResult? result =
      await showAppDialog<AccountsInvoiceEditorResult>(
        context: context,
        builder: (BuildContext dialogContext) {
          return _AccountsInvoiceEditorDialog(
            editing: editing,
            onPersist: (AccountsInvoiceDraft draft) async {
              final session = ref.read(sessionStateProvider).session?.user;
              final String? tenantId =
                  session?.tenantId ??
                  ref.read(appAccessPolicyProvider).tenantId;
              if (tenantId == null || tenantId.trim().isEmpty) {
                return Result.failure(
                  AppFailure.validation(
                    validationFields: <String>{'tenant_id'},
                  ),
                );
              }
              final Map<String, Object?> payload = draft.toPayload(
                tenantId: tenantId,
                facilityId:
                    session?.facilityId ??
                    ref.read(appAccessPolicyProvider).facilityId,
              );
              final Result<AccountsInvoice> persisted = editing == null
                  ? await ref
                        .read(accountsInvoiceRepositoryProvider)
                        .createInvoice(payload)
                  : await ref
                        .read(accountsInvoiceRepositoryProvider)
                        .updateInvoice(editing.id, payload);
              persisted.when(
                success: (_) {
                  ref.read(accountsInvoicesCountProvider.notifier).state = null;
                },
                failure: (_) {},
              );
              return persisted;
            },
          );
        },
      );
  return result ?? const AccountsInvoiceEditorResult.cancelled();
}

Future<void> showAccountsInvoiceDetailsDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsInvoice invoice,
  required Future<void> Function() onChanged,
}) async {
  AccountsInvoice current = invoice;
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return Consumer(
        builder: (BuildContext context, WidgetRef dialogRef, _) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              final accessPolicy = dialogRef.watch(appAccessPolicyProvider);
              final bool canWrite = canWriteAccounts(accessPolicy);
              final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
              final ThemeData theme = Theme.of(context);
              final l10n = context.l10n;
              return AppDialog(
                title: const Text(AccountsStrings.invoiceDetailsTitle),
                icon: const Icon(Icons.receipt_long_outlined),
                scrollable: true,
                pinActionsToBottom: true,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      current.effectiveNumber,
                      style: theme.textTheme.titleMedium,
                    ),
                    SizedBox(height: theme.spacing.sm),
                    Text(
                      '${AccountsStrings.invoicePayeeLabel}: ${current.payee}',
                    ),
                    Text(
                      '${AccountsStrings.invoiceDateLabel}: ${accountsDateTime(context, current.invoiceDate)}',
                    ),
                    Text(
                      '${AccountsStrings.statusColumn}: ${accountsStatusLabel(current.status)}',
                    ),
                    Text(
                      '${AccountsStrings.invoiceGrandTotalLabel}: ${accountsMoney(context, current.totalAmount, current.currency)}',
                    ),
                    if ((current.notes ?? '').isNotEmpty)
                      Text('${AccountsStrings.notesLabel}: ${current.notes}'),
                    if (current.isVoided &&
                        (current.voidReason ?? '').isNotEmpty)
                      Text(
                        '${AccountsStrings.reasonLabel}: ${current.voidReason}',
                      ),
                    SizedBox(height: theme.spacing.md),
                AppCollapsibleSection(
                  title: AccountsStrings.invoiceItemsSectionTitle,
                  child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (current.items.isEmpty)
                            const Text(AccountsStrings.invoiceItemsEmpty)
                          else
                            for (final AccountsInvoiceLineItem item
                                in current.items)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: theme.spacing.xs,
                                ),
                                child: Text(
                                  '${item.name} · ${item.quantity} × ${accountsMoney(context, item.unitPrice, current.currency)} = ${accountsMoney(context, item.effectiveLineTotal, current.currency)}',
                                ),
                              ),
                        ],
                      ),
                    ),
                    if (canWrite &&
                        (current.canEdit || current.canVoid)) ...<Widget>[
                      SizedBox(height: theme.spacing.md),
                      Wrap(
                        spacing: theme.spacing.sm,
                        runSpacing: theme.spacing.xs,
                        children: <Widget>[
                          if (current.canEdit)
                            AppButton.tertiary(
                              leadingIcon: Icons.edit_outlined,
                              label: l10n.commonEditActionLabel,
                              dense: true,
                              onPressed: () async {
                                final AccountsInvoiceEditorResult outcome =
                                    await showAccountsInvoiceEditorDialog(
                                      context: context,
                                      ref: dialogRef,
                                      editing: current,
                                    );
                                if (!outcome.saved) {
                                  return;
                                }
                                final AccountsInvoice? updated =
                                    outcome.invoice;
                                if (updated != null) {
                                  current = updated;
                                } else {
                                  final Result<AccountsInvoice> refreshed =
                                      await dialogRef
                                          .read(
                                            accountsInvoiceRepositoryProvider,
                                          )
                                          .getInvoice(current.id);
                                  refreshed.when(
                                    success: (AccountsInvoice value) =>
                                        current = value,
                                    failure: (_) {},
                                  );
                                }
                                await onChanged();
                                setDialogState(() {});
                              },
                            ),
                          if (current.canVoid)
                            AppButton.tertiary(
                              leadingIcon: Icons.delete_outline,
                              label: l10n.commonDeleteActionLabel,
                              dense: true,
                              color: theme.colorScheme.error,
                              onPressed: () async {
                                final AccountsReasonDraft? draft =
                                    await showAppDialog<AccountsReasonDraft>(
                                      context: context,
                                      builder: (_) => AccountsReasonForm(
                                        dialogTitle: const Text(
                                          AccountsStrings.invoiceVoidTitle,
                                        ),
                                        submitLabel:
                                            l10n.commonDeleteActionLabel,
                                      ),
                                    );
                                if (draft == null) {
                                  return;
                                }
                                final Result<AccountsInvoice> voided =
                                    await dialogRef
                                        .read(
                                          accountsInvoiceRepositoryProvider,
                                        )
                                        .voidInvoice(
                                          current.id,
                                          reason: draft.reason,
                                          notes: draft.notes,
                                        );
                                final AppFailure? failure = voided.when(
                                  success: (_) => null,
                                  failure: (AppFailure f) => f,
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                if (failure != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.failureMessage(failure),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      AccountsStrings.invoiceVoided,
                                    ),
                                  ),
                                );
                                dialogRef
                                        .read(
                                          accountsInvoicesCountProvider
                                              .notifier,
                                        )
                                        .state =
                                    null;
                                await onChanged();
                                if (dialogContext.mounted) {
                                  await Navigator.of(dialogContext).maybePop();
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
                actions: <Widget>[
                  if (canPrint)
                    AppButton.secondary(
                      leadingIcon: Icons.print_outlined,
                      label: l10n.commonPrintActionLabel,
                      onPressed: () => _printInvoiceDetails(
                        context: context,
                        ref: dialogRef,
                        invoice: current,
                      ),
                    ),
                  AppButton.secondary(
                    leadingIcon: Icons.close,
                    label: l10n.commonCloseActionLabel,
                    onPressed: () => Navigator.of(dialogContext).maybePop(),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

Future<void> _printInvoiceDetails({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsInvoice invoice,
}) {
  return printAccountsListTable<_InvoicePrintRow>(
    ref: ref,
    context: context,
    title: AccountsStrings.invoiceDetailsTitle,
    columns: <AppListTableColumn<_InvoicePrintRow>>[
      AppListTableColumn<_InvoicePrintRow>(
        id: 'field',
        label: AccountsStrings.typeColumn,
        cellBuilder: (_, _InvoicePrintRow row) => Text(row.label),
        exportValue: (_InvoicePrintRow row) => row.label,
      ),
      AppListTableColumn<_InvoicePrintRow>(
        id: 'value',
        label: AccountsStrings.invoiceItemDescriptionLabel,
        cellBuilder: (_, _InvoicePrintRow row) => Text(row.value),
        exportValue: (_InvoicePrintRow row) => row.value,
      ),
    ],
    items: <_InvoicePrintRow>[
      _InvoicePrintRow(
        AccountsStrings.invoiceNumberColumn,
        invoice.effectiveNumber,
      ),
      _InvoicePrintRow(AccountsStrings.invoicePayeeLabel, invoice.payee),
      _InvoicePrintRow(
        AccountsStrings.invoiceDateLabel,
        accountsDateTime(context, invoice.invoiceDate),
      ),
      _InvoicePrintRow(
        AccountsStrings.statusColumn,
        accountsStatusLabel(invoice.status),
      ),
      if ((invoice.notes ?? '').isNotEmpty)
        _InvoicePrintRow(AccountsStrings.notesLabel, invoice.notes!),
      for (final AccountsInvoiceLineItem item in invoice.items)
        _InvoicePrintRow(
          item.name,
          '${item.quantity} × ${accountsMoney(context, item.unitPrice, invoice.currency)} = ${accountsMoney(context, item.effectiveLineTotal, invoice.currency)}${(item.description ?? '').isEmpty ? '' : ' · ${item.description}'}',
        ),
      _InvoicePrintRow(
        AccountsStrings.invoiceGrandTotalLabel,
        accountsMoney(context, invoice.totalAmount, invoice.currency),
      ),
    ],
    emptyText: AccountsStrings.invoicesEmpty,
  );
}

final class _InvoicePrintRow {
  const _InvoicePrintRow(this.label, this.value);

  final String label;
  final String value;
}

class _AccountsInvoiceEditorDialog extends StatefulWidget {
  const _AccountsInvoiceEditorDialog({
    required this.onPersist,
    this.editing,
  });

  final AccountsInvoice? editing;
  final Future<Result<AccountsInvoice>> Function(AccountsInvoiceDraft draft)
  onPersist;

  @override
  State<_AccountsInvoiceEditorDialog> createState() =>
      _AccountsInvoiceEditorDialogState();
}

class _AccountsInvoiceEditorDialogState
    extends State<_AccountsInvoiceEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _payee;
  late final TextEditingController _notes;
  DateTime? _invoiceDate;
  late List<AccountsInvoiceLineItem> _items;
  bool _saving = false;

  bool get _isCreate => widget.editing == null;

  @override
  void initState() {
    super.initState();
    final AccountsInvoice? editing = widget.editing;
    _payee = TextEditingController(text: editing?.payee ?? '');
    _notes = TextEditingController(text: editing?.notes ?? '');
    _invoiceDate = editing?.invoiceDate ?? DateTime.now();
    _items = List<AccountsInvoiceLineItem>.from(
      editing?.items ?? const <AccountsInvoiceLineItem>[],
    );
  }

  @override
  void dispose() {
    _payee.dispose();
    _notes.dispose();
    super.dispose();
  }

  num get _grandTotal {
    num total = 0;
    for (final AccountsInvoiceLineItem item in _items) {
      total += item.effectiveLineTotal;
    }
    return total;
  }

  AppPage<_InvoiceDraftTableRow> get _itemsPage {
    final List<_InvoiceDraftTableRow> rows = <_InvoiceDraftTableRow>[
      for (int index = 0; index < _items.length; index += 1)
        _InvoiceDraftTableRow.item(_items[index], index),
      _InvoiceDraftTableRow.total(itemCount: _items.length),
    ];
    return AppPage<_InvoiceDraftTableRow>(
      items: rows,
      request: AppPageRequest(
        pageSize: rows.isEmpty ? 1 : rows.length,
      ),
      totalItemCount: rows.length,
    );
  }

  Future<void> _openItemDialog({AccountsInvoiceLineItem? editing, int? index}) async {
    final AccountsInvoiceLineItem? result =
        await showAppDialog<AccountsInvoiceLineItem>(
          context: context,
          builder: (_) => _AccountsInvoiceItemDialog(editing: editing),
        );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      if (index != null && index >= 0 && index < _items.length) {
        _items[index] = result;
      } else {
        _items.add(result);
      }
    });
  }

  Future<void> _submit() async {
    if (_saving || !validateAndSaveAppForm(_formKey)) {
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AccountsStrings.invoiceItemsRequired)),
      );
      return;
    }
    final DateTime? date = _invoiceDate;
    if (date == null) {
      return;
    }
    setState(() => _saving = true);
    final Result<AccountsInvoice> result = await widget.onPersist(
      AccountsInvoiceDraft(
        payee: _payee.text.trim(),
        invoiceDate: date,
        notes: accountsEmptyToNull(_notes.text),
        currency: widget.editing?.currency ?? 'UGX',
        status: widget.editing?.status == 'ISSUED' ? 'ISSUED' : 'DRAFT',
        items: List<AccountsInvoiceLineItem>.unmodifiable(_items),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    result.when(
      success: (AccountsInvoice invoice) {
        Navigator.of(context).pop(AccountsInvoiceEditorResult.saved(invoice));
      },
      failure: (AppFailure failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failureMessage(failure))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    final String currency = widget.editing?.currency ?? 'UGX';

    return AppDialog(
      title: Text(
        _isCreate
            ? AccountsStrings.createInvoiceTitle
            : AccountsStrings.editInvoiceTitle,
      ),
      icon: const Icon(Icons.receipt_long_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppCollapsibleSection(
            title: AccountsStrings.invoicePayeeSectionTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppResponsiveFieldRow.two(
                  gap: AppResponsiveFieldRowGap.form,
                  left: AppTextField(
                    controller: _payee,
                    labelText: AccountsStrings.invoicePayeeLabel,
                    isRequired: true,
                    validator: AppValidators.requiredText(
                      AccountsStrings.invoicePayeeRequired,
                    ),
                  ),
                  right: AppDateField(
                    value: _invoiceDate,
                    labelText: AccountsStrings.invoiceDateLabel,
                    isRequired: true,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    currentDate: DateTime.now(),
                    pickerButtonLabel: l10n.hrPickDateAction,
                    invalidDateMessage: l10n.appDateInvalidMessage,
                    enableSpeechToText: false,
                    onChanged: (DateTime? value) =>
                        setState(() => _invoiceDate = value),
                  ),
                ),
                SizedBox(height: theme.appTokens.formGapCompact),
                AppTextField(
                  controller: _notes,
                  labelText: AccountsStrings.notesLabel,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AccountsStrings.invoiceItemsSectionTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
              ),
              AppButton.tertiary(
                leadingIcon: Icons.add_outlined,
                label: AccountsStrings.invoiceAddItemAction,
                dense: true,
                onPressed: _saving ? null : () => unawaited(_openItemDialog()),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          AppListTable<_InvoiceDraftTableRow>(
            page: _itemsPage,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padEmptyRows: false,
            showRowNumbers: false,
            enableExport: false,
            forceCompact: true,
            displayMode: AppListTableDisplayMode.table,
            pinToolbar: false,
            rowColorBuilder: (BuildContext context, _InvoiceDraftTableRow row) {
              if (!row.isTotal) {
                return null;
              }
              return theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              );
            },
            columns: <AppListTableColumn<_InvoiceDraftTableRow>>[
              AppListTableColumn<_InvoiceDraftTableRow>(
                id: 'name',
                label: AccountsStrings.invoiceItemNameLabel,
                alwaysVisible: true,
                preferredWidth: 160,
                sortable: false,
                cellBuilder: (_, _InvoiceDraftTableRow row) {
                  if (row.isTotal) {
                    return Text(
                      AccountsStrings.invoiceGrandTotalLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    );
                  }
                  return Text(
                    row.item!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
                exportValue: (_InvoiceDraftTableRow row) =>
                    row.isTotal
                    ? AccountsStrings.invoiceGrandTotalLabel
                    : row.item!.name,
              ),
              AppListTableColumn<_InvoiceDraftTableRow>(
                id: 'description',
                label: AccountsStrings.invoiceItemDescriptionLabel,
                preferredWidth: 180,
                sortable: false,
                cellBuilder: (_, _InvoiceDraftTableRow row) {
                  if (row.isTotal) {
                    return Text(
                      AccountsStrings.invoiceItemsCountLabel(row.itemCount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    );
                  }
                  final String? description = row.item!.description?.trim();
                  return Text(
                    description != null && description.isNotEmpty
                        ? description
                        : AccountsStrings.unknownValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
                exportValue: (_InvoiceDraftTableRow row) => row.isTotal
                    ? AccountsStrings.invoiceItemsCountLabel(row.itemCount)
                    : row.item!.description ?? '',
              ),
              AppListTableColumn<_InvoiceDraftTableRow>(
                id: 'quantity',
                label: AccountsStrings.invoiceItemQuantityLabel,
                preferredWidth: 90,
                sortable: false,
                cellBuilder: (_, _InvoiceDraftTableRow row) {
                  if (row.isTotal) {
                    return const Text('');
                  }
                  return Text('${row.item!.quantity}');
                },
                exportValue: (_InvoiceDraftTableRow row) =>
                    row.isTotal ? '' : row.item!.quantity.toString(),
              ),
              AppListTableColumn<_InvoiceDraftTableRow>(
                id: 'unit_price',
                label: AccountsStrings.invoiceItemUnitPriceLabel,
                preferredWidth: 110,
                sortable: false,
                cellBuilder:
                    (BuildContext context, _InvoiceDraftTableRow row) {
                  if (row.isTotal) {
                    return const Text('');
                  }
                  return Text(
                    accountsMoney(context, row.item!.unitPrice, currency),
                  );
                },
                exportValue: (_InvoiceDraftTableRow row) =>
                    row.isTotal ? '' : row.item!.unitPrice.toString(),
              ),
              AppListTableColumn<_InvoiceDraftTableRow>(
                id: 'line_total',
                label: AccountsStrings.invoiceItemLineTotalLabel,
                preferredWidth: 120,
                sortable: false,
                cellBuilder:
                    (BuildContext context, _InvoiceDraftTableRow row) {
                  if (row.isTotal) {
                    return Text(
                      accountsMoney(context, _grandTotal, currency),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    );
                  }
                  return Text(
                    accountsMoney(
                      context,
                      row.item!.effectiveLineTotal,
                      currency,
                    ),
                  );
                },
                exportValue: (_InvoiceDraftTableRow row) => row.isTotal
                    ? _grandTotal.toString()
                    : row.item!.effectiveLineTotal.toString(),
              ),
              AppListTableColumn<_InvoiceDraftTableRow>(
                id: 'actions',
                label: AccountsStrings.invoiceActionsColumn,
                alwaysVisible: true,
                exportable: false,
                preferredWidth: 180,
                sortable: false,
                cellBuilder:
                    (BuildContext context, _InvoiceDraftTableRow row) {
                  if (row.isTotal) {
                    return const SizedBox.shrink();
                  }
                  final AccountsInvoiceLineItem item = row.item!;
                  final int index = row.index;
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Wrap(
                      spacing: theme.spacing.sm,
                      children: <Widget>[
                        AppButton.tertiary(
                          leadingIcon: Icons.edit_outlined,
                          label: l10n.commonEditActionLabel,
                          dense: true,
                          onPressed: _saving
                              ? null
                              : () => unawaited(
                                  _openItemDialog(
                                    editing: item,
                                    index: index,
                                  ),
                                ),
                        ),
                        AppButton.tertiary(
                          leadingIcon: Icons.delete_outline,
                          label: AccountsStrings.invoiceRemoveItemAction,
                          dense: true,
                          color: theme.colorScheme.error,
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                  if (index >= 0 && index < _items.length) {
                                    _items.removeAt(index);
                                  }
                                }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            mobileItemBuilder:
                (BuildContext context, _InvoiceDraftTableRow row) {
              if (row.isTotal) {
                return AppListTableMobileItem(
                  title: AccountsStrings.invoiceGrandTotalLabel,
                  caption: AccountsStrings.invoiceItemsCountLabel(
                    row.itemCount,
                  ),
                  meta: <AppListTableMobileMeta>[
                    AppListTableMobileMeta(
                      label: accountsMoney(context, _grandTotal, currency),
                      icon: Icons.payments_outlined,
                    ),
                  ],
                );
              }
              final AccountsInvoiceLineItem item = row.item!;
              return AppListTableMobileItem(
                title: item.name,
                caption: item.description?.trim().isNotEmpty == true
                    ? item.description
                    : null,
                meta: <AppListTableMobileMeta>[
                  AppListTableMobileMeta(
                    label: '${item.quantity}',
                    icon: Icons.numbers_outlined,
                  ),
                  AppListTableMobileMeta(
                    label: accountsMoney(
                      context,
                      item.effectiveLineTotal,
                      currency,
                    ),
                    icon: Icons.payments_outlined,
                  ),
                ],
              );
            },
            itemKeyBuilder: (_InvoiceDraftTableRow row) {
              if (row.isTotal) {
                return const ValueKey<String>('invoice-draft-total');
              }
              final AccountsInvoiceLineItem item = row.item!;
              return ValueKey<String>(
                item.id.isNotEmpty
                    ? item.id
                    : 'draft-${row.index}-${item.name}',
              );
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          leadingIcon: _isCreate
              ? Icons.add_outlined
              : Icons.save_outlined,
          label: _isCreate
              ? AccountsStrings.createInvoiceSubmitAction
              : l10n.commonSaveActionLabel,
          onPressed: _saving ? null : _submit,
        ),
        AppButton.secondary(
          leadingIcon: Icons.close,
          label: l10n.commonCloseActionLabel,
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(
                  const AccountsInvoiceEditorResult.cancelled(),
                ),
        ),
      ],
    );
  }
}

final class _InvoiceDraftTableRow {
  const _InvoiceDraftTableRow.item(this.item, this.index)
    : isTotal = false,
      itemCount = 0;

  const _InvoiceDraftTableRow.total({required this.itemCount})
    : item = null,
      index = -1,
      isTotal = true;

  final AccountsInvoiceLineItem? item;
  final int index;
  final bool isTotal;
  final int itemCount;
}

class _AccountsInvoiceItemDialog extends StatefulWidget {
  const _AccountsInvoiceItemDialog({this.editing});

  final AccountsInvoiceLineItem? editing;

  @override
  State<_AccountsInvoiceItemDialog> createState() =>
      _AccountsInvoiceItemDialogState();
}

class _AccountsInvoiceItemDialogState extends State<_AccountsInvoiceItemDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late final TextEditingController _unitPrice;

  @override
  void initState() {
    super.initState();
    final AccountsInvoiceLineItem? editing = widget.editing;
    _name = TextEditingController(text: editing?.name ?? '');
    _description = TextEditingController(text: editing?.description ?? '');
    _quantity = TextEditingController(
      text: editing == null ? '1' : editing.quantity.toString(),
    );
    _unitPrice = TextEditingController(
      text: editing == null ? '0' : editing.unitPrice.toString(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final num? qty = num.tryParse(_quantity.text.trim());
    final num? price = num.tryParse(_unitPrice.text.trim());
    if (qty == null || qty <= 0 || price == null || price < 0) {
      return;
    }
    Navigator.of(context).pop(
      AccountsInvoiceLineItem(
        id: widget.editing?.id ?? '',
        name: _name.text.trim(),
        description: accountsEmptyToNull(_description.text),
        quantity: qty,
        unitPrice: price,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: Text(
        widget.editing == null
            ? AccountsStrings.createItemTitle
            : AccountsStrings.editItemTitle,
      ),
      icon: const Icon(Icons.post_add_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _name,
            labelText: AccountsStrings.invoiceItemNameLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              AccountsStrings.invoiceItemNameRequired,
            ),
          ),
          AppTextField(
            controller: _description,
            labelText: AccountsStrings.invoiceItemDescriptionLabel,
            maxLines: 2,
          ),
          AppTextField(
            controller: _quantity,
            labelText: AccountsStrings.invoiceItemQuantityLabel,
            isRequired: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            validator: (String? value) {
              final num? qty = num.tryParse((value ?? '').trim());
              if (qty == null || qty <= 0) {
                return AccountsStrings.invoiceItemQuantityRequired;
              }
              return null;
            },
          ),
          AppTextField(
            controller: _unitPrice,
            labelText: AccountsStrings.invoiceItemUnitPriceLabel,
            isRequired: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            validator: (String? value) {
              final num? price = num.tryParse((value ?? '').trim());
              if (price == null || price < 0) {
                return AccountsStrings.invoiceItemUnitPriceRequired;
              }
              return null;
            },
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCloseActionLabel,
        submitLabel: l10n.commonSaveActionLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

