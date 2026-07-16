import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';

void main() {
  const OpdFlowSummary flow = OpdFlowSummary(
    id: 'encounter-admit',
    publicId: 'ENC000001',
    patientDisplayName: 'Patient Example',
    patientIdentifier: 'PAT000001',
    encounterType: 'OPD',
    status: 'OPEN',
    stage: 'DISPOSITION',
  );

  testWidgets(
    'uses AppConfirmActionDialog with Cancel and Open inpatient admission',
    (WidgetTester tester) async {
      await _pumpDialog(tester, flow: flow);

      expect(find.byType(AppConfirmActionDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(OpdActionContextPanel), findsOneWidget);
      expect(find.text('ADMISSION HANDOFF'), findsOneWidget);
      expect(find.text('Patient Example'), findsOneWidget);
      expect(
        find.text(
          'Admitted to IPD. Open inpatient care to assign a bed. OPD visit stays linked.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Open inpatient admission'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.bed), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.scrollable, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
    },
  );

  testWidgets('Open inpatient admission pops true without mutating state', (
    WidgetTester tester,
  ) async {
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      onResult: (bool? value) => result = value,
    );

    final Finder openAdmission = find.widgetWithText(
      AppButton,
      'Open inpatient admission',
    );
    await tester.ensureVisible(openAdmission);
    await tester.tap(openAdmission);
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('Cancel pops false without navigating', (WidgetTester tester) async {
    bool? result;

    await _pumpDialog(
      tester,
      flow: flow,
      onResult: (bool? value) => result = value,
    );

    final Finder cancel = find.widgetWithText(AppButton, 'Cancel');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('title never uses the patient display name', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, flow: flow);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, isA<Text>());
    expect((dialog.title! as Text).data, 'Admission handoff');
    expect(find.text('ADMISSION HANDOFF'), findsOneWidget);
    expect(find.text('PATIENT EXAMPLE'), findsNothing);
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
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(find.byType(AppConfirmActionDialog), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Open inpatient admission'), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required OpdFlowSummary flow,
  void Function(bool? result)? onResult,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
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
            return Center(
              child: AppButton.primary(
                label: 'Open handoff',
                leadingIcon: AppActionIcons.bed,
                onPressed: () async {
                  final bool? value = await showOpdAdmissionHandoffDialog(
                    context: context,
                    flow: flow,
                  );
                  onResult?.call(value);
                },
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(AppButton, 'Open handoff'));
  await tester.pumpAndSettle();
}
