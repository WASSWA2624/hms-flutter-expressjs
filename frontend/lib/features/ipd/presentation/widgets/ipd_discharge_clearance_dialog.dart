import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Multi-step discharge clearance workflow (flow §10).
class IpdDischargeClearanceDialog extends ConsumerStatefulWidget {
  const IpdDischargeClearanceDialog({required this.admission, super.key});

  final IpdAdmissionDetail admission;

  @override
  ConsumerState<IpdDischargeClearanceDialog> createState() =>
      _IpdDischargeClearanceDialogState();
}

class _IpdDischargeClearanceDialogState
    extends ConsumerState<IpdDischargeClearanceDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _summaryController;
  late final TextEditingController _overrideController;
  late IpdDischargeClearance _clearance;
  bool _submitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final IpdDischargeSummary? discharge =
        widget.admission.latestDischargeSummary;
    _summaryController = TextEditingController(text: discharge?.summary ?? '');
    _overrideController = TextEditingController(
      text: discharge?.clearance.overrideReason ?? '',
    );
    _clearance = discharge?.clearance ?? const IpdDischargeClearance();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _overrideController.dispose();
    super.dispose();
  }

  bool get _isPlanned {
    return (widget.admission.latestDischargeSummary?.status ?? '')
            .toUpperCase() ==
        'PLANNED';
  }

  Future<void> _planDischarge() async {
    final String summary = _summaryController.text.trim();
    if (summary.isEmpty) {
      return;
    }
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(ipdWorkspaceControllerProvider.notifier)
        .planDischarge(widget.admission.summary, summary);
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

  Future<void> _saveClearance({bool finalize = false}) async {
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final IpdWorkspaceController controller = ref.read(
      ipdWorkspaceControllerProvider.notifier,
    );
    final IpdDischargeClearance next = IpdDischargeClearance(
      summaryReady: _clearance.summaryReady,
      pendingOrdersReviewed: _clearance.pendingOrdersReviewed,
      pharmacyCleared: _clearance.pharmacyCleared,
      billingCleared: _clearance.billingCleared,
      nursingCleared: _clearance.nursingCleared,
      documentsReady: _clearance.documentsReady,
      patientExited: _clearance.patientExited,
      overrideReason: _overrideController.text.trim().isEmpty
          ? null
          : _overrideController.text.trim(),
    );
    AppFailure? failure = await controller.updateDischargeClearance(
      widget.admission.summary,
      next,
    );
    if (failure == null && finalize) {
      failure = await controller.finalizeDischarge(
        widget.admission.summary,
        _summaryController.text.trim(),
        overrideReason: next.overrideReason,
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
        widget.admission.pendingDischargeOrders;
    final bool canFinalize =
        _clearance.isComplete || _overrideController.text.trim().isNotEmpty;

    return AppDialog(
      title: Text(
        _isPlanned ? l10n.ipdManageDischargeTitle : l10n.ipdPlanDischargeAction,
      ),
      icon: const Icon(Icons.logout_outlined),
      scrollable: true,
      maxWidth: 640,
      closeEnabled: !_submitting,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFormInformationBanner.failure(context: context, failure: _failure!),
            AppTextField(
              controller: _summaryController,
              labelText: l10n.ipdSummaryFieldLabel,
              minLines: 3,
              maxLines: 8,
              enabled: !_submitting,
            ),
            if (_isPlanned) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              Text(
                l10n.ipdDischargeClearanceTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (pendingOrders.isNotEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                Text(
                  l10n.ipdPendingOrdersTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
              ],
              _ClearanceTile(
                label: l10n.ipdClearancePendingOrders,
                value: _clearance.pendingOrdersReviewed,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = IpdDischargeClearance(
                    summaryReady: _clearance.summaryReady,
                    pendingOrdersReviewed: value,
                    pharmacyCleared: _clearance.pharmacyCleared,
                    billingCleared: _clearance.billingCleared,
                    nursingCleared: _clearance.nursingCleared,
                    documentsReady: _clearance.documentsReady,
                    patientExited: _clearance.patientExited,
                    overrideReason: _clearance.overrideReason,
                  ),
                ),
              ),
              _ClearanceTile(
                label: l10n.ipdClearancePharmacy,
                value: _clearance.pharmacyCleared,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = IpdDischargeClearance(
                    summaryReady: _clearance.summaryReady,
                    pendingOrdersReviewed: _clearance.pendingOrdersReviewed,
                    pharmacyCleared: value,
                    billingCleared: _clearance.billingCleared,
                    nursingCleared: _clearance.nursingCleared,
                    documentsReady: _clearance.documentsReady,
                    patientExited: _clearance.patientExited,
                    overrideReason: _clearance.overrideReason,
                  ),
                ),
              ),
              _ClearanceTile(
                label: l10n.ipdClearanceBilling,
                value: _clearance.billingCleared,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = IpdDischargeClearance(
                    summaryReady: _clearance.summaryReady,
                    pendingOrdersReviewed: _clearance.pendingOrdersReviewed,
                    pharmacyCleared: _clearance.pharmacyCleared,
                    billingCleared: value,
                    nursingCleared: _clearance.nursingCleared,
                    documentsReady: _clearance.documentsReady,
                    patientExited: _clearance.patientExited,
                    overrideReason: _clearance.overrideReason,
                  ),
                ),
              ),
              _ClearanceTile(
                label: l10n.ipdClearanceNursing,
                value: _clearance.nursingCleared,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = IpdDischargeClearance(
                    summaryReady: _clearance.summaryReady,
                    pendingOrdersReviewed: _clearance.pendingOrdersReviewed,
                    pharmacyCleared: _clearance.pharmacyCleared,
                    billingCleared: _clearance.billingCleared,
                    nursingCleared: value,
                    documentsReady: _clearance.documentsReady,
                    patientExited: _clearance.patientExited,
                    overrideReason: _clearance.overrideReason,
                  ),
                ),
              ),
              _ClearanceTile(
                label: l10n.ipdClearanceDocuments,
                value: _clearance.documentsReady,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = IpdDischargeClearance(
                    summaryReady: _clearance.summaryReady,
                    pendingOrdersReviewed: _clearance.pendingOrdersReviewed,
                    pharmacyCleared: _clearance.pharmacyCleared,
                    billingCleared: _clearance.billingCleared,
                    nursingCleared: _clearance.nursingCleared,
                    documentsReady: value,
                    patientExited: _clearance.patientExited,
                    overrideReason: _clearance.overrideReason,
                  ),
                ),
              ),
              _ClearanceTile(
                label: l10n.ipdClearancePatientExit,
                value: _clearance.patientExited,
                enabled: !_submitting,
                onChanged: (bool value) => setState(
                  () => _clearance = IpdDischargeClearance(
                    summaryReady: _clearance.summaryReady,
                    pendingOrdersReviewed: _clearance.pendingOrdersReviewed,
                    pharmacyCleared: _clearance.pharmacyCleared,
                    billingCleared: _clearance.billingCleared,
                    nursingCleared: _clearance.nursingCleared,
                    documentsReady: _clearance.documentsReady,
                    patientExited: value,
                    overrideReason: _clearance.overrideReason,
                  ),
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
        if (!_isPlanned)
          AppButton.primary(
            label: l10n.ipdPlanDischargeAction,
            isLoading: _submitting,
            onPressed: _planDischarge,
          )
        else ...<Widget>[
          AppButton.secondary(
            label: l10n.ipdSaveClearanceAction,
            isLoading: _submitting,
            onPressed: () => _saveClearance(),
          ),
          AppButton.primary(
            label: l10n.ipdFinalizeDischargeAction,
            isLoading: _submitting,
            enabled: canFinalize,
            onPressed: canFinalize
                ? () => _saveClearance(finalize: true)
                : null,
          ),
        ],
      ],
    );
  }
}

class _ClearanceTile extends StatelessWidget {
  const _ClearanceTile({
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
