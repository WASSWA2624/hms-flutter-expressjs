import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

/// Visual week hour grid: days on the Y-axis, hours across the X-axis.
///
/// Tap or drag hour cells to paint working time. Use each day menu to copy
/// hours between days.
class HrRosterHourGrid extends StatefulWidget {
  const HrRosterHourGrid({
    required this.schedule,
    required this.onChanged,
    this.respectWeekends = false,
    this.showSectionChrome = true,
    super.key,
  });

  final HrWeeklyScheduleDraft schedule;
  final VoidCallback onChanged;

  /// When true, Saturday and Sunday cannot be painted and stay cleared.
  final bool respectWeekends;

  /// When false, omits the standalone title (parent supplies section chrome).
  final bool showSectionChrome;

  @override
  State<HrRosterHourGrid> createState() => _HrRosterHourGridState();
}

class _HrRosterHourGridState extends State<HrRosterHourGrid> {
  static const int _hourCount = 24;
  static const double _dayLabelWidth = 112;
  static const double _minCellWidth = 20;
  static const double _cellHeight = 30;

  /// When non-null, drag paint is adding (`true`) or clearing (`false`).
  bool? _paintSelect;
  int? _paintDay;

  bool _isWeekend(int day) => day == 0 || day == 6;

  bool _dayLocked(int day) => widget.respectWeekends && _isWeekend(day);

  Map<int, Set<int>> _hoursByDay() {
    return <int, Set<int>>{
      for (final int day in kHrWeekDayOrder)
        day: _hoursFromDay(widget.schedule.days[day]!),
    };
  }

  Set<int> _hoursFromDay(HrDayScheduleDraft day) {
    final Set<int> hours = <int>{};
    for (final HrScheduleSlotDraft slot in day.filledSlots) {
      final int startMinute = slot.start!.totalMinutes;
      final int endMinute = slot.end!.totalMinutes;
      for (int minute = startMinute; minute < endMinute; minute += 60) {
        hours.add(minute ~/ 60);
      }
    }
    return hours;
  }

  void _applyHours(int day, Set<int> hours) {
    if (_dayLocked(day)) {
      widget.schedule.days[day]!.replaceSlots(const <HrAvailabilitySlot>[]);
      widget.onChanged();
      return;
    }
    widget.schedule.days[day]!.replaceSlots(_slotsFromHours(hours));
    widget.onChanged();
  }

  List<HrAvailabilitySlot> _slotsFromHours(Set<int> hours) {
    if (hours.isEmpty) {
      return const <HrAvailabilitySlot>[];
    }
    final List<int> sorted = hours.toList()..sort();
    final List<HrAvailabilitySlot> slots = <HrAvailabilitySlot>[];
    int runStart = sorted.first;
    int prev = sorted.first;
    void flush(int endHourInclusive) {
      final int endExclusive = endHourInclusive + 1;
      slots.add(
        HrAvailabilitySlot(
          startTime: '${runStart.toString().padLeft(2, '0')}:00',
          endTime: endExclusive >= 24
              ? '23:59'
              : '${endExclusive.toString().padLeft(2, '0')}:00',
        ),
      );
    }

    for (int i = 1; i < sorted.length; i++) {
      final int hour = sorted[i];
      if (hour == prev + 1) {
        prev = hour;
        continue;
      }
      flush(prev);
      runStart = hour;
      prev = hour;
    }
    flush(prev);
    return slots;
  }

  void _toggleCell(int day, int hour) {
    if (_dayLocked(day)) {
      return;
    }
    final Set<int> hours = Set<int>.from(
      _hoursFromDay(widget.schedule.days[day]!),
    );
    final bool selecting = !hours.contains(hour);
    if (selecting) {
      hours.add(hour);
    } else {
      hours.remove(hour);
    }
    _paintSelect = selecting;
    _paintDay = day;
    _applyHours(day, hours);
  }

  void _paintCell(int day, int hour) {
    if (_paintSelect == null || _paintDay != day || _dayLocked(day)) {
      return;
    }
    final Set<int> hours = Set<int>.from(
      _hoursFromDay(widget.schedule.days[day]!),
    );
    final bool changed = _paintSelect! ? hours.add(hour) : hours.remove(hour);
    if (changed) {
      _applyHours(day, hours);
    }
  }

  void _copyToAll(int sourceDay) {
    if (_dayLocked(sourceDay)) {
      return;
    }
    final List<HrAvailabilitySlot> source = widget.schedule.days[sourceDay]!
        .toEntitySlots();
    for (final int day in kHrWeekDayOrder) {
      if (day == sourceDay || _dayLocked(day)) {
        continue;
      }
      widget.schedule.days[day]!.replaceSlots(source);
    }
    widget.onChanged();
  }

