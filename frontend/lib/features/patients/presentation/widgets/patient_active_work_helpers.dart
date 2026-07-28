import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';

enum PatientActiveWorkKind {
  appointment,
  encounter,
  queue,
  admission,
  labOrder,
  radiologyOrder,
  therapy,
  theater,
}

final class PatientActiveWorkItem {
  const PatientActiveWorkItem({
    required this.id,
    required this.kind,
    required this.status,
    required this.title,
    this.subtitle,
    this.occurredAt,
    this.sourceRecord,
    this.timelineItem,
  });

  final String id;
  final PatientActiveWorkKind kind;
  final String status;
  final String title;
  final String? subtitle;
  final DateTime? occurredAt;
  final PatientSummaryRecord? sourceRecord;
  final PatientTimelineItem? timelineItem;
}

bool isActivePatientAppointment(PatientSummaryRecord record) {
  return record.id.trim().isNotEmpty && !isOpdTerminalStatus(record.status);
}

bool isActivePatientEncounter(PatientSummaryRecord record) {
  if (record.id.trim().isEmpty) {
    return false;
  }
  final String status = (record.status ?? '').toUpperCase();
  return !isOpdTerminalStatus(status) && status != 'PAID';
}

bool isActivePatientQueueEntry(PatientSummaryRecord record) {
  return record.id.trim().isNotEmpty && !isOpdTerminalStatus(record.status);
}

bool isActivePatientAdmissionStatus(String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'REQUESTED' ||
    'ACTIVE' ||
    'ADMITTED' ||
    'ADMITTED_PENDING_BED' ||
    'ADMITTED_IN_BED' ||
    'TRANSFER_REQUESTED' ||
    'TRANSFER_IN_PROGRESS' ||
    'DISCHARGE_PLANNED' => true,
    _ => false,
  };
}

bool isPendingPatientAdmissionRequest(String? status) {
  return (status ?? '').trim().toUpperCase() == 'REQUESTED';
}

bool isActivePatientAdmission(PatientSummaryRecord record) {
  return record.id.trim().isNotEmpty &&
      isActivePatientAdmissionStatus(record.status);
}

bool isActiveOpdPatientVisit(PatientVisitContext? visit) {
  if (visit == null) {
    return false;
  }
  final String title = (visit.title ?? '').toUpperCase();
  final String status = (visit.status ?? '').toUpperCase();
  return visit.kind == 'encounter' &&
      (title.contains('OPD') || title.contains('EMERGENCY')) &&
      !isOpdTerminalStatus(status);
}

bool isActiveAdmissionPatientVisit(PatientVisitContext? visit) {
  return visit?.kind == 'admission' &&
      (visit?.publicId ?? '').trim().isNotEmpty &&
      isActivePatientAdmissionStatus(visit?.status);
}

PatientSummaryRecord? activePatientAdmissionRecord(
  Iterable<PatientSummaryRecord> admissions,
) {
  for (final PatientSummaryRecord admission in admissions) {
    if (isActivePatientAdmission(admission)) {
      return admission;
    }
  }
  return null;
}

bool _isActiveTimelineResource(String resource) {
  return switch (resource.toLowerCase()) {
    'lab_order' ||
    'radiology_order' ||
    'therapy_episode' ||
    'therapy' ||
    'physiotherapy' ||
    'theater_case' ||
    'theater' => true,
    _ => false,
  };
}

bool _isTerminalTimelineStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' || 'CANCELLED' || 'CLOSED' || 'NO_SHOW' || 'DISCHARGED' => true,
    _ => false,
  };
}

PatientActiveWorkKind _timelineKind(String resource) {
  return switch (resource.toLowerCase()) {
    'lab_order' => PatientActiveWorkKind.labOrder,
    'radiology_order' => PatientActiveWorkKind.radiologyOrder,
    'theater_case' || 'theater' => PatientActiveWorkKind.theater,
    _ => PatientActiveWorkKind.therapy,
  };
}

