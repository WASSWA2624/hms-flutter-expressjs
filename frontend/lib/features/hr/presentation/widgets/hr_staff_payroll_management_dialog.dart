import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_compensation_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_preview_breakdown.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> showHrStaffPayrollManagementDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
  List<HrStaffCompensation> compensations,
) async {
  if (!HrHumanResourcesAtomPermissions.runPayroll.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => _HrStaffPayrollManagementDialog(
      staff: staff,
      compensations: compensations,
    ),
  );
}

class _HrStaffPayrollManagementDialog extends ConsumerStatefulWidget {
  const _HrStaffPayrollManagementDialog({
    required this.staff,
    required this.compensations,
  });

  final HrStaffProfile staff;
  final List<HrStaffCompensation> compensations;

  @override
  ConsumerState<_HrStaffPayrollManagementDialog> createState() =>
      _HrStaffPayrollManagementDialogState();
}

class _DeductionDraft {
  _DeductionDraft({
    required this.code,
    required this.labelController,
    required this.valueController,
    this.mode = 'FIXED',
  });

  String code;
  final TextEditingController labelController;
  final TextEditingController valueController;
  String mode;

  void dispose() {
    labelController.dispose();
    valueController.dispose();
  }

  Map<String, Object?>? toPayload() {
    final num? value = num.tryParse(valueController.text.trim());
    if (value == null) {
      return null;
    }
    final String label = labelController.text.trim();
    return <String, Object?>{
      'code': code,
      if (label.isNotEmpty) 'label': label,
      'mode': mode,
      'value': value,
    };
  }
}

