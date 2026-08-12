import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

String nursingApiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

String nursingJoinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

AppWorkspaceStatus nursingSummaryStatus(NursingPatientSummary summary) {
  final String value =
      summary.stage ??
      summary.admissionStatus ??
      summary.transferStatus ??
      summary.nextStep ??
      '';
  return AppWorkspaceStatus(
    label: nursingApiLabel(value),
    tone: nursingStatusTone(value),
  );
}

AppWorkspaceStatus? nursingStatusFromValue(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return AppWorkspaceStatus(
    label: nursingApiLabel(value),
    tone: nursingStatusTone(value),
  );
}

AppWorkspaceStatusTone nursingStatusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'DISCHARGED' ||
    'COMPLETED' ||
    'ACCEPTED' ||
    'NORMAL' ||
    'GIVEN' => AppWorkspaceStatusTone.success,
    'CRITICAL' ||
    'HIGH' ||
    'MISSED' ||
    'REFUSED' ||
    'CANCELLED' => AppWorkspaceStatusTone.error,
    'TRANSFER_REQUESTED' ||
    'TRANSFER_IN_PROGRESS' ||
    'DISCHARGE_PLANNED' ||
    'REQUESTED' ||
    'PENDING' ||
    'DELAYED' => AppWorkspaceStatusTone.warning,
    'ADMITTED_IN_BED' ||
    'ACTIVE' ||
    'APPROVED' ||
    'IN_PROGRESS' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatus nursingPriorityStatus(
  BuildContext context,
  NursingPatientSummary item,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.priorityCode) {
    'HIGH' => AppWorkspaceStatus(
      label: l10n.nursingPriorityHighLabel,
      tone: AppWorkspaceStatusTone.error,
    ),
    'MEDIUM' => AppWorkspaceStatus(
      label: l10n.nursingPriorityMediumLabel,
      tone: AppWorkspaceStatusTone.warning,
    ),
    _ => AppWorkspaceStatus(label: l10n.nursingPriorityRoutineLabel),
  };
}

String nursingTaskTypeLabel(BuildContext context, NursingPatientSummary item) {
  final AppLocalizations l10n = context.l10n;
  return switch (item.taskTypeCode) {
    'MEDICATION_DUE' => l10n.nursingMedicationDueSummaryLabel,
    'HANDOVER_PENDING' => l10n.nursingHandoverPendingSummaryLabel,
    'TRANSFER_PENDING' => l10n.nursingTransferPendingSummaryLabel,
    'DISCHARGE_PENDING' => l10n.nursingDischargePendingSummaryLabel,
    final String value => nursingApiLabel(value),
  };
}

String nursingDueTimeLabel(BuildContext context, NursingPatientSummary item) {
  if (item.isUrgent || item.hasMedicationDue || item.hasPendingTransfer) {
    return context.l10n.nursingDueNowLabel;
  }
  return nursingDateTimeLabel(context, item.dueReferenceAt);
}

String nursingAdmissionLabel(BuildContext context, NursingPatientSummary item) {
  final String? id = item.displayId?.trim();
  if (id == null || id.isEmpty) {
    return context.l10n.profileUnknownValue;
  }
  return id;
}

/// Synthetic responsible-nurse summary (tables.mdc product exception — no
/// assignee API field on [NursingPatientSummary]; uses handover/shift cues).
String nursingResponsibleNurseLabel(
  BuildContext context,
  NursingPatientSummary item,
) {
  if (item.pendingHandoverCount > 0) {
    return context.l10n.nursingHandoverPendingSummaryLabel;
  }
  return context.l10n.nursingAssignedShiftLabel;
}

String nursingResponsibleNurseSortValue(NursingPatientSummary item) {
  return item.pendingHandoverCount > 0 ? 'handover pending' : 'assigned shift';
}

String nursingLastObservationLabel(
  BuildContext context,
  NursingPatientSummary item,
) {
  // Prefer an atomic timestamp in the table; full observation text belongs in
  // the patient detail dialog.
  return nursingDateTimeLabel(context, item.lastObservationAt);
}

int nursingPageTotal<T>(AppPage<T> page) =>
    page.totalItemCount ?? page.items.length;