List<PatientActiveWorkItem> collectPatientActiveWorkItems(
  PatientDetail detail,
) {
  final List<PatientActiveWorkItem> items = <PatientActiveWorkItem>[];
  final Set<String> seen = <String>{};

  void addItem(PatientActiveWorkItem item) {
    final String key = '${item.kind.name}:${item.id}';
    if (seen.add(key)) {
      items.add(item);
    }
  }

  for (final PatientSummaryRecord record in detail.workspace.appointments) {
    if (!isActivePatientAppointment(record)) {
      continue;
    }
    addItem(
      PatientActiveWorkItem(
        id: record.id,
        kind: PatientActiveWorkKind.appointment,
        status: record.status ?? '',
        title: record.title ?? 'Appointment',
        subtitle: record.subtitle,
        occurredAt: record.occurredAt,
        sourceRecord: record,
      ),
    );
  }

  for (final PatientSummaryRecord record in detail.workspace.encounters) {
    if (!isActivePatientEncounter(record)) {
      continue;
    }
    addItem(
      PatientActiveWorkItem(
        id: record.id,
        kind: PatientActiveWorkKind.encounter,
        status: isActiveOpdPatientVisit(detail.patient.currentVisit)
            ? detail.patient.currentVisit?.status ?? record.status ?? ''
            : record.status ?? '',
        title: record.title ?? 'Encounter',
        subtitle: record.subtitle,
        occurredAt: record.occurredAt,
        sourceRecord: record,
      ),
    );
  }

  for (final PatientSummaryRecord record in detail.workspace.queueEntries) {
    if (!isActivePatientQueueEntry(record)) {
      continue;
    }
    addItem(
      PatientActiveWorkItem(
        id: record.id,
        kind: PatientActiveWorkKind.queue,
        status: record.status ?? '',
        title: record.title ?? 'Visit queue',
        subtitle: record.subtitle,
        occurredAt: record.occurredAt,
        sourceRecord: record,
      ),
    );
  }

  for (final PatientSummaryRecord record in detail.workspace.admissions) {
    if (!isActivePatientAdmission(record)) {
      continue;
    }
    addItem(
      PatientActiveWorkItem(
        id: record.id,
        kind: PatientActiveWorkKind.admission,
        status: record.status ?? '',
        title: record.title ?? 'Admission',
        subtitle: record.subtitle,
        occurredAt: record.occurredAt,
        sourceRecord: record,
      ),
    );
  }

  final PatientVisitContext? admissionVisit = detail.patient.currentVisit;
  if (admissionVisit != null && isActiveAdmissionPatientVisit(admissionVisit)) {
    final String visitId = (admissionVisit.publicId ?? '').trim();
    if (visitId.isNotEmpty) {
      addItem(
        PatientActiveWorkItem(
          id: visitId,
          kind: PatientActiveWorkKind.admission,
          status: admissionVisit.status ?? '',
          title: admissionVisit.title ?? 'Admission',
          occurredAt: admissionVisit.occurredAt,
        ),
      );
    }
  }

  for (final PatientTimelineItem timelineItem in detail.timeline) {
    if (!_isActiveTimelineResource(timelineItem.resource) ||
        _isTerminalTimelineStatus(timelineItem.subtitle)) {
      continue;
    }
    addItem(
      PatientActiveWorkItem(
        id: timelineItem.id,
        kind: _timelineKind(timelineItem.resource),
        status: timelineItem.subtitle ?? '',
        title: timelineItem.title ?? timelineItem.resource,
        occurredAt: timelineItem.occurredAt,
        timelineItem: timelineItem,
      ),
    );
  }

  items.sort((PatientActiveWorkItem a, PatientActiveWorkItem b) {
    final DateTime? left = a.occurredAt;
    final DateTime? right = b.occurredAt;
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return right.compareTo(left);
  });

  return items;
}

bool patientHasOpenAppointment(PatientDetail detail) {
  return detail.workspace.appointments.any(isActivePatientAppointment);
}

bool patientHasPendingLabRequest(PatientDetail detail) {
  return collectPatientActiveWorkItems(detail).any(
    (PatientActiveWorkItem item) => item.kind == PatientActiveWorkKind.labOrder,
  );
}

bool patientHasPendingRadiologyRequest(PatientDetail detail) {
  return collectPatientActiveWorkItems(detail).any(
    (PatientActiveWorkItem item) =>
        item.kind == PatientActiveWorkKind.radiologyOrder,
  );
}

bool patientHasPendingTherapyRequest(PatientDetail detail) {
  return collectPatientActiveWorkItems(detail).any(
    (PatientActiveWorkItem item) => item.kind == PatientActiveWorkKind.therapy,
  );
}

bool patientHasPendingTheaterCase(PatientDetail detail) {
  return collectPatientActiveWorkItems(detail).any(
    (PatientActiveWorkItem item) => item.kind == PatientActiveWorkKind.theater,
  );
}

bool isGenericPatientActiveWorkTitle(String title) {
  final String normalized = title.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == 'appointment' ||
      normalized == 'encounter' ||
      normalized == 'visit queue' ||
      normalized == 'admission' ||
      normalized == 'lab_order' ||
      normalized == 'radiology_order' ||
      normalized == 'therapy' ||
      normalized == 'therapy_episode' ||
      normalized == 'physiotherapy' ||
      normalized == 'theater' ||
      normalized == 'theater_case';
}

