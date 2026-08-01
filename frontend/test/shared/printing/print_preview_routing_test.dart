import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const PrintFormTemplateContext templateContext = PrintFormTemplateContext(
    appBranding: PrintFormBranding(
      name: 'Test HMS',
      kind: PrintFormBrandingKind.app,
    ),
  );

  testWidgets(
    'PrintDocumentTemplates default preview mounts AppPrintPreviewPanel before print',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            printFormTemplateContextReadyProvider.overrideWith(
              (ref) async => templateContext,
            ),
            printFormTemplateContextProvider.overrideWith(
              (ref) => templateContext,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  return AppButton.primary(
                    label: 'Open print',
                    onPressed: () async {
                      await PrintDocumentTemplates.clinicalSummary(
                        ref: ref,
                        context: context,
                        title: 'Clinical summary',
                        patientContext: PrintFormPatientContext(
                          patientNameLabel: 'Patient',
                          patientName: 'Ada Lovelace',
                          patientIdLabel: 'ID',
                          patientId: 'PAT-1',
                        ),
                        bodyHtml: '<p>Summary body</p>',
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppPrintPreviewPanel), findsNothing);

      await tester.tap(find.text('Open print'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(AppPrintPreviewPanel), findsOneWidget);
      expect(find.text('Clinical summary'), findsWidgets);
      expect(find.text('Review the document, then print.'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Print'));
      await tester.pumpAndSettle();

      expect(find.byType(AppPrintPreviewPanel), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'showPreview:false skips shared dialog and prints immediately',
    (WidgetTester tester) async {
      var printed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            printFormTemplateContextReadyProvider.overrideWith(
              (ref) async => templateContext,
            ),
            printFormTemplateContextProvider.overrideWith(
              (ref) => templateContext,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  return AppButton.primary(
                    label: 'Print now',
                    onPressed: () async {
                      await PrintDocumentTemplates.clinicalSummary(
                        ref: ref,
                        context: context,
                        title: 'Embedded preview caller',
                        patientContext: PrintFormPatientContext(
                          patientNameLabel: 'Patient',
                          patientName: 'Ada Lovelace',
                          patientIdLabel: 'ID',
                          patientId: 'PAT-1',
                        ),
                        bodyHtml: '<p>Summary body</p>',
                        showPreview: false,
                      );
                      printed = true;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Print now'));
      await tester.pumpAndSettle();

      expect(printed, isTrue);
      expect(find.byType(AppPrintPreviewPanel), findsNothing);
      expect(find.byType(AppDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('showAppPrintPreviewDialog mounts shared preview chrome', (
    WidgetTester tester,
  ) async {
    var printed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return AppButton.primary(
                label: 'Open',
                onPressed: () {
                  showAppPrintPreviewDialog(
                    context: context,
                    title: 'Invoice preview',
                    documentHtml: '<html><body><p>Invoice</p></body></html>',
                    fallbackText: 'Invoice fallback',
                    onPrint: () async {
                      printed = true;
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(AppPrintPreviewPanel), findsOneWidget);
    expect(find.text('INVOICE PREVIEW'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Print'));
    await tester.pumpAndSettle();

    expect(printed, isTrue);
    expect(find.byType(AppPrintPreviewPanel), findsNothing);
  });
}