String nursingPageLabel(BuildContext context, AppPage<NursingWorkItem> page) {
  final int total = page.totalItemCount ?? page.items.length;
  if (total == 0) {
    return context.l10n.opdPageLabel(0, 0, 0);
  }
  final int from = page.request.pageIndex * page.request.pageSize + 1;
  final int to = (from + page.items.length - 1).clamp(from, total);
  return context.l10n.opdPageLabel(from, to, total);
}

String nursingDateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String? nursingDateLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return null;
  }
  return AppFormatters.mediumDate(value, Localizations.localeOf(context));
}

void nursingShowFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

List<Widget> nursingDialogActions(
  BuildContext context, {
  required String submitLabel,
  required bool isSaving,
  required VoidCallback onSubmit,
}) {
  final AppLocalizations l10n = context.l10n;
  return <Widget>[
    AppButton.close(
      leadingIcon: AppActionIcons.cancel,
      label: l10n.commonCancelActionLabel,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      isLoading: isSaving,
      onPressed: onSubmit,
    ),
  ];
}

NursingPatientDetail? nursingSelectedDetailFromState(
  AsyncValue<Result<NursingWorkspaceState>> state,
) {
  final Result<NursingWorkspaceState>? result = state.asData?.value;
  return result?.when(
    success: (NursingWorkspaceState value) => value.selectedDetail,
    failure: (_) => null,
  );
}

const List<String> nursingMedicationRoutes = <String>[
  'ORAL',
  'IV',
  'IM',
  'SC',
  'TOPICAL',
  'INHALATION',
  'RECTAL',
  'OTHER',
];

String? nursingSupportedMedicationRoute(String? route) {
  final String normalized = (route ?? '').trim().toUpperCase();
  return nursingMedicationRoutes.contains(normalized) ? normalized : null;
}

const List<String> nursingTransferActions = <String>[
  'APPROVE',
  'START',
  'COMPLETE',
  'CANCEL',
];

List<AppSelectOption<String>> nursingStatusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: nursingApiLabel(value)),
  ];
}

List<AppNursingRecordEntry> nursingVitalRecords(
  BuildContext context,
  NursingPatientDetail detail, {
  void Function(NursingVitalSign vital)? onEdit,
}) {
  final AppLocalizations l10n = context.l10n;
  return detail.vitalSigns
      .map(
        (NursingVitalSign vital) => AppNursingRecordEntry(
          title: nursingApiLabel(vital.vitalType),
          subtitle: nursingDateTimeLabel(context, vital.recordedAt),
          body: vital.displayValue,
          icon: Icons.monitor_heart_outlined,
          trailingLabel: l10n.opdEditVitalsAction,
          trailingIcon: Icons.edit_outlined,
          onTrailingPressed: onEdit == null ? null : () => onEdit(vital),
        ),
      )
      .toList(growable: false);
}

List<AppNursingRecordEntry> nursingMedicationRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  final List<AppNursingRecordEntry> records = <AppNursingRecordEntry>[
    for (final MedicationReminder reminder in detail.medicationReminders)
      AppNursingRecordEntry(
        title: reminder.displayTitle,
        subtitle: nursingJoinDisplay(<String?>[
          nursingDateTimeLabel(context, reminder.scheduledAt),
          reminder.frequency,
        ]),
        body: nursingJoinDisplay(<String?>[
          reminder.dose,
          reminder.unit,
          reminder.route == null ? null : nursingApiLabel(reminder.route!),
        ]),
        icon: Icons.schedule_outlined,
        status: nursingStatusFromValue(reminder.status),
      ),
    for (final MedicationSuggestion suggestion in detail.medicationSuggestions)
      AppNursingRecordEntry(
        title: suggestion.displayTitle,
        subtitle: nursingJoinDisplay(<String?>[
          suggestion.frequency,
          suggestion.orderStatus,
        ]),
        body: nursingJoinDisplay(<String?>[
          suggestion.dose,
          suggestion.unit,
          suggestion.route == null ? null : nursingApiLabel(suggestion.route!),
        ]),
        icon: Icons.medication_outlined,
        status: nursingStatusFromValue(suggestion.itemStatus),
      ),
    for (final MedicationAdministrationRecord medication
        in detail.medicationAdministrations)
      AppNursingRecordEntry(
        title: _medicationAdministrationTitle(medication, detail),
        subtitle: nursingDateTimeLabel(context, medication.administeredAt),
        body: nursingJoinDisplay(<String?>[
          medication.dose,
          medication.unit,
          medication.route == null ? null : nursingApiLabel(medication.route!),
        ]),
        icon: Icons.done_all_outlined,
        status: AppWorkspaceStatus(
          label: nursingApiLabel('ADMINISTERED'),
          tone: AppWorkspaceStatusTone.success,
        ),
      ),
  ];
  return records;
}

