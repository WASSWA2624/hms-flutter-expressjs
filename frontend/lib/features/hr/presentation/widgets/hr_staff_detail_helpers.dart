import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Builds a human-readable assignment title: Department › Unit › Room.
String hrAssignmentTitle(HrStaffAssignment assignment, AppLocalizations l10n) {
  final String department =
      assignment.departmentName ??
      assignment.departmentDisplayId ??
      l10n.hrAssignmentLabel;
  if ((assignment.roomName ?? assignment.roomDisplayId ?? '')
      .trim()
      .isNotEmpty) {
    final String room = assignment.roomName ?? assignment.roomDisplayId ?? '';
    return '$department › $room';
  }
  if ((assignment.unitName ?? assignment.unitDisplayId ?? '')
      .trim()
      .isNotEmpty) {
    final String unit = assignment.unitName ?? assignment.unitDisplayId ?? '';
    return '$department › $unit';
  }
  return department;
}

String hrAssignmentSubtitle(
  BuildContext context,
  HrStaffAssignment assignment,
  AppLocalizations l10n,
) {
  final String range = hrDateRange(
    context,
    assignment.startDate,
    assignment.endDate,
  );
  if ((assignment.displayId ?? '').trim().isNotEmpty) {
    return '$range · ${assignment.displayId}';
  }
  return range;
}

String hrDateRange(BuildContext context, DateTime? start, DateTime? end) {
  final AppLocalizations l10n = context.l10n;
  final Locale locale = Localizations.localeOf(context);
  final String? startLabel = start == null
      ? null
      : AppFormatters.shortDate(start, locale);
  final String endLabel = end == null
      ? l10n.hrDateRangeOngoingLabel
      : AppFormatters.shortDate(end, locale);
  if (startLabel != null) {
    return '$startLabel – $endLabel';
  }
  if (end != null) {
    return endLabel;
  }
  return l10n.profileUnknownValue;
}

AppWorkspaceStatus hrAssignmentStatusBadge(
  HrStaffAssignment assignment,
  AppLocalizations l10n,
) {
  return AppWorkspaceStatus(
    label: assignment.isActive
        ? l10n.hrAssignmentActiveLabel
        : l10n.hrAssignmentEndedLabel,
    tone: assignment.isActive
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.neutral,
  );
}

AppWorkspaceStatus hrPrimaryAssignmentBadge(AppLocalizations l10n) {
  return AppWorkspaceStatus(
    label: l10n.hrPrimaryAssignmentLabel,
    tone: AppWorkspaceStatusTone.info,
  );
}

/// Deduplicates identical availability time slots before display.
List<HrAvailabilitySlot> hrDedupedAvailabilitySlots(
  HrStaffAvailability availability,
) {
  final List<HrAvailabilitySlot> source = availability.timeSlots.isNotEmpty
      ? availability.timeSlots
      : <HrAvailabilitySlot>[
          if ((availability.startTime ?? '').trim().isNotEmpty &&
              (availability.endTime ?? '').trim().isNotEmpty)
            HrAvailabilitySlot(
              startTime: availability.startTime!,
              endTime: availability.endTime!,
            ),
        ];
  final Set<String> seen = <String>{};
  final List<HrAvailabilitySlot> deduped = <HrAvailabilitySlot>[];
  for (final HrAvailabilitySlot slot in source) {
    final String key = '${slot.startTime}|${slot.endTime}';
    if (seen.add(key)) {
      deduped.add(slot);
    }
  }
  return deduped;
}

String hrAvailabilitySlotSummary(HrStaffAvailability availability) {
  final List<HrAvailabilitySlot> slots = hrDedupedAvailabilitySlots(
    availability,
  );
  if (slots.isEmpty) {
    return '';
  }
  return slots
      .map((HrAvailabilitySlot slot) => '${slot.startTime}–${slot.endTime}')
      .join(', ');
}

String hrShiftAssignmentTitle(
  HrShiftAssignment assignment,
  HrReferenceData referenceData,
  AppLocalizations l10n,
) {
  if ((assignment.shiftName ?? '').trim().isNotEmpty) {
    return assignment.shiftName!;
  }
  for (final HrOption option in referenceData.shifts) {
    if (option.value == assignment.shiftId ||
        option.displayId == assignment.shiftId) {
      return option.label;
    }
  }
  return l10n.hrShiftLabel;
}

String hrShiftAssignmentSubtitle(
  BuildContext context,
  HrShiftAssignment assignment,
  AppLocalizations l10n,
) {
  final Locale locale = Localizations.localeOf(context);
  final String assignedAt = assignment.assignedAt == null
      ? ''
      : AppFormatters.dateTime(assignment.assignedAt!, locale);
  return hrJoinDisplay(<String?>[
    assignment.shiftType,
    assignedAt,
    assignment.rosterPeriodLabel,
    assignment.shiftStatus,
  ]);
}

String hrCompensationRowTitle(
  BuildContext context,
  HrStaffCompensation compensation,
) {
  final AppLocalizations l10n = context.l10n;
  return hrJoinDisplay(<String?>[
    l10n.hrReferenceCompensationPayTypeLabel(
      compensation.payType ?? '',
      fallback: compensation.payType,
    ),
    compensation.rate?.toString(),
    compensation.currency,
  ]);
}

String hrJoinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim())
      .whereType<String>()
      .where((String value) => value.isNotEmpty)
      .join(' · ');
}

String hrSeparationTypeLabel(AppLocalizations l10n, String? type) {
  if ((type ?? '').trim().isEmpty) {
    return l10n.hrSeparationTypeOtherLabel;
  }
  return switch (type!.trim().toUpperCase()) {
    'RESIGNATION' => l10n.hrSeparationTypeResignationLabel,
    'TERMINATION' => l10n.hrSeparationTypeTerminationLabel,
    'RETIREMENT' => l10n.hrSeparationTypeRetirementLabel,
    'CONTRACT_END' => l10n.hrSeparationTypeContractEndLabel,
    'DECEASED' => l10n.hrSeparationTypeDeceasedLabel,
    _ => type,
  };
}
