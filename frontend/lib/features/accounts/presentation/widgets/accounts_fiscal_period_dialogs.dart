import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_fiscal_period_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_fiscal_period.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_fiscal_period_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_detail_fact_lines.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Bumped after every fiscal period mutation so the tab badge, the workspace
/// summary, and any dependent period pickers refetch.
final accountsFiscalPeriodRevisionProvider = StateProvider<int>((Ref ref) => 0);

/// Filtered fiscal period count owned by the panel; null falls back to the
/// workspace summary so the badge never reflects only the painted page.
final accountsFiscalPeriodCountProvider = StateProvider<int?>((Ref ref) => null);

enum AccountsFiscalPeriodDialogMode { create, edit, clone }

/// Create / edit / clone form for a fiscal period.
///
/// Returns `true` when the record was written.
Future<bool> showAccountsFiscalPeriodDialog({
  required BuildContext context,
  required WidgetRef ref,
  AccountsFiscalPeriodDialogMode mode = AccountsFiscalPeriodDialogMode.create,
  AccountsFiscalPeriod? source,
}) async {
  if (!canWriteAccountsFiscalPeriods(ref.read(appAccessPolicyProvider))) {
    return false;
  }
  final String title = switch (mode) {
    AccountsFiscalPeriodDialogMode.create => AccountsStrings.fiscalCreateTitle,
    AccountsFiscalPeriodDialogMode.edit => AccountsStrings.fiscalEditTitle,
    AccountsFiscalPeriodDialogMode.clone => AccountsStrings.fiscalCloneTitle,
  };

  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(title),
    content: _AccountsFiscalPeriodForm(mode: mode, source: source),
  );

  if (saved == true) {
    ref
            .read<StateController<int>>(
              accountsFiscalPeriodRevisionProvider.notifier,
            )
            .state++;
  }
  return saved ?? false;
}

class _AccountsFiscalPeriodForm extends ConsumerStatefulWidget {
  const _AccountsFiscalPeriodForm({required this.mode, this.source});

  final AccountsFiscalPeriodDialogMode mode;
  final AccountsFiscalPeriod? source;

  @override
  ConsumerState<_AccountsFiscalPeriodForm> createState() =>
      _AccountsFiscalPeriodFormState();
}

