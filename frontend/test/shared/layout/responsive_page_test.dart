import 'package:flutter/material.dart';
import 'package:flutter_template/app/theme/app_theme.dart';
import 'package:flutter_template/shared/layout/responsive_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ResponsivePage adds keyboard inset to scrollable padding', (
    WidgetTester tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(tester.view.resetViewInsets);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ResponsivePage(
          padding: EdgeInsets.zero,
          child: Text('Keyboard aware body'),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate((Widget widget) {
        return widget is Padding &&
            widget.padding.resolve(TextDirection.ltr).bottom == 160;
      }),
      findsOneWidget,
    );
  });
}
