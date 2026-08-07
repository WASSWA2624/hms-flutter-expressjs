import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';

enum ModuleReportingPeriodPreset {
  today,
  lastWeek,
  lastMonth,
  last3Months,
  last6Months,
  last12Months,
  last24Months,
  custom,
}

enum ModuleReportingExportFormat { excel, pdf }

({DateTime from, DateTime to}) moduleReportingRangeForPreset(
  ModuleReportingPeriodPreset preset, {
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
    case ModuleReportingPeriodPreset.today:
      return (from: today, to: end);
    case ModuleReportingPeriodPreset.lastWeek:
      return (
        from: startOfDay(today.subtract(const Duration(days: 6))),
        to: end,
      );
    case ModuleReportingPeriodPreset.lastMonth:
      return (
        from: startOfDay(today.subtract(const Duration(days: 29))),
        to: end,
      );
    case ModuleReportingPeriodPreset.last3Months:
      return (
        from: startOfDay(today.subtract(const Duration(days: 89))),
        to: end,
      );
    case ModuleReportingPeriodPreset.last6Months:
      return (
        from: startOfDay(today.subtract(const Duration(days: 179))),
        to: end,
      );
    case ModuleReportingPeriodPreset.last12Months:
      return (
        from: startOfDay(today.subtract(const Duration(days: 364))),
        to: end,
      );
    case ModuleReportingPeriodPreset.last24Months:
      return (
        from: startOfDay(today.subtract(const Duration(days: 729))),
        to: end,
      );
    case ModuleReportingPeriodPreset.custom:
      return (from: today, to: end);
  }
}

Future<void> openModuleReportingReportDialog({
  required BuildContext context,
  required ModuleReportingReport report,
  required ModuleReportingLabels labels,
  required bool canExport,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => ModuleReportingReportDialog(
      report: report,
      labels: labels,
      canExport: canExport,
    ),
  );
}

class ModuleReportingReportDialog extends ConsumerStatefulWidget {
  const ModuleReportingReportDialog({
    required this.report,
    required this.labels,
    required this.canExport,
    super.key,
  });

  final ModuleReportingReport report;
  final ModuleReportingLabels labels;
  final bool canExport;

  @override
  ConsumerState<ModuleReportingReportDialog> createState() =>
      _ModuleReportingReportDialogState();
}

