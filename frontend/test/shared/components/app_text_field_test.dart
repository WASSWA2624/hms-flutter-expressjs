import 'package:flutter/material.dart';
import 'package:flutter_template/shared/components/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('AppTextField exposes form validation errors', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await pumpComponent(
      tester,
      Form(
        key: formKey,
        child: Column(
          children: <Widget>[
            AppTextField(
              labelText: 'Name',
              validator: (String? value) {
                return value == null || value.isEmpty ? 'Required' : null;
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

    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('AppTextField supports accessible password visibility toggles', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppTextField(
        labelText: 'Password',
        obscureText: true,
        enableObscureTextToggle: true,
        showObscuredTextLabel: 'Show password',
        hideObscuredTextLabel: 'Hide password',
      ),
    );

    EditableText editableText = tester.widget(find.byType(EditableText));
    expect(editableText.obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    editableText = tester.widget(find.byType(EditableText));
    expect(editableText.obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });
}
