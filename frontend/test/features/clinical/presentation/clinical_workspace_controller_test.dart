import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/clinical/presentation/controllers/clinical_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockIpdRepository extends Mock implements IpdRepository {}

IpdAdmissionDetail _detail(IpdAdmissionSummary summary) {
  return IpdAdmissionDetail(summary: summary);
}

IpdAdmissionSummary _ipdSummary({
  String id = 'adm-uuid-1',
  String displayId = 'ADM000001',
  String encounterId = 'enc-ipd-1',
  String stage = 'ADMITTED_IN_BED',
  String admissionStatus = 'ADMITTED',
}) {
  return IpdAdmissionSummary(
    id: id,
    displayId: displayId,
    patientId: 'pat-ipd-1',
    patientDisplayName: 'Jane Inpatient',
    encounterId: encounterId,
    stage: stage,
    nextStep: 'RECORD_NURSING_NOTE',
    wardDisplayName: 'Ward A',
    bedDisplayLabel: 'Bed 1',
    admittedAt: DateTime.utc(2026, 6, 25, 8),
    admissionStatus: admissionStatus,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const ClinicalWorklistQuery());
    registerFallbackValue(
      const ClinicalWorklistEntry(
        id: 'fallback',
        sourceQueue: 'ENCOUNTER',
        encounterId: 'fallback',
      ),
    );
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  ProviderContainer buildContainer({
    required _MockClinicalRepository clinical,
    required _MockOpdRepository opd,
    required _MockIpdRepository ipd,
    List<ClinicalWorklistEntry> encounters = const <ClinicalWorklistEntry>[],
    List<IpdAdmissionSummary> ipdAdmissions = const <IpdAdmissionSummary>[],
  }) {
    when(() => clinical.listEncounters(any())).thenAnswer(
      (invocation) async => Result<AppPage<ClinicalWorklistEntry>>.success(
        AppPage<ClinicalWorklistEntry>(
          items: encounters,
          request:
              (invocation.positionalArguments.single as ClinicalWorklistQuery)
                  .pageRequest,
          totalItemCount: encounters.length,
        ),
      ),
    );
    when(clinical.loadReferenceData).thenAnswer(
      (_) async =>
          const Result<ClinicalReferenceData>.success(ClinicalReferenceData()),
    );
    when(() => clinical.loadEncounterBundle(any())).thenAnswer((invocation) {
      final ClinicalWorklistEntry entry =
          invocation.positionalArguments.single as ClinicalWorklistEntry;
      return Future<Result<ClinicalEncounterBundle>>.value(
        Result<ClinicalEncounterBundle>.success(
          ClinicalEncounterBundle(entry: entry),
        ),
      );
    });

    when(() => opd.listOpdFlows(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: const <OpdFlowSummary>[],
          request: (invocation.positionalArguments.single as OpdFlowQuery)
              .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
    when(() => opd.listTriageQueue(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: const <OpdFlowSummary>[],
          request:
              (invocation.positionalArguments.single as OpdTriageQueueQuery)
                  .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
    when(() => opd.getOpdFlow(any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.success(
        OpdFlowDetail(
          summary: OpdFlowSummary(id: 'flow-stub', publicId: 'OPD-STUB'),
        ),
      ),
    );

    when(() => ipd.listAdmissions(any())).thenAnswer(
      (invocation) async => Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: ipdAdmissions,
          request: (invocation.positionalArguments.single as IpdAdmissionQuery)
              .pageRequest,
          totalItemCount: ipdAdmissions.length,
        ),
      ),
    );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        clinicalRepositoryProvider.overrideWithValue(clinical),
        opdRepositoryProvider.overrideWithValue(opd),
        ipdRepositoryProvider.overrideWithValue(ipd),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  ClinicalWorkspaceState? readState(ProviderContainer container) {
    return container
        .read(clinicalWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (ClinicalWorkspaceState value) => value,
          failure: (_) => null,
        );
  }

  test('excludes ipd admissions from the clinical worklist', () async {
    final _MockClinicalRepository clinical = _MockClinicalRepository();
    final _MockOpdRepository opd = _MockOpdRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      clinical: clinical,
      opd: opd,
      ipd: ipd,
      ipdAdmissions: <IpdAdmissionSummary>[_ipdSummary()],
    );

    await container.read(clinicalWorkspaceControllerProvider.future);

    final ClinicalWorkspaceState? state = readState(container);
    expect(state, isNotNull);
    expect(
      state!.worklist.items.where(
        (ClinicalWorklistEntry item) => item.sourceQueue == 'IPD',
      ),
      isEmpty,
    );

    verifyNever(() => clinical.listAdmissions(any()));
    verifyNever(() => ipd.listAdmissions(any()));
  });

  test('active inpatient discharge plans discharge via ipd-flows', () async {
    final _MockClinicalRepository clinical = _MockClinicalRepository();
    final _MockOpdRepository opd = _MockOpdRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      clinical: clinical,
      opd: opd,
      ipd: ipd,
    );
    when(() => ipd.planDischarge(any(), any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.success(_detail(_ipdSummary())),
    );

    await container.read(clinicalWorkspaceControllerProvider.future);
    final ClinicalWorkspaceController controller = container.read(
      clinicalWorkspaceControllerProvider.notifier,
    );

    const ClinicalWorklistEntry entry = ClinicalWorklistEntry(
      id: 'IPD_adm-uuid-1',
      sourceQueue: 'IPD',
      encounterId: 'enc-ipd-1',
      patientId: 'pat-ipd-1',
      status: 'ADMITTED',
      stage: 'ADMITTED_IN_BED',
      currentLocation: 'Ward A | Bed 1',
      admissionId: 'adm-uuid-1',
      admissionPublicId: 'ADM000001',
    );
    await controller.selectEntry(entry);

    final AppFailure? failure = await controller.completeDisposition(
      reason: 'Recovered',
    );
    expect(failure, isNull);

    final List<Object?> captured = verify(
      () => ipd.planDischarge('ADM000001', captureAny()),
    ).captured;
    expect(
      (captured.single as Map<String, Object?>)['summary'],
      contains('Recovered'),
    );
    verifyNever(() => ipd.finalizeDischarge(any(), any()));
  });

  test(
    'discharge-planned inpatient finalizes discharge via ipd-flows',
    () async {
      final _MockClinicalRepository clinical = _MockClinicalRepository();
      final _MockOpdRepository opd = _MockOpdRepository();
      final _MockIpdRepository ipd = _MockIpdRepository();
      final ProviderContainer container = buildContainer(
        clinical: clinical,
        opd: opd,
        ipd: ipd,
      );
      when(() => ipd.finalizeDischarge(any(), any())).thenAnswer(
        (_) async => Result<IpdAdmissionDetail>.success(
          _detail(
            _ipdSummary(stage: 'DISCHARGED', admissionStatus: 'DISCHARGED'),
          ),
        ),
      );

      await container.read(clinicalWorkspaceControllerProvider.future);
      final ClinicalWorkspaceController controller = container.read(
        clinicalWorkspaceControllerProvider.notifier,
      );

      const ClinicalWorklistEntry entry = ClinicalWorklistEntry(
        id: 'IPD_adm-uuid-1',
        sourceQueue: 'IPD',
        encounterId: 'enc-ipd-1',
        patientId: 'pat-ipd-1',
        status: 'ADMITTED',
        stage: 'DISCHARGE_PLANNED',
        admissionId: 'adm-uuid-1',
        admissionPublicId: 'ADM000001',
      );
      await controller.selectEntry(entry);

      final AppFailure? failure = await controller.completeDisposition(
        reason: 'Clearance complete',
      );
      expect(failure, isNull);

      verify(() => ipd.finalizeDischarge('ADM000001', any())).called(1);
      verifyNever(() => ipd.planDischarge(any(), any()));
    },
  );

  test('requestAdmission routes through ipd-flows request endpoint', () async {
    final _MockClinicalRepository clinical = _MockClinicalRepository();
    final _MockOpdRepository opd = _MockOpdRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      clinical: clinical,
      opd: opd,
      ipd: ipd,
    );
    when(() => ipd.requestAdmission(any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.success(_detail(_ipdSummary())),
    );

    await container.read(clinicalWorkspaceControllerProvider.future);
    final ClinicalWorkspaceController controller = container.read(
      clinicalWorkspaceControllerProvider.notifier,
    );

    const ClinicalWorklistEntry entry = ClinicalWorklistEntry(
      id: 'encounter-1',
      sourceQueue: 'ENCOUNTER',
      encounterId: 'enc-1',
      encounterPublicId: 'ENC000001',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      patientId: 'pat-1',
      patientPublicId: 'PAT000001',
      status: 'OPEN',
      stage: 'WAITING_DISPOSITION',
    );
    await controller.selectEntry(entry);

    final AppFailure? failure = await controller.requestAdmission(
      reason: 'Needs inpatient monitoring',
      notes: 'From clinical workspace',
    );
    expect(failure, isNull);

    final List<Object?> captured = verify(
      () => ipd.requestAdmission(captureAny()),
    ).captured;
    final Map<String, Object?> payload =
        captured.single as Map<String, Object?>;
    expect(payload['patient_id'], 'PAT000001');
    expect(payload['encounter_id'], 'ENC000001');
    expect(payload['reason'], 'Needs inpatient monitoring');
    expect(payload['notes'], 'From clinical workspace');
    expect(payload.containsKey('bed_id'), isFalse);
    verifyNever(() => ipd.startAdmission(any()));
    verifyNever(() => clinical.createAdmission(any()));
  });

  test('recordEncounterVitals posts OPD record-vitals payload', () async {
    final _MockClinicalRepository clinical = _MockClinicalRepository();
    final _MockOpdRepository opd = _MockOpdRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      clinical: clinical,
      opd: opd,
      ipd: ipd,
    );

    const OpdFlowDetail flowDetail = OpdFlowDetail(
      summary: OpdFlowSummary(id: 'flow-1', publicId: 'OPD000001'),
    );
    when(() => opd.getOpdFlow(any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.success(flowDetail),
    );
    when(() => opd.recordVitals(any(), any())).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.success(flowDetail),
    );

    await container.read(clinicalWorkspaceControllerProvider.future);
    final ClinicalWorkspaceController controller = container.read(
      clinicalWorkspaceControllerProvider.notifier,
    );

    const ClinicalWorklistEntry entry = ClinicalWorklistEntry(
      id: 'encounter-1',
      sourceQueue: 'OPD',
      encounterId: 'enc-1',
      encounterPublicId: 'ENC000001',
      opdFlowApiId: 'OPD000001',
      status: 'OPEN',
      stage: 'WAITING_VITALS',
      nextStep: 'RECORD_VITALS',
    );
    await controller.selectEntry(entry);

    final AppFailure? failure = await controller.recordEncounterVitals(
      vitals: <Map<String, Object?>>[
        <String, Object?>{
          'vital_type': 'TEMPERATURE',
          'value': 37.1,
          'unit': 'C',
        },
      ],
    );
    expect(failure, isNull);

    final List<Object?> captured = verify(
      () => opd.recordVitals('OPD000001', captureAny()),
    ).captured;
    final Map<String, Object?> payload = captured.single as Map<String, Object?>;
    expect(payload['vitals'], isA<List<Object?>>());
    expect(payload.containsKey('update_existing'), isFalse);

    final AppFailure? updateFailure = await controller.recordEncounterVitals(
      vitals: <Map<String, Object?>>[
        <String, Object?>{
          'vital_type': 'HEART_RATE',
          'value': 80,
          'unit': 'bpm',
        },
      ],
      updateExisting: true,
    );
    expect(updateFailure, isNull);
    final List<Object?> updateCaptured = verify(
      () => opd.recordVitals('OPD000001', captureAny()),
    ).captured;
    expect(
      (updateCaptured.last as Map<String, Object?>)['update_existing'],
      isTrue,
    );
  });

  test(
    'addDiagnosis blocks encounter duplicates and updateDiagnosis uses UUID',
    () async {
      final _MockClinicalRepository clinical = _MockClinicalRepository();
      final _MockOpdRepository opd = _MockOpdRepository();
      final _MockIpdRepository ipd = _MockIpdRepository();

      const ClinicalWorklistEntry entry = ClinicalWorklistEntry(
        id: 'enc-1',
        sourceQueue: 'ENCOUNTER',
        encounterId: 'enc-uuid-1',
        patientId: 'pat-1',
        status: 'IN_CONSULTATION',
      );

      when(() => clinical.createDiagnosis(any())).thenAnswer(
        (_) async => const Result<void>.success(null),
      );
      when(() => clinical.updateDiagnosis(any(), any())).thenAnswer(
        (_) async => const Result<void>.success(null),
      );
      when(() => clinical.createClinicalTermFavorite(any())).thenAnswer(
        (_) async => const Result<void>.success(null),
      );

      final ProviderContainer container = buildContainer(
        clinical: clinical,
        opd: opd,
        ipd: ipd,
        encounters: const <ClinicalWorklistEntry>[entry],
      );

      when(() => clinical.loadEncounterBundle(any())).thenAnswer((_) async {
        return const Result<ClinicalEncounterBundle>.success(
          ClinicalEncounterBundle(
            entry: entry,
            diagnoses: <ClinicalRelatedRecord>[
              ClinicalRelatedRecord(
                id: 'dx-uuid-existing',
                kind: 'diagnosis',
                title: 'Malaria',
                diagnosisType: 'PRIMARY',
                code: 'B54',
              ),
            ],
          ),
        );
      });

      await container.read(clinicalWorkspaceControllerProvider.future);
      final ClinicalWorkspaceController controller = container.read(
        clinicalWorkspaceControllerProvider.notifier,
      );
      await controller.selectEntry(entry);

      final AppFailure? duplicateFailure = await controller.addDiagnosis(
        diagnosisType: 'SECONDARY',
        diagnoses: const <ClinicalCatalogOption>[
          ClinicalActionCatalogOption(
            id: 'catalog-malaria',
            name: 'Malaria',
            code: 'B54',
          ),
        ],
      );
      expect(duplicateFailure, isA<AppFailure>());
      verifyNever(() => clinical.createDiagnosis(any()));

      final AppFailure? updateFailure = await controller.updateDiagnosis(
        diagnosisId: 'dx-uuid-existing',
        diagnosisType: 'DIFFERENTIAL',
      );
      expect(updateFailure, isNull);
      verify(
        () => clinical.updateDiagnosis(
          'dx-uuid-existing',
          any(that: containsPair('diagnosis_type', 'DIFFERENTIAL')),
        ),
      ).called(1);
    },
  );

  test('cancelLabOrderItem rejects sibling test and cancels sole item via order',
      () async {
    final _MockClinicalRepository clinical = _MockClinicalRepository();
    final _MockOpdRepository opd = _MockOpdRepository();
    final _MockIpdRepository ipd = _MockIpdRepository();

    const ClinicalWorklistEntry entry = ClinicalWorklistEntry(
      id: 'enc-lab-1',
      sourceQueue: 'ENCOUNTER',
      encounterId: 'enc-uuid-lab',
      patientId: 'pat-1',
      status: 'IN_CONSULTATION',
    );

    when(() => clinical.cancelLabOrderItem(any(), reason: any(named: 'reason')))
        .thenAnswer((_) async => const Result<void>.success(null));
    when(() => clinical.updateLabOrder(any(), any())).thenAnswer(
      (_) async => const Result<void>.success(null),
    );

    final ProviderContainer container = buildContainer(
      clinical: clinical,
      opd: opd,
      ipd: ipd,
      encounters: const <ClinicalWorklistEntry>[entry],
    );

    when(() => clinical.loadEncounterBundle(any())).thenAnswer((_) async {
      return const Result<ClinicalEncounterBundle>.success(
        ClinicalEncounterBundle(entry: entry),
      );
    });

    await container.read(clinicalWorkspaceControllerProvider.future);
    final ClinicalWorkspaceController controller = container.read(
      clinicalWorkspaceControllerProvider.notifier,
    );
    await controller.selectEntry(entry);

    const ClinicalLabOrderItem amy = ClinicalLabOrderItem(
      id: 'ITEM-AMY',
      status: 'ORDERED',
      testDisplayName: 'Amylase',
    );
    const ClinicalLabOrderItem lip = ClinicalLabOrderItem(
      id: 'ITEM-LIP',
      status: 'ORDERED',
      testDisplayName: 'Lipase',
    );

    final AppFailure? itemFailure = await controller.cancelLabOrderItem(
      labOrderId: 'LAB-1',
      item: amy,
      orderItems: const <ClinicalLabOrderItem>[amy, lip],
      reason: 'Cancelled from clinical workspace',
    );
    expect(itemFailure, isNull);
    verify(
      () => clinical.cancelLabOrderItem(
        'ITEM-AMY',
        reason: 'Cancelled from clinical workspace',
      ),
    ).called(1);
    verifyNever(() => clinical.updateLabOrder(any(), any()));

    final AppFailure? soleFailure = await controller.cancelLabOrderItem(
      labOrderId: 'LAB-1',
      item: lip,
      orderItems: const <ClinicalLabOrderItem>[lip],
      reason: 'Cancelled from clinical workspace',
    );
    expect(soleFailure, isNull);
    verify(
      () => clinical.updateLabOrder(
        'LAB-1',
        any(that: containsPair('status', 'CANCELLED')),
      ),
    ).called(1);
  });
}
