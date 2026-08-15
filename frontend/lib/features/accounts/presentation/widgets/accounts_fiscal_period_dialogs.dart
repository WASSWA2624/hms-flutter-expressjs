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
final accountsFiscalPeriodCountProvider = StateProvider<int?>(
  (Ref ref) => null,
);

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

  // The form owns the dialog so Close/Save live in the pinned footer rather
  // than scrolling away inside the body (`prompts/.cursor/dialogs.mdc`).
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _AccountsFiscalPeriodForm(mode: mode, source: source),
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
  late final TextEditingController _notesController;

  /// Controlled module scope; seeded from the record so an unrecognised stored
  /// value survives a round-trip instead of being reset to the default.
  late String _module;

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
    _module = (source?.module ?? '').trim().isEmpty
        ? 'ALL'
        : source!.module!.trim().toUpperCase();
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
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String pickDate = l10n.housekeepingPickDateAction;
    final String required = l10n.accountsFiscalRequiredField;

    AppDateField dateField({
      required DateTime? value,
      required String label,
      required ValueChanged<DateTime?> onChanged,
      bool isRequired = false,
    }) {
      return AppDateField(
        value: value,
        labelText: label,
        isRequired: isRequired,
        pickerButtonLabel: pickDate,
        invalidDateMessage: required,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        onChanged: onChanged,
      );
    }

    // Any stored module outside the controlled vocabulary stays selectable so
    // editing a legacy row never silently rewrites its scope.
    final List<String> moduleValues = <String>[
      ...accountsFiscalModuleWireValues,
      if (!accountsFiscalModuleWireValues.contains(_module)) _module,
    ];

    return AppDialog(
      title: Text(switch (widget.mode) {
        AccountsFiscalPeriodDialogMode.create => l10n.accountsFiscalCreateTitle,
        AccountsFiscalPeriodDialogMode.edit => l10n.accountsFiscalEditTitle,
        AccountsFiscalPeriodDialogMode.clone => l10n.accountsFiscalCloneTitle,
      }),
      icon: const Icon(Icons.event_note_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppFormSection(
            title: l10n.accountsFiscalIdentitySection,
            children: <Widget>[
              AppResponsiveFieldRow.two(
                left: AppTextField(
                  controller: _fiscalYearController,
                  labelText: l10n.accountsFiscalYearColumn,
                  isRequired: true,
                  validator: AppValidators.requiredText(required),
                ),
                right: AppTextField(
                  controller: _periodNoController,
                  labelText: l10n.accountsFiscalPeriodNoColumn,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  validator: _validatePeriodNo,
                ),
              ),
              AppResponsiveFieldRow.two(
                left: AppTextField(
                  controller: _periodNameController,
                  labelText: l10n.accountsFiscalPeriodNameColumn,
                  isRequired: true,
                  validator: AppValidators.requiredText(required),
                ),
                // Module is a controlled vocabulary, not free text.
                right: AppSelectField<String>(
                  value: _module,
                  labelText: l10n.accountsFiscalModuleColumn,
                  allowClear: false,
                  options: <AppSelectOption<String>>[
                    for (final String value in moduleValues)
                      AppSelectOption<String>(
                        value: value,
                        label: accountsFiscalModuleLabel(l10n, value),
                      ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _module = value ?? 'ALL'),
                ),
              ),
            ],
          ),
          AppFormSection(
            title: l10n.accountsFiscalCalendarSection,
            children: <Widget>[
              AppResponsiveFieldRow.two(
                left: dateField(
                  value: _startDate,
                  label: l10n.accountsFiscalStartDateColumn,
                  isRequired: true,
                  onChanged: (DateTime? value) =>
                      setState(() => _startDate = value),
                ),
                right: dateField(
                  value: _endDate,
                  label: l10n.accountsFiscalEndDateColumn,
                  isRequired: true,
                  onChanged: (DateTime? value) =>
                      setState(() => _endDate = value),
                ),
              ),
            ],
          ),
          AppFormSection(
            title: l10n.accountsFiscalMilestonesSection,
            children: <Widget>[
              // The three milestones share one row on wide screens and stack on
              // small ones; no half-empty slot.
              AppResponsiveFieldRow(
                children: <Widget>[
                  dateField(
                    value: _openDate,
                    label: l10n.accountsFiscalOpenDateColumn,
                    onChanged: (DateTime? value) =>
                        setState(() => _openDate = value),
                  ),
                  dateField(
                    value: _softCloseDate,
                    label: l10n.accountsFiscalSoftCloseDateColumn,
                    onChanged: (DateTime? value) =>
                        setState(() => _softCloseDate = value),
                  ),
                  dateField(
                    value: _closeDate,
                    label: l10n.accountsFiscalCloseDateColumn,
                    onChanged: (DateTime? value) =>
                        setState(() => _closeDate = value),
                  ),
                ],
              ),
              AppTextField(
                controller: _notesController,
                labelText: l10n.accountsFiscalNotesLabel,
                maxLines: 3,
              ),
            ],
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: switch (widget.mode) {
          AccountsFiscalPeriodDialogMode.create => l10n.commonAddActionLabel,
          AccountsFiscalPeriodDialogMode.edit => l10n.commonSaveActionLabel,
          AccountsFiscalPeriodDialogMode.clone =>
            l10n.accountsFiscalCloneAction,
        },
        submitIcon: Icons.save_outlined,
        isSubmitting: _isSubmitting,
        onCancel: () => Navigator.of(context).pop(false),
        onSubmit: _submit,
      ),
    );
  }

  String? _validatePeriodNo(String? value) {
    final AppLocalizations l10n = context.l10n;
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return l10n.accountsFiscalRequiredField;
    }
    final int? parsed = int.tryParse(raw);
    if (parsed == null || parsed < 1 || parsed > 366) {
      return l10n.accountsFiscalPeriodNoInvalid;
    }
    return null;
  }

  /// Mirrors the server ordering rules so a bad range never round-trips.
  String? _dateOrderingError() {
    final AppLocalizations l10n = context.l10n;
    final DateTime? start = _startDate;
    final DateTime? end = _endDate;
    if (start == null || end == null) {
      return l10n.accountsFiscalRequiredField;
    }
    if (end.isBefore(start)) {
      return l10n.accountsFiscalEndBeforeStart;
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
        return l10n.accountsFiscalMilestoneOutOfOrder;
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

    final String module = _module.trim().toUpperCase();
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
    title: Text(context.l10n.accountsFiscalDetailTitle),
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
    final AppLocalizations l10n = context.l10n;

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
                  Text(period.periodName, style: theme.textTheme.titleLarge),
                  SizedBox(height: theme.spacing.xs),
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: accountsFiscalPeriodStatusLabel(
                        l10n,
                        period.status,
                      ),
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
                  accountsUnknownValue(),
              tooltip: l10n.accountsFiscalReferenceColumn,
            ),
          ],
        ),
        if (period.isLocked) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner.message(
            message: l10n.accountsFiscalLockedNotice,
            variant: AppFormInformationVariant.warning,
            icon: AppActionIcons.warning,
          ),
        ],
        SizedBox(height: theme.spacing.md),
        AppCollapsibleSection(
          title: l10n.accountsFiscalSummarySection,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalYearColumn,
                value: period.fiscalYear,
                icon: Icons.calendar_today_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalPeriodNoColumn,
                value: '${period.periodNo}',
                icon: Icons.tag_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalStartDateColumn,
                value: accountsDate(context, period.startDate),
                icon: Icons.event_available_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalEndDateColumn,
                value: accountsDate(context, period.endDate),
                icon: Icons.event_busy_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalEntityAndFacilityColumn,
                value: period.entityAndFacility ?? accountsUnknownValue(),
                icon: Icons.apartment_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalModuleColumn,
                value: period.module ?? accountsUnknownValue(),
                icon: Icons.widgets_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalOpenDateColumn,
                value: accountsDate(context, period.openDate),
                icon: Icons.lock_open_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalSoftCloseDateColumn,
                value: accountsDate(context, period.softCloseDate),
                icon: Icons.timelapse_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalCloseDateColumn,
                value: accountsDate(context, period.closeDate),
                icon: Icons.done_all_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalLockDateColumn,
                value: accountsDate(context, period.lockDate),
                icon: Icons.lock_outline,
              ),
              if ((period.notes ?? '').trim().isNotEmpty)
                AppWorkspacePatientContextField(
                  label: l10n.accountsFiscalNotesLabel,
                  value: period.notes!,
                  icon: Icons.sticky_note_2_outlined,
                ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: l10n.accountsFiscalRelatedSection,
          initiallyExpanded: false,
          child: Text(l10n.accountsFiscalRelatedEmpty),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: l10n.accountsFiscalAttachmentsSection,
          initiallyExpanded: false,
          child: Text(l10n.accountsFiscalAttachmentsEmpty),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: l10n.accountsFiscalActivitySection,
          initiallyExpanded: false,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalActivityCreated,
                value: accountsDate(context, period.createdAt),
                icon: Icons.add_circle_outline,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalActivityUpdated,
                value: accountsDate(context, period.updatedAt),
                icon: Icons.update_outlined,
              ),
              // Timestamp and actor stay separate facts rather than one
              // concatenated line.
              if (period.reopenedAt != null)
                AppWorkspacePatientContextField(
                  label: l10n.accountsFiscalActivityReopened,
                  value: accountsDate(context, period.reopenedAt),
                  icon: Icons.restore_outlined,
                ),
              if (period.reopenedAt != null)
                AppWorkspacePatientContextField(
                  label: l10n.accountsFiscalActivityReopenedBy,
                  value: period.reopenedBy ?? accountsUnknownValue(),
                  icon: Icons.person_outline,
                ),
              if (period.archivedAt != null)
                AppWorkspacePatientContextField(
                  label: l10n.accountsFiscalActivityArchived,
                  value: accountsDate(context, period.archivedAt),
                  icon: Icons.inventory_2_outlined,
                ),
              AppWorkspacePatientContextField(
                label: l10n.accountsFiscalVersionLabel,
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
  final AppLocalizations l10n = context.l10n;
  final String reference =
      accountsPublicLabel(period.humanFriendlyId) ?? period.periodName;
  final (
    String title,
    String body,
    bool destructive,
    IconData icon,
  ) = switch (action) {
    AccountsFiscalPeriodAction.activate => (
      l10n.accountsFiscalActivateConfirmTitle,
      l10n.accountsFiscalActivateConfirmBody(reference),
      false,
      Icons.check_circle_outline,
    ),
    AccountsFiscalPeriodAction.deactivate => (
      l10n.accountsFiscalDeactivateConfirmTitle,
      l10n.accountsFiscalDeactivateConfirmBody(reference),
      true,
      Icons.pause_circle_outline,
    ),
    AccountsFiscalPeriodAction.archive => (
      l10n.accountsFiscalArchiveConfirmTitle,
      l10n.accountsFiscalArchiveConfirmBody,
      true,
      Icons.inventory_2_outlined,
    ),
    AccountsFiscalPeriodAction.restore => (
      l10n.accountsFiscalRestoreConfirmTitle,
      l10n.accountsFiscalRestoreConfirmBody(reference),
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
      submitLabel: accountsFiscalPeriodActionLabel(l10n, action),
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

String accountsFiscalPeriodActionLabel(
  AppLocalizations l10n,
  AccountsFiscalPeriodAction action,
) {
  return switch (action) {
    AccountsFiscalPeriodAction.activate => l10n.accountsFiscalActivateAction,
    AccountsFiscalPeriodAction.deactivate =>
      l10n.accountsFiscalDeactivateAction,
    AccountsFiscalPeriodAction.archive => l10n.accountsFiscalArchiveAction,
    AccountsFiscalPeriodAction.restore => l10n.accountsFiscalRestoreAction,
  };
}
