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
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  const OpdFlowSummary flow = OpdFlowSummary(
    id: 'encounter-1',
    publicId: 'ENC000001',
    patientDisplayName: 'Patient Example',
    stage: 'WAITING_CONSULTATION_PAYMENT',
    displayCode: 'PAYMENT_DUE',
    consultationPaymentRequired: true,
    consultationPaid: false,
  );

  const OpdFlowDetail detail = OpdFlowDetail(summary: flow);

  testWidgets('uses the shared action hub with a Cancel-only footer', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, flow, detail: detail);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(dialog.actions, hasLength(1));
    expect(find.byType(AppActionSection), findsOneWidget);
    expect(find.text('FLOW ACTIONS'), findsOneWidget);
    expect(find.text('Pay consultation'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('title is role-based and never the patient name', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, flow, detail: detail);

    expect(find.text('FLOW ACTIONS'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.text('PATIENT EXAMPLE'), findsNothing);
  });

  testWidgets('hides stage mutations after the encounter is terminal', (
    WidgetTester tester,
  ) async {
    const OpdFlowSummary terminal = OpdFlowSummary(
      id: 'encounter-1',
      publicId: 'ENC000001',
      patientDisplayName: 'Patient Example',
      stage: 'DISCHARGED',
      status: 'CLOSED',
    );
    await _pumpDialog(
      tester,
      terminal,
      detail: const OpdFlowDetail(summary: terminal),
    );

    expect(find.text('Pay consultation'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('permission gate keeps next billing action visible but disabled', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(
      tester,
      flow,
      detail: detail,
      policy: AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['PATIENT']),
          permissions: <AppPermission>{AppPermissions.profileRead},
        ),
      ),
    );

    // Next-step actions stay visible when denied so Flow Actions is never empty.
    expect(find.widgetWithText(AppButton, 'Pay consultation'), findsOneWidget);
    final AppButton billingButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Pay consultation'),
    );
    expect(billingButton.onPressed, isNull);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('reception context removes billing actions for billing users', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, flow, detail: detail, allowBillingActions: false);

    expect(find.text('Pay consultation'), findsNothing);
    expect(find.text('Manage consultation billing'), findsNothing);
    expect(find.text('Update consultation billing'), findsNothing);
    expect(find.text('Payment due'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('receptionist at vitals-needed sees only front-desk actions', (
    WidgetTester tester,
  ) async {
    const OpdFlowSummary vitalsNeeded = OpdFlowSummary(
      id: 'encounter-1',
      publicId: 'ENC000001',
      patientDisplayName: 'Patient Example',
      stage: 'WAITING_VITALS',
      displayCode: 'VITALS_NEEDED',
      displayNextStep: 'RECORD_VITALS',
      providerUserId: 'USR-DOC001',
      providerDisplayName: 'Jordan Demo',
      assignedStaffLabel: 'Doctor: Jordan Demo',
      consultationPaymentRequired: false,
      consultationPaid: false,
    );

    await _pumpDialog(
      tester,
      vitalsNeeded,
      detail: const OpdFlowDetail(summary: vitalsNeeded),
      policy: _receptionistPolicy(),
    );

    expect(find.widgetWithText(AppButton, 'Record vitals'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Change doctor'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Print summary'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('nurse at vitals-needed sees record vitals and change doctor', (
    WidgetTester tester,
  ) async {
    const OpdFlowSummary vitalsNeeded = OpdFlowSummary(
      id: 'encounter-1',
      publicId: 'ENC000001',
      patientDisplayName: 'Patient Example',
      stage: 'WAITING_VITALS',
      displayCode: 'VITALS_NEEDED',
      displayNextStep: 'RECORD_VITALS',
      providerUserId: 'USR-DOC001',
      providerDisplayName: 'Jordan Demo',
      assignedStaffLabel: 'Doctor: Jordan Demo',
      consultationPaymentRequired: false,
      consultationPaid: false,
    );

    await _pumpDialog(
      tester,
      vitalsNeeded,
      detail: const OpdFlowDetail(summary: vitalsNeeded),
      policy: _nursePolicy(),
    );

    expect(find.widgetWithText(AppButton, 'Record vitals'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Change doctor'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('shows shared loading while encounter detail refreshes', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);
    when(() => repository.listAppointments(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return const Result<AppPage<OpdAppointment>>.success(
        AppPage<OpdAppointment>(
          items: <OpdAppointment>[],
          request: AppPageRequest(pageSize: 12),
        ),
      );
    });
    when(() => repository.getOpdFlow(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return const Result<OpdFlowDetail>.success(detail);
    });

    await _pumpDialog(tester, flow, repository: repository, settle: false);
    await tester.pump();

    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('FLOW ACTIONS'), findsOneWidget);
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
      flow,
      detail: detail,
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
  OpdFlowSummary flow, {
  OpdFlowDetail? detail,
  AppAccessPolicy? policy,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
  OpdRepository? repository,
  bool settle = true,
  bool allowBillingActions = true,
}) async {
  final OpdRepository effectiveRepository;
  if (repository != null) {
    effectiveRepository = repository;
  } else {
    final _MockOpdRepository mock = _MockOpdRepository();
    _stubWorkspaceLoad(mock);
    when(() => mock.getOpdFlow(any())).thenAnswer(
      (_) async =>
          Result<OpdFlowDetail>.success(detail ?? OpdFlowDetail(summary: flow)),
    );
    effectiveRepository = mock;
  }

  final _MockClinicalRepository clinicalRepository = _MockClinicalRepository();
  when(() => clinicalRepository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<ClinicalReferenceData>.success(ClinicalReferenceData()),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(
          policy ?? _billingFrontDeskPolicy(),
        ),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        opdRepositoryProvider.overrideWithValue(effectiveRepository),
        clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
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
          body: FlowActionsDialog(
            flow: flow,
            allowBillingActions: allowBillingActions,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

void _stubWorkspaceLoad(_MockOpdRepository repository) {
  when(() => repository.listAppointments(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: <OpdAppointment>[],
        request: AppPageRequest(pageSize: 12),
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

AppAccessPolicy _billingFrontDeskPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
      permissions: <AppPermission>{
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
        AppPermissions.billingWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

AppAccessPolicy _receptionistPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
      permissions: <AppPermission>{
        AppPermissions.profileRead,
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

AppAccessPolicy _nursePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['NURSE']),
      permissions: <AppPermission>{
        AppPermissions.patientRead,
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}
