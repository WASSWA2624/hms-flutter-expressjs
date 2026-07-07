import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:patrol/patrol.dart';

import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository authRepository;

  setUp(() {
    authRepository = _MockAuthRepository();
    when(
      () => authRepository.logout(),
    ).thenAnswer((_) async => const Result<void>.success(null));
  });
  patrolTestWithDiagnostics(
    'unauthenticated users are redirected to login',
    ($) async {
      await pumpPatrolApp(
        $,
        overrides: testReadyAppOverrides(
          sessionState: const SessionState.unauthenticated(),
          initialLocation: AppRoutes.patients.path,
        ),
      );

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
    },
    targetFile: 'patrol_test/auth_flow_test.dart',
    platform: 'chrome',
  );

  patrolTestWithDiagnostics(
    'login shell renders without production services',
    ($) async {
      await pumpPatrolApp(
        $,
        overrides: testReadyAppOverrides(initialLocation: AppRoutes.login.path),
      );

      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        find.text('Use your facility account to open the HMS workspace.'),
        findsOneWidget,
      );
      expect(find.text('Sign in'), findsWidgets);
    },
    targetFile: 'patrol_test/auth_flow_test.dart',
    platform: 'chrome',
  );

  patrolTestWithDiagnostics(
    'logout returns to login screen',
    ($) async {
      await pumpPatrolApp(
        $,
        overrides: <Object?>[
          ...patrolAuthenticatedOverrides(),
          authRepositoryProvider.overrideWithValue(authRepository),
        ],
      );

      await $.tester.tap(find.byTooltip('Account'));
      await $.pumpAndSettle();
      await $.tester.tap(find.text('Logout'));
      await $.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
      verify(() => authRepository.logout()).called(1);
    },
    targetFile: 'patrol_test/auth_flow_test.dart',
    platform: 'chrome',
  );
}
