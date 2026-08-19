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
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_appointment_actions_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_appointment_actions_dialog.dart';

void main() {
  const OpdAppointment appointment = OpdAppointment(
    id: 'appointment-internal',
    publicId: 'APT000001',
    tenantId: 'TEN000001',
    facilityId: 'FAC000001',
    patientId: 'PAT000001',
    patientDisplayName: 'Patient Example',
    status: 'SCHEDULED',
  );

  testWidgets('composes the shared hub with the reception write gate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appAccessPolicyProvider.overrideWithValue(
            AppAccessPolicy.fromSession(
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
                  AppModuleEntitlement(
                    code: 'scheduling-queue',
                    licenseStatus: 'ACTIVE',
                  ),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ReceptionAppointmentActionsDialog(appointment: appointment),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final OpdAppointmentActionsDialog hub = tester
        .widget<OpdAppointmentActionsDialog>(
          find.byType(OpdAppointmentActionsDialog),
        );
    expect(
      hub.actionRequirement,
      same(ReceptionAppointmentsAtomPermissions.frontDesk),
    );
    expect(hub.omitPrimaryAction, isTrue);
    expect(find.text('APPOINTMENT ACTIONS'), findsOneWidget);
    expect(find.byType(OpdWorkflowContextPanel), findsOneWidget);
    expect(find.text('Scheduled'), findsWidgets);
    // Reception passes omitPrimaryAction, so starting the encounter is absent
    // from this hub altogether — the worklist's next-action column owns that
    // prompt, and the hub keeps only the actions reception may take here.
    expect(find.text('Start OPD encounter'), findsNothing);
    expect(
      find.widgetWithText(AppButton, 'Start OPD encounter'),
      findsNothing,
    );
    expect(find.text('Queue'), findsNothing);
    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('Cancel appointment'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
