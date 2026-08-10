import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_preview_breakdown.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_feedback.dart';

/// Creates a tenant pay run draft from the Pay & Compensation desk.
Future<void> showHrGeneratePayrollDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!HrPayrollDraftsAtomPermissions.create.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => const _HrGeneratePayrollDialog(),
  );
}

class _HrGeneratePayrollDialog extends ConsumerStatefulWidget {
  const _HrGeneratePayrollDialog();

  @override
  ConsumerState<_HrGeneratePayrollDialog> createState() =>
      _HrGeneratePayrollDialogState();
}

class _HrGeneratePayrollDialogState
    extends ConsumerState<_HrGeneratePayrollDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  DateTime? _periodStart = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _periodEnd = DateTime.now();
  bool _isSaving = false;

  String? _utcDatePayload(DateTime? value) {
    if (value == null) {
      return null;
    }
    final DateTime utc = DateTime.utc(value.year, value.month, value.day);
    return utc.toIso8601String();
  }

  String? _resolveTenantId() {
    final String? sessionTenant = ref
        .read(sessionStateProvider)
        .session
        ?.user
        ?.tenantId;
    if (sessionTenant != null && sessionTenant.trim().isNotEmpty) {
      return sessionTenant.trim();
    }
    final HrWorkspaceState? state = readHrWorkspaceState(ref);
    return state?.selectedStaff?.profile.tenantId ??
        state?.staff.items.firstOrNull?.tenantId;
  }

  Future<void> _openPreview(String runId) async {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final Result<HrPayrollPreview> result = await controller
        .previewPayrollRunById(runId);
    if (!mounted) {
      return;
    }
    await result.when(
      success: (HrPayrollPreview preview) async {
        await showAppDialog<void>(
          context: context,
          builder: (_) => AppDialog(
            title: Text(l10n.hrPreviewPayrollDialogTitle),
            icon: const Icon(Icons.receipt_long_outlined),
            scrollable: true,
            maxWidth: 720,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppInfoTileGrid(
                  emptyValue: l10n.profileUnknownValue,
                  items: <AppInfoTileData>[
                    AppInfoTileData(
                      label: l10n.hrPeriodColumnLabel,
                      value: hrDateRange(
                        context,
                        preview.periodStart,
                        preview.periodEnd,
                      ),
                      icon: Icons.date_range_outlined,
                    ),
                    AppInfoTileData(
                      label: l10n.hrStatusColumnLabel,
                      value: preview.status,
                      icon: Icons.radio_button_checked,
                    ),
                    AppInfoTileData(
                      label: l10n.hrPayrollReportLabel,
                      value:
                          '${preview.totalAmount} ${preview.currency ?? ''} (${preview.staffCount} staff)',
                      icon: Icons.payments_outlined,
                    ),
                  ],
                ),
                SizedBox(height: Theme.of(context).spacing.md),
                for (final HrPayrollPreviewItem line in preview.items.take(12))
                  HrPayrollPreviewBreakdown(item: line),
              ],
            ),
          ),
        );
      },
      failure: (AppFailure failure) {
        showAppFailureSnackBar(context, failure);
      },
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? tenantId = _resolveTenantId();
    if (tenantId == null || tenantId.isEmpty) {
      showAppFailureSnackBar(context, AppFailure.validation());
      return;
    }

    setState(() => _isSaving = true);
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final Result<String> result = await controller.createPayrollRunDraft(
      <String, Object?>{
        'tenant_id': tenantId,
        'period_start': _utcDatePayload(_periodStart),
        'period_end': _utcDatePayload(_periodEnd),
        'status': 'DRAFT',
      },
    );
    if (!mounted) {
      return;
    }

    await result.when(
      success: (String runId) async {
        await controller.applyWorkItemsScope(
          queue: HrQueue.payrollDrafts,
        );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop();
        showAppSuccessSnackBar(
          context,
          context.l10n.hrPayCompensationGenerateAction,
        );
        await _openPreview(runId);
      },
      failure: (AppFailure failure) async {
        setState(() => _isSaving = false);
        showAppFailureSnackBar(context, failure);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.hrPayCompensationGenerateTitle),
      icon: const Icon(Icons.payments_outlined),
      showMaximizeButton: false,
      closeEnabled: !_isSaving,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        children: <Widget>[
          Text(
            l10n.hrPayCompensationGenerateBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          AppDateField(
            value: _periodStart,
            labelText: l10n.hrPeriodStartLabel,
            isRequired: true,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.hrPickDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            enableSpeechToText: false,
            onChanged: (DateTime? value) => setState(() => _periodStart = value),
          ),
          AppDateField(
            value: _periodEnd,
            labelText: l10n.hrPeriodEndLabel,
            isRequired: true,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.hrPickDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            enableSpeechToText: false,
            onChanged: (DateTime? value) => setState(() => _periodEnd = value),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.close(
          label: l10n.commonCloseActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.hrPayCompensationGenerateAction,
          leadingIcon: Icons.add_card_outlined,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _submit,
        ),
      ],
    );
  }
}
