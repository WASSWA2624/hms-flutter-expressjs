import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_dialog_insets.dart';

import 'component_test_app.dart';

void main() {
  testWidgets(
    'showAppDialog dismisses only via close or Escape, not barrier tap',
    (WidgetTester tester) async {
      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () {
                unawaited(
                  showAppDialog<void>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return const AppDialog(
                        title: Text('Confirm action'),
                        content: SizedBox(height: 80, child: Text('Body')),
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

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(
        tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .any((ModalBarrier barrier) => barrier.dismissible),
        isFalse,
      );

      await tester.tapAt(Offset.zero);
      await tester.pump();
      expect(find.byType(AppDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
    },
  );

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
      // lg+ so footer action labels remain visible for the tap assertion.
      size: const Size(1000, 700),
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
    // Width-only resize can nudge measured height slightly when chrome/buttons
    // reflow; keep the bound tight enough to catch real height coupling.
    expect(shellAfterWidth.size.height, closeTo(heightBefore, 12));

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
          AppButton.tertiary(
            label: 'Clear',
            leadingIcon: Icons.filter_alt_off_outlined,
            onPressed: null,
          ),
          AppButton.primary(
            label: 'Apply',
            leadingIcon: Icons.check,
            onPressed: null,
          ),
        ],
      ),
      size: const Size(400, 498),
    );

    // Footer actions stay labeled at every breakpoint.
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Close'), findsNothing);

    final Offset clearAction = tester.getCenter(find.text('Clear'));
    final Offset applyAction = tester.getCenter(find.text('Apply'));
    expect(clearAction.dy, closeTo(applyAction.dy, 1));
    expect(clearAction.dx, greaterThan(applyAction.dx));
  });

  testWidgets(
    'mobile AppDialog keeps footer actions horizontal, labeled, and iconed',
    (WidgetTester tester) async {
      await pumpComponent(
        tester,
        AppDialog(
          title: const Text('Lab result entry'),
          content: const Text('Body'),
          pinActionsToBottom: true,
          // Short labels: the test font renders every glyph at the full font
          // size, so label widths here run far wider than production text.
          actions: <Widget>[
            AppButton.secondary(
              label: 'Preview',
              leadingIcon: Icons.visibility_outlined,
              onPressed: () {},
            ),
            AppButton.primary(
              label: 'Save',
              leadingIcon: Icons.save_outlined,
              onPressed: () {},
            ),
          ],
        ),
        size: const Size(390, 844),
      );

      // Icon *and* label on phones, not icon-only.
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.save_outlined), findsOneWidget);

      final Offset preview = tester.getCenter(find.text('Preview'));
      final Offset save = tester.getCenter(find.text('Save'));
      expect(preview.dy, closeTo(save.dy, 1));
      expect(preview.dx, greaterThan(save.dx));
    },
  );

  testWidgets('mobile AppDialog can opt into stacked footer actions', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppDialog(
        title: const Text('Lab result entry'),
        content: const Text('Body'),
        pinActionsToBottom: true,
        stackActionsWhenCompact: true,
        actions: <Widget>[
          AppButton.secondary(
            label: 'Preview report',
            leadingIcon: Icons.visibility_outlined,
            fullWidth: true,
            onPressed: () {},
          ),
          AppButton.primary(
            label: 'Save results',
            leadingIcon: Icons.save_outlined,
            fullWidth: true,
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(390, 844),
    );

    final Offset preview = tester.getCenter(find.text('Preview report'));
    final Offset save = tester.getCenter(find.text('Save results'));
    // Source [secondary, primary] is reversed so primary is top / left and
    // secondary (dismiss) is bottom / extreme-right.
    expect(preview.dy, greaterThan(save.dy));
  });

  testWidgets('scrollable dialog puts body padding on the scroll view', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        scrollable: true,
        title: Text('Scroll body'),
        content: SizedBox(height: 800, child: Text('Tall sections')),
      ),
      size: const Size(1000, 700),
    );

    final SingleChildScrollView scrollView = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(scrollView.padding, isNot(EdgeInsets.zero));
    expect(find.byType(Scrollbar), findsWidgets);

    // Scroll padding should own the body inset (no outer Padding wrapping the
    // scroller), so the gutter sits outside section content.
    final Finder paddedScroller = find.ancestor(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Padding),
    );
    expect(
      paddedScroller.evaluate().where((Element element) {
        final Padding padding = element.widget as Padding;
        return padding.child is SingleChildScrollView ||
            padding.child is Scrollbar;
      }),
      isEmpty,
    );
  });

  testWidgets('nested AppDialogs use distinct shell keys', (
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
                  builder: (BuildContext outerContext) {
                    return AppDialog(
                      title: const Text('Outer'),
                      content: const SizedBox(
                        height: 40,
                        child: Text('Outer body'),
                      ),
                      actions: <Widget>[
                        AppButton.primary(
                          label: 'Open nested',
                          onPressed: () {
                            unawaited(
                              showAppDialog<void>(
                                context: outerContext,
                                builder: (_) => const AppDialog(
                                  title: Text('Inner'),
                                  content: SizedBox(
                                    height: 40,
                                    child: Text('Inner body'),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              );
            },
            child: const Text('Open'),
          );
        },
      ),
      size: const Size(1200, 900),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('OUTER'), findsOneWidget);

    await tester.tap(find.text('Open nested'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNWidgets(2));
    expect(find.text('INNER'), findsOneWidget);

    final Finder shells = find.byWidgetPredicate(
      (Widget w) => AppDialog.isShellKey(w.key),
    );
    expect(shells, findsNWidgets(2));
    final List<Key?> keys = shells
        .evaluate()
        .map((Element e) => e.widget.key)
        .toList(growable: false);
    expect(keys[0], isNot(equals(keys[1])));
  });

  testWidgets('mobile header dismisses with a leading back arrow, no close X', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        title: Text('Patient details'),
        content: SizedBox(height: 80, child: Text('Body')),
      ),
      size: const Size(390, 844),
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.fullscreen), findsNothing);

    // Leading: the back control sits before the title.
    final Offset back = tester.getCenter(find.byIcon(Icons.arrow_back));
    final Offset title = tester.getCenter(find.text('PATIENT DETAILS'));
    expect(back.dx, lessThan(title.dx));
  });

  testWidgets('desktop header keeps the trailing close X and no back arrow', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        title: Text('Patient details'),
        content: SizedBox(height: 80, child: Text('Body')),
      ),
      size: const Size(1280, 800),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    final Offset close = tester.getCenter(find.byIcon(Icons.close));
    final Offset title = tester.getCenter(find.text('PATIENT DETAILS'));
    expect(close.dx, greaterThan(title.dx));
  });

  testWidgets('mobile back control uses the Apple chevron on iOS', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          return Theme(
            data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
            child: const AppDialog(
              title: Text('Patient details'),
              content: SizedBox(height: 80, child: Text('Body')),
            ),
          );
        },
      ),
      size: const Size(390, 844),
    );

    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('mobile back control pops the route and honors closeEnabled', (
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
                    title: Text('Confirm action'),
                    content: SizedBox(height: 40, child: Text('Body')),
                  ),
                ),
              );
            },
            child: const Text('Open dialog'),
          );
        },
      ),
      size: const Size(390, 844),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('mobile back control renders disabled when closeEnabled is false', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        title: Text('Saving'),
        closeEnabled: false,
        content: SizedBox(height: 80, child: Text('Body')),
      ),
      size: const Size(390, 844),
    );

    final Finder backButton = find.ancestor(
      of: find.byIcon(Icons.arrow_back),
      matching: find.byType(TextButton),
    );
    expect(backButton, findsOneWidget);
    expect(tester.widget<TextButton>(backButton).onPressed, isNull);
  });

  testWidgets('showCloseButton false renders no dismiss control on mobile', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppDialog(
        title: Text('Blocking step'),
        showCloseButton: false,
        content: SizedBox(height: 80, child: Text('Body')),
      ),
      size: const Size(390, 844),
    );

    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('crowded footer keeps primary and dismiss inline, rest overflow', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppDialog(
        title: const Text('Roster detail'),
        content: const SizedBox(height: 80, child: Text('Body')),
        actions: <Widget>[
          AppButton.close(label: 'Close', onPressed: () {}),
          AppButton.secondary(
            label: 'Duplicate',
            leadingIcon: Icons.copy_outlined,
            onPressed: () {},
          ),
          AppButton.secondary(
            label: 'Export',
            leadingIcon: Icons.file_download_outlined,
            onPressed: () {},
          ),
          AppButton.tertiary(
            label: 'Print',
            leadingIcon: Icons.print_outlined,
            onPressed: () {},
          ),
          AppButton.primary(
            label: 'Save',
            leadingIcon: Icons.save_outlined,
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(390, 844),
    );

    // Mandatory actions stay inline and labeled.
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Overflow-eligible actions moved behind one trailing menu.
    expect(find.text('Duplicate'), findsNothing);
    expect(find.text('Export'), findsNothing);
    expect(find.text('Print'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    // Nothing disappeared: the menu lists every evicted action.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
  });

  testWidgets('overflow menu keeps disabled actions visible and disabled', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppDialog(
        title: const Text('Roster detail'),
        content: const SizedBox(height: 80, child: Text('Body')),
        actions: <Widget>[
          const AppButton.close(label: 'Close', onPressed: null),
          const AppButton.secondary(
            label: 'Duplicate',
            leadingIcon: Icons.copy_outlined,
            onPressed: null,
          ),
          const AppButton.secondary(
            label: 'Export',
            leadingIcon: Icons.file_download_outlined,
            enabled: false,
            onPressed: null,
          ),
          AppButton.primary(
            label: 'Save',
            leadingIcon: Icons.save_outlined,
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(390, 844),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    final Finder exportItem = find.ancestor(
      of: find.text('Export'),
      matching: find.byType(MenuItemButton),
    );
    expect(exportItem, findsOneWidget);
    expect(tester.widget<MenuItemButton>(exportItem).onPressed, isNull);
  });

  testWidgets('overflow menu entry invokes the original action callback', (
    WidgetTester tester,
  ) async {
    var exported = 0;

    await pumpComponent(
      tester,
      AppDialog(
        title: const Text('Roster detail'),
        content: const SizedBox(height: 80, child: Text('Body')),
        actions: <Widget>[
          AppButton.close(label: 'Close', onPressed: () {}),
          AppButton.secondary(
            label: 'Duplicate',
            leadingIcon: Icons.copy_outlined,
            onPressed: () {},
          ),
          AppButton.secondary(
            label: 'Export',
            leadingIcon: Icons.file_download_outlined,
            onPressed: () => exported += 1,
          ),
          AppButton.primary(
            label: 'Save',
            leadingIcon: Icons.save_outlined,
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(390, 844),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(exported, 1);
  });

  testWidgets('AppDialogAction overrides the inferred footer priority', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppDialog(
        title: const Text('Roster detail'),
        content: const SizedBox(height: 80, child: Text('Body')),
        actions: <Widget>[
          AppButton.close(label: 'Close', onPressed: () {}),
          // Secondary by variant, but pinned inline by the caller.
          AppDialogAction(
            priority: AppDialogActionPriority.primary,
            child: AppButton.secondary(
              label: 'Post',
              leadingIcon: Icons.send_outlined,
              onPressed: () {},
            ),
          ),
          AppButton.secondary(
            label: 'Duplicate',
            leadingIcon: Icons.copy_outlined,
            onPressed: () {},
          ),
          AppButton.secondary(
            label: 'Export',
            leadingIcon: Icons.file_download_outlined,
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(390, 844),
    );

    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Duplicate'), findsNothing);
    expect(find.text('Export'), findsNothing);
  });

  testWidgets('non-AppButton footer actions stay inline, never in the menu', (
    WidgetTester tester,
  ) async {
    // Stands in for AppAccessActionGate and friends: builds lazily, so the
    // footer cannot read its icon/label and must not re-render it as a row.
    final Widget gatedAction = Builder(
      builder: (BuildContext context) => AppButton.secondary(
        label: 'Gated',
        leadingIcon: Icons.lock_outline,
        onPressed: () {},
      ),
    );

    await pumpComponent(
      tester,
      AppDialog(
        title: const Text('Roster detail'),
        content: const SizedBox(height: 80, child: Text('Body')),
        actions: <Widget>[
          AppButton.close(label: 'Close', onPressed: () {}),
          gatedAction,
          AppButton.secondary(
            label: 'Duplicate',
            leadingIcon: Icons.copy_outlined,
            onPressed: () {},
          ),
          AppButton.secondary(
            label: 'Export',
            leadingIcon: Icons.file_download_outlined,
            onPressed: () {},
          ),
          AppButton.primary(
            label: 'Save',
            leadingIcon: Icons.save_outlined,
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(390, 844),
    );

    // The uninspectable action is never evicted, even under pressure. It may
    // shed its label as a last resort, but it stays on the inline row.
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    // Inspectable secondaries still overflow normally, and the menu lists only
    // them — the gate is never re-rendered as a menu row.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsNothing,
    );
  });

  testWidgets('footer controls render unscaled at 320 px', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppDialog(
        title: const Text('Roster detail'),
        content: const SizedBox(height: 80, child: Text('Body')),
        actions: <Widget>[
          AppButton.close(label: 'Close', onPressed: () {}),
          AppButton.secondary(
            label: 'Duplicate',
            leadingIcon: Icons.copy_outlined,
            onPressed: () {},
          ),
          AppButton.primary(
            label: 'Save',
            leadingIcon: Icons.save_outlined,
            onPressed: () {},
          ),
        ],
      ),
      size: const Size(320, 640),
      padding: EdgeInsets.zero,
    );

    _expectFooterTapTargets(tester);
  });

  testWidgets('footer controls render unscaled at 200% text scale', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: AppDialog(
              title: const Text('Roster detail'),
              content: const SizedBox(height: 80, child: Text('Body')),
              actions: <Widget>[
                AppButton.close(label: 'Close', onPressed: () {}),
                AppButton.secondary(
                  label: 'Duplicate',
                  leadingIcon: Icons.copy_outlined,
                  onPressed: () {},
                ),
                AppButton.primary(
                  label: 'Save',
                  leadingIcon: Icons.save_outlined,
                  onPressed: () {},
                ),
              ],
            ),
          );
        },
      ),
      size: const Size(320, 640),
      padding: EdgeInsets.zero,
    );

    _expectFooterTapTargets(tester);
  });
}

/// Dialog controls must render at their full natural height — the footer
/// overflows actions rather than scaling controls down.
///
/// The natural height of dense chrome is the interactive-dimension token minus
/// the `VisualDensity.compact` base-size adjustment applied by `AppButton`.
/// That density predates this footer work and is asserted here as the floor so
/// the test catches shrinkage introduced by layout, not by button styling.
void _expectFooterTapTargets(WidgetTester tester) {
  final double denseChromeHeight =
      AppTheme.light.appTokens.minInteractiveDimension +
      VisualDensity.compact.baseSizeAdjustment.dy;
  final Finder footerButtons = find.descendant(
    of: find.byType(AppDialog),
    matching: find.byType(TextButton),
  );

  expect(footerButtons, findsWidgets);
  for (final Element element in footerButtons.evaluate()) {
    final Size size = tester.getSize(find.byWidget(element.widget));
    expect(
      size.height,
      greaterThanOrEqualTo(denseChromeHeight),
      reason: 'A dialog control rendered below its natural height.',
    );
  }

  // No scale-down wrapper anywhere in the dialog: crowding is resolved by
  // moving actions into the overflow menu, never by shrinking the row.
  final Finder scalers = find.descendant(
    of: find.byType(AppDialog),
    matching: find.byWidgetPredicate(
      (Widget widget) => widget is FittedBox && widget.fit == BoxFit.scaleDown,
    ),
  );
  expect(scalers, findsNothing);
}

RenderBox _dialogShellRenderBox(WidgetTester tester) {
  return tester.renderObject<RenderBox>(
    find.byWidgetPredicate((Widget w) => AppDialog.isShellKey(w.key)),
  );
}
