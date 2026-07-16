import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

AppSearchBarFilterValue nursingFilterValueFromQuery(
  NursingWorklistQuery query,
) {
  return AppSearchBarFilterValue(
    field: query.searchField.trim().isEmpty ? null : query.searchField,
    dateFrom: query.dateFrom,
    dateTo: query.dateTo,
    texts: Map<String, String>.unmodifiable(<String, String>{
      if (query.patient.trim().isNotEmpty) 'patient': query.patient,
      if (query.admission.trim().isNotEmpty) 'admission': query.admission,
      if (query.encounter.trim().isNotEmpty) 'encounter': query.encounter,
      if (query.ward.trim().isNotEmpty) 'ward': query.ward,
      if (query.room.trim().isNotEmpty) 'room': query.room,
      if (query.bed.trim().isNotEmpty) 'bed': query.bed,
      if (query.observation.trim().isNotEmpty) 'observation': query.observation,
      if (query.taskType.trim().isNotEmpty) 'task_type': query.taskType,
      if (query.assignedNurse.trim().isNotEmpty)
        'assigned_nurse': query.assignedNurse,
      if (query.shift.trim().isNotEmpty) 'shift': query.shift,
    }),
    options: Map<String, String>.unmodifiable(<String, String>{
      if (query.scope != NursingQueueScope.all)
        'scope': nursingScopeCode(query.scope),
      if (query.status.trim().isNotEmpty) 'status': query.status,
      if (query.priority.trim().isNotEmpty) 'priority': query.priority,
      if (query.transferStatus.trim().isNotEmpty)
        'transfer_status': query.transferStatus,
      if (query.handoverStatus.trim().isNotEmpty)
        'handover_status': query.handoverStatus,
      if (query.dischargeStatus.trim().isNotEmpty)
        'discharge_status': query.dischargeStatus,
    }),
  );
}

List<AppSearchBarFieldChoice> nursingWorklistSearchFields(
  AppLocalizations l10n,
) {
  return <AppSearchBarFieldChoice>[
    AppSearchBarFieldChoice(
      field: 'patient',
      label: l10n.opdPatientColumnLabel,
    ),
    AppSearchBarFieldChoice(
      field: 'admission',
      label: l10n.nursingAdmissionColumnLabel,
    ),
    AppSearchBarFieldChoice(
      field: 'encounter',
      label: l10n.nursingEncounterLabel,
    ),
    AppSearchBarFieldChoice(field: 'ward', label: l10n.patientsWardLabel),
    AppSearchBarFieldChoice(field: 'room', label: l10n.patientsRoomLabel),
    AppSearchBarFieldChoice(field: 'bed', label: l10n.nursingBedLabel),
    AppSearchBarFieldChoice(
      field: 'observation',
      label: l10n.nursingObservationsTitle,
    ),
    AppSearchBarFieldChoice(
      field: 'task_type',
      label: l10n.nursingTaskTypeColumnLabel,
    ),
    AppSearchBarFieldChoice(field: 'status', label: l10n.opdStatusColumnLabel),
    AppSearchBarFieldChoice(
      field: 'priority',
      label: l10n.nursingPriorityColumnLabel,
    ),
  ];
}

List<AppSearchBarTextFilter> nursingWorklistTextFilters(AppLocalizations l10n) {
  return <AppSearchBarTextFilter>[
    AppSearchBarTextFilter(
      key: 'patient',
      label: l10n.nursingPatientFilterLabel,
      hintText: l10n.nursingPatientFilterHint,
      icon: Icons.person_search_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'admission',
      label: l10n.nursingAdmissionColumnLabel,
      icon: Icons.hotel_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'encounter',
      label: l10n.nursingEncounterLabel,
      icon: Icons.medical_information_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'ward',
      label: l10n.patientsWardLabel,
      hintText: l10n.nursingWardFilterHint,
      icon: Icons.local_hospital_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'room',
      label: l10n.patientsRoomLabel,
      icon: Icons.meeting_room_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'bed',
      label: l10n.nursingBedLabel,
      icon: Icons.bed_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'observation',
      label: l10n.nursingObservationsTitle,
      icon: Icons.monitor_heart_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'task_type',
      label: l10n.nursingTaskTypeColumnLabel,
      hintText: l10n.nursingCareTaskFilterHint,
      icon: Icons.playlist_add_check_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'assigned_nurse',
      label: l10n.nursingResponsibleNurseColumnLabel,
      icon: Icons.badge_outlined,
    ),
    AppSearchBarTextFilter(
      key: 'shift',
      label: l10n.nursingShiftFilterLabel,
      hintText: l10n.nursingShiftFilterHint,
      icon: Icons.schedule_outlined,
    ),
  ];
}

