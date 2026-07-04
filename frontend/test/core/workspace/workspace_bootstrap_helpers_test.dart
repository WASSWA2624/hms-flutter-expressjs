import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/core/workspace/workspace_bootstrap_helpers.dart';

void main() {
  group('workspace bootstrap helpers', () {
    test('identifies access denied failures', () {
      expect(
        isWorkspaceAccessDeniedFailure(const AppFailure.forbidden()),
        isTrue,
      );
      expect(
        isWorkspaceAccessDeniedFailure(const AppFailure.unauthorized()),
        isTrue,
      );
      expect(
        isWorkspaceAccessDeniedFailure(const AppFailure.notFound()),
        isFalse,
      );
    });

    test('ignores access denied failures when selecting blockers', () {
      expect(
        firstBlockingWorkspaceBootstrapFailure(<AppFailure?>[
          const AppFailure.forbidden(),
          const AppFailure.network(),
        ]),
        const AppFailure.network(),
      );
      expect(
        firstBlockingWorkspaceBootstrapFailure(<AppFailure?>[
          const AppFailure.unauthorized(),
        ]),
        isNull,
      );
    });

    test('reclassifies bootstrap unauthorized failures', () {
      final AppFailure normalized = normalizeWorkspaceBootstrapFailure(
        const AppFailure.unauthorized(statusCode: 401),
      );

      expect(normalized.category, AppFailureCategory.network);
      expect(normalized.isRetryable, isTrue);
    });
  });

  group('TenantSubscriptionSummary header state', () {
    test('defaults to unknown before hydration', () {
      expect(
        const TenantSubscriptionSummary().headerState,
        TenantSubscriptionHeaderState.unknown,
      );
      expect(TenantSubscriptionHeaderState.fromServer(null), isUnknown);
    });
  });
}

const Matcher isUnknown = _IsUnknownHeaderState();

final class _IsUnknownHeaderState extends Matcher {
  const _IsUnknownHeaderState();

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    return item == TenantSubscriptionHeaderState.unknown;
  }

  @override
  Description describe(Description description) {
    return description.add('unknown subscription header state');
  }
}
