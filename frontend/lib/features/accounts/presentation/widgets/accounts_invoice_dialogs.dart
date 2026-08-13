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
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

enum AccountsInvoiceDialogOutcome { cancelled, saved }

Future<AccountsInvoiceDialogOutcome> showAccountsInvoiceEditorDialog({
  required BuildContext context,
  required WidgetRef ref,
  AccountsInvoice? editing,
}) async {
  if (!canWriteAccounts(ref.read(appAccessPolicyProvider))) {
    return AccountsInvoiceDialogOutcome.cancelled;
  }
  final AccountsInvoiceDialogOutcome? result =
      await showAppWorkspaceActionDialog<AccountsInvoiceDialogOutcome>(
        context: context,
        title: Text(
          editing == null
              ? AccountsStrings.createInvoiceTitle
              : AccountsStrings.editInvoiceTitle,
        ),
        content: _AccountsInvoiceEditor(
          editing: editing,
          onSubmit: (AccountsInvoiceDraft draft) async {
            final session = ref.read(sessionStateProvider).session?.user;
            final String? tenantId =
                session?.tenantId ??
                ref.read(appAccessPolicyProvider).tenantId;
            if (tenantId == null || tenantId.trim().isEmpty) {
              return AppFailure.validation(
                validationFields: <String>{'tenant_id'},
              );
            }
            final Map<String, Object?> payload = draft.toPayload(
              tenantId: tenantId,
              facilityId:
                  session?.facilityId ??
                  ref.read(appAccessPolicyProvider).facilityId,
            );
            final Result<AccountsInvoice> result = editing == null
                ? await ref
                      .read(accountsInvoiceRepositoryProvider)
                      .createInvoice(payload)
                : await ref
                      .read(accountsInvoiceRepositoryProvider)
                      .updateInvoice(editing.id, payload);
            return result.when(
              success: (_) {
                ref.read(accountsInvoicesCountProvider.notifier).state = null;
                return null;
              },
              failure: (AppFailure failure) => failure,
            );
          },
        ),
      );
  return result ?? AccountsInvoiceDialogOutcome.cancelled;
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
          final accessPolicy = dialogRef.watch(appAccessPolicyProvider);
          final bool canWrite = canWriteAccounts(accessPolicy);
          final bool canPrint = canPrintAccountsWorkspace(accessPolicy);
          final ThemeData theme = Theme.of(context);
          return AppDialog(
            title: const Text(AccountsStrings.invoiceDetailsTitle),
            scrollable: true,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  current.effectiveNumber,
                  style: theme.textTheme.titleMedium,
                ),
                SizedBox(height: theme.spacing.sm),
                Text('${AccountsStrings.invoicePayeeLabel}: ${current.payee}'),
                Text(
                  '${AccountsStrings.invoiceDateLabel}: ${accountsDateTime(context, current.invoiceDate)}',
                ),
                Text(
                  '${AccountsStrings.statusColumn}: ${accountsStatusLabel(current.status)}',
                ),
                Text(
                  '${AccountsStrings.invoiceGrandTotalLabel}: ${accountsMoney(context, current.totalAmount, current.currency)}',
                ),
                if ((current.reference ?? '').isNotEmpty)
                  Text(
                    '${AccountsStrings.invoiceReferenceLabel}: ${current.reference}',
                  ),
                if ((current.notes ?? '').isNotEmpty)
                  Text('${AccountsStrings.notesLabel}: ${current.notes}'),
                if (current.isVoided && (current.voidReason ?? '').isNotEmpty)
                  Text(
                    '${AccountsStrings.reasonLabel}: ${current.voidReason}',
                  ),
                SizedBox(height: theme.spacing.md),
                Text(
                  AccountsStrings.invoiceItemNameLabel,
                  style: theme.textTheme.titleSmall,
                ),
                SizedBox(height: theme.spacing.sm),
                for (final AccountsInvoiceLineItem item in current.items)
                  Padding(
                    padding: EdgeInsets.only(bottom: theme.spacing.xs),
                    child: Text(
                      '${item.name} · ${item.quantity} × ${accountsMoney(context, item.unitPrice, current.currency)} = ${accountsMoney(context, item.effectiveLineTotal, current.currency)}',
                    ),
                  ),
              ],
            ),
            actions: <Widget>[
              if (canPrint)
                AppButton.secondary(
                  leadingIcon: Icons.print_outlined,
                  label: context.l10n.commonPrintActionLabel,
                  onPressed: () => printAccountsListTable<AccountsInvoice>(
                    ref: dialogRef,
                    context: context,
                    title: AccountsStrings.invoicesLabel,
                    columns: <AppListTableColumn<AccountsInvoice>>[
                      AppListTableColumn<AccountsInvoice>(
                        id: 'invoice',
                        label: AccountsStrings.invoiceNumberColumn,
                        cellBuilder: (_, AccountsInvoice row) =>
                            Text(row.effectiveNumber),
                        exportValue: (AccountsInvoice row) =>
                            row.effectiveNumber,
                      ),
                      AppListTableColumn<AccountsInvoice>(
                        id: 'payee',
                        label: AccountsStrings.invoicePayeeColumn,
                        cellBuilder: (_, AccountsInvoice row) =>
                            Text(row.payee),
                        exportValue: (AccountsInvoice row) => row.payee,
                      ),
                      AppListTableColumn<AccountsInvoice>(
                        id: 'total',
                        label: AccountsStrings.invoiceTotalColumn,
                        cellBuilder: (_, AccountsInvoice row) => Text(
                          accountsMoney(context, row.totalAmount, row.currency),
                        ),
                        exportValue: (AccountsInvoice row) =>
                            row.totalAmount.toString(),
                      ),
                    ],
                    items: <AccountsInvoice>[current],
                    emptyText: AccountsStrings.invoicesEmpty,
                  ),
                ),
              if (canWrite && current.canEdit)
                AppButton.secondary(
                  leadingIcon: Icons.edit_outlined,
                  label: context.l10n.commonEditActionLabel,
                  onPressed: () async {
                    final AccountsInvoiceDialogOutcome outcome =
                        await showAccountsInvoiceEditorDialog(
                          context: context,
                          ref: dialogRef,
                          editing: current,
                        );
                    if (outcome == AccountsInvoiceDialogOutcome.saved) {
                      final Result<AccountsInvoice> refreshed = await dialogRef
                          .read(accountsInvoiceRepositoryProvider)
                          .getInvoice(current.id);
                      refreshed.when(
                        success: (AccountsInvoice value) => current = value,
                        failure: (_) {},
                      );
                      await onChanged();
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).maybePop();
                      }
                    }
                  },
                ),
              if (canWrite && current.canVoid)
                AppButton.tertiary(
                  leadingIcon: Icons.delete_outline,
                  label: context.l10n.commonDeleteActionLabel,
                  color: theme.colorScheme.error,
                  onPressed: () async {
                    final AccountsReasonDraft? draft =
                        await showAppDialog<AccountsReasonDraft>(
                          context: context,
                          builder: (_) => AccountsReasonForm(
                            dialogTitle: const Text(
                              AccountsStrings.invoiceVoidTitle,
                            ),
                            submitLabel: context.l10n.commonDeleteActionLabel,
                          ),
                        );
                    if (draft == null) return;
                    final Result<AccountsInvoice> voided = await dialogRef
                        .read(accountsInvoiceRepositoryProvider)
                        .voidInvoice(
                          current.id,
                          reason: draft.reason,
                          notes: draft.notes,
                        );
                    final AppFailure? failure = voided.when(
                      success: (_) => null,
                      failure: (AppFailure f) => f,
                    );
                    if (!context.mounted) return;
                    if (failure != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.failureMessage(failure))),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(AccountsStrings.invoiceVoided),
                      ),
                    );
                    dialogRef.read(accountsInvoicesCountProvider.notifier).state =
                        null;
                    await onChanged();
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).maybePop();
                    }
                  },
                ),
              AppButton.secondary(
                leadingIcon: Icons.close,
                label: context.l10n.commonCloseActionLabel,
                onPressed: () => Navigator.of(dialogContext).maybePop(),
              ),
            ],
          );
        },
      );
    },
  );
}