  void _copyToFollowing(int sourceDay) {
    if (_dayLocked(sourceDay)) {
      return;
    }
    final List<HrAvailabilitySlot> source = widget.schedule.days[sourceDay]!
        .toEntitySlots();
    final int startIndex = kHrWeekDayOrder.indexOf(sourceDay);
    if (startIndex < 0) {
      return;
    }
    for (int i = startIndex + 1; i < kHrWeekDayOrder.length; i++) {
      final int day = kHrWeekDayOrder[i];
      if (_dayLocked(day)) {
        continue;
      }
      widget.schedule.days[day]!.replaceSlots(source);
    }
    widget.onChanged();
  }

  void _copyFrom(int targetDay, int sourceDay) {
    if (_dayLocked(targetDay) || sourceDay == targetDay) {
      return;
    }
    final List<HrAvailabilitySlot> source = widget.schedule.days[sourceDay]!
        .toEntitySlots();
    widget.schedule.days[targetDay]!.replaceSlots(source);
    widget.onChanged();
  }

  void _clearDay(int day) {
    widget.schedule.days[day]!.replaceSlots(const <HrAvailabilitySlot>[]);
    widget.onChanged();
  }

  void _clearAll() {
    for (final int day in kHrWeekDayOrder) {
      widget.schedule.days[day]!.replaceSlots(const <HrAvailabilitySlot>[]);
    }
    widget.onChanged();
  }

