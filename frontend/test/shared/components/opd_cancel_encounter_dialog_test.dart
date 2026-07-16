import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

void main() {
  const OpdFlowSummary flow = OpdFlowSummary(
    id: 'encounter-1',
    publicId: 'ENC000001',
    status: 'OPEN',
    stage: 'WAITING_VITALS',
    patientDisplayName: 'Jane Doe',
    providerDisplayName: 'Dr. Example',
  );

  testWidgets(
    'uses AppDialog with destructive Cancel encounter commit',
    (WidgetTester tester) async {
      await _pumpDialog(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('CANCEL ENCOUNTER'), findsOneWidget);
      expect(find.text('ENC000001'), findsOneWidget);
      expect(find.text('Cancellation reason'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cancel encounter'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.delete), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
      expect(dialog.scrollable, isTrue);
    },
  );

  testWidgets('title never uses a patient display name', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, isA<Text>());
    expect((dialog.title! as Text).data, 'Cancel encounter');
    expect(find.text('CANCEL ENCOUNTER'), findsOneWidget);
    expect(find.text('JANE DOE'), findsNothing);
  });

  testWidgets('Cancel pops false without confirming', (WidgetTester tester) async {
    bool? result;
    var confirmed = false;

    await _pumpDialog(
      tester,
      onConfirm: (Map<String, Object?> payload) async {
        confirmed = true;
        return null;
      },
      onResult: (bool? value) => result = value,
    );

    final Finder cancel = find.widgetWithText(AppButton, 'Cancel');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
    expect(result, isFalse);
  });

  testWidgets('Cancel encounter pops true after persisted success', (
    WidgetTester tester,
  ) async {
    bool? result;
    Map<String, Object?>? submitted;

    await _pumpDialog(
      tester,
      onConfirm: (Map<String, Object?> payload) async {
        submitted = payload;
        return null;
      },
      onResult: (bool? value) => result = value,
    );

    final Finder commit = find.widgetWithText(AppButton, 'Cancel encounter');
    await tester.ensureVisible(commit);
    await tester.tap(commit);
    await tester.pumpAndSettle();

    expect(submitted, containsPair('reason_code', 'PATIENT_LEFT'));
    expect(submitted, containsPair('reason_notes', null));
    expect(result, isTrue);
  });

  testWidgets('OTHER reason requires notes and does not mutate', (
    WidgetTester tester,
  ) async {
    bool? result;
    var confirmed = false;

    await _pumpDialog(
      tester,
      onConfirm: (Map<String, Object?> payload) async {
        confirmed = true;
        return null;
      },
      onResult: (bool? value) => result = value,
    );

    final Finder reasonField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppSelectField<String> &&
          widget.labelText == 'Cancellation reason',
    );
    tester.widget<AppSelectField<String>>(reasonField).onChanged?.call('OTHER');
    await tester.pump();

    final Finder commit = find.widgetWithText(AppButton, 'Cancel encounter');
    await tester.ensureVisible(commit);
    await tester.tap(commit);
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
    expect(result, isNull);
    expect(find.text('Enter details when selecting Other.'), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
  });

  testWidgets('OTHER reason submits notes after persisted success', (
    WidgetTester tester,
  ) async {
    bool? result;
    Map<String, Object?>? submitted;

    await _pumpDialog(
      tester,
      onConfirm: (Map<String, Object?> payload) async {
        submitted = payload;
        return null;
      },
      onResult: (bool? value) => result = value,
    );

    final Finder reasonField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppSelectField<String> &&
          widget.labelText == 'Cancellation reason',
    );
    tester.widget<AppSelectField<String>>(reasonField).onChanged?.call('OTHER');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Left for another facility');
    final Finder commit = find.widgetWithText(AppButton, 'Cancel encounter');
    await tester.ensureVisible(commit);
    await tester.tap(commit);
    await tester.pumpAndSettle();

    expect(submitted, containsPair('reason_code', 'OTHER'));
    expect(
      submitted,
      containsPair('reason_notes', 'Left for another facility'),
    );
    expect(result, isTrue);
  });

  testWidgets('failure keeps dialog open and does not pop success', (
    WidgetTester tester,
  ) async {
    bool? result;

    await _pumpDialog(
      tester,
      onConfirm: (Map<String, Object?> payload) async => AppFailure.network(),
      onResult: (bool? value) => result = value,
    );

    final Finder commit = find.widgetWithText(AppButton, 'Cancel encounter');
    await tester.ensureVisible(commit);
    await tester.tap(commit);
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancel encounter'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('blocks dismiss while cancel is in flight', (
    WidgetTester tester,
  ) async {
    final Completer<AppFailure?> completer = Completer<AppFailure?>();

    await _pumpDialog(tester, onConfirm: (_) => completer.future);

    final Finder commit = find.widgetWithText(AppButton, 'Cancel encounter');
    await tester.ensureVisible(commit);
    await tester.tap(commit);
    await tester.pump();

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isFalse);

    final AppButton cancel = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Cancel'),
    );
    expect(cancel.enabled, isFalse);

    completer.complete(null);
    await tester.pumpAndSettle();
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
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('CANCEL ENCOUNTER'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancel encounter'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  Future<AppFailure?> Function(Map<String, Object?> payload)? onConfirm,
  void Function(bool? result)? onResult,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  const OpdFlowSummary flow = OpdFlowSummary(
    id: 'encounter-1',
    publicId: 'ENC000001',
    status: 'OPEN',
    stage: 'WAITING_VITALS',
    patientDisplayName: 'Jane Doe',
    providerDisplayName: 'Dr. Example',
  );

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
                label: 'Open cancel',
                leadingIcon: AppActionIcons.delete,
                onPressed: () async {
                  final bool? value = await showOpdCancelEncounterDialog(
                    context: context,
                    flow: flow,
                    onConfirm: onConfirm ?? (_) async => null,
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
  await tester.tap(find.widgetWithText(AppButton, 'Open cancel'));
  await tester.pumpAndSettle();
}