String _medicationAdministrationTitle(
  MedicationAdministrationRecord medication,
  NursingPatientDetail detail,
) {
  final String? prescriptionId = medication.prescriptionId?.trim();
  if (prescriptionId != null && prescriptionId.isNotEmpty) {
    for (final MedicationSuggestion suggestion
        in detail.medicationSuggestions) {
      if (suggestion.id == prescriptionId) {
        return suggestion.displayTitle;
      }
    }
    for (final MedicationReminder reminder in detail.medicationReminders) {
      if (reminder.prescriptionId == prescriptionId) {
        return reminder.displayTitle;
      }
    }
  }
  final String fallback = nursingJoinDisplay(<String?>[
    medication.dose,
    medication.unit,
    medication.route == null ? null : nursingApiLabel(medication.route!),
  ]);
  return fallback.isEmpty ? nursingApiLabel('ADMINISTERED') : fallback;
}

List<AppNursingRecordEntry> nursingNoteRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return detail.nursingNotes
      .map(
        (NursingNoteRecord note) => AppNursingRecordEntry(
          title: note.nurseName ?? context.l10n.profileUnknownValue,
          subtitle: nursingDateTimeLabel(context, note.createdAt),
          body: note.note,
          icon: Icons.edit_note_outlined,
        ),
      )
      .toList(growable: false);
}

List<AppNursingRecordEntry> nursingCarePlanRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return detail.carePlans
      .map(
        (NursingCarePlan plan) => AppNursingRecordEntry(
          title: plan.plan ?? plan.id,
          subtitle: nursingJoinDisplay(<String?>[
            nursingDateLabel(context, plan.startDate),
            nursingDateLabel(context, plan.endDate),
          ]),
          icon: Icons.playlist_add_check_outlined,
          status: nursingStatusFromValue(plan.status),
        ),
      )
      .toList(growable: false);
}

List<AppNursingRecordEntry> nursingHandoverRecords(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return detail.handovers
      .map(
        (NursingHandover handover) => AppNursingRecordEntry(
          title: context.l10n.profileUnknownValue,
          subtitle: nursingDateTimeLabel(context, handover.createdAt),
          body: handover.signoffNotes,
          icon: Icons.swap_horiz_outlined,
          status: nursingStatusFromValue(handover.status),
        ),
      )
      .toList(growable: false);
}

