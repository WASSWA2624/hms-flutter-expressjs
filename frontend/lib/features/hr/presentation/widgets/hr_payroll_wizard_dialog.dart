import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_preview_breakdown.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

Future<void> showHrPayrollWizardDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => _HrPayrollWizardDialog(staff: staff),
  );
}

class _HrPayrollWizardDialog extends ConsumerStatefulWidget {
  const _HrPayrollWizardDialog({required this.staff});

  final HrStaffProfile staff;

  @override
  ConsumerState<_HrPayrollWizardDialog> createState() =>
      _HrPayrollWizardDialogState();
}

class _HrPayrollWizardDialogState extends ConsumerState<_HrPayrollWizardDialog> {
  int _step = 0;
  DateTime? _periodStart = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _periodEnd = DateTime.now();
  HrPayrollPreview? _preview;
  AppFailure? _failure;
  bool _isLoading = false;
  String? _createdRunId;

  Future<void> _createDraft() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final Result<String> createResult = await controller.createPayrollRunDraft(
      <String, Object?>{
        'tenant_id': widget.staff.tenantId,
        'period_start': _periodStart?.toIso8601String(),
        'period_end': _periodEnd?.toIso8601String(),
        'status': 'DRAFT',
      },
    );
    if (!mounted) {
      return;
    }
    await createResult.when(
      success: (String runId) async {
        _createdRunId = runId;
        await _loadPreview(controller);
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _loadPreview(HrWorkspaceController controller) async {
    final String? runId = _createdRunId;
    if (runId == null) {
      setState(() {
        _isLoading = false;
        _failure = AppFailure.validation();
      });
      return;
    }
    final Result<HrPayrollPreview> result = await controller.previewPayrollRunById(
      runId,
      staffProfileId: widget.staff.id,
    );
    if (!mounted) {
      return;
    }
    result.when(
      success: (HrPayrollPreview preview) {
        setState(() {
          _preview = preview;
          _step = 1;
          _isLoading = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _processPayroll() async {
    final String? runId = _createdRunId ?? _preview?.runId;
    if (runId == null) {
      return;
    }
    setState(() => _isLoading = true);
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = await controller.processPayrollRunById(
      runId,
      replaceExistingItems: true,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
    if (failure == null) {
      Navigator.of(context).pop();
      showHrMutationSnackBar(context, null);
    } else {
      setState(() => _failure = failure);
    }
  }

  List<HrPayrollPreviewItem> get _scopedItems {
    final HrPayrollPreview? preview = _preview;
    if (preview == null) {
      return const <HrPayrollPreviewItem>[];
    }
    return preview.items
        .where(
          (HrPayrollPreviewItem item) =>
              item.staffProfileId == widget.staff.id ||
              item.staffProfileDisplayId == widget.staff.effectiveId ||
              item.staffNumber == widget.staff.staffNumber,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.hrPayrollWizardTitle),
      icon: const Icon(Icons.payments_outlined),
      scrollable: true,
      maxWidth: 720,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LinearProgressIndicator(value: (_step + 1) / 4),
          SizedBox(height: theme.spacing.md),
          if (_failure != null)
            Text(
              l10n.failureMessage(_failure!),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (_step == 0)
            AppFormSection(
              title: l10n.hrPayrollWizardPeriodStepTitle,
              children: <Widget>[
                AppDateField(
                  value: _periodStart,
                  labelText: l10n.hrPayPeriodStartLabel,
                  isRequired: true,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  currentDate: DateTime.now(),
                  pickerButtonLabel: l10n.hrPickDateAction,
                  invalidDateMessage: l10n.appDateInvalidMessage,
                  onChanged: (DateTime? value) =>
                      setState(() => _periodStart = value),
                ),
                AppDateField(
                  value: _periodEnd,
                  labelText: l10n.hrPayPeriodEndLabel,
                  isRequired: true,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  currentDate: DateTime.now(),
                  pickerButtonLabel: l10n.hrPickDateAction,
                  invalidDateMessage: l10n.appDateInvalidMessage,
                  onChanged: (DateTime? value) =>
                      setState(() => _periodEnd = value),
                ),
              ],
            ),
          if (_step == 1 && _preview != null) ...<Widget>[
            Text(l10n.hrPayrollWizardPreviewStepTitle),
            SizedBox(height: theme.spacing.sm),
            for (final HrPayrollPreviewItem item in _scopedItems)
              HrPayrollPreviewBreakdown(
                item: item,
                defaultStaffName: widget.staff.displayName,
              ),
            if (_scopedItems.isEmpty)
              Text(l10n.hrPayrollWizardNoStaffItemsLabel),
          ],
          if (_step == 2 && _preview != null)
            AppInfoTileGrid(
              emptyValue: l10n.profileUnknownValue,
              items: <AppInfoTileData>[
                AppInfoTileData(
                  label: l10n.hrPayrollStaffCountLabel,
                  value: _scopedItems.length.toString(),
                  icon: Icons.people_outline,
                ),
                AppInfoTileData(
                  label: l10n.hrGrossPayLabel,
                  value: '${_preview!.totalAmount} ${_preview!.currency ?? ''}',
                  icon: Icons.payments_outlined,
                ),
                AppInfoTileData(
                  label: l10n.hrDeductionsLabel,
                  value: l10n.profileUnknownValue,
                  icon: Icons.remove_circle_outline,
                ),
                AppInfoTileData(
                  label: l10n.hrNetPayLabel,
                  value: '${_preview!.totalAmount} ${_preview!.currency ?? ''}',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
          if (_step == 3)
            Text(l10n.hrPayrollWizardProcessStepBody),
        ],
      ),
      actions: <Widget>[
        if (_step > 0)
          AppButton.secondary(
            label: l10n.commonCancelActionLabel,
            enabled: !_isLoading,
            onPressed: () => setState(() => _step -= 1),
          ),
        AppButton(
          label: switch (_step) {
            0 => l10n.hrPayrollWizardPreviewAction,
            1 => l10n.hrPayrollWizardReviewAction,
            2 => l10n.hrProcessPayrollAction,
            _ => l10n.hrRunPayrollAction,
          },
          isLoading: _isLoading,
          onPressed: _isLoading
              ? null
              : () async {
                  if (_step == 0) {
                    await _createDraft();
                    return;
                  }
                  if (_step < 3) {
                    setState(() => _step += 1);
                    return;
                  }
                  await _processPayroll();
                },
        ),
      ],
    );
  }
}
