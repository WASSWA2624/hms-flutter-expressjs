import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_active_work_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('REQUESTED admission is active work but not treated as admitted', () {
    expect(isActivePatientAdmissionStatus('REQUESTED'), isTrue);
    expect(isPendingPatientAdmissionRequest('REQUESTED'), isTrue);
    expect(isPendingPatientAdmissionRequest('ADMITTED'), isFalse);
  });

  test('collectPatientActiveWorkItems includes REQUESTED admissions', () {
    final PatientDetail detail = PatientDetail(
      patient: const Patient(
        id: 'patient-1',
        tenantId: 'tenant-1',
        firstName: 'Amina',
        lastName: 'Demo',
      ),
      workspace: PatientWorkspaceSnapshot(
        admissions: <PatientSummaryRecord>[
          PatientSummaryRecord(
            id: 'ADM000001',
            kind: 'admission',
            status: 'REQUESTED',
            title: 'Admission',
            occurredAt: DateTime.utc(2026, 7, 2),
          ),
        ],
      ),
    );

    final List<PatientActiveWorkItem> items = collectPatientActiveWorkItems(
      detail,
    );

    expect(items, hasLength(1));
    expect(items.single.kind, PatientActiveWorkKind.admission);
    expect(items.single.status, 'REQUESTED');
  });

  test(
    'active work labels distinguish encounter and queue at same facility',
    () {
      const PatientActiveWorkItem encounter = PatientActiveWorkItem(
        id: 'enc-1',
        kind: PatientActiveWorkKind.encounter,
        status: 'OPEN',
        title: 'Jordan Demo',
      );
      const PatientActiveWorkItem queue = PatientActiveWorkItem(
        id: 'queue-1',
        kind: PatientActiveWorkKind.queue,
        status: 'IN_PROGRESS',
        title: 'Jordan Demo',
      );

      expect(
        patientActiveWorkKindLabel(l10n, encounter),
        l10n.patientsActiveWorkKindEncounter,
      );
      expect(
        patientActiveWorkKindLabel(l10n, queue),
        l10n.patientsActiveWorkKindQueue,
      );
      expect(
        patientActiveWorkStatusLabel(l10n, encounter),
        l10n.patientsActiveWorkStatusEncounterOpen,
      );
      expect(
        patientActiveWorkStatusLabel(l10n, queue),
        l10n.patientsActiveWorkStatusQueueInProgress,
      );
      expect(patientActiveWorkContextLabel(encounter), 'Jordan Demo');
      expect(patientActiveWorkContextLabel(queue), 'Jordan Demo');
    },
  );

  test('pending admission request uses admission request kind label', () {
    const PatientActiveWorkItem item = PatientActiveWorkItem(
      id: 'adm-1',
      kind: PatientActiveWorkKind.admission,
      status: 'REQUESTED',
      title: 'Jordan Demo',
    );

    expect(
      patientActiveWorkKindLabel(l10n, item),
      l10n.patientsActiveWorkKindAdmissionRequest,
    );
    expect(
      patientActiveWorkStatusLabel(l10n, item),
      l10n.opdStatusAdmissionPendingLabel,
    );
    expect(patientActiveWorkStatusTone(item), AppWorkspaceStatusTone.warning);
  });

  test('context label prefers subtitle and falls back to public id', () {
    const PatientActiveWorkItem withSubtitle = PatientActiveWorkItem(
      id: 'enc-1',
      kind: PatientActiveWorkKind.encounter,
      status: 'OPEN',
      title: 'Encounter',
      subtitle: 'Jordan Demo',
    );
    const PatientActiveWorkItem withRecordId = PatientActiveWorkItem(
      id: 'enc-2',
      kind: PatientActiveWorkKind.encounter,
      status: 'OPEN',
      title: 'Encounter',
      sourceRecord: PatientSummaryRecord(
        id: 'ENC0000001',
        kind: 'encounter',
        status: 'OPEN',
      ),
    );

    expect(patientActiveWorkContextLabel(withSubtitle), 'Jordan Demo');
    expect(patientActiveWorkContextLabel(withRecordId), 'ENC0000001');
  });
}