  @override
  void didUpdateWidget(covariant HrRosterHourGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.respectWeekends && widget.respectWeekends) {
      for (final int day in kHrWeekDayOrder) {
        if (_isWeekend(day)) {
          widget.schedule.days[day]!.replaceSlots(const <HrAvailabilitySlot>[]);
        }
      }
      widget.onChanged();
    }
  }

  Widget _buildGrid({
    required ThemeData theme,
    required AppLocalizations l10n,
    required Map<int, Set<int>> hoursByDay,
    required double cellWidth,
  }) {
    final ColorScheme scheme = theme.colorScheme;
    final Color selectedFill = scheme.primary.withValues(alpha: 0.82);
    final Color selectedEdge = scheme.primary;
    final Color idleFill = scheme.surfaceContainerHighest.withValues(alpha: 0.42);
    final Color idleEdge = scheme.outlineVariant.withValues(alpha: 0.55);
    final Color lockedFill = scheme.surfaceContainerHighest.withValues(
      alpha: 0.22,
    );
    final Color lockedEdge = scheme.outlineVariant.withValues(alpha: 0.28);
    final bool hasAnyHours = hoursByDay.values.any(
      (Set<int> hours) => hours.isNotEmpty,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.85)),
        color: scheme.surface,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          theme.spacing.sm,
          theme.spacing.xs,
          theme.spacing.sm,
          theme.spacing.sm,
        ),
        child: Listener(
          onPointerUp: (_) {
            _paintSelect = null;
            _paintDay = null;
          },
          onPointerCancel: (_) {
            _paintSelect = null;
            _paintDay = null;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox(
                    width: _dayLabelWidth,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.symmetric(
                            horizontal: theme.spacing.xs,
                          ),
                        ),
                        onPressed: hasAnyHours ? _clearAll : null,
                        child: Text(l10n.hrRosterClearAllHoursAction),
                      ),
                    ),
                  ),
                  for (int hour = 0; hour < _hourCount; hour++)
                    SizedBox(
                      width: cellWidth,
                      child: Text(
                        hour.toString().padLeft(2, '0'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: theme.spacing.xs),
              for (final int day in kHrWeekDayOrder)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: _dayLabelWidth,
                        child: _DayLabel(
                          day: day,
                          label: hrDayLabel(l10n, day),
                          hasHours: hoursByDay[day]!.isNotEmpty,
                          locked: _dayLocked(day),
                          hoursByDay: hoursByDay,
                          dayLocked: _dayLocked,
                          dayLabel: (int value) => hrDayLabel(l10n, value),
                          onCopyToAll: () => _copyToAll(day),
                          onCopyToFollowing: () => _copyToFollowing(day),
                          onCopyFrom: (int sourceDay) =>
                              _copyFrom(day, sourceDay),
                          onClear: () => _clearDay(day),
                          copyToAllLabel: l10n.hrRosterCopyHoursToAllAction,
                          copyToFollowingLabel:
                              l10n.hrRosterCopyHoursToFollowingAction,
                          copyFromLabel: l10n.hrRosterCopyHoursFromAction,
                          clearLabel: l10n.hrRosterClearDayHoursAction,
                        ),
                      ),
                      for (int hour = 0; hour < _hourCount; hour++)
                        _HourCell(
                          selected: hoursByDay[day]!.contains(hour),
                          selectedStart:
                              hoursByDay[day]!.contains(hour) &&
                              !hoursByDay[day]!.contains(hour - 1),
                          selectedEnd:
                              hoursByDay[day]!.contains(hour) &&
                              !hoursByDay[day]!.contains(hour + 1),
                          locked: _dayLocked(day),
                          width: cellWidth,
                          height: _cellHeight,
                          selectedFill: selectedFill,
                          selectedEdge: selectedEdge,
                          idleFill: idleFill,
                          idleEdge: idleEdge,
                          lockedFill: lockedFill,
                          lockedEdge: lockedEdge,
                          onPrimary: scheme.onPrimary,
                          onTap: _dayLocked(day)
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  _toggleCell(day, hour);
                                },
                          onDragEnter: _dayLocked(day)
                              ? null
                              : () => _paintCell(day, hour),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Map<int, Set<int>> hoursByDay = _hoursByDay();

    final Widget grid = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final double rawCellWidth =
            (maxWidth - _dayLabelWidth) / _hourCount;
        final bool needsScroll = rawCellWidth < _minCellWidth;
        final double cellWidth = needsScroll
            ? _minCellWidth
            : rawCellWidth;

        final Widget body = _buildGrid(
          theme: theme,
          l10n: l10n,
          hoursByDay: hoursByDay,
          cellWidth: cellWidth,
        );

        if (!needsScroll) {
          return body;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _dayLabelWidth + (_minCellWidth * _hourCount),
            child: body,
          ),
        );
      },
    );

    if (!widget.showSectionChrome) {
      return grid;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.hrRosterWeekHoursTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        grid,
      ],
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({
    required this.day,
    required this.label,
    required this.hasHours,
    required this.locked,
    required this.hoursByDay,
    required this.dayLocked,
    required this.dayLabel,
    required this.onCopyToAll,
    required this.onCopyToFollowing,
    required this.onCopyFrom,
    required this.onClear,
    required this.copyToAllLabel,
    required this.copyToFollowingLabel,
    required this.copyFromLabel,
    required this.clearLabel,
  });

  final int day;
  final String label;
  final bool hasHours;
  final bool locked;
  final Map<int, Set<int>> hoursByDay;
  final bool Function(int day) dayLocked;
  final String Function(int day) dayLabel;
  final VoidCallback onCopyToAll;
  final VoidCallback onCopyToFollowing;
  final ValueChanged<int> onCopyFrom;
  final VoidCallback onClear;
  final String copyToAllLabel;
  final String copyToFollowingLabel;
  final String copyFromLabel;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: locked
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                  : hasHours
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: copyToAllLabel,
          padding: EdgeInsets.zero,
          enabled: !locked,
          onSelected: (String value) {
            if (value == 'all') {
              onCopyToAll();
              return;
            }
            if (value == 'following') {
              onCopyToFollowing();
              return;
            }
            if (value == 'clear') {
              onClear();
              return;
            }
            if (value.startsWith('from:')) {
              final int? source = int.tryParse(value.substring(5));
              if (source != null) {
                onCopyFrom(source);
              }
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'all',
              enabled: hasHours,
              child: Text(copyToAllLabel),
            ),
            PopupMenuItem<String>(
              value: 'following',
              enabled: hasHours,
              child: Text(copyToFollowingLabel),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              enabled: false,
              height: 28,
              child: Text(
                copyFromLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final int sourceDay in kHrWeekDayOrder)
              if (sourceDay != day)
                PopupMenuItem<String>(
                  value: 'from:$sourceDay',
                  enabled:
                      !dayLocked(day) &&
                      (hoursByDay[sourceDay]?.isNotEmpty ?? false),
                  child: Text(dayLabel(sourceDay)),
                ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'clear',
              enabled: hasHours,
              child: Text(clearLabel),
            ),
          ],
          child: Icon(
            Icons.more_vert,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell({
    required this.selected,
    required this.selectedStart,
    required this.selectedEnd,
    required this.locked,
    required this.width,
    required this.height,
    required this.selectedFill,
    required this.selectedEdge,
    required this.idleFill,
    required this.idleEdge,
    required this.lockedFill,
    required this.lockedEdge,
    required this.onPrimary,
    required this.onTap,
    required this.onDragEnter,
  });

  final bool selected;
  final bool selectedStart;
  final bool selectedEnd;
  final bool locked;
  final double width;
  final double height;
  final Color selectedFill;
  final Color selectedEdge;
  final Color idleFill;
  final Color idleEdge;
  final Color lockedFill;
  final Color lockedEdge;
  final Color onPrimary;
  final VoidCallback? onTap;
  final VoidCallback? onDragEnter;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.horizontal(
      left: Radius.circular(selected && selectedStart ? 5 : 2),
      right: Radius.circular(selected && selectedEnd ? 5 : 2),
    );

    final Widget cell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.5, vertical: 1.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: locked
              ? lockedFill
              : selected
              ? selectedFill
              : idleFill,
          borderRadius: radius,
          border: Border.all(
            color: locked
                ? lockedEdge
                : selected
                ? selectedEdge
                : idleEdge,
            width: selected && !locked ? 1 : 0.7,
          ),
          boxShadow: selected && !locked
              ? <BoxShadow>[
                  BoxShadow(
                    color: selectedEdge.withValues(alpha: 0.22),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: SizedBox(
          height: height - 3,
          width: width - 1,
          child: selected && !locked
              ? Align(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: onPrimary.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );

    if (locked || onTap == null) {
      return cell;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onDragEnter?.call(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanUpdate: (_) => onDragEnter?.call(),
        child: cell,
      ),
    );
  }
}
