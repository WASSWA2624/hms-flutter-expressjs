import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/currency/effective_default_currency_provider.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';

/// Opens the patient-registry quick consultation billing / walk-in OPD flow.
///
/// Mutating opener: not barrier-dismissible. Returns `true` only after a
/// persisted success from [OpdWorkspaceController.submitOpdEncounter].
Future<bool?> showPatientBillingQuickDialog({
  required BuildContext context,
  required Patient patient,
  required PatientReferenceData referenceData,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PatientBillingQuickDialog(
      patient: patient,
      referenceData: referenceData,
    ),
  );
}

/// Patient Billing Quick — create consultation fee, invoice, and optional pay.
///
/// Historical inventory symbol: `_PatientFlowQuickDialog`. This is a billing
/// mutation form, not a stage-action hub.
class PatientBillingQuickDialog extends ConsumerStatefulWidget {
  const PatientBillingQuickDialog({
    required this.patient,
    required this.referenceData,
    super.key,
  });

  final Patient patient;
  final PatientReferenceData referenceData;

  @override
  ConsumerState<PatientBillingQuickDialog> createState() =>
      _PatientBillingQuickDialogState();
}

class _PatientBillingQuickDialogState
    extends ConsumerState<PatientBillingQuickDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _transactionRefController =
      TextEditingController();
  String? _facilityId;
  String _currency = appDefaultCurrencyCode;
  String _paymentMethod = 'CASH';
  bool _markPaid = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _facilityId = _initialFacilityId();
    _currency = ref.read(effectiveDefaultCurrencyProvider);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _feeController.dispose();
    _transactionRefController.dispose();
    super.dispose();
  }

  String? _initialFacilityId() {
    if (widget.patient.facilityId != null &&
        widget.patient.facilityId!.trim().isNotEmpty) {
      return widget.patient.facilityId;
    }
    if (widget.referenceData.facilities.length == 1) {
      return widget.referenceData.facilities.first.id;
    }
    return null;
  }

  String? _resolvedFacilityId() {
    if (_facilityId != null && _facilityId!.trim().isNotEmpty) {
      return _facilityId;
    }
    if (widget.referenceData.facilities.length == 1) {
      return widget.referenceData.facilities.first.id;
    }
    return widget.patient.facilityId;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.patientsBillingDialogTitle),
      icon: const Icon(AppActionIcons.payment),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      maxWidth: 780,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: appFormFailureStatus(
          context,
          _failure,
          messageBuilder: (AppFailure failure) => failure.displayMessage(l10n),
        ),
        children: <Widget>[
          if (widget.referenceData.facilities.length > 1)
            AppFormSection(
              title: l10n.patientsWorkflowSectionTitle,
              density: AppFormSectionDensity.compact,
              children: <Widget>[_facilitySelect(context)],
            ),
          AppFormSection(
            title: l10n.patientsBillingSectionTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              _consultationFeeField(context),
              AppAccessActionGate(
                requirement: opdBillingActionRequirement,
                builder: (BuildContext context, bool canRecordPayment) {
                  if (!canRecordPayment) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AppCheckboxField(
                        title: l10n.patientsMarkPaymentReceivedLabel,
                        value: _markPaid,
                        enabled: !_isSaving,
                        secondary: const Icon(AppActionIcons.payment),
                        onChanged: (bool value) =>
                            setState(() => _markPaid = value),
                      ),
                      if (_markPaid)
                        AppResponsiveFieldRow.two(
                          left: AppSelectField<String>.searchable(
                            value: _paymentMethod,
                            labelText: l10n.patientsPaymentMethodLabel,
                            enabled: !_isSaving,
                            onChanged: (String? value) => setState(
                              () => _paymentMethod = value ?? 'CASH',
                            ),
                            options: buildAppPaymentMethodSelectOptions(
                              methods: opdConsultationPaymentMethods,
                            ),
                          ),
                          right: AppTextField(
                            controller: _transactionRefController,
                            labelText: l10n.patientsTransactionReferenceLabel,
                            enabled: !_isSaving,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          AppFormSection(
            title: l10n.patientsNotesSectionTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppTextField(
                controller: _notesController,
                labelText: l10n.patientsNotesLabel,
                enabled: !_isSaving,
                maxLines: 3,
              ),
            ],
          ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.patientsQuickBillingAction,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: AppActionIcons.payment,
      ),
    );
  }

  Widget _consultationFeeField(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCurrencyAmountField(
      amountController: _feeController,
      currency: _currency,
      amountLabelText: l10n.patientsConsultationFeeLabel,
      currencyLabelText: l10n.patientsCurrencyLabel,
      enabled: !_isSaving,
      isRequired: true,
      validator: AppValidators.requiredText(l10n.validationRequired),
      onCurrencyChanged: (String? value) {
        setState(() {
          _currency = value ?? appDefaultCurrencyCode;
        });
      },
    );
  }

  Widget _facilitySelect(BuildContext context) {
    return PatientFacilitySelectField(
      facilities: widget.referenceData.facilities,
      value: _facilityId,
      labelText: context.l10n.patientsFacilityLabel,
      enabled: !_isSaving,
      onChanged: (String? value) {
        setState(() => _facilityId = value);
      },
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final AppFailure? failure = await _submitBilling();

    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isSaving = false;
      _failure = failure;
    });
  }

  Future<AppFailure?> _submitBilling() {
    final String amount = normalizeCurrencyAmount(_feeController.text);
    final bool canRecordPayment = opdBillingActionRequirement.isAllowed(
      ref.read(appAccessPolicyProvider),
    );
    final bool markPaid = _markPaid && canRecordPayment;
    return _startFlow(<String, Object?>{
      'arrival_mode': 'WALK_IN',
      'consultation_fee': amount,
      'currency': _currency,
      'create_consultation_invoice': true,
      'require_consultation_payment': true,
      if (markPaid)
        'pay_now': _withoutEmptyPayload(<String, Object?>{
          'method': _paymentMethod,
          'amount': amount,
          'status': 'COMPLETED',
          'transaction_ref': _transactionRefController.text.trim(),
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        }),
    });
  }

  Future<AppFailure?> _startFlow(Map<String, Object?> payload) async {
    // Persist through the OPD controller so flows/queues patch on success only.
    final Result<OpdFlowDetail> result = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .submitOpdEncounter(_baseFlowPayload(payload));
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  Map<String, Object?> _baseFlowPayload(Map<String, Object?> extra) {
    return _withoutEmptyPayload(<String, Object?>{
      'tenant_id': widget.patient.tenantId,
      'facility_id': _resolvedFacilityId(),
      'patient_id': widget.patient.id,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
      'reuse_open_encounter': true,
      'notes': _notesController.text.trim(),
      ...extra,
    });
  }
}

Map<String, Object?> _withoutEmptyPayload(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_payloadValueIsEmpty(entry.value)) entry.key: entry.value,
  };
}

bool _payloadValueIsEmpty(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable) {
    return value.isEmpty;
  }
  if (value is Map) {
    return value.isEmpty;
  }
  return false;
}
