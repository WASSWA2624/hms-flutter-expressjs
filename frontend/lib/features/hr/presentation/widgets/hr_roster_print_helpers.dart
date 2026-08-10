import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_calendar_preview.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Printable content sections for a roster template.
enum HrRosterPrintSection {
  overview,
  schedule,
  staff,
}

/// Mutable section selection for live roster print-preview rebuilds.
final class HrRosterPrintOptionsController extends ChangeNotifier {
  HrRosterPrintOptionsController({
    Set<HrRosterPrintSection> initial = const <HrRosterPrintSection>{
      HrRosterPrintSection.overview,
      HrRosterPrintSection.schedule,
      HrRosterPrintSection.staff,
    },
  }) : _selected = Set<HrRosterPrintSection>.from(initial);

  final Set<HrRosterPrintSection> _selected;

  Set<HrRosterPrintSection> get selectedSections =>
      Set<HrRosterPrintSection>.unmodifiable(_selected);

  Set<Object> get selectedIds => _selected.cast<Object>().toSet();

  bool get canPrint => _selected.isNotEmpty;

  bool isSelected(HrRosterPrintSection section) => _selected.contains(section);

  void setSelection(Set<Object> selected) {
    final Set<HrRosterPrintSection> next = <HrRosterPrintSection>{
      for (final Object id in selected)
        if (id is HrRosterPrintSection) id,
    };
    if (next.length == _selected.length && _selected.containsAll(next)) {
      return;
    }
    _selected
      ..clear()
      ..addAll(next);
    notifyListeners();
  }
}

/// Collapsible roster content toggles for the shared print-preview dialog.
class HrRosterPrintOptionsSection extends StatelessWidget {
  const HrRosterPrintOptionsSection({required this.controller, super.key});

  final HrRosterPrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        return AppFormSection(
          title: l10n.hrRosterPrintContentSection,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            Text(
              l10n.hrRosterPrintContentSectionHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: HrRosterPrintSection.overview,
                  title: l10n.hrRosterPrintOverviewSection,
                  icon: Icons.info_outline,
                ),
                AppReportSectionData(
                  id: HrRosterPrintSection.schedule,
                  title: l10n.hrRosterPrintScheduleSection,
                  icon: Icons.calendar_month_outlined,
                ),
                AppReportSectionData(
                  id: HrRosterPrintSection.staff,
                  title: l10n.hrRosterPrintStaffSection,
                  icon: Icons.groups_outlined,
                ),
              ],
              selectedIds: controller.selectedIds,
              onSelectionChanged: controller.setSelection,
            ),
          ],
        );
      },
    );
  }
}

String hrRosterEscapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