String patientActiveWorkKindLabel(
  AppLocalizations l10n,
  PatientActiveWorkItem item,
) {
  if (item.kind == PatientActiveWorkKind.admission &&
      isPendingPatientAdmissionRequest(item.status)) {
    return l10n.patientsActiveWorkKindAdmissionRequest;
  }

  return switch (item.kind) {
    PatientActiveWorkKind.appointment => l10n.patientsActiveWorkKindAppointment,
    PatientActiveWorkKind.encounter => l10n.patientsActiveWorkKindEncounter,
    PatientActiveWorkKind.queue => l10n.patientsActiveWorkKindQueue,
    PatientActiveWorkKind.admission => l10n.patientsActiveWorkKindAdmission,
    PatientActiveWorkKind.labOrder => l10n.patientsActiveWorkKindLabOrder,
    PatientActiveWorkKind.radiologyOrder =>
      l10n.patientsActiveWorkKindRadiologyOrder,
    PatientActiveWorkKind.therapy => l10n.patientsActiveWorkKindTherapy,
    PatientActiveWorkKind.theater => l10n.patientsActiveWorkKindTheater,
  };
}

String patientActiveWorkContextLabel(PatientActiveWorkItem item) {
  final String subtitle = item.subtitle?.trim() ?? '';
  final String title = item.title.trim();

  if (subtitle.isNotEmpty && subtitle.toLowerCase() != title.toLowerCase()) {
    return subtitle;
  }
  if (title.isNotEmpty && !isGenericPatientActiveWorkTitle(title)) {
    return title;
  }

  final String? sourceId = item.sourceRecord?.id.trim();
  if (sourceId != null && sourceId.isNotEmpty) {
    return sourceId;
  }

  final String? timelineId = item.timelineItem?.id.trim();
  if (timelineId != null && timelineId.isNotEmpty) {
    return timelineId;
  }

  return subtitle;
}

String patientActiveWorkStatusLabel(
  AppLocalizations l10n,
  PatientActiveWorkItem item,
) {
  if (item.kind == PatientActiveWorkKind.admission &&
      isPendingPatientAdmissionRequest(item.status)) {
    return l10n.opdStatusAdmissionPendingLabel;
  }

  final String status = item.status.trim().toUpperCase();
  if (status.isEmpty) {
    return '';
  }

  return switch (item.kind) {
    PatientActiveWorkKind.encounter => switch (status) {
      'OPEN' => l10n.patientsActiveWorkStatusEncounterOpen,
      'IN_PROGRESS' => l10n.patientsActiveWorkStatusEncounterInProgress,
      _ => opdStageDisplayLabel(l10n, item.status),
    },
    PatientActiveWorkKind.queue => switch (status) {
      'OPEN' => l10n.patientsActiveWorkStatusQueueWaiting,
      'IN_PROGRESS' => l10n.patientsActiveWorkStatusQueueInProgress,
      _ => AppDisplay.apiLabel(item.status),
    },
    PatientActiveWorkKind.appointment => switch (status) {
      'OPEN' => l10n.patientsActiveWorkStatusAppointmentScheduled,
      'IN_PROGRESS' => l10n.patientsActiveWorkStatusAppointmentInProgress,
      _ => AppDisplay.apiLabel(item.status),
    },
    PatientActiveWorkKind.admission => switch (status) {
      'ACTIVE' ||
      'ADMITTED' ||
      'ADMITTED_IN_BED' => l10n.patientsActiveWorkStatusAdmissionActive,
      'ADMITTED_PENDING_BED' =>
        l10n.patientsActiveWorkStatusAdmissionPendingBed,
      'TRANSFER_REQUESTED' ||
      'TRANSFER_IN_PROGRESS' => l10n.patientsActiveWorkStatusAdmissionTransfer,
      'DISCHARGE_PLANNED' =>
        l10n.patientsActiveWorkStatusAdmissionDischargePlanned,
      _ => AppDisplay.apiLabel(item.status),
    },
    _ => AppDisplay.apiLabel(item.status),
  };
}

