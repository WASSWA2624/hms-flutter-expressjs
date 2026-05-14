import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_harness.dart';

Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 600),
}) async {
  await pumpLocalizedWidget(tester, child, size: size);
}
