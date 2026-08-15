import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_payment_method_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_payment_method.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_payment_method_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_detail_fact_lines.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Bumped after every payment method mutation so the tab badge, the workspace
/// summary, and any dependent tender pickers refetch.
final accountsPaymentMethodRevisionProvider = StateProvider<int>((Ref ref) => 0);

/// Filtered payment method count owned by the panel; null falls back to the
/// workspace summary so the badge never reflects only the painted page.
final accountsPaymentMethodCountProvider = StateProvider<int?>((Ref ref) => null);

enum AccountsPaymentMethodDialogMode { create, edit, clone }

/// Create / edit / clone form for a payment method.
///
/// Returns `true` when the record was written.
Future<bool> showAccountsPaymentMethodDialog({
  required BuildContext context,
  required WidgetRef ref,
  AccountsPaymentMethodDialogMode mode =
      AccountsPaymentMethodDialogMode.create,
  AccountsPaymentMethod? source,
}) async {
  if (!canWriteAccountsPaymentMethods(ref.read(appAccessPolicyProvider))) {
    return false;
  }
  final AppLocalizations l10n = context.l10n;
  final String title = switch (mode) {
    AccountsPaymentMethodDialogMode.create =>
      l10n.accountsPaymentMethodCreateTitle,
    AccountsPaymentMethodDialogMode.edit => l10n.accountsPaymentMethodEditTitle,
    AccountsPaymentMethodDialogMode.clone =>
      l10n.accountsPaymentMethodCloneTitle,
  };

  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(title),
    content: _AccountsPaymentMethodForm(mode: mode, source: source),
  );

  if (saved == true) {
    ref
            .read<StateController<int>>(
              accountsPaymentMethodRevisionProvider.notifier,
            )
            .state++;
  }
  return saved ?? false;
}

class _AccountsPaymentMethodForm extends ConsumerStatefulWidget {
  const _AccountsPaymentMethodForm({required this.mode, this.source});

  final AccountsPaymentMethodDialogMode mode;
  final AccountsPaymentMethod? source;

  @override
  ConsumerState<_AccountsPaymentMethodForm> createState() =>
      _AccountsPaymentMethodFormState();
}

