import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Rooms/beds `_showTransferUpdateDialog` wires [showAppTransferUpdateDialog]
/// with manage-transfer copy and Edit commit — covered here without pumping
/// the full workspace page.
void main() {
  testWidgets(
    'rooms/beds transfer update opens shared dialog with Edit chrome',
    (WidgetTester tester) async {
      await _pumpRoomsBedsOpener(tester);

      expect(find.byType(AppTransferUpdateDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('MANAGE TRANSFER'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.transfer), findsWidgets);
      expect(find.byIcon(AppActionIcons.edit), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.scrollable, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
    },
  );

  testWidgets('title is role-based and never a patient name', (
    WidgetTester tester,
  ) async {
    await _pumpRoomsBedsOpener(tester);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, isA<Text>());
    expect((dialog.title! as Text).data, 'Manage transfer');
    expect(find.text('JANE DOE'), findsNothing);
    expect(find.text('Jane Doe'), findsNothing);
  });

  testWidgets('Cancel pops false without calling onSubmit', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;
    bool? result;

    await _pumpRoomsBedsOpener(
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

  testWidgets('failure keeps dialog open and does not pop success', (
    WidgetTester tester,
  ) async {
    bool? result;

    await _pumpRoomsBedsOpener(
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

  testWidgets('success pops true after persisted submit', (
    WidgetTester tester,
  ) async {
    String? submittedAction;
    bool? result;

    await _pumpRoomsBedsOpener(
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
}

Future<void> _pumpRoomsBedsOpener(
  WidgetTester tester, {
  ValueChanged<bool?>? onResult,
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
            final AppLocalizations l10n = context.l10n;
            return Center(
              child: AppButton.primary(
                label: 'Open',
                leadingIcon: AppActionIcons.transfer,
                onPressed: () async {
                  final bool? value = await showAppTransferUpdateDialog(
                    context: context,
                    title: l10n.roomsBedsManageTransferAction,
                    actionLabel: l10n.ipdTransferActionFieldLabel,
                    destinationBedLabel: l10n.ipdDestinationBedFieldLabel,
                    destinationBedHint: l10n.ipdSelectBedHint,
                    submitLabel: l10n.patientsEditAction,
                    requiredMessage: l10n.roomsBedsRequiredMessage(
                      l10n.ipdDestinationBedFieldLabel,
                    ),
                    initialAction: appTransferDefaultActionForStatus(
                      'REQUESTED',
                    ),
                    actionOptions: <AppSelectOption<String>>[
                      AppSelectOption<String>(
                        value: AppTransferUpdateActions.approve,
                        label: l10n.ipdTransferApproveAction,
                      ),
                      AppSelectOption<String>(
                        value: AppTransferUpdateActions.start,
                        label: l10n.ipdTransferStartAction,
                      ),
                      AppSelectOption<String>(
                        value: AppTransferUpdateActions.complete,
                        label: l10n.ipdTransferCompleteAction,
                      ),
                      AppSelectOption<String>(
                        value: AppTransferUpdateActions.cancel,
                        label: l10n.ipdTransferCancelAction,
                      ),
                    ],
                    bedOptions: const <AppSelectOption<String>>[
                      AppSelectOption<String>(
                        value: 'bed-2',
                        label: 'Bed 2 | Ward B',
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
