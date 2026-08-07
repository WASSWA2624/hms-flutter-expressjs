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
Future<Map<String, String>> captureModuleReportingChartImages({
  required BuildContext context,
  required ModuleReportingReportSnapshot snapshot,
  required ModuleReportingLabels labels,
  required List<ModuleReportingPrintBlock> blocks,
  double pixelRatio = 2,
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
      return IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: Align(
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: const Offset(-20000, -20000),
              child: ColoredBox(
                color: Theme.of(overlayContext).colorScheme.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final ModuleReportingPrintBlock block in chartBlocks)
                      SizedBox(
                        width: block.width.clamp(280, 900).toDouble(),
                        height: block.height.clamp(160, 720).toDouble(),
                        child: RepaintBoundary(
                          key: keys[block.id],
                          child: ModuleReportingVisualizationView(
                            kind: block.kind,
                            snapshot: snapshot,
                            labels: labels,
                            title: block.title,
                            canExport: false,
                            embedded: true,
                            showOptionsBar: false,
                            storageKeyPrefix: 'print-capture-${block.id}',
                            dataLimit: block.maxRows,
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
    // Allow layout + paint of off-screen chart hosts.
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 32));
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