List<AppCareTaskChecklistItem> nursingAdmissionChecklistItems(
  BuildContext context,
  NursingPatientDetail detail, {
  VoidCallback? onOpenHandover,
  VoidCallback? onConfirmIdentity,
  VoidCallback? onOpenVitals,
  VoidCallback? onOpenAllergies,
  VoidCallback? onOpenBelongings,
  VoidCallback? onOpenCarePlan,
  VoidCallback? onNotifyDoctor,
  VoidCallback? onOpenDischargeClearance,
}) {
  final AppLocalizations l10n = context.l10n;
  final NursingPatientSummary summary = detail.enrichedSummary;
  AppWorkspaceStatus status(bool complete) {
    return AppWorkspaceStatus(
      label: complete
          ? l10n.nursingChecklistCompleteStatus
          : l10n.nursingChecklistPendingStatus,
      tone: complete
          ? AppWorkspaceStatusTone.success
          : AppWorkspaceStatusTone.warning,
    );
  }

  final bool locationReady =
      summary.locationLabel != null || summary.hasActiveBed;
  final bool handoverReady = detail.handovers.any(
    (NursingHandover item) => item.admissionId == summary.admissionId,
  );
  final bool identityReady = detail.hasNursingNoteTag(NursingNoteTags.identity);
  final bool vitalsReady = detail.vitalSigns.isNotEmpty;
  final bool allergiesReady = detail.hasNursingNoteTag(
    NursingNoteTags.allergies,
  );
  final bool belongingsReady = detail.hasNursingNoteTag(
    NursingNoteTags.belongings,
  );
  final bool carePlanReady = detail.carePlans.isNotEmpty;
  final bool doctorNotified = detail.hasNursingNoteTag(
    NursingNoteTags.doctorNotified,
  );
  final bool medicationReady = !detail.hasMedicationDue;
  final bool dischargeReady = !summary.isDischargePending;

  return <AppCareTaskChecklistItem>[
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistLocationTitle,
      subtitle: locationReady
          ? summary.locationLabel ?? l10n.nursingChecklistLocationReadyBody
          : l10n.nursingChecklistLocationPendingBody,
      isComplete: locationReady,
      status: status(locationReady),
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistHandoverTitle,
      subtitle: handoverReady
          ? l10n.nursingChecklistHandoverReadyBody
          : l10n.nursingChecklistHandoverPendingBody,
      isComplete: handoverReady,
      status: status(handoverReady),
      actionLabel: handoverReady || onOpenHandover == null
          ? null
          : l10n.nursingActionCreateHandover,
      actionIcon: Icons.swap_horiz_outlined,
      onAction: handoverReady ? null : onOpenHandover,
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistIdentityTitle,
      subtitle: identityReady
          ? (detail.latestNursingNoteWithTag(NursingNoteTags.identity)?.note ??
                l10n.nursingChecklistIdentityReadyBody)
          : l10n.nursingChecklistIdentityPendingBody,
      isComplete: identityReady,
      status: status(identityReady),
      actionLabel: identityReady || onConfirmIdentity == null
          ? null
          : l10n.nursingActionConfirmIdentity,
      actionIcon: Icons.badge_outlined,
      onAction: identityReady ? null : onConfirmIdentity,
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistVitalsTitle,
      subtitle: vitalsReady
          ? nursingDateTimeLabel(context, detail.vitalSigns.first.recordedAt)
          : l10n.nursingChecklistVitalsPendingBody,
      isComplete: vitalsReady,
      status: status(vitalsReady),
      actionLabel: vitalsReady || onOpenVitals == null
          ? null
          : l10n.nursingActionRecordVitals,
      actionIcon: Icons.monitor_heart_outlined,
      onAction: vitalsReady ? null : onOpenVitals,
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistAllergiesTitle,
      subtitle: allergiesReady
          ? (detail.latestNursingNoteWithTag(NursingNoteTags.allergies)?.note ??
                l10n.nursingChecklistAllergiesReadyBody)
          : l10n.nursingChecklistAllergiesPendingBody,
      isComplete: allergiesReady,
      status: status(allergiesReady),
      actionLabel: onOpenAllergies == null
          ? null
          : l10n.nursingActionRecordAllergies,
      actionIcon: Icons.health_and_safety_outlined,
      onAction: onOpenAllergies,
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistBelongingsTitle,
      subtitle: belongingsReady
          ? (detail
                    .latestNursingNoteWithTag(NursingNoteTags.belongings)
                    ?.note ??
                l10n.nursingChecklistBelongingsReadyBody)
          : l10n.nursingChecklistBelongingsPendingBody,
      isComplete: belongingsReady,
      status: status(belongingsReady),
      actionLabel: onOpenBelongings == null
          ? null
          : l10n.nursingActionRecordBelongings,
      actionIcon: Icons.work_outline,
      onAction: onOpenBelongings,
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistCarePlanTitle,
      subtitle: carePlanReady
          ? l10n.nursingChecklistCarePlanReadyBody
          : l10n.nursingChecklistCarePlanPendingBody,
      isComplete: carePlanReady,
      status: status(carePlanReady),
      actionLabel: carePlanReady || onOpenCarePlan == null
          ? null
          : l10n.nursingChecklistCarePlanTitle,
      actionIcon: Icons.playlist_add_check_outlined,
      onAction: carePlanReady ? null : onOpenCarePlan,
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistDoctorTitle,
      subtitle: doctorNotified
          ? (detail
                    .latestNursingNoteWithTag(NursingNoteTags.doctorNotified)
                    ?.note ??
                l10n.nursingChecklistDoctorReadyBody)
          : l10n.nursingChecklistDoctorPendingBody,
      isComplete: doctorNotified,
      status: status(doctorNotified),
      actionLabel: doctorNotified || onNotifyDoctor == null
          ? null
          : l10n.nursingActionNotifyDoctor,
      actionIcon: Icons.contact_phone_outlined,
      onAction: doctorNotified ? null : onNotifyDoctor,
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistMedicationTitle,
      subtitle: medicationReady
          ? l10n.nursingChecklistMedicationReadyBody
          : l10n.nursingChecklistMedicationPendingBody,
      isComplete: medicationReady,
      status: status(medicationReady),
    ),
    AppCareTaskChecklistItem(
      title: l10n.nursingChecklistDischargeTitle,
      subtitle: dischargeReady
          ? l10n.nursingChecklistDischargeReadyBody
          : l10n.nursingChecklistDischargePendingBody,
      isComplete: dischargeReady,
      status: status(dischargeReady),
      actionLabel: dischargeReady || onOpenDischargeClearance == null
          ? null
          : l10n.nursingActionDischargeClearance,
      actionIcon: Icons.fact_check_outlined,
      onAction: dischargeReady ? null : onOpenDischargeClearance,
    ),
  ];
}

