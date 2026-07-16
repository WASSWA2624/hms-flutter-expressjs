import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_admission_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import '../../helpers/test_harness.dart';

void main() {
  const ClinicalActionReferenceData referenceData = ClinicalActionReferenceData(
    wards: <ClinicalActionCatalogOption>[
      ClinicalActionCatalogOption(id: 'ward-1', name: 'Medical ward'),
    ],
    rooms: <ClinicalActionCatalogOption>[
      ClinicalActionCatalogOption(
        id: 'room-1',
        name: 'Room 101',
        parentId: 'ward-1',
      ),
    ],
    availableBeds: <ClinicalActionCatalogOption>[
      ClinicalActionCatalogOption(
        id: 'bed-1',
        name: 'Bed A',
        parentId: 'ward-1',
        secondaryId: 'room-1',
        status: 'AVAILABLE',
      ),
    ],
  );

  Future<void> openDialog(
    WidgetTester tester, {
    required Future<AppFailure?> Function(ClinicalActionAdmissionInput input)
    onSubmit,
    bool showCancelButton = true,
    bool initialMaximized = true,
  }) async {
    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open admission dialog',
            onPressed: () {
              showAppDialog<void>(
                context: context,
                builder: (_) => ClinicalAdmissionActionDialog(
                  referenceData: referenceData,
                  reasonLabel: 'Admission reason',
                  reasonRequired: true,
                  notesLabel: 'Notes (optional)',
                  initialMaximized: initialMaximized,
                  showCancelButton: showCancelButton,
                  submitLeadingIcon: Icons.local_hospital_outlined,
                  onSubmit: onSubmit,
                ),
              );
            },
          );
        },
      ),
    );
    await tester.tap(find.text('Open admission dialog'));
    await tester.pumpAndSettle();
  }

  Future<void> selectSearchableOption(
    WidgetTester tester,
    int fieldIndex,
    String optionLabel,
  ) async {
    await tester.tap(find.byType(EditableText).at(fieldIndex));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(MenuItemButton),
            matching: find.textContaining(optionLabel),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens maximized without cancel when configured', (
    WidgetTester tester,
  ) async {
    await openDialog(
      tester,
      onSubmit: (_) async => null,
      showCancelButton: false,
    );

    expect(find.text('Request admission'), findsWidgets);
    expect(find.text('Cancel'), findsNothing);
    expect(find.byIcon(Icons.fullscreen_exit), findsWidgets);
    expect(find.byIcon(Icons.local_hospital_outlined), findsWidgets);
  });

  testWidgets('shows progressive ward room bed summary tiles', (
    WidgetTester tester,
  ) async {
    await openDialog(tester, onSubmit: (_) async => null);

    expect(find.text('Medical ward'), findsNothing);

    await selectSearchableOption(tester, 0, 'Medical ward');
    expect(find.text('Medical ward'), findsWidgets);

    await selectSearchableOption(tester, 1, 'Room 101');
    expect(find.text('Room 101'), findsWidgets);

    await selectSearchableOption(tester, 2, 'Bed A');
    expect(find.text('Bed A'), findsWidgets);
  });

  testWidgets('blocks submit without admission reason', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;
    await openDialog(
      tester,
      onSubmit: (_) async {
        submitCount += 1;
        return null;
      },
    );

    await selectSearchableOption(tester, 0, 'Medical ward');
    await selectSearchableOption(tester, 1, 'Room 101');
    await selectSearchableOption(tester, 2, 'Bed A');
    await tester.tap(find.text('Request admission').last);
    await tester.pumpAndSettle();

    expect(submitCount, 0);
    expect(find.text('This field is required.'), findsWidgets);
  });

  testWidgets('shows helper text when location fields are inactive', (
    WidgetTester tester,
  ) async {
    await openDialog(tester, onSubmit: (_) async => null);

    expect(find.text('Select a ward first.'), findsOneWidget);
    expect(find.text('Select a room first.'), findsOneWidget);
  });

  testWidgets('submits when location and reason are provided', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;
    await openDialog(
      tester,
      showCancelButton: false,
      onSubmit: (_) async {
        submitCount += 1;
        return null;
      },
    );

    await selectSearchableOption(tester, 0, 'Medical ward');
    await selectSearchableOption(tester, 1, 'Room 101');
    await selectSearchableOption(tester, 2, 'Bed A');
    await tester.enterText(find.byType(TextFormField).first, 'Chest pain');
    await tester.tap(find.text('Request admission').last);
    await tester.pumpAndSettle();

    expect(submitCount, 1);
  });

  testWidgets('optional bed mode submits without ward room or bed', (
    WidgetTester tester,
  ) async {
    ClinicalActionAdmissionInput? submitted;
    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open admission dialog',
            onPressed: () {
              showAppDialog<void>(
                context: context,
                builder: (_) => ClinicalAdmissionActionDialog(
                  title: 'Start admission',
                  submitLabel: 'Start admission',
                  referenceData: referenceData,
                  bedRequired: false,
                  initialMaximized: false,
                  submitLeadingIcon: Icons.person_add_alt_1_outlined,
                  onSubmit: (ClinicalActionAdmissionInput input) async {
                    submitted = input;
                    return null;
                  },
                ),
              );
            },
          );
        },
      ),
    );
    await tester.tap(find.text('Open admission dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start admission').last);
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.bed, isNull);
    expect(submitted!.wardId, isNull);
    expect(submitted!.roomId, isNull);
  });
}
