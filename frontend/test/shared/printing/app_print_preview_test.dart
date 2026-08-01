import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

void main() {
  testWidgets('AppPrintPreviewPanel has no title header; zoom and maximize on toolbar', (
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

    expect(find.text('Print preview'), findsNothing);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Fallback preview'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(find.text('110%'), findsOneWidget);

    await tester.tap(find.byTooltip('Maximize preview'));
    await tester.pump();
    expect(find.byTooltip('Restore preview'), findsOneWidget);
  });

  testWidgets('AppPrintPreviewPaneModeBar uses AppTabStrip to switch modes', (
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

    expect(find.byType(AppTabStrip), findsOneWidget);

    await tester.tap(find.text('Preview'));
    await tester.pump();
    expect(mode, AppPrintPreviewPaneMode.preview);

    await tester.tap(find.text('Sections'));
    await tester.pump();
    expect(mode, AppPrintPreviewPaneMode.sections);

    await tester.tap(find.text('Split view'));
    await tester.pump();
    expect(mode, AppPrintPreviewPaneMode.split);
  });

  testWidgets('AppPrintPreviewWorkspace places tab strip on sections column only', (
    WidgetTester tester,
  ) async {
    var mode = AppPrintPreviewPaneMode.split;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 480,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return AppPrintPreviewWorkspace(
                  height: 480,
                  sectionsFlex: 3,
                  previewFlex: 2,
                  paneMode: mode,
                  onPaneModeChanged: (AppPrintPreviewPaneMode next) {
                    setState(() => mode = next);
                  },
                  sectionPicker: const Text('Sections content'),
                  preview: const AppPrintPreviewPanel(
                    html: '<html><body></body></html>',
                    height: 400,
                    fallbackChild: Text('Preview content'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Sections content'), findsOneWidget);
    expect(find.text('Preview content'), findsOneWidget);
    expect(find.text('Print preview'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(mode, AppPrintPreviewPaneMode.preview);
    // Preview-only still exposes the strip so the user can switch back.
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Sections content'), findsNothing);
  });
}
