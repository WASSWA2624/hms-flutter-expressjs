import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_department_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_department.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_department_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_detail_fact_lines.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Bumped after every department mutation so the tab badge, the workspace
/// summary, and any dependent department pickers refetch.
final accountsDepartmentRevisionProvider = StateProvider<int>((Ref ref) => 0);

/// Filtered department count owned by the panel; null falls back to the
/// workspace summary so the badge never reflects only the painted page.
final accountsDepartmentCountProvider = StateProvider<int?>((Ref ref) => null);

enum AccountsDepartmentDialogMode { create, edit, clone }

/// Create / edit / clone form for a department and its cost centre.
///
/// Returns `true` when the record was written.
Future<bool> showAccountsDepartmentDialog({
  required BuildContext context,
  required WidgetRef ref,
  AccountsDepartmentDialogMode mode = AccountsDepartmentDialogMode.create,
  AccountsDepartment? source,
}) async {
  if (!canWriteAccountsDepartments(ref.read(appAccessPolicyProvider))) {
    return false;
  }
  final AppLocalizations l10n = context.l10n;
  final String title = switch (mode) {
    AccountsDepartmentDialogMode.create => l10n.accountsDepartmentCreateTitle,
    AccountsDepartmentDialogMode.edit => l10n.accountsDepartmentEditTitle,
    AccountsDepartmentDialogMode.clone => l10n.accountsDepartmentCloneTitle,
  };

  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(title),
    content: _AccountsDepartmentForm(mode: mode, source: source),
  );

  if (saved == true) {
    ref
            .read<StateController<int>>(
              accountsDepartmentRevisionProvider.notifier,
            )
            .state++;
  }
  return saved ?? false;
}

class _AccountsDepartmentForm extends ConsumerStatefulWidget {
  const _AccountsDepartmentForm({required this.mode, this.source});

  final AccountsDepartmentDialogMode mode;
  final AccountsDepartment? source;

  @override
  ConsumerState<_AccountsDepartmentForm> createState() =>
      _AccountsDepartmentFormState();
}

