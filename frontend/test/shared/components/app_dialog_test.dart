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

  testWidgets('desktop maximize toggles shell size and icon', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          return TextButton(
            onPressed: () {
              unawaited(
                showAppDialog<void>(
                  context: context,
                  builder: (_) => const AppDialog(
                    maxWidth: 480,
                    title: Text('Large form'),
                    content: SizedBox(
                      width: 320,
                      height: 240,
                      child: Text('Dialog body'),
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open dialog'),
          );
        },
      ),
      size: const Size(1000, 700),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);

    final RenderBox shellBefore = _dialogShellRenderBox(tester);
    final double widthBefore = shellBefore.size.width;
    final double heightBefore = shellBefore.size.height;

    await tester.tap(find.byTooltip('Maximize dialog'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    final RenderBox shellMaximized = _dialogShellRenderBox(tester);
    expect(shellMaximized.size.width, closeTo(1000, 1));
    expect(shellMaximized.size.height, closeTo(700, 1));
    expect(shellMaximized.size.width, greaterThan(widthBefore + 100));
    expect(shellMaximized.size.height, greaterThan(heightBefore + 50));

    await tester.tap(find.byTooltip('Restore dialog'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    final RenderBox shellRestored = _dialogShellRenderBox(tester);
    expect(shellRestored.size.width, closeTo(widthBefore, 2));
    expect(shellRestored.size.height, closeTo(heightBefore, 2));
  });

  testWidgets('desktop corner resize updates shell size', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        maxWidth: 520,
        title: Text('Resize me'),
        content: SizedBox(width: 320, height: 200, child: Text('Dialog body')),
      ),
      size: const Size(1000, 700),
    );

    final RenderBox shellBefore = _dialogShellRenderBox(tester);
    final double widthBefore = shellBefore.size.width;
    final double heightBefore = shellBefore.size.height;

    await tester.drag(find.byIcon(Icons.open_in_full), const Offset(-80, 60));
    await tester.pump();

    final RenderBox shellAfter = _dialogShellRenderBox(tester);
    expect(shellAfter.size.width, lessThan(widthBefore - 40));
    expect(shellAfter.size.height, greaterThan(heightBefore + 40));
  });

  testWidgets('desktop edge resize updates width or height independently', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        maxWidth: 520,
        title: Text('Edge resize'),
        content: SizedBox(width: 320, height: 200, child: Text('Dialog body')),
      ),
      size: const Size(1000, 700),
    );

    final RenderBox shellBefore = _dialogShellRenderBox(tester);
    final double widthBefore = shellBefore.size.width;
    final double heightBefore = shellBefore.size.height;

    await tester.drag(find.byTooltip('Resize width'), const Offset(-120, 0));
    await tester.pump();

    final RenderBox shellAfterWidth = _dialogShellRenderBox(tester);
    expect(shellAfterWidth.size.width, lessThan(widthBefore - 80));
    expect(shellAfterWidth.size.height, closeTo(heightBefore, 4));

    await tester.drag(find.byTooltip('Resize height'), const Offset(0, 80));
    await tester.pump();

    final RenderBox shellAfterHeight = _dialogShellRenderBox(tester);
    expect(shellAfterHeight.size.height, greaterThan(heightBefore + 50));
  });

  testWidgets('two-action footer stays on one row at narrow width', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        title: Text('Filters'),
        content: SizedBox(height: 200, child: Text('Filter body')),
        showMaximizeButton: false,
        resizable: false,
        actions: <Widget>[
          AppButton.tertiary(label: 'Clear filters', onPressed: null),
          AppButton.primary(label: 'Apply filters', onPressed: null),
        ],
      ),
      size: const Size(400, 498),
    );

    final Finder clearAction = find.text('Clear filters');
    final Finder applyAction = find.text('Apply filters');

    expect(clearAction, findsOneWidget);
    expect(applyAction, findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    expect(
      tester.getTopLeft(clearAction).dy,
      tester.getTopLeft(applyAction).dy,
    );
  });
}

RenderBox _dialogShellRenderBox(WidgetTester tester) {
  final Finder sizedBoxes = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(SizedBox),
  );
  return tester.renderObject<RenderBox>(sizedBoxes.first);
}
