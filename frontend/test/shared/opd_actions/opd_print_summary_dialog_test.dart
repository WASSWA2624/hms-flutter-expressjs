import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_print_summary_dialog.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  const OpdFlowSummary flow = OpdFlowSummary(
    id: 'flow-internal',
    publicId: 'ENC0000001',
    patientDisplayName: 'Patient Example',
    patientIdentifier: 'PAT0000001',
    patientPhone: '+256700000000',
    providerDisplayName: 'Provider Example',
    stage: 'WAITING_DOCTOR_REVIEW',
    displayCode: 'WAITING_DOCTOR_REVIEW',
    nextStep: 'COMPLETE_REVIEW',
    displayNextStep: 'COMPLETE_REVIEW',
    triageLevel: 'LEVEL_3',
    chiefComplaint: 'Headache',
    consultationPaid: true,
    consultationPaymentStatus: 'PAID',
  );

  const OpdFlowDetail detail = OpdFlowDetail(
    summary: flow,
    vitalSigns: <OpdRelatedRecord>[
      OpdRelatedRecord(
        id: 'vital-1',
        kind: 'VITAL',
        title: 'Temperature',
        subtitle: '37.0 C',
      ),
    ],
    clinicalNotes: <OpdRelatedRecord>[
      OpdRelatedRecord(
        id: 'note-1',
        kind: 'NOTE',
        title: 'Observation',
      ),
    ],
    diagnoses: <OpdRelatedRecord>[
      OpdRelatedRecord(
        id: 'dx-1',
        kind: 'DIAGNOSIS',
        title: 'Migraine',
        status: 'CONFIRMED',
      ),
    ],
    labOrders: <OpdRelatedRecord>[
      OpdRelatedRecord(
        id: 'lab-1',
        kind: 'LAB',
        title: 'CBC',
        status: 'PENDING',
      ),
    ],
    timeline: <OpdTimelineItem>[
      OpdTimelineItem(
        action: 'STAGE_CHANGED',
        stage: 'WAITING_DOCTOR_REVIEW',
        notes: 'Ready for review',
      ),
    ],
  );

  testWidgets(
    'uses AppDialog with section picker, Copy → Cancel → Print',
    (WidgetTester tester) async {
      _useDesktopSurface(tester);
      await _pumpDialog(tester, flow: flow, detail: detail);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
      expect(dialog.actions, hasLength(3));
      expect(find.text('PRINT SUMMARY'), findsOneWidget);
      expect(find.text('Patient Example'), findsWidgets);
      expect(find.byType(OpdActionContextPanel), findsOneWidget);
      expect(find.byType(AppReportSectionPicker), findsOneWidget);
      expect(find.byType(AppPrintPreviewWorkspace), findsOneWidget);
      expect(find.byType(AppPrintPreviewPanel), findsOneWidget);
      expect(find.text('Visit'), findsWidgets);
      expect(find.text('Payment'), findsWidgets);
      expect(find.text('Vitals'), findsWidgets);
      expect(find.text('Copy summary'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.print), findsWidgets);
      expect(find.byIcon(AppActionIcons.copy), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final List<String> actionLabels = dialog.actions
          .map(_actionLabel)
          .whereType<String>()
          .toList();
      expect(actionLabels, <String>['Copy summary', 'Print', 'Close']);
    },
  );

  testWidgets('Close pops false without treating print as saved', (
    WidgetTester tester,
  ) async {
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      detail: detail,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('Copy keeps the dialog open and writes selected summary text', (
    WidgetTester tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final Object? arguments = methodCall.arguments;
          if (arguments is Map<Object?, Object?>) {
            clipboardText = arguments['text'] as String?;
          }
          return null;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    bool? result;
    await _pumpDialog(
      tester,
      flow: flow,
      detail: detail,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Copy summary'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('Patient Example'));
    expect(clipboardText, contains('Headache'));
    expect(clipboardText, contains('Temperature'));
    expect(clipboardText, contains('Migraine'));
    expect(clipboardText, contains('CBC'));
    expect(clipboardText, isNot(contains('Try again')));
  });

  testWidgets(
    'Print dismisses with false and does not signal a persisted save',
    (WidgetTester tester) async {
      bool? result;

      await _pumpDialog(
        tester,
        flow: flow,
        detail: detail,
        onResult: (bool? value) => result = value,
      );

      await tester.tap(find.widgetWithText(AppButton, 'Print'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.byType(AppDialog), findsNothing);
    },
  );

  testWidgets('summary text includes selected clinical and payment detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              final String summary = buildOpdPrintSummaryText(
                context: context,
                flow: flow,
                detail: detail,
              );
              return Text(summary);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final String summary = tester.widget<Text>(find.byType(Text)).data!;
    expect(summary, contains('Patient Example'));
    expect(summary, contains('PAT0000001'));
    expect(summary, contains('Headache'));
    expect(summary, contains('Temperature'));
    expect(summary, contains('Migraine'));
    expect(summary, contains('CBC'));
    expect(summary, contains('Pending'));
    expect(summary, contains('Ready for review'));
    expect(summary, isNot(contains('Try again')));
  });

  testWidgets('deselecting vitals removes them from preview', (
    WidgetTester tester,
  ) async {
    _useDesktopSurface(tester);
    await _pumpDialog(tester, flow: flow, detail: detail);

    expect(find.textContaining('Temperature'), findsWidgets);

    final Finder vitalsTile = find.text('Vitals');
    await tester.ensureVisible(vitalsTile.first);
    await tester.tap(vitalsTile.first);
    await tester.pumpAndSettle();

    final SelectableText preview = tester.widget(
      find.descendant(
        of: find.byType(AppPrintPreviewPanel),
        matching: find.byType(SelectableText),
      ),
    );
    expect(preview.data, isNot(contains('Temperature')));
    expect(preview.data, contains('Patient Example'));
  });

  testWidgets('HTML builder uses PrintFormTemplate sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              final String html = buildOpdPrintSummaryHtml(
                context: context,
                flow: flow,
                detail: detail,
                selectedSections: <OpdPrintSection>{
                  OpdPrintSection.visit,
                  OpdPrintSection.payment,
                  OpdPrintSection.vitals,
                  OpdPrintSection.diagnoses,
                  OpdPrintSection.services,
                },
              );
              return Text(html);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final String html = tester.widget<Text>(find.byType(Text)).data!;
    expect(html, contains('print-template-section'));
    expect(html, contains('print-template-kv'));
    expect(html, contains('print-template-list'));
    expect(html, contains('Migraine'));
    expect(html, contains('CBC'));
    expect(html, isNot(contains('Try again')));
  });

  testWidgets('empty clinical sections stay disabled in the picker', (
    WidgetTester tester,
  ) async {
    _useDesktopSurface(tester);
    await _pumpDialog(tester, flow: flow);

    final List<ReportSectionAvailability> availabilities =
        buildOpdPrintSectionAvailabilities(flow: flow);
    expect(
      availabilities
          .firstWhere((ReportSectionAvailability s) => s.id == OpdPrintSection.vitals)
          .enabled,
      isFalse,
    );
    expect(
      availabilities
          .firstWhere(
            (ReportSectionAvailability s) => s.id == OpdPrintSection.visit,
          )
          .enabled,
      isTrue,
    );
    expect(find.text('No data available'), findsWidgets);
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDialog(
      tester,
      flow: flow,
      detail: detail,
      dark: true,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('PRINT SUMMARY'), findsOneWidget);
    expect(find.byType(AppPrintPreviewWorkspace), findsOneWidget);
    expect(find.text('Copy summary'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
  });

  testWidgets(
    'unavailable print branding keeps the preview dialog from mounting',
    (WidgetTester tester) async {
      FlutterErrorDetails? caught;
      final void Function(FlutterErrorDetails)? previous =
          FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        caught = details;
      };
      addTearDown(() => FlutterError.onError = previous);

      bool? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            printFormTemplateContextReadyProvider.overrideWith(
              (ref) async => throw StateError('print unavailable'),
            ),
            printFormTemplateContextProvider.overrideWith(
              (ref) => throw StateError('print unavailable'),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return AppButton.primary(
                    label: 'Open',
                    onPressed: () async {
                      result = await showPrintOpdSummaryDialog(
                        context: context,
                        flow: flow,
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

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.byType(AppPrintPreviewPanel), findsNothing);
      expect(caught, isNotNull);
    },
  );

  testWidgets(
    'Print recovers when ready context hangs by using sync branding',
    (WidgetTester tester) async {
      bool? result;
      final Completer<PrintFormTemplateContext> hanging =
          Completer<PrintFormTemplateContext>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            printFormTemplateContextReadyProvider.overrideWith(
              (ref) => hanging.future,
            ),
            printFormTemplateContextProvider.overrideWith(
              (ref) => const PrintFormTemplateContext(
                appBranding: PrintFormBranding(
                  name: 'Fallback HMS',
                  kind: PrintFormBrandingKind.app,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return AppButton.primary(
                    label: 'Open',
                    onPressed: () async {
                      result = await showPrintOpdSummaryDialog(
                        context: context,
                        flow: flow,
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

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Print'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.byType(AppDialog), findsNothing);
    },
  );
}

String? _actionLabel(Widget action) {
  if (action is AppButton) {
    return action.label;
  }
  if (action is AppReportActionButton) {
    return action.label;
  }
  return null;
}

/// Desktop-width surface.
///
/// The print dialog is preview-first: below [AppBreakpoints.lg] it drops the
/// sections pane entirely and shows only the preview, so any test that asserts
/// on the section picker has to run on a surface wide enough to split.
void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required OpdFlowSummary flow,
  OpdFlowDetail? detail,
  ValueChanged<bool?>? onResult,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        printFormTemplateContextReadyProvider.overrideWith(
          (ref) async => const PrintFormTemplateContext(
            appBranding: PrintFormBranding(
              name: 'Test HMS',
              kind: PrintFormBrandingKind.app,
            ),
          ),
        ),
        printFormTemplateContextProvider.overrideWith(
          (ref) => const PrintFormTemplateContext(
            appBranding: PrintFormBranding(
              name: 'Test HMS',
              kind: PrintFormBrandingKind.app,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          );
        },
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return AppButton.primary(
                label: 'Open',
                onPressed: () async {
                  final bool? value = await showPrintOpdSummaryDialog(
                    context: context,
                    flow: flow,
                    detail: detail,
                  );
                  onResult?.call(value);
                },
              );
            },
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
