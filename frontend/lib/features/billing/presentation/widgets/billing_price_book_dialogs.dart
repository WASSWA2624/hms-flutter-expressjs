import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_price_book_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Bumped after price-book create / update / deactivate so Charge resolution
/// (and any cached book consumers) can refresh.
final billingPriceBookRevisionProvider = StateProvider<int>((Ref ref) => 0);

/// Active price count shown on the Price book desk tab.
final billingPriceBookActiveCountProvider = StateProvider<int?>((Ref ref) => null);

Future<bool> showBillingPriceBookEntryDialog({
  required BuildContext context,
  required WidgetRef ref,
  BillingPriceBookEntry? editing,
}) async {
  if (!canWriteBillingPriceBook(ref.read(appAccessPolicyProvider))) {
    return false;
  }
  final AppLocalizations l10n = context.l10n;
  final bool? saved = await showAppWorkspaceActionDialog<bool>(
    context: context,
    title: Text(
      editing == null
          ? l10n.billingPriceBookAddTitle
          : l10n.billingPriceBookEditTitle,
    ),
    content: _BillingPriceBookEntryDialog(
      editing: editing,
      onSubmit: (Map<String, Object?> payload) async {
        final repo = ref.read(billingPriceBookRepositoryProvider);
        if (editing == null) {
          final result = await repo.createEntry(payload);
          return result.when(
            success: (_) async => null,
            failure: (AppFailure failure) async => failure,
          );
        }
        final result = await repo.updateEntry(editing.id, payload);
        return result.when(
          success: (_) async => null,
          failure: (AppFailure failure) async => failure,
        );
      },
    ),
  );
  if (saved == true) {
    ref.read<StateController<int>>(billingPriceBookRevisionProvider.notifier).state++;
  }
  return saved == true;
}

class _BillingPriceBookEntryDialog extends ConsumerStatefulWidget {
  const _BillingPriceBookEntryDialog({
    required this.onSubmit,
    this.editing,
  });

  final BillingPriceBookEntry? editing;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;

  @override
  ConsumerState<_BillingPriceBookEntryDialog> createState() =>
      _BillingPriceBookEntryDialogState();
}

