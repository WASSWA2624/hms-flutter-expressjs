import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';
import 'package:hosspi_hms/shared/components/app_triage_components.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

import '../../helpers/test_harness.dart';
import 'component_test_app.dart';

void main() {
  testWidgets(
    'showAppTriageActionDialog uses AppDialog chrome with muted dismiss',
    (WidgetTester tester) async {
      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open',
              leadingIcon: Icons.monitor_heart_outlined,
              onPressed: () {
                unawaited(
                  showAppTriageActionDialog<bool>(
                    context: context,
                    builder: (_) => AppTriageActionDialog(
                      title: 'Record triage',
                      semanticLabel: 'Record triage assessment',
                      submitLabel: 'Save triage',
                      requiredMessage: 'Required',
                      triageLevelLabel: 'Triage level',
                      triageLevelOptions: const <AppTriageOption>[
                        AppTriageOption(value: 'LEVEL_1', label: 'Level 1'),
                        AppTriageOption(value: 'LEVEL_2', label: 'Level 2'),
                      ],
                      initialTriageLevel: 'LEVEL_2',
                      notesLabel: 'Triage notes',
                      onSubmit: (_) async => null,
                    ),
                  ),
                );
              },
            );
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AppTriageActionDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('RECORD TRIAGE'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save triage'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.save), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
      expect(find.byIcon(Icons.monitor_heart_outlined), findsWidgets);
      expect(find.text('Jane Doe'), findsNothing);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
      expect(dialog.semanticLabel, 'Record triage assessment');
    },
  );

  testWidgets('Cancel pops without invoking onSubmit', (
    WidgetTester tester,
  ) async {
    var submitted = false;

    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open',
            leadingIcon: Icons.monitor_heart_outlined,
            onPressed: () {
              unawaited(
                showAppTriageActionDialog<bool>(
                  context: context,
                  builder: (_) => AppTriageActionDialog(
                    title: 'Record triage',
                    submitLabel: 'Save triage',
                    requiredMessage: 'Required',
                    triageLevelLabel: 'Triage level',
                    triageLevelOptions: const <AppTriageOption>[
                      AppTriageOption(value: 'LEVEL_2', label: 'Level 2'),
                    ],
                    notesLabel: 'Triage notes',
                    onSubmit: (_) async {
                      submitted = true;
                      return null;
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Should not save');
    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(submitted, isFalse);
    expect(find.byType(AppTriageActionDialog), findsNothing);
  });

  testWidgets(
    'failure keeps dialog open, preserves notes, and re-enables actions',
    (WidgetTester tester) async {
      final Completer<AppFailure?> completer = Completer<AppFailure?>();
      AppTriageActionInput? submitted;

      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open',
              leadingIcon: Icons.monitor_heart_outlined,
              onPressed: () {
                unawaited(
                  showAppTriageActionDialog<bool>(
                    context: context,
                    builder: (_) => AppTriageActionDialog(
                      title: 'Record triage',
                      submitLabel: 'Save triage',
                      requiredMessage: 'Required',
                      triageLevelLabel: 'Triage level',
                      triageLevelOptions: const <AppTriageOption>[
                        AppTriageOption(value: 'LEVEL_2', label: 'Level 2'),
                      ],
                      initialTriageLevel: 'LEVEL_2',
                      notesLabel: 'Triage notes',
                      initialNotes: 'Draft note',
                      onSubmit: (AppTriageActionInput input) {
                        submitted = input;
                        return completer.future;
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
        size: const Size(390, 700),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText), 'Chest pain');
      await tester.tap(find.widgetWithText(AppButton, 'Save triage'));
      await tester.pump();

      expect(submitted?.notes, 'Chest pain');
      expect(_button(tester, 'Cancel').enabled, isFalse);
      expect(_button(tester, 'Save triage').isLoading, isTrue);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isFalse);

      completer.complete(const AppFailure.network());
      await tester.pumpAndSettle();

      expect(find.byType(AppTriageActionDialog), findsOneWidget);
      expect(find.text('Chest pain'), findsOneWidget);
      expect(_button(tester, 'Cancel').enabled, isTrue);
      expect(find.byType(AppFormInformationBanner), findsOneWidget);
    },
  );

  testWidgets('success closes the dialog after onSubmit returns null', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open',
            leadingIcon: Icons.monitor_heart_outlined,
            onPressed: () {
              unawaited(
                showAppTriageActionDialog<bool>(
                  context: context,
                  builder: (_) => AppTriageActionDialog(
                    title: 'Record triage',
                    submitLabel: 'Save triage',
                    requiredMessage: 'Required',
                    triageLevelLabel: 'Triage level',
                    triageLevelOptions: const <AppTriageOption>[
                      AppTriageOption(value: 'LEVEL_2', label: 'Level 2'),
                    ],
                    initialTriageLevel: 'LEVEL_2',
                    onSubmit: (_) async => null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Save triage'));
    await tester.pumpAndSettle();

    expect(find.byType(AppTriageActionDialog), findsNothing);
  });

  testWidgets('parent isBusy disables close and footer actions', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppTriageActionDialog(
        title: 'Record triage',
        submitLabel: 'Save triage',
        requiredMessage: 'Required',
        triageLevelLabel: 'Triage level',
        triageLevelOptions: const <AppTriageOption>[
          AppTriageOption(value: 'LEVEL_2', label: 'Level 2'),
        ],
        isBusy: true,
        onSubmit: (_) async {
          fail('onSubmit should not be called while busy');
          return null;
        },
      ),
    );

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isFalse);
    expect(_button(tester, 'Cancel').enabled, isFalse);
    expect(_button(tester, 'Save triage').enabled, isFalse);
  });

  testWidgets('vitals section uses localized label defaults', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppTriageActionDialog(
        title: 'Record triage',
        submitLabel: 'Save triage',
        requiredMessage: 'Required',
        triageLevelLabel: 'Triage level',
        triageLevelOptions: const <AppTriageOption>[
          AppTriageOption(value: 'LEVEL_2', label: 'Level 2'),
        ],
        vitalsSectionTitle: 'Vitals',
        onSubmit: (_) async => null,
      ),
      size: const Size(900, 900),
    );

    expect(find.text('Temperature'), findsWidgets);
    expect(find.text('Heart rate'), findsWidgets);
    expect(find.text('Oxygen saturation'), findsWidgets);
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return Theme(
            data: Theme.of(context).copyWith(brightness: Brightness.dark),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: AppButton.primary(
                label: 'Open',
                leadingIcon: Icons.monitor_heart_outlined,
                onPressed: () {
                  unawaited(
                    showAppTriageActionDialog<bool>(
                      context: context,
                      builder: (_) => AppTriageActionDialog(
                        title: 'Record triage',
                        submitLabel: 'Save triage',
                        requiredMessage: 'Required',
                        triageLevelLabel: 'Triage level',
                        triageLevelOptions: const <AppTriageOption>[
                          AppTriageOption(value: 'LEVEL_2', label: 'Level 2'),
                        ],
                        notesLabel: 'Triage notes',
                        onSubmit: (_) async => null,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      size: const Size(320, 568),
      padding: EdgeInsets.zero,
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('RECORD TRIAGE'), findsOneWidget);
    expect(find.text('Save triage'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}

AppButton _button(WidgetTester tester, String label) {
  return tester.widget<AppButton>(
    find.byWidgetPredicate(
      (Widget widget) => widget is AppButton && widget.label == label,
    ),
  );
}
