import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/presentation/controllers/discharge_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Multi-step discharge clearance for the Discharge workspace (ipd-flow §10–§12).
class DischargeClearanceDialog extends ConsumerStatefulWidget {
  const DischargeClearanceDialog({required this.detail, super.key});

  final DischargeAdmissionDetail detail;

  @override
  ConsumerState<DischargeClearanceDialog> createState() =>
      _DischargeClearanceDialogState();
}

class _DischargeClearanceDialogState
    extends ConsumerState<DischargeClearanceDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _overrideController;
  late IpdDischargeClearance _clearance;
  bool _submitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _clearance = widget.detail.effectiveClearance;
    _overrideController = TextEditingController(
      text: _clearance.overrideReason ?? '',
    );
  }

  @override
  void dispose() {
    _overrideController.dispose();
    super.dispose();
  }

  bool get _isPlanned {
    return (widget.detail.latestDischargeSummary?.status ?? '').toUpperCase() ==
        'PLANNED';
  }

  IpdDischargeClearance _nextClearance({
    bool? summaryReady,
    bool? pendingOrdersReviewed,
    bool? pharmacyCleared,
    bool? billingCleared,
    bool? nursingCleared,
    bool? documentsReady,
    bool? patientExited,
  }) {
    return IpdDischargeClearance(
      summaryReady: summaryReady ?? _clearance.summaryReady,
      pendingOrdersReviewed:
          pendingOrdersReviewed ?? _clearance.pendingOrdersReviewed,
      pharmacyCleared: pharmacyCleared ?? _clearance.pharmacyCleared,
      billingCleared: billingCleared ?? _clearance.billingCleared,
      nursingCleared: nursingCleared ?? _clearance.nursingCleared,
      documentsReady: documentsReady ?? _clearance.documentsReady,
      patientExited: patientExited ?? _clearance.patientExited,
      overrideReason: _clearance.overrideReason,
    );
  }

  Future<void> _save({bool finalize = false}) async {
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final DischargeWorkspaceController controller = ref.read(
      dischargeWorkspaceControllerProvider.notifier,
    );
    final String? overrideReason = _overrideController.text.trim().isEmpty
        ? null
        : _overrideController.text.trim();
    final IpdDischargeClearance next = IpdDischargeClearance(
      summaryReady: _clearance.summaryReady,
      pendingOrdersReviewed: _clearance.pendingOrdersReviewed,
      pharmacyCleared: _clearance.pharmacyCleared,
      billingCleared: _clearance.billingCleared,
      nursingCleared: _clearance.nursingCleared,
      documentsReady: _clearance.documentsReady,
      patientExited: _clearance.patientExited,
      overrideReason: overrideReason,
    );
    AppFailure? failure = await controller.updateDischargeClearance(next);
    if (failure == null && finalize) {
      failure = await controller.completeDischarge(
        summary: widget.detail.summaryText,
        overrideReason: overrideReason,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<IpdPendingOrder> pendingOrders =
        widget.detail.ipd.pendingDischargeOrders;
    final bool canFinalize =
        _clearance.isComplete || _overrideController.text.trim().isNotEmpty;

    return AppDialog(
      title: Text(l10n.dischargeManageClearanceTitle),
      icon: const Icon(Icons.fact_check_outlined),
      scrollable: true,
      maxWidth: 640,
      closeEnabled: !_submitting,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            if (!_isPlanned)
              AppWorkspaceStatePanel.state(
                variant: AppStateViewVariant.info,
                title: l10n.dischargeEmptySummaryTitle,
                body: l10n.dischargeEmptySummaryBody,
                minHeight: 120,
              )
            else ...<Widget>[
              if (pendingOrders.isNotEmpty) ...<Widget>[
                Text(
                  l10n.dischargePendingOrdersTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final IpdPendingOrder order in pendingOrders)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.pending_actions_outlined,
                      size: 18,
                    ),
                    title: Text(order.label ?? order.kind ?? order.id),
                    subtitle: Text(order.status ?? ''),
                  ),
                SizedBox(height: theme.spacing.sm),
              ],
              _ClearanceCheckbox(
                label: l10n.ipdClearancePendingOrders,
                value: _clearance.pendingOrdersReviewed,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () =>
                      _clearance = _nextClearance(pendingOrdersReviewed: value),
                ),
              ),
              _ClearanceCheckbox(
                label: l10n.ipdClearancePharmacy,
                value: _clearance.pharmacyCleared,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = _nextClearance(pharmacyCleared: value),
                ),
              ),
              _ClearanceCheckbox(
                label: l10n.ipdClearanceBilling,
                value: _clearance.billingCleared,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = _nextClearance(billingCleared: value),
                ),
              ),
              _ClearanceCheckbox(
                label: l10n.ipdClearanceNursing,
                value: _clearance.nursingCleared,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = _nextClearance(nursingCleared: value),
                ),
              ),
              _ClearanceCheckbox(
                label: l10n.ipdClearanceDocuments,
                value: _clearance.documentsReady,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = _nextClearance(documentsReady: value),
                ),
              ),
              _ClearanceCheckbox(
                label: l10n.ipdClearancePatientExit,
                value: _clearance.patientExited,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = _nextClearance(patientExited: value),
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              AppTextField(
                controller: _overrideController,
                labelText: l10n.ipdDischargeOverrideLabel,
                hintText: l10n.ipdDischargeOverrideHint,
                minLines: 2,
                maxLines: 4,
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_submitting,
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (_isPlanned) ...<Widget>[
          AppButton.secondary(
            label: l10n.dischargeSaveClearanceAction,
            isLoading: _submitting,
            onPressed: () => _save(),
          ),
          AppButton.primary(
            label: l10n.ipdFinalizeDischargeAction,
            isLoading: _submitting,
            enabled: canFinalize,
            onPressed: canFinalize ? () => _save(finalize: true) : null,
          ),
        ],
      ],
    );
  }
}

class _ClearanceCheckbox extends StatelessWidget {
  const _ClearanceCheckbox({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: enabled ? (bool? next) => onChanged(next ?? false) : null,
      title: Text(label),
    );
  }
}
