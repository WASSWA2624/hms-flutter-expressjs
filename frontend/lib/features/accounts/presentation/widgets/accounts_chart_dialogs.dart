import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_chart_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_chart_account.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_similarity.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_similarity_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Bumped after chart create / update / deactivate so Journal create and GL
/// can refresh chart-backed account lists.
final accountsChartRevisionProvider = StateProvider<int>((Ref ref) => 0);

/// Active chart account count shown on the Account chart desk tab.
final accountsChartActiveCountProvider = StateProvider<int?>((Ref ref) => null);

String accountsChartTypeLabel(String accountType) {
  return switch (accountType.trim().toUpperCase()) {
    'ASSET' => AccountsStrings.chartTypeAsset,
    'LIABILITY' => AccountsStrings.chartTypeLiability,
    'EQUITY' => AccountsStrings.chartTypeEquity,
    'REVENUE' => AccountsStrings.chartTypeRevenue,
    'EXPENSE' => AccountsStrings.chartTypeExpense,
    _ => accountType.trim().isEmpty
        ? AccountsStrings.unknownValue
        : accountType,
  };
}

enum AccountsChartDialogOutcome { cancelled, saved, openExisting }

final class AccountsChartDialogResult {
  const AccountsChartDialogResult._({required this.outcome, this.existing});

  const AccountsChartDialogResult.cancelled()
    : this._(outcome: AccountsChartDialogOutcome.cancelled);

  const AccountsChartDialogResult.saved()
    : this._(outcome: AccountsChartDialogOutcome.saved);

  const AccountsChartDialogResult.openExisting(this.existing)
    : outcome = AccountsChartDialogOutcome.openExisting;

  final AccountsChartDialogOutcome outcome;
  final AccountsChartAccount? existing;

  bool get saved => outcome == AccountsChartDialogOutcome.saved;
}

Future<AccountsChartDialogResult> showAccountsChartAccountDialog({
  required BuildContext context,
  required WidgetRef ref,
  AccountsChartAccount? editing,
  List<AccountsChartAccount> parentChoices = const <AccountsChartAccount>[],
}) async {
  if (!canWriteAccountsChart(ref.read(appAccessPolicyProvider))) {
    return const AccountsChartDialogResult.cancelled();
  }
  final AccountsChartDialogResult? result =
      await showAppWorkspaceActionDialog<AccountsChartDialogResult>(
        context: context,
        title: Text(
          editing == null
              ? AccountsStrings.chartAddTitle
              : AccountsStrings.chartEditTitle,
        ),
        content: _AccountsChartAccountDialog(
          editing: editing,
          parentChoices: parentChoices,
          onSubmit: (Map<String, Object?> payload) async {
            final repo = ref.read(accountsChartRepositoryProvider);
            if (editing == null) {
              final createResult = await repo.createAccount(payload);
              return createResult.when(
                success: (_) async => null,
                failure: (AppFailure failure) async => failure,
              );
            }
            final updateResult = await repo.updateAccount(editing.id, payload);
            return updateResult.when(
              success: (_) async => null,
              failure: (AppFailure failure) async => failure,
            );
          },
          onOverwrite:
              (AccountsChartAccount target, Map<String, Object?> payload) async {
                final repo = ref.read(accountsChartRepositoryProvider);
                final updateResult = await repo.updateAccount(
                  target.id,
                  payload,
                );
                return updateResult.when(
                  success: (_) async => null,
                  failure: (AppFailure failure) async => failure,
                );
              },
        ),
      );
  if (result?.saved == true) {
    ref
            .read<StateController<int>>(accountsChartRevisionProvider.notifier)
            .state++;
  }
  return result ?? const AccountsChartDialogResult.cancelled();
}

class _AccountsChartAccountDialog extends ConsumerStatefulWidget {
  const _AccountsChartAccountDialog({
    required this.onSubmit,
    required this.onOverwrite,
    required this.parentChoices,
    this.editing,
  });

  final AccountsChartAccount? editing;
  final List<AccountsChartAccount> parentChoices;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;
  final Future<AppFailure?> Function(
    AccountsChartAccount target,
    Map<String, Object?> payload,
  )
  onOverwrite;

  @override
  ConsumerState<_AccountsChartAccountDialog> createState() =>
      _AccountsChartAccountDialogState();
}

