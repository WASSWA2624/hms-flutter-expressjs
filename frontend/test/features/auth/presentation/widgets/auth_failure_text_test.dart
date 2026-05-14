import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_failure_text.dart';

import '../../../../helpers/test_harness.dart';

void main() {
  testWidgets('shows a missing account login message', (
    WidgetTester tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      const AuthFailureText(
        failure: AppFailure.unauthorized(code: 'auth.account_not_found'),
      ),
    );

    expect(
      find.text(
        'No account exists for that email or phone. Check the details or create an account.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a wrong password login message', (
    WidgetTester tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      const AuthFailureText(
        failure: AppFailure.unauthorized(code: 'auth.wrong_password'),
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
      const AuthFailureText(
        failure: AppFailure.network(code: 'network.rate_limited'),
      ),
    );

    expect(
      find.text(
        'Too many sign-in attempts. Please wait a moment and try again.',
      ),
      findsOneWidget,
    );
  });
}
