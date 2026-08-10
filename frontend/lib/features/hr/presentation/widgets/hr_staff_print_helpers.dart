import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_leave_detail_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_calendar_preview.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_print_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

enum HrStaffPrintSection {
  overview,
  assignments,
  rosters,
  leaves,
  payroll,
  roles,
  permissions,
}

/// How the Rosters section is rendered in staff print preview / printout.
enum HrStaffRosterPrintFormat { calendar, list, timeline }

final class HrStaffPrintOptionsController extends ChangeNotifier {
  HrStaffPrintOptionsController({
    Set<HrStaffPrintSection> initial = const <HrStaffPrintSection>{
      HrStaffPrintSection.overview,
      HrStaffPrintSection.assignments,
      HrStaffPrintSection.rosters,
      HrStaffPrintSection.leaves,
      HrStaffPrintSection.payroll,
      HrStaffPrintSection.roles,
      HrStaffPrintSection.permissions,
    },
    HrStaffRosterPrintFormat initialRosterFormat =
        HrStaffRosterPrintFormat.calendar,
  }) : _selected = Set<HrStaffPrintSection>.from(initial),
       _rosterFormat = initialRosterFormat;

  final Set<HrStaffPrintSection> _selected;
  HrStaffRosterPrintFormat _rosterFormat;

  Set<HrStaffPrintSection> get selectedSections =>
      Set<HrStaffPrintSection>.unmodifiable(_selected);

  Set<Object> get selectedIds => _selected.cast<Object>().toSet();

  HrStaffRosterPrintFormat get rosterFormat => _rosterFormat;

  bool get canPrint => _selected.isNotEmpty;

  void setSelection(Set<Object> selected) {
    final Set<HrStaffPrintSection> next = <HrStaffPrintSection>{
      for (final Object id in selected)
        if (id is HrStaffPrintSection) id,
    };
    if (next.length == _selected.length && _selected.containsAll(next)) {
      return;
    }
    _selected
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  void setRosterFormat(HrStaffRosterPrintFormat format) {
    if (_rosterFormat == format) {
      return;
    }
    _rosterFormat = format;
    notifyListeners();
  }
}

class HrStaffPrintOptionsSection extends StatelessWidget {
  const HrStaffPrintOptionsSection({required this.controller, super.key});

