import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Shared roster-preview status colors (busy / free / holiday / off).
@immutable
final class HrRosterPreviewColors {
  const HrRosterPreviewColors(this.scheme);

  final ColorScheme scheme;

  Color get busy => scheme.primary;
  Color get free => scheme.primaryContainer;
  Color get holiday => scheme.tertiary;
  Color get onHoliday => scheme.onTertiary;
  Color get off => scheme.surfaceContainerHighest;
  Color get workingFill => scheme.primaryContainer.withValues(alpha: 0.42);
  Color get offFill => scheme.surfaceContainerHighest.withValues(alpha: 0.85);
  Color get busyBlock => scheme.primary.withValues(alpha: 0.92);
}

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

  /// Busy blocks across the full clock day (00:00–24:00), including overnight splits.
  List<HrRosterMinuteRange> get absoluteBusyRanges {
    final List<HrRosterMinuteRange> ranges = <HrRosterMinuteRange>[];
    const int dayMinutes = 24 * 60;
    for (final HrRosterShiftWindow shift in shifts) {
      final int start = shift.startMinutes;
      int end = shift.endMinutes;
      if (end <= start) {
        end += dayMinutes;
      }
      if (start < dayMinutes && end > dayMinutes) {
        ranges.add(
          HrRosterMinuteRange(startMinutes: start, endMinutes: dayMinutes),
        );
        ranges.add(
          HrRosterMinuteRange(startMinutes: 0, endMinutes: end - dayMinutes),
        );
      } else if (start >= dayMinutes) {
        ranges.add(
          HrRosterMinuteRange(
            startMinutes: start - dayMinutes,
            endMinutes: end - dayMinutes,
          ),
        );
      } else {
        ranges.add(
          HrRosterMinuteRange(
            startMinutes: start.clamp(0, dayMinutes),
            endMinutes: end.clamp(0, dayMinutes),
          ),
        );
      }
    }
    return hrRosterMergeRanges(
      ranges.where((HrRosterMinuteRange r) => r.endMinutes > r.startMinutes).toList(),
    );
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
  DateTimeRange? _customRange;

  static const int _maxCustomWeekDays = 14;

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

  DateTime get _viewStart {
    final DateTimeRange? range = _customRange;
    if (range != null) {
      return hrRosterDateOnly(range.start);
    }
    return switch (_mode) {
      HrRosterPreviewMode.day => _focus,
      HrRosterPreviewMode.week => hrRosterWeekStart(_focus),
      HrRosterPreviewMode.month => DateTime(_focus.year, _focus.month, 1),
    };
  }

  DateTime get _viewEnd {
    final DateTimeRange? range = _customRange;
    if (range != null) {
      return hrRosterDateOnly(range.end);
    }
    return switch (_mode) {
      HrRosterPreviewMode.day => _focus,
      HrRosterPreviewMode.week =>
        hrRosterWeekStart(_focus).add(const Duration(days: 6)),
      HrRosterPreviewMode.month => DateTime(_focus.year, _focus.month + 1, 0),
    };
  }

  List<DateTime> get _weekDates {
    final DateTimeRange? range = _customRange;
    if (range != null) {
      final DateTime start = hrRosterDateOnly(range.start);
      final DateTime end = hrRosterDateOnly(range.end);
      final int dayCount = end.difference(start).inDays + 1;
      if (dayCount >= 1 && dayCount <= _maxCustomWeekDays) {
        return <DateTime>[
          for (int i = 0; i < dayCount; i++) start.add(Duration(days: i)),
        ];
      }
    }
    return <DateTime>[
      for (int i = 0; i < 7; i++)
        hrRosterWeekStart(_focus).add(Duration(days: i)),
    ];
  }

  void _setFocus(DateTime value) {
    setState(() {
      _focus = hrRosterDateOnly(value);
      _customRange = null;
    });
  }

  void _goToday() {
    setState(() {
      _focus = hrRosterDateOnly(DateTime.now());
      _customRange = null;
    });
  }

  void _applyCustomRange(DateTimeRange range) {
    final DateTime start = hrRosterDateOnly(range.start);
    final DateTime end = hrRosterDateOnly(range.end);
    final int dayCount = end.difference(start).inDays + 1;
    setState(() {
      _customRange = DateTimeRange(start: start, end: end);
      _focus = start;
      if (dayCount <= 1) {
        _mode = HrRosterPreviewMode.day;
      } else if (dayCount <= _maxCustomWeekDays) {
        _mode = HrRosterPreviewMode.week;
      } else {
        _mode = HrRosterPreviewMode.month;
      }
    });
  }

  void _shift({int months = 0, int weeks = 0, int days = 0}) {
    setState(() {
      final DateTimeRange? range = _customRange;
      if (range != null) {
        final int spanDays =
            hrRosterDateOnly(range.end).difference(hrRosterDateOnly(range.start)).inDays;
        final int stepDays = months != 0
            ? months * 30
            : (weeks != 0 ? weeks * 7 : days);
        final DateTime nextStart =
            hrRosterDateOnly(range.start).add(Duration(days: stepDays));
        _customRange = DateTimeRange(
          start: nextStart,
          end: nextStart.add(Duration(days: spanDays)),
        );
        _focus = nextStart;
        return;
      }
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
      _customRange = null;
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
    final DateTime start = _viewStart;
    final DateTime end = _viewEnd;
    final HrRosterPeriodScope scope = switch (_mode) {
      HrRosterPreviewMode.month => HrRosterPeriodScope.month,
      HrRosterPreviewMode.week => HrRosterPeriodScope.week,
      HrRosterPreviewMode.day => HrRosterPeriodScope.day,
    };
    widget.onShowDetails(
      HrRosterPeriodDetails(
        scope: scope,
        days: _daysInRange(start, end),
        focus: _focus,
      ),
    );
  }

  Future<void> _pickRange() async {
    final DateTime firstDate = DateTime(_periodStart.year - 1);
    final DateTime lastDate = DateTime(_periodEnd.year + 1, 12, 31);
    final DateTimeRange initial =
        _customRange ??
        DateTimeRange(start: _viewStart, end: _viewEnd);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: DateTimeRange(
        start: initial.start.isBefore(firstDate) ? firstDate : initial.start,
        end: initial.end.isAfter(lastDate) ? lastDate : initial.end,
      ),
      helpText: context.l10n.hrRosterPreviewPickRangeAction,
      saveText: context.l10n.commonSaveActionLabel,
    );
    if (picked != null && mounted) {
      _applyCustomRange(picked);
    }
  }

  Future<void> _maximize() async {
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Size viewport = MediaQuery.sizeOf(dialogContext);
        final double contentHeight = (viewport.height * 0.86).clamp(420.0, 900.0);
        return AppDialog(
          title: Text(dialogContext.l10n.hrRosterPreviewSectionTitle),
          icon: const Icon(Icons.calendar_month_outlined),
          maxWidth: 1200,
          scrollable: false,
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            height: contentHeight,
            width: double.infinity,
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

  String _chromeTitle(MaterialLocalizations materials) {
    if (_customRange != null) {
      return '${materials.formatShortDate(_viewStart)} – ${materials.formatShortDate(_viewEnd)}';
    }
    return switch (_mode) {
      HrRosterPreviewMode.month => materials.formatMonthYear(_focus),
      HrRosterPreviewMode.week => hrRosterWeekRangeLabel(materials, _focus),
      HrRosterPreviewMode.day => materials.formatFullDate(_focus),
    };
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
        final bool heightBounded = constraints.hasBoundedHeight &&
            constraints.maxHeight.isFinite &&
            constraints.maxHeight < double.infinity;
        final double fallbackBoardHeight = switch (_mode) {
          HrRosterPreviewMode.month =>
            widget.expanded ? (narrow ? 360.0 : 440.0) : (narrow ? 240.0 : 280.0),
          HrRosterPreviewMode.week || HrRosterPreviewMode.day =>
            widget.expanded ? (narrow ? 520.0 : 600.0) : (narrow ? 360.0 : 420.0),
        };

        final bool showActionLabels =
            AppBreakpoints.fromWidth(constraints.maxWidth).showsToolbarActionLabels;

        final Widget board = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showSideMini) ...<Widget>[
              SizedBox(
                width: 168,
                child: _MiniMonthPicker(
                  focus: _focus,
                  periodStart: _periodStart,
                  periodEnd: _periodEnd,
                  highlightStart: _viewStart,
                  highlightEnd: _viewEnd,
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
                  highlightStart: _viewStart,
                  highlightEnd: _viewEnd,
                  onDayTap: _openDay,
                  onSelectOutside: _setFocus,
                ),
                HrRosterPreviewMode.week => _TimeGrid(
                  dates: _weekDates,
                  byKey: _byKey,
                  periodStart: _periodStart,
                  periodEnd: _periodEnd,
                  gridStartMinutes: 0,
                  gridEndMinutes: 24 * 60,
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
                HrRosterPreviewMode.day => _DayDualColumnGrid(
                  day: _byKey[hrRosterDateKey(_focus)],
                  inPeriod: !_focus.isBefore(_periodStart) &&
                      !_focus.isAfter(_periodEnd),
                ),
              },
            ),
          ],
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: heightBounded ? MainAxisSize.max : MainAxisSize.min,
            children: <Widget>[
              _CalendarChrome(
                narrow: narrow,
                showActionLabels: showActionLabels,
                mode: _mode,
                title: _chromeTitle(materials),
                onModeChanged: (HrRosterPreviewMode mode) =>
                    setState(() => _mode = mode),
                onToday: _goToday,
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
                onPickPeriod: _pickRange,
                onToggleMini: narrow
                    ? null
                    : () => setState(() => _showMini = !_showMini),
                miniVisible: _showMini,
                onMaximize: widget.expanded ? null : _maximize,
                onSummary: _openSummary,
              ),
              SizedBox(height: theme.spacing.sm),
              if (heightBounded)
                Expanded(child: board)
              else
                SizedBox(height: fallbackBoardHeight, child: board),
              if (narrow) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_outlined, size: 16),
                    label: Text(l10n.hrRosterPreviewPickRangeAction),
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
        );
      },
    );
  }
}

