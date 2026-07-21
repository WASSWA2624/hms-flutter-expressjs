import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_appointment_eligibility.dart';

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

  test('matches open flow by unique patient when appointment id is absent', () {
    const OpdFlowSummary patientOnlyFlow = OpdFlowSummary(
      id: 'flow-2',
      patientId: 'PAT000001',
      status: 'OPEN',
      stage: 'WAITING_VITALS',
    );
    final OpdFlowSummary? linked = findActiveOpdFlowForAppointment(
      appointment: scheduled,
      flows: <OpdFlowSummary>[patientOnlyFlow],
    );
    expect(linked?.id, 'flow-2');
  });
}