/// Visual month-calendar HTML that mirrors the on-screen roster template preview.
String hrRosterPrintScheduleHtml(
  AppLocalizations l10n,
  List<HrRosterDayPreview> days, {
  bool includeHeading = true,
  bool includeDayDetails = true,
}) {
  if (days.isEmpty) {
    return '<p>${hrRosterEscapeHtml(l10n.hrRosterNoSchedulePreviewLabel)}</p>';
  }

  final StringBuffer buffer = StringBuffer();
  if (includeHeading) {
    buffer.writeln(
      '<h2>${hrRosterEscapeHtml(l10n.hrRosterPreviewSectionTitle)}</h2>',
    );
  }
  buffer.writeln(_legendHtml(l10n));

  final Map<String, List<HrRosterDayPreview>> byMonth =
      <String, List<HrRosterDayPreview>>{};
  for (final HrRosterDayPreview day in days) {
    final String key =
        '${day.date.year.toString().padLeft(4, '0')}-${day.date.month.toString().padLeft(2, '0')}';
    byMonth.putIfAbsent(key, () => <HrRosterDayPreview>[]).add(day);
  }

  for (final MapEntry<String, List<HrRosterDayPreview>> entry
      in byMonth.entries) {
    final List<HrRosterDayPreview> monthDays = entry.value;
    final DateTime focus = monthDays.first.date;
    buffer.writeln(_monthCalendarHtml(l10n, focus: focus, days: monthDays));
  }

  if (includeDayDetails) {
    buffer.writeln(
      '<h3>${hrRosterEscapeHtml(l10n.hrRosterPrintDayDetailsHeading)}</h3>',
    );
    buffer.writeln(
      '<table class="roster-day-details" style="width:100%;border-collapse:collapse;font-size:11px;">'
      '<thead><tr>'
      '<th style="text-align:left;padding:6px;border-bottom:1px solid #CFD8DC;">${hrRosterEscapeHtml(l10n.hrPeriodColumnLabel)}</th>'
      '<th style="text-align:left;padding:6px;border-bottom:1px solid #CFD8DC;">${hrRosterEscapeHtml(l10n.hrStatusColumnLabel)}</th>'
      '<th style="text-align:left;padding:6px;border-bottom:1px solid #CFD8DC;">${hrRosterEscapeHtml(l10n.hrRosterAttachedStaffTitle)}</th>'
      '</tr></thead><tbody>',
    );
    for (final HrRosterDayPreview day in days) {
      if (!day.isWorkingDay && day.shifts.isEmpty && !day.isHoliday) {
        continue;
      }
      final String staff = day.staffNames.isEmpty
          ? '—'
          : day.staffNames.join(', ');
      final String shifts = day.shifts.isEmpty
          ? ''
          : '<div style="color:#546E7A;margin-top:2px;">${hrRosterEscapeHtml(day.shifts.map((HrRosterShiftWindow shift) => shift.summary).join('; '))}</div>';
      buffer.writeln(
        '<tr>'
        '<td style="padding:6px;border-bottom:1px solid #ECEFF1;vertical-align:top;">${hrRosterEscapeHtml(day.label)}</td>'
        '<td style="padding:6px;border-bottom:1px solid #ECEFF1;vertical-align:top;">'
        '<span style="display:inline-block;padding:2px 8px;border-radius:999px;background:${_toneBackground(day.tone)};color:${_toneForeground(day.tone)};">${hrRosterEscapeHtml(day.statusLabel(l10n))}</span>'
        '$shifts'
        '</td>'
        '<td style="padding:6px;border-bottom:1px solid #ECEFF1;vertical-align:top;">${hrRosterEscapeHtml(staff)}</td>'
        '</tr>',
      );
    }
    buffer.writeln('</tbody></table>');
  }
  return buffer.toString();
}

String _legendHtml(AppLocalizations l10n) {
  final List<(String, String, String)> items = <(String, String, String)>[
    (l10n.hrRosterAvailableLabel, '#1565C0', '#FFFFFF'),
    (l10n.hrRosterFreeHoursLabel, '#BBDEFB', '#0D47A1'),
    (l10n.hrRosterPublicHolidayLabel, '#2E7D32', '#FFFFFF'),
    (l10n.hrRosterDayOffLabel, '#ECEFF1', '#455A64'),
  ];
  final StringBuffer buffer = StringBuffer(
    '<div style="display:flex;flex-wrap:wrap;gap:10px;margin:0 0 12px;font-size:11px;">',
  );
  for (final (String label, String bg, String fg) in items) {
    buffer.write(
      '<span style="display:inline-flex;align-items:center;gap:6px;">'
      '<span style="width:12px;height:12px;border-radius:50%;background:$bg;border:1px solid #90A4AE;"></span>'
      '<span style="color:$fg;background:$bg;padding:1px 6px;border-radius:999px;">${hrRosterEscapeHtml(label)}</span>'
      '</span>',
    );
  }
  buffer.write('</div>');
  return buffer.toString();
}