class _BillingPriceBookEntryDialogState
    extends ConsumerState<_BillingPriceBookEntryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _itemController;
  late final TextEditingController _priceController;
  late final TextEditingController _schemeController;
  late final TextEditingController _currencyController;
  late String _catalogType;
  late String _paymentMode;
  late String _billingEntity;
  late bool _isActive;
  DateTime? _effectiveFrom;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final BillingPriceBookEntry? editing = widget.editing;
    _itemController = TextEditingController(text: editing?.catalogItemId ?? '');
    _priceController = TextEditingController(
      text: editing == null ? '' : editing.unitPrice.toString(),
    );
    _schemeController = TextEditingController(
      text: editing?.coveragePlanId ?? '',
    );
    _currencyController = TextEditingController(
      text: editing?.currency ?? 'UGX',
    );
    _catalogType = editing?.catalogType.isNotEmpty == true
        ? editing!.catalogType
        : 'SERVICE';
    _paymentMode = editing?.paymentMode.isNotEmpty == true
        ? editing!.paymentMode
        : 'SELF_PAY';
    _billingEntity = editing?.billingEntity.isNotEmpty == true
        ? editing!.billingEntity
        : 'FACILITY';
    _isActive = editing?.isActive ?? true;
    _effectiveFrom = editing?.effectiveFrom;
  }

  @override
  void dispose() {
    _itemController.dispose();
    _priceController.dispose();
    _schemeController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormShell(
      formKey: _formKey,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppSelectField<String>(
          value: _catalogType,
          labelText: l10n.billingPriceBookCatalogLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'SERVICE',
              label: l10n.billingPriceBookCatalogService,
            ),
            AppSelectOption<String>(
              value: 'CONSULTATION',
              label: l10n.billingPriceBookCatalogConsultation,
            ),
            AppSelectOption<String>(
              value: 'LAB_TEST',
              label: l10n.billingPriceBookCatalogLabTest,
            ),
            AppSelectOption<String>(
              value: 'LAB_PANEL',
              label: l10n.billingPriceBookCatalogLabPanel,
            ),
            AppSelectOption<String>(
              value: 'RADIOLOGY_TEST',
              label: l10n.billingPriceBookCatalogRadiology,
            ),
            AppSelectOption<String>(
              value: 'DRUG',
              label: l10n.billingPriceBookCatalogDrug,
            ),
          ],
          onChanged: (String? value) {
            setState(() => _catalogType = value ?? _catalogType);
          },
        ),
        AppTextField(
          controller: _itemController,
          labelText: l10n.billingPriceBookItemLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.billingPriceBookItemRequired,
          ),
        ),
        AppSelectField<String>(
          value: _paymentMode,
          labelText: l10n.billingPriceBookModeLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'SELF_PAY',
              label: l10n.billingPriceBookModeSelfPay,
            ),
            AppSelectOption<String>(
              value: 'INSURANCE',
              label: l10n.billingPriceBookModeInsurance,
            ),
          ],
          onChanged: (String? value) {
            setState(() {
              _paymentMode = value ?? _paymentMode;
              if (_paymentMode == 'SELF_PAY') {
                _schemeController.clear();
              }
            });
          },
        ),
        AppTextField(
          controller: _priceController,
          labelText: l10n.billingPriceBookPriceLabel,
          isRequired: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: AppValidators.requiredText(
            l10n.billingPriceBookPriceRequired,
          ),
        ),
        AppTextField(
          controller: _currencyController,
          labelText: l10n.billingPriceBookCurrencyLabel,
          isRequired: true,
          validator: AppValidators.requiredText(
            l10n.billingPriceBookCurrencyRequired,
          ),
        ),
        if (_paymentMode == 'INSURANCE')
          AppTextField(
            controller: _schemeController,
            labelText: l10n.billingPriceBookSchemeLabel,
          ),
        AppSelectField<String>(
          value: _billingEntity,
          labelText: l10n.billingPriceBookBillingEntityLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'FACILITY',
              label: l10n.billingPriceBookFacilityEntity,
            ),
            AppSelectOption<String>(
              value: 'PHARMACY',
              label: l10n.billingPriceBookPharmacyEntity,
            ),
          ],
          onChanged: (String? value) {
            setState(() => _billingEntity = value ?? _billingEntity);
          },
        ),
        AppDateField(
          value: _effectiveFrom,
          labelText: l10n.billingPriceBookEffectiveLabel,
          pickerButtonLabel: l10n.housekeepingPickDateAction,
          invalidDateMessage: l10n.billingPriceBookEffectiveLabel,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onChanged: (DateTime? value) {
            setState(() => _effectiveFrom = value);
          },
        ),
        AppSwitchField(
          value: _isActive,
          title: l10n.billingPriceBookActiveLabel,
          onChanged: (bool value) => setState(() => _isActive = value),
        ),
        AppFormActions(
          cancelLabel: l10n.commonCancelActionLabel,
          submitLabel: l10n.commonSaveActionLabel,
          submitIcon: Icons.menu_book_outlined,
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
    final num? unitPrice = num.tryParse(_priceController.text.trim());
    if (tenantId == null || tenantId.isEmpty || unitPrice == null) {
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
      'catalog_type': _catalogType,
      'catalog_item_id': _itemController.text.trim(),
      'payment_mode': _paymentMode,
      'coverage_plan_id': _schemeController.text.trim().isEmpty
          ? null
          : _schemeController.text.trim(),
      'billing_entity': _billingEntity,
      'unit_price': unitPrice,
      'currency': _currencyController.text.trim().toUpperCase(),
      'effective_from': _effectiveFrom?.toUtc().toIso8601String(),
      'is_active': _isActive,
    };
    final AppFailure? failure = await widget.onSubmit(payload);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

String billingPriceBookModeLabel(AppLocalizations l10n, String mode) {
  return switch (mode.trim().toUpperCase()) {
    'INSURANCE' => l10n.billingPriceBookModeInsurance,
    _ => l10n.billingPriceBookModeSelfPay,
  };
}

String billingPriceBookCatalogLabel(AppLocalizations l10n, String catalogType) {
  return switch (catalogType.trim().toUpperCase()) {
    'CONSULTATION' => l10n.billingPriceBookCatalogConsultation,
    'LAB_TEST' => l10n.billingPriceBookCatalogLabTest,
    'LAB_PANEL' => l10n.billingPriceBookCatalogLabPanel,
    'RADIOLOGY_TEST' => l10n.billingPriceBookCatalogRadiology,
    'DRUG' => l10n.billingPriceBookCatalogDrug,
    _ => l10n.billingPriceBookCatalogService,
  };
}

String billingPriceBookMoney(
  BuildContext context,
  num value,
  String currency,
) {
  return AppFormatters.currency(
    value,
    Localizations.localeOf(context),
    currencyCode: currency,
    decimalDigits: value % 1 == 0 ? 0 : 2,
  );
}
