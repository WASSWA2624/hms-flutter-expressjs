import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/shell_badge_counts.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  final DateTime now = DateTime(2026, 7, 19, 13);

  test('Reception badge counts unique patients across all four sections', () {
    final OpdWorkspaceState state = _state(
      appointments: const <OpdAppointment>[
        OpdAppointment(
          id: 'appointment-1',
          patientId: 'patient-1',
          patientIdentifier: 'MRN-1',
          status: 'SCHEDULED',
        ),
        OpdAppointment(
          id: 'appointment-terminal',
          patientId: 'patient-terminal',
          status: 'COMPLETED',
        ),
      ],
      queueEntries: const <OpdQueueEntry>[
        OpdQueueEntry(
          id: 'queue-1',
          patientIdentifier: 'MRN-1',
          appointmentId: 'appointment-1',
          status: 'WAITING',
        ),
        OpdQueueEntry(id: 'queue-3', patientId: 'patient-3', status: 'WAITING'),
      ],
      flows: <OpdFlowSummary>[
        OpdFlowSummary(
          id: 'active-1',
          patientId: 'patient-1',
          status: 'OPEN',
          startedAt: now,
          stage: 'WAITING_VITALS',
        ),
        OpdFlowSummary(
          id: 'payment-2',
          patientId: 'patient-2',
          status: 'OPEN',
          startedAt: now,
          stage: 'WAITING_CONSULTATION_PAYMENT',
        ),
        OpdFlowSummary(
          id: 'old-payment-4',
          patientId: 'patient-4',
          status: 'OPEN',
          startedAt: now.subtract(const Duration(days: 1)),
          stage: 'WAITING_CONSULTATION_PAYMENT',
        ),
        OpdFlowSummary(
          id: 'closed-5',
          patientId: 'patient-5',
          status: 'CLOSED',
          startedAt: now,
          stage: 'WAITING_DOCTOR_REVIEW',
        ),
      ],
    );

    expect(receptionPatientBadgeCount(state, now: now), 4);
  });

  test('Reception badge joins records through appointment and queue links', () {
    final OpdWorkspaceState state = _state(
      appointments: const <OpdAppointment>[
        OpdAppointment(id: 'appointment-1', status: 'SCHEDULED'),
      ],
      queueEntries: const <OpdQueueEntry>[
        OpdQueueEntry(
          id: 'queue-1',
          appointmentId: 'appointment-1',
          status: 'WAITING',
        ),
      ],
      flows: <OpdFlowSummary>[
        OpdFlowSummary(
          id: 'flow-1',
          visitQueueId: 'queue-1',
          status: 'OPEN',
          startedAt: now,
          stage: 'CONSULTATION_IN_PROGRESS',
        ),
      ],
    );

    expect(receptionPatientBadgeCount(state, now: now), 1);
  });

  test('Reception badge is absent when every section is empty', () {
    expect(
      receptionPatientBadgeCount(OpdWorkspaceState.empty(), now: now),
      null,
    );
  });

  test('Reception badge ignores unauthorized sections', () {
    final OpdWorkspaceState state = _state(
      appointments: const <OpdAppointment>[
        OpdAppointment(
          id: 'appointment-1',
          patientId: 'patient-1',
          status: 'SCHEDULED',
        ),
      ],
      queueEntries: const <OpdQueueEntry>[
        OpdQueueEntry(id: 'queue-2', patientId: 'patient-2', status: 'WAITING'),
      ],
      flows: <OpdFlowSummary>[
        OpdFlowSummary(
          id: 'active-3',
          patientId: 'patient-3',
          status: 'OPEN',
          startedAt: now,
          stage: 'WAITING_VITALS',
        ),
        OpdFlowSummary(
          id: 'payment-4',
          patientId: 'patient-4',
          status: 'OPEN',
          startedAt: now,
          stage: 'WAITING_CONSULTATION_PAYMENT',
        ),
      ],
    );

    expect(
      receptionPatientBadgeCount(
        state,
        now: now,
        sections: <ReceptionDeskSection>{ReceptionDeskSection.appointments},
      ),
      1,
    );
  });

  test('Reception badge excludes terminal payment-gate stages', () {
    final OpdWorkspaceState state = _state(
      flows: <OpdFlowSummary>[
        OpdFlowSummary(
          id: 'closed-payment',
          patientId: 'patient-closed',
          status: 'CLOSED',
          startedAt: now,
          stage: 'WAITING_CONSULTATION_PAYMENT',
        ),
      ],
    );

    expect(receptionPatientBadgeCount(state, now: now), null);
  });
}

OpdWorkspaceState _state({
  List<OpdAppointment> appointments = const <OpdAppointment>[],
  List<OpdQueueEntry> queueEntries = const <OpdQueueEntry>[],
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[],
}) {
  return OpdWorkspaceState.empty().copyWith(
    appointments: AppPage<OpdAppointment>(
      items: appointments,
      request: const AppPageRequest(),
    ),
    queueEntries: AppPage<OpdQueueEntry>(
      items: queueEntries,
      request: const AppPageRequest(),
    ),
    flows: AppPage<OpdFlowSummary>(
      items: flows,
      request: const AppPageRequest(),
    ),
  );
}