class _AccountsChartAccountDialogState
    extends ConsumerState<_AccountsChartAccountDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _currencyController;
  late String _accountType;
  String? _parentId;
  late bool _isActive;
  DateTime? _effectiveFrom;
  bool _isSubmitting = false;
  AppFailure? _failure;
  AccountsChartAccount? _overwriteTarget;

  @override
  void initState() {
    super.initState();
    final AccountsChartAccount? editing = widget.editing;
    _codeController = TextEditingController(text: editing?.code ?? '');
    _nameController = TextEditingController(text: editing?.name ?? '');
    _currencyController = TextEditingController(
      text: editing?.currency ?? 'UGX',
    );
    _accountType = editing?.accountType.isNotEmpty == true
        ? editing!.accountType
        : 'ASSET';
    _parentId = editing?.parentId;
    _isActive = editing?.isActive ?? true;
    _effectiveFrom = editing?.effectiveFrom;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  List<AppSelectOption<String>> get _parentOptions {
    final String? editingId = widget.editing?.id;
    final List<AppSelectOption<String>> options = <AppSelectOption<String>>[
      const AppSelectOption<String>(value: '', label: '—'),
    ];
    for (final AccountsChartAccount account in widget.parentChoices) {
      if (editingId != null && account.id == editingId) {
        continue;
      }
      final String code = accountsPublicLabel(account.code) ?? account.code;
      options.add(
        AppSelectOption<String>(
          value: account.id,
          label: '$code · ${account.accountLabel}',
        ),
      );
    }
    return options;
  }

  String _parentLabelFor(String? parentId) {
    if (parentId == null || parentId.isEmpty) {
      return '';
    }
    for (final AccountsChartAccount account in widget.parentChoices) {
      if (account.id == parentId) {
        return account.accountLabel;
      }
    }
    return accountsPublicLabel(parentId) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppTextField(
          controller: _codeController,
          labelText: AccountsStrings.chartCodeLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            AccountsStrings.chartCodeRequired,
          ),
        ),
        AppTextField(
          controller: _nameController,
          labelText: AccountsStrings.chartNameLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            AccountsStrings.chartNameRequired,
          ),
        ),
        AppSelectField<String>(
          value: _accountType,
          labelText: AccountsStrings.chartTypeLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'ASSET',
              label: AccountsStrings.chartTypeAsset,
            ),
            AppSelectOption<String>(
              value: 'LIABILITY',
              label: AccountsStrings.chartTypeLiability,
            ),
            AppSelectOption<String>(
              value: 'EQUITY',
              label: AccountsStrings.chartTypeEquity,
            ),
            AppSelectOption<String>(
              value: 'REVENUE',
              label: AccountsStrings.chartTypeRevenue,
            ),
            AppSelectOption<String>(
              value: 'EXPENSE',
              label: AccountsStrings.chartTypeExpense,
            ),
          ],
          onChanged: (String? value) {
            setState(() => _accountType = value ?? _accountType);
          },
        ),
        AppSelectField<String>(
          value: _parentId ?? '',
          labelText: AccountsStrings.chartParentLabel,
          options: _parentOptions,
          onChanged: (String? value) {
            setState(() {
              final String next = (value ?? '').trim();
              _parentId = next.isEmpty ? null : next;
            });
          },
        ),
        AppTextField(
          controller: _currencyController,
          labelText: AccountsStrings.chartCurrencyLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            AccountsStrings.chartCurrencyRequired,
          ),
        ),
        AppDateField(
          value: _effectiveFrom,
          labelText: AccountsStrings.chartEffectiveLabel,
          pickerButtonLabel: l10n.housekeepingPickDateAction,
          invalidDateMessage: AccountsStrings.chartEffectiveLabel,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onChanged: (DateTime? value) {
            setState(() => _effectiveFrom = value);
          },
        ),
        AppSwitchField(
          value: _isActive,
          title: AccountsStrings.chartActiveLabel,
          onChanged: (bool value) => setState(() => _isActive = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.commonSaveActionLabel,
          submitIcon: Icons.save_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(
            context,
          ).pop(const AccountsChartDialogResult.cancelled()),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? tenantId = ref
        .read(sessionStateProvider)
        .session
        ?.user
        ?.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final String? facilityId = ref
        .read(sessionStateProvider)
        .session
        ?.user
        ?.facilityId;
    final Map<String, Object?> payload = <String, Object?>{
      if (widget.editing == null) 'tenant_id': tenantId,
      if (widget.editing == null) 'facility_id': facilityId,
      'code': _codeController.text.trim(),
      'name': _nameController.text.trim(),
      'account_type': _accountType,
      'parent_id': _parentId,
      'currency': _currencyController.text.trim().toUpperCase(),
      'effective_from': _effectiveFrom?.toUtc().toIso8601String(),
      'is_active': _isActive,
    };

    final AccountsChartSimilarityDraft draft = AccountsChartSimilarityDraft(
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      accountType: _accountType,
      parentId: _parentId,
      parentLabel: _parentLabelFor(_parentId),
    );

    final bool shouldSubmit = await _reviewSimilarity(draft);
    if (!shouldSubmit || !mounted) {
      setState(() => _isSubmitting = false);
      return;
    }

    final AccountsChartAccount? overwriteTarget = _overwriteTarget;
    _overwriteTarget = null;
    final AppFailure? failure = overwriteTarget == null
        ? await widget.onSubmit(payload)
        : await widget.onOverwrite(overwriteTarget, payload);
    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _failure = failure;
        _isSubmitting = false;
      });
      return;
    }
    Navigator.of(context).pop(const AccountsChartDialogResult.saved());
  }

  Future<bool> _reviewSimilarity(AccountsChartSimilarityDraft draft) async {
    final AccountsChartSimilarityResult check = checkAccountsChartSimilarity(
      draft: draft,
      candidates: widget.parentChoices,
      excludeAccountId: widget.editing?.id,
    );
    if (!check.hasMatches) {
      return true;
    }

    final AccountsChartSimilarityDialogResult result =
        await showAccountsChartSimilarityDialog(
          context,
          draft: draft,
          check: check,
          isCreate: widget.editing == null,
        );
    if (!mounted) {
      return false;
    }
    switch (result.action) {
      case AccountsChartSimilarityAction.cancel:
        return false;
      case AccountsChartSimilarityAction.proceed:
        // Exact code / full match must never create or update via Continue.
        return !check.hasExactCodeConflict && !check.hasExactConflict;
      case AccountsChartSimilarityAction.selectExisting:
        final AccountsChartAccount? existing = result.selected;
        if (existing == null) {
          return false;
        }
        Navigator.of(
          context,
        ).pop(AccountsChartDialogResult.openExisting(existing));
        return false;
      case AccountsChartSimilarityAction.overwrite:
        _overwriteTarget = result.selected;
        return _overwriteTarget != null;
    }
  }
}
