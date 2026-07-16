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
    timeline: <OpdTimelineItem>[
      OpdTimelineItem(
        action: 'STAGE_CHANGED',
        stage: 'WAITING_DOCTOR_REVIEW',
        notes: 'Ready for review',
      ),
    ],
  );

  testWidgets(
    'uses AppDialog with Copy → Cancel → Print and general title',
    (WidgetTester tester) async {
      await _pumpDialog(tester, flow: flow, detail: detail);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
      expect(dialog.actions, hasLength(3));
      expect(find.text('PRINT SUMMARY'), findsOneWidget);
      expect(find.text('Patient Example'), findsWidgets);
      expect(find.byType(OpdActionContextPanel), findsOneWidget);
      expect(find.byType(AppReportPreviewPanel), findsOneWidget);
      expect(find.byType(AppFormSection), findsOneWidget);
      expect(find.text('Copy summary'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.print), findsWidgets);
      expect(find.byIcon(AppActionIcons.copy), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final List<String> actionLabels = dialog.actions
          .map(_actionLabel)
          .whereType<String>()
          .toList();
      expect(actionLabels, <String>['Copy summary', 'Cancel', 'Print']);
    },
  );

  testWidgets('Cancel pops false without treating print as saved', (
    WidgetTester tester,
  ) async {
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      detail: detail,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('Copy keeps the dialog open and writes the summary text', (
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

  testWidgets('summary text includes stage, vitals, and timeline details', (
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
    expect(summary, contains('Ready for review'));
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDialog(
      tester,
      flow: flow,
      detail: detail,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('PRINT SUMMARY'), findsOneWidget);
    expect(find.text('Copy summary'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
  });

  testWidgets('Print failure keeps the dialog open and shows AppFailure', (
    WidgetTester tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          printFormTemplateContextReadyProvider.overrideWith(
            (ref) async => throw StateError('print unavailable'),
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
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.byType(AppFormInformationBanner), findsOneWidget);
  });
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
