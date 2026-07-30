import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/discharge_clearance_tile.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_disposition_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// System-validated discharge planning dialog (ipd-flow §10–§12).
class DischargePlanningDialog extends ConsumerStatefulWidget {
  const DischargePlanningDialog({
    required this.admissionId,
    required this.title,
    this.initialDetail,
    this.initialMaximized = true,
    super.key,
  });

  final String admissionId;
  final Widget title;
  final DischargeAdmissionDetail? initialDetail;
  final bool initialMaximized;

  @override
  ConsumerState<DischargePlanningDialog> createState() =>
      _DischargePlanningDialogState();
}

class _DischargePlanningDialogState
    extends ConsumerState<DischargePlanningDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _summaryController;
  late final TextEditingController _overrideController;

  DischargeAdmissionDetail? _detail;
  bool _loading = false;
  bool _submitting = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _detail = widget.initialDetail;
    _summaryController = TextEditingController(
      text: widget.initialDetail?.summaryText ?? '',
    );
    _overrideController = TextEditingController(
      text: widget.initialDetail?.effectiveClearance.overrideReason ?? '',
    );
    if (_detail == null) {
      _loadDetail();
    }
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _overrideController.dispose();
    super.dispose();
  }

  bool get _isPlanned {
    return (_detail?.latestDischargeSummary?.status ?? '').toUpperCase() ==
        'PLANNED';
  }

  bool get _canFinalize {
    final DischargeAdmissionDetail? detail = _detail;
    if (detail == null) {
      return false;
    }
    if (_overrideController.text.trim().isNotEmpty) {
      return true;
    }
    return detail.blockingItems.isEmpty && detail.hasSummary;
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    final Result<DischargeAdmissionDetail> result = await ref
        .read(dischargeRepositoryProvider)
        .getAdmissionDetail(widget.admissionId);
    if (!mounted) {
      return;
    }
    result.when(
      success: (DischargeAdmissionDetail value) {
        setState(() {
          _detail = value;
          _loading = false;
          if (_summaryController.text.trim().isEmpty &&
              (value.summaryText ?? '').isNotEmpty) {
            _summaryController.text = value.summaryText!;
          }
          final String? override = value.effectiveClearance.overrideReason;
          if (_overrideController.text.trim().isEmpty &&
              (override ?? '').isNotEmpty) {
            _overrideController.text = override!;
          }
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loading = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _planDischarge() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final Result<void> result = await ref
        .read(dischargeRepositoryProvider)
        .planDischarge(widget.admissionId, <String, Object?>{
          'summary': _summaryController.text.trim(),
        });
    if (!mounted) {
      return;
    }
    await result.when(
      success: (_) async {
        await _loadDetail();
        if (mounted) {
          setState(() => _submitting = false);
        }
      },
      failure: (AppFailure failure) async {
        setState(() {
          _submitting = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _finalizeDischarge() async {
    final DischargeAdmissionDetail? detail = _detail;
    if (detail == null) {
      return;
    }
    if (!_canFinalize) {
      return;
    }

    setState(() {
      _submitting = true;
      _failure = null;
    });

    final String? overrideReason = _overrideController.text.trim().isEmpty
        ? null
        : _overrideController.text.trim();
    final Result<void> clearanceResult = await ref
        .read(dischargeRepositoryProvider)
        .updateDischargeClearance(
          widget.admissionId,
          detail.buildSyncClearancePayload(overrideReason: overrideReason),
        );

    AppFailure? failure = clearanceResult.when(
      success: (_) => null,
      failure: (AppFailure value) => value,
    );

    if (failure == null) {
      final Map<String, Object?> finalizePayload = <String, Object?>{
        'summary': _summaryController.text.trim().isEmpty
            ? detail.summaryText
            : _summaryController.text.trim(),
        'discharged_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (overrideReason != null) {
        finalizePayload['override_reason'] = overrideReason;
      }
      final Result<void> finalizeResult = await ref
          .read(dischargeRepositoryProvider)
          .finalizeDischarge(widget.admissionId, finalizePayload);
      failure = finalizeResult.when(
        success: (_) => null,
        failure: (AppFailure value) => value,
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

  Future<void> _openModuleAndRefresh(String location) async {
    await context.push<String?>(location);
    if (mounted) {
      await _loadDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DischargeAdmissionDetail? detail = _detail;

    return AppDialog(
      title: widget.title,
      icon: const Icon(Icons.logout_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      initialMaximized: widget.initialMaximized,
      maxWidth: 960,
      closeEnabled: !_submitting,
      content: _loading
          ? AppWorkspaceStatePanel.loading(
              title: l10n.dischargeLoadingTitle,
              body: l10n.dischargeLoadingBody,
              minHeight: 240,
            )
          : _failure != null && detail == null
          ? AppWorkspaceStatePanel.error(
              title: l10n.dischargeLoadErrorTitle,
              body: l10n.dischargeLoadErrorBody,
              minHeight: 240,
              action: AppButton.secondary(
                label: l10n.commonRefreshActionLabel,
                onPressed: _loadDetail,
              ),
            )
          : detail == null
          ? const SizedBox.shrink()
          : Form(
              key: _formKey,
              child: AppFormSection(
                children: <Widget>[
                  if (_failure != null)
                    AppFormInformationBanner.failure(
                      context: context,
                      failure: _failure!,
                    ),
                  if (!_isPlanned) ...<Widget>[
                    Text(l10n.dischargePlanDialogBody),
                    AppTextField(
                      controller: _summaryController,
                      labelText: l10n.dischargeSummaryFieldLabel,
                      helperText: l10n.dischargeSummaryHelperText,
                      enabled: !_submitting,
                      isRequired: true,
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      validator: AppValidators.requiredText(
                        l10n.validationRequired,
                      ),
                    ),
                  ] else ...<Widget>[
                    Text(l10n.dischargeCompleteDialogBody),
                    if (detail.blockingItems.isNotEmpty)
                      AppWorkspaceStatePanel.state(
                        variant: AppStateViewVariant.validation,
                        title: l10n.dischargeCompletionBlockersTitle,
                        body: l10n.dischargeCompletionBlockersBody,
                        minHeight: 100,
                      ),
                    _ClearanceChecklist(detail: detail),
                    if (detail.ipd.pendingDischargeOrders.isNotEmpty)
                      _PendingOrdersSection(
                        detail: detail,
                        enabled: !_submitting,
                        onResolve: _openModuleAndRefresh,
                      ),
                    if (detail.hasOpenInvoices || detail.hasOpenPharmacyOrders)
                      _RelatedRecordsSection(
                        detail: detail,
                        enabled: !_submitting,
                        onResolve: _openModuleAndRefresh,
                      ),
                    _ResolveLinksSection(
                      detail: detail,
                      enabled: !_submitting,
                      onResolve: _openModuleAndRefresh,
                    ),
                    if ((detail.summaryText ?? '').isNotEmpty) ...<Widget>[
                      AppTextField(
                        controller: _summaryController,
                        labelText: l10n.dischargeSummaryFieldLabel,
                        enabled: !_submitting,
                        isRequired: true,
                        minLines: 2,
                        maxLines: 4,
                        readOnly: true,
                      ),
                    ],
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
          onPressed: () => Navigator.of(context).pop(false),
        ),
        if (detail != null && !_loading) ...<Widget>[
          AppButton.secondary(
            label: l10n.commonRefreshActionLabel,
            enabled: !_submitting,
            onPressed: _loadDetail,
          ),
          if (!_isPlanned)
            AppAccessActionGate(
              requirement: DischargeAllPatientsAtomPermissions.create,
              builder: (BuildContext context, bool isAllowed) {
                return AppButton.primary(
                  label: l10n.dischargeSavePlanAction,
                  isLoading: _submitting,
                  onPressed: _planDischarge,
                );
              },
            )
          else
            AppAccessActionGate(
              requirement: DischargeAllPatientsAtomPermissions.update,
              builder: (BuildContext context, bool isAllowed) {
                return AppButton.primary(
                  label: clinicalDispositionActionLabel(
                    l10n,
                    sourceQueue: 'IPD',
                    status: detail.summary.admissionStatus,
                    stage: detail.summary.stage,
                    location: detail.summary.location,
                    hasAdmission: true,
                  ),
                  leadingIcon: Icons.logout_outlined,
                  isLoading: _submitting,
                  enabled: _canFinalize,
                  onPressed: _canFinalize ? _finalizeDischarge : null,
                );
              },
            ),
        ],
      ],
    );
  }
}

class _ClearanceChecklist extends ConsumerWidget {
  const _ClearanceChecklist({required this.detail});

  final DischargeAdmissionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final List<DischargeClearanceItem> items = dischargeVisibleClearanceItems(
      policy,
      detail.clearanceItems
          .where((DischargeClearanceItem item) => !_isNonBlocking(item.code))
          .toList(growable: false),
    );
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final int firstPendingIndex = items.indexWhere(
      (DischargeClearanceItem item) =>
          item.state == DischargeClearanceState.pending,
    );

    return AppWorkspaceDetailPanel(
      title: l10n.dischargeChecklistTitle,
      description: l10n.dischargeChecklistBody,
      child: AppWorkflowStepper(
        semanticLabel: l10n.dischargeClearanceProgressTitle,
        showDescriptions: false,
        steps: <AppWorkflowStepItem>[
          for (var index = 0; index < items.length; index += 1)
            AppWorkflowStepItem(
              id: items[index].code.name,
              label: dischargeClearanceLabel(context, items[index].code),
              icon: dischargeClearanceIcon(items[index].code),
              state: switch (items[index].state) {
                DischargeClearanceState.complete =>
                  AppWorkflowStepState.completed,
                DischargeClearanceState.unavailable =>
                  AppWorkflowStepState.unavailable,
                DischargeClearanceState.pending =>
                  index == firstPendingIndex
                      ? AppWorkflowStepState.current
                      : AppWorkflowStepState.upcoming,
              },
            ),
        ],
      ),
    );
  }

  bool _isNonBlocking(DischargeClearanceCode code) {
    return code == DischargeClearanceCode.bedRelease ||
        code == DischargeClearanceCode.housekeeping ||
        code == DischargeClearanceCode.insurance;
  }
}

class _PendingOrdersSection extends StatelessWidget {
  const _PendingOrdersSection({
    required this.detail,
    required this.enabled,
    required this.onResolve,
  });

  final DischargeAdmissionDetail detail;
  final bool enabled;
  final Future<void> Function(String location) onResolve;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<IpdPendingOrder> orders = detail.ipd.pendingDischargeOrders;

    return AppWorkspaceDetailPanel(
      title: l10n.dischargePendingOrdersTitle,
      description: l10n.dischargePendingOrdersBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final IpdPendingOrder order in orders)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pending_actions_outlined, size: 20),
              title: Text(order.label ?? order.kind ?? order.id),
              subtitle: Text(order.status ?? ''),
              trailing: AppButton.tertiary(
                label: l10n.patientsActiveWorkContinueAction,
                enabled: enabled,
                onPressed: () => onResolve(_routeForPendingOrder(order)),
              ),
            ),
        ],
      ),
    );
  }

  String _routeForPendingOrder(IpdPendingOrder order) {
    return switch ((order.kind ?? '').toLowerCase()) {
      'lab_order' => AppRoutes.lab.path,
      'radiology_order' => AppRoutes.radiology.path,
      'pharmacy_order' => AppRoutes.pharmacy.path,
      _ => AppRoutes.clinical.path,
    };
  }
}

class _RelatedRecordsSection extends StatelessWidget {
  const _RelatedRecordsSection({
    required this.detail,
    required this.enabled,
    required this.onResolve,
  });

  final DischargeAdmissionDetail detail;
  final bool enabled;
  final Future<void> Function(String location) onResolve;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (detail.hasOpenPharmacyOrders)
          AppAccessGate(
            requirement: dischargePharmacyClearanceReadRequirement,
            child: AppWorkspaceDetailPanel(
              title: l10n.dischargeMedicinesSectionTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final DischargeRelatedRecord record
                      in detail.pharmacyOrders.where(
                        (DischargeRelatedRecord item) =>
                            item.isOpenPharmacyOrder,
                      ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.medication_outlined, size: 20),
                      title: Text(
                        (record.title ?? '').trim().isNotEmpty
                            ? record.title!.trim()
                            : record.kind,
                      ),
                      subtitle: Text(record.status ?? ''),
                      trailing: AppButton.tertiary(
                        label: l10n.patientsActiveWorkContinueAction,
                        enabled: enabled,
                        onPressed: () => onResolve(AppRoutes.pharmacy.path),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (detail.hasOpenPharmacyOrders && detail.hasOpenInvoices)
          AppAccessGate(
            requirement: dischargeBillingClearanceReadRequirement,
            child: SizedBox(height: theme.spacing.md),
          ),
        if (detail.hasOpenInvoices)
          AppAccessGate(
            requirement: dischargeBillingClearanceReadRequirement,
            child: AppWorkspaceDetailPanel(
              title: l10n.dischargeBillingSectionTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final DischargeRelatedRecord record
                      in detail.invoices.where(
                        (DischargeRelatedRecord item) => item.isOpenInvoice,
                      ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.receipt_long_outlined,
                        size: 20,
                      ),
                      title: Text(
                        (record.title ?? '').trim().isNotEmpty
                            ? record.title!.trim()
                            : record.kind,
                      ),
                      subtitle: Text(
                        record.status ?? record.billingStatus ?? '',
                      ),
                      trailing: AppButton.tertiary(
                        label: l10n.patientsActiveWorkContinueAction,
                        enabled: enabled,
                        onPressed: () {
                          final String? patientId = detail.patientId?.trim();
                          onResolve(
                            (patientId == null || patientId.isEmpty)
                                ? AppRoutes.billing.path
                                : AppRoutes.billing.location(
                                    queryParameters: <String, String>{
                                      'patient_id': patientId,
                                    },
                                  ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ResolveLinksSection extends ConsumerWidget {
  const _ResolveLinksSection({
    required this.detail,
    required this.enabled,
    required this.onResolve,
  });

  final DischargeAdmissionDetail detail;
  final bool enabled;
  final Future<void> Function(String location) onResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final String admissionId = detail.summary.displayId ?? detail.summary.id;
    final List<Widget> children = <Widget>[
      if (dischargeNursingNavigateRequirement.isAllowed(policy))
        AppButton.tertiary(
          label: l10n.dischargeOpenNursingAction,
          leadingIcon: Icons.health_and_safety_outlined,
          enabled: enabled,
          onPressed: () => onResolve(AppRoutes.nursing.path),
        ),
      if (dischargePharmacyNavigateRequirement.isAllowed(policy))
        AppButton.tertiary(
          label: l10n.dischargeOpenPharmacyAction,
          leadingIcon: Icons.medication_outlined,
          enabled: enabled,
          onPressed: () => onResolve(AppRoutes.pharmacy.path),
        ),
      if (dischargeBillingNavigateRequirement.isAllowed(policy))
        AppButton.tertiary(
          label: l10n.dischargeOpenBillingAction,
          leadingIcon: Icons.receipt_long_outlined,
          enabled: enabled,
          onPressed: () {
            final String? patientId = detail.patientId?.trim();
            onResolve(
              (patientId == null || patientId.isEmpty)
                  ? AppRoutes.billing.path
                  : AppRoutes.billing.location(
                      queryParameters: <String, String>{
                        'patient_id': patientId,
                      },
                    ),
            );
          },
        ),
      if (admissionId.isNotEmpty &&
          dischargeIpdNavigateRequirement.isAllowed(policy))
        AppButton.tertiary(
          label: l10n.dischargeOpenIpdAction,
          leadingIcon: Icons.local_hotel_outlined,
          enabled: enabled,
          onPressed: () => onResolve(
            AppRoutes.ipd.location(
              queryParameters: <String, String>{'id': admissionId},
            ),
          ),
        ),
      if (dischargeHousekeepingNavigateRequirement.isAllowed(policy))
        AppButton.tertiary(
          label: l10n.dischargeOpenHousekeepingAction,
          leadingIcon: Icons.cleaning_services_outlined,
          enabled: enabled,
          onPressed: () => onResolve(AppRoutes.housekeeping.path),
        ),
    ];
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppWorkspaceDetailPanel(
      title: l10n.dischargeCrossModuleLinksTitle,
      child: Wrap(
        spacing: theme.spacing.sm,
        runSpacing: theme.spacing.sm,
        children: children,
      ),
    );
  }
}