class _AccountsInvoiceEditor extends StatefulWidget {
  const _AccountsInvoiceEditor({required this.onSubmit, this.editing});

  final AccountsInvoice? editing;
  final Future<AppFailure?> Function(AccountsInvoiceDraft draft) onSubmit;

  @override
  State<_AccountsInvoiceEditor> createState() => _AccountsInvoiceEditorState();
}

class _LineDraft {
  _LineDraft({
    TextEditingController? name,
    TextEditingController? description,
    TextEditingController? quantity,
    TextEditingController? unitPrice,
  }) : name = name ?? TextEditingController(),
       description = description ?? TextEditingController(),
       quantity = quantity ?? TextEditingController(text: '1'),
       unitPrice = unitPrice ?? TextEditingController(text: '0');

  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  void dispose() {
    name.dispose();
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

class _AccountsInvoiceEditorState extends State<_AccountsInvoiceEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _payee;
  late final TextEditingController _reference;
  late final TextEditingController _notes;
  late final TextEditingController _currency;
  DateTime? _invoiceDate;
  late List<_LineDraft> _lines;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final AccountsInvoice? editing = widget.editing;
    _payee = TextEditingController(text: editing?.payee ?? '');
    _reference = TextEditingController(text: editing?.reference ?? '');
    _notes = TextEditingController(text: editing?.notes ?? '');
    _currency = TextEditingController(text: editing?.currency ?? 'UGX');
    _invoiceDate = editing?.invoiceDate ?? DateTime.now();
    if (editing != null && editing.items.isNotEmpty) {
      _lines = editing.items
          .map(
            (AccountsInvoiceLineItem item) => _LineDraft(
              name: TextEditingController(text: item.name),
              description: TextEditingController(text: item.description ?? ''),
              quantity: TextEditingController(text: item.quantity.toString()),
              unitPrice: TextEditingController(text: item.unitPrice.toString()),
            ),
          )
          .toList();
    } else {
      _lines = <_LineDraft>[_LineDraft()];
    }
  }

