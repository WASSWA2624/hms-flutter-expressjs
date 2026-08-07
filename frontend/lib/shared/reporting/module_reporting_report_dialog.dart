import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_table.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_visualization_panel.dart';

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
  ModuleReportingDataProvider? dataProvider,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => ModuleReportingReportDialog(
      report: report,
      labels: labels,
      canExport: canExport,
      dataProvider: dataProvider,
    ),
  );
}

class ModuleReportingReportDialog extends ConsumerStatefulWidget {
  const ModuleReportingReportDialog({
    required this.report,
    required this.labels,
    required this.canExport,
    this.dataProvider,
    super.key,
  });

  final ModuleReportingReport report;
  final ModuleReportingLabels labels;
  final bool canExport;
  final ModuleReportingDataProvider? dataProvider;

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
  int _loadToken = 0;
  ModuleReportingReportSnapshot _snapshot =
      const ModuleReportingReportSnapshot.loading();

  ModuleReportingLabels get _labels => widget.labels;

  @override
  void initState() {
    super.initState();
    final ({DateTime from, DateTime to}) range =
        moduleReportingRangeForPreset(_preset);
    _rangeFrom = range.from;
    _rangeTo = range.to;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadSnapshot());
    });
  }

  bool get _busy => _isPrinting || _isExporting;

  Future<void> _loadSnapshot() async {
    final ModuleReportingDataProvider? provider = widget.dataProvider;
    final DateTime? from = _rangeFrom;
    final DateTime? to = _rangeTo;
    final int token = ++_loadToken;

    if (provider == null) {
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _snapshot = ModuleReportingReportSnapshot.unavailable(
          title: widget.report.label,
        );
      });
      return;
    }

    setState(() {
      _snapshot = ModuleReportingReportSnapshot.loading(
        title: widget.report.label,
      );
    });

    if (from == null || to == null) {
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _snapshot = ModuleReportingReportSnapshot.error(
          failureMessage: _labels.invalidDateMessage,
          title: widget.report.label,
        );
      });
      return;
    }

    final ModuleReportingReportSnapshot next = await provider.load(
      report: widget.report,
      from: from,
      to: to,
      preset: _preset,
    );
    if (!mounted || token != _loadToken) {
      return;
    }
    setState(() => _snapshot = next);
  }

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
      maxWidth: 960,
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
              SizedBox(height: theme.spacing.xs),
              Text(
                _rangeError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.sm),
            _buildBody(context, isChart: isChart),
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

  Widget _buildBody(BuildContext context, {required bool isChart}) {
    final ThemeData theme = Theme.of(context);
    switch (_snapshot.state) {
      case ModuleReportingLoadState.loading:
        return AppWorkspaceStatePanel.loading(
          title: _labels.loadingTitle,
          body: _labels.loadingBody,
          minHeight: 220,
        );
      case ModuleReportingLoadState.error:
        return AppWorkspaceStatePanel.error(
          title: _labels.errorTitle,
          body: _snapshot.failureMessage?.trim().isNotEmpty == true
              ? _snapshot.failureMessage!
              : _labels.errorBody,
          icon: Icons.error_outline,
          minHeight: 220,
          action: AppButton.secondary(
            label: _labels.retryAction,
            leadingIcon: Icons.refresh,
            onPressed: () => unawaited(_loadSnapshot()),
          ),
        );
      case ModuleReportingLoadState.unavailable:
        return AppWorkspaceStatePanel.empty(
          title: _labels.unavailableTitle,
          body: widget.report.hasBackend
              ? _labels.unavailableMappedBody
              : _labels.unavailableBody,
          icon: isChart
              ? Icons.bar_chart_outlined
              : Icons.table_chart_outlined,
          minHeight: 220,
        );
      case ModuleReportingLoadState.empty:
        return AppWorkspaceStatePanel.empty(
          title: _labels.emptyTitle,
          body: _labels.emptyBody,
          icon: isChart
              ? Icons.bar_chart_outlined
              : Icons.table_chart_outlined,
          minHeight: 220,
        );
      case ModuleReportingLoadState.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if ((_snapshot.subtitle ?? '').trim().isNotEmpty)
              Text(
                _snapshot.subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            SizedBox(height: theme.spacing.sm),
            ModuleReportingVisualizationPanel(
              snapshot: _snapshot,
              report: widget.report,
              labels: _labels,
            ),
          ],
        );
    }
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
      unawaited(_loadSnapshot());
      return;
    }

    final ({DateTime from, DateTime to}) range =
        moduleReportingRangeForPreset(preset);
    setState(() {
      _preset = preset;
      _rangeFrom = range.from;
      _rangeTo = range.to;
    });
    unawaited(_loadSnapshot());
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
          snapshot: _snapshot,
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
              snapshot: _snapshot,
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
    if (_snapshot.hasRows && _snapshot.columns.isNotEmpty) {
      final List<String> columns = _snapshot.columns;
      final List<Map<String, Object?>> rows = _snapshot.exportRows;
      final List<AppListTableColumn<Map<String, Object?>>> tableColumns =
          moduleReportingTableColumns(
            columnKeys: columns,
            locale: locale,
            unknownLabel: _labels.unknownValue,
          );
      await showAppListTableExportDialog<Map<String, Object?>>(
        context: context,
        columns: tableColumns,
        visibleColumnKeys: columns.toSet(),
        rows: rows,
        config: AppListTableExportConfig<Map<String, Object?>>(
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
      return;
    }

    final List<ModuleReportingExportRow> summaryRows =
        moduleReportingExportSummaryRows(
          labels: _labels,
          report: widget.report,
          periodLabel: moduleReportingPeriodLabel(_labels, _preset),
          from: _rangeFrom,
          to: _rangeTo,
          locale: locale,
          snapshot: _snapshot,
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
      rows: summaryRows,
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

String _snapshotStatusLabel(
  ModuleReportingLabels labels,
  ModuleReportingReportSnapshot? snapshot,
  ModuleReportingReport report,
) {
  if (snapshot == null) {
    return labels.unavailableTitle;
  }
  return switch (snapshot.state) {
    ModuleReportingLoadState.loading => labels.loadingTitle,
    ModuleReportingLoadState.ready => labels.previewTitle,
    ModuleReportingLoadState.empty => labels.emptyTitle,
    ModuleReportingLoadState.error => labels.errorTitle,
    ModuleReportingLoadState.unavailable => labels.unavailableTitle,
  };
}

String _snapshotNotesLabel(
  ModuleReportingLabels labels,
  ModuleReportingReportSnapshot? snapshot,
  ModuleReportingReport report,
) {
  if (snapshot == null) {
    return report.hasBackend
        ? labels.unavailableMappedBody
        : labels.unavailableBody;
  }
  return switch (snapshot.state) {
    ModuleReportingLoadState.loading => labels.loadingBody,
    ModuleReportingLoadState.ready =>
      snapshot.subtitle?.trim().isNotEmpty == true
          ? snapshot.subtitle!
          : labels.previewTitle,
    ModuleReportingLoadState.empty => labels.emptyBody,
    ModuleReportingLoadState.error =>
      snapshot.failureMessage?.trim().isNotEmpty == true
          ? snapshot.failureMessage!
          : labels.errorBody,
    ModuleReportingLoadState.unavailable => report.hasBackend
        ? labels.unavailableMappedBody
        : labels.unavailableBody,
  };
}

String moduleReportingPrintBodyHtml({
  required ModuleReportingLabels labels,
  required ModuleReportingReport report,
  required String periodLabel,
  required DateTime? from,
  required DateTime? to,
  required Locale locale,
  ModuleReportingReportSnapshot? snapshot,
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

  final String metadata = PrintFormTemplate.section(
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
        value: _snapshotStatusLabel(labels, snapshot, report),
      ),
      PrintFormMetadataItem(
        label: labels.exportNotesLabel,
        value: _snapshotNotesLabel(labels, snapshot, report),
      ),
    ]),
  );

  if (snapshot == null || !snapshot.hasRows || snapshot.columns.isEmpty) {
    return metadata;
  }

  final String tableHtml = PrintFormTemplate.section(
    title: snapshot.title?.trim().isNotEmpty == true
        ? snapshot.title!
        : report.label,
    bodyHtml: PrintFormTemplate.table(
      headers: snapshot.columns,
      rows: <List<String>>[
        for (final Map<String, Object?> row in snapshot.rows)
          <String>[
            for (final String column in snapshot.columns)
              '${row[column] ?? ''}',
          ],
      ],
      emptyText: labels.emptyBody,
    ),
  );
  return '$metadata$tableHtml';
}

List<ModuleReportingExportRow> moduleReportingExportSummaryRows({
  required ModuleReportingLabels labels,
  required ModuleReportingReport report,
  required String periodLabel,
  required DateTime? from,
  required DateTime? to,
  required Locale locale,
  ModuleReportingReportSnapshot? snapshot,
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
      value: _snapshotStatusLabel(labels, snapshot, report),
    ),
    ModuleReportingExportRow(
      field: labels.exportNotesLabel,
      value: _snapshotNotesLabel(labels, snapshot, report),
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

  static const double _selectWidth = 168;
  static const double _stackBreakpoint = 480;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? summaryStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.2,
    );
    final Widget select = SizedBox(
      width: _selectWidth,
      child: AppSelectField<ModuleReportingPeriodPreset>(
        value: selected,
        semanticLabel: labels.periodLabel,
        isDense: true,
        allowClear: false,
        enableSpeechToText: false,
        options: <AppSelectOption<ModuleReportingPeriodPreset>>[
          for (final ModuleReportingPeriodPreset preset
              in ModuleReportingPeriodPreset.values)
            AppSelectOption<ModuleReportingPeriodPreset>(
              value: preset,
              label: moduleReportingPeriodLabel(labels, preset),
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

    final Widget summaryText = rangeSummary == null
        ? const SizedBox.shrink()
        : Text(
            rangeSummary!,
            style: summaryStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
    final Widget summary = rangeSummary == null
        ? const SizedBox.shrink()
        : selected == ModuleReportingPeriodPreset.custom
        ? InkWell(
            onTap: () => onSelected(ModuleReportingPeriodPreset.custom),
            child: summaryText,
          )
        : summaryText;

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
                SizedBox(height: theme.spacing.xs),
                summary,
              ],
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: summary),
            SizedBox(width: theme.spacing.sm),
            select,
          ],
        );
      },
    );
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
