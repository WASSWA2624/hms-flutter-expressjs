import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/idempotency.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_currency_rate_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_currency_rate.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_currency_rate_repository.dart';
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

/// Bumped after every currency rate mutation so the tab badge, the workspace
/// summary, and any dependent currency pickers refetch.
final accountsCurrencyRateRevisionProvider = StateProvider<int>((Ref ref) => 0);

/// Filtered currency rate count owned by the panel; null falls back to the
/// workspace summary so the badge never reflects only the painted page.
final accountsCurrencyRateCountProvider = StateProvider<int?>((Ref ref) => null);

enum AccountsCurrencyRateDialogMode { create, edit, clone }

/// Create / edit / clone form for a currency rate.
///
/// Returns `true` when the record was written.
Future<bool> showAccountsCurrencyRateDialog({
  required BuildContext context,
  required WidgetRef ref,
  AccountsCurrencyRateDialogMode mode = AccountsCurrencyRateDialogMode.create,
  AccountsCurrencyRate? source,
}) async {
  if (!canWriteAccountsCurrencyRates(ref.read(appAccessPolicyProvider))) {
    return false;
  }
  final String title = switch (mode) {
    AccountsCurrencyRateDialogMode.create => AccountsStrings.currencyCreateTitle,
    AccountsCurrencyRateDialogMode.edit => AccountsStrings.currencyEditTitle,
    AccountsCurrencyRateDialogMode.clone => AccountsStrings.currencyCloneTitle,
  };

  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(title),
    content: _AccountsCurrencyRateForm(mode: mode, source: source),
  );

  if (saved == true) {
    ref
            .read<StateController<int>>(
              accountsCurrencyRateRevisionProvider.notifier,
            )
            .state++;
  }
  return saved ?? false;
}

class _AccountsCurrencyRateForm extends ConsumerStatefulWidget {
  const _AccountsCurrencyRateForm({required this.mode, this.source});

  final AccountsCurrencyRateDialogMode mode;
  final AccountsCurrencyRate? source;

  @override
  ConsumerState<_AccountsCurrencyRateForm> createState() =>
      _AccountsCurrencyRateFormState();
}

