import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_active_work_helpers.dart';

void main() {
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
}
