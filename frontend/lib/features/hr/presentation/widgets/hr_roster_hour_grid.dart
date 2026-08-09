import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Visual Mon–Sun × hour grid for roster template working hours.
///
/// Tap or drag hour cells to paint working time. Use each day header menu to
/// copy that day’s hours to all days or to following days.
class HrRosterHourGrid extends StatefulWidget {
  const HrRosterHourGrid({
    required this.schedule,
    required this.onChanged,
    super.key,
  });

  final HrWeeklyScheduleDraft schedule;
  final VoidCallback onChanged;

  @override
  State<HrRosterHourGrid> createState() => _HrRosterHourGridState();
}

class _HrRosterHourGridState extends State<HrRosterHourGrid> {
  static const int _hourCount = 24;
  static const double _hourLabelWidth = 44;
  static const double _dayMinWidth = 72;
  static const double _cellHeight = 22;

  /// When non-null, drag paint is adding (`true`) or clearing (`false`).
  bool? _paintSelect;
  int? _paintDay;

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
    final Set<int> hours = Set<int>.from(_hoursFromDay(widget.schedule.days[day]!));
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
    if (_paintSelect == null || _paintDay != day) {
      return;
    }
    final Set<int> hours = Set<int>.from(_hoursFromDay(widget.schedule.days[day]!));
    final bool changed = _paintSelect!
        ? hours.add(hour)
        : hours.remove(hour);
    if (changed) {
      _applyHours(day, hours);
    }
  }

  void _copyToAll(int sourceDay) {
    final List<HrAvailabilitySlot> source =
        widget.schedule.days[sourceDay]!.toEntitySlots();
    for (final int day in kHrWeekDayOrder) {
      if (day == sourceDay) {
        continue;
      }
      widget.schedule.days[day]!.replaceSlots(source);
    }
    widget.onChanged();
  }

  void _copyToFollowing(int sourceDay) {
    final List<HrAvailabilitySlot> source =
        widget.schedule.days[sourceDay]!.toEntitySlots();
    final int startIndex = kHrWeekDayOrder.indexOf(sourceDay);
    if (startIndex < 0) {
      return;
    }
    for (int i = startIndex + 1; i < kHrWeekDayOrder.length; i++) {
      widget.schedule.days[kHrWeekDayOrder[i]]!.replaceSlots(source);
    }
    widget.onChanged();
  }

  Future<void> _clearDay(int day) async {
    widget.schedule.days[day]!.replaceSlots(const <HrAvailabilitySlot>[]);
    widget.onChanged();
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
        DecoratedBox(
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: _hourLabelWidth,
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 40),
                        for (int hour = 0; hour < _hourCount; hour++)
                          SizedBox(
                            height: _cellHeight,
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Padding(
                                padding: EdgeInsetsDirectional.only(
                                  end: theme.spacing.xs,
                                ),
                                child: Text(
                                  hour.toString().padLeft(2, '0'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final int day in kHrWeekDayOrder)
                    SizedBox(
                      width: _dayMinWidth,
                      child: Column(
                        children: <Widget>[
                          _DayHeader(
                            label: hrDayLabel(l10n, day),
                            hasHours: hoursByDay[day]!.isNotEmpty,
                            onCopyToAll: () => _copyToAll(day),
                            onCopyToFollowing: () => _copyToFollowing(day),
                            onClear: () => _clearDay(day),
                            copyToAllLabel: l10n.hrRosterCopyHoursToAllAction,
                            copyToFollowingLabel:
                                l10n.hrRosterCopyHoursToFollowingAction,
                            clearLabel: l10n.hrRosterClearDayHoursAction,
                          ),
                          for (int hour = 0; hour < _hourCount; hour++)
                            _HourCell(
                              selected: hoursByDay[day]!.contains(hour),
                              height: _cellHeight,
                              selectedFill: selectedFill,
                              selectedBorder: selectedBorder,
                              idleFill: idleFill,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _toggleCell(day, hour);
                              },
                              onDragEnter: () => _paintCell(day, hour),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.label,
    required this.hasHours,
    required this.onCopyToAll,
    required this.onCopyToFollowing,
    required this.onClear,
    required this.copyToAllLabel,
    required this.copyToFollowingLabel,
    required this.clearLabel,
  });

  final String label;
  final bool hasHours;
  final VoidCallback onCopyToAll;
  final VoidCallback onCopyToFollowing;
  final VoidCallback onClear;
  final String copyToAllLabel;
  final String copyToFollowingLabel;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: hasHours
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: copyToAllLabel,
            padding: EdgeInsets.zero,
            iconSize: 18,
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
      ),
    );
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell({
    required this.selected,
    required this.height,
    required this.selectedFill,
    required this.selectedBorder,
    required this.idleFill,
    required this.onTap,
    required this.onDragEnter,
  });

  final bool selected;
  final double height;
  final Color selectedFill;
  final Color selectedBorder;
  final Color idleFill;
  final VoidCallback onTap;
  final VoidCallback onDragEnter;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onDragEnter(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanUpdate: (_) => onDragEnter(),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? selectedFill : idleFill,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: selected
                    ? selectedBorder
                    : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 1.2 : 0.6,
              ),
            ),
            child: SizedBox(height: height - 2, width: double.infinity),
          ),
        ),
      ),
    );
  }
}