class _ModuleReportingReportDialogState
    extends ConsumerState<ModuleReportingReportDialog> {
  ModuleReportingPeriodPreset _preset =
      ModuleReportingPeriodPreset.lastMonth;
  DateTime? _rangeFrom;
  DateTime? _rangeTo;
  String? _rangeError;
  bool _isPrinting = false;
  bool _isExporting = false;

  ModuleReportingLabels get _labels => widget.labels;

  @override
  void initState() {
    super.initState();
    final ({DateTime from, DateTime to}) range =
        moduleReportingRangeForPreset(_preset);
    _rangeFrom = range.from;
    _rangeTo = range.to;
  }

  bool get _busy => _isPrinting || _isExporting;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isChart =
        widget.report.contentKind == ModuleReportingContentKind.chart;

    return AppDialog(
      title: Text(widget.report.label),
      icon: Icon(
        isChart ? Icons.bar_chart_outlined : Icons.table_chart_outlined,
      ),
      scrollable: true,
      maxWidth: 760,
      closeEnabled: !_busy,
      content: AbsorbPointer(
        absorbing: _busy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ModuleReportingPeriodToolbar(
              labels: _labels,
              selected: _preset,
              rangeSummary: _rangeSummary(context),
              onSelected: _onPeriodSelected,
            ),
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
            AppWorkspaceStatePanel.empty(
              title: _labels.unavailableTitle,
              body: widget.report.hasBackend
                  ? _labels.unavailableMappedBody
                  : _labels.unavailableBody,
              icon: isChart
                  ? Icons.bar_chart_outlined
                  : Icons.table_chart_outlined,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.canExport) ...<Widget>[
          AppReportActionButton.print(
            label: _labels.printAction,
            enabled: !_busy,
            isLoading: _isPrinting,
            onPressed: _busy ? null : () => unawaited(_printReport()),
          ),
          AppReportActionButton.export(
            label: _labels.exportAction,
            enabled: !_busy,
            isLoading: _isExporting,
            onPressed: _busy ? null : () => unawaited(_exportReport()),
          ),
        ],
        AppButton.close(
          label: _labels.closeAction,
          enabled: !_busy,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _onPeriodSelected(ModuleReportingPeriodPreset preset) async {
    _rangeError = null;
    if (preset == ModuleReportingPeriodPreset.custom) {
      final DateTimeRange? range = await _openCustomRangeDialog(
        context: context,
        labels: _labels,
        initialFrom: _rangeFrom,
        initialTo: _rangeTo,
      );
      if (!mounted || range == null) {
        return;
      }
      setState(() {
        _preset = ModuleReportingPeriodPreset.custom;
        _rangeFrom = DateUtils.dateOnly(range.start);
        _rangeTo = DateUtils.dateOnly(range.end)
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
      });
      return;
    }

    final ({DateTime from, DateTime to}) range =
        moduleReportingRangeForPreset(preset);
    setState(() {
      _preset = preset;
      _rangeFrom = range.from;
      _rangeTo = range.to;
    });
  }

  String? _rangeSummary(BuildContext context) {
    final DateTime? from = _rangeFrom;
    final DateTime? to = _rangeTo;
    if (from == null || to == null) {
      return null;
    }
    final Locale locale = Localizations.localeOf(context);
    final String fromLabel = AppFormatters.mediumDate(from, locale);
    final String toLabel = AppFormatters.mediumDate(to, locale);
    final String presetLabel = moduleReportingPeriodLabel(_labels, _preset);
    return _labels.activeRangeSummary(presetLabel, fromLabel, toLabel);
  }

  bool _validateRange() {
    if (!appSearchBarDateRangeIsValid(_rangeFrom, _rangeTo)) {
      setState(() => _rangeError = _labels.invalidDateMessage);
      return false;
    }
    return true;
  }

  Future<void> _printReport() async {
    if (!_validateRange()) {
      return;
    }
    setState(() => _isPrinting = true);
    try {
      await PrintDocumentTemplates.registry(
        ref: ref,
        context: context,
        title: widget.report.label,
        subtitle: _labels.printSubtitle,
        recordReference: PrintFormContextReference(
          label: _labels.referenceLabel,
          value: widget.report.id,
        ),
        bodyHtml: moduleReportingPrintBodyHtml(
          labels: _labels,
          report: widget.report,
          periodLabel: moduleReportingPeriodLabel(_labels, _preset),
          from: _rangeFrom,
          to: _rangeTo,
          locale: Localizations.localeOf(context),
        ),
        footerNote: _labels.printFooter,
      );
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _exportReport() async {
    if (!_validateRange()) {
      return;
    }

    final ModuleReportingExportFormat? format =
        await _openExportOptionsDialog(
          context: context,
          labels: _labels,
          contentKind: widget.report.contentKind,
        );
    if (!mounted || format == null) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      switch (format) {
        case ModuleReportingExportFormat.pdf:
          await PrintDocumentTemplates.registry(
            ref: ref,
            context: context,
            title: widget.report.label,
            subtitle: _labels.exportPdfSubtitle,
            recordReference: PrintFormContextReference(
              label: _labels.referenceLabel,
              value: widget.report.id,
            ),
            bodyHtml: moduleReportingPrintBodyHtml(
              labels: _labels,
              report: widget.report,
              periodLabel: moduleReportingPeriodLabel(_labels, _preset),
              from: _rangeFrom,
              to: _rangeTo,
              locale: Localizations.localeOf(context),
            ),
            footerNote: _labels.printFooter,
          );
        case ModuleReportingExportFormat.excel:
          await _exportExcel();
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportExcel() async {
    final Locale locale = Localizations.localeOf(context);
    final List<ModuleReportingExportRow> rows =
        moduleReportingExportSummaryRows(
          labels: _labels,
          report: widget.report,
          periodLabel: moduleReportingPeriodLabel(_labels, _preset),
          from: _rangeFrom,
          to: _rangeTo,
          locale: locale,
        );
    final List<AppListTableColumn<ModuleReportingExportRow>> columns =
        <AppListTableColumn<ModuleReportingExportRow>>[
          AppListTableColumn<ModuleReportingExportRow>(
            id: 'field',
            label: _labels.exportFieldColumn,
            cellBuilder: (_, ModuleReportingExportRow row) => Text(row.field),
            exportValue: (ModuleReportingExportRow row) => row.field,
          ),
          AppListTableColumn<ModuleReportingExportRow>(
            id: 'value',
            label: _labels.exportValueColumn,
            cellBuilder: (_, ModuleReportingExportRow row) => Text(row.value),
            exportValue: (ModuleReportingExportRow row) => row.value,
          ),
        ];

    await showAppListTableExportDialog<ModuleReportingExportRow>(
      context: context,
      columns: columns,
      visibleColumnKeys: const <String>{'field', 'value'},
      rows: rows,
      config: AppListTableExportConfig<ModuleReportingExportRow>(
        fileNameStem: widget.report.id,
        sheetName: _labels.exportSheetName,
        enableDateFilter: false,
      ),
      title: _labels.exportDialogTitle,
      exportLabel: _labels.exportAction,
      cancelLabel: _labels.cancelAction,
      columnsSectionLabel: _labels.exportColumnsSectionLabel,
      filtersSectionLabel: _labels.exportFiltersSectionLabel,
      emptyColumnsMessage: _labels.exportEmptyColumnsMessage,
      emptyRowsMessage: _labels.exportEmptyRowsMessage,
      successMessage: _labels.exportSuccessMessage,
      failureMessage: _labels.exportFailureMessage,
    );
  }
}

String moduleReportingPeriodLabel(
  ModuleReportingLabels labels,
  ModuleReportingPeriodPreset preset,
) {
  return switch (preset) {
    ModuleReportingPeriodPreset.today => labels.periodToday,
    ModuleReportingPeriodPreset.lastWeek => labels.periodLastWeek,
    ModuleReportingPeriodPreset.lastMonth => labels.periodLastMonth,
    ModuleReportingPeriodPreset.last3Months => labels.periodLast3Months,
    ModuleReportingPeriodPreset.last6Months => labels.periodLast6Months,
    ModuleReportingPeriodPreset.last12Months => labels.periodLast12Months,
    ModuleReportingPeriodPreset.last24Months => labels.periodLast24Months,
    ModuleReportingPeriodPreset.custom => labels.periodCustom,
  };
}

String moduleReportingPrintBodyHtml({
  required ModuleReportingLabels labels,
  required ModuleReportingReport report,
  required String periodLabel,
  required DateTime? from,
  required DateTime? to,
  required Locale locale,
}) {
  final String fromLabel = from == null
      ? labels.unknownValue
      : AppFormatters.mediumDate(from, locale);
  final String toLabel = to == null
      ? labels.unknownValue
      : AppFormatters.mediumDate(to, locale);
  final String kindLabel =
      report.contentKind == ModuleReportingContentKind.chart
      ? labels.contentKindChart
      : labels.contentKindTable;
  final String availability = report.hasBackend
      ? labels.unavailableMappedBody
      : labels.unavailableBody;

  return PrintFormTemplate.section(
    title: labels.previewTitle,
    bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
      PrintFormMetadataItem(
        label: labels.nameColumnLabel,
        value: report.label,
      ),
      PrintFormMetadataItem(
        label: labels.referenceLabel,
        value: report.id,
      ),
      PrintFormMetadataItem(
        label: labels.contentKindFilterLabel,
        value: kindLabel,
      ),
      PrintFormMetadataItem(
        label: labels.periodLabel,
        value: periodLabel,
      ),
      PrintFormMetadataItem(
        label: labels.dateFromLabel,
        value: fromLabel,
      ),
      PrintFormMetadataItem(label: labels.dateToLabel, value: toLabel),
      PrintFormMetadataItem(
        label: labels.statusColumnLabel,
        value: labels.unavailableTitle,
      ),
      PrintFormMetadataItem(
        label: labels.exportNotesLabel,
        value: availability,
      ),
    ]),
  );
}

List<ModuleReportingExportRow> moduleReportingExportSummaryRows({
  required ModuleReportingLabels labels,
  required ModuleReportingReport report,
  required String periodLabel,
  required DateTime? from,
  required DateTime? to,
  required Locale locale,
}) {
  final String fromLabel = from == null
      ? labels.unknownValue
      : AppFormatters.mediumDate(from, locale);
  final String toLabel = to == null
      ? labels.unknownValue
      : AppFormatters.mediumDate(to, locale);
  final String kindLabel =
      report.contentKind == ModuleReportingContentKind.chart
      ? labels.contentKindChart
      : labels.contentKindTable;

  return <ModuleReportingExportRow>[
    ModuleReportingExportRow(
      field: labels.nameColumnLabel,
      value: report.label,
    ),
    ModuleReportingExportRow(
      field: labels.referenceLabel,
      value: report.id,
    ),
    ModuleReportingExportRow(
      field: labels.contentKindFilterLabel,
      value: kindLabel,
    ),
    ModuleReportingExportRow(
      field: labels.periodLabel,
      value: periodLabel,
    ),
    ModuleReportingExportRow(
      field: labels.dateFromLabel,
      value: fromLabel,
    ),
    ModuleReportingExportRow(
      field: labels.dateToLabel,
      value: toLabel,
    ),
    ModuleReportingExportRow(
      field: labels.statusColumnLabel,
      value: labels.unavailableTitle,
    ),
    ModuleReportingExportRow(
      field: labels.exportNotesLabel,
      value: report.hasBackend
          ? labels.unavailableMappedBody
          : labels.unavailableBody,
    ),
  ];
}

final class ModuleReportingExportRow {
  const ModuleReportingExportRow({required this.field, required this.value});

  final String field;
  final String value;
}

Future<DateTimeRange?> _openCustomRangeDialog({
  required BuildContext context,
  required ModuleReportingLabels labels,
  DateTime? initialFrom,
  DateTime? initialTo,
}) {
  return showAppDialog<DateTimeRange>(
    context: context,
    builder: (_) => _ModuleReportingCustomRangeDialog(
      labels: labels,
      initialFrom: initialFrom,
      initialTo: initialTo,
    ),
  );
}

Future<ModuleReportingExportFormat?> _openExportOptionsDialog({
  required BuildContext context,
  required ModuleReportingLabels labels,
  required ModuleReportingContentKind contentKind,
}) {
  return showAppDialog<ModuleReportingExportFormat>(
    context: context,
    builder: (_) => _ModuleReportingExportOptionsDialog(
      labels: labels,
      contentKind: contentKind,
    ),
  );
}

class _ModuleReportingPeriodToolbar extends StatelessWidget {
  const _ModuleReportingPeriodToolbar({
    required this.labels,
    required this.selected,
    required this.rangeSummary,
    required this.onSelected,
  });

  final ModuleReportingLabels labels;
  final ModuleReportingPeriodPreset selected;
  final String? rangeSummary;
  final ValueChanged<ModuleReportingPeriodPreset> onSelected;

  static const double _selectWidth = 220;
  static const double _stackBreakpoint = 520;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget select = SizedBox(
      width: _selectWidth,
      child: AppSelectField<ModuleReportingPeriodPreset>(
        value: selected,
        labelText: labels.periodLabel,
        isDense: true,
        allowClear: false,
        options: <AppSelectOption<ModuleReportingPeriodPreset>>[
          for (final ModuleReportingPeriodPreset preset
              in ModuleReportingPeriodPreset.values)
            AppSelectOption<ModuleReportingPeriodPreset>(
              value: preset,
              label: moduleReportingPeriodLabel(labels, preset),
              leadingIcon: Icon(_periodIcon(preset), size: 18),
            ),
        ],
        onChanged: (ModuleReportingPeriodPreset? value) {
          if (value == null) {
            return;
          }
          onSelected(value);
        },
      ),
    );

    final Widget summary = rangeSummary == null
        ? const SizedBox.shrink()
        : selected == ModuleReportingPeriodPreset.custom
        ? InkWell(
            onTap: () => onSelected(ModuleReportingPeriodPreset.custom),
            child: AppMutedText(rangeSummary!),
          )
        : AppMutedText(rangeSummary!);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final bool stacked = maxWidth < _stackBreakpoint;

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: select,
              ),
              if (rangeSummary != null) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                summary,
              ],
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: summary),
            SizedBox(width: theme.spacing.md),
            select,
          ],
        );
      },
    );
  }

  IconData _periodIcon(ModuleReportingPeriodPreset preset) {
    return switch (preset) {
      ModuleReportingPeriodPreset.today => Icons.today_outlined,
      ModuleReportingPeriodPreset.lastWeek => Icons.date_range_outlined,
      ModuleReportingPeriodPreset.lastMonth => Icons.calendar_month_outlined,
      ModuleReportingPeriodPreset.last3Months =>
        Icons.calendar_view_month_outlined,
      ModuleReportingPeriodPreset.last6Months =>
        Icons.calendar_view_week_outlined,
      ModuleReportingPeriodPreset.last12Months => Icons.event_outlined,
      ModuleReportingPeriodPreset.last24Months => Icons.event_note_outlined,
      ModuleReportingPeriodPreset.custom => Icons.edit_calendar_outlined,
    };
  }
}

