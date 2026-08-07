import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_print_layout.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_table.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_visualization.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_visualization_panel.dart';

/// Opens the interactive module-reporting print composer, then the shared
/// HTML print-preview dialog when the user confirms print.
Future<void> openModuleReportingPrintPreviewDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ModuleReportingReport report,
  required ModuleReportingReportSnapshot snapshot,
  required ModuleReportingLabels labels,
  required String periodLabel,
  required DateTime? from,
  required DateTime? to,
}) {
  return showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ModuleReportingPrintPreviewDialog(
      report: report,
      snapshot: snapshot,
      labels: labels,
      periodLabel: periodLabel,
      from: from,
      to: to,
      ref: ref,
    ),
  );
}

class ModuleReportingPrintPreviewDialog extends StatefulWidget {
  const ModuleReportingPrintPreviewDialog({
    required this.report,
    required this.snapshot,
    required this.labels,
    required this.periodLabel,
    required this.from,
    required this.to,
    required this.ref,
    super.key,
  });

  final ModuleReportingReport report;
  final ModuleReportingReportSnapshot snapshot;
  final ModuleReportingLabels labels;
  final String periodLabel;
  final DateTime? from;
  final DateTime? to;
  final WidgetRef ref;

  @override
  State<ModuleReportingPrintPreviewDialog> createState() =>
      _ModuleReportingPrintPreviewDialogState();
}

