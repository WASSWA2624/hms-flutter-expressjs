import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_price_book_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_similarity.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_similarity_dialog.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Bumped after price-book create / update / deactivate so Charge resolution
/// (and any cached book consumers) can refresh.
final billingPriceBookRevisionProvider = StateProvider<int>((Ref ref) => 0);

/// Active price count shown on the Price book desk tab.
final billingPriceBookActiveCountProvider = StateProvider<int?>((Ref ref) => null);

/// Result of Add / Edit price dialog (saved, cancelled, or select existing).
enum BillingPriceBookDialogOutcome { cancelled, saved, openExisting }

final class BillingPriceBookDialogResult {
  const BillingPriceBookDialogResult._({
    required this.outcome,
    this.existing,
  });

  const BillingPriceBookDialogResult.cancelled()
    : this._(outcome: BillingPriceBookDialogOutcome.cancelled);

  const BillingPriceBookDialogResult.saved()
    : this._(outcome: BillingPriceBookDialogOutcome.saved);

  const BillingPriceBookDialogResult.openExisting(this.existing)
    : outcome = BillingPriceBookDialogOutcome.openExisting;

  final BillingPriceBookDialogOutcome outcome;
  final BillingPriceBookEntry? existing;

  bool get saved => outcome == BillingPriceBookDialogOutcome.saved;
}

Future<BillingPriceBookDialogResult> showBillingPriceBookEntryDialog({
  required BuildContext context,
  required WidgetRef ref,
  BillingPriceBookEntry? editing,
}) async {
  if (!canWriteBillingPriceBook(ref.read(appAccessPolicyProvider))) {
    return const BillingPriceBookDialogResult.cancelled();
  }
  final AppLocalizations l10n = context.l10n;
  final BillingPriceBookDialogResult? result =
      await showAppWorkspaceActionDialog<BillingPriceBookDialogResult>(
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
              final createResult = await repo.createEntry(payload);
              return createResult.when(
                success: (_) async => null,
                failure: (AppFailure failure) async => failure,
              );
            }
            final updateResult = await repo.updateEntry(editing.id, payload);
            return updateResult.when(
              success: (_) async => null,
              failure: (AppFailure failure) async => failure,
            );
          },
          onOverwrite: (BillingPriceBookEntry target, Map<String, Object?> payload) async {
            final repo = ref.read(billingPriceBookRepositoryProvider);
            final updateResult = await repo.updateEntry(target.id, payload);
            return updateResult.when(
              success: (_) async => null,
              failure: (AppFailure failure) async => failure,
            );
          },
        ),
      );
  if (result?.saved == true) {
    ref.read<StateController<int>>(billingPriceBookRevisionProvider.notifier).state++;
  }
  return result ?? const BillingPriceBookDialogResult.cancelled();
}

class _BillingPriceBookEntryDialog extends ConsumerStatefulWidget {
  const _BillingPriceBookEntryDialog({
    required this.onSubmit,
    required this.onOverwrite,
    this.editing,
  });

  final BillingPriceBookEntry? editing;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onSubmit;
  final Future<AppFailure?> Function(
    BillingPriceBookEntry target,
    Map<String, Object?> payload,
  )
  onOverwrite;

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
          onCancel: () => Navigator.of(context).pop(
            const BillingPriceBookDialogResult.cancelled(),
          ),
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

    final BillingPriceBookSimilarityDraft draft = BillingPriceBookSimilarityDraft(
      catalogItemId: _itemController.text.trim(),
      paymentMode: _paymentMode,
      coveragePlanId: _schemeController.text.trim().isEmpty
          ? null
          : _schemeController.text.trim(),
      effectiveFrom: _effectiveFrom,
      isActive: _isActive,
    );

    final bool shouldSubmit = await _reviewSimilarity(draft);
    if (!shouldSubmit || !mounted) {
      setState(() => _isSubmitting = false);
      return;
    }

    // Overwrite target set by similarity review (create path only).
    final BillingPriceBookEntry? overwriteTarget = _overwriteTarget;
    _overwriteTarget = null;
    final AppFailure? failure = overwriteTarget == null
        ? await widget.onSubmit(payload)
        : await widget.onOverwrite(overwriteTarget, payload);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(const BillingPriceBookDialogResult.saved());
      return;
    }
    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }

  BillingPriceBookEntry? _overwriteTarget;

  Future<bool> _reviewSimilarity(BillingPriceBookSimilarityDraft draft) async {
    final Result<AppPage<BillingPriceBookEntry>> listed = await ref
        .read(billingPriceBookRepositoryProvider)
        .listEntries(
          BillingPriceBookQuery(search: draft.catalogItemId),
          tenantId: ref.read(sessionStateProvider).session?.user?.tenantId,
          facilityId: ref.read(sessionStateProvider).session?.user?.facilityId,
        );
    if (!mounted) {
      return false;
    }
    final List<BillingPriceBookEntry> candidates = listed.when(
      success: (AppPage<BillingPriceBookEntry> page) => page.items,
      failure: (_) => const <BillingPriceBookEntry>[],
    );
    final BillingPriceBookSimilarityResult check =
        checkBillingPriceBookSimilarity(
          draft: draft,
          candidates: candidates,
          excludeEntryId: widget.editing?.id,
        );
    if (!check.hasMatches) {
      return true;
    }

    final BillingPriceBookSimilarityDialogResult result =
        await showBillingPriceBookSimilarityDialog(
          context,
          draft: draft,
          check: check,
          isCreate: widget.editing == null,
        );
    if (!mounted) {
      return false;
    }
    switch (result.action) {
      case BillingPriceBookSimilarityAction.cancel:
        return false;
      case BillingPriceBookSimilarityAction.proceed:
        return true;
      case BillingPriceBookSimilarityAction.useExisting:
        final BillingPriceBookEntry? existing = result.selectedEntry;
        if (existing == null) {
          return false;
        }
        Navigator.of(context).pop(
          BillingPriceBookDialogResult.openExisting(existing),
        );
        return false;
      case BillingPriceBookSimilarityAction.overwrite:
        _overwriteTarget = result.selectedEntry;
        return _overwriteTarget != null;
    }
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

/// Human-readable item cell — catalog label · public item code (never UUID).
String billingPriceBookItemDisplayLabel(
  AppLocalizations l10n,
  BillingPriceBookEntry entry,
) {
  final String catalog = billingPriceBookCatalogLabel(l10n, entry.catalogType);
  final String? item = billingPublicLabel(entry.catalogItemId);
  if (item == null || item.isEmpty) {
    return catalog;
  }
  return '$catalog · $item';
}

/// Scheme label for tables / similarity — never raw plan UUID.
String billingPriceBookSchemeDisplayLabel(
  AppLocalizations l10n,
  BillingPriceBookEntry entry,
) {
  final String? name = billingPublicLabel(entry.coveragePlanName);
  if (name != null && name.isNotEmpty) {
    return name;
  }
  final String? planId = billingPublicLabel(entry.coveragePlanId);
  if (planId != null && planId.isNotEmpty) {
    return planId;
  }
  return l10n.billingNotRecorded;
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