List<AppRosterAssignmentView> nursingRosterViews(
  BuildContext context,
  List<NursingRosterAssignment> rosters,
) {
  return rosters
      .map(
        (NursingRosterAssignment roster) => AppRosterAssignmentView(
          title: roster.id,
          subtitle: nursingJoinDisplay(<String?>[
            nursingDateTimeLabel(context, roster.periodStart),
            nursingDateTimeLabel(context, roster.periodEnd),
            roster.facilityId,
            roster.departmentId,
          ]),
          status: nursingStatusFromValue(roster.status),
        ),
      )
      .toList(growable: false);
}

List<AppWardActivityEntry> nursingHandoverActivityEntries(
  BuildContext context,
  List<NursingHandover> handovers,
) {
  return handovers
      .map(
        (NursingHandover handover) => AppWardActivityEntry(
          title: context.l10n.profileUnknownValue,
          subtitle: nursingDateTimeLabel(context, handover.createdAt),
          body: handover.signoffNotes,
          icon: Icons.swap_horiz_outlined,
          status: nursingStatusFromValue(handover.status),
        ),
      )
      .toList(growable: false);
}

List<AppWardActivityEntry> nursingActivityEntries(
  BuildContext context,
  NursingPatientDetail detail,
) {
  return <AppWardActivityEntry>[
    for (final NursingCriticalAlert alert in detail.criticalAlerts)
      AppWardActivityEntry(
        title: alert.severity == null
            ? alert.id
            : nursingApiLabel(alert.severity!),
        subtitle: nursingDateTimeLabel(context, alert.createdAt),
        body: alert.message,
        icon: Icons.report_problem_outlined,
        status: nursingStatusFromValue(alert.severity),
      ),
    for (final NursingTimelineItem item in <NursingTimelineItem>[
      ...detail.icuObservations,
      ...detail.timeline,
    ])
      AppWardActivityEntry(
        title: nursingApiLabel(item.type),
        subtitle: nursingDateTimeLabel(context, item.occurredAt),
        body: item.label,
        icon: nursingTimelineIcon(item.type),
      ),
  ];
}

IconData nursingTimelineIcon(String type) {
  return switch (type) {
    'NURSING_NOTE' => Icons.edit_note_outlined,
    'MEDICATION_ADMINISTRATION' => Icons.medication_outlined,
    'MEDICATION_REMINDER' => Icons.schedule_outlined,
    'TRANSFER' => Icons.transfer_within_a_station_outlined,
    'ICU_OBSERVATION' => Icons.monitor_heart_outlined,
    'CRITICAL_ALERT' => Icons.report_problem_outlined,
    _ => Icons.history_outlined,
  };
}

String nursingDefaultTransferAction(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'REQUESTED' => 'APPROVE',
    'APPROVED' => 'START',
    'IN_PROGRESS' => 'COMPLETE',
    _ => 'APPROVE',
  };
}

