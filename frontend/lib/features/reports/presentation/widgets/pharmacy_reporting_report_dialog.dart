import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_catalog.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

enum PharmacyReportingPeriodPreset {
  today,
  lastWeek,
  lastMonth,
  last3Months,
  last6Months,
  last12Months,
  last24Months,
  custom,
}

({DateTime from, DateTime to}) pharmacyReportingRangeForPreset(
  PharmacyReportingPeriodPreset preset, {
  DateTime? now,
}) {
  final DateTime current = now ?? DateTime.now();
  final DateTime today = DateTime(current.year, current.month, current.day);
  final DateTime end = today
      .add(const Duration(days: 1))
      .subtract(const Duration(milliseconds: 1));

  DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  switch (preset) {
    case PharmacyReportingPeriodPreset.today:
      return (from: today, to: end);
    case PharmacyReportingPeriodPreset.lastWeek:
      return (
        from: startOfDay(today.subtract(const Duration(days: 6))),
        to: end,
      );
    case PharmacyReportingPeriodPreset.lastMonth:
      return (
        from: startOfDay(today.subtract(const Duration(days: 29))),
        to: end,
      );
    case PharmacyReportingPeriodPreset.last3Months:
      return (
        from: startOfDay(today.subtract(const Duration(days: 89))),
        to: end,
      );
    case PharmacyReportingPeriodPreset.last6Months:
      return (
        from: startOfDay(today.subtract(const Duration(days: 179))),
        to: end,
      );
    case PharmacyReportingPeriodPreset.last12Months:
      return (
        from: startOfDay(today.subtract(const Duration(days: 364))),
        to: end,
      );
    case PharmacyReportingPeriodPreset.last24Months:
      return (
        from: startOfDay(today.subtract(const Duration(days: 729))),
        to: end,
      );
    case PharmacyReportingPeriodPreset.custom:
      return (from: today, to: end);
  }
}

Future<void> openPharmacyReportingReportDialog({
  required BuildContext context,
  required PharmacyReportingReport report,
  required AppAccessPolicy policy,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => PharmacyReportingReportDialog(
      report: report,
      policy: policy,
    ),
  );
}

class PharmacyReportingReportDialog extends StatefulWidget {
  const PharmacyReportingReportDialog({
    required this.report,
    required this.policy,
    super.key,
  });

  final PharmacyReportingReport report;
  final AppAccessPolicy policy;

  @override
  State<PharmacyReportingReportDialog> createState() =>
      _PharmacyReportingReportDialogState();
}