class _ModuleReportingCustomRangeDialog extends StatefulWidget {
  const _ModuleReportingCustomRangeDialog({
    required this.labels,
    this.initialFrom,
    this.initialTo,
  });

  final ModuleReportingLabels labels;
  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<_ModuleReportingCustomRangeDialog> createState() =>
      _ModuleReportingCustomRangeDialogState();
}

class _ModuleReportingCustomRangeDialogState
    extends State<_ModuleReportingCustomRangeDialog> {
  late DateTime? _from;
  late DateTime? _to;
  String? _error;
  bool _isApplying = false;

  ModuleReportingLabels get _labels => widget.labels;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canInteract = !_isApplying;

    return AppDialog(
      title: Text(_labels.customRangeTitle),
      icon: const Icon(Icons.date_range_outlined),
      scrollable: true,
      maxWidth: 560,
      closeEnabled: canInteract,
      content: AbsorbPointer(
        absorbing: !canInteract,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppMutedText(_labels.customRangeBody),
            SizedBox(height: theme.spacing.md),
            AppResponsiveFieldRow(
              children: <Widget>[
                AppDateField(
                  value: _from,
                  labelText: _labels.dateFromLabel,
                  pickerButtonLabel: _labels.datePickerLabel,
                  invalidDateMessage: _labels.invalidDateMessage,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (DateTime? value) {
                    setState(() {
                      _from = value;
                      _error = null;
                    });
                  },
                ),
                AppDateField(
                  value: _to,
                  labelText: _labels.dateToLabel,
                  pickerButtonLabel: _labels.datePickerLabel,
                  invalidDateMessage: _labels.invalidDateMessage,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (DateTime? value) {
                    setState(() {
                      _to = value;
                      _error = null;
                    });
                  },
                ),
              ],
            ),
            if (_error != null) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: _labels.customRangeApplyAction,
          leadingIcon: Icons.check,
          enabled: canInteract,
          isLoading: _isApplying,
          onPressed: canInteract ? () => unawaited(_apply()) : null,
        ),
        AppButton.close(
          label: _labels.cancelAction,
          enabled: canInteract,
          onPressed: canInteract
              ? () => Navigator.of(context).pop()
              : null,
        ),
      ],
    );
  }

  Future<void> _apply() async {
    if (_from == null || _to == null) {
      setState(() => _error = _labels.customRangeRequired);
      return;
    }
    if (!appSearchBarDateRangeIsValid(_from, _to)) {
      setState(() => _error = _labels.invalidDateMessage);
      return;
    }
    setState(() => _isApplying = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(
      DateTimeRange(start: _from!, end: _to!),
    );
  }
}

