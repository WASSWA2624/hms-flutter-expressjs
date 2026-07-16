import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  testWidgets(
    'uses AppTextActionDialog with Cancel and Close encounter',
    (WidgetTester tester) async {
      await _pumpDialog(tester);

      expect(find.byType(AppTextActionDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('CLOSE ENCOUNTER'), findsOneWidget);
      expect(find.text('Close reason (optional)'), findsOneWidget);
      expect(find.text('ENC000001'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Close encounter'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.success), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
    },
  );

  testWidgets('title never uses a patient display name', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, isA<Text>());
    expect((dialog.title! as Text).data, 'Close encounter');
    expect(find.text('CLOSE ENCOUNTER'), findsOneWidget);
    expect(find.text('JANE DOE'), findsNothing);
    expect(find.text('Jane Doe'), findsNothing);
  });

  testWidgets('Close encounter pops true after persisted success', (
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

    await tester.enterText(find.byType(TextField), 'Visit completed');
    final Finder close = find.widgetWithText(AppButton, 'Close encounter');
    await tester.ensureVisible(close);
    await tester.tap(close);
    await tester.pumpAndSettle();

    expect(submitted, containsPair('reason_notes', 'Visit completed'));
    expect(result, isTrue);
  });

  testWidgets('omits empty reason_notes on confirm', (WidgetTester tester) async {
    Map<String, Object?>? submitted;

    await _pumpDialog(
      tester,
      onConfirm: (Map<String, Object?> payload) async {
        submitted = payload;
        return null;
      },
    );

    final Finder close = find.widgetWithText(AppButton, 'Close encounter');
    await tester.ensureVisible(close);
    await tester.tap(close);
    await tester.pumpAndSettle();

    expect(submitted, containsPair('reason_notes', null));
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

  testWidgets('failure keeps dialog open and does not pop success', (
    WidgetTester tester,
  ) async {
    bool? result;

    await _pumpDialog(
      tester,
      onConfirm: (Map<String, Object?> payload) async => AppFailure.validation(),
      onResult: (bool? value) => result = value,
    );

    final Finder close = find.widgetWithText(AppButton, 'Close encounter');
    await tester.ensureVisible(close);
    await tester.tap(close);
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppTextActionDialog), findsOneWidget);
    expect(find.text('Close encounter'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('blocks dismiss while close is in flight', (
    WidgetTester tester,
  ) async {
    final Completer<AppFailure?> completer = Completer<AppFailure?>();

    await _pumpDialog(tester, onConfirm: (_) => completer.future);

    final Finder close = find.widgetWithText(AppButton, 'Close encounter');
    await tester.ensureVisible(close);
    await tester.tap(close);
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

    expect(find.byType(AppTextActionDialog), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Close encounter'), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
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
                label: 'Open close',
                leadingIcon: AppActionIcons.success,
                onPressed: () async {
                  final bool? value = await showOpdCloseEncounterDialog(
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
  await tester.tap(find.widgetWithText(AppButton, 'Open close'));
  await tester.pumpAndSettle();
}