class _PharmacyReportingReportDialogState
    extends State<PharmacyReportingReportDialog> {
  PharmacyReportingPeriodPreset _preset =
      PharmacyReportingPeriodPreset.lastMonth;
  DateTime? _customFrom;
  DateTime? _customTo;
  String? _rangeError;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    final ({DateTime from, DateTime to}) range =
        pharmacyReportingRangeForPreset(_preset);
    _customFrom = range.from;
    _customTo = range.to;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool canExport = canExportEvidence(widget.policy);
    final bool isChart =
        widget.report.contentKind == PharmacyReportingContentKind.chart;

    return AppDialog(
      title: Text(widget.report.label),
      icon: Icon(
        isChart ? Icons.bar_chart_outlined : Icons.table_chart_outlined,
      ),
      scrollable: true,
      maxWidth: 760,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.reportsPharmacyReportingPeriodLabel,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: <Widget>[
              for (final PharmacyReportingPeriodPreset preset
                  in PharmacyReportingPeriodPreset.values)
                ChoiceChip(
                  label: Text(_periodLabel(l10n, preset)),
                  selected: _preset == preset,
                  onSelected: (bool selected) {
                    if (!selected) {
                      return;
                    }
                    setState(() {
                      _preset = preset;
                      _rangeError = null;
                      if (preset != PharmacyReportingPeriodPreset.custom) {
                        final ({DateTime from, DateTime to}) range =
                            pharmacyReportingRangeForPreset(preset);
                        _customFrom = range.from;
                        _customTo = range.to;
                      }
                    });
                    unawaited(_softRefresh());
                  },
                ),
            ],
          ),
          if (_preset == PharmacyReportingPeriodPreset.custom) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppResponsiveFieldRow(
              children: <Widget>[
                AppDateField(
                  value: _customFrom,
                  labelText: l10n.reportsDateFromLabel,
                  pickerButtonLabel: l10n.reportsDatePickerLabel,
                  invalidDateMessage: l10n.reportsInvalidDateMessage,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (DateTime? value) {
                    setState(() {
                      _customFrom = value;
                      _rangeError = null;
                    });
                  },
                ),
                AppDateField(
                  value: _customTo,
                  labelText: l10n.reportsDateToLabel,
                  pickerButtonLabel: l10n.reportsDatePickerLabel,
                  invalidDateMessage: l10n.reportsInvalidDateMessage,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (DateTime? value) {
                    setState(() {
                      _customTo = value;
                      _rangeError = null;
                    });
                  },
                ),
              ],
            ),
          ],
          if (_rangeError != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              _rangeError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          SizedBox(height: theme.spacing.lg),
          if (_isRefreshing)
            AppLoadingIndicator(
              title: l10n.reportsPharmacyReportingLoadingTitle,
              body: l10n.reportsPharmacyReportingLoadingBody,
            )
          else
            AppWorkspaceStatePanel.empty(
              title: l10n.reportsPharmacyReportingUnavailableTitle,
              body: widget.report.hasBackend
                  ? l10n.reportsPharmacyReportingUnavailableMappedBody
                  : l10n.reportsPharmacyReportingUnavailableBody,
              icon: Icons.insights_outlined,
            ),
        ],
      ),
      actions: <Widget>[
        if (canExport)
          AppButton.secondary(
            label: isChart
                ? l10n.reportsPharmacyReportingExportPdfAction
                : l10n.reportsPharmacyReportingExportExcelAction,
            leadingIcon: isChart
                ? Icons.picture_as_pdf_outlined
                : Icons.grid_on_outlined,
            onPressed: () {
              if (!_validateRange(l10n)) {
                return;
              }
              showAppSuccessSnackBar(
                context,
                l10n.reportsPharmacyReportingExportUnavailableSnack,
              );
            },
          ),
        AppButton.close(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  String _periodLabel(
    AppLocalizations l10n,
    PharmacyReportingPeriodPreset preset,
  ) {
    return switch (preset) {
      PharmacyReportingPeriodPreset.today =>
        l10n.reportsPharmacyReportingPeriodToday,
      PharmacyReportingPeriodPreset.lastWeek =>
        l10n.reportsPharmacyReportingPeriodLastWeek,
      PharmacyReportingPeriodPreset.lastMonth =>
        l10n.reportsPharmacyReportingPeriodLastMonth,
      PharmacyReportingPeriodPreset.last3Months =>
        l10n.reportsPharmacyReportingPeriodLast3Months,
      PharmacyReportingPeriodPreset.last6Months =>
        l10n.reportsPharmacyReportingPeriodLast6Months,
      PharmacyReportingPeriodPreset.last12Months =>
        l10n.reportsPharmacyReportingPeriodLast12Months,
      PharmacyReportingPeriodPreset.last24Months =>
        l10n.reportsPharmacyReportingPeriodLast24Months,
      PharmacyReportingPeriodPreset.custom =>
        l10n.reportsPharmacyReportingPeriodCustom,
    };
  }

  bool _validateRange(AppLocalizations l10n) {
    if (_preset != PharmacyReportingPeriodPreset.custom) {
      return true;
    }
    if (!appSearchBarDateRangeIsValid(_customFrom, _customTo)) {
      setState(() => _rangeError = l10n.reportsInvalidDateMessage);
      return false;
    }
    return true;
  }

  Future<void> _softRefresh() async {
    if (!_validateRange(context.l10n)) {
      return;
    }
    setState(() => _isRefreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }
    setState(() => _isRefreshing = false);
  }
}