String patientActiveWorkNextStepLabel(
  AppLocalizations l10n,
  PatientActiveWorkItem item,
) {
  return switch (item.kind) {
    PatientActiveWorkKind.appointment => l10n.patientsActiveWorkNextAppointment,
    PatientActiveWorkKind.encounter =>
      _opdNextStepDescriptionForStatus(l10n, item.status) ??
          l10n.patientsActiveWorkNextEncounter,
    PatientActiveWorkKind.queue =>
      _opdNextStepDescriptionForStatus(l10n, item.status) ??
          l10n.patientsActiveWorkNextQueue,
    PatientActiveWorkKind.admission => _admissionNextStepDescription(
      l10n,
      item.status,
    ),
    PatientActiveWorkKind.labOrder => l10n.patientsActiveWorkNextLabPending,
    PatientActiveWorkKind.radiologyOrder =>
      l10n.patientsActiveWorkNextImagingPending,
    PatientActiveWorkKind.therapy => l10n.patientsActiveWorkNextTherapy,
    PatientActiveWorkKind.theater => l10n.patientsActiveWorkNextTheater,
  };
}

String patientActiveWorkActionLabel(
  AppLocalizations l10n,
  PatientActiveWorkItem item,
) {
  return switch (item.kind) {
    PatientActiveWorkKind.appointment =>
      l10n.patientsActiveWorkManageAppointmentAction,
    PatientActiveWorkKind.encounter =>
      _opdActionLabelForStatus(l10n, item.status) ??
          l10n.patientsActiveWorkOpenOpdAction,
    PatientActiveWorkKind.queue =>
      _opdActionLabelForStatus(l10n, item.status) ??
          l10n.patientsActiveWorkOpenOpdAction,
    PatientActiveWorkKind.admission => _admissionActionLabel(l10n, item.status),
    PatientActiveWorkKind.labOrder => l10n.opdCollectSampleAction,
    PatientActiveWorkKind.radiologyOrder => l10n.opdPerformImagingAction,
    PatientActiveWorkKind.therapy => l10n.opdPhysiotherapyAction,
    PatientActiveWorkKind.theater => l10n.opdTheatreSchedulingAction,
  };
}

AppWorkspaceStatusTone patientActiveWorkStatusTone(PatientActiveWorkItem item) {
  if (item.kind == PatientActiveWorkKind.admission &&
      isPendingPatientAdmissionRequest(item.status)) {
    return AppWorkspaceStatusTone.warning;
  }
  if (item.kind == PatientActiveWorkKind.encounter) {
    return opdStageStatusTone(item.status);
  }
  return AppWorkspaceStatusTone.info;
}

String? _opdActionLabelForStatus(AppLocalizations l10n, String status) {
  return switch (status.trim().toUpperCase()) {
    'PAYMENT_DUE' ||
    'WAITING_CONSULTATION_PAYMENT' ||
    'CONSULTATION_PAYMENT_PENDING' => l10n.opdPayConsultationAction,
    'VITALS_NEEDED' ||
    'WAITING_VITALS' ||
    'VITALS_PENDING' ||
    'TRIAGE_PENDING' => l10n.opdRecordVitalsAction,
    'DOCTOR_NEEDED' ||
    'WAITING_DOCTOR_ASSIGNMENT' ||
    'AWAITING_DOCTOR' => l10n.opdAssignDoctorAction,
    'WITH_DOCTOR' ||
    'WAITING_DOCTOR_REVIEW' ||
    'CLINICAL_REVIEW' ||
    'DOCTOR_CONSULTATION' => l10n.opdDoctorReviewAction,
    'LAB_PENDING' ||
    'LAB_REQUESTED' ||
    'SAMPLE_PENDING' ||
    'IN_LAB' ||
    'LAB_ORDER_CREATED' => l10n.opdCollectSampleAction,
    'IMAGING_PENDING' ||
    'RADIOLOGY_REQUESTED' ||
    'REPORT_PENDING' ||
    'RADIOLOGY_ORDER_CREATED' => l10n.opdPerformImagingAction,
    'LAB_AND_RADIOLOGY_REQUESTED' ||
    'DIAGNOSTICS_PENDING' => l10n.opdDiagnosticsPendingAction,
    'RESULTS_READY' || 'LAB_RESULTS_READY' => l10n.opdReviewResultsAction,
    'REPORT_READY' || 'IMAGING_REPORT_READY' => l10n.opdReviewReportAction,
    'PHARMACY_PENDING' ||
    'PHARMACY_REQUESTED' ||
    'PRESCRIPTION_READY' ||
    'AWAITING_DISPENSING' ||
    'DISPENSING' => l10n.opdDispenseMedicineAction,
    'MEDICINES_DISPENSED' ||
    'MEDICATION_COMPLETE' => l10n.opdMedicinesDispensedAction,
    'DECISION_NEEDED' ||
    'WAITING_DISPOSITION' ||
    'ENCOUNTER_COMPLETE' ||
    'CLOSE_ENCOUNTER' => l10n.opdDispositionAction,
    'ADMISSION_PENDING' ||
    'ADMIT_PATIENT' ||
    'IPD_ADMISSION' => l10n.opdAdmissionHandoffAction,
    'ADMITTED' || 'IN_IPD' || 'IPD_ACTIVE' => l10n.opdAdmittedAction,
    _ => null,
  };
}

