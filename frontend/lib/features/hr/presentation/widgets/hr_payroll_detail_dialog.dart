import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_labels.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_preview_breakdown.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_workspace_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

Future<void> showHrPayrollDetailDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => _HrPayrollDetailShell(item: item),
  );
}

class _HrPayrollDetailShell extends ConsumerStatefulWidget {
  const _HrPayrollDetailShell({required this.item});

  final HrWorkItem item;

  @override
  ConsumerState<_HrPayrollDetailShell> createState() =>
      _HrPayrollDetailShellState();
}

class _HrPayrollDetailShellState extends ConsumerState<_HrPayrollDetailShell> {
  HrPayrollPreview? _preview;
  AppFailure? _failure;
  bool _loadingPreview = true;
  bool _busy = false;

  HrWorkItem get _item => widget.item;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPreview());
    });
  }

  Future<void> _loadPreview() async {
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    setState(() {
      _loadingPreview = true;
      _failure = null;
    });
    final Result<HrPayrollPreview> result = await controller.previewPayrollRun(
      _item,
    );
    if (!mounted) {
      return;
    }
    result.when(
      success: (HrPayrollPreview preview) {
        setState(() {
          _preview = preview;
          _loadingPreview = false;
          _failure = null;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _preview = null;
          _loadingPreview = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _approveAndNotify() async {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final GlobalKey<HrProcessPayrollFieldsState> fieldsKey =
        GlobalKey<HrProcessPayrollFieldsState>();
    final bool? saved = await showAppWorkspaceMutationDialog(
      context: context,
      title: Text(l10n.hrPayCompensationApproveSendAction),
      icon: const Icon(Icons.price_check_outlined),
      submitLabel: l10n.hrPayCompensationApproveSendAction,
      cancelLabel: l10n.commonCancelActionLabel,
      submitIcon: Icons.price_check_outlined,
      buildFields:
          (
            BuildContext context,
            GlobalKey<FormState> formKey,
            bool _, [
            AppFailure? failure,
          ]) {
            return HrProcessPayrollFields(key: fieldsKey);
          },
      onSubmit: () {
        final Map<String, Object?> payload =
            fieldsKey.currentState?.toPayload() ?? <String, Object?>{};
        return controller.processPayrollRun(
          _item,
          replaceExistingItems: payload['replace_existing_items'] == true,
          notes: payload['notes']?.toString(),
        );
      },
    );
    if (saved == true && mounted) {
      showHrMutationSnackBar(context, null);
      await _loadPreview();
    }
  }

  Future<void> _markPaid() async {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.hrPayCompensationMarkPaidTitle,
        body: l10n.hrPayCompensationMarkPaidBody(_item.effectiveId),
        submitLabel: l10n.hrPayCompensationMarkPaidAction,
        icon: const Icon(Icons.payments_outlined),
        onConfirm: () => controller.markPayrollRunPaidById(_item.effectiveId),
      ),
    );
    if (confirmed == true && mounted) {
      showHrMutationSnackBar(context, null);
      await _loadPreview();
    }
  }

  Future<void> _cancelPayRun() async {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.hrPayCompensationCancelTitle,
        body: l10n.hrPayCompensationCancelBody(_item.effectiveId),
        submitLabel: l10n.hrPayCompensationCancelAction,
        destructive: true,
        icon: const Icon(Icons.cancel_outlined),
        onConfirm: () => controller.cancelPayrollRunById(_item.effectiveId),
      ),
    );
    if (confirmed == true && mounted) {
      showHrMutationSnackBar(context, null);
      await _loadPreview();
    }
  }

  Future<void> _printPayroll() async {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final String runId = hrPayrollRunId(_item);
    final String bodyHtml = _buildPrintHtml(l10n, locale);

    setState(() => _busy = true);
    try {
      if (!mounted) {
        return;
      }
      await PrintDocumentTemplates.registry(
        ref: ref,
        context: context,
        title: l10n.hrPayrollDetailDialogTitle,
        subtitle: runId,
        bodyHtml: bodyHtml,
        bodyHtmlBuilder: () => _buildPrintHtml(l10n, locale),
        previewDialogTitle: l10n.hrPayrollPrintDialogTitle,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _buildPrintHtml(AppLocalizations l10n, Locale locale) {
    final HrPayrollPreview? preview = _preview;
    final String currency = hrPayrollCurrencyCode(
      _item,
      fallback: preview?.currency,
    );
    final num total = preview?.totalAmount ?? _item.totalAmount;
    final int staffCount = preview?.staffCount ?? _item.staffCount;
    final StringBuffer buffer = StringBuffer();

    buffer.writeln('<h2>${hrPayrollEscapeHtml(l10n.hrPayrollOverviewSectionTitle)}</h2>');
    buffer.writeln(
      '<table style="width:100%;border-collapse:collapse;margin:0 0 16px;font-size:12px;">'
      '<tbody>',
    );
    void row(String label, String value) {
      buffer.writeln(
        '<tr>'
        '<td style="padding:8px 10px;width:34%;color:#546E7A;border-bottom:1px solid #ECEFF1;">${hrPayrollEscapeHtml(label)}</td>'
        '<td style="padding:8px 10px;border-bottom:1px solid #ECEFF1;font-weight:600;">${hrPayrollEscapeHtml(value)}</td>'
        '</tr>',
      );
    }

    row(l10n.hrPayrollRunDialogTitle, hrPayrollRunId(_item));
    row(
      l10n.hrPeriodColumnLabel,
      (_item.periodLabel ?? '').trim().isNotEmpty
          ? _item.periodLabel!
          : l10n.profileUnknownValue,
    );
    row(l10n.hrStatusColumnLabel, hrPayrollStatusLabel(l10n, _item.status));
    row(l10n.hrPayCompensationStaffCountColumn, '$staffCount');
    row(hrPayrollTotalColumnLabel(l10n, currencyCode: currency), hrPayrollAmountLabel(total, locale));
    row(
      l10n.hrPayCompensationLaneColumn,
      hrPayrollLaneLabel(l10n, _item.paymentLane),
    );
    row(l10n.hrNextActionColumnLabel, hrPayrollNextActionLabel(l10n, _item));
    buffer.writeln('</tbody></table>');

    final List<HrPayrollPreviewItem> items =
        preview?.items ?? const <HrPayrollPreviewItem>[];
    if (items.isNotEmpty) {
      buffer.writeln(
        '<h2>${hrPayrollEscapeHtml(l10n.hrPayrollBreakdownSectionTitle)}</h2>',
      );
      buffer.writeln(
        '<table style="width:100%;border-collapse:collapse;margin:0 0 16px;font-size:12px;">'
        '<thead><tr>'
        '<th style="text-align:left;padding:8px 10px;border-bottom:2px solid #CFD8DC;">${hrPayrollEscapeHtml(l10n.hrStaffColumnLabel)}</th>'
        '<th style="text-align:right;padding:8px 10px;border-bottom:2px solid #CFD8DC;">${hrPayrollEscapeHtml(hrPayrollTotalColumnLabel(l10n, currencyCode: currency))}</th>'
        '</tr></thead><tbody>',
      );
      for (final HrPayrollPreviewItem line in items) {
        final String name =
            (line.staffName ?? line.staffNumber ?? line.staffProfileId ?? '')
                .trim();
        final String lineCurrency =
            (line.currency ?? currency).trim().toUpperCase();
        buffer.writeln(
          '<tr>'
          '<td style="padding:8px 10px;border-bottom:1px solid #ECEFF1;">${hrPayrollEscapeHtml(name.isEmpty ? l10n.profileUnknownValue : name)}</td>'
          '<td style="padding:8px 10px;border-bottom:1px solid #ECEFF1;text-align:right;">${hrPayrollEscapeHtml(hrPayrollAmountLabel(line.amount, locale, treatZeroAsEmpty: false))} ${hrPayrollEscapeHtml(lineCurrency)}</td>'
          '</tr>',
        );
      }
      buffer.writeln('</tbody></table>');
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final HrWorkspaceState? state = readHrWorkspaceState(ref);
    final bool enabled = state?.isMutating != true && !_busy;
    final String currency = hrPayrollCurrencyCode(
      _item,
      fallback: _preview?.currency,
    );
    final num total = _preview?.totalAmount ?? _item.totalAmount;
    final int staffCount = _preview?.staffCount ?? _item.staffCount;
    final List<HrPayrollPreviewItem> lines =
        _preview?.items ?? const <HrPayrollPreviewItem>[];

    return AppDialog(
      title: Text(l10n.hrPayrollDetailDialogTitle),
      icon: const Icon(Icons.payments_outlined),
      scrollable: true,
      maxWidth: 980,
      stackActionsWhenCompact: false,
      pinActionsToBottom: true,
      content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppCollapsibleSection(
              title: l10n.hrPayrollOverviewSectionTitle,
              titleIcon: Icons.info_outline,
              child: AppInfoSheetGrid(
                emptyValue: l10n.profileUnknownValue,
                spacing: theme.spacing.lg,
                runSpacing: theme.spacing.sm,
                layout: AppInfoSheetLayout.inline,
                items: <AppInfoSheetItem>[
                  AppInfoSheetItem(
                    label: l10n.hrPayrollRunDialogTitle,
                    value: hrPayrollRunId(_item),
                  ),
                  AppInfoSheetItem(
                    label: l10n.hrPeriodColumnLabel,
                    value: (_item.periodLabel ?? '').trim().isNotEmpty
                        ? _item.periodLabel
                        : null,
                  ),
                  AppInfoSheetItem(
                    label: l10n.hrStatusColumnLabel,
                    value: hrPayrollStatusLabel(l10n, _item.status),
                  ),
                  AppInfoSheetItem(
                    label: l10n.hrPayCompensationStaffCountColumn,
                    value: '$staffCount',
                  ),
                  AppInfoSheetItem(
                    label: hrPayrollTotalColumnLabel(
                      l10n,
                      currencyCode: currency,
                    ),
                    value: hrPayrollAmountLabel(total, locale),
                  ),
                  AppInfoSheetItem(
                    label: l10n.hrPayCompensationLaneColumn,
                    value: hrPayrollLaneLabel(l10n, _item.paymentLane),
                  ),
                  AppInfoSheetItem(
                    label: l10n.hrNextActionColumnLabel,
                    value: hrPayrollNextActionLabel(l10n, _item),
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.spacing.lg),
            AppCollapsibleSection(
              title: l10n.hrPayrollBreakdownSectionTitle,
              titleIcon: Icons.receipt_long_outlined,
              child: _loadingPreview
                  ? const Center(child: CircularProgressIndicator())
                  : _failure != null && lines.isEmpty
                  ? Text(
                      _failure!.detailMessage ?? _failure!.messageKey,
                    )
                  : lines.isEmpty
                  ? Text(l10n.hrPayrollBreakdownEmptyBody)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final HrPayrollPreviewItem line in lines)
                          HrPayrollPreviewBreakdown(item: line),
                      ],
                    ),
            ),
          ],
        ),
        actions: <Widget>[
          if (hrPayrollIsPendingReview(_item))
            AppAccessActionGate(
              requirement: HrPayrollDraftsAtomPermissions.process,
              builder: (BuildContext context, bool isAllowed) {
                return AppButton.secondary(
                  leadingIcon: Icons.price_check_outlined,
                  label: l10n.hrPayCompensationApproveSendAction,
                  tooltip: l10n.hrPayCompensationApproveSendAction,
                  dense: true,
                  enabled: isAllowed && enabled,
                  onPressed: !isAllowed || !enabled ? null : _approveAndNotify,
                );
              },
            ),
          if (hrPayrollIsApproved(_item))
            AppAccessActionGate(
              requirement: HrPayrollDraftsAtomPermissions.process,
              builder: (BuildContext context, bool isAllowed) {
                return AppButton.secondary(
                  leadingIcon: Icons.payments_outlined,
                  label: l10n.hrPayCompensationMarkPaidAction,
                  tooltip: l10n.hrPayCompensationMarkPaidAction,
                  dense: true,
                  enabled: isAllowed && enabled,
                  onPressed: !isAllowed || !enabled ? null : _markPaid,
                );
              },
            ),
          if (hrPayrollIsPendingReview(_item) || hrPayrollIsApproved(_item))
            AppAccessActionGate(
              requirement: HrPayrollDraftsAtomPermissions.process,
              builder: (BuildContext context, bool isAllowed) {
                return AppButton.secondary(
                  leadingIcon: Icons.cancel_outlined,
                  label: l10n.hrPayCompensationCancelAction,
                  tooltip: l10n.hrPayCompensationCancelAction,
                  dense: true,
                  color: theme.colorScheme.error,
                  enabled: isAllowed && enabled,
                  onPressed: !isAllowed || !enabled ? null : _cancelPayRun,
                );
              },
            ),
          AppAccessActionGate(
            requirement: HrPayrollDraftsAtomPermissions.preview,
            hideWhenDenied: false,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                leadingIcon: Icons.print_outlined,
                label: l10n.commonPrintActionLabel,
                tooltip: l10n.commonPrintActionLabel,
                dense: true,
                enabled: isAllowed && enabled && !_loadingPreview,
                onPressed: !isAllowed || !enabled || _loadingPreview
                    ? null
                    : _printPayroll,
              );
            },
          ),
          AppButton.close(
            label: l10n.commonCloseActionLabel,
            tooltip: l10n.commonCloseActionLabel,
            dense: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
    );
  }
}
