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

Future<bool> showAccountsChartAccountDialog({
  required BuildContext context,
  required WidgetRef ref,
  AccountsChartAccount? editing,
  List<AccountsChartAccount> parentChoices = const <AccountsChartAccount>[],
}) async {
  if (!canWriteAccountsChart(ref.read(appAccessPolicyProvider))) {
    return false;
  }
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
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
          final result = await repo.createAccount(payload);
          return result.when(
            success: (_) async => null,
            failure: (AppFailure failure) async => failure,
          );
        }
        final result = await repo.updateAccount(editing.id, payload);
        return result.when(
          success: (_) async => null,
          failure: (AppFailure failure) async => failure,
        );
      },
    ),
  );
  if (saved == true) {
    ref
            .read<StateController<int>>(accountsChartRevisionProvider.notifier)
            .state++;
  }
  return saved == true;
}

class _AccountsChartAccountDialog extends ConsumerStatefulWidget {
  const _AccountsChartAccountDialog({
    required this.onSubmit,
    required this.parentChoices,
    this.editing,
  });

  final AccountsChartAccount? editing;
  final List<AccountsChartAccount> parentChoices;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

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
      options.add(
        AppSelectOption<String>(
          value: account.id,
          label: '${account.code} · ${account.accountLabel}',
        ),
      );
    }
    return options;
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
          onCancel: () => Navigator.of(context).pop(false),
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
    final AppFailure? failure = await widget.onSubmit(payload);
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
    Navigator.of(context).pop(true);
  }
}
