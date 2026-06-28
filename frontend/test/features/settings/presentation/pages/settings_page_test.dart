import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/settings/presentation/pages/settings_page.dart';

import '../../../../helpers/test_harness.dart';

void main() {
  testWidgets('HR policy sees personal settings only', (
    WidgetTester tester,
  ) async {
    final AuthSession session = AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(tenantId: 'tenant-1', roles: <String>['HR']),
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'hr-rosters'),
      ],
    );
    final AppAccessPolicy policy = AppAccessPolicy.fromSession(
      session,
    ).copyWithPermissions(<AppPermission>[AppPermissions.hrWrite]);

    await pumpLocalizedWidget(
      tester,
      ProviderScope(
        overrides: [appAccessPolicyProvider.overrideWithValue(policy)],
        child: const SettingsPage(),
      ),
      size: const Size(1280, 1400),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Accessibility'), findsOneWidget);
    expect(find.text('Account and security'), findsOneWidget);
    expect(find.text('Administration boundaries'), findsNothing);
    expect(find.text('Administrative setup workspace'), findsNothing);
    expect(find.text('Users and access'), findsNothing);
    expect(find.text('User and security settings'), findsNothing);
  });
}
