import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

void main() {
  testWidgets('AppPrintPreviewPanel exposes zoom and maximize toolbar', (
    WidgetTester tester,
  ) async {
    var maximized = false;
    var scale = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppPrintPreviewPanel(
                html: '<html><body><p>Preview body</p></body></html>',
                height: 240,
                scale: scale,
                maximized: maximized,
                onZoomIn: () => setState(() {
                  scale = AppPrintPreviewZoom.zoomIn(scale);
                }),
                onZoomOut: () => setState(() {
                  scale = AppPrintPreviewZoom.zoomOut(scale);
                }),
                onFitPage: () => setState(() {
                  scale = AppPrintPreviewZoom.fitPage(400);
                }),
                onMaximizeToggle: () {
                  setState(() => maximized = !maximized);
                },
                fallbackChild: const Text('Fallback preview'),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Print preview'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Fallback preview'), findsOneWidget);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(find.text('110%'), findsOneWidget);

    await tester.tap(find.byTooltip('Maximize preview'));
    await tester.pump();
    expect(find.byTooltip('Restore preview'), findsOneWidget);
  });

  testWidgets('AppPrintPreviewPaneModeBar switches layout modes', (
    WidgetTester tester,
  ) async {
    var mode = AppPrintPreviewPaneMode.split;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppPrintPreviewPaneModeBar(
                mode: mode,
                onChanged: (AppPrintPreviewPaneMode next) {
                  setState(() => mode = next);
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Preview'));
    await tester.pump();
    expect(mode, AppPrintPreviewPaneMode.preview);

    await tester.tap(find.byTooltip('Sections'));
    await tester.pump();
    expect(mode, AppPrintPreviewPaneMode.sections);
  });
}
