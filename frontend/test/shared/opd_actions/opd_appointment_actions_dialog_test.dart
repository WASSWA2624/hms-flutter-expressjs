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
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_appointment_actions_dialog.dart';

void main() {
  const OpdAppointment appointment = OpdAppointment(
    id: 'appointment-internal',
    publicId: 'APT000001',
    tenantId: 'TEN000001',
    facilityId: 'FAC000001',
    patientId: 'PAT000001',
    patientDisplayName: 'Patient Example',
    providerUserId: 'USR000001',
    providerDisplayName: 'Provider Example',
    status: 'SCHEDULED',
    reason: 'Review',
  );

  testWidgets('uses the shared action hub with a Cancel-only footer', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, appointment);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(dialog.actions, hasLength(1));
    expect(find.byType(AppActionSection), findsOneWidget);
    expect(find.text('APPOINTMENT ACTIONS'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('Cancel appointment'), findsOneWidget);
    expect(find.text('Start OPD encounter'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
  });

  testWidgets('hides mutation actions after the appointment is terminal', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, appointment.copyWith(status: 'COMPLETED'));

    expect(find.byType(AppActionSection), findsNothing);
    expect(find.text('Start OPD encounter'), findsNothing);
    expect(find.text('Reschedule'), findsNothing);
    expect(find.text('Cancel appointment'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('permission gate hides appointment mutations when denied', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(
      tester,
      appointment,
      policy: AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['PATIENT']),
          permissions: <AppPermission>{AppPermissions.profileRead},
        ),
      ),
    );

    expect(find.text('Queue'), findsNothing);
    expect(find.text('Reschedule'), findsNothing);
    expect(find.text('Cancel appointment'), findsNothing);
    expect(find.text('Start OPD encounter'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('hides Queue when the appointment already has an active entry', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(
      tester,
      appointment,
      workspaceState: OpdWorkspaceState.empty().copyWith(
        queueEntries: const AppPage<OpdQueueEntry>(
          items: <OpdQueueEntry>[
            OpdQueueEntry(
              id: 'queue-internal',
              publicId: 'QUE000001',
              appointmentId: 'APT000001',
              status: 'CONFIRMED',
            ),
          ],
          request: AppPageRequest(pageSize: 12),
        ),
      ),
    );

    expect(find.text('Queue'), findsNothing);
    expect(find.text('Start OPD encounter'), findsOneWidget);
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
      appointment,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppActionSection), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester,
  OpdAppointment appointment, {
  AppAccessPolicy? policy,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
  OpdWorkspaceState? workspaceState,
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
        home: Scaffold(
          body: OpdAppointmentActionsDialog(
            appointment: appointment,
            workspaceState: workspaceState,
          ),
        ),
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
