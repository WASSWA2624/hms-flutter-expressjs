import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_appointment_eligibility.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_board_next_action.dart';

void main() {
  const OpdAppointment scheduled = OpdAppointment(
    id: 'appointment-1',
    publicId: 'APT000001',
    patientId: 'PAT000001',
    status: 'SCHEDULED',
  );

  const OpdFlowSummary openFlow = OpdFlowSummary(
    id: 'flow-1',
    publicId: 'ENC000001',
    patientId: 'PAT000001',
    appointmentId: 'APT000001',
    status: 'OPEN',
    stage: 'WAITING_DOCTOR_REVIEW',
    displayCode: 'WITH_DOCTOR',
    displayStatus: 'With doctor',
  );

  final AppLocalizationsEn l10n = AppLocalizationsEn();

  test('prefers continue when an open OPD flow is linked', () {
    final OpdFlowSummary? linked = findActiveOpdFlowForAppointment(
      appointment: scheduled,
      flows: <OpdFlowSummary>[openFlow],
    );
    expect(linked?.id, 'flow-1');

    final OpdAppointmentPrimaryAction action =
        resolveOpdAppointmentPrimaryAction(
          appointment: scheduled,
          linkedFlow: linked,
        );
    expect(action, OpdAppointmentPrimaryAction.continueEncounter);
    expect(
      opdAppointmentPrimaryActionLabel(l10n, action),
      'Continue encounter',
    );
    expect(
      opdAppointmentCurrentStepLabel(
        l10n,
        appointment: scheduled,
        linkedFlow: linked,
      ),
      isNot(equals('Scheduled')),
    );
  });

  test('offers start when no open OPD flow exists', () {
    final OpdAppointmentPrimaryAction action =
        resolveOpdAppointmentPrimaryAction(
          appointment: scheduled,
          linkedFlow: null,
        );
    expect(action, OpdAppointmentPrimaryAction.startEncounter);
    expect(opdAppointmentPrimaryActionLabel(l10n, action), 'Start OPD encounter');
  });

  test('offers reschedule for in-progress appointments without an open flow', () {
    const OpdAppointment inProgress = OpdAppointment(
      id: 'appointment-1',
      publicId: 'APT000001',
      patientId: 'PAT000001',
      status: 'IN_PROGRESS',
    );
    final OpdAppointmentPrimaryAction action =
        resolveOpdAppointmentPrimaryAction(
          appointment: inProgress,
          linkedFlow: null,
        );
    expect(action, OpdAppointmentPrimaryAction.reschedule);
    expect(opdAppointmentPrimaryActionLabel(l10n, action), 'Reschedule');
  });

  const OpdFlowSummary patientOnlyFlow = OpdFlowSummary(
    id: 'flow-2',
    patientId: 'PAT000001',
    status: 'OPEN',
    stage: 'WAITING_VITALS',
  );

  test('matches open flow by unique patient when appointment id is absent', () {
    final OpdFlowSummary? linked = findActiveOpdFlowForAppointment(
      appointment: scheduled.copyWith(status: 'IN_PROGRESS'),
      flows: <OpdFlowSummary>[patientOnlyFlow],
    );
    expect(linked?.id, 'flow-2');
  });

  test('a still-scheduled booking is never claimed by an unrelated visit', () {
    // The patient walking in today does not turn next week's booking into an
    // encounter: only the server marking the appointment IN_PROGRESS does.
    expect(
      findActiveOpdFlowForAppointment(
        appointment: scheduled,
        flows: <OpdFlowSummary>[patientOnlyFlow],
      ),
      isNull,
    );
    expect(
      isReceptionPreEncounterAppointment(
        appointment: scheduled,
        flows: <OpdFlowSummary>[patientOnlyFlow],
      ),
      isTrue,
    );
    expect(
      canCancelOpdAppointment(
        appointment: scheduled,
        linkedFlow: findActiveOpdFlowForAppointment(
          appointment: scheduled,
          flows: <OpdFlowSummary>[patientOnlyFlow],
        ),
      ),
      isTrue,
    );
  });

  test('a visitor meeting is completed rather than checked in', () {
    const OpdAppointment visitorMeeting = OpdAppointment(
      id: 'appointment-2',
      publicId: 'APT000002',
      subjectType: 'VISITOR',
      visitorName: 'Jane Visitor',
      status: 'SCHEDULED',
    );
    final OpdAppointmentPrimaryAction action =
        resolveOpdAppointmentPrimaryAction(appointment: visitorMeeting);
    expect(action, OpdAppointmentPrimaryAction.complete);
    expect(opdAppointmentPrimaryActionLabel(l10n, action), 'Mark complete');
  });

  test('allows complete only before a terminal status or an open encounter', () {
    expect(canCompleteOpdAppointment(appointment: scheduled), isTrue);
    expect(
      canCompleteOpdAppointment(appointment: scheduled, linkedFlow: openFlow),
      isFalse,
    );
    expect(
      canCompleteOpdAppointment(
        appointment: scheduled.copyWith(status: 'COMPLETED'),
      ),
      isFalse,
    );
  });

  test('every primary action maps to its own worklist cell', () {
    expect(
      opdAppointmentNextActionKind(OpdAppointmentPrimaryAction.startEncounter),
      OpdBoardNextActionKind.checkInAppointment,
    );
    expect(
      opdAppointmentNextActionKind(
        OpdAppointmentPrimaryAction.continueEncounter,
      ),
      OpdBoardNextActionKind.continueAppointmentEncounter,
    );
    expect(
      opdAppointmentNextActionKind(OpdAppointmentPrimaryAction.reschedule),
      OpdBoardNextActionKind.rescheduleAppointment,
    );
    expect(
      opdAppointmentNextActionKind(OpdAppointmentPrimaryAction.complete),
      OpdBoardNextActionKind.completeAppointment,
    );
    expect(
      opdAppointmentNextActionKind(OpdAppointmentPrimaryAction.none),
      OpdBoardNextActionKind.none,
    );
  });

  test('allows cancel only for pre-encounter appointments', () {
    expect(canCancelOpdAppointment(appointment: scheduled), isTrue);
    expect(
      canCancelOpdAppointment(appointment: scheduled, linkedFlow: openFlow),
      isFalse,
    );
    expect(
      canCancelOpdAppointment(
        appointment: scheduled.copyWith(status: 'CANCELLED'),
      ),
      isFalse,
    );
  });

  test('reception appointments exclude rows with a linked active encounter', () {
    expect(
      isReceptionPreEncounterAppointment(
        appointment: scheduled,
        flows: const <OpdFlowSummary>[],
      ),
      isTrue,
    );
    expect(
      isReceptionPreEncounterAppointment(
        appointment: scheduled,
        flows: <OpdFlowSummary>[openFlow],
      ),
      isFalse,
    );
    expect(
      isReceptionPreEncounterAppointment(
        appointment: scheduled.copyWith(status: 'COMPLETED'),
        flows: const <OpdFlowSummary>[],
      ),
      isFalse,
    );
  });
}