class _HrStaffPayrollManagementDialogState
    extends ConsumerState<_HrStaffPayrollManagementDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late List<HrStaffCompensation> _compensations;
  final List<_DeductionDraft> _deductions = <_DeductionDraft>[];
  final TextEditingController _bankReferenceController =
      TextEditingController();

  DateTime? _periodStart = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _periodEnd = DateTime.now();
  HrPayrollPreview? _preview;
  AppFailure? _failure;
  bool _isLoading = false;
  bool _isSavingDeductions = false;
  String? _createdRunId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _compensations = List<HrStaffCompensation>.from(widget.compensations);
    _hydrateDeductions();
  }

  void _hydrateDeductions() {
    for (final _DeductionDraft draft in _deductions) {
      draft.dispose();
    }
    _deductions.clear();
    final HrStaffCompensation? monthly = _activeMonthly();
    final List<HrPayrollDeduction> source =
        monthly?.deductions ?? const <HrPayrollDeduction>[];
    for (final HrPayrollDeduction row in source) {
      _deductions.add(
        _DeductionDraft(
          code: row.code,
          labelController: TextEditingController(text: row.label ?? ''),
          valueController: TextEditingController(text: row.value.toString()),
          mode: row.mode,
        ),
      );
    }
  }

  HrStaffCompensation? _activeMonthly() {
    for (final HrStaffCompensation row in _compensations) {
      if (row.isActive && (row.payType ?? '').toUpperCase() == 'PER_MONTH') {
        return row;
      }
    }
    for (final HrStaffCompensation row in _compensations) {
      if (row.isActive) {
        return row;
      }
    }
    return null;
  }

  List<HrStaffCompensation> get _activeCompensations => _compensations
      .where((HrStaffCompensation row) => row.isActive)
      .toList(growable: false);

  @override
  void dispose() {
    _tabController.dispose();
    _bankReferenceController.dispose();
    for (final _DeductionDraft draft in _deductions) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _openSalaryEditor() async {
    await showHrCompensationDialog(
      context,
      ref,
      widget.staff,
      _compensations,
    );
    if (!mounted) {
      return;
    }
    _syncCompensationsFromWorkspace();
  }

  void _syncCompensationsFromWorkspace() {
    final HrStaffDetail? detail = readHrWorkspaceState(ref)?.selectedStaff;
    if (detail == null) {
      return;
    }
    setState(() {
      _compensations = List<HrStaffCompensation>.from(detail.compensations);
      _hydrateDeductions();
    });
  }

  Future<void> _saveDeductions() async {
    final List<HrStaffCompensation> active = _activeCompensations;
    if (active.isEmpty) {
      setState(() {
        _failure = AppFailure.validation(
          detailMessage: context.l10n.hrPayrollDeductionsRequireSalaryMessage,
        );
      });
      return;
    }

    setState(() {
      _isSavingDeductions = true;
      _failure = null;
    });

    final List<Map<String, Object?>> deductionPayloads = _deductions
        .map((_DeductionDraft draft) => draft.toPayload())
        .whereType<Map<String, Object?>>()
        .toList(growable: false);

    final HrStaffCompensation? primary = _activeMonthly();
    final List<Map<String, Object?>> compensationPayloads = <Map<String, Object?>>[];
    for (final HrStaffCompensation row in active) {
      final bool attachDeductions = identical(row, primary);
      final Map<String, Object?> metadata = <String, Object?>{
        'pay_frequency': (row.payFrequency ?? '').trim().isEmpty
            ? 'MONTHLY'
            : row.payFrequency,
        if (attachDeductions) 'deductions': deductionPayloads,
      };
      compensationPayloads.add(<String, Object?>{
        if (row.id.trim().isNotEmpty) 'id': row.id,
        'pay_type': row.payType ?? 'PER_MONTH',
        'rate': row.rate ?? 0,
        'currency': (row.currency ?? appDefaultCurrencyCode).toUpperCase(),
        'effective_from':
            (row.effectiveFrom ?? DateTime.now()).toUtc().toIso8601String(),
        if (row.effectiveTo != null)
          'effective_to': row.effectiveTo!.toUtc().toIso8601String(),
        'metadata_json': metadata,
      });
    }

    final AppFailure? failure = await ref
        .read(hrWorkspaceControllerProvider.notifier)
        .updateSelectedStaffProfile(<String, Object?>{
          'compensations': compensationPayloads,
        });
    if (!mounted) {
      return;
    }
    setState(() => _isSavingDeductions = false);
    if (failure != null) {
      setState(() => _failure = failure);
      return;
    }
    showHrMutationSnackBar(context, null);
    _syncCompensationsFromWorkspace();
  }

  void _addDeduction() {
    setState(() {
      _deductions.add(
        _DeductionDraft(
          code: 'TAX',
          labelController: TextEditingController(),
          valueController: TextEditingController(),
        ),
      );
    });
  }

  Future<void> _createDraftAndPreview() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final Result<String> createResult = await controller
        .createPayrollRunDraft(<String, Object?>{
          'tenant_id': widget.staff.tenantId,
          'period_start': _periodStart?.toIso8601String(),
          'period_end': _periodEnd?.toIso8601String(),
          'status': 'DRAFT',
          if (_bankReferenceController.text.trim().isNotEmpty)
            'notes': _bankReferenceController.text.trim(),
        });
    if (!mounted) {
      return;
    }
    await createResult.when(
      success: (String runId) async {
        _createdRunId = runId;
        final Result<HrPayrollPreview> result = await controller
            .previewPayrollRunById(runId, staffProfileId: widget.staff.id);
        if (!mounted) {
          return;
        }
        result.when(
          success: (HrPayrollPreview preview) {
            setState(() {
              _preview = preview;
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
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _approveAndSend() async {
    String? processId = _createdRunId ?? _preview?.runId;
    if (processId == null) {
      await _createDraftAndPreview();
      processId = _createdRunId ?? _preview?.runId;
      if (processId == null) {
        return;
      }
    }
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(hrWorkspaceControllerProvider.notifier)
        .processPayrollRunById(processId, replaceExistingItems: true);
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
    final double tabBodyHeight = (MediaQuery.sizeOf(context).height * 0.55)
        .clamp(280.0, 480.0);

    return AppDialog(
      title: Text(l10n.hrManagePayrollDialogTitle),
      icon: const Icon(Icons.account_balance_wallet_outlined),
      scrollable: true,
      maxWidth: 760,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          TabBar(
            controller: _tabController,
            tabs: <Widget>[
              Tab(text: l10n.hrPayrollSalaryTabLabel),
              Tab(text: l10n.hrPayrollDeductionsTabLabel),
              Tab(text: l10n.hrPayrollPaymentsTabLabel),
            ],
          ),
          SizedBox(
            height: tabBodyHeight,
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildSalaryTab(l10n, theme),
                _buildDeductionsTab(l10n, theme),
                _buildPaymentsTab(l10n, theme),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.close(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSalaryTab(AppLocalizations l10n, ThemeData theme) {
    final List<HrStaffCompensation> active = _activeCompensations;
    return SingleChildScrollView(
      primary: false,
      padding: EdgeInsets.only(top: theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.hrPayrollSalaryTabBody,
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: theme.spacing.md),
          if (active.isEmpty)
            AppStateView(
              variant: AppStateViewVariant.empty,
              title: l10n.hrNoCompensationLabel,
              body: l10n.hrStaffPayrollEmptyBody,
              icon: Icons.price_change_outlined,
              action: AppButton.primary(
                label: l10n.hrCompensationAction,
                leadingIcon: Icons.price_change_outlined,
                onPressed: _openSalaryEditor,
              ),
            )
          else
            for (final HrStaffCompensation row in active) ...<Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(hrCompensationRowTitle(context, row)),
                subtitle: Text(
                  l10n.hrReferenceCompensationPayTypeLabel(
                    row.payType ?? '',
                    fallback: row.payType,
                  ),
                ),
                trailing: Text(
                  row.payFrequency ?? '',
                  style: theme.textTheme.labelMedium,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
            ],
          if (active.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton.secondary(
                label: l10n.hrPayrollEditSalaryAction,
                leadingIcon: Icons.edit_outlined,
                onPressed: _openSalaryEditor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeductionsTab(AppLocalizations l10n, ThemeData theme) {
    return SingleChildScrollView(
      primary: false,
      padding: EdgeInsets.only(top: theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.hrPayrollDeductionsTabBody,
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: theme.spacing.md),
          for (int i = 0; i < _deductions.length; i++) ...<Widget>[
            AppContentPanel(
              density: AppContentPanelDensity.compact,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppSelectField<String>(
                          value: _deductions[i].code,
                          labelText: l10n.hrPayrollDeductionTypeLabel,
                          options: <AppSelectOption<String>>[
                            AppSelectOption<String>(
                              value: 'TAX',
                              label: l10n.hrPayrollDeductionTaxLabel,
                            ),
                            AppSelectOption<String>(
                              value: 'NSSF',
                              label: l10n.hrPayrollDeductionNssfLabel,
                            ),
                            AppSelectOption<String>(
                              value: 'NHIF',
                              label: l10n.hrPayrollDeductionNhifLabel,
                            ),
                            AppSelectOption<String>(
                              value: 'LOAN',
                              label: l10n.hrPayrollDeductionLoanLabel,
                            ),
                            AppSelectOption<String>(
                              value: 'OTHER',
                              label: l10n.hrPayrollDeductionOtherLabel,
                            ),
                          ],
                          onChanged: (String? value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _deductions[i].code = value);
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.hrPayrollRemoveDeductionAction,
                        onPressed: () {
                          setState(() {
                            _deductions[i].dispose();
                            _deductions.removeAt(i);
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  AppTextField(
                    controller: _deductions[i].labelController,
                    labelText: l10n.hrPayrollDeductionLabelField,
                  ),
                  AppSelectField<String>(
                    value: _deductions[i].mode,
                    labelText: l10n.hrPayrollDeductionModeLabel,
                    options: <AppSelectOption<String>>[
                      AppSelectOption<String>(
                        value: 'FIXED',
                        label: l10n.hrPayrollDeductionModeFixedLabel,
                      ),
                      AppSelectOption<String>(
                        value: 'PERCENT',
                        label: l10n.hrPayrollDeductionModePercentLabel,
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _deductions[i].mode = value);
                    },
                  ),
                  AppTextField(
                    controller: _deductions[i].valueController,
                    labelText: l10n.hrPayrollDeductionValueLabel,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.spacing.sm),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.secondary(
              label: l10n.hrPayrollAddDeductionAction,
              leadingIcon: Icons.add,
              onPressed: _addDeduction,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.primary(
              label: l10n.hrPayrollSaveDeductionsAction,
              leadingIcon: Icons.save_outlined,
              onPressed: _isSavingDeductions ? null : _saveDeductions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab(AppLocalizations l10n, ThemeData theme) {
    return SingleChildScrollView(
      primary: false,
      padding: EdgeInsets.only(top: theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.hrPayrollPaymentsTabBody,
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: theme.spacing.md),
          AppDateField(
            value: _periodStart,
            labelText: l10n.hrPayPeriodStartLabel,
            isRequired: true,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.hrPickDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            onChanged: (DateTime? value) => setState(() => _periodStart = value),
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
            onChanged: (DateTime? value) => setState(() => _periodEnd = value),
          ),
          AppTextField(
            controller: _bankReferenceController,
            labelText: l10n.hrPayrollBankReferenceLabel,
            hintText: l10n.hrPayrollBankReferenceHint,
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: <Widget>[
              AppButton.secondary(
                label: l10n.hrPayrollWizardPreviewAction,
                leadingIcon: Icons.preview_outlined,
                onPressed: _isLoading ? null : _createDraftAndPreview,
              ),
              AppButton.primary(
                label: l10n.hrPayrollApproveSendAction,
                leadingIcon: Icons.send_outlined,
                onPressed: _isLoading || _activeCompensations.isEmpty
                    ? null
                    : _approveAndSend,
              ),
            ],
          ),
          if (_isLoading) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            const LinearProgressIndicator(),
          ],
          if (_preview != null) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            Text(
              l10n.hrPayrollWizardPreviewStepTitle,
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: theme.spacing.sm),
            if (_scopedItems.isEmpty)
              Text(l10n.hrPayrollWizardNoStaffItemsLabel)
            else
              for (final HrPayrollPreviewItem item in _scopedItems)
                HrPayrollPreviewBreakdown(
                  item: item,
                  defaultStaffName: widget.staff.displayName,
                ),
          ],
        ],
      ),
    );
  }
}
