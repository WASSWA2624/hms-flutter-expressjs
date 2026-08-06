import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_start_admission_dialog.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_admission_action_dialog.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';
import 'package:mocktail/mocktail.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

class _MockPatientRepository extends Mock implements PatientRepository {}

const IpdReferenceData _referenceData = IpdReferenceData(
  wards: <IpdWardOption>[
    IpdWardOption(id: 'ward-a', name: 'Ward A', wardType: 'GENERAL'),
  ],
  availableBeds: <IpdBedOption>[
    IpdBedOption(
      id: 'bed-1',
      label: 'Bed 1',
      status: 'AVAILABLE',
      wardId: 'ward-a',
      wardName: 'Ward A',
      roomId: 'room-1',
      roomName: 'Room 1',
    ),
  ],
);

const Patient _patient = Patient(
  id: 'pat-1',
  displayName: 'Ada Active',
  primaryIdentifierValue: 'MRN-1',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(
      const PatientListQuery(pageRequest: AppPageRequest(pageSize: 12)),
    );
  });

  testWidgets(
    'reuses ClinicalAdmissionActionDialog with Close and Start admission chrome',
    (WidgetTester tester) async {
      final _MockIpdRepository ipdRepository = _MockIpdRepository();
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      _stubWorkspaceLoad(ipdRepository);
      _stubPatientSearch(patientRepository);

      await _pumpDialog(
        tester,
        ipdRepository: ipdRepository,
        patientRepository: patientRepository,
      );

      expect(find.byType(IpdStartAdmissionDialog), findsOneWidget);
      expect(find.byType(ClinicalAdmissionActionDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('START ADMISSION'), findsOneWidget);
      expect(find.text('Start admission'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.personAdd), findsWidgets);
      expect(find.byIcon(AppActionIcons.add), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
      expect(find.text('Ada Active'), findsNothing);
      expect(find.text('Ward'), findsOneWidget);
      expect(find.text('Room'), findsOneWidget);
      expect(find.text('Bed'), findsOneWidget);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.scrollable, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
      expect(dialog.initialMaximized, isFalse);
    },
  );

  testWidgets('title never uses a patient display name', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository ipdRepository = _MockIpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    _stubWorkspaceLoad(ipdRepository);
    _stubPatientSearch(patientRepository);

    await _pumpDialog(
      tester,
      ipdRepository: ipdRepository,
      patientRepository: patientRepository,
    );

    expect(find.text('START ADMISSION'), findsOneWidget);
    expect(find.textContaining('Ada Active'), findsNothing);
  });

  testWidgets('searches patients through the workspace controller', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository ipdRepository = _MockIpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    _stubWorkspaceLoad(ipdRepository);
    _stubPatientSearch(patientRepository);

    await _pumpDialog(
      tester,
      ipdRepository: ipdRepository,
      patientRepository: patientRepository,
    );

    await tester.enterText(find.byType(EditableText).first, 'Ada');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    verify(
      () => patientRepository.listPatients(any()),
    ).called(greaterThanOrEqualTo(1));
    expect(find.textContaining('Ada Active'), findsWidgets);
  });

  testWidgets('Close pops without mutating admissions', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository ipdRepository = _MockIpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    bool? result;
    _stubWorkspaceLoad(ipdRepository);
    _stubPatientSearch(patientRepository);

    await _pumpDialog(
      tester,
      ipdRepository: ipdRepository,
      patientRepository: patientRepository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => ipdRepository.startAdmission(any()));
  });

  testWidgets('failure keeps the dialog open and patches nothing', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository ipdRepository = _MockIpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    when(() => ipdRepository.startAdmission(any())).thenAnswer(
      (_) async => const Result<IpdAdmissionDetail>.failure(
        AppFailure.network(),
      ),
    );
    _stubWorkspaceLoad(ipdRepository);
    _stubPatientSearch(patientRepository);
    bool? result;

    await _pumpDialog(
      tester,
      ipdRepository: ipdRepository,
      patientRepository: patientRepository,
      onResult: (bool? value) => result = value,
    );

    await _selectPatient(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Start admission'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(IpdStartAdmissionDialog), findsOneWidget);
    expect(find.byType(ClinicalAdmissionActionDialog), findsOneWidget);
    verify(() => ipdRepository.startAdmission(any())).called(1);
  });

  testWidgets('successful save posts patient and optional bed then pops true', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockIpdRepository ipdRepository = _MockIpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    Map<String, Object?>? payload;
    when(() => ipdRepository.startAdmission(any())).thenAnswer((
      Invocation invocation,
    ) async {
      payload = invocation.positionalArguments.single as Map<String, Object?>;
      return Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'adm-1',
            displayId: 'ADM-1',
            patientId: 'pat-1',
            patientDisplayName: 'Ada Active',
            stage: 'ADMITTED_IN_BED',
            admissionStatus: 'ADMITTED',
            hasActiveBed: true,
          ),
        ),
      );
    });
    _stubWorkspaceLoad(ipdRepository);
    _stubPatientSearch(patientRepository);
    bool? result;

    await _pumpDialog(
      tester,
      ipdRepository: ipdRepository,
      patientRepository: patientRepository,
      onResult: (bool? value) => result = value,
    );

    await _selectPatient(tester);
    await _selectSearchableOption(tester, 1, 'Ward A');
    await _selectSearchableOption(tester, 2, 'Room 1');
    await _selectSearchableOption(tester, 3, 'Bed 1');

    await tester.tap(find.widgetWithText(AppButton, 'Start admission'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(IpdStartAdmissionDialog), findsNothing);
    expect(payload?['patient_id'], 'pat-1');
    expect(payload?['ward_id'], 'ward-a');
    expect(payload?['room_id'], 'room-1');
    expect(payload?['bed_id'], 'bed-1');
    verify(() => ipdRepository.startAdmission(any())).called(1);
  });

  testWidgets('successful save can omit bed assignment', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository ipdRepository = _MockIpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    Map<String, Object?>? payload;
    when(() => ipdRepository.startAdmission(any())).thenAnswer((
      Invocation invocation,
    ) async {
      payload = invocation.positionalArguments.single as Map<String, Object?>;
      return Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'adm-1',
            displayId: 'ADM-1',
            patientId: 'pat-1',
            patientDisplayName: 'Ada Active',
            stage: 'ADMITTED_PENDING_BED',
            admissionStatus: 'ADMITTED',
          ),
        ),
      );
    });
    _stubWorkspaceLoad(ipdRepository);
    _stubPatientSearch(patientRepository);
    bool? result;

    await _pumpDialog(
      tester,
      ipdRepository: ipdRepository,
      patientRepository: patientRepository,
      onResult: (bool? value) => result = value,
    );

    await _selectPatient(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Start admission'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(payload?['patient_id'], 'pat-1');
    expect(payload?['bed_id'], isNull);
    verify(() => ipdRepository.startAdmission(any())).called(1);
  });

  testWidgets('blocks competing actions while start admission is in flight', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository ipdRepository = _MockIpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    final Completer<Result<IpdAdmissionDetail>> completer =
        Completer<Result<IpdAdmissionDetail>>();
    when(
      () => ipdRepository.startAdmission(any()),
    ).thenAnswer((_) => completer.future);
    _stubWorkspaceLoad(ipdRepository);
    _stubPatientSearch(patientRepository);

    await _pumpDialog(
      tester,
      ipdRepository: ipdRepository,
      patientRepository: patientRepository,
    );

    await _selectPatient(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Start admission'));
    await tester.pump();

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isFalse);
    expect(_button(tester, 'Close').enabled, isFalse);
    expect(_button(tester, 'Start admission').isLoading, isTrue);

    completer.complete(
      Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'adm-1',
            displayId: 'ADM-1',
            patientId: 'pat-1',
            patientDisplayName: 'Ada Active',
            stage: 'ADMITTED_PENDING_BED',
            admissionStatus: 'ADMITTED',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockIpdRepository ipdRepository = _MockIpdRepository();
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    _stubWorkspaceLoad(ipdRepository);
    _stubPatientSearch(patientRepository);

    await _pumpDialog(
      tester,
      ipdRepository: ipdRepository,
      patientRepository: patientRepository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ClinicalAdmissionActionDialog), findsOneWidget);
    expect(find.text('START ADMISSION'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Start admission'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required IpdRepository ipdRepository,
  required PatientRepository patientRepository,
  ValueChanged<bool?>? onResult,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        ipdRepositoryProvider.overrideWithValue(ipdRepository),
        patientRepositoryProvider.overrideWithValue(patientRepository),
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
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              return Center(
                child: AppButton.primary(
                  label: 'Open start admission',
                  leadingIcon: AppActionIcons.add,
                  onPressed: () async {
                    await ref.read(ipdWorkspaceControllerProvider.future);
                    if (!context.mounted) {
                      return;
                    }
                    final bool? value = await showIpdStartAdmissionDialog(
                      context,
                      referenceData: _referenceData,
                    );
                    onResult?.call(value);
                  },
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open start admission'));
  await tester.pumpAndSettle();
}

void _stubWorkspaceLoad(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer(
    (Invocation invocation) async =>
        Result<AppPage<IpdAdmissionSummary>>.success(
          AppPage<IpdAdmissionSummary>(
            items: const <IpdAdmissionSummary>[],
            request: (invocation.positionalArguments.single as IpdAdmissionQuery)
                .pageRequest,
            totalItemCount: 0,
          ),
        ),
  );
  when(() => repository.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
  when(() => repository.listWards(search: any(named: 'search'))).thenAnswer(
    (_) async => const Result<List<IpdWardOption>>.success(
      <IpdWardOption>[
        IpdWardOption(id: 'ward-a', name: 'Ward A', wardType: 'GENERAL'),
      ],
    ),
  );
  when(
    () => repository.listBeds(
      search: any(named: 'search'),
      status: any(named: 'status'),
      wardId: any(named: 'wardId'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<IpdBedOption>>.success(
      <IpdBedOption>[
        IpdBedOption(
          id: 'bed-1',
          label: 'Bed 1',
          status: 'AVAILABLE',
          wardId: 'ward-a',
          wardName: 'Ward A',
          roomId: 'room-1',
          roomName: 'Room 1',
        ),
      ],
    ),
  );
  when(
    () => repository.listBedBoard(
      wardId: any(named: 'wardId'),
      status: any(named: 'status'),
      statusAny: any(named: 'statusAny'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<IpdBedBoardEntry>>.success(
      <IpdBedBoardEntry>[],
    ),
  );
}

void _stubPatientSearch(_MockPatientRepository repository) {
  when(() => repository.listPatients(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<Patient>>.success(
      AppPage<Patient>(
        items: const <Patient>[_patient],
        request: (invocation.positionalArguments.single as PatientListQuery)
            .pageRequest,
        totalItemCount: 1,
      ),
    ),
  );
}

Future<void> _selectPatient(WidgetTester tester) async {
  await tester.enterText(find.byType(EditableText).first, 'Ada');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(MenuItemButton),
          matching: find.textContaining('Ada Active'),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _selectSearchableOption(
  WidgetTester tester,
  int fieldIndex,
  String optionLabel,
) async {
  final Finder fieldFinder = find.byType(EditableText).at(fieldIndex);
  await tester.ensureVisible(fieldFinder);
  await tester.pumpAndSettle();
  await tester.tap(fieldFinder);
  await tester.pumpAndSettle();
  final Finder optionFinder = find
      .descendant(
        of: find.byType(MenuItemButton),
        matching: find.textContaining(optionLabel),
      )
      .first;
  await tester.ensureVisible(optionFinder);
  await tester.pumpAndSettle();
  await tester.tap(optionFinder);
  await tester.pumpAndSettle();
}

AppButton _button(WidgetTester tester, String label) {
  return tester.widget<AppButton>(
    find
        .ancestor(of: find.text(label), matching: find.byType(AppButton))
        .first,
  );
}
