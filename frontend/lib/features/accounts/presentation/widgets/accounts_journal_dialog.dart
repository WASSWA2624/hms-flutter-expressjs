import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_form_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

Future<AccountsJournalDraft?> showAccountsJournalDialog(
  BuildContext context,
) {
  return showAppDialog<AccountsJournalDraft>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AccountsJournalDialog(),
  );
}

class AccountsJournalDialog extends StatefulWidget {
  const AccountsJournalDialog({super.key});

  @override
  State<AccountsJournalDialog> createState() => _AccountsJournalDialogState();
}

class _AccountsJournalDialogState extends State<AccountsJournalDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _periodController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _date;
  String? _balanceError;
  final List<_JournalLineControllers> _lines = <_JournalLineControllers>[
    _JournalLineControllers(),
    _JournalLineControllers(),
  ];

  @override
  void dispose() {
    _periodController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    for (final _JournalLineControllers line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() => _lines.add(_JournalLineControllers()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 2) {
      return;
    }
    setState(() {
      _lines.removeAt(index).dispose();
      _balanceError = null;
    });
  }

  num _parseAmount(String value) {
    final String normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) {
      return 0;
    }
    return num.tryParse(normalized) ?? 0;
  }

  bool _validateBalance() {
    num debitTotal = 0;
    num creditTotal = 0;
    for (final _JournalLineControllers line in _lines) {
      debitTotal += _parseAmount(line.debitController.text);
      creditTotal += _parseAmount(line.creditController.text);
    }
    if (debitTotal != creditTotal) {
      setState(
        () => _balanceError = AccountsStrings.journalBalanceValidation,
      );
      return false;
    }
    setState(() => _balanceError = null);
    return true;
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey) || !_validateBalance()) {
      return;
    }
    final List<AccountsJournalLineDraft> lines = <AccountsJournalLineDraft>[];
    for (final _JournalLineControllers line in _lines) {
      final String accountId = line.accountController.text.trim();
      if (accountId.isEmpty) {
        continue;
      }
      lines.add(
        AccountsJournalLineDraft(
          accountId: accountId,
          debit: _parseAmount(line.debitController.text),
          credit: _parseAmount(line.creditController.text),
          memo: accountsEmptyToNull(line.memoController.text),
        ),
      );
    }
    if (lines.length < 2) {
      return;
    }
    Navigator.of(context).pop(
      AccountsJournalDraft(
        date: _date ?? DateTime.now(),
        periodLabel: accountsEmptyToNull(_periodController.text),
        source: accountsEmptyToNull(_sourceController.text),
        lines: lines,
        notes: accountsEmptyToNull(_notesController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 10);
    final DateTime lastDate = DateTime(now.year + 1);

    return AppDialog(
      title: const Text(AccountsStrings.journalAction),
      icon: const Icon(Icons.receipt_long_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppDateField(
            value: _date,
            firstDate: firstDate,
            lastDate: lastDate,
            pickerButtonLabel: l10n.appDateRangePickDateAction,
            invalidDateMessage: l10n.opdInvalidDateMessage,
            labelText: AccountsStrings.journalDateLabel,
            hintText: AccountsStrings.journalDateHint,
            onChanged: (DateTime? value) => setState(() => _date = value),
          ),
          AppTextField(
            controller: _periodController,
            labelText: AccountsStrings.periodColumn,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: _sourceController,
            labelText: AccountsStrings.sourceColumn,
            textInputAction: TextInputAction.next,
          ),
          Text(
            AccountsStrings.journalLinesLabel,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          for (int index = 0; index < _lines.length; index++)
            _JournalLineRow(
              index: index,
              line: _lines[index],
              canRemove: _lines.length > 2,
              onRemove: () => _removeLine(index),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add_outlined),
              label: const Text(AccountsStrings.journalAddLineAction),
            ),
          ),
          if (_balanceError != null) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            Text(
              _balanceError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          AppTextField(
            controller: _notesController,
            labelText: AccountsStrings.notesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.commonSaveActionLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class _JournalLineControllers {
  _JournalLineControllers()
      : accountController = TextEditingController(),
        debitController = TextEditingController(),
        creditController = TextEditingController(),
        memoController = TextEditingController();

  final TextEditingController accountController;
  final TextEditingController debitController;
  final TextEditingController creditController;
  final TextEditingController memoController;

  void dispose() {
    accountController.dispose();
    debitController.dispose();
    creditController.dispose();
    memoController.dispose();
  }
}

class _JournalLineRow extends StatelessWidget {
  const _JournalLineRow({
    required this.index,
    required this.line,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _JournalLineControllers line;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${AccountsStrings.journalLineLabel} ${index + 1}',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (canRemove)
                IconButton(
                  tooltip: AccountsStrings.journalRemoveLineAction,
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
            ],
          ),
          AppTextField(
            controller: line.accountController,
            labelText: AccountsStrings.journalAccountIdLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              AccountsStrings.journalAccountIdLabel,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: line.debitController,
                  labelText: AccountsStrings.debitColumn,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+')),
                  ],
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: AppTextField(
                  controller: line.creditController,
                  labelText: AccountsStrings.creditColumn,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+')),
                  ],
                ),
              ),
            ],
          ),
          AppTextField(
            controller: line.memoController,
            labelText: AccountsStrings.journalMemoLabel,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
