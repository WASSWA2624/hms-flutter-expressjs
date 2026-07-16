import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

void main() {
  test('appTransferDefaultActionForStatus maps transfer statuses', () {
    expect(appTransferDefaultActionForStatus(null), 'APPROVE');
    expect(appTransferDefaultActionForStatus('REQUESTED'), 'APPROVE');
    expect(appTransferDefaultActionForStatus('APPROVED'), 'START');
    expect(appTransferDefaultActionForStatus('IN_PROGRESS'), 'COMPLETE');
  });

  test('appTransferRequiresDestinationBed only for COMPLETE', () {
    expect(appTransferRequiresDestinationBed('APPROVE'), isFalse);
    expect(appTransferRequiresDestinationBed('COMPLETE'), isTrue);
    expect(appTransferRequiresDestinationBed('complete'), isTrue);
  });

  testWidgets('showAppTransferUpdateDialog uses non-dismissible AppDialog', (
    WidgetTester tester,
  ) async {
    await _pumpOpener(tester);

    expect(find.byType(AppTransferUpdateDialog), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('MANAGE TRANSFER'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.byIcon(AppActionIcons.transfer), findsWidgets);
    expect(find.byIcon(AppActionIcons.edit), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.scrollable, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
  });

  testWidgets('Cancel pops false without calling onSubmit', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;
    bool? result;

    await _pumpOpener(
      tester,
      onResult: (bool? value) => result = value,
      onSubmit: ({required String action, String? toBedId}) async {
        submitCount += 1;
        return null;
      },
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(submitCount, 0);
  });

  testWidgets('failure keeps dialog open', (WidgetTester tester) async {
    bool? result;

    await _pumpOpener(
      tester,
      onResult: (bool? value) => result = value,
      onSubmit: ({required String action, String? toBedId}) async {
        return AppFailure.network();
      },
    );

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
  });

  testWidgets('blocks close and Cancel while saving', (WidgetTester tester) async {
    final Completer<AppFailure?> completer = Completer<AppFailure?>();

    await _pumpOpener(
      tester,
      onSubmit: ({required String action, String? toBedId}) {
        return completer.future;
      },
    );

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
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

  testWidgets('success pops true with selected action', (
    WidgetTester tester,
  ) async {
    String? submittedAction;
    bool? result;

    await _pumpOpener(
      tester,
      onResult: (bool? value) => result = value,
      onSubmit: ({required String action, String? toBedId}) async {
        submittedAction = action;
        return null;
      },
    );

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(submittedAction, AppTransferUpdateActions.approve);
    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('COMPLETE shows destination bed and submits bed id', (
    WidgetTester tester,
  ) async {
    String? submittedAction;
    String? submittedBedId;
    bool? result;

    await _pumpOpener(
      tester,
      initialAction: AppTransferUpdateActions.complete,
      onResult: (bool? value) => result = value,
      onSubmit: ({required String action, String? toBedId}) async {
        submittedAction = action;
        submittedBedId = toBedId;
        return null;
      },
    );

    final Finder fields = find.byType(AppSelectField<String>);
    expect(fields, findsNWidgets(2));
    final AppSelectField<String> bedField =
        tester.widget<AppSelectField<String>>(fields.at(1));
    expect(bedField.labelText, 'Destination bed');
    bedField.onChanged?.call('bed-2');
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(submittedAction, AppTransferUpdateActions.complete);
    expect(submittedBedId, 'bed-2');
  });
}

Future<void> _pumpOpener(
  WidgetTester tester, {
  ValueChanged<bool?>? onResult,
  String initialAction = AppTransferUpdateActions.approve,
  Future<AppFailure?> Function({
    required String action,
    String? toBedId,
  })?
  onSubmit,
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
                  final bool? value = await showAppTransferUpdateDialog(
                    context: context,
                    title: 'Manage transfer',
                    actionLabel: 'Transfer action',
                    destinationBedLabel: 'Destination bed',
                    destinationBedHint: 'Select a bed',
                    submitLabel: 'Edit',
                    requiredMessage: 'Required',
                    initialAction: initialAction,
                    actionOptions: const <AppSelectOption<String>>[
                      AppSelectOption<String>(
                        value: AppTransferUpdateActions.approve,
                        label: 'Approve',
                      ),
                      AppSelectOption<String>(
                        value: AppTransferUpdateActions.start,
                        label: 'Start transfer',
                      ),
                      AppSelectOption<String>(
                        value: AppTransferUpdateActions.complete,
                        label: 'Complete transfer',
                      ),
                      AppSelectOption<String>(
                        value: AppTransferUpdateActions.cancel,
                        label: 'Cancel transfer',
                      ),
                    ],
                    bedOptions: const <AppSelectOption<String>>[
                      AppSelectOption<String>(
                        value: 'bed-1',
                        label: 'Bed 1',
                      ),
                      AppSelectOption<String>(
                        value: 'bed-2',
                        label: 'Bed 2',
                      ),
                    ],
                    onSubmit:
                        onSubmit ??
                        ({required String action, String? toBedId}) async =>
                            null,
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