class _AccountsDepartmentFormState
    extends ConsumerState<_AccountsDepartmentForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _departmentCodeController;
  late final TextEditingController _departmentNameController;
  late final TextEditingController _costCentreCodeController;
  late final TextEditingController _costCentreNameController;
  late final TextEditingController _parentController;
  late final TextEditingController _managerController;
  late final TextEditingController _revenueAccountController;
  late final TextEditingController _expenseAccountController;
  late final TextEditingController _budgetOwnerController;

  DateTime? _effectiveFrom;
  DateTime? _effectiveTo;
  bool _isSubmitting = false;
  AppFailure? _failure;

  bool get _isEdit => widget.mode == AccountsDepartmentDialogMode.edit;

  @override
  void initState() {
    super.initState();
    final AccountsDepartment? source = widget.source;
    // A clone must not reuse the source codes; both are unique per facility.
    _departmentCodeController = TextEditingController(
      text: _isEdit ? source?.departmentCode ?? '' : '',
    );
    _costCentreCodeController = TextEditingController(
      text: _isEdit ? source?.costCentreCode ?? '' : '',
    );
    _departmentNameController = TextEditingController(
      text: source?.departmentName ?? '',
    );
    _costCentreNameController = TextEditingController(
      text: source?.costCentreName ?? '',
    );
    _parentController = TextEditingController(
      text: source?.parentHumanFriendlyId ?? '',
    );
    _managerController = TextEditingController(
      text: source?.managerHumanFriendlyId ?? '',
    );
    _revenueAccountController = TextEditingController(
      text: source?.defaultRevenueAccountHumanFriendlyId ?? '',
    );
    _expenseAccountController = TextEditingController(
      text: source?.defaultExpenseAccountHumanFriendlyId ?? '',
    );
    _budgetOwnerController = TextEditingController(
      text: source?.budgetOwnerHumanFriendlyId ?? '',
    );
    if (_isEdit) {
      _effectiveFrom = source?.effectiveFrom;
      _effectiveTo = source?.effectiveTo;
    }
  }

  @override
  void dispose() {
    _departmentCodeController.dispose();
    _departmentNameController.dispose();
    _costCentreCodeController.dispose();
    _costCentreNameController.dispose();
    _parentController.dispose();
    _managerController.dispose();
    _revenueAccountController.dispose();
    _expenseAccountController.dispose();
    _budgetOwnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String pickDate = l10n.housekeepingPickDateAction;
    final String required = l10n.accountsDepartmentRequiredField;

    AppDateField dateField({
      required DateTime? value,
      required String label,
      required ValueChanged<DateTime?> onChanged,
    }) {
      return AppDateField(
        value: value,
        labelText: label,
        pickerButtonLabel: pickDate,
        invalidDateMessage: required,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        onChanged: onChanged,
      );
    }

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        // The department is shared with facility setup; say so once rather than
        // letting an operator assume this is a finance-only record.
        AppFormInformationBanner.message(
          message: l10n.accountsDepartmentOwnedNotice,
        ),
        AppFormSection(
          title: l10n.accountsDepartmentIdentitySection,
          children: <Widget>[
            AppResponsiveFieldRow.two(
              left: AppTextField(
                controller: _departmentCodeController,
                labelText: l10n.accountsDepartmentCodeColumn,
                isRequired: true,
                validator: AppValidators.requiredText(required),
              ),
              right: AppTextField(
                controller: _departmentNameController,
                labelText: l10n.accountsDepartmentNameColumn,
                isRequired: true,
                validator: AppValidators.requiredText(required),
              ),
            ),
            AppResponsiveFieldRow.two(
              left: AppTextField(
                controller: _costCentreCodeController,
                labelText: l10n.accountsDepartmentCostCentreCodeColumn,
                isRequired: true,
                validator: AppValidators.requiredText(required),
              ),
              right: AppTextField(
                controller: _costCentreNameController,
                labelText: l10n.accountsDepartmentCostCentreNameColumn,
                isRequired: true,
                validator: AppValidators.requiredText(required),
              ),
            ),
          ],
        ),
        AppFormSection(
          title: l10n.accountsDepartmentStructureSection,
          children: <Widget>[
            // Facility is fixed by the session scope and never asked for.
            AppResponsiveFieldRow.two(
              left: AppTextField(
                controller: _parentController,
                labelText: l10n.accountsDepartmentParentColumn,
              ),
              right: AppTextField(
                controller: _managerController,
                labelText: l10n.accountsDepartmentManagerColumn,
              ),
            ),
            AppResponsiveFieldRow.two(
              left: AppTextField(
                controller: _budgetOwnerController,
                labelText: l10n.accountsDepartmentBudgetOwnerColumn,
              ),
              right: const SizedBox.shrink(),
            ),
            AppResponsiveFieldRow.two(
              left: dateField(
                value: _effectiveFrom,
                label: l10n.accountsDepartmentEffectiveFromColumn,
                onChanged: (DateTime? value) =>
                    setState(() => _effectiveFrom = value),
              ),
              right: dateField(
                value: _effectiveTo,
                label: l10n.accountsDepartmentEffectiveToColumn,
                onChanged: (DateTime? value) =>
                    setState(() => _effectiveTo = value),
              ),
            ),
          ],
        ),
        AppFormSection(
          title: l10n.accountsDepartmentPostingSection,
          children: <Widget>[
            AppResponsiveFieldRow.two(
              left: AppTextField(
                controller: _revenueAccountController,
                labelText: l10n.accountsDepartmentRevenueAccountColumn,
              ),
              right: AppTextField(
                controller: _expenseAccountController,
                labelText: l10n.accountsDepartmentExpenseAccountColumn,
              ),
            ),
          ],
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: switch (widget.mode) {
            AccountsDepartmentDialogMode.create => l10n.commonAddActionLabel,
            AccountsDepartmentDialogMode.edit => l10n.commonSaveActionLabel,
            AccountsDepartmentDialogMode.clone =>
              l10n.accountsDepartmentCloneAction,
          },
          submitIcon: Icons.save_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  /// Mirrors the server ordering rule so a bad window never round-trips.
  String? _effectiveWindowError() {
    final DateTime? from = _effectiveFrom;
    final DateTime? to = _effectiveTo;
    if (from == null || to == null) {
      return null;
    }
    if (to.isBefore(from)) {
      return context.l10n.accountsDepartmentEffectiveToBeforeFrom;
    }
    return null;
  }

  String? _optional(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? windowError = _effectiveWindowError();
    if (windowError != null) {
      setState(
        () => _failure = AppFailure.validation(detailMessage: windowError),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final Map<String, Object?> payload = <String, Object?>{
      'department_code': _departmentCodeController.text.trim(),
      'department_name': _departmentNameController.text.trim(),
      'cost_centre_code': _costCentreCodeController.text.trim(),
      'cost_centre_name': _costCentreNameController.text.trim(),
      'parent_id': _optional(_parentController),
      'manager_id': _optional(_managerController),
      'budget_owner_id': _optional(_budgetOwnerController),
      'default_revenue_account_id': _optional(_revenueAccountController),
      'default_expense_account_id': _optional(_expenseAccountController),
      'effective_from': _effectiveFrom?.toUtc().toIso8601String(),
      'effective_to': _effectiveTo?.toUtc().toIso8601String(),
      if (_isEdit) 'version': widget.source?.version,
    };

    final AccountsDepartmentRepository repository = ref.read(
      accountsDepartmentRepositoryProvider,
    );
    final Result<AccountsDepartment> result = _isEdit
        ? await repository.updateDepartment(
            widget.source!.humanFriendlyId,
            payload,
          )
        : await repository.createDepartment(payload);

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
Future<void> showAccountsDepartmentDetail({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsDepartment department,
  Future<void> Function()? onChanged,
}) async {
  await showAppWorkspaceDetailDrawer<void>(
    context: context,
    title: Text(context.l10n.accountsDepartmentDetailTitle),
    child: _AccountsDepartmentDetail(
      department: department,
      onChanged: onChanged,
    ),
  );
}

class _AccountsDepartmentDetail extends ConsumerWidget {
  const _AccountsDepartmentDetail({required this.department, this.onChanged});

  final AccountsDepartment department;
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
                  Text(
                    department.departmentName,
                    style: theme.textTheme.titleLarge,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: accountsDepartmentStatusLabel(
                        l10n,
                        department.status,
                      ),
                      tone: accountsDepartmentStatusTone(department.status),
                      icon: accountsDepartmentStatusIcon(department.status),
                    ),
                  ),
                ],
              ),
            ),
            AppCopyableIdentifier(
              value:
                  accountsPublicLabel(department.humanFriendlyId) ??
                  accountsUnknownValue(),
              tooltip: l10n.accountsDepartmentReferenceColumn,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppCollapsibleSection(
          title: l10n.accountsDepartmentSummarySection,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentCodeColumn,
                value: department.departmentCode,
                icon: Icons.tag_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentCostCentreCodeColumn,
                value: department.costCentreCode,
                icon: Icons.pin_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentCostCentreNameColumn,
                value: department.costCentreName,
                icon: Icons.account_balance_wallet_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentParentColumn,
                value: department.parent ?? accountsUnknownValue(),
                icon: Icons.account_tree_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentFacilityColumn,
                value: department.facility ?? accountsUnknownValue(),
                icon: Icons.apartment_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentManagerColumn,
                value: department.manager ?? accountsUnknownValue(),
                icon: Icons.badge_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentBudgetOwnerColumn,
                value: department.budgetOwner ?? accountsUnknownValue(),
                icon: Icons.person_outline,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentEffectiveFromColumn,
                value: accountsDate(context, department.effectiveFrom),
                icon: Icons.event_available_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentEffectiveToColumn,
                value: accountsDate(context, department.effectiveTo),
                icon: Icons.event_busy_outlined,
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        // Cross-module references: the posting accounts are owned by Chart of
        // Accounts, so they are shown here rather than duplicated as facts.
        AppCollapsibleSection(
          title: l10n.accountsDepartmentRelatedSection,
          initiallyExpanded: false,
          child:
              department.defaultRevenueAccount == null &&
                  department.defaultExpenseAccount == null
              ? Text(l10n.accountsDepartmentRelatedEmpty)
              : AccountsDetailFactLines(
                  fields: <AppWorkspacePatientContextField>[
                    if (department.defaultRevenueAccount != null)
                      AppWorkspacePatientContextField(
                        label: l10n.accountsDepartmentRevenueAccountColumn,
                        value: department.defaultRevenueAccount!,
                        icon: Icons.trending_up_outlined,
                      ),
                    if (department.defaultExpenseAccount != null)
                      AppWorkspacePatientContextField(
                        label: l10n.accountsDepartmentExpenseAccountColumn,
                        value: department.defaultExpenseAccount!,
                        icon: Icons.trending_down_outlined,
                      ),
                  ],
                ),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: l10n.accountsDepartmentAttachmentsSection,
          initiallyExpanded: false,
          child: Text(l10n.accountsDepartmentAttachmentsEmpty),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: l10n.accountsDepartmentActivitySection,
          initiallyExpanded: false,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentActivityCreated,
                value: accountsDate(context, department.createdAt),
                icon: Icons.add_circle_outline,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentActivityUpdated,
                value: accountsDate(context, department.updatedAt),
                icon: Icons.update_outlined,
              ),
              if (department.archivedAt != null)
                AppWorkspacePatientContextField(
                  label: l10n.accountsDepartmentActivityArchived,
                  value: accountsDate(context, department.archivedAt),
                  icon: Icons.inventory_2_outlined,
                ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDepartmentVersionLabel,
                value: '${department.version}',
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
Future<bool> confirmAccountsDepartmentAction({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsDepartment department,
  required AccountsDepartmentAction action,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String reference =
      accountsPublicLabel(department.humanFriendlyId) ??
      department.departmentName;
  final (String title, String body, bool destructive, IconData icon) =
      switch (action) {
        AccountsDepartmentAction.activate => (
          l10n.accountsDepartmentActivateConfirmTitle,
          l10n.accountsDepartmentActivateConfirmBody(reference),
          false,
          Icons.check_circle_outline,
        ),
        AccountsDepartmentAction.deactivate => (
          l10n.accountsDepartmentDeactivateConfirmTitle,
          l10n.accountsDepartmentDeactivateConfirmBody(reference),
          true,
          Icons.pause_circle_outline,
        ),
        AccountsDepartmentAction.archive => (
          l10n.accountsDepartmentArchiveConfirmTitle,
          l10n.accountsDepartmentArchiveConfirmBody,
          true,
          Icons.inventory_2_outlined,
        ),
        AccountsDepartmentAction.restore => (
          l10n.accountsDepartmentRestoreConfirmTitle,
          l10n.accountsDepartmentRestoreConfirmBody(reference),
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
      submitLabel: accountsDepartmentActionLabel(l10n, action),
      destructive: destructive,
      icon: Icon(icon),
      onConfirm: () async {
        final Result<AccountsDepartment> result = await ref
            .read(accountsDepartmentRepositoryProvider)
            .applyAction(
              department.humanFriendlyId,
              action,
              version: department.version,
            );
        return result.when(
          success: (_) {
            ref
                    .read<StateController<int>>(
                      accountsDepartmentRevisionProvider.notifier,
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

String accountsDepartmentActionLabel(
  AppLocalizations l10n,
  AccountsDepartmentAction action,
) {
  return switch (action) {
    AccountsDepartmentAction.activate => l10n.accountsDepartmentActivateAction,
    AccountsDepartmentAction.deactivate =>
      l10n.accountsDepartmentDeactivateAction,
    AccountsDepartmentAction.archive => l10n.accountsDepartmentArchiveAction,
    AccountsDepartmentAction.restore => l10n.accountsDepartmentRestoreAction,
  };
}
