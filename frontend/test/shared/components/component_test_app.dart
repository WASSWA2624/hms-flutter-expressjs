import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_harness.dart';

Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 600),
  EdgeInsetsGeometry? padding,
}) async {
  await pumpLocalizedWidget(
    tester,
    ProviderScope(child: child),
    size: size,
    padding: padding ?? const EdgeInsets.all(24),
  );
}