class _ModuleReportingPrintPreviewDialogState
    extends State<ModuleReportingPrintPreviewDialog> {
  late List<ModuleReportingPrintBlock> _blocks;
  String? _selectedBlockId;
  bool _isPrinting = false;
  AppPrintPreviewPaneMode _paneMode = AppPrintPreviewPaneMode.split;
  double _scale = 1;

  ModuleReportingLabels get _labels => widget.labels;

  @override
  void initState() {
    super.initState();
    _blocks = moduleReportingDefaultPrintBlocks(
      report: widget.report,
      snapshot: widget.snapshot,
    );
    if (_blocks.isNotEmpty) {
      _selectedBlockId = _blocks.first.id;
    }
  }

  ModuleReportingPrintBlock? get _selectedBlock {
    final String? id = _selectedBlockId;
    if (id == null) {
      return null;
    }
    for (final ModuleReportingPrintBlock block in _blocks) {
      if (block.id == id) {
        return block;
      }
    }
    return null;
  }

  void _updateBlock(String id, ModuleReportingPrintBlock Function(ModuleReportingPrintBlock) transform) {
    setState(() {
      _blocks = <ModuleReportingPrintBlock>[
        for (final ModuleReportingPrintBlock block in _blocks)
          if (block.id == id) transform(block) else block,
      ];
    });
  }

  Future<void> _confirmPrint() async {
    if (_isPrinting) {
      return;
    }
    setState(() => _isPrinting = true);
    try {
      final Locale locale = Localizations.localeOf(context);
      final String bodyHtml = moduleReportingPrintLayoutBodyHtml(
        labels: _labels,
        report: widget.report,
        snapshot: widget.snapshot,
        blocks: _blocks,
        periodLabel: widget.periodLabel,
        from: widget.from,
        to: widget.to,
        locale: locale,
      );
      if (!mounted) {
        return;
      }
      await PrintDocumentTemplates.registry(
        ref: widget.ref,
        context: context,
        title: widget.report.label,
        subtitle: _labels.printSubtitle,
        recordReference: PrintFormContextReference(
          label: _labels.referenceLabel,
          value: widget.report.id,
        ),
        bodyHtml: bodyHtml,
        footerNote: _labels.printFooter,
        previewDialogTitle: context.l10n.printPreviewTitle,
      );
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<ReportSectionAvailability> availabilities =
        <ReportSectionAvailability>[
          for (final ModuleReportingPrintBlock block in _blocks)
            ReportSectionAvailability(
              id: block.id,
              count: 1,
              alwaysAvailable: true,
            ),
        ];
    final Set<Object> selectedIds = <Object>{
      for (final ModuleReportingPrintBlock block in _blocks)
        if (block.visible) block.id,
    };
    final List<AppReportSectionData> tiles = buildReportSectionTiles(
      sections: availabilities,
      titleFor: (Object id) {
        final ModuleReportingPrintBlock block = _blocks.firstWhere(
          (ModuleReportingPrintBlock item) => item.id == id,
        );
        return block.title;
      },
      iconFor: (Object id) {
        final ModuleReportingPrintBlock block = _blocks.firstWhere(
          (ModuleReportingPrintBlock item) => item.id == id,
        );
        return moduleReportingVisualizationIcon(block.kind);
      },
    );

    final ModuleReportingPrintBlock? selected = _selectedBlock;

    final Widget sectionPicker = Padding(
      padding: EdgeInsets.all(theme.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFormSection(
            title: l10n.printPreviewSectionsOnlyAction,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppReportSectionPicker(
                sections: tiles,
                selectedIds: selectedIds,
                onSelectionChanged: (Set<Object> next) {
                  setState(() {
                    _blocks = <ModuleReportingPrintBlock>[
                      for (final ModuleReportingPrintBlock block in _blocks)
                        block.copyWith(visible: next.contains(block.id)),
                    ];
                  });
                },
              ),
            ],
          ),
          if (selected != null) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppFormSection(
              title: selected.title,
              density: AppFormSectionDensity.compact,
              children: <Widget>[
                AppTextField(
                  labelText: l10n.reportsNameColumnLabel,
                  initialValue: selected.title,
                  onChanged: (String value) {
                    _updateBlock(
                      selected.id,
                      (ModuleReportingPrintBlock block) =>
                          block.copyWith(title: value),
                    );
                  },
                ),
                SizedBox(height: theme.spacing.sm),
                AppTextField(
                  labelText: _labels.exportNotesLabel,
                  initialValue: selected.caption,
                  maxLines: 2,
                  onChanged: (String value) {
                    _updateBlock(
                      selected.id,
                      (ModuleReportingPrintBlock block) =>
                          block.copyWith(caption: value),
                    );
                  },
                ),
                if (selected.kind == ModuleReportingVisualizationKind.table)
                  ..._tableInspector(selected, theme, l10n),
                if (selected.kind !=
                    ModuleReportingVisualizationKind.table) ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  AppTextField(
                    labelText: 'Max data points',
                    initialValue: '${selected.maxRows}',
                    keyboardType: TextInputType.number,
                    onChanged: (String value) {
                      final int? parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed < 1) {
                        return;
                      }
                      _updateBlock(
                        selected.id,
                        (ModuleReportingPrintBlock block) => block.copyWith(
                          maxRows: parsed.clamp(1, 500),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    final Widget canvas = _PrintCanvas(
      blocks: _blocks,
      snapshot: widget.snapshot,
      labels: _labels,
      selectedBlockId: _selectedBlockId,
      scale: _scale,
      onSelect: (String id) => setState(() => _selectedBlockId = id),
      onMove: (String id, Offset delta) {
        _updateBlock(id, (ModuleReportingPrintBlock block) {
          final double nextLeft = (block.left + delta.dx)
              .clamp(0, moduleReportingPrintPageSize.width - block.width);
          final double nextTop = (block.top + delta.dy)
              .clamp(0, moduleReportingPrintPageSize.height - block.height);
          return block.copyWith(left: nextLeft, top: nextTop);
        });
      },
      onResize: (String id, Offset delta) {
        _updateBlock(id, (ModuleReportingPrintBlock block) {
          final double nextWidth = (block.width + delta.dx).clamp(160, 680);
          final double nextHeight = (block.height + delta.dy).clamp(120, 640);
          return block.copyWith(width: nextWidth, height: nextHeight);
        });
      },
    );

    return AppDialog(
      title: Text(l10n.printPreviewTitle),
      icon: const Icon(Icons.print_outlined),
      pinActionsToBottom: true,
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      maxWidth: 1180,
      closeEnabled: !_isPrinting,
      content: AppPrintPreviewWorkspace(
        paneMode: _paneMode,
        paneModeEnabled: !_isPrinting,
        onPaneModeChanged: (AppPrintPreviewPaneMode next) {
          setState(() => _paneMode = next);
        },
        toolbar: AppPrintPreviewToolbar(
          scale: _scale,
          enabled: !_isPrinting,
          currentPage: 1,
          pageCount: 1,
          onZoomIn: () {
            setState(() => _scale = AppPrintPreviewZoom.zoomIn(_scale));
          },
          onZoomOut: () {
            setState(() => _scale = AppPrintPreviewZoom.zoomOut(_scale));
          },
          onZoomIncrease: () {
            setState(() => _scale = AppPrintPreviewZoom.increase(_scale));
          },
          onZoomDecrease: () {
            setState(() => _scale = AppPrintPreviewZoom.decrease(_scale));
          },
          onFitPage: () {
            setState(() => _scale = 1);
          },
          onPagePrevious: null,
          onPageNext: null,
        ),
        sectionPicker: sectionPicker,
        preview: canvas,
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: _labels.closeAction,
          enabled: !_isPrinting,
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: _labels.printAction,
          leadingIcon: Icons.print_outlined,
          enabled: !_isPrinting && selectedIds.isNotEmpty,
          isLoading: _isPrinting,
          onPressed: _isPrinting || selectedIds.isEmpty
              ? null
              : () => unawaited(_confirmPrint()),
        ),
      ],
    );
  }

  List<Widget> _tableInspector(
    ModuleReportingPrintBlock selected,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final List<String> allColumns = widget.snapshot.columns;
    return <Widget>[
      SizedBox(height: theme.spacing.sm),
      Text(
        l10n.commonTableExportColumnsSectionLabel,
        style: theme.textTheme.labelLarge,
      ),
      SizedBox(height: theme.spacing.xs),
      Wrap(
        spacing: theme.spacing.xs,
        runSpacing: theme.spacing.xs,
        children: <Widget>[
          for (final String column in allColumns)
            FilterChip(
              label: Text(moduleReportingColumnLabel(column)),
              selected: selected.visibleColumns.contains(column),
              onSelected: (bool selectedNow) {
                final List<String> next =
                    List<String>.from(selected.visibleColumns);
                if (selectedNow) {
                  if (!next.contains(column)) {
                    next.add(column);
                  }
                } else {
                  next.remove(column);
                }
                if (next.isEmpty) {
                  return;
                }
                _updateBlock(
                  selected.id,
                  (ModuleReportingPrintBlock block) =>
                      block.copyWith(visibleColumns: next),
                );
              },
            ),
        ],
      ),
      SizedBox(height: theme.spacing.sm),
      AppTextField(
        labelText: 'Max rows',
        initialValue: '${selected.maxRows}',
        keyboardType: TextInputType.number,
        onChanged: (String value) {
          final int? parsed = int.tryParse(value.trim());
          if (parsed == null || parsed < 1) {
            return;
          }
          _updateBlock(
            selected.id,
            (ModuleReportingPrintBlock block) =>
                block.copyWith(maxRows: parsed.clamp(1, 500)),
          );
        },
      ),
      SizedBox(height: theme.spacing.sm),
      AppSelectField<String>(
        labelText: 'Sort column',
        value: selected.sortColumnKey,
        allowClear: true,
        options: <AppSelectOption<String>>[
          for (final String column in allColumns)
            AppSelectOption<String>(
              value: column,
              label: moduleReportingColumnLabel(column),
            ),
        ],
        onChanged: (String? value) {
          _updateBlock(
            selected.id,
            (ModuleReportingPrintBlock block) => block.copyWith(
              sortColumnKey: value,
              clearSortColumnKey: value == null,
            ),
          );
        },
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Sort ascending'),
        value: selected.sortAscending,
        onChanged: (bool value) {
          _updateBlock(
            selected.id,
            (ModuleReportingPrintBlock block) =>
                block.copyWith(sortAscending: value),
          );
        },
      ),
    ];
  }
}

class _PrintCanvas extends StatelessWidget {
  const _PrintCanvas({
    required this.blocks,
    required this.snapshot,
    required this.labels,
    required this.selectedBlockId,
    required this.scale,
    required this.onSelect,
    required this.onMove,
    required this.onResize,
  });

  final List<ModuleReportingPrintBlock> blocks;
  final ModuleReportingReportSnapshot snapshot;
  final ModuleReportingLabels labels;
  final String? selectedBlockId;
  final double scale;
  final ValueChanged<String> onSelect;
  final void Function(String id, Offset delta) onMove;
  final void Function(String id, Offset delta) onResize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 2.5,
        child: Center(
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: Container(
              width: moduleReportingPrintPageSize.width,
              height: moduleReportingPrintPageSize.height,
              margin: EdgeInsets.all(theme.spacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                border: theme.borders.all(),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  for (final ModuleReportingPrintBlock block in blocks)
                    if (block.visible)
                      Positioned(
                        left: block.left,
                        top: block.top,
                        width: block.width,
                        height: block.height,
                        child: _DraggablePrintBlock(
                          block: block,
                          selected: block.id == selectedBlockId,
                          snapshot: snapshot,
                          labels: labels,
                          onSelect: () => onSelect(block.id),
                          onMove: (Offset delta) => onMove(block.id, delta),
                          onResize: (Offset delta) => onResize(block.id, delta),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DraggablePrintBlock extends StatelessWidget {
  const _DraggablePrintBlock({
    required this.block,
    required this.selected,
    required this.snapshot,
    required this.labels,
    required this.onSelect,
    required this.onMove,
    required this.onResize,
  });

  final ModuleReportingPrintBlock block;
  final bool selected;
  final ModuleReportingReportSnapshot snapshot;
  final ModuleReportingLabels labels;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return GestureDetector(
      onTap: onSelect,
      onPanUpdate: (DragUpdateDetails details) => onMove(details.delta),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(
            color: selected ? colors.primary : theme.borders.faint,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(theme.radius.sm),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          moduleReportingVisualizationIcon(block.kind),
                          size: 16,
                          color: colors.primary,
                        ),
                        SizedBox(width: theme.spacing.xs),
                        Expanded(
                          child: Text(
                            block.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: AppFontWeight.emphasis,
                            ),
                          ),
                        ),
                        const Icon(Icons.drag_indicator, size: 16),
                      ],
                    ),
                    if (block.caption.trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: theme.spacing.xs),
                      Text(
                        block.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    SizedBox(height: theme.spacing.xs),
                    Expanded(
                      child: _BlockPreviewBody(
                        block: block,
                        snapshot: snapshot,
                        labels: labels,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanUpdate: (DragUpdateDetails details) =>
                    onResize(details.delta),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      Icons.north_west,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockPreviewBody extends StatelessWidget {
  const _BlockPreviewBody({
    required this.block,
    required this.snapshot,
    required this.labels,
  });

  final ModuleReportingPrintBlock block;
  final ModuleReportingReportSnapshot snapshot;
  final ModuleReportingLabels labels;

  @override
  Widget build(BuildContext context) {
    final ModuleReportingReportSnapshot scopedSnapshot =
        block.kind == ModuleReportingVisualizationKind.table
        ? ModuleReportingReportSnapshot.ready(
            columns: block.visibleColumns.isEmpty
                ? snapshot.columns
                : block.visibleColumns,
            rows: moduleReportingPrintTableRows(
              snapshot: snapshot,
              block: block,
            ),
            summary: snapshot.summary,
            breakdown: snapshot.breakdown,
            title: block.title,
            subtitle: block.caption,
          )
        : snapshot;

    final Widget view = ModuleReportingVisualizationView(
      kind: block.kind,
      snapshot: scopedSnapshot,
      labels: labels,
      title: block.title,
      canExport: false,
      embedded: true,
      storageKeyPrefix: 'print-${block.id}',
      dataLimit: block.maxRows,
    );

    // Nested chart chrome (options + legend + painters) can exceed the block
    // height; keep the same visuals and scroll within the tile.
    return ClipRect(
      child: SingleChildScrollView(
        primary: false,
        child: view,
      ),
    );
  }
}