String nursingSummaryText(BuildContext context, NursingPatientDetail detail) {
  final AppLocalizations l10n = context.l10n;
  final NursingPatientSummary summary = detail.enrichedSummary;
  final List<String> lines = <String>[
    l10n.nursingReportTitle,
    '',
    '${l10n.nursingPatientFilterLabel}: ${summary.displayTitle}',
    '${l10n.nursingAdmissionLabel}: ${summary.displayId ?? l10n.profileUnknownValue}',
    '${l10n.nursingLocationLabel}: ${summary.locationLabel ?? l10n.profileUnknownValue}',
    '${l10n.nursingPriorityColumnLabel}: ${nursingPriorityStatus(context, summary).label}',
    '${l10n.nursingTaskTypeColumnLabel}: ${nursingTaskTypeLabel(context, summary)}',
    '',
    l10n.nursingObservationsTitle,
    ..._recordsAsLines(context, nursingVitalRecords(context, detail)),
    '',
    l10n.nursingMedicationsTitle,
    ..._recordsAsLines(context, nursingMedicationRecords(context, detail)),
    '',
    l10n.nursingNotesTitle,
    ..._recordsAsLines(context, nursingNoteRecords(context, detail)),
    '',
    l10n.nursingCarePlansTitle,
    ..._recordsAsLines(context, nursingCarePlanRecords(context, detail)),
    '',
    l10n.nursingHandoversTitle,
    ..._recordsAsLines(context, nursingHandoverRecords(context, detail)),
    '',
    l10n.nursingWardAdmissionChecklistTitle,
    for (final AppCareTaskChecklistItem item in nursingAdmissionChecklistItems(
      context,
      detail,
      onOpenHandover: () {},
      onConfirmIdentity: () {},
      onOpenVitals: () {},
      onOpenAllergies: () {},
      onOpenBelongings: () {},
      onOpenCarePlan: () {},
      onNotifyDoctor: () {},
      onOpenDischargeClearance: () {},
    ))
      '- ${item.title}: ${item.isComplete ? l10n.nursingChecklistCompleteStatus : l10n.nursingChecklistPendingStatus}',
  ];
  return lines.join('\n');
}

String nursingSummaryHtml(BuildContext context, NursingPatientDetail detail) {
  final String text = nursingSummaryText(context, detail);
  return '<p>${text.split('\n').map(_htmlEscape).join('<br />')}</p>';
}

List<String> _recordsAsLines(
  BuildContext context,
  List<AppNursingRecordEntry> records,
) {
  if (records.isEmpty) {
    return <String>['- ${context.l10n.nursingNoRecordsLabel}'];
  }
  return records
      .map(
        (AppNursingRecordEntry record) =>
            '- ${nursingJoinDisplay(<String?>[record.title, record.subtitle, record.body, record.status?.label])}',
      )
      .toList(growable: false);
}

String _htmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String nursingDocumentsTypeGroupLabel(AppLocalizations l10n) =>
    l10n.patientsDocumentsSectionTitle;

NursingQueueScope nursingScopeFromFilterValue(String? value) {
  return switch (value) {
    'urgent' => NursingQueueScope.urgent,
    'medication_due' => NursingQueueScope.medicationDue,
    'handover_pending' => NursingQueueScope.handoverPending,
    'transfer_pending' => NursingQueueScope.transferPending,
    'discharge_pending' => NursingQueueScope.dischargePending,
    'assigned_ward' => NursingQueueScope.assignedWard,
    'all' => NursingQueueScope.all,
    _ => NursingQueueScope.all,
  };
}

String nursingScopeCode(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.assignedWard => 'assigned_ward',
    NursingQueueScope.urgent => 'urgent',
    NursingQueueScope.medicationDue => 'medication_due',
    NursingQueueScope.handoverPending => 'handover_pending',
    NursingQueueScope.transferPending => 'transfer_pending',
    NursingQueueScope.dischargePending => 'discharge_pending',
    NursingQueueScope.all => 'all',
  };
}

Future<void> nursingShowActionResult(
  BuildContext context,
  Future<bool?> future,
) async {
  final bool? saved = await future;
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.nursingSavedMessage)));
  }
}
