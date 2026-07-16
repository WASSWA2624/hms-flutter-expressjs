import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/currency/effective_default_currency_provider.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_consultation_billing_breakdown.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_coverage_verification_panel.dart';

/// Payment methods for consultation billing / patient quick billing.
const List<String> opdConsultationPaymentMethods = <String>[
  'CASH',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'CREDIT_CARD',
  'INSURANCE',
  'OTHER',
];

/// Opens the consultation payment dialog (mutating; not barrier-dismissible).
///
/// Returns `true` only after a persisted success from
/// [OpdWorkspaceController.payConsultation].
Future<bool?> showConsultationPaymentDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ConsultationPaymentDialog(flow: flow),
  );
}

/// Consultation Payment — record or edit consultation fee payment for an OPD flow.
class ConsultationPaymentDialog extends ConsumerStatefulWidget {
  const ConsultationPaymentDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<ConsultationPaymentDialog> createState() =>
      _ConsultationPaymentDialogState();
}

class _ConsultationPaymentDialogState
    extends ConsumerState<ConsultationPaymentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;
  String _currency = appDefaultCurrencyCode;
  String _method = 'CASH';
  bool _isSaving = false;
  bool _coverageVerified = false;
  String? _selectedInsuranceCompanyId;
  String? _selectedInsuranceCompanyName;
  String? _selectedCoveragePlanId;
  String? _selectedCoveragePlanName;
  int? _selectedCoveragePercentage;
  AppFailure? _failure;

  OpdFlowSummary get _currentFlow {
    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    if (selected != null && _isSameFlow(selected.summary, widget.flow)) {
      return selected.summary;
    }
    return widget.flow;
  }

  OpdFlowDetail? get _currentDetail {
    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    if (selected != null && _isSameFlow(selected.summary, widget.flow)) {
      return selected;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final OpdFlowSummary flow = widget.flow;
    final OpdBillingState billingState = opdFlowBillingState(flow);
    _amountController = TextEditingController(
      text: opdCurrencyAmountInput(
        billingState == OpdBillingState.paid
            ? flow.consultationPaidAmount ?? flow.consultationFee
            : flow.consultationFee,
      ),
    );
    _referenceController = TextEditingController();
    _notesController = TextEditingController();
    _currency =
        flow.consultationCurrency?.trim().toUpperCase() ??
        ref.read(effectiveDefaultCurrencyProvider);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary flow = _currentFlow;
    final OpdFlowDetail? detail = _currentDetail;
    final bool alreadyPaid = opdFlowBillingState(flow) == OpdBillingState.paid;
    final String submitLabel = alreadyPaid
        ? l10n.opdUpdateConsultationBillingAction
        : l10n.opdPayConsultationAction;
    return AppDialog(
      title: Text(l10n.opdManageConsultationBillingAction),
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
          OpdActionContextPanel(flow: flow, detail: detail, showTitle: false),
          OpdConsultationBillingBreakdownPanel(flow: flow, detail: detail),
          AppFormSection(
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppCurrencyAmountField(
                amountController: _amountController,
                currency: _currency,
                amountLabelText: l10n.opdFieldRequiredLabel(l10n.opdAmountLabel),
                currencyLabelText: l10n.opdFieldRequiredLabel(
                  l10n.opdCurrencyLabel,
                ),
                enabled: !_isSaving,
                validator: AppValidators.requiredText(l10n.validationRequired),
                onCurrencyChanged: (String? value) {
                  setState(() {
                    _currency = value ?? appDefaultCurrencyCode;
                  });
                },
              ),
              AppSelectField<String>(
                value: _method,
                labelText: l10n.opdFieldRequiredLabel(
                  l10n.opdPaymentMethodLabel,
                ),
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _method = value ?? _method;
                    _coverageVerified = false;
                    _selectedInsuranceCompanyId = null;
                    _selectedInsuranceCompanyName = null;
                    _selectedCoveragePlanId = null;
                    _selectedCoveragePlanName = null;
                    _selectedCoveragePercentage = null;
                  });
                },
                options: buildAppPaymentMethodSelectOptions(
                  methods: opdConsultationPaymentMethods,
                ),
              ),
              if (_method == 'INSURANCE')
                OpdCoverageVerificationPanel(
                  patientId: flow.patientId,
                  encounterId: flow.apiId,
                  enabled: !_isSaving,
                  onVerifiedChanged:
                      (
                        ({
                          bool verified,
                          String? insuranceCompanyId,
                          String? insuranceCompanyName,
                          String? coveragePlanId,
                          String? coveragePlanName,
                          int? coveragePercentage,
                          String? copayType,
                          num? copayValue,
                        })
                        result,
                      ) {
                        setState(() {
                          _coverageVerified = result.verified;
                          _selectedInsuranceCompanyId =
                              result.insuranceCompanyId;
                          _selectedInsuranceCompanyName =
                              result.insuranceCompanyName;
                          _selectedCoveragePlanId = result.coveragePlanId;
                          _selectedCoveragePlanName = result.coveragePlanName;
                          _selectedCoveragePercentage =
                              result.coveragePercentage;
                        });
                      },
                ),
              AppTextField(
                controller: _referenceController,
                labelText: l10n.opdFieldOptionalLabel(
                  l10n.opdTransactionReferenceLabel,
                ),
                enabled: !_isSaving,
              ),
              AppTextField(
                controller: _notesController,
                labelText: l10n.opdFieldOptionalLabel(l10n.opdNotesLabel),
                enabled: !_isSaving,
                maxLines: 3,
              ),
            ],
          ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        submitLabel,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: AppActionIcons.payment,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    if (_method == 'INSURANCE' && !_coverageVerified) {
      setState(() {
        _failure = AppFailure.validation(
          detailMessage: context.l10n.opdCoverageVerificationRequiredMessage,
        );
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .payConsultation(_currentFlow, <String, Object?>{
          'amount': normalizeCurrencyAmount(_amountController.text),
          'currency': _currency,
          'method': _method,
          'status': 'COMPLETED',
          'transaction_ref': _referenceController.text.trim(),
          'notes': _joinPaymentNotes(),
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        });
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  String _joinPaymentNotes() {
    final String manualNotes = _notesController.text.trim();
    if (_method != 'INSURANCE') {
      return manualNotes;
    }
    final String coveragePlanId = (_selectedCoveragePlanId ?? '').trim();
    final String coveragePlanName = (_selectedCoveragePlanName ?? '').trim();
    final String companyId = (_selectedInsuranceCompanyId ?? '').trim();
    final String companyName = (_selectedInsuranceCompanyName ?? '').trim();
    final List<String> parts = <String>[
      if (companyId.isNotEmpty) 'insurance_company_id=$companyId',
      if (companyName.isNotEmpty) 'insurance_company=$companyName',
      if (coveragePlanId.isNotEmpty) 'coverage_plan_id=$coveragePlanId',
      if (coveragePlanName.isNotEmpty) 'coverage_plan=$coveragePlanName',
      if (_selectedCoveragePercentage != null)
        'coverage_percentage=$_selectedCoveragePercentage',
      if (manualNotes.isNotEmpty) manualNotes,
    ];
    return parts.join(' | ');
  }
}

OpdWorkspaceState? _workspaceState(WidgetRef ref) {
  final Result<OpdWorkspaceState>? workspaceResult = ref
      .watch(opdWorkspaceControllerProvider)
      .asData
      ?.value;
  return workspaceResult?.when(
    success: (OpdWorkspaceState state) => state,
    failure: (_) => null,
  );
}

bool _isSameFlow(OpdFlowSummary left, OpdFlowSummary right) {
  return left.id == right.id ||
      (left.publicId != null && left.publicId == right.publicId);
}
