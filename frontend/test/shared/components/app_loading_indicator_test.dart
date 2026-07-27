import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_loading_indicator.dart';
import 'package:hosspi_hms/shared/components/app_logo.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('centers expanded loader within parent bounds', (
    WidgetTester tester,
  ) async {
    const Key parentKey = ValueKey<String>('loading-parent');
    await pumpComponent(
      tester,
      const SizedBox(
        key: parentKey,
        width: 420,
        height: 240,
        child: AppLoadingIndicator.compact(
          title: 'Loading',
          body: 'Please wait',
        ),
      ),
      size: const Size(480, 320),
      padding: EdgeInsets.zero,
    );

    expect(
      find.byKey(const ValueKey<String>('appLoadingIndicatorExpanded')),
      findsOneWidget,
    );
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('Please wait'), findsOneWidget);

    final Rect parent = tester.getRect(find.byKey(parentKey));
    final Rect logo = tester.getRect(find.byType(AppLogo));
    expect((logo.center.dx - parent.center.dx).abs(), lessThan(2));
    expect(logo.left, greaterThan(parent.left));
    expect(logo.right, lessThan(parent.right));
  });

  testWidgets('shows size-based default message when title is omitted', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const SizedBox(
        width: 320,
        height: 220,
        child: AppLoadingIndicator(
          size: AppLoadingIndicatorSize.regular,
        ),
      ),
      size: const Size(360, 280),
      padding: EdgeInsets.zero,
    );

    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('Please wait...'), findsOneWidget);
  });

  testWidgets('shows compact default title without body', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const SizedBox(
        width: 280,
        height: 180,
        child: AppLoadingIndicator.compact(),
      ),
      size: const Size(320, 220),
      padding: EdgeInsets.zero,
    );

    expect(find.text('Loading...'), findsOneWidget);
    expect(find.text('Please wait...'), findsNothing);
  });

  testWidgets('keeps inline expand:false mark message-free by default', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const Align(
        alignment: Alignment.centerLeft,
        child: AppLoadingIndicator(
          size: AppLoadingIndicatorSize.compact,
          expand: false,
        ),
      ),
    );

    expect(find.text('Loading...'), findsNothing);
    expect(find.text('Loading'), findsNothing);
    expect(find.byType(AppLogo), findsOneWidget);
  });

  testWidgets('keeps expanded loader within a tight parent', (
    WidgetTester tester,
  ) async {
    const Key parentKey = ValueKey<String>('tight-loading-parent');
    await pumpComponent(
      tester,
      const SizedBox(
        key: parentKey,
        width: 96,
        height: 96,
        child: AppLoadingIndicator(
          size: AppLoadingIndicatorSize.regular,
        ),
      ),
      size: const Size(140, 140),
      padding: EdgeInsets.zero,
    );

    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('Please wait...'), findsOneWidget);

    final Rect parent = tester.getRect(find.byKey(parentKey));
    final Rect logo = tester.getRect(find.byType(AppLogo));
    expect(logo.left, greaterThanOrEqualTo(parent.left - 0.5));
    expect(logo.right, lessThanOrEqualTo(parent.right + 0.5));
    expect(logo.top, greaterThanOrEqualTo(parent.top - 0.5));
    expect(logo.bottom, lessThanOrEqualTo(parent.bottom + 0.5));
  });

  testWidgets('keeps intrinsic size when expand is false', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const Align(
        alignment: Alignment.centerLeft,
        child: AppLoadingIndicator(
          size: AppLoadingIndicatorSize.compact,
          expand: false,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('appLoadingIndicatorExpanded')),
      findsNothing,
    );
    expect(find.byType(AppLogo), findsOneWidget);
  });

  testWidgets('inline mark-only compact fits without overflow in a tight slot', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: AppLoadingIndicator.compact(expand: false),
        ),
      ),
      size: const Size(120, 120),
      padding: EdgeInsets.zero,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppLogo), findsOneWidget);
  });
}
