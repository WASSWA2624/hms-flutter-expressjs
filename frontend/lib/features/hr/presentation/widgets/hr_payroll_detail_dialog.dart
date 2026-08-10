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
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_labels.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_workspace_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
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
  String? _statusOverride;
  String _breakdownQuery = '';
  final TextEditingController _breakdownSearchController =
      TextEditingController();

  HrWorkItem get _item => widget.item;

  String get _effectiveStatus =>
      _statusOverride ?? _preview?.status ?? _item.status ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPreview());
    });
  }

  @override
  void dispose() {
    _breakdownSearchController.dispose();
    super.dispose();
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
          final String previewStatus = (preview.status ?? '').trim();
          if (previewStatus.isNotEmpty) {
            _statusOverride = previewStatus;
          }
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
      setState(() => _statusOverride = 'PROCESSED');
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
      setState(() => _statusOverride = 'PAID');
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
      setState(() => _statusOverride = 'CANCELLED');
      await _loadPreview();
    }
  }

  Future<void> _printPayroll() async {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final String period =
        (_item.periodLabel ?? '').trim().isNotEmpty
        ? _item.periodLabel!
        : hrPayrollRunId(_item);
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
        subtitle: period,
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

  String _payTypeLabel(AppLocalizations l10n, String? payType) {
    final String normalized = (payType ?? '').trim();
    if (normalized.isEmpty) {
      return l10n.hrGrossPayLabel;
    }
    return l10n.hrReferenceCompensationPayTypeLabel(
      normalized,
      fallback: normalized,
    );
  }

  String _basisLabel(AppLocalizations l10n, HrPayrollBreakdownRow row) {
    if (row.quantity == 0 && (row.unit ?? '').trim().isEmpty) {
      return l10n.profileUnknownValue;
    }
    final String unit = (row.unit ?? '').trim();
    final String quantity = hrPayrollAmountLabel(
      row.quantity,
      Localizations.localeOf(context),
      treatZeroAsEmpty: false,
    );
    if (unit.isEmpty) {
      return quantity;
    }
    return '$quantity $unit';
  }

  String _buildPrintHtml(AppLocalizations l10n, Locale locale) {
    final String currency = hrPayrollCurrencyCode(
      _item,
      fallback: _preview?.currency,
    );
    final num total = hrPayrollResolvedTotal(_item, _preview);
    final int staffCount = hrPayrollResolvedStaffCount(_item, _preview);
    final String paymentPath = hrPayrollLaneLabel(l10n, _item.paymentLane);
    final List<HrPayrollBreakdownRow> rows = hrPayrollBreakdownRows(
      preview: _preview,
      paymentPath: paymentPath,
    );
    final StringBuffer buffer = StringBuffer();

    buffer.writeln(
      '<h2 style="margin:0 0 10px;font-size:16px;">'
      '${hrPayrollEscapeHtml(l10n.hrPayrollOverviewSectionTitle)}'
      '</h2>',
    );
    buffer.writeln(
      '<table style="width:100%;border-collapse:collapse;margin:0 0 18px;font-size:12px;">'
      '<tbody>',
    );
    void overviewRow(String label, String value) {
      buffer.writeln(
        '<tr>'
        '<td style="padding:8px 10px;width:32%;color:#546E7A;border:1px solid #ECEFF1;background:#FAFAFA;">${hrPayrollEscapeHtml(label)}</td>'
        '<td style="padding:8px 10px;border:1px solid #ECEFF1;font-weight:600;">${hrPayrollEscapeHtml(value)}</td>'
        '</tr>',
      );
    }

    overviewRow(l10n.hrPayrollRunDialogTitle, hrPayrollRunId(_item));
    overviewRow(
      l10n.hrPeriodColumnLabel,
      (_item.periodLabel ?? '').trim().isNotEmpty
          ? _item.periodLabel!
          : l10n.profileUnknownValue,
    );
    overviewRow(
      l10n.hrStatusColumnLabel,
      hrPayrollStatusLabel(l10n, _effectiveStatus),
    );
    overviewRow(l10n.hrPayCompensationStaffCountColumn, '$staffCount');
    overviewRow(
      hrPayrollTotalColumnLabel(l10n, currencyCode: currency),
      hrPayrollAmountLabel(total, locale),
    );
    overviewRow(l10n.hrPayCompensationLaneColumn, paymentPath);
    overviewRow(
      l10n.hrNextActionColumnLabel,
      hrPayrollNextActionLabel(
        l10n,
        HrWorkItem(
          id: _item.id,
          queue: _item.queue,
          status: _effectiveStatus,
        ),
      ),
    );
    buffer.writeln('</tbody></table>');

    buffer.writeln(
      '<h2 style="margin:0 0 10px;font-size:16px;">'
      '${hrPayrollEscapeHtml(l10n.hrPayrollBreakdownSectionTitle)}'
      '</h2>',
    );
    if (rows.isEmpty) {
      buffer.writeln(
        '<p style="margin:0;color:#546E7A;font-size:12px;">'
        '${hrPayrollEscapeHtml(l10n.hrPayrollBreakdownEmptyBody)}'
        '</p>',
      );
      return buffer.toString();
    }

    buffer.writeln(
      '<table style="width:100%;border-collapse:collapse;margin:0 0 8px;font-size:12px;">'
      '<thead><tr>'
      '<th style="text-align:left;padding:8px 10px;border:1px solid #CFD8DC;background:#ECEFF1;">${hrPayrollEscapeHtml(l10n.hrStaffColumnLabel)}</th>'
      '<th style="text-align:left;padding:8px 10px;border:1px solid #CFD8DC;background:#ECEFF1;">${hrPayrollEscapeHtml(l10n.hrPayrollPayTypeColumn)}</th>'
      '<th style="text-align:left;padding:8px 10px;border:1px solid #CFD8DC;background:#ECEFF1;">${hrPayrollEscapeHtml(l10n.hrPayrollBasisColumn)}</th>'
      '<th style="text-align:right;padding:8px 10px;border:1px solid #CFD8DC;background:#ECEFF1;">${hrPayrollEscapeHtml(l10n.hrPayrollRateColumn)}</th>'
      '<th style="text-align:right;padding:8px 10px;border:1px solid #CFD8DC;background:#ECEFF1;">${hrPayrollEscapeHtml(hrPayrollTotalColumnLabel(l10n, currencyCode: currency))}</th>'
      '<th style="text-align:left;padding:8px 10px;border:1px solid #CFD8DC;background:#ECEFF1;">${hrPayrollEscapeHtml(l10n.hrPayrollPaymentPathColumn)}</th>'
      '</tr></thead><tbody>',
    );
    for (final HrPayrollBreakdownRow row in rows) {
      final String staff = row.staffName.trim().isEmpty
          ? l10n.profileUnknownValue
          : row.staffName;
      final String basis = row.quantity == 0 && (row.unit ?? '').trim().isEmpty
          ? l10n.profileUnknownValue
          : '${hrPayrollAmountLabel(row.quantity, locale, treatZeroAsEmpty: false)}${(row.unit ?? '').trim().isEmpty ? '' : ' ${row.unit}'}';
      buffer.writeln(
        '<tr>'
        '<td style="padding:8px 10px;border:1px solid #ECEFF1;">${hrPayrollEscapeHtml(staff)}</td>'
        '<td style="padding:8px 10px;border:1px solid #ECEFF1;">${hrPayrollEscapeHtml(_payTypeLabel(l10n, row.payType))}</td>'
        '<td style="padding:8px 10px;border:1px solid #ECEFF1;">${hrPayrollEscapeHtml(basis)}</td>'
        '<td style="padding:8px 10px;border:1px solid #ECEFF1;text-align:right;">${hrPayrollEscapeHtml(hrPayrollAmountLabel(row.rate, locale, treatZeroAsEmpty: false))}</td>'
        '<td style="padding:8px 10px;border:1px solid #ECEFF1;text-align:right;">${hrPayrollEscapeHtml(hrPayrollAmountLabel(row.amount, locale, treatZeroAsEmpty: false))}</td>'
        '<td style="padding:8px 10px;border:1px solid #ECEFF1;">${hrPayrollEscapeHtml(row.paymentPath)}</td>'
        '</tr>',
      );
    }
    buffer.writeln('</tbody></table>');
    return buffer.toString();
  }

  List<HrPayrollBreakdownRow> get _visibleBreakdownRows {
    final AppLocalizations l10n = context.l10n;
    final String paymentPath = hrPayrollLaneLabel(l10n, _item.paymentLane);
    final List<HrPayrollBreakdownRow> rows = hrPayrollBreakdownRows(
      preview: _preview,
      paymentPath: paymentPath,
    );
    final String needle = _breakdownQuery.trim().toLowerCase();
    if (needle.isEmpty) {
      return rows;
    }
    return rows
        .where((HrPayrollBreakdownRow row) {
          final String payType = _payTypeLabel(l10n, row.payType).toLowerCase();
          return row.staffName.toLowerCase().contains(needle) ||
              payType.contains(needle);
        })
        .toList(growable: false);
  }

  List<AppListTableColumn<HrPayrollBreakdownRow>> _breakdownColumns(
    AppLocalizations l10n,
    Locale locale,
    String currency,
  ) {
    return <AppListTableColumn<HrPayrollBreakdownRow>>[
      AppListTableColumn<HrPayrollBreakdownRow>(
        id: 'staff',
        label: l10n.hrStaffColumnLabel,
        sortComparator: (HrPayrollBreakdownRow a, HrPayrollBreakdownRow b) =>
            appListTableCompareText(a.staffName, b.staffName),
        cellBuilder: (BuildContext context, HrPayrollBreakdownRow row) {
          return Text(
            row.staffName.trim().isEmpty
                ? l10n.profileUnknownValue
                : row.staffName,
          );
        },
      ),
      AppListTableColumn<HrPayrollBreakdownRow>(
        id: 'pay_type',
        label: l10n.hrPayrollPayTypeColumn,
        sortComparator: (HrPayrollBreakdownRow a, HrPayrollBreakdownRow b) =>
            appListTableCompareText(a.payType, b.payType),
        cellBuilder: (BuildContext context, HrPayrollBreakdownRow row) {
          return Text(_payTypeLabel(l10n, row.payType));
        },
      ),
      AppListTableColumn<HrPayrollBreakdownRow>(
        id: 'basis',
        label: l10n.hrPayrollBasisColumn,
        cellBuilder: (BuildContext context, HrPayrollBreakdownRow row) {
          return Text(_basisLabel(l10n, row));
        },
      ),
      AppListTableColumn<HrPayrollBreakdownRow>(
        id: 'rate',
        label: l10n.hrPayrollRateColumn,
        sortComparator: (HrPayrollBreakdownRow a, HrPayrollBreakdownRow b) =>
            a.rate.compareTo(b.rate),
        cellBuilder: (BuildContext context, HrPayrollBreakdownRow row) {
          return Text(
            hrPayrollAmountLabel(row.rate, locale, treatZeroAsEmpty: false),
          );
        },
      ),
      AppListTableColumn<HrPayrollBreakdownRow>(
        id: 'amount',
        label: hrPayrollTotalColumnLabel(l10n, currencyCode: currency),
        sortComparator: (HrPayrollBreakdownRow a, HrPayrollBreakdownRow b) =>
            a.amount.compareTo(b.amount),
        cellBuilder: (BuildContext context, HrPayrollBreakdownRow row) {
          return Text(
            hrPayrollAmountLabel(row.amount, locale, treatZeroAsEmpty: false),
          );
        },
      ),
      AppListTableColumn<HrPayrollBreakdownRow>(
        id: 'payment_path',
        label: l10n.hrPayrollPaymentPathColumn,
        cellBuilder: (BuildContext context, HrPayrollBreakdownRow row) {
          return Text(row.paymentPath);
        },
      ),
    ];
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
    final num total = hrPayrollResolvedTotal(_item, _preview);
    final int staffCount = hrPayrollResolvedStaffCount(_item, _preview);
    final String status = _effectiveStatus.trim().toUpperCase();
    final bool pending =
        status == 'DRAFT' || status == 'PENDING' || status == 'PENDING_REVIEW';
    final bool approved = status == 'PROCESSED' || status == 'APPROVED';
    final List<HrPayrollBreakdownRow> visibleRows = _visibleBreakdownRows;

    return AppDialog(
      title: Text(l10n.hrPayrollDetailDialogTitle),
      icon: const Icon(Icons.payments_outlined),
      scrollable: true,
      maxWidth: 1100,
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
                  value: hrPayrollStatusLabel(l10n, _effectiveStatus),
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
                  value: hrPayrollNextActionLabel(
                    l10n,
                    HrWorkItem(
                      id: _item.id,
                      queue: _item.queue,
                      status: _effectiveStatus,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: theme.spacing.lg),
          AppCollapsibleSection(
            title: l10n.hrPayrollBreakdownSectionTitle,
            titleIcon: Icons.table_chart_outlined,
            contentPadding: EdgeInsets.only(bottom: theme.spacing.md),
            child: _loadingPreview
                ? const Center(child: CircularProgressIndicator())
                : _failure != null && visibleRows.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(theme.spacing.md),
                    child: Text(
                      _failure!.detailMessage ?? _failure!.messageKey,
                    ),
                  )
                : AppListTable<HrPayrollBreakdownRow>(
                    page: AppPage<HrPayrollBreakdownRow>(
                      items: visibleRows,
                      request: AppPageRequest(
                        pageSize: visibleRows.isEmpty
                            ? 20
                            : visibleRows.length,
                      ),
                      totalItemCount: visibleRows.length,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    forceCompact: true,
                    maxVisibleItems: visibleRows.isEmpty
                        ? 1
                        : visibleRows.length,
                    columnVisibilityStorageKey: 'hr_payroll_breakdown_v1',
                    columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
                    search: AppListTableSearch<HrPayrollBreakdownRow>(
                      controller: _breakdownSearchController,
                      semanticLabel: l10n.hrSearchLabel,
                      hintText: l10n.hrPayrollBreakdownSearchHint,
                      clearLabel: l10n.hrClearFiltersAction,
                      matcher: (HrPayrollBreakdownRow _, String query) => true,
                      onChanged: (String value) =>
                          setState(() => _breakdownQuery = value),
                      onSubmitted: (String value) =>
                          setState(() => _breakdownQuery = value),
                      onClear: () => setState(() => _breakdownQuery = ''),
                    ),
                    columns: _breakdownColumns(l10n, locale, currency),
                    emptyBuilder: (_) => Text(l10n.hrPayrollBreakdownEmptyBody),
                    mobileItemBuilder:
                        (BuildContext context, HrPayrollBreakdownRow row) {
                          return AppListTableMobileItem(
                            title: row.staffName.trim().isEmpty
                                ? l10n.profileUnknownValue
                                : row.staffName,
                            caption: _payTypeLabel(l10n, row.payType),
                            meta: <AppListTableMobileMeta>[
                              AppListTableMobileMeta(
                                label: hrPayrollAmountLabel(
                                  row.amount,
                                  locale,
                                  treatZeroAsEmpty: false,
                                ),
                              ),
                              AppListTableMobileMeta(label: row.paymentPath),
                            ],
                          );
                        },
                  ),
          ),
        ],
      ),
      actions: <Widget>[
        if (pending)
          AppAccessActionGate(
            requirement: HrPayrollDraftsAtomPermissions.process,
            hideWhenDenied: false,
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
        if (approved)
          AppAccessActionGate(
            requirement: HrPayrollDraftsAtomPermissions.process,
            hideWhenDenied: false,
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
        if (pending || approved)
          AppAccessActionGate(
            requirement: HrPayrollDraftsAtomPermissions.process,
            hideWhenDenied: false,
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
