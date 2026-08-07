import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_print_layout.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_visualization.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_visualization_panel.dart';

/// Renders selected non-table print blocks off-screen and returns PNG data URLs.
///
/// Captures use a fixed printable width and intrinsic height so charts are not
/// clipped horizontally or padded with empty vertical space.
Future<Map<String, String>> captureModuleReportingChartImages({
  required BuildContext context,
  required ModuleReportingReportSnapshot snapshot,
  required ModuleReportingLabels labels,
  required List<ModuleReportingPrintBlock> blocks,
  double pixelRatio = 2,
  double captureWidth = moduleReportingPrintCaptureWidth,
}) async {
  final List<ModuleReportingPrintBlock> chartBlocks = blocks
      .where(
        (ModuleReportingPrintBlock block) =>
            block.visible &&
            block.kind != ModuleReportingVisualizationKind.table,
      )
      .toList(growable: false);
  if (chartBlocks.isEmpty || !context.mounted) {
    return const <String, String>{};
  }

  final Map<String, GlobalKey> keys = <String, GlobalKey>{
    for (final ModuleReportingPrintBlock block in chartBlocks)
      block.id: GlobalKey(debugLabel: 'print-capture-${block.id}'),
  };

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext overlayContext) {
      final ColorScheme colors = Theme.of(overlayContext).colorScheme;
      return IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: Align(
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: const Offset(-20000, -20000),
              child: ColoredBox(
                color: colors.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final ModuleReportingPrintBlock block in chartBlocks)
                      // Width-constrained, height intrinsic — avoids empty
                      // capture boxes and right-edge clipping.
                      SizedBox(
                        width: captureWidth,
                        child: RepaintBoundary(
                          key: keys[block.id],
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: ModuleReportingVisualizationView(
                              kind: block.kind,
                              snapshot: snapshot,
                              labels: labels,
                              title: block.title,
                              canExport: false,
                              embedded: true,
                              showOptionsBar: false,
                              fitForPrint: true,
                              storageKeyPrefix: 'print-capture-${block.id}',
                              dataLimit: block.maxRows.clamp(1, 24),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  overlay.insert(entry);

  try {
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 48));
    await WidgetsBinding.instance.endOfFrame;
    if (!overlay.mounted) {
      return const <String, String>{};
    }

    final Map<String, String> images = <String, String>{};
    for (final ModuleReportingPrintBlock block in chartBlocks) {
      final GlobalKey? key = keys[block.id];
      final RenderObject? renderObject = key?.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        continue;
      }
      if (renderObject.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
        if (!overlay.mounted) {
          break;
        }
      }
      final Size size = renderObject.size;
      if (size.isEmpty || size.width <= 0 || size.height <= 0) {
        continue;
      }
      final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      if (bytes == null) {
        continue;
      }
      images[block.id] =
          'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
    }
    return images;
  } finally {
    entry.remove();
  }
}
