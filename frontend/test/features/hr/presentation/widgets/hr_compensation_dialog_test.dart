import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_compensation_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_compensation_line_editor.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHrRepository extends Mock implements HrRepository {}

AppAccessPolicy _hrWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['HR'],
        tenantId: '550e8400-e29b-41d4-a716-446655440000',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: hrRostersModule, licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspaceBootstrap(_MockHrRepository repository) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async =>
        const Result<HrWorkspaceOverview>.success(HrWorkspaceOverview()),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(
    () => repository.loadReferenceData(
      facilityId: any(named: 'facilityId'),
      departmentId: any(named: 'departmentId'),
    ),
  ).thenAnswer(
    (_) async => const Result<HrReferenceData>.success(HrReferenceData()),
  );
  when(() => repository.listWorkItems(any())).thenAnswer(
    (_) async => const Result<AppPage<HrWorkItem>>.success(
      AppPage<HrWorkItem>(
        items: <HrWorkItem>[],
        request: AppPageRequest(pageSize: 10),
      ),
    ),
  );
}

void main() {
  testWidgets('HrCompensationLineEditor renders pay type fields', (
    WidgetTester tester,
  ) async {
    final HrCompensationLineData line = HrCompensationLineData(
      payType: 'PER_MONTH',
      rateController: TextEditingController(text: '3000'),
      effectiveFrom: DateTime(2026),
    );
    addTearDown(line.rateController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: HrCompensationLineEditor(
            line: line,
            usedPayTypes: const <String>{'PER_MONTH'},
            onChanged: () {},
            onRemove: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3000'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  test('HrCompensationLineData serializes full compensation payload', () {
    final HrCompensationLineData line = HrCompensationLineData(
      payType: 'PER_CONSULTATION',
      rateController: TextEditingController(text: '75'),
      currency: 'USD',
      effectiveFrom: DateTime(2026),
    );

    final Map<String, Object?> payload = line.toPayload();
    expect(payload['pay_type'], 'PER_CONSULTATION');
    expect(payload['rate'], 75);
    expect(payload['currency'], 'USD');
    line.rateController.dispose();
  });

  group('showHrCompensationDialog', () {
    late _MockHrRepository repository;

    setUpAll(() {
      registerFallbackValue(const HrStaffQuery());
      registerFallbackValue(const HrWorkItemsQuery());
    });

    setUp(() {
      repository = _MockHrRepository();
      _stubWorkspaceBootstrap(repository);
    });

    Future<void> pumpDialog(
      WidgetTester tester, {
      required List<HrStaffCompensation> history,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      const HrStaffProfile staff = HrStaffProfile(
        id: 'staff-1',
        userFullName: 'Dr. Belinda Lim',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hrRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(_hrWritePolicy()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () => showHrCompensationDialog(
                        context,
                        ref,
                        staff,
                        history,
                      ),
                      child: const Text('open'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'opens maximized with both tabs and no overflow on a short viewport',
      (WidgetTester tester) async {
        // A short viewport is where the previous fixed-height tab body
        // overflowed ("BOTTOM OVERFLOWED BY 71 PIXELS").
        tester.view.physicalSize = const Size(1000, 560);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpDialog(
          tester,
          history: <HrStaffCompensation>[
            HrStaffCompensation(
              id: 'comp-1',
              payType: 'PER_CONSULTATION',
              rate: 75,
              currency: 'UGX',
              effectiveFrom: DateTime(2026),
            ),
          ],
        );

        // Dialog headers are uppercased by normalizeDialogTitleWidget.
        expect(find.text('UPDATE COMPENSATION'), findsWidgets);
        expect(find.text('Pay structure'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('Add pay line'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders on a narrow mobile viewport without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(420, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpDialog(tester, history: const <HrStaffCompensation>[]);

      expect(find.text('Pay structure'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