class _CalendarChrome extends StatelessWidget {
  const _CalendarChrome({
    required this.narrow,
    required this.showActionLabels,
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
  final bool showActionLabels;
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

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    if (showActionLabels && onPressed != null) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    }
    return IconButton(
      tooltip: label,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }

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
      _actionButton(
        icon: Icons.date_range_outlined,
        label: l10n.hrRosterPreviewPickRangeAction,
        onPressed: onPickPeriod,
      ),
      _actionButton(
        icon: Icons.info_outline,
        label: l10n.hrRosterPreviewSummaryAction,
        onPressed: onSummary,
      ),
      if (onToggleMini != null)
        _actionButton(
          icon: miniVisible
              ? Icons.view_sidebar_outlined
              : Icons.view_sidebar,
          label: miniVisible
              ? l10n.hrRosterPreviewHideMiniAction
              : l10n.hrRosterPreviewShowMiniAction,
          onPressed: onToggleMini,
        ),
      if (onMaximize != null)
        _actionButton(
          icon: Icons.open_in_full,
          label: l10n.hrRosterPreviewMaximizeAction,
          onPressed: onMaximize,
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
                _actionButton(
                  icon: Icons.open_in_full,
                  label: l10n.hrRosterPreviewMaximizeAction,
                  onPressed: onMaximize,
                ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Row(
            children: <Widget>[
              nav,
              const Spacer(),
              _actionButton(
                icon: Icons.date_range_outlined,
                label: l10n.hrRosterPreviewPickRangeAction,
                onPressed: onPickPeriod,
              ),
              _actionButton(
                icon: Icons.info_outline,
                label: l10n.hrRosterPreviewSummaryAction,
                onPressed: onSummary,
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
    required this.highlightStart,
    required this.highlightEnd,
    required this.byKey,
    required this.onSelect,
  });

  final DateTime focus;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime highlightStart;
  final DateTime highlightEnd;
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
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int rows = (cells / 7).ceil().clamp(1, 6);
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: constraints.maxHeight / rows,
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
                  final bool inHighlight = !date.isBefore(highlightStart) &&
                      !date.isAfter(highlightEnd);
                  final bool inPeriod =
                      !date.isBefore(periodStart) && !date.isAfter(periodEnd);
                  final HrRosterDayPreview? day = byKey[hrRosterDateKey(date)];
                  final HrRosterPreviewColors colors =
                      HrRosterPreviewColors(theme.colorScheme);
                  return InkWell(
                    onTap: () => onSelect(date),
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? colors.busy
                              : day?.isHoliday == true
                              ? colors.holiday
                              : inHighlight
                              ? colors.free
                              : null,
                        ),
                        child: Text(
                          '${date.day}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : day?.isHoliday == true
                                ? colors.onHoliday
                                : inPeriod
                                ? null
                                : theme.colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.45,
                                  ),
                            fontWeight: selected || inHighlight
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
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

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focus,
    required this.byKey,
    required this.periodStart,
    required this.periodEnd,
    required this.highlightStart,
    required this.highlightEnd,
    required this.onDayTap,
    required this.onSelectOutside,
  });

  final DateTime focus;
  final Map<String, HrRosterDayPreview> byKey;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime highlightStart;
  final DateTime highlightEnd;
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
                  final bool inHighlight = !date.isBefore(highlightStart) &&
                      !date.isAfter(highlightEnd);
                  final HrRosterDayPreview? day = byKey[hrRosterDateKey(date)];
                  final bool selected =
                      hrRosterDateKey(date) == hrRosterDateKey(focus);
                  final HrRosterPreviewColors colors =
                      HrRosterPreviewColors(theme.colorScheme);

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: inHighlight
                          ? colors.free.withValues(alpha: 0.35)
                          : null,
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
                      child: ClipRect(
                        child: Stack(
                          children: <Widget>[
                            Positioned(
                              top: 2,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected ? colors.busy : null,
                                  ),
                                  child: Text(
                                    '${date.day}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: selected
                                          ? theme.colorScheme.onPrimary
                                          : inMonth
                                          ? null
                                          : theme.colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.4),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (day?.isHoliday == true)
                              Positioned(
                                left: 3,
                                right: 3,
                                bottom: 3,
                                child: Container(
                                  height: 16,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.holiday,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    l10n.hrRosterPublicHolidayLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onHoliday,
                                      fontSize: 8,
                                      height: 1,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                            else if (day != null &&
                                inPeriod &&
                                !day.isWorkingDay)
                              Positioned(
                                left: 4,
                                right: 4,
                                bottom: 4,
                                height: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.off,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              )
                            else if (day != null &&
                                inPeriod &&
                                day.isWorkingDay)
                              Positioned(
                                left: 4,
                                right: 4,
                                bottom: 4,
                                height: 8,
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
            const SizedBox(width: 48),
            for (final DateTime date in dates)
              Expanded(
                child: InkWell(
                  onTap: () => onDayHeaderTap(date),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          hrDayLabel(
                            l10n,
                            date.weekday == DateTime.sunday ? 0 : date.weekday,
                          ).substring(0, 3).toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.3,
                            fontSize: 10,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 22,
                          height: 22,
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
                            style: theme.textTheme.labelMedium?.copyWith(
                              color:
                                  hrRosterDateKey(date) ==
                                      hrRosterDateKey(focus)
                                  ? theme.colorScheme.onPrimary
                                  : null,
                              fontWeight: FontWeight.w600,
                              height: 1,
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
            const SizedBox(width: 48),
            for (final DateTime date in dates)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Builder(
                    builder: (BuildContext context) {
                      final HrRosterDayPreview? day =
                          byKey[hrRosterDateKey(date)];
                      if (day?.isHoliday != true) {
                        return const SizedBox(height: 16);
                      }
                      return Container(
                        height: 16,
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
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double height = constraints.maxHeight;
              final double hourHeight = height / hourCount;
              // Keep every hour marked when space allows; thin views skip labels.
              final int labelStep = hourHeight >= 16
                  ? 1
                  : hourHeight >= 11
                  ? 2
                  : 3;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 48,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: <Widget>[
                        for (int i = 0; i <= hourCount; i++)
                          if (i % labelStep == 0)
                            Positioned(
                              top: (i / hourCount) * height -
                                  (i == hourCount ? 10 : 5),
                              left: 0,
                              right: 2,
                              child: Text(
                                hrRosterFormatMinutes(
                                  (gridStartMinutes + i * 60).clamp(
                                    gridStartMinutes,
                                    gridEndMinutes,
                                  ),
                                ),
                                textAlign: TextAlign.right,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: hourHeight >= 14 ? 11 : 9,
                                  height: 1,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  for (final DateTime date in dates)
                    Expanded(
                      child: _DayColumn(
                        day: byKey[hrRosterDateKey(date)],
                        inPeriod: !date.isBefore(periodStart) &&
                            !date.isAfter(periodEnd),
                        gridStartMinutes: gridStartMinutes,
                        gridEndMinutes: gridEndMinutes,
                        hourCount: hourCount,
                        useAbsoluteBusy: true,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayDualColumnGrid extends StatelessWidget {
  const _DayDualColumnGrid({
    required this.day,
    required this.inPeriod,
  });

  final HrRosterDayPreview? day;
  final bool inPeriod;

  static const int _daytimeStart = 6 * 60;
  static const int _daytimeEnd = 18 * 60;
  static const int _nightWindowStart = 18 * 60;
  static const int _nightSpan = 12 * 60;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final HrRosterDayPreview? preview = day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${l10n.hrRosterPreviewDaytimeLabel} · 06:00–18:00',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${l10n.hrRosterPreviewNighttimeLabel} · 18:00–06:00',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (preview?.isHoliday == true) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Container(
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.hrRosterPublicHolidayLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiary,
              ),
            ),
          ),
        ],
        SizedBox(height: theme.spacing.xs),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _HalfDayColumn(
                  labelHours: const <int>[
                    6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18,
                  ],
                  windowStartMinutes: _daytimeStart,
                  windowEndMinutes: _daytimeEnd,
                  wrapsMidnight: false,
                  day: preview,
                  inPeriod: inPeriod,
                ),
              ),
              VerticalDivider(
                width: theme.spacing.sm,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(
                child: _HalfDayColumn(
                  labelHours: const <int>[
                    18, 19, 20, 21, 22, 23, 0, 1, 2, 3, 4, 5, 6,
                  ],
                  windowStartMinutes: _nightWindowStart,
                  windowEndMinutes: _nightWindowStart + _nightSpan,
                  wrapsMidnight: true,
                  day: preview,
                  inPeriod: inPeriod,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HalfDayColumn extends StatelessWidget {
  const _HalfDayColumn({
    required this.labelHours,
    required this.windowStartMinutes,
    required this.windowEndMinutes,
    required this.wrapsMidnight,
    required this.day,
    required this.inPeriod,
  });

  final List<int> labelHours;
  final int windowStartMinutes;
  final int windowEndMinutes;
  final bool wrapsMidnight;
  final HrRosterDayPreview? day;
  final bool inPeriod;

  int get _span => windowEndMinutes - windowStartMinutes;

  List<HrRosterMinuteRange> get _displayBusy {
    final HrRosterDayPreview? preview = day;
    if (preview == null) {
      return const <HrRosterMinuteRange>[];
    }
    return hrRosterBusyInDisplayWindow(
      preview.absoluteBusyRanges,
      windowStartMinutes: windowStartMinutes,
      spanMinutes: _span,
      wrapsMidnight: wrapsMidnight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final HrRosterDayPreview? preview = day;
    final int labelCount = labelHours.length;
    final double labelFraction =
        labelCount <= 1 ? 1.0 : 1.0 / (labelCount - 1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: 40,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double height = constraints.maxHeight;
              final double hourHeight =
                  labelCount <= 1 ? height : height / (labelCount - 1);
              final int labelEvery = hourHeight >= 14
                  ? 1
                  : hourHeight >= 10
                  ? 2
                  : 3;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  for (int i = 0; i < labelCount; i++)
                    if (i % labelEvery == 0 || i == labelCount - 1)
                      Positioned(
                        top: (i * labelFraction * height) -
                            (i == labelCount - 1 ? 10 : 5),
                        left: 0,
                        right: 2,
                        child: Text(
                          hrRosterFormatMinutes(labelHours[i] * 60),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: hourHeight >= 14 ? 11 : 9,
                            height: 1,
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double height = constraints.maxHeight;
                final int span = _span;
                final HrRosterPreviewColors colors =
                    HrRosterPreviewColors(theme.colorScheme);
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: <Widget>[
                    for (int i = 0; i < labelCount; i++)
                      Positioned(
                        top: i * labelFraction * height,
                        left: 0,
                        right: 0,
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                    if (preview != null && inPeriod && preview.isWorkingDay)
                      Positioned.fill(
                        child: ColoredBox(color: colors.workingFill),
                      ),
                    if (preview != null && inPeriod && !preview.isWorkingDay)
                      Positioned.fill(
                        child: ColoredBox(color: colors.offFill),
                      ),
                    for (final HrRosterMinuteRange range in _displayBusy)
                      Positioned(
                        top: (range.startMinutes / span) * height,
                        height:
                            ((range.endMinutes - range.startMinutes) / span) *
                            height,
                        left: 3,
                        right: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.busyBlock,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
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
    this.useAbsoluteBusy = false,
  });

  final HrRosterDayPreview? day;
  final bool inPeriod;
  final int gridStartMinutes;
  final int gridEndMinutes;
  final int hourCount;
  final bool useAbsoluteBusy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int span = (gridEndMinutes - gridStartMinutes).clamp(1, 24 * 60);
    final HrRosterDayPreview? preview = day;
    final HrRosterPreviewColors colors =
        HrRosterPreviewColors(theme.colorScheme);
    final List<HrRosterMinuteRange> busy = preview == null
        ? const <HrRosterMinuteRange>[]
        : useAbsoluteBusy
        ? preview.absoluteBusyRanges
        : preview.busyRanges;

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
                  child: ColoredBox(color: colors.workingFill),
                ),
              if (preview != null && inPeriod && !preview.isWorkingDay)
                Positioned.fill(
                  child: ColoredBox(color: colors.offFill),
                ),
              for (final HrRosterMinuteRange range in busy)
                if (range.endMinutes > gridStartMinutes &&
                    range.startMinutes < gridEndMinutes)
                  Positioned(
                    top:
                        (((range.startMinutes < gridStartMinutes
                                    ? gridStartMinutes
                                    : range.startMinutes) -
                                gridStartMinutes) /
                            span) *
                        height,
                    height:
                        ((((range.endMinutes > gridEndMinutes
                                        ? gridEndMinutes
                                        : range.endMinutes) -
                                    (range.startMinutes < gridStartMinutes
                                        ? gridStartMinutes
                                        : range.startMinutes)) /
                                span) *
                            height)
                            .clamp(1.0, height),
                    left: 3,
                    right: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.busyBlock,
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
    final HrRosterPreviewColors colors =
        HrRosterPreviewColors(theme.colorScheme);
    final int span = (day.dayEndMinutes - day.dayStartMinutes).clamp(1, 24 * 60);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: <Widget>[
                Positioned.fill(child: ColoredBox(color: colors.free)),
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
                    child: ColoredBox(color: colors.busy),
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
    final HrRosterPreviewColors colors =
        HrRosterPreviewColors(theme.colorScheme);
    Widget swatch(Color color, String label, {Color? border}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: border ?? theme.colorScheme.outline.withValues(alpha: 0.55),
              ),
            ),
          ),
          SizedBox(width: theme.spacing.xs),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: theme.spacing.md,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        swatch(colors.busy, l10n.hrRosterAvailableLabel),
        swatch(colors.free, l10n.hrRosterFreeHoursLabel),
        swatch(colors.holiday, l10n.hrRosterPublicHolidayLabel),
        swatch(colors.off, l10n.hrRosterDayOffLabel),
      ],
    );
  }
}

Future<void> showHrRosterPeriodDetailsDialog(
  BuildContext context, {
  required HrRosterPeriodDetails details,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool showActionLabels =
      AppBreakpoints.of(context).showsToolbarActionLabels;

  return showAppDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AppActionLabelScope(
        showLabels: showActionLabels,
        forceIconOnly: !showActionLabels,
        child: AppDialog(
          title: Text(switch (details.scope) {
            HrRosterPeriodScope.day => l10n.hrRosterDayDetailsTitle,
            HrRosterPeriodScope.week => l10n.hrRosterWeekDetailsTitle,
            HrRosterPeriodScope.month => l10n.hrRosterMonthDetailsTitle,
          }),
          icon: Icon(switch (details.scope) {
            HrRosterPeriodScope.day => Icons.event_note_outlined,
            HrRosterPeriodScope.week => Icons.view_week_outlined,
            HrRosterPeriodScope.month => Icons.calendar_month_outlined,
          }),
          maxWidth: details.scope == HrRosterPeriodScope.day ? 520 : 720,
          scrollable: true,
          stackActionsWhenCompact: false,
          denseActions: true,
          content: details.days.isEmpty
              ? Text(l10n.hrRosterPeriodNoDaysLabel)
              : details.scope == HrRosterPeriodScope.day
              ? _RosterDayDetailsBody(day: details.days.first)
              : _RosterPeriodDetailsBody(details: details),
          actions: <Widget>[
            AppButton.close(
              label: l10n.commonCloseActionLabel,
              tooltip: l10n.commonCloseActionLabel,
              dense: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      );
    },
  );
}

class _RosterDayDetailsBody extends StatelessWidget {
  const _RosterDayDetailsBody({required this.day});

  final HrRosterDayPreview day;

  Color _toneColor(HrRosterPreviewColors colors) {
    return switch (day.tone) {
      HrRosterDayTone.holiday => colors.holiday,
      HrRosterDayTone.off => colors.off,
      HrRosterDayTone.busy => colors.busy,
      HrRosterDayTone.free => colors.free,
      HrRosterDayTone.mixed => colors.busy,
    };
  }

  Color _toneOnColor(ThemeData theme, HrRosterPreviewColors colors) {
    return switch (day.tone) {
      HrRosterDayTone.holiday => colors.onHoliday,
      HrRosterDayTone.off => theme.colorScheme.onSurface,
      HrRosterDayTone.busy => theme.colorScheme.onPrimary,
      HrRosterDayTone.free => theme.colorScheme.onPrimaryContainer,
      HrRosterDayTone.mixed => theme.colorScheme.onPrimary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final MaterialLocalizations materials = MaterialLocalizations.of(context);
    final HrRosterPreviewColors colors =
        HrRosterPreviewColors(theme.colorScheme);
    final String weekday = hrDayLabel(
      l10n,
      day.date.weekday == DateTime.sunday ? 0 : day.date.weekday,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    weekday,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs / 2),
                  Text(
                    materials.formatFullDate(day.date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.sm,
                vertical: theme.spacing.xs,
              ),
              decoration: BoxDecoration(
                color: _toneColor(colors),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                day.statusLabel(l10n),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _toneOnColor(theme, colors),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        if (day.isWorkingDay) ...<Widget>[
          _DetailsSection(
            title: l10n.hrRosterDayWorkingHoursLabel,
            child: Text(
              '${hrRosterFormatMinutes(day.dayStartMinutes)}–${hrRosterFormatMinutes(day.dayEndMinutes)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
          ),
          SizedBox(height: theme.spacing.md),
          _DetailsSection(
            title: l10n.hrRosterDayBusyHoursLabel,
            accent: colors.busy,
            child: day.busyRanges.isEmpty
                ? Text(
                    l10n.hrRosterDayNoShiftsLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.xs,
                    children: <Widget>[
                      for (final HrRosterMinuteRange range in day.busyRanges)
                        _RangeChip(
                          label: range.label,
                          color: colors.busy,
                          onColor: theme.colorScheme.onPrimary,
                        ),
                    ],
                  ),
          ),
          SizedBox(height: theme.spacing.md),
          _DetailsSection(
            title: l10n.hrRosterDayFreeHoursLabel,
            accent: colors.free,
            child: day.freeRanges.isEmpty
                ? Text(
                    '—',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.xs,
                    children: <Widget>[
                      for (final HrRosterMinuteRange range in day.freeRanges)
                        _RangeChip(
                          label: range.label,
                          color: colors.free,
                          onColor: theme.colorScheme.onPrimaryContainer,
                        ),
                    ],
                  ),
          ),
          SizedBox(height: theme.spacing.md),
        ],
        _DetailsSection(
          title: l10n.hrRosterDayShiftsLabel,
          child: day.shifts.isEmpty
              ? Text(
                  l10n.hrRosterDayNoShiftsLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (int i = 0; i < day.shifts.length; i++) ...<Widget>[
                      if (i > 0) SizedBox(height: theme.spacing.sm),
                      _ShiftTile(shift: day.shifts[i], colors: colors),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _RosterPeriodDetailsBody extends StatelessWidget {
  const _RosterPeriodDetailsBody({required this.details});

  final HrRosterPeriodDetails details;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final MaterialLocalizations materials = MaterialLocalizations.of(context);
    final HrRosterPreviewColors colors =
        HrRosterPreviewColors(theme.colorScheme);
    final List<HrRosterDayPreview> days = details.days;
    final int working =
        days.where((HrRosterDayPreview d) => d.isWorkingDay).length;
    final int busyDays =
        days.where((HrRosterDayPreview d) => d.shifts.isNotEmpty).length;
    final int holidays =
        days.where((HrRosterDayPreview d) => d.isHoliday).length;
    final String heading = switch (details.scope) {
      HrRosterPeriodScope.week =>
        hrRosterWeekRangeLabel(materials, details.focus),
      HrRosterPeriodScope.month => materials.formatMonthYear(details.focus),
      HrRosterPeriodScope.day => materials.formatFullDate(details.focus),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          heading,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        SizedBox(height: theme.spacing.md),
        Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            _StatChip(
              label: l10n.hrRosterPeriodWorkingDaysLabel,
              value: '$working',
              color: colors.free,
              onColor: theme.colorScheme.onPrimaryContainer,
            ),
            _StatChip(
              label: l10n.hrRosterPeriodBusyDaysLabel,
              value: '$busyDays',
              color: colors.busy,
              onColor: theme.colorScheme.onPrimary,
            ),
            _StatChip(
              label: l10n.hrRosterPeriodHolidayDaysLabel,
              value: '$holidays',
              color: colors.holiday,
              onColor: colors.onHoliday,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        for (final HrRosterDayPreview day in days) ...<Widget>[
          _PeriodDayRow(day: day, colors: colors),
          SizedBox(height: theme.spacing.sm),
        ],
      ],
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.child,
    this.accent,
  });

  final String title;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (accent != null) ...<Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  SizedBox(width: theme.spacing.xs),
                ],
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.color,
    required this.onColor,
  });

  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: onColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.onColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: onColor.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({required this.shift, required this.colors});

  final HrRosterShiftWindow shift;
  final HrRosterPreviewColors colors;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.workingFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.busy.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Row(
          children: <Widget>[
            Icon(Icons.schedule_outlined, size: 18, color: colors.busy),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                shift.summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodDayRow extends StatelessWidget {
  const _PeriodDayRow({required this.day, required this.colors});

  final HrRosterDayPreview day;
  final HrRosterPreviewColors colors;

  Color get _tone {
    return switch (day.tone) {
      HrRosterDayTone.holiday => colors.holiday,
      HrRosterDayTone.off => colors.off,
      HrRosterDayTone.busy => colors.busy,
      HrRosterDayTone.free => colors.free,
      HrRosterDayTone.mixed => colors.busy,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 32,
              decoration: BoxDecoration(
                color: _tone,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            SizedBox(
              width: 96,
              child: Text(
                day.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                day.statusLabel(l10n),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (day.shifts.isNotEmpty)
              Text(
                '${day.shifts.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.busy,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
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

/// Maps absolute clock ranges into a display window starting at
/// [windowStartMinutes] with length [spanMinutes].
///
/// When [wrapsMidnight] is true (night column), the window continues past
/// midnight (e.g. 18:00→06:00) and morning segments are placed after evening.
List<HrRosterMinuteRange> hrRosterBusyInDisplayWindow(
  List<HrRosterMinuteRange> absolute, {
  required int windowStartMinutes,
  required int spanMinutes,
  required bool wrapsMidnight,
}) {
  if (absolute.isEmpty || spanMinutes <= 0) {
    return const <HrRosterMinuteRange>[];
  }
  const int dayMinutes = 24 * 60;
  final List<HrRosterMinuteRange> mapped = <HrRosterMinuteRange>[];

  if (!wrapsMidnight) {
    final int windowEnd = windowStartMinutes + spanMinutes;
    for (final HrRosterMinuteRange range in absolute) {
      final int start = range.startMinutes < windowStartMinutes
          ? windowStartMinutes
          : range.startMinutes;
      final int end = range.endMinutes > windowEnd
          ? windowEnd
          : range.endMinutes;
      if (end > start) {
        mapped.add(
          HrRosterMinuteRange(
            startMinutes: start - windowStartMinutes,
            endMinutes: end - windowStartMinutes,
          ),
        );
      }
    }
  } else {
    final int wrapEnd = windowStartMinutes + spanMinutes - dayMinutes;
    final int eveningSpan = dayMinutes - windowStartMinutes;
    for (final HrRosterMinuteRange range in absolute) {
      final int eveStart = range.startMinutes < windowStartMinutes
          ? windowStartMinutes
          : range.startMinutes;
      final int eveEnd = range.endMinutes > dayMinutes
          ? dayMinutes
          : range.endMinutes;
      if (eveEnd > eveStart) {
        mapped.add(
          HrRosterMinuteRange(
            startMinutes: eveStart - windowStartMinutes,
            endMinutes: eveEnd - windowStartMinutes,
          ),
        );
      }
      if (wrapEnd > 0) {
        final int mornStart = range.startMinutes < 0 ? 0 : range.startMinutes;
        final int mornEnd = range.endMinutes > wrapEnd
            ? wrapEnd
            : range.endMinutes;
        if (mornEnd > mornStart && mornStart < wrapEnd) {
          mapped.add(
            HrRosterMinuteRange(
              startMinutes: eveningSpan + mornStart,
              endMinutes: eveningSpan + mornEnd,
            ),
          );
        }
      }
    }
  }

  return hrRosterMergeRanges(mapped);
}
