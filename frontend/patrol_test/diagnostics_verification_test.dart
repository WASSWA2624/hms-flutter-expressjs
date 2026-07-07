import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/failure_reporter.dart';

void main() {
  patrolTestWithDiagnostics(
    'diagnostic bundle verification (intentional failure)',
    ($) async {
      await $.pumpWidgetAndSettle(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: Text('diagnostic probe')),
        ),
      );

      expect(find.text('this text is intentionally missing'), findsOneWidget);
    },
    skip: true,
    targetFile: 'patrol_test/diagnostics_verification_test.dart',
    platform: 'chrome',
  );
}
