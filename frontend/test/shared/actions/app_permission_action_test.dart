import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/app_action_lifecycle.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/actions/app_quick_actions.dart';
import 'package:hosspi_hms/shared/components/app_permission_action.dart';
import 'package:hosspi_hms/shared/components/app_permission_async_action.dart';

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

  AppAccessPolicy doctorPolicy() {
    return AppAccessPolicy.fromSession(
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
  }

  AppAccessPolicy patientPolicy() {
    return AppAccessPolicy.fromSession(
      AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['PATIENT']),
        permissions: <AppPermission>{AppPermissions.profileRead},
      ),
    );
  }

  const AccessRequirement clinicalWrite = AccessRequirement(
    anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  );

  group('hide vs disable matrix', () {
    testWidgets('hides when effective permission is missing', (tester) async {
      await tester.pumpWidget(
        wrap(
          AppPermissionActionButton(
            requirement: clinicalWrite,
            label: 'Order lab',
            icon: Icons.science_outlined,
            onPressed: () {},
          ),
          patientPolicy(),
        ),
      );

      expect(find.text('Order lab'), findsNothing);
    });

    testWidgets('disables when authorized but capability/prerequisite blocks', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        wrap(
          AppPermissionActionButton(
            requirement: clinicalWrite,
            label: 'Discharge',
            icon: Icons.logout,
            capabilityAllowed: false,
            blockedReason: 'Encounter is still open',
            onPressed: () => pressed += 1,
          ),
          doctorPolicy(),
        ),
      );

      expect(find.text('Discharge'), findsOneWidget);
      await tester.tap(find.text('Discharge'), warnIfMissed: false);
      await tester.pump();
      expect(pressed, 0);
    });

    testWidgets('enabled action invokes callback when authorized', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        wrap(
          AppPermissionActionButton(
            requirement: clinicalWrite,
            label: 'Save note',
            icon: Icons.save_outlined,
            onPressed: () => pressed += 1,
          ),
          doctorPolicy(),
        ),
      );

      await tester.tap(find.text('Save note'));
      await tester.pump();
      expect(pressed, 1);
    });
  });

  group('confirmation flows', () {
    testWidgets('destructive confirmation cancel leaves action uninvoked', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        wrap(
          AppPermissionActionButton(
            requirement: clinicalWrite,
            label: 'Delete order',
            icon: Icons.delete_outline,
            confirmTitle: 'Delete order?',
            confirmBody: 'This cannot be undone.',
            confirmSubmitLabel: 'Delete',
            destructive: true,
            onPressed: () => pressed += 1,
          ),
          doctorPolicy(),
        ),
      );

      await tester.tap(find.text('Delete order'));
      await tester.pumpAndSettle();
      expect(find.text('DELETE ORDER?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(pressed, 0);
      expect(find.text('DELETE ORDER?'), findsNothing);
    });

    testWidgets('destructive confirmation accept invokes action once', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        wrap(
          AppPermissionActionButton(
            requirement: clinicalWrite,
            label: 'Delete order',
            icon: Icons.delete_outline,
            confirmTitle: 'Delete order?',
            confirmBody: 'This cannot be undone.',
            confirmSubmitLabel: 'Delete',
            destructive: true,
            onPressed: () => pressed += 1,
          ),
          doctorPolicy(),
        ),
      );

      await tester.tap(find.text('Delete order'));
      await tester.pumpAndSettle();
      expect(find.text('This cannot be undone.'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });
  });

  group('AppQuickActions overflow', () {
    testWidgets('places overflow actions in the more-actions menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AppQuickActions(
            presentation: AppQuickActionsPresentation.buttonsOnly,
            permissionActions: <AppPermissionActionItem>[
              AppPermissionActionItem(
                requirement: clinicalWrite,
                label: 'Primary',
                icon: Icons.check,
                onPressed: () {},
              ),
              AppPermissionActionItem(
                requirement: clinicalWrite,
                label: 'Archive',
                icon: Icons.archive_outlined,
                placement: AppActionPlacement.overflow,
                onPressed: () {},
              ),
            ],
          ),
          doctorPolicy(),
        ),
      );

      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Archive'), findsNothing);
      expect(find.text('More actions'), findsOneWidget);

      await tester.tap(find.text('More actions'));
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsOneWidget);
    });
  });

  group('AppPermissionAsyncActionButton lifecycle', () {
    testWidgets(
      'success patches via onSuccess and cancel leaves domain alone',
      (tester) async {
        var domainValue = 0;
        var calls = 0;
        final AppActionRunner runner = AppActionRunner(createKey: () => 'k-1');

        await tester.pumpWidget(
          wrap(
            AppPermissionAsyncActionButton(
              requirement: clinicalWrite,
              label: 'Save vitals',
              icon: Icons.monitor_heart_outlined,
              runner: runner,
              mutate: (context) async {
                calls += 1;
                await Future<void>.delayed(const Duration(milliseconds: 20));
                return null;
              },
              onSuccess: () => domainValue = 1,
            ),
            doctorPolicy(),
          ),
        );

        await tester.tap(find.text('Save vitals'));
        await tester.pump();
        // In-flight: second tap must not double-submit.
        await tester.tap(find.text('Save vitals'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pumpAndSettle();

        expect(calls, 1);
        expect(domainValue, 1);
      },
    );

    testWidgets('failure leaves domain unchanged and offers idempotent retry', (
      tester,
    ) async {
      var domainValue = 0;
      final List<String> keys = <String>[];
      var attempt = 0;
      final AppActionRunner runner = AppActionRunner(
        createKey: () => 'retry-key',
      );

      await tester.pumpWidget(
        wrap(
          AppPermissionAsyncActionButton(
            requirement: clinicalWrite,
            label: 'Submit order',
            icon: Icons.send_outlined,
            runner: runner,
            mutate: (context) async {
              keys.add(context.idempotencyKey);
              attempt += 1;
              if (attempt == 1) {
                return const AppFailure.network();
              }
              return null;
            },
            onSuccess: () => domainValue = 1,
          ),
          doctorPolicy(),
        ),
      );

      await tester.tap(find.text('Submit order'));
      await tester.pumpAndSettle();

      expect(domainValue, 0);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(domainValue, 1);
      expect(keys, <String>['retry-key', 'retry-key']);
    });

    testWidgets('destructive confirm cancel does not run mutate', (
      tester,
    ) async {
      var calls = 0;
      var patched = false;

      await tester.pumpWidget(
        wrap(
          AppPermissionAsyncActionButton(
            requirement: clinicalWrite,
            label: 'Void charge',
            icon: Icons.money_off_outlined,
            confirmTitle: 'Void charge?',
            confirmBody: 'This cannot be undone.',
            confirmSubmitLabel: 'Void',
            destructive: true,
            mutate: (context) async {
              calls += 1;
              return null;
            },
            onSuccess: () => patched = true,
          ),
          doctorPolicy(),
        ),
      );

      await tester.tap(find.text('Void charge'));
      await tester.pumpAndSettle();
      expect(find.text('This cannot be undone.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(patched, isFalse);
    });
  });
}
