import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

void main() {
  test('AppPrintPreviewPages counts article.print-template-page nodes', () {
    expect(AppPrintPreviewPages.countFromHtml('<div>plain</div>'), 1);
    expect(
      AppPrintPreviewPages.countFromHtml(
        '<article class="print-template-page">one</article>'
        '<article class="print-template-page print-template-page--anchored-footer">'
        'two</article>',
      ),
      2,
    );
    expect(AppPrintPreviewPages.clampPage(0, 3), 1);
    expect(AppPrintPreviewPages.clampPage(9, 3), 3);
  });

  testWidgets(
    'AppPrintPreviewPanel has no title header; zoom on toolbar without maximize',
    (WidgetTester tester) async {
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
                  onZoomIn: () => setState(() {
                    scale = AppPrintPreviewZoom.zoomIn(scale);
                  }),
                  onZoomOut: () => setState(() {
                    scale = AppPrintPreviewZoom.zoomOut(scale);
                  }),
                  onFitPage: () => setState(() {
                    scale = AppPrintPreviewZoom.fitPage(400);
                  }),
                  fallbackChild: const Text('Fallback preview'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Print preview'), findsNothing);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Page 1 of 1'), findsOneWidget);
      expect(find.byTooltip('Maximize preview'), findsNothing);
      expect(find.text('Fallback preview'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      expect(find.text('110%'), findsOneWidget);
    },
  );

  testWidgets('AppPrintPreviewToolbar page controls respect bounds', (
    WidgetTester tester,
  ) async {
    var page = 1;
    const int total = 3;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppPrintPreviewToolbar(
                scale: 1,
                currentPage: page,
                pageCount: total,
                onPagePrevious: () => setState(() => page = page - 1),
                onPageNext: () => setState(() => page = page + 1),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Page 1 of 3'), findsOneWidget);
    AppButton pageTool(String tooltip) {
      return tester.widget<AppButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(AppButton),
        ),
      );
    }

    expect(pageTool('Previous page').onPressed, isNull);
    expect(find.byTooltip('Maximize preview'), findsNothing);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pump();
    expect(page, 2);
    expect(find.text('Page 2 of 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pump();
    expect(page, 3);
    expect(find.text('Page 3 of 3'), findsOneWidget);
    expect(pageTool('Next page').onPressed, isNull);

    await tester.tap(find.byTooltip('Previous page'));
    await tester.pump();
    expect(page, 2);
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

  testWidgets(
    'AppPrintPreviewWorkspace keeps tabs and toolbar in the preview column',
    (WidgetTester tester) async {
      var mode = AppPrintPreviewPaneMode.split;
      var scale = 1.0;

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
                    sectionsFlex: 2,
                    previewFlex: 3,
                    paneMode: mode,
                    onPaneModeChanged: (AppPrintPreviewPaneMode next) {
                      setState(() => mode = next);
                    },
                    toolbar: AppPrintPreviewToolbar(
                      scale: scale,
                      currentPage: 1,
                      pageCount: 2,
                      onZoomIn: () => setState(() {
                        scale = AppPrintPreviewZoom.zoomIn(scale);
                      }),
                    ),
                    sectionPicker: const Text('Sections content'),
                    preview: const AppPrintPreviewPanel(
                      html:
                          '<article class="print-template-page">a</article>'
                          '<article class="print-template-page">b</article>',
                      toolbarEnabled: false,
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
      expect(find.byType(AppPrintPreviewToolbar), findsOneWidget);
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(find.text('Sections content'), findsOneWidget);
      expect(find.text('Preview content'), findsOneWidget);
      expect(find.byTooltip('Maximize preview'), findsNothing);
      expect(find.text('Print preview'), findsNothing);

      final Finder panel = find.byType(AppPrintPreviewPanel);
      expect(
        find.descendant(
          of: panel,
          matching: find.byType(AppPrintPreviewToolbar),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.article_outlined));
      await tester.pumpAndSettle();
      expect(mode, AppPrintPreviewPaneMode.preview);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppPrintPreviewToolbar), findsOneWidget);
      expect(find.text('Sections content'), findsNothing);

      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();
      expect(mode, AppPrintPreviewPaneMode.sections);
      // Sections-only hides zoom/page toolbar; tabs remain for navigation.
      expect(find.byType(AppPrintPreviewToolbar), findsNothing);
      expect(find.byType(AppTabStrip), findsOneWidget);
    },
  );
}
