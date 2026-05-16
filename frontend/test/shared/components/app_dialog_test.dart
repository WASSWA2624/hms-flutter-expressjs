import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('showAppDialog restores focus to the opener after closing', (
    WidgetTester tester,
  ) async {
    final FocusNode openerFocusNode = FocusNode(debugLabel: 'opener');
    addTearDown(openerFocusNode.dispose);

    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          return TextButton(
            focusNode: openerFocusNode,
            onPressed: () {
              unawaited(
                showAppDialog<void>(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AppDialog(
                      semanticLabel: 'Confirmation dialog',
                      title: const Text('Confirm action'),
                      actions: <Widget>[
                        AppButton.primary(
                          label: 'Close',
                          autofocus: true,
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                      ],
                    );
                  },
                ),
              );
            },
            child: const Text('Open dialog'),
          );
        },
      ),
    );

    openerFocusNode.requestFocus();
    await tester.pump();

    expect(openerFocusNode.hasFocus, isTrue);

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm action'), findsOneWidget);
    expect(openerFocusNode.hasFocus, isFalse);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(openerFocusNode.hasFocus, isTrue);
  });

  testWidgets('AppDialog marks required and optional form fields', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppDialog(
        title: const Text('Edit record'),
        content: Form(
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppTextField(labelText: 'Name', isRequired: true),
              AppTextField(labelText: 'Middle name'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Name *'), findsOneWidget);
    expect(find.text('Middle name (optional)'), findsOneWidget);
  });
}
