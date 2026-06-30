import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockHrRepository extends Mock implements HrRepository {}

const HrReferenceData _referenceData = HrReferenceData(
  staffPositions: <HrOption>[
    HrOption(value: 'pos-nurse', label: 'Nurse'),
    HrOption(value: 'pos-doctor', label: 'Doctor'),
  ],
  departments: <HrOption>[
    HrOption(value: 'dept-er', label: 'Emergency'),
    HrOption(value: 'dept-lab', label: 'Laboratory'),
  ],
  practitionerTypes: <HrOption>[
    HrOption(value: 'MO', label: 'Medical Officer (MO)'),
    HrOption(value: 'SPECIALIST', label: 'Specialist / Consultant'),
  ],
  roles: <HrOption>[
    HrOption(
      value: 'role-nurse',
      label: 'Nurse | ROL001',
      extra: <String, Object?>{'permission_count': 5, 'name': 'NURSE'},
    ),
    HrOption(
      value: 'role-doctor',
      label: 'Doctor | ROL002',
      extra: <String, Object?>{'permission_count': 12, 'name': 'DOCTOR'},
    ),
  ],
);

void _stubWorkspaceBootstrap(_MockHrRepository repository) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async => const Result<HrWorkspaceOverview>.success(HrWorkspaceOverview()),
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
  group('HrStaffOnboardingForm', () {
    late _MockHrRepository repository;

    setUp(() {
      repository = _MockHrRepository();
      _stubWorkspaceBootstrap(repository);
      when(
        () => repository.generateStaffNumber(
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
        ),
      ).thenAnswer(
        (_) async => const Result<String>.success('DEMO-STF-0001'),
      );
      when(() => repository.listRolePermissions(any())).thenAnswer(
        (_) async => const Result<AppPage<HrOption>>.success(
          AppPage<HrOption>(
            items: <HrOption>[HrOption(value: 'p1', label: 'HR_READ')],
            request: AppPageRequest(),
          ),
        ),
      );
    });

    setUpAll(() {
      registerFallbackValue(const HrStaffQuery());
      registerFallbackValue(const HrWorkItemsQuery());
    });

    Widget buildForm({double width = 1000}) {
      return ProviderScope(
        overrides: [
          hrRepositoryProvider.overrideWithValue(repository),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.authenticated(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: width,
                  child: const Form(
                    child: HrStaffOnboardingForm(
                      referenceData: _referenceData,
                      tenantId: 'tenant-1',
                      facilityId: 'facility-1',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('defaults hire date to today and uses generate staff number mode',
        (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pump();
      await tester.pumpAndSettle();

      final HrStaffOnboardingFormState state = tester.state<HrStaffOnboardingFormState>(
        find.byType(HrStaffOnboardingForm),
      );

      final DateTime today = DateTime.now();
      expect(state.hireDate?.year, today.year);
      expect(state.hireDate?.month, today.month);
      expect(state.hireDate?.day, today.day);
      expect(state.staffNumberMode, StaffNumberEntryMode.generate);
      expect(find.text('Automatically generate staff number'), findsOneWidget);
      expect(find.text('Enter staff number manually'), findsOneWidget);
      expect(find.text('DEMO-STF-0001'), findsNothing);
    });

    testWidgets('shows staff number mode radios side by side on wide layout',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      final Finder generateRadio = find.ancestor(
        of: find.text('Automatically generate staff number'),
        matching: find.byType(RadioListTile<StaffNumberEntryMode>),
      );
      final Finder manualRadio = find.ancestor(
        of: find.text('Enter staff number manually'),
        matching: find.byType(RadioListTile<StaffNumberEntryMode>),
      );

      expect(generateRadio, findsOneWidget);
      expect(manualRadio, findsOneWidget);
      expect(
        tester.getTopLeft(generateRadio).dy,
        closeTo(tester.getTopLeft(manualRadio).dy, 1.0),
      );
    });

    testWidgets('stacks staff number mode radios on narrow layout',
        (tester) async {
      await tester.pumpWidget(buildForm(width: 400));
      await tester.pumpAndSettle();

      final Finder generateRadio = find.ancestor(
        of: find.text('Automatically generate staff number'),
        matching: find.byType(RadioListTile<StaffNumberEntryMode>),
      );
      final Finder manualRadio = find.ancestor(
        of: find.text('Enter staff number manually'),
        matching: find.byType(RadioListTile<StaffNumberEntryMode>),
      );

      expect(
        tester.getTopLeft(generateRadio).dy,
        lessThan(tester.getTopLeft(manualRadio).dy),
      );
    });

    testWidgets('shows staff number field only in manual mode', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(find.text('Staff number'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Enter staff number manually'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.ancestor(
          of: find.text('Enter staff number manually'),
          matching: find.byType(RadioListTile<StaffNumberEntryMode>),
        ),
      );
      await tester.pumpAndSettle();

      final HrStaffOnboardingFormState state =
          tester.state<HrStaffOnboardingFormState>(
        find.byType(HrStaffOnboardingForm),
      );
      expect(state.staffNumberMode, StaffNumberEntryMode.manual);
    });

    testWidgets('can add and remove roles from the assignment picker',
        (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(find.textContaining('No roles assigned yet'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Add role'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add role'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nurse | ROL001').last);
      await tester.pumpAndSettle();

      final HrStaffOnboardingFormState state =
          tester.state<HrStaffOnboardingFormState>(
        find.byType(HrStaffOnboardingForm),
      );
      expect(state.selectedRoleIds, contains('role-nurse'));
      expect(find.text('HR_READ'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove role'));
      await tester.pumpAndSettle();

      expect(
        tester.state<HrStaffOnboardingFormState>(
          find.byType(HrStaffOnboardingForm),
        ).selectedRoleIds,
        isEmpty,
      );
    });

    testWidgets('shows required validation for staff phone', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      final FormState formState = tester.state<FormState>(find.byType(Form));
      expect(formState.validate(), isFalse);
    });

    testWidgets('uses single-column layout on narrow width', (tester) async {
      await tester.pumpWidget(buildForm(width: 400));
      await tester.pumpAndSettle();

      expect(find.text('Staff details and access'), findsOneWidget);
      expect(find.text('Employment'), findsOneWidget);
      expect(find.text('Roles and access'), findsOneWidget);
    });

    testWidgets('exposes populated position and department options on first open',
        (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      final HrStaffOnboardingFormState state =
          tester.state<HrStaffOnboardingFormState>(
        find.byType(HrStaffOnboardingForm),
      );
      expect(state.positionOptionCountForTest(), greaterThanOrEqualTo(2));
      expect(state.departmentOptionCountForTest(), greaterThanOrEqualTo(2));
      expect(find.text('Add a new position'), findsNothing);
    });

    testWidgets('shows compensation section on create', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(find.text('Compensation'), findsOneWidget);
      expect(find.text('Pay type'), findsOneWidget);
      expect(find.text('Monthly rate'), findsWidgets);
    });

    testWidgets('shows practitioner type only after doctor role is selected',
        (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      final HrStaffOnboardingFormState state =
          tester.state<HrStaffOnboardingFormState>(
        find.byType(HrStaffOnboardingForm),
      );
      expect(state.showPractitionerTypeForTest, isFalse);

      state.setSelectedRolesForTest(<String>{'role-doctor'});
      await tester.pump();

      expect(state.showPractitionerTypeForTest, isTrue);
      expect(find.text('Practitioner type'), findsWidgets);
    });

    testWidgets('typed position is included in create payload', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      final HrStaffOnboardingFormState state =
          tester.state<HrStaffOnboardingFormState>(
        find.byType(HrStaffOnboardingForm),
      );
      state.setPositionDraftForTest(searchText: 'Clinical Coordinator');

      final Map<String, Object?> payload = state.toPayload();
      expect(payload['position'], 'Clinical Coordinator');
    });

    testWidgets('does not show create/link user toggle', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(find.text('Create new user'), findsNothing);
      expect(find.text('Link existing user'), findsNothing);
    });
  });

  group('hr staff onboarding consolidation', () {
    test('exports canonical showHrStaffOnboardingDialog', () {
      expect(showHrStaffOnboardingDialog, isNotNull);
    });
  });
}
