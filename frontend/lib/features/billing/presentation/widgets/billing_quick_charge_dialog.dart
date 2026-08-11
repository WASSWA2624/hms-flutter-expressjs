import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/currency/effective_default_currency_provider.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_price_book_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_dialogs.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_patient_actions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Opens the Open work Charge dialog (Patient · Item · Qty · Price · Mode · Notes).
Future<BillingChargeDraft?> showBillingQuickChargeDialog(
  BuildContext context,
) {
  return showAppDialog<BillingChargeDraft>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const BillingQuickChargeDialog(),
  );
}

class BillingQuickChargeDialog extends ConsumerStatefulWidget {
  const BillingQuickChargeDialog({super.key});

  @override
  ConsumerState<BillingQuickChargeDialog> createState() =>
      _BillingQuickChargeDialogState();
}

class _BillingQuickChargeDialogState
    extends ConsumerState<BillingQuickChargeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  Patient? _patient;
  String _paymentMode = 'SELF_PAY';
  String? _resolvedPriceBookEntryId;
  int? _watchedRevision;
  Timer? _resolveDebounce;

  @override
  void initState() {
    super.initState();
    _itemController.addListener(_schedulePriceResolve);
  }

  @override
  void dispose() {
    _resolveDebounce?.cancel();
    _itemController.removeListener(_schedulePriceResolve);
    _patientController.dispose();
    _itemController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _schedulePriceResolve() {
    _resolveDebounce?.cancel();
    _resolveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_resolvePriceFromBook());
    });
  }

  Future<void> _resolvePriceFromBook() async {
    final String item = _itemController.text.trim();
    if (item.isEmpty) {
      _resolvedPriceBookEntryId = null;
      return;
    }
    final String? tenantId = ref
        .read(sessionStateProvider)
        .session
        ?.user
        ?.tenantId;
    final String? facilityId = ref
        .read(sessionStateProvider)
        .session
        ?.user
        ?.facilityId;
    final Result<AppPage<BillingPriceBookEntry>> result = await ref
        .read(billingPriceBookRepositoryProvider)
        .listEntries(
          BillingPriceBookQuery(
            search: item,
            paymentMode: _paymentMode,
            isActive: true,
          ),
          tenantId: tenantId,
          facilityId: facilityId,
        );
    if (!mounted) {
      return;
    }
    final List<BillingPriceBookEntry> items = result.when(
      success: (AppPage<BillingPriceBookEntry> page) => page.items,
      failure: (_) => const <BillingPriceBookEntry>[],
    );
    final String needle = item.toLowerCase();
    BillingPriceBookEntry? match;
    for (final BillingPriceBookEntry entry in items) {
      if (entry.paymentMode.toUpperCase() != _paymentMode.toUpperCase()) {
        continue;
      }
      if (!entry.isActive) {
        continue;
      }
      final String catalogItem = entry.catalogItemId.trim().toLowerCase();
      final String label = billingPriceBookItemDisplayLabel(
        context.l10n,
        entry,
      ).toLowerCase();
      if (catalogItem == needle ||
          label.contains(needle) ||
          (catalogItem.isNotEmpty && needle.contains(catalogItem))) {
        match = entry;
        break;
      }
    }
    if (match == null) {
      return;
    }
    setState(() {
      _resolvedPriceBookEntryId = match!.id;
      _priceController.text = match.unitPrice.toString();
    });
  }

  Future<void> _pickPatient() async {
    final Patient? selected = await showReceptionPatientPickerDialog(
      context: context,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _patient = selected;
      _patientController.text = billingJoinDisplay(<String?>[
        selected.effectiveDisplayName,
        billingPublicLabel(selected.effectiveIdentifier) ??
            billingPublicLabel(selected.publicId),
      ]);
    });
  }

  void _submit() {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final Patient? patient = _patient;
    if (patient == null || patient.id.trim().isEmpty) {
      return;
    }
    final int qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty < 1) {
      return;
    }
    Navigator.of(context).pop(
      BillingChargeDraft(
        patientId: patient.id,
        itemDescription: _itemController.text.trim(),
        quantity: qty,
        unitPrice: _priceController.text.trim(),
        paymentMode: _paymentMode,
        currency: ref.read(effectiveDefaultCurrencyProvider),
        notes: billingEmptyToNull(_notesController.text),
        priceBookEntryId: _resolvedPriceBookEntryId,
        patientDisplayName: patient.effectiveDisplayName.trim().isEmpty
            ? null
            : patient.effectiveDisplayName.trim(),
        patientDisplayId: billingPublicLabel(patient.effectiveIdentifier) ??
            billingPublicLabel(patient.publicId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String currency = ref.watch(effectiveDefaultCurrencyProvider);
    final int revision = ref.watch(billingPriceBookRevisionProvider);
    if (_watchedRevision != revision) {
      _watchedRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_resolvePriceFromBook());
      });
    }

    return AppDialog(
      title: Text(l10n.billingChargeAction),
      icon: const Icon(Icons.add_card_outlined),
      scrollable: true,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _patientController,
            labelText: l10n.billingChargePatientLabel,
            readOnly: true,
            isRequired: true,
            hintText: l10n.billingChargeSelectPatient,
            suffixIcon: IconButton(
              tooltip: l10n.billingChargeSelectPatient,
              onPressed: _pickPatient,
              icon: const Icon(Icons.person_search_outlined),
            ),
            validator: (_) {
              if (_patient == null) {
                return l10n.billingChargeSelectPatient;
              }
              return null;
            },
          ),
          AppTextField(
            controller: _itemController,
            labelText: l10n.billingChargeItemLabel,
            hintText: l10n.billingChargeItemHint,
            isRequired: true,
            textInputAction: TextInputAction.next,
            validator: AppValidators.requiredText(l10n.billingChargeItemLabel),
          ),
          AppTextField(
            controller: _qtyController,
            labelText: l10n.billingChargeQtyLabel,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            isRequired: true,
            textInputAction: TextInputAction.next,
            validator: (String? value) {
              final int? qty = int.tryParse((value ?? '').trim());
              if (qty == null || qty < 1) {
                return l10n.billingChargeQtyLabel;
              }
              return null;
            },
          ),
          AppCurrencyAmountField(
            amountController: _priceController,
            currency: currency,
            onCurrencyChanged: (_) {},
            amountLabelText: l10n.billingDueLabel,
            currencyLabelText: l10n.billingCurrencyLabel,
            isRequired: true,
            allowZero: false,
          ),
          AppSelectField<String>(
            value: _paymentMode,
            labelText: l10n.billingChargeModeLabel,
            options: <AppSelectOption<String>>[
              AppSelectOption<String>(
                value: 'SELF_PAY',
                label: l10n.billingChargeModeSelfPay,
              ),
              AppSelectOption<String>(
                value: 'INSURANCE',
                label: l10n.billingChargeModeInsurance,
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _paymentMode = value);
                unawaited(_resolvePriceFromBook());
              }
            },
          ),
          AppTextField(
            controller: _notesController,
            labelText: l10n.billingNotesLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: l10n.billingChargeAction,
        submitIcon: Icons.add_card_outlined,
        onCancel: () => Navigator.of(context).maybePop(),
        onSubmit: _submit,
      ),
    );
  }
}
