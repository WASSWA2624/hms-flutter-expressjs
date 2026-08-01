import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

void main() {
  testWidgets('AppPrintPreviewPanel shows maximize control and fallback', (
    WidgetTester tester,
  ) async {
    var maximized = false;

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
                maximized: maximized,
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
    expect(find.text('Fallback preview'), findsOneWidget);

    await tester.tap(find.byTooltip('Maximize preview'));
    await tester.pump();

    expect(find.byTooltip('Restore preview'), findsOneWidget);
  });
}