class _AccountsCurrencyRateFormState
    extends ConsumerState<_AccountsCurrencyRateForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _currencyNameController;
  late final TextEditingController _symbolController;
  late final TextEditingController _decimalPlacesController;
  late final TextEditingController _exchangeRateController;
  late final TextEditingController _sourceController;
  late final TextEditingController _buyRateController;
  late final TextEditingController _sellRateController;
  late final TextEditingController _notesController;

  String? _currencyCode;
  AccountsCurrencyRateType _rateType = AccountsCurrencyRateType.spot;
  DateTime? _effectiveDate;
  bool _baseCurrency = false;
  bool _isSubmitting = false;
  AppFailure? _failure;

  bool get _isEdit => widget.mode == AccountsCurrencyRateDialogMode.edit;

  @override
  void initState() {
    super.initState();
    final AccountsCurrencyRate? source = widget.source;
    _currencyCode = source?.currencyCode;
    _currencyNameController = TextEditingController(
      text: source?.currencyName ?? '',
    );
    _symbolController = TextEditingController(text: source?.symbol ?? '');
    _decimalPlacesController = TextEditingController(
      text: '${source?.decimalPlaces ?? 2}',
    );
    _exchangeRateController = TextEditingController(
      text: source == null ? '' : _rateText(source.exchangeRate),
    );
    _sourceController = TextEditingController(text: source?.source ?? '');
    _buyRateController = TextEditingController(
      text: source?.buyRate == null ? '' : _rateText(source!.buyRate!),
    );
    _sellRateController = TextEditingController(
      text: source?.sellRate == null ? '' : _rateText(source!.sellRate!),
    );
    _notesController = TextEditingController(text: source?.notes ?? '');
    _rateType = source?.rateType ?? AccountsCurrencyRateType.spot;
    _baseCurrency = source?.baseCurrency ?? false;
    // A clone must not reuse the source effective date; it would collide with
    // the currency + rate type + effective date uniqueness rule.
    if (_isEdit) {
      _effectiveDate = source?.effectiveDate;
    }
  }

  static String _rateText(double value) {
    final String text = value.toStringAsFixed(8);
    final String trimmed = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  @override
  void dispose() {
    _currencyNameController.dispose();
    _symbolController.dispose();
    _decimalPlacesController.dispose();
    _exchangeRateController.dispose();
    _sourceController.dispose();
    _buyRateController.dispose();
    _sellRateController.dispose();
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
        AppSelectField<String>.searchable(
          value: _currencyCode,
          labelText: AccountsStrings.currencyCodeLabel,
          isRequired: true,
          options: <AppSelectOption<String>>[
            for (final AppCurrencyOption option in appCurrencyOptions)
              AppSelectOption<String>(
                value: option.normalizedCode,
                label: option.label,
                searchText: option.searchText,
              ),
          ],
          validator: (String? value) => (value ?? '').trim().length == 3
              ? null
              : AccountsStrings.currencyCodeInvalid,
          onChanged: _onCurrencyCodeChanged,
        ),
        AppTextField(
          controller: _currencyNameController,
          labelText: AccountsStrings.currencyNameLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            AccountsStrings.currencyRequiredField,
          ),
        ),
        AppTextField(
          controller: _symbolController,
          labelText: AccountsStrings.currencySymbolLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            AccountsStrings.currencyRequiredField,
          ),
        ),
        AppTextField(
          controller: _decimalPlacesController,
          labelText: AccountsStrings.currencyDecimalPlacesLabel,
          isRequired: true,
          keyboardType: TextInputType.number,
          validator: _validateDecimalPlaces,
        ),
        AppSwitchField(
          title: AccountsStrings.currencyBaseLabel,
          subtitle: AccountsStrings.currencyBaseNotice,
          value: _baseCurrency,
          onChanged: (bool value) {
            setState(() {
              _baseCurrency = value;
              if (value) {
                _exchangeRateController.text = '1';
              }
            });
          },
        ),
        AppSelectField<AccountsCurrencyRateType>(
          value: _rateType,
          labelText: AccountsStrings.currencyRateTypeLabel,
          isRequired: true,
          allowClear: false,
          options: <AppSelectOption<AccountsCurrencyRateType>>[
            for (final AccountsCurrencyRateType type
                in AccountsCurrencyRateType.values)
              AppSelectOption<AccountsCurrencyRateType>(
                value: type,
                label: accountsCurrencyRateTypeLabel(type),
              ),
          ],
          onChanged: (AccountsCurrencyRateType? value) {
            setState(() => _rateType = value ?? AccountsCurrencyRateType.spot);
          },
        ),
        AppTextField(
          controller: _exchangeRateController,
          labelText: AccountsStrings.currencyExchangeRateLabel,
          isRequired: true,
          enabled: !_baseCurrency,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String? value) => _validateRate(value, required: true),
        ),
        AppDateField(
          value: _effectiveDate,
          labelText: AccountsStrings.currencyEffectiveDateLabel,
          isRequired: true,
          pickerButtonLabel: l10n.housekeepingPickDateAction,
          invalidDateMessage: AccountsStrings.currencyRequiredField,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onChanged: (DateTime? value) => setState(() => _effectiveDate = value),
        ),
        AppTextField(
          controller: _sourceController,
          labelText: AccountsStrings.currencySourceLabel,
        ),
        AppTextField(
          controller: _buyRateController,
          labelText: AccountsStrings.currencyBuyRateLabel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String? value) => _validateRate(value),
        ),
        AppTextField(
          controller: _sellRateController,
          labelText: AccountsStrings.currencySellRateLabel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String? value) => _validateRate(value),
        ),
        AppTextField(
          controller: _notesController,
          labelText: AccountsStrings.currencyNotesLabel,
          maxLines: 3,
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: switch (widget.mode) {
            AccountsCurrencyRateDialogMode.create =>
              AccountsStrings.currencyCreateAction,
            AccountsCurrencyRateDialogMode.edit =>
              AccountsStrings.currencySaveAction,
            AccountsCurrencyRateDialogMode.clone =>
              AccountsStrings.currencyCloneAction,
          },
          submitIcon: Icons.save_outlined,
          isSubmitting: _isSubmitting,
          onCancel: () => Navigator.of(context).pop(false),
          onSubmit: _submit,
        ),
      ],
    );
  }

  /// Prefills the display name and symbol from the ISO catalogue so the
  /// registry stays consistent across facilities.
  void _onCurrencyCodeChanged(String? value) {
    setState(() {
      _currencyCode = value;
      final AppCurrencyOption? option = value == null
          ? null
          : lookupAppCurrencyOption(value);
      if (option != null && _currencyNameController.text.trim().isEmpty) {
        _currencyNameController.text = option.name;
      }
      if (option != null && _symbolController.text.trim().isEmpty) {
        _symbolController.text = option.normalizedCode;
      }
    });
  }

  String? _validateDecimalPlaces(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return AccountsStrings.currencyRequiredField;
    }
    final int? parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0 || parsed > 6) {
      return AccountsStrings.currencyDecimalPlacesInvalid;
    }
    return null;
  }

  String? _validateRate(String? value, {bool required = false}) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return required ? AccountsStrings.currencyRequiredField : null;
    }
    final double? parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      return AccountsStrings.currencyRateInvalid;
    }
    return null;
  }

  /// Mirrors the server consistency rules so a bad payload never round-trips.
  String? _rateConsistencyError() {
    if (_effectiveDate == null) {
      return AccountsStrings.currencyRequiredField;
    }
    final double? exchange = double.tryParse(
      _exchangeRateController.text.trim(),
    );
    if (_baseCurrency && exchange != null && exchange != 1) {
      return AccountsStrings.currencyBaseRateMustBeOne;
    }
    final double? buy = double.tryParse(_buyRateController.text.trim());
    final double? sell = double.tryParse(_sellRateController.text.trim());
    if (buy != null && sell != null && buy > sell) {
      return AccountsStrings.currencyBuyAboveSell;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? consistencyError = _rateConsistencyError();
    if (consistencyError != null) {
      setState(
        () => _failure = AppFailure.validation(detailMessage: consistencyError),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final String source = _sourceController.text.trim();
    final String notes = _notesController.text.trim();
    final Map<String, Object?> payload = <String, Object?>{
      'currency_code': (_currencyCode ?? '').trim().toUpperCase(),
      'currency_name': _currencyNameController.text.trim(),
      'symbol': _symbolController.text.trim(),
      'decimal_places': int.parse(_decimalPlacesController.text.trim()),
      'is_base_currency': _baseCurrency,
      'rate_type': _rateType.wireValue,
      'exchange_rate': _baseCurrency
          ? 1
          : double.parse(_exchangeRateController.text.trim()),
      'effective_date': _effectiveDate!.toUtc().toIso8601String(),
      'source': source.isEmpty ? null : source,
      'buy_rate': double.tryParse(_buyRateController.text.trim()),
      'sell_rate': double.tryParse(_sellRateController.text.trim()),
      'notes': notes.isEmpty ? null : notes,
      if (_isEdit) 'version': widget.source?.version,
    };

    final AccountsCurrencyRateRepository repository = ref.read(
      accountsCurrencyRateRepositoryProvider,
    );
    // One key per submit attempt: transport-level retries replay the first
    // write, while a corrected resubmit is a new logical mutation.
    final String idempotencyKey = createIdempotencyKey();
    final Result<AccountsCurrencyRate> result = _isEdit
        ? await repository.updateRate(
            widget.source!.humanFriendlyId,
            payload,
            idempotencyKey: idempotencyKey,
          )
        : await repository.createRate(payload, idempotencyKey: idempotencyKey);

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
Future<void> showAccountsCurrencyRateDetail({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsCurrencyRate rate,
  Future<void> Function()? onChanged,
}) async {
  await showAppWorkspaceDetailDrawer<void>(
    context: context,
    title: const Text(AccountsStrings.currencyDetailTitle),
    child: _AccountsCurrencyRateDetail(rate: rate, onChanged: onChanged),
  );
}

class _AccountsCurrencyRateDetail extends ConsumerWidget {
  const _AccountsCurrencyRateDetail({required this.rate, this.onChanged});

  final AccountsCurrencyRate rate;
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
                    '${rate.currencyCode} · ${rate.currencyName}',
                    style: theme.textTheme.titleLarge,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: accountsCurrencyStatusLabel(rate.status),
                      tone: accountsCurrencyStatusTone(rate.status),
                      icon: accountsCurrencyStatusIcon(rate.status),
                    ),
                  ),
                ],
              ),
            ),
            AppCopyableIdentifier(
              value:
                  accountsPublicLabel(rate.humanFriendlyId) ??
                  AccountsStrings.unknownValue,
              tooltip: AccountsStrings.currencyReferenceColumn,
            ),
          ],
        ),
        if (rate.baseCurrency) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppFormInformationBanner.message(
            message: AccountsStrings.currencyBaseNotice,
            icon: AppActionIcons.info,
          ),
        ],
        SizedBox(height: theme.spacing.md),
        AppCollapsibleSection(
          title: AccountsStrings.currencySummarySection,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyCodeColumn,
                value: rate.currencyCode,
                icon: Icons.paid_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencySymbolColumn,
                value: rate.symbol,
                icon: Icons.attach_money_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyDecimalPlacesColumn,
                value: '${rate.decimalPlaces}',
                icon: Icons.numbers_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyBaseColumn,
                value: rate.baseCurrency
                    ? AccountsStrings.currencyBaseYes
                    : AccountsStrings.currencyBaseNo,
                icon: Icons.star_outline,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyRateTypeColumn,
                value: accountsCurrencyRateTypeLabel(rate.rateType),
                icon: Icons.category_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyExchangeRateColumn,
                value: accountsRate(
                  context,
                  rate.exchangeRate,
                  decimalPlaces: rate.decimalPlaces,
                ),
                icon: Icons.currency_exchange_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyEffectiveDateColumn,
                value: accountsDate(context, rate.effectiveDate),
                icon: Icons.event_available_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencySourceColumn,
                value: rate.source ?? AccountsStrings.unknownValue,
                icon: Icons.source_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyBuyRateColumn,
                value: accountsRate(
                  context,
                  rate.buyRate,
                  decimalPlaces: rate.decimalPlaces,
                ),
                icon: Icons.south_west_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencySellRateColumn,
                value: accountsRate(
                  context,
                  rate.sellRate,
                  decimalPlaces: rate.decimalPlaces,
                ),
                icon: Icons.north_east_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyEntityAndFacilityLabel,
                value: rate.entityAndFacility ?? AccountsStrings.unknownValue,
                icon: Icons.apartment_outlined,
              ),
              if ((rate.notes ?? '').trim().isNotEmpty)
                AppWorkspacePatientContextField(
                  label: AccountsStrings.currencyNotesLabel,
                  value: rate.notes!,
                  icon: Icons.sticky_note_2_outlined,
                ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        const AppCollapsibleSection(
          title: AccountsStrings.currencyRelatedSection,
          initiallyExpanded: false,
          child: Text(AccountsStrings.currencyRelatedEmpty),
        ),
        SizedBox(height: theme.spacing.sm),
        const AppCollapsibleSection(
          title: AccountsStrings.currencyAttachmentsSection,
          initiallyExpanded: false,
          child: Text(AccountsStrings.currencyAttachmentsEmpty),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: AccountsStrings.currencyActivitySection,
          initiallyExpanded: false,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyActivityCreated,
                value: accountsDate(context, rate.createdAt),
                icon: Icons.add_circle_outline,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyActivityUpdated,
                value:
                    '${accountsDate(context, rate.lastUpdatedAt)} · '
                    '${rate.updatedBy ?? AccountsStrings.unknownValue}',
                icon: Icons.update_outlined,
              ),
              if (rate.archivedAt != null)
                AppWorkspacePatientContextField(
                  label: AccountsStrings.currencyActivityArchived,
                  value: accountsDate(context, rate.archivedAt),
                  icon: Icons.inventory_2_outlined,
                ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.currencyVersionLabel,
                value: '${rate.version}',
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
Future<bool> confirmAccountsCurrencyRateAction({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsCurrencyRate rate,
  required AccountsCurrencyRateAction action,
}) async {
  final String reference =
      accountsPublicLabel(rate.humanFriendlyId) ?? rate.currencyCode;
  final (String title, String body, bool destructive, IconData icon) =
      switch (action) {
        AccountsCurrencyRateAction.activate => (
          AccountsStrings.currencyActivateConfirmTitle,
          AccountsStrings.currencyActivateConfirmBody(reference),
          false,
          Icons.check_circle_outline,
        ),
        AccountsCurrencyRateAction.deactivate => (
          AccountsStrings.currencyDeactivateConfirmTitle,
          AccountsStrings.currencyDeactivateConfirmBody(reference),
          true,
          Icons.pause_circle_outline,
        ),
        AccountsCurrencyRateAction.archive => (
          AccountsStrings.currencyArchiveConfirmTitle,
          AccountsStrings.currencyArchiveConfirmBody,
          true,
          Icons.inventory_2_outlined,
        ),
        AccountsCurrencyRateAction.restore => (
          AccountsStrings.currencyRestoreConfirmTitle,
          AccountsStrings.currencyRestoreConfirmBody(reference),
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
      submitLabel: accountsCurrencyRateActionLabel(action),
      destructive: destructive,
      icon: Icon(icon),
      onConfirm: () async {
        final Result<AccountsCurrencyRate> result = await ref
            .read(accountsCurrencyRateRepositoryProvider)
            .applyAction(
              rate.humanFriendlyId,
              action,
              version: rate.version,
              idempotencyKey: createIdempotencyKey(),
            );
        return result.when(
          success: (_) {
            ref
                    .read<StateController<int>>(
                      accountsCurrencyRateRevisionProvider.notifier,
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
