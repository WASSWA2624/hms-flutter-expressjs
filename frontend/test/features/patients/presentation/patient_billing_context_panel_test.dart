import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_billing_context_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  const PatientDetail detail = PatientDetail(
    patient: Patient(
      id: 'patient-1',
      publicId: 'PAT000001',
      tenantId: 'tenant-1',
      firstName: 'Amina',
      lastName: 'Demo',
    ),
    workspace: PatientWorkspaceSnapshot(),
  );

  testWidgets('reception context keeps billing details read-only', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpPanel(
      tester,
      detail: detail,
      allowBillingNavigation: false,
    );

    expect(find.text('Billing details'), findsOneWidget);
    expect(find.text('No invoices recorded for this patient.'), findsOneWidget);
    expect(find.text('Open billing'), findsNothing);
    expect(router.state.uri.path, '/reception');
  });

  testWidgets('non-reception context preserves authorized billing navigation', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpPanel(
      tester,
      detail: detail,
      allowBillingNavigation: true,
      initialLocation: '/patients',
    );

    expect(find.text('Open billing'), findsOneWidget);
    await tester.tap(find.text('Open billing'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/billing');
    expect(router.state.uri.queryParameters['patientId'], 'PAT000001');
  });
}

Future<GoRouter> _pumpPanel(
  WidgetTester tester, {
  required PatientDetail detail,
  required bool allowBillingNavigation,
  String initialLocation = '/reception',
}) async {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/reception',
        builder: (_, _) => Scaffold(
          body: PatientBillingContextPanel(
            detail: detail,
            allowBillingNavigation: allowBillingNavigation,
          ),
        ),
      ),
      GoRoute(
        path: '/patients',
        builder: (_, _) => Scaffold(
          body: PatientBillingContextPanel(
            detail: detail,
            allowBillingNavigation: allowBillingNavigation,
          ),
        ),
      ),
      GoRoute(
        path: '/billing',
        builder: (_, _) => const Scaffold(body: Text('Billing workspace')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(_billingWriterPolicy()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

AppAccessPolicy _billingWriterPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['BILLING']),
      permissions: <AppPermission>{AppPermissions.billingWrite},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}
