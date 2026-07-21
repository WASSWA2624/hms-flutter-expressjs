import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_queue_actions_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_queue_actions_dialog.dart';

void main() {
  const OpdQueueEntry entry = OpdQueueEntry(
    id: 'queue-internal',
    publicId: 'QUE000001',
    patientDisplayName: 'Patient Example',
    providerDisplayName: 'Provider Example',
    status: 'CONFIRMED',
  );

  testWidgets('composes the shared queue hub with a Cancel-only footer', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, entry);

    expect(find.byType(ReceptionQueueActionsDialog), findsOneWidget);
    expect(find.byType(QueueActionsDialog), findsOneWidget);

    final QueueActionsDialog hub = tester.widget<QueueActionsDialog>(
      find.byType(QueueActionsDialog),
    );
    expect(hub.actionRequirement, same(receptionFrontDeskWriteRequirement));

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(dialog.actions, hasLength(1));
    expect(find.byType(AppQuickActions), findsOneWidget);
    expect(find.byType(OpdWorkflowContextPanel), findsOneWidget);
    expect(find.text('QUEUE ACTIONS'), findsOneWidget);
    expect(find.text('Prioritize'), findsOneWidget);
    expect(find.text('Change status'), findsOneWidget);
    expect(find.text('Assign doctor'), findsOneWidget);
    expect(find.text('Start consultation'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('hides mutation actions after the queue entry is terminal', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, entry.copyWith(status: 'COMPLETED'));

    expect(find.byType(AppQuickActions), findsNothing);
    expect(find.text('Prioritize'), findsNothing);
    expect(find.text('Change status'), findsNothing);
    expect(find.text('Assign doctor'), findsNothing);
    expect(find.text('Change doctor'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Start consultation'), findsNothing);
    expect(find.text('Start consultation'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('permission gate hides queue mutations when denied', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(
      tester,
      entry,
      policy: AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['PATIENT']),
          permissions: <AppPermission>{AppPermissions.profileRead},
        ),
      ),
    );

    expect(find.text('Prioritize'), findsNothing);
    expect(find.text('Change status'), findsNothing);
    expect(find.text('Assign doctor'), findsNothing);
    expect(find.text('Change doctor'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Start consultation'), findsNothing);
    expect(find.text('Start consultation'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('opens child prioritize dialog through showAppDialog', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, entry);

    await tester.tap(find.text('Prioritize'));
    await tester.pumpAndSettle();

    expect(find.text('PRIORITIZE QUEUE ENTRY'), findsOneWidget);
    expect(find.text('Cancel'), findsWidgets);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDialog(
      tester,
      entry,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppQuickActions), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester,
  OpdQueueEntry entry, {
  AppAccessPolicy? policy,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy ?? _frontDeskPolicy()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          );
        },
        home: Scaffold(body: ReceptionQueueActionsDialog(entry: entry)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppAccessPolicy _frontDeskPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
      permissions: <AppPermission>{
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}
