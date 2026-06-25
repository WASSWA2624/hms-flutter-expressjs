import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  testWidgets(
    'copies the visible identifier value and shows success feedback',
    (WidgetTester tester) async {
      final List<String> copiedValues = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final arguments = Map<Object?, Object?>.from(
              methodCall.arguments as Map,
            );
            copiedValues.add(arguments['text']! as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpComponent(
        tester,
        const AppCopyableIdentifier(
          value: ' PAT-2026-0001 ',
          copiedMessage: 'Patient ID copied.',
        ),
      );

      await tester.tap(find.text('PAT-2026-0001'));
      await tester.pump();

      expect(copiedValues, <String>['PAT-2026-0001']);
      expect(find.text('Patient ID copied.'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );

  testWidgets('does not copy placeholder identifier values', (
    WidgetTester tester,
  ) async {
    var copied = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          copied = true;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpComponent(tester, const AppCopyableIdentifier(value: 'N/A'));

    expect(find.text('N/A'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsNothing);
    await tester.tap(find.text('N/A'), warnIfMissed: false);
    await tester.pump();

    expect(copied, isFalse);
  });
}
