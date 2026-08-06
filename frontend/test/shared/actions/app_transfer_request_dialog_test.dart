import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

void main() {
  testWidgets('showAppTransferRequestDialog uses non-dismissible AppDialog', (
    WidgetTester tester,
  ) async {
    await _pumpOpener(tester);

    expect(find.byType(AppTransferRequestDialog), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('REQUEST TRANSFER'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Request transfer'), findsOneWidget);
    expect(find.byIcon(AppActionIcons.transfer), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.scrollable, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
  });

  testWidgets('Close pops false without calling onSubmit', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;
    bool? result;

    await _pumpOpener(
      tester,
      onResult: (bool? value) => result = value,
      onSubmit: (_) async {
        submitCount += 1;
        return null;
      },
    );

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(submitCount, 0);
  });

  testWidgets('failure keeps dialog open', (WidgetTester tester) async {
    bool? result;

    await _pumpOpener(
      tester,
      onResult: (bool? value) => result = value,
      onSubmit: (_) async => AppFailure.network(),
    );

    final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    field.onChanged?.call('ward-2');
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'Request transfer'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
  });

  testWidgets('success pops true with selected ward id', (
    WidgetTester tester,
  ) async {
    String? submittedWardId;
    bool? result;

    await _pumpOpener(
      tester,
      onResult: (bool? value) => result = value,
      onSubmit: (String toWardId) async {
        submittedWardId = toWardId;
        return null;
      },
    );

    final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    field.onChanged?.call('ward-2');
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'Request transfer'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(submittedWardId, 'ward-2');
    expect(find.byType(AppDialog), findsNothing);
  });
}

Future<void> _pumpOpener(
  WidgetTester tester, {
  ValueChanged<bool?>? onResult,
  Future<AppFailure?> Function(String toWardId)? onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: AppButton.primary(
                label: 'Open',
                leadingIcon: AppActionIcons.transfer,
                onPressed: () async {
                  final bool? value = await showAppTransferRequestDialog(
                    context: context,
                    title: 'Request transfer',
                    wardLabel: 'Target ward',
                    wardHint: 'Select a ward',
                    submitLabel: 'Request transfer',
                    requiredMessage: 'Required',
                    wardOptions: const <AppSelectOption<String>>[
                      AppSelectOption<String>(
                        value: 'ward-1',
                        label: 'Ward 1',
                      ),
                      AppSelectOption<String>(
                        value: 'ward-2',
                        label: 'Ward 2',
                      ),
                    ],
                    onSubmit: onSubmit ?? (_) async => null,
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
  await tester.tap(find.widgetWithText(AppButton, 'Open'));
  await tester.pumpAndSettle();
}
