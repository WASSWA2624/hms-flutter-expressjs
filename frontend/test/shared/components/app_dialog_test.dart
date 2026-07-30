import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_dialog_insets.dart';

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

    expect(find.text('CONFIRM ACTION'), findsOneWidget);
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

  testWidgets('AppDialog uppercases dialog header titles', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        title: Text('Lab result entry'),
        content: SizedBox(height: 120, child: Text('Dialog body')),
      ),
    );

    expect(find.text('LAB RESULT ENTRY'), findsOneWidget);
    expect(find.text('Lab result entry'), findsNothing);
  });

  testWidgets('desktop header drag moves the dialog surface', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        initialMaximized: false,
        title: Text('Move encounter'),
        content: SizedBox(width: 320, height: 160, child: Text('Dialog body')),
      ),
      size: const Size(1000, 700),
    );

    final Finder dialog = find.byType(Dialog);
    final Offset dialogBefore = tester.getTopLeft(dialog);
    final Offset titleBefore = tester.getTopLeft(find.text('MOVE ENCOUNTER'));

    await tester.drag(find.text('MOVE ENCOUNTER'), const Offset(80, 40));
    await tester.pump();

    expect(tester.getTopLeft(dialog).dx, closeTo(dialogBefore.dx + 80, 1));
    expect(tester.getTopLeft(dialog).dy, closeTo(dialogBefore.dy + 40, 1));
    expect(
      tester.getTopLeft(find.text('MOVE ENCOUNTER')).dx,
      closeTo(titleBefore.dx + 80, 1),
    );
    expect(
      tester.getTopLeft(find.text('MOVE ENCOUNTER')).dy,
      closeTo(titleBefore.dy + 40, 1),
    );
  });

  testWidgets('desktop maximize toggles shell size and icon', (
    WidgetTester tester,
  ) async {
    const Size viewport = Size(1000, 700);
    const AppDesignTokens designTokens = AppDesignTokens.standard;
    final Size expectedMaximizedSize = AppDialogInsets.availableSizeFor(
      viewport,
      AppBreakpoint.lg,
      designTokens: designTokens,
      maximized: true,
    );

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
                    initialMaximized: false,
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
      size: viewport,
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
    expect(shellMaximized.size.width, closeTo(expectedMaximizedSize.width, 1));
    expect(
      shellMaximized.size.height,
      closeTo(expectedMaximizedSize.height, 1),
    );
    expect(shellMaximized.size.width, greaterThan(widthBefore + 100));
    expect(shellMaximized.size.height, greaterThan(heightBefore + 50));

    await tester.tap(find.byTooltip('Restore dialog'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    final RenderBox shellRestored = _dialogShellRenderBox(tester);
    expect(shellRestored.size.width, closeTo(widthBefore, 2));
    expect(shellRestored.size.height, closeTo(heightBefore, 2));
  });

  testWidgets('desktop AppDialog opens maximized by default', (
    WidgetTester tester,
  ) async {
    const Size viewport = Size(1000, 700);
    const AppDesignTokens designTokens = AppDesignTokens.standard;
    final Size expectedMaximizedSize = AppDialogInsets.availableSizeFor(
      viewport,
      AppBreakpoint.lg,
      designTokens: designTokens,
      maximized: true,
    );

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
                    title: Text('Default maximized'),
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
      size: viewport,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    final RenderBox shell = _dialogShellRenderBox(tester);
    expect(shell.size.width, closeTo(expectedMaximizedSize.width, 1));
    expect(shell.size.height, closeTo(expectedMaximizedSize.height, 1));
  });

  testWidgets('desktop AppDialog respects initialMaximized false opt-out', (
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
                    initialMaximized: false,
                    maxWidth: 480,
                    title: Text('Compact dialog'),
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
    expect(find.byIcon(Icons.fullscreen_exit), findsNothing);
  });

  testWidgets(
    'desktop scrollable non-maximized dialog renders visible shell height',
    (WidgetTester tester) async {
      const Size viewport = Size(1000, 700);
      const AppDesignTokens designTokens = AppDesignTokens.standard;
      final double inset = designTokens.dialogInsetTablet;
      final double maxHeight =
          viewport.height - (inset * 2) - designTokens.dialogSnackBarClearance;
      final double expectedHeight = (maxHeight * 0.75).clamp(
        designTokens.dialogMinHeight,
        maxHeight,
      );

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
                      initialMaximized: false,
                      scrollable: true,
                      maxWidth: 1080,
                      title: Text('Catalog and stock'),
                      content: SizedBox(
                        height: 240,
                        child: Text('Catalog body'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open dialog'),
            );
          },
        ),
        size: viewport,
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('CATALOG AND STOCK'), findsOneWidget);
      expect(find.text('Catalog body'), findsOneWidget);

      final RenderBox shell = _dialogShellRenderBox(tester);
      expect(shell.size.height, closeTo(expectedHeight, 2));
      expect(shell.size.height, greaterThan(designTokens.dialogMinHeight));
    },
  );

  testWidgets(
    'maximized dialog fills viewport on mobile and workspace on tablet',
    (WidgetTester tester) async {
      const AppDesignTokens designTokens = AppDesignTokens.standard;

      for (final ({Size viewport, AppBreakpoint breakpoint, bool fillsViewport})
          config
          in <({Size viewport, AppBreakpoint breakpoint, bool fillsViewport})>[
            (
              viewport: const Size(400, 700),
              breakpoint: AppBreakpoint.sm,
              fillsViewport: true,
            ),
            (
              viewport: const Size(800, 700),
              breakpoint: AppBreakpoint.md,
              fillsViewport: false,
            ),
          ]) {
        final Size expectedMaximizedSize = AppDialogInsets.availableSizeFor(
          config.viewport,
          config.breakpoint,
          designTokens: designTokens,
          maximized: true,
        );

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
                        title: Text('Maximized form'),
                        content: SizedBox(
                          height: 120,
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
          size: config.viewport,
        );

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();

        final RenderBox shell = _dialogShellRenderBox(tester);
        expect(shell.size.width, closeTo(expectedMaximizedSize.width, 1));
        expect(shell.size.height, closeTo(expectedMaximizedSize.height, 1));
        if (config.fillsViewport) {
          expect(shell.size.width, closeTo(config.viewport.width, 1));
          expect(shell.size.height, closeTo(config.viewport.height, 1));
        } else {
          expect(shell.size.height, lessThan(config.viewport.height));
        }

        await tester.binding.setSurfaceSize(null);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets('desktop corner resize updates shell size', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        initialMaximized: false,
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
        initialMaximized: false,
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

  testWidgets('mobile AppDialog stacks footer actions full width', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppDialog(
        title: const Text('Lab result entry'),
        content: const Text('Body'),
        pinActionsToBottom: true,
        actions: <Widget>[
          AppButton.secondary(
            label: 'Preview report',
            fullWidth: true,
            onPressed: () {},
          ),
          AppButton.primary(
            label: 'Save results',
            fullWidth: true,
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(390, 844),
    );

    final Offset preview = tester.getCenter(find.text('Preview report'));
    final Offset save = tester.getCenter(find.text('Save results'));
    expect(save.dy, greaterThan(preview.dy));
  });
}

RenderBox _dialogShellRenderBox(WidgetTester tester) {
  return tester.renderObject<RenderBox>(find.byKey(AppDialog.shellKey));
}
