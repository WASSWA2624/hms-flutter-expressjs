import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

import '../components/component_test_app.dart';

void main() {
  testWidgets('AppFormShell validates and saves through shared helper', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    String? savedValue;
    var submitted = false;

    await pumpComponent(
      tester,
      AppFormShell(
        formKey: formKey,
        children: <Widget>[
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Required'),
            validator: (String? value) =>
                value == null || value.isEmpty ? 'Required' : null,
            onSaved: (String? value) {
              savedValue = value;
            },
          ),
          AppButton.primary(
            label: 'Submit',
            onPressed: () {
              submitted = validateAndSaveAppForm(formKey);
            },
          ),
        ],
      ),
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(submitted, isFalse);
    expect(savedValue, isNull);
    expect(find.text('Required'), findsWidgets);

    await tester.enterText(find.byType(TextFormField), 'ready');
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(submitted, isTrue);
    expect(savedValue, 'ready');

    controller.dispose();
  });

  testWidgets('AppFormActions prevents duplicate submit while loading', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;
    var cancelCount = 0;

    await pumpComponent(
      tester,
      AppFormActions(
        cancelLabel: 'Cancel',
        submitLabel: 'Save',
        isSubmitting: true,
        onCancel: () {
          cancelCount += 1;
        },
        onSubmit: () {
          submitCount += 1;
        },
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(submitCount, 0);
    expect(cancelCount, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
