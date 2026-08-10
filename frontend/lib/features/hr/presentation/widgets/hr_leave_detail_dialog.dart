import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_calendar_preview.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Opens leave details with overview sheet + visual calendar (roster-style).
Future<void> showHrLeaveDetailDialog(
  BuildContext context,
  HrStaffLeave leave,
) async {
  final AppLocalizations l10n = context.l10n;
  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => _HrLeaveDetailDialog(
      leave: leave,
      l10n: l10n,
    ),
  );
}

class _HrLeaveDetailDialog extends StatelessWidget {
  const _HrLeaveDetailDialog({required this.leave, required this.l10n});

  final HrStaffLeave leave;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<HrRosterDayPreview> days = hrLeaveCalendarDayPreviews(
      <HrStaffLeave>[leave],
    );

    return AppDialog(
      title: Text(l10n.hrLeaveDetailDialogTitle),
      icon: const Icon(Icons.event_busy_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 980,
      stackActionsWhenCompact: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppCollapsibleSection(
            title: l10n.hrLeaveOverviewSectionTitle,
            titleIcon: Icons.info_outline,
            child: AppInfoSheetGrid(
              emptyValue: l10n.profileUnknownValue,
              spacing: theme.spacing.lg,
              runSpacing: theme.spacing.sm,
              layout: AppInfoSheetLayout.inline,
              items: _overviewItems(context),
            ),
          ),
          SizedBox(height: theme.spacing.lg),
          AppCollapsibleSection(
            title: l10n.hrLeavePreviewSectionTitle,
            titleIcon: Icons.calendar_month_outlined,
            contentPadding: EdgeInsets.only(bottom: theme.spacing.md),
            child: days.isEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      theme.spacing.md,
                      theme.spacing.md,
                      theme.spacing.md,
                      0,
                    ),
                    child: Text(l10n.hrLeavePreviewEmptyBody),
                  )
                : HrRosterCalendarPreview(
                    days: days,
                    onShowDetails: (HrRosterPeriodDetails details) {
                      unawaited(
                        showHrRosterPeriodDetailsDialog(
                          context,
                          details: details,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.close(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  List<AppInfoSheetItem> _overviewItems(BuildContext context) {
    final Locale locale = Localizations.localeOf(context);
    final String typeLabel = l10n.hrReferenceLeaveTypeLabel(
      leave.leaveType,
      fallback: leave.leaveType ?? l10n.hrLeaveLabel,
    );
    final String? start = leave.startDate == null
        ? null
        : AppFormatters.shortDate(leave.startDate!, locale);
    final String? end = leave.endDate == null
        ? null
        : AppFormatters.shortDate(leave.endDate!, locale);

    return <AppInfoSheetItem>[
      AppInfoSheetItem(label: l10n.hrLeaveTypeLabel, value: typeLabel),
      AppInfoSheetItem(
        label: l10n.hrStatusColumnLabel,
        value: _statusDisplay(leave.status),
      ),
      AppInfoSheetItem(
        label: l10n.hrPeriodColumnLabel,
        value: hrDateRange(context, leave.startDate, leave.endDate),
      ),
      AppInfoSheetItem(label: l10n.hrPeriodStartLabel, value: start),
      AppInfoSheetItem(label: l10n.hrPeriodEndLabel, value: end),
      AppInfoSheetItem(
        label: l10n.hrLeaveCoveringStaffLabel,
        value: leave.coveringStaffName ?? leave.coveringStaffProfileId,
      ),
      AppInfoSheetItem(label: l10n.hrLeaveReasonLabel, value: leave.reason),
      AppInfoSheetItem(
        label: l10n.hrLeaveHandoverNotesLabel,
        value: leave.handoverNotes,
      ),
      if ((leave.displayId ?? leave.id).trim().isNotEmpty)
        AppInfoSheetItem(
          label: l10n.hrLeaveIdLabel,
          value: leave.displayId ?? leave.id,
          copyable: true,
        ),
    ];
  }

  String _statusDisplay(String? status) {
    final String normalized = (status ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return '';
    }
    return switch (normalized) {
      'APPROVED' => l10n.settingsLeaveStatusApproved,
      'REQUESTED' => l10n.settingsLeaveStatusRequested,
      'REJECTED' => l10n.settingsLeaveStatusRejected,
      'CANCELLED' => l10n.settingsLeaveStatusCancelled,
      _ => status!.trim(),
    };
  }
}

/// Builds calendar day previews for one or more leave records.
List<HrRosterDayPreview> hrLeaveCalendarDayPreviews(
  List<HrStaffLeave> leaves, {
  bool approvedOnly = false,
}) {
  final List<HrStaffLeave> visible = leaves.where((HrStaffLeave leave) {
    if (leave.startDate == null) {
      return false;
    }
    if (!approvedOnly) {
      return true;
    }
    return (leave.status ?? '').toUpperCase() == 'APPROVED';
  }).toList(growable: false);

  if (visible.isEmpty) {
    return const <HrRosterDayPreview>[];
  }

  DateTime rangeStart = DateTime(
    visible.first.startDate!.year,
    visible.first.startDate!.month,
    visible.first.startDate!.day,
  );
  DateTime rangeEnd = rangeStart;

  for (final HrStaffLeave leave in visible) {
    final DateTime start = DateTime(
      leave.startDate!.year,
      leave.startDate!.month,
      leave.startDate!.day,
    );
    final DateTime end = leave.endDate == null
        ? start
        : DateTime(
            leave.endDate!.year,
            leave.endDate!.month,
            leave.endDate!.day,
          );
    if (start.isBefore(rangeStart)) {
      rangeStart = start;
    }
    if (end.isAfter(rangeEnd)) {
      rangeEnd = end;
    }
  }

  // Expand to full months for calendar chrome.
  rangeStart = DateTime(rangeStart.year, rangeStart.month);
  rangeEnd = DateTime(rangeEnd.year, rangeEnd.month + 1, 0);

  bool isLeaveDay(DateTime day) {
    final DateTime cursor = DateTime(day.year, day.month, day.day);
    for (final HrStaffLeave leave in visible) {
      final DateTime start = DateTime(
        leave.startDate!.year,
        leave.startDate!.month,
        leave.startDate!.day,
      );
      final DateTime end = leave.endDate == null
          ? start
          : DateTime(
              leave.endDate!.year,
              leave.endDate!.month,
              leave.endDate!.day,
            );
      if (!cursor.isBefore(start) && !cursor.isAfter(end)) {
        return true;
      }
    }
    return false;
  }

  final List<HrRosterDayPreview> days = <HrRosterDayPreview>[];
  DateTime cursor = rangeStart;
  while (!cursor.isAfter(rangeEnd)) {
    final bool onLeave = isLeaveDay(cursor);
    final bool weekend =
        cursor.weekday == DateTime.saturday ||
        cursor.weekday == DateTime.sunday;
    days.add(
      HrRosterDayPreview(
        date: cursor,
        label: hrRosterDateKey(cursor),
        isHoliday: false,
        isLeave: onLeave,
        isWorkingDay: onLeave ? false : !weekend,
        dayStartMinutes: 8 * 60,
        dayEndMinutes: 17 * 60,
        shifts: const <HrRosterShiftWindow>[],
      ),
    );
    cursor = cursor.add(const Duration(days: 1));
  }
  return days;
}