class _AccountsFiscalPeriodFormState
    extends ConsumerState<_AccountsFiscalPeriodForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fiscalYearController;
  late final TextEditingController _periodNoController;
  late final TextEditingController _periodNameController;
  late final TextEditingController _moduleController;
  late final TextEditingController _notesController;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _openDate;
  DateTime? _softCloseDate;
  DateTime? _closeDate;
  bool _isSubmitting = false;
  AppFailure? _failure;

  bool get _isEdit => widget.mode == AccountsFiscalPeriodDialogMode.edit;

  @override
  void initState() {
    super.initState();
    final AccountsFiscalPeriod? source = widget.source;
    _fiscalYearController = TextEditingController(
      text: source?.fiscalYear ?? '',
    );
    // A clone must not reuse the source period number; it would collide.
    _periodNoController = TextEditingController(
      text: _isEdit ? '${source?.periodNo ?? ''}' : '',
    );
    _periodNameController = TextEditingController(
      text: source?.periodName ?? '',
    );
    _moduleController = TextEditingController(text: source?.module ?? 'ALL');
    _notesController = TextEditingController(text: source?.notes ?? '');
    if (_isEdit) {
      _startDate = source?.startDate;
      _endDate = source?.endDate;
      _openDate = source?.openDate;
      _softCloseDate = source?.softCloseDate;
      _closeDate = source?.closeDate;
    }
  }

  @override
  void dispose() {
    _fiscalYearController.dispose();
    _periodNoController.dispose();
    _periodNameController.dispose();
    _moduleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppTextField(
          controller: _fiscalYearController,
          labelText: AccountsStrings.fiscalYearLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            AccountsStrings.fiscalRequiredField,
          ),
        ),
        AppTextField(
          controller: _periodNoController,
          labelText: AccountsStrings.fiscalPeriodNoLabel,
          isRequired: true,
          keyboardType: TextInputType.number,
          validator: _validatePeriodNo,
        ),
        AppTextField(
          controller: _periodNameController,
          labelText: AccountsStrings.fiscalPeriodNameLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            AccountsStrings.fiscalRequiredField,
          ),
        ),
        AppDateField(
          value: _startDate,
          labelText: AccountsStrings.fiscalStartDateLabel,
          isRequired: true,
          pickerButtonLabel: l10n.housekeepingPickDateAction,
          invalidDateMessage: AccountsStrings.fiscalRequiredField,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onChanged: (DateTime? value) => setState(() => _startDate = value),
        ),
        AppDateField(
          value: _endDate,
          labelText: AccountsStrings.fiscalEndDateLabel,
          isRequired: true,
          pickerButtonLabel: l10n.housekeepingPickDateAction,
          invalidDateMessage: AccountsStrings.fiscalRequiredField,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onChanged: (DateTime? value) => setState(() => _endDate = value),
        ),
        AppTextField(
          controller: _moduleController,
          labelText: AccountsStrings.fiscalModuleLabel,
        ),
        AppDateField(
          value: _openDate,
          labelText: AccountsStrings.fiscalOpenDateLabel,
          pickerButtonLabel: l10n.housekeepingPickDateAction,
          invalidDateMessage: AccountsStrings.fiscalRequiredField,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onChanged: (DateTime? value) => setState(() => _openDate = value),
        ),
        AppDateField(
          value: _softCloseDate,
          labelText: AccountsStrings.fiscalSoftCloseDateLabel,
          pickerButtonLabel: l10n.housekeepingPickDateAction,
          invalidDateMessage: AccountsStrings.fiscalRequiredField,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onChanged: (DateTime? value) => setState(() => _softCloseDate = value),
        ),
        AppDateField(
          value: _closeDate,
          labelText: AccountsStrings.fiscalCloseDateLabel,
          pickerButtonLabel: l10n.housekeepingPickDateAction,
          invalidDateMessage: AccountsStrings.fiscalRequiredField,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onChanged: (DateTime? value) => setState(() => _closeDate = value),
        ),
        AppTextField(
          controller: _notesController,
          labelText: AccountsStrings.fiscalNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: switch (widget.mode) {
            AccountsFiscalPeriodDialogMode.create =>
              AccountsStrings.fiscalCreateAction,
            AccountsFiscalPeriodDialogMode.edit =>
              AccountsStrings.fiscalSaveAction,
            AccountsFiscalPeriodDialogMode.clone =>
              AccountsStrings.fiscalCloneAction,
          },
          submitIcon: Icons.save_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  String? _validatePeriodNo(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return AccountsStrings.fiscalRequiredField;
    }
    final int? parsed = int.tryParse(raw);
    if (parsed == null || parsed < 1 || parsed > 366) {
      return AccountsStrings.fiscalPeriodNoInvalid;
    }
    return null;
  }

  /// Mirrors the server ordering rules so a bad range never round-trips.
  String? _dateOrderingError() {
    final DateTime? start = _startDate;
    final DateTime? end = _endDate;
    if (start == null || end == null) {
      return AccountsStrings.fiscalRequiredField;
    }
    if (end.isBefore(start)) {
      return AccountsStrings.fiscalEndBeforeStart;
    }
    final List<DateTime?> milestones = <DateTime?>[
      _openDate,
      _softCloseDate,
      _closeDate,
    ];
    DateTime? previous;
    for (final DateTime? milestone in milestones) {
      if (milestone == null) {
        continue;
      }
      if (previous != null && milestone.isBefore(previous)) {
        return AccountsStrings.fiscalMilestoneOutOfOrder;
      }
      previous = milestone;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? dateError = _dateOrderingError();
    if (dateError != null) {
      setState(
        () => _failure = AppFailure.validation(detailMessage: dateError),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final String module = _moduleController.text.trim().toUpperCase();
    final String notes = _notesController.text.trim();
    final Map<String, Object?> payload = <String, Object?>{
      'fiscal_year': _fiscalYearController.text.trim(),
      'period_no': int.parse(_periodNoController.text.trim()),
      'period_name': _periodNameController.text.trim(),
      'start_date': _startDate!.toUtc().toIso8601String(),
      'end_date': _endDate!.toUtc().toIso8601String(),
      'module': module.isEmpty ? 'ALL' : module,
      'open_date': _openDate?.toUtc().toIso8601String(),
      'soft_close_date': _softCloseDate?.toUtc().toIso8601String(),
      'close_date': _closeDate?.toUtc().toIso8601String(),
      'notes': notes.isEmpty ? null : notes,
      if (_isEdit) 'version': widget.source?.version,
    };

    final AccountsFiscalPeriodRepository repository = ref.read(
      accountsFiscalPeriodRepositoryProvider,
    );
    final Result<AccountsFiscalPeriod> result = _isEdit
        ? await repository.updatePeriod(widget.source!.humanFriendlyId, payload)
        : await repository.createPeriod(payload);

    if (!mounted) {
      return;
    }
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isSubmitting = false;
        });
      },
    );
  }
}

