import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/ipd_actions/ipd_actions.dart';

void main() {
  testWidgets(
    'uses AppConfirmActionDialog with Cancel and Release bed',
    (WidgetTester tester) async {
      await _pumpDialog(tester);

      expect(find.byType(IpdReleaseBedDialog), findsOneWidget);
      expect(find.byType(AppConfirmActionDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('RELEASE BED'), findsOneWidget);
      expect(
        find.text('Release the current bed assignment for this admission?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Release bed'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.cleaning), findsWidgets);
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
    expect((dialog.title! as Text).data, 'Release bed');
    expect(find.text('RELEASE BED'), findsOneWidget);
    expect(find.text('JANE DOE'), findsNothing);
    expect(find.text('Jane Doe'), findsNothing);
  });

  testWidgets('Release bed pops true after persisted success', (
    WidgetTester tester,
  ) async {
    bool? result;
    var confirmed = false;

    await _pumpDialog(
      tester,
      onConfirm: () async {
        confirmed = true;
        return null;
      },
      onResult: (bool? value) => result = value,
    );

    final Finder release = find.widgetWithText(AppButton, 'Release bed');
    await tester.ensureVisible(release);
    await tester.tap(release);
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(result, isTrue);
  });

  testWidgets('Cancel pops false without confirming', (WidgetTester tester) async {
    bool? result;
    var confirmed = false;

    await _pumpDialog(
      tester,
      onConfirm: () async {
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
      onConfirm: () async => AppFailure.validation(),
      onResult: (bool? value) => result = value,
    );

    final Finder release = find.widgetWithText(AppButton, 'Release bed');
    await tester.ensureVisible(release);
    await tester.tap(release);
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppConfirmActionDialog), findsOneWidget);
    expect(find.text('Release bed'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('blocks dismiss while release is in flight', (
    WidgetTester tester,
  ) async {
    final Completer<AppFailure?> completer = Completer<AppFailure?>();

    await _pumpDialog(tester, onConfirm: () => completer.future);

    final Finder release = find.widgetWithText(AppButton, 'Release bed');
    await tester.ensureVisible(release);
    await tester.tap(release);
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

    expect(find.byType(AppConfirmActionDialog), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Release bed'), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  Future<AppFailure?> Function()? onConfirm,
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
                label: 'Open release',
                leadingIcon: AppActionIcons.cleaning,
                onPressed: () async {
                  final bool? value = await showIpdReleaseBedDialog(
                    context: context,
                    onConfirm: onConfirm ?? () async => null,
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
  await tester.tap(find.widgetWithText(AppButton, 'Open release'));
  await tester.pumpAndSettle();
}