class _AccountsPaymentMethodFormState
    extends ConsumerState<_AccountsPaymentMethodForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _methodCodeController;
  late final TextEditingController _methodNameController;
  late final TextEditingController _providerController;
  late final TextEditingController _settlementAccountController;
  late final TextEditingController _clearingAccountController;
  late final TextEditingController _feeRuleController;
  late final TextEditingController _notesController;

  AccountsPaymentMethodType? _methodType;
  AccountsPaymentMethodDirection? _direction;
  bool _requiresExternalReference = false;
  bool _requiresApproval = false;
  bool _isSubmitting = false;
  AppFailure? _failure;

  bool get _isEdit => widget.mode == AccountsPaymentMethodDialogMode.edit;

  @override
  void initState() {
    super.initState();
    final AccountsPaymentMethod? source = widget.source;
    // A clone must not reuse the source code; it is unique per tenant.
    _methodCodeController = TextEditingController(
      text: _isEdit ? source?.methodCode ?? '' : '',
    );
    _methodNameController = TextEditingController(
      text: source?.methodName ?? '',
    );
    _providerController = TextEditingController(text: source?.provider ?? '');
    _settlementAccountController = TextEditingController(
      text: source?.settlementAccountHumanFriendlyId ?? '',
    );
    _clearingAccountController = TextEditingController(
      text: source?.clearingAccountHumanFriendlyId ?? '',
    );
    _feeRuleController = TextEditingController(text: source?.feeRule ?? '');
    _notesController = TextEditingController(text: source?.notes ?? '');
    _methodType = source?.methodType;
    _direction = source?.direction ?? AccountsPaymentMethodDirection.incoming;
    _requiresExternalReference = source?.requiresExternalReference ?? false;
    _requiresApproval = source?.requiresApproval ?? false;
  }

  @override
  void dispose() {
    _methodCodeController.dispose();
    _methodNameController.dispose();
    _providerController.dispose();
    _settlementAccountController.dispose();
    _clearingAccountController.dispose();
    _feeRuleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String required = l10n.accountsPaymentMethodRequiredField;

    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        // The tender taxonomy is shared with every recorded payment; say so
        // once rather than letting an operator assume it is local to finance.
        AppFormInformationBanner.message(
          message: l10n.accountsPaymentMethodSharedTypeNotice,
        ),
        AppFormSection(
          title: l10n.accountsPaymentMethodIdentitySection,
          children: <Widget>[
            AppResponsiveFieldRow.two(
              left: AppTextField(
                controller: _methodCodeController,
                labelText: l10n.accountsPaymentMethodCodeColumn,
                isRequired: true,
                validator: AppValidators.requiredText(required),
              ),
              right: AppTextField(
                controller: _methodNameController,
                labelText: l10n.accountsPaymentMethodNameColumn,
                isRequired: true,
                validator: AppValidators.requiredText(required),
              ),
            ),
            AppResponsiveFieldRow.two(
              left: AppSelectField<AccountsPaymentMethodType>(
                value: _methodType,
                labelText: l10n.accountsPaymentMethodTypeColumn,
                isRequired: true,
                allowClear: false,
                options: <AppSelectOption<AccountsPaymentMethodType>>[
                  for (final AccountsPaymentMethodType type
                      in AccountsPaymentMethodType.values)
                    AppSelectOption<AccountsPaymentMethodType>(
                      value: type,
                      label: accountsPaymentMethodTypeLabel(l10n, type),
                    ),
                ],
                validator: (AccountsPaymentMethodType? value) =>
                    value == null ? required : null,
                onChanged: (AccountsPaymentMethodType? value) =>
                    setState(() => _methodType = value),
              ),
              right: AppSelectField<AccountsPaymentMethodDirection>(
                value: _direction,
                labelText: l10n.accountsPaymentMethodDirectionColumn,
                isRequired: true,
                allowClear: false,
                options: <AppSelectOption<AccountsPaymentMethodDirection>>[
                  for (final AccountsPaymentMethodDirection direction
                      in AccountsPaymentMethodDirection.values)
                    AppSelectOption<AccountsPaymentMethodDirection>(
                      value: direction,
                      label: accountsPaymentMethodDirectionLabel(
                        l10n,
                        direction,
                      ),
                    ),
                ],
                validator: (AccountsPaymentMethodDirection? value) =>
                    value == null ? required : null,
                onChanged: (AccountsPaymentMethodDirection? value) =>
                    setState(() => _direction = value),
              ),
            ),
            AppResponsiveFieldRow.two(
              left: AppTextField(
                controller: _providerController,
                labelText: l10n.accountsPaymentMethodProviderColumn,
              ),
              right: const SizedBox.shrink(),
            ),
          ],
        ),
        AppFormSection(
          title: l10n.accountsPaymentMethodPostingSection,
          children: <Widget>[
            AppResponsiveFieldRow.two(
              left: AppTextField(
                controller: _settlementAccountController,
                labelText: l10n.accountsPaymentMethodSettlementAccountColumn,
              ),
              right: AppTextField(
                controller: _clearingAccountController,
                labelText: l10n.accountsPaymentMethodClearingAccountColumn,
              ),
            ),
          ],
        ),
        AppFormSection(
          title: l10n.accountsPaymentMethodRulesSection,
          children: <Widget>[
            AppResponsiveFieldRow.two(
              left: AppSwitchField(
                title: l10n.accountsPaymentMethodRequiresReferenceColumn,
                value: _requiresExternalReference,
                onChanged: (bool value) =>
                    setState(() => _requiresExternalReference = value),
              ),
              right: AppSwitchField(
                title: l10n.accountsPaymentMethodRequiresApprovalColumn,
                value: _requiresApproval,
                onChanged: (bool value) =>
                    setState(() => _requiresApproval = value),
              ),
            ),
            AppTextField(
              controller: _feeRuleController,
              labelText: l10n.accountsPaymentMethodFeeRuleColumn,
            ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.accountsPaymentMethodNotesLabel,
              maxLines: 3,
            ),
          ],
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: switch (widget.mode) {
            AccountsPaymentMethodDialogMode.create => l10n.commonAddActionLabel,
            AccountsPaymentMethodDialogMode.edit => l10n.commonSaveActionLabel,
            AccountsPaymentMethodDialogMode.clone =>
              l10n.accountsPaymentMethodCloneAction,
          },
          submitIcon: Icons.save_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  String? _optional(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  /// Mirrors the server pairing rule so an unreconcilable method never
  /// round-trips.
  String? _accountPairingError() {
    final bool hasClearing = _optional(_clearingAccountController) != null;
    final bool hasSettlement = _optional(_settlementAccountController) != null;
    if (hasClearing && !hasSettlement) {
      return context.l10n.accountsPaymentMethodSettlementRequired;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? pairingError = _accountPairingError();
    if (pairingError != null) {
      setState(
        () => _failure = AppFailure.validation(detailMessage: pairingError),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final Map<String, Object?> payload = <String, Object?>{
      'method_code': _methodCodeController.text.trim(),
      'method_name': _methodNameController.text.trim(),
      'method_type': _methodType?.wireValue,
      'direction':
          (_direction ?? AccountsPaymentMethodDirection.incoming).wireValue,
      'provider': _optional(_providerController),
      'settlement_account_id': _optional(_settlementAccountController),
      'clearing_account_id': _optional(_clearingAccountController),
      'requires_external_reference': _requiresExternalReference,
      'requires_approval': _requiresApproval,
      'fee_rule': _optional(_feeRuleController),
      'notes': _optional(_notesController),
      if (_isEdit) 'version': widget.source?.version,
    };

    final AccountsPaymentMethodRepository repository = ref.read(
      accountsPaymentMethodRepositoryProvider,
    );
    final Result<AccountsPaymentMethod> result = _isEdit
        ? await repository.updatePaymentMethod(
            widget.source!.humanFriendlyId,
            payload,
          )
        : await repository.createPaymentMethod(payload);

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

/// Read-only detail view: summary, allocations, settlement, documents & audit.
Future<void> showAccountsPaymentMethodDetail({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsPaymentMethod method,
  Future<void> Function()? onChanged,
}) async {
  await showAppWorkspaceDetailDrawer<void>(
    context: context,
    title: Text(context.l10n.accountsPaymentMethodDetailTitle),
    child: _AccountsPaymentMethodDetail(method: method, onChanged: onChanged),
  );
}

class _AccountsPaymentMethodDetail extends ConsumerWidget {
  const _AccountsPaymentMethodDetail({required this.method, this.onChanged});

  final AccountsPaymentMethod method;
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
                    method.methodName,
                    style: theme.textTheme.titleLarge,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: accountsPaymentMethodStatusLabel(
                        l10n,
                        method.status,
                      ),
                      tone: accountsPaymentMethodStatusTone(method.status),
                      icon: accountsPaymentMethodStatusIcon(method.status),
                    ),
                  ),
                ],
              ),
            ),
            AppCopyableIdentifier(
              value:
                  accountsPublicLabel(method.humanFriendlyId) ??
                  accountsUnknownValue(),
              tooltip: l10n.accountsPaymentMethodReferenceColumn,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppCollapsibleSection(
          title: l10n.accountsPaymentMethodSummarySection,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodCodeColumn,
                value: method.methodCode,
                icon: Icons.tag_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodTypeColumn,
                value: accountsPaymentMethodTypeLabel(l10n, method.methodType),
                icon: Icons.payments_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodDirectionColumn,
                value: accountsPaymentMethodDirectionLabel(
                  l10n,
                  method.direction,
                ),
                icon: Icons.swap_horiz_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodProviderColumn,
                value: method.provider ?? accountsUnknownValue(),
                icon: Icons.storefront_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodFacilityScopeColumn,
                value: method.facilityScope ?? accountsUnknownValue(),
                icon: Icons.apartment_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodEffectiveFromColumn,
                value: accountsDate(context, method.effectiveFrom),
                icon: Icons.event_available_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodEffectiveToColumn,
                value: accountsDate(context, method.effectiveTo),
                icon: Icons.event_busy_outlined,
              ),
              if ((method.notes ?? '').trim().isNotEmpty)
                AppWorkspacePatientContextField(
                  label: l10n.accountsPaymentMethodNotesLabel,
                  value: method.notes!,
                  icon: Icons.sticky_note_2_outlined,
                ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        // Allocation rows belong to the payments that used the method, not to
        // its configuration; the section states where they live.
        AppCollapsibleSection(
          title: l10n.accountsPaymentMethodAllocationsSection,
          initiallyExpanded: false,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodRequiresApprovalColumn,
                value: accountsPaymentMethodFlagLabel(
                  l10n,
                  method.requiresApproval,
                ),
                icon: Icons.verified_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodFeeRuleColumn,
                value: method.feeRule ?? accountsUnknownValue(),
                icon: Icons.percent_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodAllocationsSection,
                value: l10n.accountsPaymentMethodAllocationsEmpty,
                icon: Icons.call_split_outlined,
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: l10n.accountsPaymentMethodSettlementSection,
          initiallyExpanded: false,
          child:
              method.settlementAccount == null && method.clearingAccount == null
              ? Text(l10n.accountsPaymentMethodSettlementEmpty)
              : AccountsDetailFactLines(
                  fields: <AppWorkspacePatientContextField>[
                    if (method.settlementAccount != null)
                      AppWorkspacePatientContextField(
                        label:
                            l10n.accountsPaymentMethodSettlementAccountColumn,
                        value: method.settlementAccount!,
                        icon: Icons.account_balance_outlined,
                      ),
                    if (method.clearingAccount != null)
                      AppWorkspacePatientContextField(
                        label: l10n.accountsPaymentMethodClearingAccountColumn,
                        value: method.clearingAccount!,
                        icon: Icons.compare_arrows_outlined,
                      ),
                    AppWorkspacePatientContextField(
                      label:
                          l10n.accountsPaymentMethodRequiresReferenceColumn,
                      value: accountsPaymentMethodFlagLabel(
                        l10n,
                        method.requiresExternalReference,
                      ),
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                ),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: l10n.accountsPaymentMethodDocumentsSection,
          initiallyExpanded: false,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodActivityCreated,
                value: accountsDate(context, method.createdAt),
                icon: Icons.add_circle_outline,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodActivityUpdated,
                value: accountsDate(context, method.updatedAt),
                icon: Icons.update_outlined,
              ),
              if (method.archivedAt != null)
                AppWorkspacePatientContextField(
                  label: l10n.accountsPaymentMethodActivityArchived,
                  value: accountsDate(context, method.archivedAt),
                  icon: Icons.inventory_2_outlined,
                ),
              AppWorkspacePatientContextField(
                label: l10n.accountsPaymentMethodVersionLabel,
                value: '${method.version}',
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
Future<bool> confirmAccountsPaymentMethodAction({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsPaymentMethod method,
  required AccountsPaymentMethodAction action,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String reference =
      accountsPublicLabel(method.humanFriendlyId) ?? method.methodName;
  final (String title, String body, bool destructive, IconData icon) =
      switch (action) {
        AccountsPaymentMethodAction.activate => (
          l10n.accountsPaymentMethodActivateConfirmTitle,
          l10n.accountsPaymentMethodActivateConfirmBody(reference),
          false,
          Icons.check_circle_outline,
        ),
        AccountsPaymentMethodAction.deactivate => (
          l10n.accountsPaymentMethodDeactivateConfirmTitle,
          l10n.accountsPaymentMethodDeactivateConfirmBody(reference),
          true,
          Icons.pause_circle_outline,
        ),
        AccountsPaymentMethodAction.archive => (
          l10n.accountsPaymentMethodArchiveConfirmTitle,
          l10n.accountsPaymentMethodArchiveConfirmBody,
          true,
          Icons.inventory_2_outlined,
        ),
        AccountsPaymentMethodAction.restore => (
          l10n.accountsPaymentMethodRestoreConfirmTitle,
          l10n.accountsPaymentMethodRestoreConfirmBody(reference),
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
      submitLabel: accountsPaymentMethodActionLabel(l10n, action),
      destructive: destructive,
      icon: Icon(icon),
      onConfirm: () async {
        final Result<AccountsPaymentMethod> result = await ref
            .read(accountsPaymentMethodRepositoryProvider)
            .applyAction(
              method.humanFriendlyId,
              action,
              version: method.version,
            );
        return result.when(
          success: (_) {
            ref
                    .read<StateController<int>>(
                      accountsPaymentMethodRevisionProvider.notifier,
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

String accountsPaymentMethodActionLabel(
  AppLocalizations l10n,
  AccountsPaymentMethodAction action,
) {
  return switch (action) {
    AccountsPaymentMethodAction.activate =>
      l10n.accountsPaymentMethodActivateAction,
    AccountsPaymentMethodAction.deactivate =>
      l10n.accountsPaymentMethodDeactivateAction,
    AccountsPaymentMethodAction.archive =>
      l10n.accountsPaymentMethodArchiveAction,
    AccountsPaymentMethodAction.restore =>
      l10n.accountsPaymentMethodRestoreAction,
  };
}