String? _opdNextStepDescriptionForStatus(AppLocalizations l10n, String status) {
  return switch (status.trim().toUpperCase()) {
    'PAYMENT_DUE' ||
    'WAITING_CONSULTATION_PAYMENT' ||
    'CONSULTATION_PAYMENT_PENDING' =>
      l10n.patientsActiveWorkNextPayConsultation,
    'VITALS_NEEDED' ||
    'WAITING_VITALS' ||
    'VITALS_PENDING' ||
    'TRIAGE_PENDING' => l10n.patientsActiveWorkNextRecordVitals,
    'DOCTOR_NEEDED' ||
    'WAITING_DOCTOR_ASSIGNMENT' ||
    'AWAITING_DOCTOR' => l10n.patientsActiveWorkNextAssignDoctor,
    'WAITING_DOCTOR_REVIEW' ||
    'CLINICAL_REVIEW' ||
    'DOCTOR_CONSULTATION' => l10n.patientsActiveWorkNextDoctorReview,
    'WITH_DOCTOR' => l10n.patientsActiveWorkNextWithDoctor,
    'LAB_PENDING' ||
    'LAB_REQUESTED' ||
    'SAMPLE_PENDING' ||
    'IN_LAB' ||
    'LAB_ORDER_CREATED' => l10n.patientsActiveWorkNextLabPending,
    'IMAGING_PENDING' ||
    'RADIOLOGY_REQUESTED' ||
    'REPORT_PENDING' ||
    'RADIOLOGY_ORDER_CREATED' => l10n.patientsActiveWorkNextImagingPending,
    'LAB_AND_RADIOLOGY_REQUESTED' ||
    'DIAGNOSTICS_PENDING' => l10n.patientsActiveWorkNextLabAndImagingPending,
    'RESULTS_READY' ||
    'LAB_RESULTS_READY' => l10n.patientsActiveWorkNextResultsReady,
    'REPORT_READY' ||
    'IMAGING_REPORT_READY' => l10n.patientsActiveWorkNextReportReady,
    'PHARMACY_PENDING' ||
    'PHARMACY_REQUESTED' ||
    'PRESCRIPTION_READY' ||
    'AWAITING_DISPENSING' ||
    'DISPENSING' => l10n.patientsActiveWorkNextPharmacyPending,
    'MEDICINES_DISPENSED' ||
    'MEDICATION_COMPLETE' => l10n.patientsActiveWorkNextMedicinesDispensed,
    'DECISION_NEEDED' ||
    'WAITING_DISPOSITION' ||
    'ENCOUNTER_COMPLETE' ||
    'CLOSE_ENCOUNTER' => l10n.patientsActiveWorkNextDisposition,
    'ADMISSION_PENDING' ||
    'ADMIT_PATIENT' ||
    'IPD_ADMISSION' => l10n.patientsActiveWorkNextAdmissionPending,
    'ADMITTED' ||
    'IN_IPD' ||
    'IPD_ACTIVE' => l10n.patientsActiveWorkNextAdmitted,
    _ => null,
  };
}

String _admissionNextStepDescription(AppLocalizations l10n, String status) {
  return switch (status.trim().toUpperCase()) {
    'REQUESTED' => l10n.patientsActiveWorkNextAdmissionPending,
    'ADMITTED_PENDING_BED' => l10n.patientsActiveWorkNextAdmissionBedPending,
    'TRANSFER_REQUESTED' ||
    'TRANSFER_IN_PROGRESS' => l10n.patientsActiveWorkNextAdmissionTransfer,
    'DISCHARGE_PLANNED' => l10n.patientsActiveWorkNextAdmissionDischarge,
    _ => l10n.patientsActiveWorkNextAdmission,
  };
}

String _admissionActionLabel(AppLocalizations l10n, String status) {
  return switch (status.trim().toUpperCase()) {
    'REQUESTED' => l10n.opdAdmissionHandoffAction,
    'ADMITTED_PENDING_BED' => l10n.opdAssignBedAction,
    'TRANSFER_REQUESTED' ||
    'TRANSFER_IN_PROGRESS' => l10n.ipdNextApproveTransfer,
    'DISCHARGE_PLANNED' => l10n.opdDischargeAction,
    // Active Work is the sole continue path for in-flight admissions.
    _ => l10n.navigationDischargeLabel,
  };
}
