import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_appointment_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

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
    await _pumpMountedDialog(tester, appointment);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(dialog.actions, hasLength(1));
    expect(find.byType(AppQuickActions), findsOneWidget);
    expect(find.text('APPOINTMENT ACTIONS'), findsOneWidget);
    expect(find.text('Queue'), findsNothing);
    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('Cancel appointment'), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, 'Start OPD encounter'),
      findsOneWidget,
    );
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.byType(AppWorkflowStepper), findsOneWidget);
    expect(find.text('Current step'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsNothing);
    expect(find.byIcon(AppActionIcons.appointment), findsOneWidget);
    expect(find.byIcon(AppActionIcons.queue), findsNothing);
    expect(find.byIcon(AppActionIcons.reschedule), findsWidgets);
    expect(find.byIcon(AppActionIcons.start), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'shows Continue and Edit when the patient already has an open OPD flow',
    (WidgetTester tester) async {
      await _pumpMountedDialog(
        tester,
        appointment,
        workspaceState: OpdWorkspaceState.empty().copyWith(
          flows: const AppPage<OpdFlowSummary>(
            items: <OpdFlowSummary>[
              OpdFlowSummary(
                id: 'flow-1',
                publicId: 'ENC000001',
                patientId: 'PAT000001',
                appointmentId: 'APT000001',
                status: 'OPEN',
                stage: 'WAITING_DOCTOR_REVIEW',
                displayCode: 'WITH_DOCTOR',
                displayStatus: 'With doctor',
              ),
            ],
            request: AppPageRequest(pageSize: 12),
          ),
        ),
      );

      expect(find.text('Start OPD encounter'), findsNothing);
      expect(
        find.widgetWithText(AppButton, 'Continue encounter'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Edit encounter'), findsOneWidget);
      expect(find.text('Cancel appointment'), findsNothing);
      expect(find.text('Reschedule'), findsOneWidget);
      expect(find.text('With doctor'), findsWidgets);
    },
  );

  testWidgets('hides mutation actions after the appointment is terminal', (
    WidgetTester tester,
  ) async {
    await _pumpMountedDialog(tester, appointment.copyWith(status: 'COMPLETED'));

    expect(find.byType(AppQuickActions), findsNothing);
    expect(find.text('Start OPD encounter'), findsNothing);
    expect(find.text('Reschedule'), findsNothing);
    expect(find.text('Cancel appointment'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('permission gate hides appointment mutations when denied', (
    WidgetTester tester,
  ) async {
    await _pumpMountedDialog(
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
    expect(find.widgetWithText(AppButton, 'Start OPD encounter'), findsNothing);
    expect(find.text('Quick actions'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('doctor front-desk roles can see Start OPD encounter', (
    WidgetTester tester,
  ) async {
    await _pumpMountedDialog(
      tester,
      appointment,
      policy: AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['DOCTOR']),
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
    );

    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Queue'), findsNothing);
    expect(
      find.widgetWithText(AppButton, 'Start OPD encounter'),
      findsOneWidget,
    );
    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('Cancel appointment'), findsOneWidget);
  });

  testWidgets('never offers Queue beside Start OPD encounter', (
    WidgetTester tester,
  ) async {
    await _pumpMountedDialog(tester, appointment);

    expect(find.text('Queue'), findsNothing);
    expect(
      find.widgetWithText(AppButton, 'Start OPD encounter'),
      findsOneWidget,
    );
  });

  testWidgets('Close pops false without mutating the appointment', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, appointments: <OpdAppointment>[appointment]);
    bool? result;

    await _pumpOpenedDialog(
      tester,
      appointment: appointment,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(
      () => repository.createVisitQueue(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
    verifyNever(
      () => repository.startOpdFlow(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
  });

  testWidgets('Reschedule opens the canonical child dialog', (
    WidgetTester tester,
  ) async {
    await _pumpMountedDialog(tester, appointment);
    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();

    expect(find.text('RESCHEDULE'), findsOneWidget);
    expect(find.text('Close'), findsWidgets);
  });

  testWidgets('Cancel appointment opens the canonical child dialog', (
    WidgetTester tester,
  ) async {
    await _pumpMountedDialog(tester, appointment);
    await tester.tap(find.text('Cancel appointment'));
    await tester.pumpAndSettle();

    expect(find.text('CANCEL APPOINTMENT'), findsOneWidget);
    expect(find.text('Close'), findsWidgets);
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpMountedDialog(
      tester,
      appointment,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppQuickActions), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}

Future<void> _pumpMountedDialog(
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

Future<void> _pumpOpenedDialog(
  WidgetTester tester, {
  required OpdAppointment appointment,
  required OpdRepository repository,
  ValueChanged<bool?>? onResult,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(_frontDeskPolicy()),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        opdRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return AppButton.primary(
                label: 'Open',
                onPressed: () async {
                  final bool? value = await showOpdAppointmentActionsDialog(
                    context: context,
                    appointment: appointment,
                  );
                  onResult?.call(value);
                },
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold)),
  );
  await container.read(opdWorkspaceControllerProvider.future);

  await tester.tap(find.widgetWithText(AppButton, 'Open'));
  await tester.pumpAndSettle();
}

void _stubWorkspaceLoad(
  _MockOpdRepository repository, {
  required List<OpdAppointment> appointments,
}) {
  when(() => repository.listAppointments(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: appointments,
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: appointments.length,
      ),
    ),
  );
  when(() => repository.listVisitQueues(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: <OpdQueueEntry>[],
        request: AppPageRequest(pageSize: 12),
      ),
    ),
  );
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: <OpdFlowSummary>[],
        request: AppPageRequest(pageSize: 12),
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: <OpdFlowSummary>[],
        request: AppPageRequest(pageSize: 12),
      ),
    ),
  );
  when(() => repository.getOpdSummaryCounts()).thenAnswer(
    (_) async =>
        const Result<OpdFlowAggregateCounts>.success(OpdFlowAggregateCounts()),
  );
  when(
    () => repository.listClinicalAlertThresholds(
      vitalType: any(named: 'vitalType'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<OpdClinicalAlertThreshold>>.success(
      <OpdClinicalAlertThreshold>[],
    ),
  );
  when(() => repository.listProviderSchedules()).thenAnswer(
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
  );
  when(() => repository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
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
