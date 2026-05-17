import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('AppSelectField participates in form validation', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await pumpComponent(
      tester,
      Form(
        key: formKey,
        child: Column(
          children: <Widget>[
            AppSelectField<String>(
              labelText: 'Status',
              options: const <AppSelectOption<String>>[
                AppSelectOption<String>(value: 'draft', label: 'Draft'),
                AppSelectOption<String>(value: 'live', label: 'Live'),
              ],
              onChanged: (_) {},
              validator: (String? value) {
                return value == null ? 'Choose a status' : null;
              },
            ),
            AppButton.primary(
              label: 'Submit',
              onPressed: () {
                formKey.currentState!.validate();
              },
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('Choose a status'), findsOneWidget);
  });

  testWidgets('AppSelectField opens a non-searchable menu without filtering', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppSelectField<String>(
        labelText: 'Status',
        options: const <AppSelectOption<String>>[
          AppSelectOption<String>(value: 'draft', label: 'Draft'),
          AppSelectOption<String>(value: 'live', label: 'Live'),
        ],
        onChanged: (_) {},
      ),
    );

    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Draft').hitTestable(), findsOneWidget);
    expect(find.text('Live').hitTestable(), findsOneWidget);
  });

  testWidgets('AppSelectField.searchable filters options in the menu overlay', (
    WidgetTester tester,
  ) async {
    String? selected;

    await pumpComponent(
      tester,
      AppSelectField<String>.searchable(
        labelText: 'Status',
        options: const <AppSelectOption<String>>[
          AppSelectOption<String>(value: 'draft', label: 'Draft'),
          AppSelectOption<String>(value: 'live', label: 'Live'),
        ],
        onChanged: (String? value) {
          selected = value;
        },
      ),
    );

    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'liv');
    await tester.pumpAndSettle();

    expect(find.text('Draft').hitTestable(), findsNothing);
    expect(find.text('Live').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Live').hitTestable());
    await tester.pumpAndSettle();

    expect(selected, 'live');
  });

  testWidgets('AppSelectField clear button clears the selected value', (
    WidgetTester tester,
  ) async {
    String? selected = 'live';

    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AppSelectField<String>(
            labelText: 'Status',
            value: selected,
            options: const <AppSelectOption<String>>[
              AppSelectOption<String>(value: 'draft', label: 'Draft'),
              AppSelectOption<String>(value: 'live', label: 'Live'),
            ],
            onChanged: (String? value) {
              setState(() {
                selected = value;
              });
            },
          );
        },
      ),
    );

    expect(find.text('Live'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    final EditableText editableText = tester.widget(find.byType(EditableText));
    expect(selected, isNull);
    expect(editableText.controller.text, isEmpty);
  });

  testWidgets(
    'AppSelectField saves a selection without an onChanged callback',
    (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      String? savedValue;

      await pumpComponent(
        tester,
        Form(
          key: formKey,
          child: Column(
            children: <Widget>[
              AppSelectField<String>(
                labelText: 'Status',
                options: const <AppSelectOption<String>>[
                  AppSelectOption<String>(value: 'draft', label: 'Draft'),
                  AppSelectOption<String>(value: 'live', label: 'Live'),
                ],
                onSaved: (String? value) {
                  savedValue = value;
                },
              ),
              AppButton.primary(
                label: 'Save',
                onPressed: () {
                  formKey.currentState!.save();
                },
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Live').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(savedValue, 'live');
    },
  );

  testWidgets('AppRadioGroup changes the selected value', (
    WidgetTester tester,
  ) async {
    String? selected;

    await pumpComponent(
      tester,
      AppRadioGroup<String>(
        labelText: 'Plan',
        value: selected,
        options: const <AppRadioOption<String>>[
          AppRadioOption<String>(value: 'basic', label: 'Basic'),
          AppRadioOption<String>(value: 'pro', label: 'Pro'),
        ],
        onChanged: (String? value) {
          selected = value;
        },
      ),
    );

    await tester.tap(find.text('Pro'));
    await tester.pump();

    expect(selected, 'pro');
  });

  testWidgets('AppRadioGroup saves a selection without an onChanged callback', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    String? savedValue;

    await pumpComponent(
      tester,
      Form(
        key: formKey,
        child: Column(
          children: <Widget>[
            AppRadioGroup<String>(
              labelText: 'Plan',
              options: const <AppRadioOption<String>>[
                AppRadioOption<String>(value: 'basic', label: 'Basic'),
                AppRadioOption<String>(value: 'pro', label: 'Pro'),
              ],
              onSaved: (String? value) {
                savedValue = value;
              },
            ),
            AppButton.primary(
              label: 'Save',
              onPressed: () {
                formKey.currentState!.save();
              },
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Pro'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(savedValue, 'pro');
  });

  testWidgets('AppCheckboxField updates through the shared form wrapper', (
    WidgetTester tester,
  ) async {
    var accepted = false;

    await pumpComponent(
      tester,
      AppCheckboxField(
        title: 'Accept terms',
        value: accepted,
        onChanged: (bool value) {
          accepted = value;
        },
      ),
    );

    await tester.tap(find.text('Accept terms'));
    await tester.pump();

    expect(accepted, isTrue);
  });

  testWidgets('AppCheckboxField saves a value without an onChanged callback', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    bool? savedValue;

    await pumpComponent(
      tester,
      Form(
        key: formKey,
        child: Column(
          children: <Widget>[
            AppCheckboxField(
              title: 'Accept terms',
              value: false,
              onSaved: (bool? value) {
                savedValue = value;
              },
            ),
            AppButton.primary(
              label: 'Save',
              onPressed: () {
                formKey.currentState!.save();
              },
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Accept terms'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(savedValue, isTrue);
  });

  testWidgets('AppSwitchField updates through the shared form wrapper', (
    WidgetTester tester,
  ) async {
    var enabled = false;

    await pumpComponent(
      tester,
      AppSwitchField(
        title: 'Enable alerts',
        value: enabled,
        onChanged: (bool value) {
          enabled = value;
        },
      ),
    );

    await tester.tap(find.text('Enable alerts'));
    await tester.pump();

    expect(enabled, isTrue);
  });

  testWidgets('AppSwitchField saves a value without an onChanged callback', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    bool? savedValue;

    await pumpComponent(
      tester,
      Form(
        key: formKey,
        child: Column(
          children: <Widget>[
            AppSwitchField(
              title: 'Enable alerts',
              value: false,
              onSaved: (bool? value) {
                savedValue = value;
              },
            ),
            AppButton.primary(
              label: 'Save',
              onPressed: () {
                formKey.currentState!.save();
              },
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Enable alerts'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(savedValue, isTrue);
  });

  testWidgets('AppDateField formats the selected date for manual entry', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppDateField(
        value: DateTime(2026, 5, 13),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        pickerButtonLabel: 'Open date picker',
        invalidDateMessage: 'Enter a valid date.',
        onChanged: (_) {},
      ),
    );

    final List<EditableText> fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList(growable: false);

    expect(
      fields.map((EditableText field) => field.controller.text),
      containsAllInOrder(<String>['13', '05', '2026']),
    );
  });

  testWidgets('AppDateField remains enabled without an onChanged callback', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppDateField(
        value: DateTime(2026, 5, 13),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        pickerButtonLabel: 'Open date picker',
        invalidDateMessage: 'Enter a valid date.',
      ),
    );

    final Iterable<TextField> textFields = tester.widgetList<TextField>(
      find.byType(TextField),
    );
    final IconButton pickerButton = tester.widget(find.byType(IconButton));

    expect(
      textFields.every((TextField field) => field.enabled ?? false),
      isTrue,
    );
    expect(pickerButton.onPressed, isNotNull);
  });

  testWidgets('AppDateField emits dates from editable parts', (
    WidgetTester tester,
  ) async {
    DateTime? selectedDate;

    await pumpComponent(
      tester,
      AppDateField(
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        pickerButtonLabel: 'Open date picker',
        invalidDateMessage: 'Enter a valid date.',
        hintText: 'DD/MM/YYYY',
        onChanged: (DateTime? value) {
          selectedDate = value;
        },
      ),
    );

    final Finder textFields = find.byType(TextField);

    await tester.enterText(textFields.at(0), '17');
    await tester.enterText(textFields.at(1), '08');
    await tester.enterText(textFields.at(2), '2023');
    await tester.pump();

    expect(selectedDate, DateTime(2023, 8, 17));
  });

  testWidgets('AppDateField date picker syncs the editable parts', (
    WidgetTester tester,
  ) async {
    DateTime? selectedDate;

    await pumpComponent(
      tester,
      AppDateField(
        value: DateTime(2026, 5, 13),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        pickerButtonLabel: 'Open date picker',
        invalidDateMessage: 'Enter a valid date.',
        onChanged: (DateTime? value) {
          selectedDate = value;
        },
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final List<EditableText> fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList(growable: false);

    expect(selectedDate, DateTime(2026, 5, 14));
    expect(
      fields.map((EditableText field) => field.controller.text),
      containsAllInOrder(<String>['14', '05', '2026']),
    );
  });

  testWidgets('AppDateField validates constrained manual dates', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await pumpComponent(
      tester,
      Form(
        key: formKey,
        child: AppDateField(
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          pickerButtonLabel: 'Open date picker',
          invalidDateMessage: 'Enter a valid date.',
          hintText: 'DD/MM/YYYY',
          selectableDayPredicate: (DateTime date) {
            return date.weekday != DateTime.saturday;
          },
        ),
      ),
    );

    final Finder textFields = find.byType(TextField);

    await tester.enterText(textFields.at(0), '31');
    await tester.enterText(textFields.at(1), '02');
    await tester.enterText(textFields.at(2), '2026');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Enter a valid date.'), findsOneWidget);

    await tester.enterText(textFields.at(0), '29');
    await tester.enterText(textFields.at(1), '02');
    await tester.enterText(textFields.at(2), '2024');
    expect(formKey.currentState!.validate(), isTrue);
    await tester.pump();
    expect(find.text('Enter a valid date.'), findsNothing);

    await tester.enterText(textFields.at(0), '19');
    await tester.enterText(textFields.at(1), '08');
    await tester.enterText(textFields.at(2), '2023');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Enter a valid date.'), findsOneWidget);
  });

  testWidgets('AppDateField picker uses nearest selectable date', (
    WidgetTester tester,
  ) async {
    DateTime? selectedDate;

    await pumpComponent(
      tester,
      AppDateField(
        value: DateTime(2026, 5, 13),
        firstDate: DateTime(2026, 5),
        lastDate: DateTime(2026, 5, 31),
        pickerButtonLabel: 'Open date picker',
        invalidDateMessage: 'Enter a valid date.',
        selectableDayPredicate: (DateTime date) => date.day != 13,
        onChanged: (DateTime? value) {
          selectedDate = value;
        },
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(selectedDate, DateTime(2026, 5, 14));
  });

  testWidgets('AppDateField fits compact widths', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      AppDateField(
        value: DateTime(2026, 5, 13),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        labelText: 'Date',
        pickerButtonLabel: 'Open date picker',
        invalidDateMessage: 'Enter a valid date.',
        hintText: 'DD/MM/YYYY',
        onChanged: (_) {},
      ),
      size: const Size(240, 320),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('AppPhoneField composes one international phone value', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();

    await pumpComponent(
      tester,
      AppPhoneField(
        controller: controller,
        labelText: 'Phone',
        countryLabelText: 'Country code',
        countrySearchLabelText: 'Search country',
        countryNoResultsText: 'No countries found',
        numberLabelText: 'Phone number',
        numberHintText: 'Remaining number digits',
        invalidPhoneMessage: 'Enter a valid phone number.',
      ),
    );

    expect(find.text('+256'), findsOneWidget);
    expect(find.text('Remaining number digits'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '700000000');
    await tester.pump();

    expect(controller.text, '+256700000000');
  });

  testWidgets('AppPhoneField normalizes national prefixes', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();

    await pumpComponent(
      tester,
      AppPhoneField(
        controller: controller,
        labelText: 'Phone',
        countryLabelText: 'Country code',
        countrySearchLabelText: 'Search country',
        countryNoResultsText: 'No countries found',
        numberLabelText: 'Phone number',
        numberHintText: 'Remaining number digits',
        invalidPhoneMessage: 'Enter a valid phone number.',
      ),
    );

    await tester.enterText(find.byType(EditableText), '0700000000');
    await tester.pump();

    expect(controller.text, '+256700000000');
  });

  testWidgets('AppPhoneField picker searches by country code and name', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();

    await pumpComponent(
      tester,
      AppPhoneField(
        controller: controller,
        labelText: 'Phone',
        countryLabelText: 'Country code',
        countrySearchLabelText: 'Search country',
        countryNoResultsText: 'No countries found',
        numberLabelText: 'Phone number',
        numberHintText: 'Remaining number digits',
        invalidPhoneMessage: 'Enter a valid phone number.',
      ),
    );

    await tester.tap(find.text('+256'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, '256');
    await tester.pumpAndSettle();

    expect(find.text('Uganda'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).last, 'United States');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'United States'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'United States'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '2025550119');
    await tester.pump();

    expect(controller.text, '+12025550119');
  });

  testWidgets('AppPhoneField rejects invalid national digits', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();

    await pumpComponent(
      tester,
      Form(
        key: formKey,
        child: Column(
          children: <Widget>[
            AppPhoneField(
              controller: controller,
              labelText: 'Phone',
              countryLabelText: 'Country code',
              countrySearchLabelText: 'Search country',
              countryNoResultsText: 'No countries found',
              numberLabelText: 'Phone number',
              numberHintText: 'Remaining number digits',
              invalidPhoneMessage: 'Enter a valid phone number.',
            ),
            AppButton.primary(
              label: 'Submit',
              onPressed: () {
                formKey.currentState!.validate();
              },
            ),
          ],
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText), '123');
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('Enter a valid phone number.'), findsOneWidget);
  });
}