  final HrStaffPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final bool showRosterFormats = controller.selectedSections.contains(
          HrStaffPrintSection.rosters,
        );
        return AppFormSection(
          title: l10n.hrStaffPrintContentSection,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            Text(
              l10n.hrStaffPrintContentSectionHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: HrStaffPrintSection.overview,
                  title: l10n.hrStaffDetailsSectionTitle,
                  icon: Icons.badge_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.assignments,
                  title: l10n.hrAssignmentsSectionTitle,
                  icon: Icons.account_tree_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.rosters,
                  title: l10n.hrStaffRostersSectionTitle,
                  icon: Icons.calendar_month_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.leaves,
                  title: l10n.hrStaffLeavesSectionTitle,
                  icon: Icons.event_busy_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.payroll,
                  title: l10n.hrStaffPayrollSectionTitle,
                  icon: Icons.payments_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.roles,
                  title: l10n.hrRolesSectionTitle,
                  icon: Icons.badge_outlined,
                ),
                AppReportSectionData(
                  id: HrStaffPrintSection.permissions,
                  title: l10n.hrStaffPermissionsSectionTitle,
                  icon: Icons.shield_outlined,
                ),
              ],
              selectedIds: controller.selectedIds,
              onSelectionChanged: controller.setSelection,
            ),
            if (showRosterFormats) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              Text(
                l10n.hrStaffPrintRosterFormatHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              AppRadioGroup<HrStaffRosterPrintFormat>(
                labelText: l10n.hrStaffPrintRosterFormatTitle,
                presentation: AppRadioGroupPresentation.borderless,
                layout: AppRadioGroupLayout.wrap,
                dense: true,
                itemMinWidth: 140,
                value: controller.rosterFormat,
                options: <AppRadioOption<HrStaffRosterPrintFormat>>[
                  AppRadioOption<HrStaffRosterPrintFormat>(
                    value: HrStaffRosterPrintFormat.calendar,
                    label: l10n.hrStaffPrintRosterFormatCalendar,
                  ),
                  AppRadioOption<HrStaffRosterPrintFormat>(
                    value: HrStaffRosterPrintFormat.list,
                    label: l10n.hrStaffPrintRosterFormatList,
                  ),
                  AppRadioOption<HrStaffRosterPrintFormat>(
                    value: HrStaffRosterPrintFormat.timeline,
                    label: l10n.hrStaffPrintRosterFormatTimeline,
                  ),
                ],
                onChanged: (HrStaffRosterPrintFormat? value) {
                  if (value != null) {
                    controller.setRosterFormat(value);
                  }
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

Future<void> showHrStaffPrintPreview({
  required BuildContext context,
  required WidgetRef ref,
  required HrStaffDetail detail,
}) async {
  final AppLocalizations l10n = context.l10n;
  final HrStaffProfile profile = detail.profile;
  final HrStaffPrintOptionsController options = HrStaffPrintOptionsController();

  String buildBodyHtml() => buildHrStaffPrintHtml(
    l10n,
    detail,
    options.selectedSections,
    rosterFormat: options.rosterFormat,
  );

  try {
    await PrintDocumentTemplates.registry(
      ref: ref,
      context: context,
      title: profile.displayName,
      subtitle: profile.staffNumber ?? profile.effectiveId,
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewDialogTitle: l10n.hrStaffPrintDialogTitle,
      previewSectionsExtra: HrStaffPrintOptionsSection(controller: options),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
    );
  } finally {
    options.dispose();
  }
}

String buildHrStaffPrintHtml(
  AppLocalizations l10n,
  HrStaffDetail detail,
  Set<HrStaffPrintSection> sections, {
  HrStaffRosterPrintFormat rosterFormat = HrStaffRosterPrintFormat.calendar,
}) {
  final HrStaffProfile profile = detail.profile;
  final StringBuffer buffer = StringBuffer();
  buffer.writeln(
    '<div style="font-family:Segoe UI,Arial,sans-serif;color:#1A237E;">'
    '<h1 style="margin:0 0 4px;font-size:22px;">${_esc(profile.displayName)}</h1>'
    '<p style="margin:0 0 18px;color:#546E7A;font-size:13px;">'
    '${_esc(profile.staffNumber ?? profile.effectiveId)}'
    '${profile.position == null ? '' : ' · ${_esc(profile.position!)}'}'
    '</p>',
  );

  if (sections.contains(HrStaffPrintSection.overview)) {
    buffer.writeln(_sectionTitle(l10n.hrStaffDetailsSectionTitle));
    buffer.writeln(_tableStart());
    _row(buffer, l10n.hrPositionLabel, profile.position ?? '—');
    _row(
      buffer,
      l10n.hrPractitionerTypeLabel,
      l10n.hrReferencePractitionerTypeLabel(
        profile.practitionerType,
        fallback: profile.practitionerType ?? '—',
      ),
    );
    _row(
      buffer,
      l10n.hrDepartmentLabel,
      profile.departmentName ?? profile.departmentDisplayId ?? '—',
    );
    _row(buffer, l10n.hrStatusLabel, profile.status ?? '—');
    _row(buffer, l10n.hrEmailLabel, profile.userEmail ?? '—');
    buffer.writeln(_tableEnd());
  }

  if (sections.contains(HrStaffPrintSection.assignments)) {
    buffer.writeln(_sectionTitle(l10n.hrAssignmentsSectionTitle));
    final List<HrStaffAssignment> rows = detail.assignments
        .where((HrStaffAssignment row) => row.isActive)
        .toList(growable: false);
    if (rows.isEmpty) {
      buffer.writeln(
        '<p style="color:#78909C;">${_esc(l10n.hrNoAssignmentsLabel)}</p>',
      );
    } else {
      buffer.writeln(_tableStart());
      for (final HrStaffAssignment assignment in rows) {
        _row(
          buffer,
          hrAssignmentTitle(assignment, l10n),
          assignment.isPrimary ? l10n.hrPrimaryAssignmentLabel : '—',
        );
      }
      buffer.writeln(_tableEnd());
    }
  }

  if (sections.contains(HrStaffPrintSection.rosters)) {
    buffer.writeln(_sectionTitle(l10n.hrStaffRostersSectionTitle));
    buffer.writeln(
      _buildStaffRostersHtml(
        l10n,
        detail.shiftAssignments,
        format: rosterFormat,
      ),
    );
  }

  if (sections.contains(HrStaffPrintSection.leaves)) {
    buffer.writeln(_sectionTitle(l10n.hrStaffLeavesSectionTitle));
    if (detail.leaves.isEmpty) {
      buffer.writeln(
        '<p style="color:#78909C;">${_esc(l10n.hrNoLeaveLabel)}</p>',
      );
    } else {
      buffer.writeln(
        '<h3 style="margin:0 0 8px;font-size:13px;">${_esc(l10n.hrLeavePrintListHeading)}</h3>',
      );
      buffer.writeln(_tableStart());
      for (final HrStaffLeave leave in detail.leaves) {
        final String typeLabel = l10n.hrReferenceLeaveTypeLabel(
          leave.leaveType,
          fallback: leave.leaveType ?? l10n.hrLeaveLabel,
        );
        final String status = _leaveStatusLabel(l10n, leave.status);
        final String period = _leavePeriodLabel(leave);
        _row(buffer, typeLabel, '$status · $period');
        if ((leave.reason ?? '').trim().isNotEmpty) {
          _row(buffer, l10n.hrLeaveReasonLabel, leave.reason!.trim());
        }
        if ((leave.coveringStaffName ?? leave.coveringStaffProfileId ?? '')
            .trim()
            .isNotEmpty) {
          _row(
            buffer,
            l10n.hrLeaveCoveringStaffLabel,
            (leave.coveringStaffName ?? leave.coveringStaffProfileId)!.trim(),
          );
        }
      }
      buffer.writeln(_tableEnd());

      final List<HrRosterDayPreview> leaveDays = hrLeaveCalendarDayPreviews(
        detail.leaves,
      );
      if (leaveDays.isNotEmpty) {
        buffer.writeln(
          '<h3 style="margin:16px 0 8px;font-size:13px;">${_esc(l10n.hrLeavePrintCalendarHeading)}</h3>',
        );
        buffer.writeln(
          hrRosterPrintScheduleHtml(
            l10n,
            leaveDays,
            includeHeading: false,
          ),
        );
      }
    }
  }

  if (sections.contains(HrStaffPrintSection.payroll)) {
    buffer.writeln(_sectionTitle(l10n.hrStaffPayrollSectionTitle));
    final List<HrStaffCompensation> comps = detail.compensations
        .where((HrStaffCompensation row) => row.isActive)
        .toList(growable: false);
    if (comps.isEmpty && profile.consultationFee == null) {
      buffer.writeln(
        '<p style="color:#78909C;">${_esc(l10n.hrNoCompensationLabel)}</p>',
      );
    } else {
      buffer.writeln(_tableStart());
      for (final HrStaffCompensation row in comps) {
        _row(
          buffer,
          l10n.hrReferenceCompensationPayTypeLabel(
            row.payType ?? '',
            fallback: row.payType ?? '—',
          ),
          '${row.rate ?? '—'} ${row.currency ?? ''}'.trim(),
        );
      }
      if (profile.consultationFee != null) {
        _row(
          buffer,
          l10n.hrConsultationFeeLabel,
          '${profile.consultationFee} ${profile.consultationCurrency ?? ''}'
              .trim(),
        );
      }
      buffer.writeln(_tableEnd());
    }
  }

  if (sections.contains(HrStaffPrintSection.roles)) {
    buffer.writeln(_sectionTitle(l10n.hrRolesSectionTitle));
    final List<HrUserRole> roles =
        detail.accessSummary?.userRoles ?? const <HrUserRole>[];
    if (roles.isEmpty) {
      buffer.writeln(
        '<p style="color:#78909C;">${_esc(l10n.hrNoRolesLabel)}</p>',
      );
    } else {
      buffer.writeln(
        '<p>${roles.map((HrUserRole role) => _esc(role.roleName ?? role.roleId ?? '')).where((String v) => v.isNotEmpty).join(' · ')}</p>',
      );
    }
  }

  if (sections.contains(HrStaffPrintSection.permissions)) {
    buffer.writeln(_sectionTitle(l10n.hrStaffPermissionsSectionTitle));
    final List<String> permissions =
        detail.accessSummary?.effectivePermissions ?? const <String>[];
    if (permissions.isEmpty) {
      buffer.writeln(
        '<p style="color:#78909C;">${_esc(l10n.hrStaffPermissionsEmptyTitle)}</p>',
      );
    } else {
      buffer.writeln(
        '<p style="font-size:12px;line-height:1.6;">${permissions.map(_esc).join(' · ')}</p>',
      );
    }
  }

  buffer.writeln('</div>');
  return buffer.toString();
}

String _buildStaffRostersHtml(
  AppLocalizations l10n,
  List<HrShiftAssignment> assignments, {
  required HrStaffRosterPrintFormat format,
}) {
  if (assignments.every(
    (HrShiftAssignment row) => row.startTime == null || row.endTime == null,
  )) {
    return '<p style="color:#78909C;">${_esc(l10n.hrStaffRostersEmptyTitle)}</p>';
  }

  final List<HrRosterDayPreview> days = hrStaffRosterDayPreviews(assignments);
  return switch (format) {
    HrStaffRosterPrintFormat.calendar => hrRosterPrintScheduleHtml(
      l10n,
      days,
      includeHeading: false,
    ),
    HrStaffRosterPrintFormat.list => _staffRosterListHtml(l10n, assignments),
    HrStaffRosterPrintFormat.timeline => _staffRosterTimelineHtml(l10n, days),
  };
}

/// Builds calendar day previews from staff shift assignments.
List<HrRosterDayPreview> hrStaffRosterDayPreviews(
  List<HrShiftAssignment> assignments,
) {
  final DateTime now = DateTime.now();
  final DateTime from = DateTime(now.year, now.month);
  final DateTime to = DateTime(now.year, now.month + 1, 0);
  final Map<String, List<HrRosterShiftWindow>> byDay =
      <String, List<HrRosterShiftWindow>>{};

  for (final HrShiftAssignment assignment in assignments) {
    final DateTime? start = assignment.startTime?.toLocal();
    final DateTime? end = assignment.endTime?.toLocal();
    if (start == null || end == null) {
      continue;
    }
    final String key = hrRosterDateKey(start);
    byDay
        .putIfAbsent(key, () => <HrRosterShiftWindow>[])
        .add(
          HrRosterShiftWindow(
            start: start,
            end: end,
            staffNames: const <String>[],
            shiftType: assignment.shiftType,
          ),
        );
  }

  DateTime rangeStart = from;
  DateTime rangeEnd = to;
  if (byDay.isNotEmpty) {
    final List<DateTime> dated = byDay.keys
        .map(DateTime.parse)
        .toList(growable: false)
      ..sort();
    if (dated.first.isBefore(rangeStart)) {
      rangeStart = DateTime(dated.first.year, dated.first.month);
    }
    if (dated.last.isAfter(rangeEnd)) {
      rangeEnd = DateTime(dated.last.year, dated.last.month + 1, 0);
    }
  }

  final List<HrRosterDayPreview> days = <HrRosterDayPreview>[];
  DateTime cursor = rangeStart;
  while (!cursor.isAfter(rangeEnd)) {
    final String key = hrRosterDateKey(cursor);
    final List<HrRosterShiftWindow> dayShifts =
        List<HrRosterShiftWindow>.from(
          byDay[key] ?? const <HrRosterShiftWindow>[],
        )..sort(
          (HrRosterShiftWindow a, HrRosterShiftWindow b) =>
              a.start.compareTo(b.start),
        );
    final bool weekend =
        cursor.weekday == DateTime.saturday ||
        cursor.weekday == DateTime.sunday;
    days.add(
      HrRosterDayPreview(
        date: cursor,
        label: key,
        isHoliday: false,
        isWorkingDay: dayShifts.isNotEmpty || !weekend,
        dayStartMinutes: 8 * 60,
        dayEndMinutes: 17 * 60,
        shifts: dayShifts,
      ),
    );
    cursor = cursor.add(const Duration(days: 1));
  }
  return days;
}

String _staffRosterListHtml(
  AppLocalizations l10n,
  List<HrShiftAssignment> assignments,
) {
  final List<HrShiftAssignment> rows =
      assignments
          .where(
            (HrShiftAssignment row) =>
                row.startTime != null && row.endTime != null,
          )
          .toList(growable: false)
        ..sort((HrShiftAssignment a, HrShiftAssignment b) {
          final DateTime aStart = a.startTime!;
          final DateTime bStart = b.startTime!;
          return aStart.compareTo(bStart);
        });

  if (rows.isEmpty) {
    return '<p style="color:#78909C;">${_esc(l10n.hrStaffRostersEmptyTitle)}</p>';
  }

  final StringBuffer buffer = StringBuffer();
  buffer.writeln(
    '<table style="width:100%;border-collapse:collapse;font-size:11px;">'
    '<thead><tr>'
    '<th style="text-align:left;padding:6px;border-bottom:1px solid #CFD8DC;">${_esc(l10n.hrPeriodColumnLabel)}</th>'
    '<th style="text-align:left;padding:6px;border-bottom:1px solid #CFD8DC;">${_esc(l10n.hrShiftTypeLabel)}</th>'
    '<th style="text-align:left;padding:6px;border-bottom:1px solid #CFD8DC;">${_esc(l10n.hrStaffRostersSectionTitle)}</th>'
    '<th style="text-align:left;padding:6px;border-bottom:1px solid #CFD8DC;">${_esc(l10n.hrStatusColumnLabel)}</th>'
    '</tr></thead><tbody>',
  );
  for (final HrShiftAssignment shift in rows) {
    final String when =
        '${AppFormatters.dateTime(shift.startTime!, const Locale('en'))}'
        ' – '
        '${AppFormatters.dateTime(shift.endTime!, const Locale('en'))}';
    buffer.writeln(
      '<tr>'
      '<td style="padding:6px;border-bottom:1px solid #ECEFF1;">${_esc(when)}</td>'
      '<td style="padding:6px;border-bottom:1px solid #ECEFF1;">${_esc(shift.shiftType ?? '—')}</td>'
      '<td style="padding:6px;border-bottom:1px solid #ECEFF1;">${_esc(shift.shiftName ?? shift.rosterId ?? shift.displayId ?? shift.id)}</td>'
      '<td style="padding:6px;border-bottom:1px solid #ECEFF1;">${_esc(shift.shiftStatus ?? '—')}</td>'
      '</tr>',
    );
  }
  buffer.writeln('</tbody></table>');
  return buffer.toString();
}

String _staffRosterTimelineHtml(
  AppLocalizations l10n,
  List<HrRosterDayPreview> days,
) {
  final List<HrRosterDayPreview> withShifts = days
      .where((HrRosterDayPreview day) => day.shifts.isNotEmpty)
      .toList(growable: false);
  if (withShifts.isEmpty) {
    return '<p style="color:#78909C;">${_esc(l10n.hrStaffRostersEmptyTitle)}</p>';
  }

  final StringBuffer buffer = StringBuffer();
  buffer.writeln(
    '<p style="margin:0 0 10px;color:#546E7A;font-size:11px;">'
    '${_esc(l10n.hrStaffPrintRosterFormatTimeline)}'
    '</p>',
  );

  DateTime? weekStart;
  for (final HrRosterDayPreview day in withShifts) {
    final DateTime monday = day.date.subtract(
      Duration(days: day.date.weekday - DateTime.monday),
    );
    if (weekStart == null || monday != weekStart) {
      weekStart = monday;
      final DateTime sunday = monday.add(const Duration(days: 6));
      buffer.writeln(
        '<div style="font-weight:700;font-size:12px;margin:12px 0 6px;">'
        '${_esc('${hrRosterDateKey(monday)} – ${hrRosterDateKey(sunday)}')}'
        '</div>',
      );
    }

    final String blocks = day.shifts
        .map((HrRosterShiftWindow shift) {
          return '<span style="display:inline-block;margin:2px 4px 2px 0;padding:4px 8px;border-radius:6px;background:#1565C0;color:#fff;font-size:10px;">'
              '${_esc('${hrRosterFormatHm(shift.start)}–${hrRosterFormatHm(shift.end)}')}'
              '${shift.shiftType == null || shift.shiftType!.trim().isEmpty ? '' : ' · ${_esc(shift.shiftType!)}'}'
              '</span>';
        })
        .join();

    buffer.writeln(
      '<div style="display:flex;align-items:flex-start;gap:10px;padding:6px 0;border-bottom:1px solid #ECEFF1;">'
      '<div style="width:88px;flex-shrink:0;font-size:11px;font-weight:600;color:#37474F;">${_esc(day.label)}</div>'
      '<div style="flex:1;">$blocks</div>'
      '</div>',
    );
  }
  return buffer.toString();
}

String _sectionTitle(String title) =>
    '<h2 style="margin:18px 0 8px;font-size:15px;border-bottom:2px solid #E3F2FD;padding-bottom:6px;">${_esc(title)}</h2>';

String _tableStart() =>
    '<table style="width:100%;border-collapse:collapse;margin:0 0 8px;font-size:12px;"><tbody>';

String _tableEnd() => '</tbody></table>';

void _row(StringBuffer buffer, String label, String value) {
  buffer.writeln(
    '<tr>'
    '<td style="padding:8px 10px;width:34%;color:#546E7A;border-bottom:1px solid #ECEFF1;">${_esc(label)}</td>'
    '<td style="padding:8px 10px;border-bottom:1px solid #ECEFF1;font-weight:600;">${_esc(value)}</td>'
    '</tr>',
  );
}

String _leaveStatusLabel(AppLocalizations l10n, String? status) {
  final String normalized = (status ?? '').trim().toUpperCase();
  if (normalized.isEmpty) {
    return '—';
  }
  return switch (normalized) {
    'APPROVED' => l10n.settingsLeaveStatusApproved,
    'REQUESTED' => l10n.settingsLeaveStatusRequested,
    'REJECTED' => l10n.settingsLeaveStatusRejected,
    'CANCELLED' => l10n.settingsLeaveStatusCancelled,
    _ => status!.trim(),
  };
}

String _leavePeriodLabel(HrStaffLeave leave) {
  final String? start = leave.startDate?.toIso8601String().substring(0, 10);
  final String? end = leave.endDate?.toIso8601String().substring(0, 10);
  if (start == null && end == null) {
    return '—';
  }
  if (start == null) {
    return end!;
  }
  if (end == null || end == start) {
    return start;
  }
  return '$start – $end';
}

String _esc(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
