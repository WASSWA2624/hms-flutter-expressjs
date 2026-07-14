import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_permission_action.dart';

void main() {
  Widget wrap(Widget child, AppAccessPolicy policy) {
    return ProviderScope(
      overrides: [appAccessPolicyProvider.overrideWithValue(policy)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('AppAccessGate', () {
    testWidgets('hides child when unauthorized', (tester) async {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['PATIENT']),
          permissions: <AppPermission>{AppPermissions.profileRead},
        ),
      );

      await tester.pumpWidget(
        wrap(
          AppAccessGate(
            requirement: const AccessRequirement(
              anyPermissions: <AppPermission>[AppPermissions.billingWrite],
            ),
            child: const Text('secret'),
          ),
          policy,
        ),
      );

      expect(find.text('secret'), findsNothing);
    });

    testWidgets('shows child when authorized', (tester) async {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['DOCTOR']),
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        wrap(
          AppAccessGate(
            requirement: const AccessRequirement(
              anyPermissions: <AppPermission>[AppPermissions.clinicalRead],
            ),
            child: const Text('allowed'),
          ),
          policy,
        ),
      );

      expect(find.text('allowed'), findsOneWidget);
    });
  });

  group('AppPermissionActionButton hide vs disable', () {
    testWidgets('hides unauthorized actions by default', (tester) async {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['PATIENT']),
          permissions: <AppPermission>{AppPermissions.profileRead},
        ),
      );

      await tester.pumpWidget(
        wrap(
          AppPermissionActionButton(
            requirement: const AccessRequirement(
              anyPermissions: <AppPermission>[AppPermissions.billingWrite],
            ),
            label: 'Charge',
            icon: Icons.payment,
            onPressed: () {},
          ),
          policy,
        ),
      );

      expect(find.text('Charge'), findsNothing);
    });

    testWidgets(
      'keeps authorized action visible when prerequisite disables it',
      (tester) async {
        final policy = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: const AuthUserProfile(roles: <String>['DOCTOR']),
            permissions: <AppPermission>{AppPermissions.clinicalWrite},
            moduleEntitlements: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          wrap(
            AppPermissionActionButton(
              requirement: const AccessRequirement(
                anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
              ),
              label: 'Save note',
              icon: Icons.save,
              enabled: false,
              onPressed: () {},
            ),
            policy,
          ),
        );

        expect(find.text('Save note'), findsOneWidget);
      },
    );
  });

  group('AppAccessActionGate', () {
    testWidgets('hides an unauthorized action by default', (tester) async {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['PATIENT']),
          permissions: <AppPermission>{AppPermissions.profileRead},
        ),
      );

      await tester.pumpWidget(
        wrap(
          AppAccessActionGate(
            requirement: const AccessRequirement(
              anyPermissions: <AppPermission>[AppPermissions.billingWrite],
            ),
            builder: (_, isAllowed) => Text('Refund: $isAllowed'),
          ),
          policy,
        ),
      );

      expect(find.textContaining('Refund'), findsNothing);
    });

    testWidgets('can explicitly render a denied non-action state', (
      tester,
    ) async {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['PATIENT']),
          permissions: <AppPermission>{AppPermissions.profileRead},
        ),
      );

      await tester.pumpWidget(
        wrap(
          AppAccessActionGate(
            requirement: const AccessRequirement(
              anyPermissions: <AppPermission>[AppPermissions.billingWrite],
            ),
            hideWhenDenied: false,
            builder: (_, isAllowed) => Text('Status: $isAllowed'),
          ),
          policy,
        ),
      );

      expect(find.text('Status: false'), findsOneWidget);
    });
  });
}
