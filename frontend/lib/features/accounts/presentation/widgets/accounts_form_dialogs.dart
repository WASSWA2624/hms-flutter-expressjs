import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

String? accountsEmptyToNull(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

/// Result from optional-notes dialogs (Post / Approve / Send).
final class AccountsOptionalNotesResult {
  const AccountsOptionalNotesResult({this.notes});

  final String? notes;
}

class AccountsNotesForm extends StatefulWidget {
  const AccountsNotesForm({
    super.key,
    required this.dialogTitle,
    this.dialogIcon,
    required this.submitLabel,
    this.email = false,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final String submitLabel;
  final bool email;

  @override
  State<AccountsNotesForm> createState() => _AccountsNotesFormState();
}

class _AccountsNotesFormState extends State<AccountsNotesForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      AccountsOptionalNotesResult(notes: accountsEmptyToNull(_controller.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _controller,
            labelText: widget.email
                ? context.l10n.billingRecipientEmailLabel
                : AccountsStrings.notesLabel,
            keyboardType: widget.email ? TextInputType.emailAddress : null,
            maxLines: widget.email ? 1 : 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class AccountsReasonForm extends StatefulWidget {
  const AccountsReasonForm({
    super.key,
    required this.dialogTitle,
    this.dialogIcon,
    required this.submitLabel,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final String submitLabel;

  @override
  State<AccountsReasonForm> createState() => _AccountsReasonFormState();
}

class _AccountsReasonFormState extends State<AccountsReasonForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      AccountsReasonDraft(
        reason: _reasonController.text.trim(),
        notes: accountsEmptyToNull(_notesController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _reasonController,
            labelText: AccountsStrings.reasonLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              AccountsStrings.reasonValidation,
            ),
          ),
          AppTextField(
            controller: _notesController,
            labelText: AccountsStrings.notesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.save_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class AccountsClosePeriodForm extends StatefulWidget {
  const AccountsClosePeriodForm({
    super.key,
    required this.dialogTitle,
    this.dialogIcon,
    this.period,
    this.submitLabel = AccountsStrings.closeAction,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;
  final AccountsFiscalPeriod? period;
  final String submitLabel;

  @override
  State<AccountsClosePeriodForm> createState() =>
      _AccountsClosePeriodFormState();
}

class _AccountsClosePeriodFormState extends State<AccountsClosePeriodForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    Navigator.of(context).pop(
      AccountsNotesDraft(notes: accountsEmptyToNull(_notesController.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AccountsFiscalPeriod? period = widget.period;

    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          if (period != null) ...<Widget>[
            Text(
              AccountsStrings.periodChecklistTitle,
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              '${AccountsStrings.periodUnpostedLabel}: ${period.unpostedJournalCount}',
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              '${AccountsStrings.periodPendingApprovalsLabel}: ${period.pendingApprovalsCount}',
            ),
            SizedBox(height: theme.spacing.md),
          ],
          AppTextField(
            controller: _notesController,
            labelText: AccountsStrings.notesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: widget.submitLabel,
        submitIcon: Icons.lock_clock_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}

class AccountsOpenPeriodForm extends StatefulWidget {
  const AccountsOpenPeriodForm({
    super.key,
    required this.dialogTitle,
    this.dialogIcon,
  });

  final Widget dialogTitle;
  final Widget? dialogIcon;

  @override
  State<AccountsOpenPeriodForm> createState() => _AccountsOpenPeriodFormState();
}

class _AccountsOpenPeriodFormState extends State<AccountsOpenPeriodForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _labelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final DateTime? start = _startDate;
    final DateTime? end = _endDate;
    if (start == null || end == null) {
      return;
    }
    Navigator.of(context).pop(
      AccountsOpenPeriodDraft(
        label: _labelController.text.trim(),
        startDate: start,
        endDate: end,
        notes: accountsEmptyToNull(_notesController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final DateTime firstDate = DateTime(2000);
    final DateTime lastDate = DateTime(2100);

    return AppDialog(
      title: widget.dialogTitle,
      icon: widget.dialogIcon,
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _labelController,
            labelText: AccountsStrings.periodLabelField,
            isRequired: true,
            validator: AppValidators.requiredText(
              AccountsStrings.periodLabelRequired,
            ),
          ),
          AppDateField(
            value: _startDate,
            labelText: AccountsStrings.periodStartField,
            isRequired: true,
            firstDate: firstDate,
            lastDate: lastDate,
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.hrPickDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            enableSpeechToText: false,
            validator: (DateTime? value) {
              if (value == null) {
                return AccountsStrings.periodDatesRequired;
              }
              return null;
            },
            onChanged: (DateTime? value) {
              setState(() => _startDate = value);
            },
          ),
          AppDateField(
            value: _endDate,
            labelText: AccountsStrings.periodEndField,
            isRequired: true,
            firstDate: firstDate,
            lastDate: lastDate,
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.hrPickDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            enableSpeechToText: false,
            validator: (DateTime? value) {
              if (value == null) {
                return AccountsStrings.periodDatesRequired;
              }
              return null;
            },
            onChanged: (DateTime? value) {
              setState(() => _endDate = value);
            },
          ),
          AppTextField(
            controller: _notesController,
            labelText: AccountsStrings.notesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: context.l10n.commonCancelActionLabel,
        submitLabel: AccountsStrings.openAction,
        submitIcon: Icons.lock_open_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}