class _ModuleReportingExportOptionsDialog extends StatefulWidget {
  const _ModuleReportingExportOptionsDialog({
    required this.labels,
    required this.contentKind,
  });

  final ModuleReportingLabels labels;
  final ModuleReportingContentKind contentKind;

  @override
  State<_ModuleReportingExportOptionsDialog> createState() =>
      _ModuleReportingExportOptionsDialogState();
}

class _ModuleReportingExportOptionsDialogState
    extends State<_ModuleReportingExportOptionsDialog> {
  late ModuleReportingExportFormat _format;

  ModuleReportingLabels get _labels => widget.labels;

  @override
  void initState() {
    super.initState();
    _format =
        widget.contentKind == ModuleReportingContentKind.chart
        ? ModuleReportingExportFormat.pdf
        : ModuleReportingExportFormat.excel;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(_labels.exportDialogTitle),
      icon: const Icon(Icons.share_outlined),
      scrollable: true,
      maxWidth: 520,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppMutedText(_labels.exportDialogBody),
          SizedBox(height: theme.spacing.md),
          AppRadioGroup<ModuleReportingExportFormat>(
            labelText: _labels.exportFormatLabel,
            presentation: AppRadioGroupPresentation.borderless,
            layout: AppRadioGroupLayout.wrap,
            dense: true,
            itemMinWidth: 160,
            value: _format,
            options: <AppRadioOption<ModuleReportingExportFormat>>[
              AppRadioOption<ModuleReportingExportFormat>(
                value: ModuleReportingExportFormat.excel,
                label: _labels.exportExcelAction,
                description: _labels.exportExcelOptionBody,
              ),
              AppRadioOption<ModuleReportingExportFormat>(
                value: ModuleReportingExportFormat.pdf,
                label: _labels.exportPdfAction,
                description: _labels.exportPdfOptionBody,
              ),
            ],
            onChanged: (ModuleReportingExportFormat? value) {
              if (value == null) {
                return;
              }
              setState(() => _format = value);
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: _labels.exportAction,
          leadingIcon: Icons.download_outlined,
          onPressed: () => Navigator.of(context).pop(_format),
        ),
        AppButton.close(
          label: _labels.cancelAction,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