List<AppSearchBarFilterGroup> nursingWorklistFilterGroups(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterGroup>[
    AppSearchBarFilterGroup(
      key: 'scope',
      label: l10n.nursingScopeFilterLabel,
      allLabel: l10n.nursingScopeAllLabel,
      choices: nursingScopeFilterChoices(l10n),
    ),
    AppSearchBarFilterGroup(
      key: 'status',
      label: l10n.opdStatusColumnLabel,
      allLabel: l10n.nursingAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'ADMITTED_PENDING_BED',
          label: nursingApiLabel('ADMITTED_PENDING_BED'),
          icon: Icons.hotel_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'ADMITTED_IN_BED',
          label: nursingApiLabel('ADMITTED_IN_BED'),
          icon: Icons.bed_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'TRANSFER_REQUESTED',
          label: nursingApiLabel('TRANSFER_REQUESTED'),
          icon: Icons.transfer_within_a_station_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'TRANSFER_IN_PROGRESS',
          label: nursingApiLabel('TRANSFER_IN_PROGRESS'),
          icon: Icons.transfer_within_a_station_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'DISCHARGE_PLANNED',
          label: nursingApiLabel('DISCHARGE_PLANNED'),
          icon: Icons.logout_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'DISCHARGED',
          label: nursingApiLabel('DISCHARGED'),
          icon: Icons.task_alt_outlined,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'priority',
      label: l10n.nursingPriorityFilterLabel,
      allLabel: l10n.nursingAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'HIGH',
          label: l10n.nursingPriorityHighLabel,
          icon: Icons.priority_high_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'MEDIUM',
          label: l10n.nursingPriorityMediumLabel,
          icon: Icons.warning_amber_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'ROUTINE',
          label: l10n.nursingPriorityRoutineLabel,
          icon: Icons.task_alt_outlined,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'transfer_status',
      label: l10n.nursingTransferPendingSummaryLabel,
      allLabel: l10n.nursingAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        for (final String value in <String>[
          'REQUESTED',
          'APPROVED',
          'IN_PROGRESS',
          'COMPLETED',
          'CANCELLED',
        ])
          AppSearchBarFilterChoice(
            value: value,
            label: nursingApiLabel(value),
            icon: Icons.transfer_within_a_station_outlined,
          ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'handover_status',
      label: l10n.nursingHandoverPendingSummaryLabel,
      allLabel: l10n.nursingAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        AppSearchBarFilterChoice(
          value: 'PENDING',
          label: nursingApiLabel('PENDING'),
          icon: Icons.swap_horiz_outlined,
        ),
        AppSearchBarFilterChoice(
          value: 'NONE',
          label: l10n.nursingNoRecordsLabel,
          icon: Icons.check_circle_outline,
        ),
      ],
    ),
    AppSearchBarFilterGroup(
      key: 'discharge_status',
      label: l10n.dischargeStatusFilterLabel,
      allLabel: l10n.nursingAllFieldsLabel,
      choices: <AppSearchBarFilterChoice>[
        for (final String value in <String>[
          'PLANNED',
          'DISCHARGE_PLANNED',
          'COMPLETED',
          'DISCHARGED',
        ])
          AppSearchBarFilterChoice(
            value: value,
            label: nursingApiLabel(value),
            icon: Icons.logout_outlined,
          ),
      ],
    ),
  ];
}

bool nursingWorklistSearchMatcher(NursingWorkItem item, String query) {
  if (item.matchesSearch(query)) {
    return true;
  }
  return _matchesNursingWorklistExtraFields(item, query);
}

bool _matchesNursingWorklistExtraFields(NursingWorkItem item, String query) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  final Iterable<String> extraValues = <String?>[
    item.medicationDueCount > 0 ? item.medicationDueCount.toString() : null,
    item.pendingHandoverCount > 0 ? item.pendingHandoverCount.toString() : null,
    item.locationLabel,
    item.taskTypeCode,
    item.priorityCode,
    item.transferStatus,
    item.dischargeStatus,
  ].whereType<String>();

  for (final String value in extraValues) {
    if (value.trim().toLowerCase().contains(needle)) {
      return true;
    }
  }
  return false;
}

List<AppSearchBarFilterChoice> nursingScopeFilterChoices(
  AppLocalizations l10n,
) {
  return <AppSearchBarFilterChoice>[
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.assignedWard),
      label: l10n.nursingScopeAssignedWardLabel,
      icon: Icons.local_hospital_outlined,
    ),
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.urgent),
      label: l10n.nursingScopeUrgentLabel,
      icon: Icons.priority_high_outlined,
    ),
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.medicationDue),
      label: l10n.nursingScopeMedicationDueLabel,
      icon: Icons.medication_outlined,
    ),
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.handoverPending),
      label: l10n.nursingScopeHandoverPendingLabel,
      icon: Icons.swap_horiz_outlined,
    ),
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.transferPending),
      label: l10n.nursingScopeTransferPendingLabel,
      icon: Icons.transfer_within_a_station_outlined,
    ),
    AppSearchBarFilterChoice(
      value: nursingScopeCode(NursingQueueScope.dischargePending),
      label: l10n.nursingScopeDischargePendingLabel,
      icon: Icons.logout_outlined,
    ),
  ];
}
