import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum HrRosterPreviewMode { month, week, day }

enum HrRosterPeriodScope { day, week, month }

enum HrRosterDayTone { holiday, off, busy, free, mixed }

@immutable
final class HrRosterMinuteRange {
  const HrRosterMinuteRange({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;

  String get label =>
      '${hrRosterFormatMinutes(startMinutes)}–${hrRosterFormatMinutes(endMinutes)}';
}

@immutable
final class HrRosterShiftWindow {
  const HrRosterShiftWindow({
    required this.start,
    required this.end,
    required this.staffNames,
    this.shiftType,
  });

  final DateTime start;
  final DateTime end;
  final List<String> staffNames;
  final String? shiftType;

  int get startMinutes {
    final DateTime local = start.toLocal();
    return local.hour * 60 + local.minute;
  }

  int get endMinutes {
    final DateTime local = end.toLocal();
    final int raw = local.hour * 60 + local.minute;
    return raw <= startMinutes ? raw + (24 * 60) : raw;
  }

  String get summary {
    final String staff = staffNames.isEmpty ? '' : ' (${staffNames.join(', ')})';
    return '${hrRosterFormatHm(start)}–${hrRosterFormatHm(end)}$staff';
  }
}

@immutable
final class HrRosterDayPreview {
  const HrRosterDayPreview({
    required this.date,
    required this.label,
    required this.isHoliday,
    required this.isWorkingDay,
    required this.dayStartMinutes,
    required this.dayEndMinutes,
    required this.shifts,
  });

  final DateTime date;
  final String label;
  final bool isHoliday;
  final bool isWorkingDay;
  final int dayStartMinutes;
  final int dayEndMinutes;
  final List<HrRosterShiftWindow> shifts;

  List<HrRosterMinuteRange> get busyRanges {
    if (!isWorkingDay) {
      return const <HrRosterMinuteRange>[];
    }
    final List<HrRosterMinuteRange> ranges = <HrRosterMinuteRange>[];
    for (final HrRosterShiftWindow shift in shifts) {
      final int start = shift.startMinutes.clamp(dayStartMinutes, dayEndMinutes);
      final int end = shift.endMinutes.clamp(dayStartMinutes, dayEndMinutes);
      if (end > start) {
        ranges.add(HrRosterMinuteRange(startMinutes: start, endMinutes: end));
      }
    }
    return hrRosterMergeRanges(ranges);
  }

  List<HrRosterMinuteRange> get freeRanges {
    if (!isWorkingDay) {
      return const <HrRosterMinuteRange>[];
    }
    final List<HrRosterMinuteRange> busy = busyRanges;
    if (busy.isEmpty) {
      return <HrRosterMinuteRange>[
        HrRosterMinuteRange(
          startMinutes: dayStartMinutes,
          endMinutes: dayEndMinutes,
        ),
      ];
    }
    final List<HrRosterMinuteRange> free = <HrRosterMinuteRange>[];
    int cursor = dayStartMinutes;
    for (final HrRosterMinuteRange range in busy) {
      if (range.startMinutes > cursor) {
        free.add(
          HrRosterMinuteRange(
            startMinutes: cursor,
            endMinutes: range.startMinutes,
          ),
        );
      }
      cursor = range.endMinutes > cursor ? range.endMinutes : cursor;
    }
    if (cursor < dayEndMinutes) {
      free.add(
        HrRosterMinuteRange(startMinutes: cursor, endMinutes: dayEndMinutes),
      );
    }
    return free;
  }

  HrRosterDayTone get tone {
    if (isHoliday) {
      return HrRosterDayTone.holiday;
    }
    if (!isWorkingDay) {
      return HrRosterDayTone.off;
    }
    if (shifts.isEmpty) {
      return HrRosterDayTone.free;
    }
    if (freeRanges.isEmpty) {
      return HrRosterDayTone.busy;
    }
    return HrRosterDayTone.mixed;
  }

  String statusLabel(AppLocalizations l10n) {
    if (isHoliday) {
      return l10n.hrRosterPublicHolidayLabel;
    }
    if (!isWorkingDay) {
      return l10n.hrRosterDayOffLabel;
    }
    if (shifts.isEmpty) {
      return l10n.hrRosterUnassignedDayLabel;
    }
    if (freeRanges.isEmpty) {
      return l10n.hrRosterAvailableLabel;
    }
    return '${l10n.hrRosterAvailableLabel} / ${l10n.hrRosterFreeHoursLabel}';
  }

  List<String> get staffNames {
    final Set<String> names = <String>{};
    for (final HrRosterShiftWindow shift in shifts) {
      names.addAll(shift.staffNames);
    }
    return names.toList(growable: false);
  }
}

@immutable
final class HrRosterPeriodDetails {
  const HrRosterPeriodDetails({
    required this.scope,
    required this.days,
    required this.focus,
  });

  final HrRosterPeriodScope scope;
  final List<HrRosterDayPreview> days;
  final DateTime focus;
}

/// Compact Google Calendar–style roster board (no in-section scrolling).
class HrRosterCalendarPreview extends StatefulWidget {
  const HrRosterCalendarPreview({
    required this.days,
    required this.onShowDetails,
    this.expanded = false,
    super.key,
  });

  final List<HrRosterDayPreview> days;
  final ValueChanged<HrRosterPeriodDetails> onShowDetails;
  final bool expanded;

  @override
  State<HrRosterCalendarPreview> createState() =>
      _HrRosterCalendarPreviewState();
}

class _HrRosterCalendarPreviewState extends State<HrRosterCalendarPreview> {
  HrRosterPreviewMode _mode = HrRosterPreviewMode.month;
  late DateTime _focus;
  bool _showMini = true;

  @override
  void initState() {
    super.initState();
    _focus = hrRosterDateOnly(widget.days.first.date);
  }

  @override
  void didUpdateWidget(covariant HrRosterCalendarPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days.isEmpty && widget.days.isNotEmpty) {
      _focus = hrRosterDateOnly(widget.days.first.date);
    }
  }

  Map<String, HrRosterDayPreview> get _byKey => <String, HrRosterDayPreview>{
    for (final HrRosterDayPreview day in widget.days) day.label: day,
  };

  DateTime get _periodStart => hrRosterDateOnly(widget.days.first.date);
  DateTime get _periodEnd => hrRosterDateOnly(widget.days.last.date);

  int get _gridStartMinutes {
    if (widget.days.isEmpty) {
      return 8 * 60;
    }
    return widget.days
        .map((HrRosterDayPreview d) => d.dayStartMinutes)
        .reduce((int a, int b) => a < b ? a : b);
  }

  int get _gridEndMinutes {
    if (widget.days.isEmpty) {
      return 17 * 60;
    }
    return widget.days
        .map((HrRosterDayPreview d) => d.dayEndMinutes)
        .reduce((int a, int b) => a > b ? a : b);
  }

  void _setFocus(DateTime value) =>
      setState(() => _focus = hrRosterDateOnly(value));

  void _shift({int months = 0, int weeks = 0, int days = 0}) {
    setState(() {
      if (months != 0) {
        _focus = DateTime(_focus.year, _focus.month + months, _focus.day);
      } else if (weeks != 0) {
        _focus = _focus.add(Duration(days: 7 * weeks));
      } else {
        _focus = _focus.add(Duration(days: days));
      }
    });
  }

  List<HrRosterDayPreview> _daysInRange(DateTime start, DateTime end) {
    return widget.days
        .where(
          (HrRosterDayPreview day) =>
              !day.date.isBefore(start) && !day.date.isAfter(end),
        )
        .toList(growable: false);
  }

  void _openDay(HrRosterDayPreview day) {
    setState(() {
      _focus = hrRosterDateOnly(day.date);
      _mode = HrRosterPreviewMode.day;
    });
    widget.onShowDetails(
      HrRosterPeriodDetails(
        scope: HrRosterPeriodScope.day,
        days: <HrRosterDayPreview>[day],
        focus: day.date,
      ),
    );
  }

  void _openSummary() {
    final HrRosterPeriodScope scope = switch (_mode) {
      HrRosterPreviewMode.month => HrRosterPeriodScope.month,
      HrRosterPreviewMode.week => HrRosterPeriodScope.week,
      HrRosterPreviewMode.day => HrRosterPeriodScope.day,
    };
    final DateTime start;
    final DateTime end;
    switch (scope) {
      case HrRosterPeriodScope.day:
        start = _focus;
        end = _focus;
      case HrRosterPeriodScope.week:
        start = hrRosterWeekStart(_focus);
        end = start.add(const Duration(days: 6));
      case HrRosterPeriodScope.month:
        start = DateTime(_focus.year, _focus.month, 1);
        end = DateTime(_focus.year, _focus.month + 1, 0);
    }
    widget.onShowDetails(
      HrRosterPeriodDetails(
        scope: scope,
        days: _daysInRange(start, end),
        focus: _focus,
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focus,
      firstDate: DateTime(_periodStart.year - 1),
      lastDate: DateTime(_periodEnd.year + 1, 12, 31),
      helpText: context.l10n.hrRosterPreviewPickPeriodAction,
    );
    if (picked != null && mounted) {
      _setFocus(picked);
    }
  }

  Future<void> _maximize() async {
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialog(
          title: Text(dialogContext.l10n.hrRosterPreviewSectionTitle),
          icon: const Icon(Icons.calendar_month_outlined),
          maxWidth: 1200,
          scrollable: false,
          content: SizedBox(
            height: MediaQuery.sizeOf(dialogContext).height * 0.72,
            child: HrRosterCalendarPreview(
              days: widget.days,
              expanded: true,
              onShowDetails: (HrRosterPeriodDetails details) {
                Navigator.of(dialogContext).maybePop();
                widget.onShowDetails(details);
              },
            ),
          ),
          actions: <Widget>[
            AppButton.secondary(
              label: dialogContext.l10n.commonCancelActionLabel,
              onPressed: () => Navigator.of(dialogContext).maybePop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final MaterialLocalizations materials = MaterialLocalizations.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth < 640;
        final bool showSideMini = !narrow && _showMini;
        final double boardHeight = widget.expanded
            ? (narrow ? 420.0 : 520.0)
            : (narrow ? 250.0 : 290.0);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CalendarChrome(
                  narrow: narrow,
                  mode: _mode,
                  title: switch (_mode) {
                    HrRosterPreviewMode.month =>
                      materials.formatMonthYear(_focus),
                    HrRosterPreviewMode.week =>
                      hrRosterWeekRangeLabel(materials, _focus),
                    HrRosterPreviewMode.day => materials.formatFullDate(_focus),
                  },
                  onModeChanged: (HrRosterPreviewMode mode) =>
                      setState(() => _mode = mode),
                  onToday: () => _setFocus(_periodStart),
                  onPrevious: () {
                    switch (_mode) {
                      case HrRosterPreviewMode.month:
                        _shift(months: -1);
                      case HrRosterPreviewMode.week:
                        _shift(weeks: -1);
                      case HrRosterPreviewMode.day:
                        _shift(days: -1);
                    }
                  },
                  onNext: () {
                    switch (_mode) {
                      case HrRosterPreviewMode.month:
                        _shift(months: 1);
                      case HrRosterPreviewMode.week:
                        _shift(weeks: 1);
                      case HrRosterPreviewMode.day:
                        _shift(days: 1);
                    }
                  },
                  onPickPeriod: _pickDate,
                  onToggleMini: narrow
                      ? null
                      : () => setState(() => _showMini = !_showMini),
                  miniVisible: _showMini,
                  onMaximize: widget.expanded ? null : _maximize,
                  onSummary: _openSummary,
                ),
                SizedBox(height: theme.spacing.sm),
                SizedBox(
                  height: boardHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (showSideMini) ...<Widget>[
                        SizedBox(
                          width: 168,
                          child: _MiniMonthPicker(
                            focus: _focus,
                            periodStart: _periodStart,
                            periodEnd: _periodEnd,
                            byKey: _byKey,
                            onSelect: _setFocus,
                          ),
                        ),
                        VerticalDivider(
                          width: theme.spacing.md,
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ],
                      Expanded(
                        child: switch (_mode) {
                          HrRosterPreviewMode.month => _MonthGrid(
                            focus: _focus,
                            byKey: _byKey,
                            periodStart: _periodStart,
                            periodEnd: _periodEnd,
                            onDayTap: _openDay,
                            onSelectOutside: _setFocus,
                          ),
                          HrRosterPreviewMode.week => _TimeGrid(
                            dates: <DateTime>[
                              for (int i = 0; i < 7; i++)
                                hrRosterWeekStart(
                                  _focus,
                                ).add(Duration(days: i)),
                            ],
                            byKey: _byKey,
                            periodStart: _periodStart,
                            periodEnd: _periodEnd,
                            gridStartMinutes: _gridStartMinutes,
                            gridEndMinutes: _gridEndMinutes,
                            focus: _focus,
                            onDayHeaderTap: (DateTime date) {
                              final HrRosterDayPreview? day =
                                  _byKey[hrRosterDateKey(date)];
                              if (day != null) {
                                _openDay(day);
                              } else {
                                _setFocus(date);
                              }
                            },
                          ),
                          HrRosterPreviewMode.day => _TimeGrid(
                            dates: <DateTime>[_focus],
                            byKey: _byKey,
                            periodStart: _periodStart,
                            periodEnd: _periodEnd,
                            gridStartMinutes: _gridStartMinutes,
                            gridEndMinutes: _gridEndMinutes,
                            focus: _focus,
                            onDayHeaderTap: (_) {},
                          ),
                        },
                      ),
                    ],
                  ),
                ),
                if (narrow) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                      label: Text(l10n.hrRosterPreviewPickPeriodAction),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: theme.spacing.xs),
                _CompactLegend(l10n: l10n),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalendarChrome extends StatelessWidget {
  const _CalendarChrome({
    required this.narrow,
    required this.mode,
    required this.title,
    required this.onModeChanged,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
    required this.onPickPeriod,
    required this.onToggleMini,
    required this.miniVisible,
    required this.onMaximize,
    required this.onSummary,
  });

  final bool narrow;
  final HrRosterPreviewMode mode;
  final String title;
  final ValueChanged<HrRosterPreviewMode> onModeChanged;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickPeriod;
  final VoidCallback? onToggleMini;
  final bool miniVisible;
  final VoidCallback? onMaximize;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    final Widget nav = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton(
          onPressed: onToday,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: Text(l10n.hrRosterPreviewTodayAction),
        ),
        IconButton(
          tooltip: l10n.hrRosterPreviewPreviousAction,
          visualDensity: VisualDensity.compact,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: l10n.hrRosterPreviewNextAction,
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    final Widget titleText = InkWell(
      onTap: onPickPeriod,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );

    final Widget viewSwitcher = PopupMenuButton<HrRosterPreviewMode>(
      initialValue: mode,
      tooltip: l10n.hrRosterPreviewViewMenuLabel,
      onSelected: onModeChanged,
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<HrRosterPreviewMode>>[
            PopupMenuItem<HrRosterPreviewMode>(
              value: HrRosterPreviewMode.day,
              child: Text(l10n.hrRosterPreviewDayView),
            ),
            PopupMenuItem<HrRosterPreviewMode>(
              value: HrRosterPreviewMode.week,
              child: Text(l10n.hrRosterPreviewWeekView),
            ),
            PopupMenuItem<HrRosterPreviewMode>(
              value: HrRosterPreviewMode.month,
              child: Text(l10n.hrRosterPreviewMonthView),
            ),
          ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              switch (mode) {
                HrRosterPreviewMode.month => l10n.hrRosterPreviewMonthView,
                HrRosterPreviewMode.week => l10n.hrRosterPreviewWeekView,
                HrRosterPreviewMode.day => l10n.hrRosterPreviewDayView,
              },
              style: theme.textTheme.labelLarge,
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );

    final List<Widget> trailing = <Widget>[
      viewSwitcher,
      IconButton(
        tooltip: l10n.hrRosterPreviewPickPeriodAction,
        visualDensity: VisualDensity.compact,
        onPressed: onPickPeriod,
        icon: const Icon(Icons.edit_calendar_outlined, size: 20),
      ),
      IconButton(
        tooltip: l10n.hrRosterPreviewSummaryAction,
        visualDensity: VisualDensity.compact,
        onPressed: onSummary,
        icon: const Icon(Icons.info_outline, size: 20),
      ),
      if (onToggleMini != null)
        IconButton(
          tooltip: miniVisible
              ? l10n.hrRosterPreviewHideMiniAction
              : l10n.hrRosterPreviewShowMiniAction,
          visualDensity: VisualDensity.compact,
          onPressed: onToggleMini,
          icon: Icon(
            miniVisible ? Icons.view_sidebar_outlined : Icons.view_sidebar,
            size: 20,
          ),
        ),
      if (onMaximize != null)
        IconButton(
          tooltip: l10n.hrRosterPreviewMaximizeAction,
          visualDensity: VisualDensity.compact,
          onPressed: onMaximize,
          icon: const Icon(Icons.open_in_full, size: 18),
        ),
    ];

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: titleText),
              viewSwitcher,
              if (onMaximize != null)
                IconButton(
                  tooltip: l10n.hrRosterPreviewMaximizeAction,
                  visualDensity: VisualDensity.compact,
                  onPressed: onMaximize,
                  icon: const Icon(Icons.open_in_full, size: 18),
                ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Row(
            children: <Widget>[
              nav,
              const Spacer(),
              IconButton(
                tooltip: l10n.hrRosterPreviewPickPeriodAction,
                visualDensity: VisualDensity.compact,
                onPressed: onPickPeriod,
                icon: const Icon(Icons.edit_calendar_outlined, size: 20),
              ),
              IconButton(
                tooltip: l10n.hrRosterPreviewSummaryAction,
                visualDensity: VisualDensity.compact,
                onPressed: onSummary,
                icon: const Icon(Icons.info_outline, size: 20),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        nav,
        SizedBox(width: theme.spacing.sm),
        Expanded(child: titleText),
        ...trailing,
      ],
    );
  }
}

class _MiniMonthPicker extends StatelessWidget {
  const _MiniMonthPicker({
    required this.focus,
    required this.periodStart,
    required this.periodEnd,
    required this.byKey,
    required this.onSelect,
  });

  final DateTime focus;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, HrRosterDayPreview> byKey;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final MaterialLocalizations materials = MaterialLocalizations.of(context);
    final DateTime first = DateTime(focus.year, focus.month, 1);
    final DateTime last = DateTime(focus.year, focus.month + 1, 0);
    final int leading = (first.weekday - DateTime.monday) % 7;
    final int cells =
        leading + last.day + ((DateTime.sunday - last.weekday) % 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          materials.formatMonthYear(focus),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Row(
          children: <Widget>[
            for (final int weekday in const <int>[1, 2, 3, 4, 5, 6, 7])
              Expanded(
                child: Text(
                  hrDayLabel(l10n, weekday == 7 ? 0 : weekday).characters.first,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (BuildContext context, int index) {
              if (index < leading || index >= leading + last.day) {
                return const SizedBox.shrink();
              }
              final DateTime date = DateTime(
                focus.year,
                focus.month,
                index - leading + 1,
              );
              final bool selected =
                  hrRosterDateKey(date) == hrRosterDateKey(focus);
              final bool inPeriod =
                  !date.isBefore(periodStart) && !date.isAfter(periodEnd);
              final HrRosterDayPreview? day = byKey[hrRosterDateKey(date)];
              return InkWell(
                onTap: () => onSelect(date),
                customBorder: const CircleBorder(),
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? theme.colorScheme.primary
                          : day?.isHoliday == true
                          ? theme.colorScheme.tertiary.withValues(alpha: 0.25)
                          : null,
                    ),
                    child: Text(
                      '${date.day}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : inPeriod
                            ? null
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.45,
                              ),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focus,
    required this.byKey,
    required this.periodStart,
    required this.periodEnd,
    required this.onDayTap,
    required this.onSelectOutside,
  });

  final DateTime focus;
  final Map<String, HrRosterDayPreview> byKey;
  final DateTime periodStart;
  final DateTime periodEnd;
  final ValueChanged<HrRosterDayPreview> onDayTap;
  final ValueChanged<DateTime> onSelectOutside;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final DateTime first = DateTime(focus.year, focus.month, 1);
    final DateTime gridStart = first.subtract(
      Duration(days: (first.weekday - DateTime.monday) % 7),
    );
    final DateTime last = DateTime(focus.year, focus.month + 1, 0);
    final DateTime gridEnd = last.add(
      Duration(days: (DateTime.sunday - last.weekday) % 7),
    );
    final int cellCount = gridEnd.difference(gridStart).inDays + 1;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final int weekday in const <int>[1, 2, 3, 4, 5, 6, 7])
              Expanded(
                child: Text(
                  hrDayLabel(l10n, weekday == 7 ? 0 : weekday)
                      .substring(0, 3)
                      .toUpperCase(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int rows = (cellCount / 7).ceil();
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cellCount,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: constraints.maxHeight / rows,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final DateTime date = gridStart.add(Duration(days: index));
                  final bool inMonth = date.month == focus.month;
                  final bool inPeriod =
                      !date.isBefore(periodStart) && !date.isAfter(periodEnd);
                  final HrRosterDayPreview? day = byKey[hrRosterDateKey(date)];
                  final bool selected =
                      hrRosterDateKey(date) == hrRosterDateKey(focus);

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (day != null) {
                          onDayTap(day);
                        } else {
                          onSelectOutside(date);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : null,
                                ),
                                child: Text(
                                  '${date.day}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: selected
                                        ? theme.colorScheme.onPrimary
                                        : inMonth
                                        ? null
                                        : theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.4),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (day?.isHoliday == true)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  l10n.hrRosterPublicHolidayLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onTertiary,
                                    fontSize: 9,
                                  ),
                                ),
                              )
                            else if (day != null &&
                                inPeriod &&
                                day.isWorkingDay)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _BusyFreeBar(day: day),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.dates,
    required this.byKey,
    required this.periodStart,
    required this.periodEnd,
    required this.gridStartMinutes,
    required this.gridEndMinutes,
    required this.focus,
    required this.onDayHeaderTap,
  });

  final List<DateTime> dates;
  final Map<String, HrRosterDayPreview> byKey;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int gridStartMinutes;
  final int gridEndMinutes;
  final DateTime focus;
  final ValueChanged<DateTime> onDayHeaderTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final int span = (gridEndMinutes - gridStartMinutes).clamp(60, 24 * 60);
    final int hourCount = (span / 60).ceil().clamp(1, 24);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            const SizedBox(width: 44),
            for (final DateTime date in dates)
              Expanded(
                child: InkWell(
                  onTap: () => onDayHeaderTap(date),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      children: <Widget>[
                        Text(
                          hrDayLabel(
                            l10n,
                            date.weekday == DateTime.sunday ? 0 : date.weekday,
                          ).substring(0, 3).toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                hrRosterDateKey(date) == hrRosterDateKey(focus)
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          child: Text(
                            '${date.day}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color:
                                  hrRosterDateKey(date) ==
                                      hrRosterDateKey(focus)
                                  ? theme.colorScheme.onPrimary
                                  : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        Row(
          children: <Widget>[
            const SizedBox(width: 44),
            for (final DateTime date in dates)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Builder(
                    builder: (BuildContext context) {
                      final HrRosterDayPreview? day =
                          byKey[hrRosterDateKey(date)];
                      if (day?.isHoliday != true) {
                        return const SizedBox(height: 18);
                      }
                      return Container(
                        height: 18,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l10n.hrRosterPublicHolidayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiary,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 44,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (int i = 0; i <= hourCount; i++)
                      Text(
                        hrRosterFormatMinutes(
                          (gridStartMinutes + i * 60).clamp(
                            gridStartMinutes,
                            gridEndMinutes,
                          ),
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              for (final DateTime date in dates)
                Expanded(
                  child: _DayColumn(
                    day: byKey[hrRosterDateKey(date)],
                    inPeriod:
                        !date.isBefore(periodStart) && !date.isAfter(periodEnd),
                    gridStartMinutes: gridStartMinutes,
                    gridEndMinutes: gridEndMinutes,
                    hourCount: hourCount,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.inPeriod,
    required this.gridStartMinutes,
    required this.gridEndMinutes,
    required this.hourCount,
  });

  final HrRosterDayPreview? day;
  final bool inPeriod;
  final int gridStartMinutes;
  final int gridEndMinutes;
  final int hourCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int span = (gridEndMinutes - gridStartMinutes).clamp(1, 24 * 60);
    final HrRosterDayPreview? preview = day;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double height = constraints.maxHeight;
          return Stack(
            children: <Widget>[
              for (int i = 0; i <= hourCount; i++)
                Positioned(
                  top: (i / hourCount) * height,
                  left: 0,
                  right: 0,
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.35,
                    ),
                  ),
                ),
              if (preview != null && inPeriod && preview.isWorkingDay)
                Positioned.fill(
                  child: ColoredBox(
                    color: theme.colorScheme.tertiaryContainer.withValues(
                      alpha: 0.18,
                    ),
                  ),
                ),
              if (preview != null && inPeriod && !preview.isWorkingDay)
                Positioned.fill(
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
              if (preview != null)
                for (final HrRosterMinuteRange range in preview.busyRanges)
                  Positioned(
                    top:
                        ((range.startMinutes - gridStartMinutes) / span) *
                        height,
                    height:
                        ((range.endMinutes - range.startMinutes) / span) *
                        height,
                    left: 3,
                    right: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _BusyFreeBar extends StatelessWidget {
  const _BusyFreeBar({required this.day});

  final HrRosterDayPreview day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int span = (day.dayEndMinutes - day.dayStartMinutes).clamp(1, 24 * 60);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ColoredBox(color: theme.colorScheme.tertiaryContainer),
                ),
                for (final HrRosterMinuteRange range in day.busyRanges)
                  Positioned(
                    left:
                        ((range.startMinutes - day.dayStartMinutes) / span) *
                        constraints.maxWidth,
                    width:
                        ((range.endMinutes - range.startMinutes) / span) *
                        constraints.maxWidth,
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(color: theme.colorScheme.primary),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompactLegend extends StatelessWidget {
  const _CompactLegend({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Widget swatch(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(width: theme.spacing.xs),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      );
    }

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: 2,
      children: <Widget>[
        swatch(theme.colorScheme.primary, l10n.hrRosterAvailableLabel),
        swatch(
          theme.colorScheme.tertiaryContainer,
          l10n.hrRosterFreeHoursLabel,
        ),
        swatch(theme.colorScheme.tertiary, l10n.hrRosterPublicHolidayLabel),
        swatch(
          theme.colorScheme.surfaceContainerHighest,
          l10n.hrRosterDayOffLabel,
        ),
      ],
    );
  }
}

Future<void> showHrRosterPeriodDetailsDialog(
  BuildContext context, {
  required HrRosterPeriodDetails details,
}) {
  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final MaterialLocalizations materials = MaterialLocalizations.of(context);
  final List<HrRosterDayPreview> days = details.days;
  final String title = switch (details.scope) {
    HrRosterPeriodScope.day => l10n.hrRosterDayDetailsTitle,
    HrRosterPeriodScope.week => l10n.hrRosterWeekDetailsTitle,
    HrRosterPeriodScope.month => l10n.hrRosterMonthDetailsTitle,
  };
  final String heading = switch (details.scope) {
    HrRosterPeriodScope.day when days.isNotEmpty =>
      '${hrDayLabel(l10n, days.first.date.weekday == DateTime.sunday ? 0 : days.first.date.weekday)} · ${days.first.label}',
    HrRosterPeriodScope.week => hrRosterWeekRangeLabel(materials, details.focus),
    HrRosterPeriodScope.month => materials.formatMonthYear(details.focus),
    _ => materials.formatFullDate(details.focus),
  };

  final int working = days
      .where((HrRosterDayPreview d) => d.isWorkingDay)
      .length;
  final int busy = days
      .where((HrRosterDayPreview d) => d.shifts.isNotEmpty)
      .length;
  final int holidays = days.where((HrRosterDayPreview d) => d.isHoliday).length;

  return showAppDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AppDialog(
        title: Text(title),
        icon: Icon(switch (details.scope) {
          HrRosterPeriodScope.day => Icons.event_note_outlined,
          HrRosterPeriodScope.week => Icons.view_week_outlined,
          HrRosterPeriodScope.month => Icons.calendar_month_outlined,
        }),
        content: days.isEmpty
            ? Text(l10n.hrRosterPeriodNoDaysLabel)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(heading, style: theme.textTheme.titleMedium),
                  SizedBox(height: theme.spacing.sm),
                  if (details.scope == HrRosterPeriodScope.day) ...<Widget>[
                    Text(days.first.statusLabel(l10n)),
                    if (days.first.isWorkingDay) ...<Widget>[
                      SizedBox(height: theme.spacing.sm),
                      Text(
                        '${l10n.hrRosterDayWorkingHoursLabel}: ${hrRosterFormatMinutes(days.first.dayStartMinutes)}–${hrRosterFormatMinutes(days.first.dayEndMinutes)}',
                      ),
                      Text(l10n.hrRosterDayBusyHoursLabel),
                      if (days.first.busyRanges.isEmpty)
                        Text(l10n.hrRosterDayNoShiftsLabel)
                      else
                        for (final HrRosterMinuteRange range
                            in days.first.busyRanges)
                          Text('• ${range.label}'),
                      Text(l10n.hrRosterDayFreeHoursLabel),
                      for (final HrRosterMinuteRange range
                          in days.first.freeRanges)
                        Text('• ${range.label}'),
                    ],
                    SizedBox(height: theme.spacing.sm),
                    Text(l10n.hrRosterDayShiftsLabel),
                    if (days.first.shifts.isEmpty)
                      Text(l10n.hrRosterDayNoShiftsLabel)
                    else
                      for (final HrRosterShiftWindow shift
                          in days.first.shifts)
                        Text(shift.summary),
                  ] else ...<Widget>[
                    Text('${l10n.hrRosterPeriodWorkingDaysLabel}: $working'),
                    Text('${l10n.hrRosterPeriodBusyDaysLabel}: $busy'),
                    Text('${l10n.hrRosterPeriodHolidayDaysLabel}: $holidays'),
                    SizedBox(height: theme.spacing.sm),
                    for (final HrRosterDayPreview day in days)
                      Padding(
                        padding: EdgeInsets.only(bottom: theme.spacing.xs),
                        child: Row(
                          children: <Widget>[
                            SizedBox(width: 88, child: Text(day.label)),
                            Expanded(child: Text(day.statusLabel(l10n))),
                            if (day.shifts.isNotEmpty)
                              Text('${day.shifts.length}'),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
        actions: <Widget>[
          AppButton.secondary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      );
    },
  );
}

String hrRosterDateKey(DateTime value) {
  final DateTime local = value.isUtc ? value.toLocal() : value;
  final String y = local.year.toString().padLeft(4, '0');
  final String m = local.month.toString().padLeft(2, '0');
  final String d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime hrRosterDateOnly(DateTime value) {
  final DateTime local = value.isUtc ? value.toLocal() : value;
  return DateTime(local.year, local.month, local.day);
}

DateTime hrRosterWeekStart(DateTime value) {
  final DateTime day = hrRosterDateOnly(value);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String hrRosterWeekRangeLabel(
  MaterialLocalizations materials,
  DateTime focus,
) {
  final DateTime start = hrRosterWeekStart(focus);
  final DateTime end = start.add(const Duration(days: 6));
  return '${materials.formatShortDate(start)} – ${materials.formatShortDate(end)}';
}

String hrRosterFormatMinutes(int minutes) {
  final int normalized = minutes % (24 * 60);
  final int hour = normalized ~/ 60;
  final int minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String hrRosterFormatHm(DateTime value) {
  final DateTime local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

List<HrRosterMinuteRange> hrRosterMergeRanges(List<HrRosterMinuteRange> input) {
  if (input.isEmpty) {
    return const <HrRosterMinuteRange>[];
  }
  final List<HrRosterMinuteRange> sorted = List<HrRosterMinuteRange>.from(input)
    ..sort(
      (HrRosterMinuteRange a, HrRosterMinuteRange b) =>
          a.startMinutes.compareTo(b.startMinutes),
    );
  final List<HrRosterMinuteRange> merged = <HrRosterMinuteRange>[sorted.first];
  for (int i = 1; i < sorted.length; i++) {
    final HrRosterMinuteRange current = sorted[i];
    final HrRosterMinuteRange last = merged.last;
    if (current.startMinutes <= last.endMinutes) {
      merged[merged.length - 1] = HrRosterMinuteRange(
        startMinutes: last.startMinutes,
        endMinutes: current.endMinutes > last.endMinutes
            ? current.endMinutes
            : last.endMinutes,
      );
    } else {
      merged.add(current);
    }
  }
  return merged;
}
