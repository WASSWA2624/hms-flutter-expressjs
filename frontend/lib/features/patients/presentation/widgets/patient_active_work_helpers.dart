import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';

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
        status: record.status ?? '',
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
