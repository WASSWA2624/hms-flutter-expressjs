import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';

import '../../../../helpers/test_harness.dart';

void main() {
  testWidgets('shows a missing account login message', (
    WidgetTester tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppFormInformationBanner.failure(
            context: context,
            failure: const AppFailure.unauthorized(
              code: 'auth.account_not_found',
            ),
          );
        },
      ),
    );

    expect(
      find.text(
        'No account for that email or phone. Check details or register.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a wrong password login message', (
    WidgetTester tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppFormInformationBanner.failure(
            context: context,
            failure: const AppFailure.unauthorized(code: 'auth.wrong_password'),
          );
        },
      ),
    );

    expect(
      find.text('The password is incorrect for this account.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a rate limited auth message', (WidgetTester tester) async {
    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppFormInformationBanner.failure(
            context: context,
            failure: const AppFailure.network(code: 'network.rate_limited'),
          );
        },
      ),
    );

    expect(
      find.text('Too many attempts. Please wait a moment and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a rate limited retry time when reset_at is present', (
    WidgetTester tester,
  ) async {
    final DateTime resetAt = DateTime.utc(2026, 8, 4, 17, 22);
    final String expectedTime =
        '${resetAt.toLocal().hour.toString().padLeft(2, '0')}:'
        '${resetAt.toLocal().minute.toString().padLeft(2, '0')}';

    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppFormInformationBanner.failure(
            context: context,
            failure: AppFailure.network(
              code: 'network.rate_limited',
              detailMessage: resetAt.toIso8601String(),
            ),
          );
        },
      ),
    );

    expect(
      find.text('Too many attempts. Try again after $expectedTime.'),
      findsOneWidget,
    );
  });
}