  @override
  void dispose() {
    _payee.dispose();
    _reference.dispose();
    _notes.dispose();
    _currency.dispose();
    for (final _LineDraft line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  num get _grandTotal {
    num total = 0;
    for (final _LineDraft line in _lines) {
      final num qty = num.tryParse(line.quantity.text.trim()) ?? 0;
      final num price = num.tryParse(line.unitPrice.text.trim()) ?? 0;
      total += qty * price;
    }
    return total;
  }

  Future<void> _submit() async {
    if (_saving || !validateAndSaveAppForm(_formKey)) return;
    final List<AccountsInvoiceLineItem> items = <AccountsInvoiceLineItem>[];
    for (final _LineDraft line in _lines) {
      final String name = line.name.text.trim();
      final num qty = num.tryParse(line.quantity.text.trim()) ?? 0;
      final num price = num.tryParse(line.unitPrice.text.trim()) ?? 0;
      if (name.isEmpty || qty <= 0 || price < 0) {
        continue;
      }
      items.add(
        AccountsInvoiceLineItem(
          name: name,
          description: accountsEmptyToNull(line.description.text),
          quantity: qty,
          unitPrice: price,
        ),
      );
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AccountsStrings.invoiceItemsRequired)),
      );
      return;
    }
    final DateTime? date = _invoiceDate;
    if (date == null) return;
    setState(() => _saving = true);
    final AppFailure? failure = await widget.onSubmit(
      AccountsInvoiceDraft(
        payee: _payee.text.trim(),
        invoiceDate: date,
        reference: accountsEmptyToNull(_reference.text),
        notes: accountsEmptyToNull(_notes.text),
        currency: _currency.text.trim().isEmpty
            ? 'UGX'
            : _currency.text.trim().toUpperCase(),
        status: widget.editing?.status == 'ISSUED' ? 'ISSUED' : 'DRAFT',
        items: items,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
      return;
    }
    Navigator.of(context).pop(AccountsInvoiceDialogOutcome.saved);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      children: <Widget>[
        AppTextField(
          controller: _payee,
          labelText: AccountsStrings.invoicePayeeLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            AccountsStrings.invoicePayeeRequired,
          ),
        ),
        AppDateField(
          value: _invoiceDate,
          labelText: AccountsStrings.invoiceDateLabel,
          isRequired: true,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          enableSpeechToText: false,
          onChanged: (DateTime? value) => setState(() => _invoiceDate = value),
        ),
        AppTextField(
          controller: _reference,
          labelText: AccountsStrings.invoiceReferenceLabel,
        ),
        AppTextField(
          controller: _currency,
          labelText: AccountsStrings.invoiceCurrencyLabel,
        ),
        AppTextField(
          controller: _notes,
          labelText: AccountsStrings.notesLabel,
          maxLines: 2,
        ),
        SizedBox(height: theme.spacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AccountsStrings.invoiceItemNameLabel,
                style: theme.textTheme.titleSmall,
              ),
            ),
            AppButton.tertiary(
              leadingIcon: Icons.add_outlined,
              label: AccountsStrings.invoiceAddItemAction,
              dense: true,
              onPressed: () => setState(() => _lines.add(_LineDraft())),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        for (int i = 0; i < _lines.length; i++) ...<Widget>[
          AppTextField(
            controller: _lines[i].name,
            labelText: AccountsStrings.invoiceItemNameLabel,
            isRequired: true,
          ),
          AppTextField(
            controller: _lines[i].description,
            labelText: AccountsStrings.invoiceItemDescriptionLabel,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _lines[i].quantity,
                  labelText: AccountsStrings.invoiceItemQuantityLabel,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: AppTextField(
                  controller: _lines[i].unitPrice,
                  labelText: AccountsStrings.invoiceItemUnitPriceLabel,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (_lines.length > 1)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton.tertiary(
                leadingIcon: Icons.remove_circle_outline,
                label: AccountsStrings.invoiceRemoveItemAction,
                dense: true,
                color: theme.colorScheme.error,
                onPressed: () {
                  setState(() {
                    _lines.removeAt(i).dispose();
                  });
                },
              ),
            ),
          SizedBox(height: theme.spacing.sm),
        ],
        Text(
          '${AccountsStrings.invoiceGrandTotalLabel}: ${accountsMoney(context, _grandTotal, _currency.text)}',
          style: theme.textTheme.titleSmall,
        ),
        SizedBox(height: theme.spacing.md),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AppButton.primary(
            leadingIcon: Icons.save_outlined,
            label: l10n.commonSaveActionLabel,
            onPressed: _saving ? null : _submit,
          ),
        ),
      ],
    );
  }
}
