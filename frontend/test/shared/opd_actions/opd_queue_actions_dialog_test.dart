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
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_queue_actions_dialog.dart';
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

  const OpdQueueEntry entry = OpdQueueEntry(
    id: 'queue-internal',
    publicId: 'QUE000001',
    patientDisplayName: 'Patient Example',
    providerUserId: 'USR000001',
    providerDisplayName: 'Provider Example',
    status: 'CONFIRMED',
  );

  testWidgets('uses the shared action hub with a Cancel-only footer', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, entry);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(dialog.actions, hasLength(1));
    expect(find.byType(AppQuickActions), findsOneWidget);
    expect(find.text('QUEUE ACTIONS'), findsOneWidget);
    expect(find.text('Prioritize'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, 'Start consultation'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.byType(AppWorkflowStepper), findsOneWidget);
    expect(find.text('Current step'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('hides mutation actions after the queue entry is terminal', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, entry.copyWith(status: 'COMPLETED'));

    expect(find.byType(AppQuickActions), findsNothing);
    expect(find.text('Prioritize'), findsNothing);
    expect(find.text('Move'), findsNothing);
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
    expect(find.text('Move'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Start consultation'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Move opens the shared move dialog without raw progress', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);
    when(() => repository.listProviders()).thenAnswer(
      (_) async =>
          const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[
            OpdProviderOption(id: 'USR000001', displayName: 'Dr Queue'),
          ]),
    );

    await _pumpDialog(tester, entry, repository: repository);
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    expect(find.text('MOVE QUEUE ENTRY'), findsOneWidget);
    expect(find.text('Cancel'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Prioritize opens the text action child dialog', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, entry);
    await tester.tap(find.text('Prioritize'));
    await tester.pumpAndSettle();

    expect(find.text('PRIORITIZE QUEUE ENTRY'), findsOneWidget);
    expect(find.text('Cancel'), findsWidgets);
  });

  testWidgets('Start consultation opens the confirm child dialog', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, entry);
    await tester.tap(find.widgetWithText(AppButton, 'Start consultation'));
    await tester.pumpAndSettle();

    expect(find.text('START CONSULTATION'), findsOneWidget);
    expect(find.text('Cancel'), findsWidgets);
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
  OpdRepository? repository,
}) async {
  final OpdRepository effectiveRepository;
  if (repository != null) {
    effectiveRepository = repository;
  } else {
    final _MockOpdRepository mock = _MockOpdRepository();
    _stubWorkspaceLoad(mock);
    effectiveRepository = mock;
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy ?? _frontDeskPolicy()),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        opdRepositoryProvider.overrideWithValue(effectiveRepository),
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
        home: Scaffold(body: QueueActionsDialog(entry: entry)),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
