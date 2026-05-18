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
      const AppDialog(
        title: Text('Edit record'),
        content: Form(
          child: Column(
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

  testWidgets('desktop header drag moves the dialog surface', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        title: Text('Move encounter'),
        content: SizedBox(width: 320, height: 160, child: Text('Dialog body')),
      ),
      size: const Size(1000, 700),
    );

    final Finder dialog = find.byType(Dialog);
    final Offset dialogBefore = tester.getTopLeft(dialog);
    final Offset titleBefore = tester.getTopLeft(find.text('Move encounter'));

    await tester.drag(find.text('Move encounter'), const Offset(80, 40));
    await tester.pump();

    expect(tester.getTopLeft(dialog).dx, closeTo(dialogBefore.dx + 80, 1));
    expect(tester.getTopLeft(dialog).dy, closeTo(dialogBefore.dy + 40, 1));
    expect(
      tester.getTopLeft(find.text('Move encounter')).dx,
      closeTo(titleBefore.dx + 80, 1),
    );
    expect(
      tester.getTopLeft(find.text('Move encounter')).dy,
      closeTo(titleBefore.dy + 40, 1),
    );
  });
}