String _monthCalendarHtml(
  AppLocalizations l10n, {
  required DateTime focus,
  required List<HrRosterDayPreview> days,
}) {
  final DateTime first = DateTime(focus.year, focus.month, 1);
  final DateTime last = DateTime(focus.year, focus.month + 1, 0);
  final int leading = (first.weekday - DateTime.monday) % 7;
  final int trailing = (DateTime.sunday - last.weekday) % 7;
  final int totalCells = leading + last.day + trailing;
  final Map<String, HrRosterDayPreview> byKey = <String, HrRosterDayPreview>{
    for (final HrRosterDayPreview day in days) hrRosterDateKey(day.date): day,
  };
  final String heading =
      '${focus.year}-${focus.month.toString().padLeft(2, '0')}';

  final StringBuffer buffer = StringBuffer();
  buffer.writeln(
    '<div style="margin:0 0 16px;">'
    '<div style="font-weight:700;font-size:13px;margin:0 0 8px;">${hrRosterEscapeHtml(heading)}</div>'
    '<table style="width:100%;border-collapse:separate;border-spacing:4px;table-layout:fixed;">'
    '<thead><tr>',
  );
  for (final int weekday in const <int>[1, 2, 3, 4, 5, 6, 7]) {
    final String label = hrDayLabel(l10n, weekday == 7 ? 0 : weekday);
    final String short = label.trim().isEmpty
        ? ''
        : String.fromCharCode(label.trim().runes.first);
    buffer.write(
      '<th style="padding:4px;font-size:10px;color:#546E7A;text-align:center;">${hrRosterEscapeHtml(short)}</th>',
    );
  }
  buffer.writeln('</tr></thead><tbody>');

  for (int index = 0; index < totalCells; index += 1) {
    if (index % 7 == 0) {
      buffer.write('<tr>');
    }
    final int dayNumber = index - leading + 1;
    if (dayNumber < 1 || dayNumber > last.day) {
      buffer.write(
        '<td style="height:54px;background:#FAFAFA;border:1px dashed #E0E0E0;border-radius:8px;"></td>',
      );
    } else {
      final DateTime date = DateTime(focus.year, focus.month, dayNumber);
      final HrRosterDayPreview? day = byKey[hrRosterDateKey(date)];
      final HrRosterDayTone tone = day?.tone ?? HrRosterDayTone.off;
      final String bg = _toneBackground(tone);
      final String fg = _toneForeground(tone);
      final String detail = day == null || day.shifts.isEmpty
          ? ''
          : '<div style="font-size:9px;line-height:1.2;margin-top:4px;opacity:0.95;">${hrRosterEscapeHtml(_shortShiftSummary(day))}</div>';
      buffer.write(
        '<td style="height:54px;vertical-align:top;padding:6px;border-radius:8px;background:$bg;color:$fg;border:1px solid rgba(0,0,0,0.06);">'
        '<div style="font-weight:700;font-size:12px;">$dayNumber</div>'
        '$detail'
        '</td>',
      );
    }
    if (index % 7 == 6) {
      buffer.writeln('</tr>');
    }
  }
  buffer.writeln('</tbody></table></div>');
  return buffer.toString();
}

String _shortShiftSummary(HrRosterDayPreview day) {
  if (day.shifts.isEmpty) {
    return '';
  }
  if (day.shifts.length == 1) {
    final HrRosterShiftWindow shift = day.shifts.first;
    return '${hrRosterFormatHm(shift.start)}–${hrRosterFormatHm(shift.end)}';
  }
  return '${day.shifts.length} shifts';
}

String _toneBackground(HrRosterDayTone tone) {
  return switch (tone) {
    HrRosterDayTone.holiday => '#2E7D32',
    HrRosterDayTone.off => '#ECEFF1',
    HrRosterDayTone.busy => '#1565C0',
    HrRosterDayTone.free => '#BBDEFB',
    HrRosterDayTone.mixed => '#1976D2',
  };
}

String _toneForeground(HrRosterDayTone tone) {
  return switch (tone) {
    HrRosterDayTone.holiday => '#FFFFFF',
    HrRosterDayTone.off => '#455A64',
    HrRosterDayTone.busy => '#FFFFFF',
    HrRosterDayTone.free => '#0D47A1',
    HrRosterDayTone.mixed => '#FFFFFF',
  };
}