/// Read-only detail view: summary, related records, attachments, activity.
Future<void> showAccountsFiscalPeriodDetail({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsFiscalPeriod period,
  Future<void> Function()? onChanged,
}) async {
  await showAppWorkspaceDetailDrawer<void>(
    context: context,
    title: const Text(AccountsStrings.fiscalDetailTitle),
    child: _AccountsFiscalPeriodDetail(period: period, onChanged: onChanged),
  );
}

class _AccountsFiscalPeriodDetail extends ConsumerWidget {
  const _AccountsFiscalPeriodDetail({required this.period, this.onChanged});

  final AccountsFiscalPeriod period;
  final Future<void> Function()? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    period.periodName,
                    style: theme.textTheme.titleLarge,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: accountsFiscalPeriodStatusLabel(period.status),
                      tone: accountsFiscalPeriodStatusTone(period.status),
                      icon: accountsFiscalPeriodStatusIcon(period.status),
                    ),
                  ),
                ],
              ),
            ),
            AppCopyableIdentifier(
              value:
                  accountsPublicLabel(period.humanFriendlyId) ??
                  AccountsStrings.unknownValue,
              tooltip: AccountsStrings.fiscalReferenceColumn,
            ),
          ],
        ),
        if (period.isLocked) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner.message(
            message: AccountsStrings.fiscalLockedNotice,
            variant: AppFormInformationVariant.warning,
            icon: AppActionIcons.warning,
          ),
        ],
        SizedBox(height: theme.spacing.md),
        AppCollapsibleSection(
          title: AccountsStrings.fiscalSummarySection,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalYearColumn,
                value: period.fiscalYear,
                icon: Icons.calendar_today_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalPeriodNoColumn,
                value: '${period.periodNo}',
                icon: Icons.tag_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalStartDateColumn,
                value: accountsDate(context, period.startDate),
                icon: Icons.event_available_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalEndDateColumn,
                value: accountsDate(context, period.endDate),
                icon: Icons.event_busy_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalEntityAndFacilityColumn,
                value:
                    period.entityAndFacility ?? AccountsStrings.unknownValue,
                icon: Icons.apartment_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalModuleColumn,
                value: period.module ?? AccountsStrings.unknownValue,
                icon: Icons.widgets_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalOpenDateColumn,
                value: accountsDate(context, period.openDate),
                icon: Icons.lock_open_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalSoftCloseDateColumn,
                value: accountsDate(context, period.softCloseDate),
                icon: Icons.timelapse_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalCloseDateColumn,
                value: accountsDate(context, period.closeDate),
                icon: Icons.done_all_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalLockDateColumn,
                value: accountsDate(context, period.lockDate),
                icon: Icons.lock_outline,
              ),
              if ((period.notes ?? '').trim().isNotEmpty)
                AppWorkspacePatientContextField(
                  label: AccountsStrings.fiscalNotesLabel,
                  value: period.notes!,
                  icon: Icons.sticky_note_2_outlined,
                ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        const AppCollapsibleSection(
          title: AccountsStrings.fiscalRelatedSection,
          initiallyExpanded: false,
          child: Text(AccountsStrings.fiscalRelatedEmpty),
        ),
        SizedBox(height: theme.spacing.sm),
        const AppCollapsibleSection(
          title: AccountsStrings.fiscalAttachmentsSection,
          initiallyExpanded: false,
          child: Text(AccountsStrings.fiscalAttachmentsEmpty),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: AccountsStrings.fiscalActivitySection,
          initiallyExpanded: false,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalActivityCreated,
                value: accountsDate(context, period.createdAt),
                icon: Icons.add_circle_outline,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalActivityUpdated,
                value: accountsDate(context, period.updatedAt),
                icon: Icons.update_outlined,
              ),
              if (period.reopenedAt != null)
                AppWorkspacePatientContextField(
                  label: AccountsStrings.fiscalActivityReopened,
                  value:
                      '${accountsDate(context, period.reopenedAt)} · '
                      '${period.reopenedBy ?? AccountsStrings.unknownValue}',
                  icon: Icons.restore_outlined,
                ),
              if (period.archivedAt != null)
                AppWorkspacePatientContextField(
                  label: AccountsStrings.fiscalActivityArchived,
                  value: accountsDate(context, period.archivedAt),
                  icon: Icons.inventory_2_outlined,
                ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.fiscalVersionLabel,
                value: '${period.version}',
                icon: Icons.history_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Confirms and posts a workflow transition; returns true when applied.
Future<bool> confirmAccountsFiscalPeriodAction({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsFiscalPeriod period,
  required AccountsFiscalPeriodAction action,
}) async {
  final String reference =
      accountsPublicLabel(period.humanFriendlyId) ?? period.periodName;
  final (String title, String body, bool destructive, IconData icon) =
      switch (action) {
        AccountsFiscalPeriodAction.activate => (
          AccountsStrings.fiscalActivateConfirmTitle,
          AccountsStrings.fiscalActivateConfirmBody(reference),
          false,
          Icons.check_circle_outline,
        ),
        AccountsFiscalPeriodAction.deactivate => (
          AccountsStrings.fiscalDeactivateConfirmTitle,
          AccountsStrings.fiscalDeactivateConfirmBody(reference),
          true,
          Icons.pause_circle_outline,
        ),
        AccountsFiscalPeriodAction.archive => (
          AccountsStrings.fiscalArchiveConfirmTitle,
          AccountsStrings.fiscalArchiveConfirmBody,
          true,
          Icons.inventory_2_outlined,
        ),
        AccountsFiscalPeriodAction.restore => (
          AccountsStrings.fiscalRestoreConfirmTitle,
          AccountsStrings.fiscalRestoreConfirmBody(reference),
          false,
          Icons.restore_outlined,
        ),
      };

  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppConfirmActionDialog(
      title: title,
      body: body,
      highlightedText: reference,
      submitLabel: accountsFiscalPeriodActionLabel(action),
      destructive: destructive,
      icon: Icon(icon),
      onConfirm: () async {
        final Result<AccountsFiscalPeriod> result = await ref
            .read(accountsFiscalPeriodRepositoryProvider)
            .applyAction(
              period.humanFriendlyId,
              action,
              version: period.version,
            );
        return result.when(
          success: (_) {
            ref
                    .read<StateController<int>>(
                      accountsFiscalPeriodRevisionProvider.notifier,
                    )
                    .state++;
            return null;
          },
          failure: (AppFailure failure) => failure,
        );
      },
    ),
  );
  return confirmed == true;
}

String accountsFiscalPeriodActionLabel(AccountsFiscalPeriodAction action) {
  return switch (action) {
    AccountsFiscalPeriodAction.activate => AccountsStrings.fiscalActivateAction,
    AccountsFiscalPeriodAction.deactivate =>
      AccountsStrings.fiscalDeactivateAction,
    AccountsFiscalPeriodAction.archive => AccountsStrings.fiscalArchiveAction,
    AccountsFiscalPeriodAction.restore => AccountsStrings.fiscalRestoreAction,
  };
}
