import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Visual week hour grid: days on the Y-axis, hours across the X-axis.
///
/// Tap or drag hour cells to paint working time. Use each day menu to copy
/// that day’s hours to all days or to following days.
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

  /// When false, omits the title/hint (parent supplies section chrome).
  final bool showSectionChrome;

  @override
  State<HrRosterHourGrid> createState() => _HrRosterHourGridState();
}

class _HrRosterHourGridState extends State<HrRosterHourGrid> {
  static const int _hourCount = 24;
  static const double _dayLabelWidth = 108;
  static const double _cellWidth = 28;
  static const double _cellHeight = 28;

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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Map<int, Set<int>> hoursByDay = _hoursByDay();
    final Color selectedFill = theme.colorScheme.primaryContainer;
    final Color selectedBorder = theme.colorScheme.primary;
    final Color idleFill = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.35,
    );
    final Color lockedFill = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.18);
    final bool hasAnyHours = hoursByDay.values.any(
      (Set<int> hours) => hours.isNotEmpty,
    );

    final Widget grid = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(theme.spacing.sm),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox(
                    width: _dayLabelWidth,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: hasAnyHours ? _clearAll : null,
                        child: Text(l10n.hrRosterClearAllHoursAction),
                      ),
                    ),
                  ),
                  for (int hour = 0; hour < _hourCount; hour++)
                    SizedBox(
                      width: _cellWidth,
                      child: Text(
                        hour.toString().padLeft(2, '0'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
                  padding: EdgeInsets.only(bottom: theme.spacing.xs / 2),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: _dayLabelWidth,
                        child: _DayLabel(
                          label: hrDayLabel(l10n, day),
                          hasHours: hoursByDay[day]!.isNotEmpty,
                          locked: _dayLocked(day),
                          onCopyToAll: () => _copyToAll(day),
                          onCopyToFollowing: () => _copyToFollowing(day),
                          onClear: () => _clearDay(day),
                          copyToAllLabel: l10n.hrRosterCopyHoursToAllAction,
                          copyToFollowingLabel:
                              l10n.hrRosterCopyHoursToFollowingAction,
                          clearLabel: l10n.hrRosterClearDayHoursAction,
                        ),
                      ),
                      for (int hour = 0; hour < _hourCount; hour++)
                        _HourCell(
                          selected: hoursByDay[day]!.contains(hour),
                          locked: _dayLocked(day),
                          width: _cellWidth,
                          height: _cellHeight,
                          selectedFill: selectedFill,
                          selectedBorder: selectedBorder,
                          idleFill: idleFill,
                          lockedFill: lockedFill,
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

    if (!widget.showSectionChrome) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppMutedText(l10n.hrRosterWeekHoursHint),
          SizedBox(height: theme.spacing.sm),
          grid,
        ],
      );
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
        SizedBox(height: theme.spacing.xs),
        AppMutedText(l10n.hrRosterWeekHoursHint),
        SizedBox(height: theme.spacing.sm),
        grid,
      ],
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({
    required this.label,
    required this.hasHours,
    required this.locked,
    required this.onCopyToAll,
    required this.onCopyToFollowing,
    required this.onClear,
    required this.copyToAllLabel,
    required this.copyToFollowingLabel,
    required this.clearLabel,
  });

  final String label;
  final bool hasHours;
  final bool locked;
  final VoidCallback onCopyToAll;
  final VoidCallback onCopyToFollowing;
  final VoidCallback onClear;
  final String copyToAllLabel;
  final String copyToFollowingLabel;
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
            switch (value) {
              case 'all':
                onCopyToAll();
              case 'following':
                onCopyToFollowing();
              case 'clear':
                onClear();
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
    required this.locked,
    required this.width,
    required this.height,
    required this.selectedFill,
    required this.selectedBorder,
    required this.idleFill,
    required this.lockedFill,
    required this.onTap,
    required this.onDragEnter,
  });

  final bool selected;
  final bool locked;
  final double width;
  final double height;
  final Color selectedFill;
  final Color selectedBorder;
  final Color idleFill;
  final Color lockedFill;
  final VoidCallback? onTap;
  final VoidCallback? onDragEnter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget cell = Padding(
      padding: const EdgeInsets.all(1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: locked
              ? lockedFill
              : selected
              ? selectedFill
              : idleFill,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: locked
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.5)
                : selected
                ? selectedBorder
                : theme.colorScheme.outlineVariant,
            width: selected && !locked ? 1.2 : 0.6,
          ),
        ),
        child: SizedBox(height: height - 2, width: width - 2),
      ),
    );

    if (locked || onTap == null) {
      return cell;
    }

    return MouseRegion(
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
