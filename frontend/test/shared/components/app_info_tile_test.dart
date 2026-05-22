import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('AppInfoTile copies identifier values when opted in', (
    WidgetTester tester,
  ) async {
    final List<String> copiedValues = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          final arguments = Map<Object?, Object?>.from(methodCall.arguments as Map);
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
      const AppInfoTile(
        label: 'Encounter ID',
        value: 'OPD-2026-0007',
        copyable: true,
        copiedMessage: 'Encounter ID copied.',
      ),
    );

    expect(find.text('Encounter ID'), findsOneWidget);
    await tester.tap(find.text('OPD-2026-0007'));
    await tester.pump();

    expect(copiedValues, <String>['OPD-2026-0007']);
    expect(find.text('Encounter ID copied.'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('AppInfoTileGrid keeps non-copyable tiles unchanged', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppInfoTileGrid(
        items: <AppInfoTileData>[
          AppInfoTileData(label: 'Ward', value: 'Ward A'),
          AppInfoTileData(label: 'Admission ID', value: 'ADM-100', copyable: true),
        ],
      ),
    );

    expect(find.text('Ward A'), findsOneWidget);
    expect(find.text('ADM-100'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
  });
}
