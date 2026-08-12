import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_print_summary_dialog.dart';
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

  const NursingPatientDetail detail = NursingPatientDetail(
    summary: NursingPatientSummary(
      id: 'adm-1',
      admissionId: 'adm-1',
      displayId: 'ADM-1',
      patientDisplayName: 'Nurse Patient',
      patientId: 'PAT-1',
      encounterDisplayId: 'ENC-1',
      stage: 'ADMITTED_IN_BED',
      admissionStatus: 'ADMITTED_IN_BED',
    ),
  );

  testWidgets(
    'showNursingPrintSummary opens shared AppPrintPreviewPanel chrome',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
                    label: 'Open nursing print',
                    onPressed: () {
                      showNursingPrintSummary(
                        ref: ref,
                        context: context,
                        detail: detail,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open nursing print'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(AppPrintPreviewPanel), findsOneWidget);
      expect(find.byType(AppPrintPreviewWorkspace), findsOneWidget);
      expect(find.text('PRINT PREVIEW'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Print'));
      await tester.pumpAndSettle();

      expect(find.byType(AppPrintPreviewPanel), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
