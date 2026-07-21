import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_loading_indicator.dart';
import 'package:hosspi_hms/shared/components/app_logo.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('centers expanded loader within parent bounds', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const SizedBox(
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

    final Rect parent = tester.getRect(find.byType(SizedBox).first);
    final Rect logo = tester.getRect(find.byType(AppLogo));
    expect((logo.center.dx - parent.center.dx).abs(), lessThan(2));
    expect(logo.left, greaterThan(parent.left));
    expect(logo.right, lessThan(parent.right));
  });

  testWidgets('scales logo down to fit a tight parent', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const SizedBox(
        width: 72,
        height: 72,
        child: AppLoadingIndicator(
          size: AppLoadingIndicatorSize.regular,
          expand: true,
        ),
      ),
      size: const Size(120, 120),
      padding: EdgeInsets.zero,
    );

    final Size logoSize = tester.getSize(find.byType(AppLogo));
    expect(logoSize.shortestSide, lessThan(48));
    expect(logoSize.shortestSide, greaterThanOrEqualTo(20));
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
}
