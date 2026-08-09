import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Visual week hour grid: days on the Y-axis, half-hour slots across the X-axis.
///
/// Click a slot to toggle it. Click and drag across a day row to select a
/// contiguous range. Right-click a slot to fine-tune minutes within that hour.
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
  static const int _slotMinutes = 30;
  static const double _dayLabelWidthComfortable = 128;
  static const double _dayLabelWidthCompact = 88;
  static const double _minHourWidth = 22;
  static const double _cellHeightComfortable = 32;
  static const double _cellHeightCompact = 28;
  static const double _hourHeaderHeightComfortable = 34;
  static const double _hourHeaderHeightCompact = 28;

  int? _anchorDay;
  int? _anchorSlot;
  bool _dragging = false;
  List<_MinuteRange>? _dragBaseRanges;

  bool _isWeekend(int day) => day == 0 || day == 6;

  bool _dayLocked(int day) => widget.respectWeekends && _isWeekend(day);

  List<_MinuteRange> _rangesForDay(int day) =>
      _rangesFromDay(widget.schedule.days[day]!);

  void _applyRanges(int day, List<_MinuteRange> ranges) {
    if (_dayLocked(day)) {
      widget.schedule.days[day]!.replaceSlots(const <HrAvailabilitySlot>[]);
      widget.onChanged();
      return;
    }
    widget.schedule.days[day]!.replaceSlots(_slotsFromRanges(ranges));
    widget.onChanged();
  }

  void _toggleSlot(int day, int slot) {
    if (_dayLocked(day)) {
      return;
    }
    final List<_MinuteRange> ranges = _rangesForDay(day);
    final int start = slot * _slotMinutes;
    final int end = start + _slotMinutes;
    final double coverage = _coverageFraction(ranges, start, end);
    final List<_MinuteRange> next = coverage > 0
        ? _removeCoverage(ranges, start, end)
        : _addCoverage(ranges, start, end);
    _applyRanges(day, next);
  }

  void _selectSlotRange(int day, int fromSlot, int toSlot) {
    if (_dayLocked(day)) {
      return;
    }
    final int low = fromSlot < toSlot ? fromSlot : toSlot;
    final int high = fromSlot < toSlot ? toSlot : fromSlot;
    final List<_MinuteRange> base =
        _dragBaseRanges ?? _rangesForDay(day);
    final List<_MinuteRange> next = _addCoverage(
      base,
      low * _slotMinutes,
      (high + 1) * _slotMinutes,
    );
    _applyRanges(day, next);
  }

  void _selectAll() {
    final List<HrAvailabilitySlot> fullDay = <HrAvailabilitySlot>[
      const HrAvailabilitySlot(startTime: '00:00', endTime: '23:59'),
    ];
    for (final int day in kHrWeekDayOrder) {
      if (_dayLocked(day)) {
        widget.schedule.days[day]!.replaceSlots(const <HrAvailabilitySlot>[]);
        continue;
      }
      widget.schedule.days[day]!.replaceSlots(fullDay);
    }
    widget.onChanged();
  }

  void _clearAll() {
    for (final int day in kHrWeekDayOrder) {
      widget.schedule.days[day]!.replaceSlots(const <HrAvailabilitySlot>[]);
    }
    widget.onChanged();
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

  Future<void> _adjustHourMinutes({
    required int day,
    required int hour,
  }) async {
    if (_dayLocked(day)) {
      return;
    }
    final List<_MinuteRange> ranges = _rangesForDay(day);
    final int hourStart = hour * 60;
    final int hourEnd = hourStart + 60;
    final _MinuteRange? existing = _intersection(ranges, hourStart, hourEnd);

    final int startMinute = existing == null
        ? 0
        : (existing.start - hourStart).clamp(0, 59);
    int endMinute = existing == null
        ? 60
        : (existing.end - hourStart).clamp(1, 60);
    if (endMinute <= startMinute) {
      endMinute = (startMinute + _slotMinutes).clamp(1, 60);
    }

    final ({int startMinute, int endMinute})? result =
        await showAppDialog<({int startMinute, int endMinute})>(
          context: context,
          builder: (BuildContext dialogContext) {
            return _HourMinuteDialog(
              hour: hour,
              initialStartMinute: startMinute,
              initialEndMinute: endMinute,
            );
          },
        );
    if (result == null || !mounted) {
      return;
    }
    final List<_MinuteRange> withoutHour = _removeCoverage(
      ranges,
      hourStart,
      hourEnd,
    );
    final List<_MinuteRange> next = result.endMinute > result.startMinute
        ? _addCoverage(
            withoutHour,
            hourStart + result.startMinute,
            hourStart + result.endMinute,
          )
        : withoutHour;
    _applyRanges(day, next);
  }

  void _onSlotPointerDown(int day, int slot, PointerDownEvent event) {
    if (_dayLocked(day)) {
      return;
    }
    // Right-click is handled by onSecondaryTap; don't start a paint gesture.
    if ((event.buttons & 0x02) != 0) {
      return;
    }
    _anchorDay = day;
    _anchorSlot = slot;
    _dragging = false;
    _dragBaseRanges = _rangesForDay(day);
  }

  void _onSlotPointerEnter(int day, int slot) {
    if (_anchorDay != day || _anchorSlot == null || _dragBaseRanges == null) {
      return;
    }
    if (slot == _anchorSlot && !_dragging) {
      return;
    }
    _dragging = true;
    _selectSlotRange(day, _anchorSlot!, slot);
  }

  void _resetPointerState() {
    _anchorDay = null;
    _anchorSlot = null;
    _dragging = false;
    _dragBaseRanges = null;
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
    required Map<int, List<_MinuteRange>> rangesByDay,
    required double? hourWidth,
    required double dayLabelWidth,
    required double cellHeight,
    required double hourHeaderHeight,
    required bool compactChrome,
  }) {
    final ColorScheme scheme = theme.colorScheme;
    final Color selectedFill = scheme.primary.withValues(alpha: 0.88);
    final Color selectedEdge = scheme.primary;
    final Color partialFill = scheme.primary.withValues(alpha: 0.45);
    final Color idleFill = scheme.surfaceContainerHighest.withValues(alpha: 0.38);
    final Color idleEdge = scheme.outlineVariant.withValues(alpha: 0.42);
    final Color lockedFill = scheme.surfaceContainerHighest.withValues(
      alpha: 0.18,
    );
    final Color lockedEdge = scheme.outlineVariant.withValues(alpha: 0.22);
    final bool hasAnyHours = rangesByDay.values.any(
      (List<_MinuteRange> ranges) => ranges.isNotEmpty,
    );
    final bool flexibleHours = hourWidth == null;

    Widget hourSlot({required Widget child}) {
      if (flexibleHours) {
        return Expanded(child: child);
      }
      return SizedBox(width: hourWidth, child: child);
    }

    return Listener(
      onPointerUp: (_) {
        if (_anchorDay != null && _anchorSlot != null && !_dragging) {
          // Pointer up may land outside a cell; still toggle the anchor.
          final int day = _anchorDay!;
          final int slot = _anchorSlot!;
          if (_dragBaseRanges != null) {
            _applyRanges(day, _dragBaseRanges!);
          }
          HapticFeedback.selectionClick();
          _toggleSlot(day, slot);
        }
        _resetPointerState();
      },
      onPointerCancel: (_) => _resetPointerState(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              SizedBox(
                width: dayLabelWidth,
                child: _WeekBulkActions(
                  onSelectAll: _selectAll,
                  onClearAll: hasAnyHours ? _clearAll : null,
                  selectAllLabel: l10n.hrRosterSelectAllHoursAction,
                  clearAllLabel: l10n.hrRosterClearAllHoursAction,
                  compact: compactChrome,
                ),
              ),
              for (int hour = 0; hour < _hourCount; hour++)
                hourSlot(
                  child: _HourHeader(
                    hour: hour,
                    height: hourHeaderHeight,
                    compact: compactChrome,
                  ),
                ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          for (final int day in kHrWeekDayOrder)
            Padding(
              padding: EdgeInsets.only(bottom: compactChrome ? 2 : 3),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: dayLabelWidth,
                    height: cellHeight,
                    child: _DayLabel(
                      day: day,
                      label: hrDayLabel(l10n, day),
                      hasHours: rangesByDay[day]!.isNotEmpty,
                      locked: _dayLocked(day),
                      compact: compactChrome,
                      rangesByDay: rangesByDay,
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
                    hourSlot(
                      child: Row(
                        children: <Widget>[
                          for (int half = 0; half < 2; half++)
                            Expanded(
                              child: _HalfHourCell(
                                coverage: _coverageFraction(
                                  rangesByDay[day]!,
                                  (hour * 2 + half) * _slotMinutes,
                                  (hour * 2 + half + 1) * _slotMinutes,
                                ),
                                selectedStart: _isRangeEdge(
                                  rangesByDay[day]!,
                                  (hour * 2 + half) * _slotMinutes,
                                  isStart: true,
                                ),
                                selectedEnd: _isRangeEdge(
                                  rangesByDay[day]!,
                                  (hour * 2 + half + 1) * _slotMinutes,
                                  isStart: false,
                                ),
                                locked: _dayLocked(day),
                                height: cellHeight,
                                selectedFill: selectedFill,
                                partialFill: partialFill,
                                selectedEdge: selectedEdge,
                                idleFill: idleFill,
                                idleEdge: idleEdge,
                                lockedFill: lockedFill,
                                lockedEdge: lockedEdge,
                                onPointerDown: _dayLocked(day)
                                    ? null
                                    : (PointerDownEvent event) =>
                                          _onSlotPointerDown(
                                            day,
                                            hour * 2 + half,
                                            event,
                                          ),
                                onPointerEnter: _dayLocked(day)
                                    ? null
                                    : () => _onSlotPointerEnter(
                                        day,
                                        hour * 2 + half,
                                      ),
                                onSecondaryTap: _dayLocked(day)
                                    ? null
                                    : () => _adjustHourMinutes(
                                        day: day,
                                        hour: hour,
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Map<int, List<_MinuteRange>> rangesByDay = <int, List<_MinuteRange>>{
      for (final int day in kHrWeekDayOrder) day: _rangesForDay(day),
    };
    final Widget grid = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final bool compactChrome = maxWidth < AppBreakpoints.lg;
        final double dayLabelWidth = compactChrome
            ? _dayLabelWidthCompact
            : _dayLabelWidthComfortable;
        final double cellHeight = compactChrome
            ? _cellHeightCompact
            : _cellHeightComfortable;
        final double hourHeaderHeight = compactChrome
            ? _hourHeaderHeightCompact
            : _hourHeaderHeightComfortable;
        final double hoursWidth =
            (maxWidth - dayLabelWidth).clamp(0.0, double.infinity);
        final double rawHourWidth = hoursWidth / _hourCount;
        final bool needsScroll = rawHourWidth < _minHourWidth;

        final Widget body = _buildGrid(
          theme: theme,
          l10n: l10n,
          rangesByDay: rangesByDay,
          hourWidth: needsScroll ? _minHourWidth : null,
          dayLabelWidth: dayLabelWidth,
          cellHeight: cellHeight,
          hourHeaderHeight: hourHeaderHeight,
          compactChrome: compactChrome,
        );

        if (!needsScroll) {
          return body;
        }

        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: dayLabelWidth + (_minHourWidth * _hourCount),
              child: body,
            ),
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

class _MinuteRange {
  const _MinuteRange(this.start, this.end);

  final int start;
  final int end;
}

List<_MinuteRange> _rangesFromDay(HrDayScheduleDraft day) {
  final List<_MinuteRange> ranges = <_MinuteRange>[];
  for (final HrScheduleSlotDraft slot in day.filledSlots) {
    final int start = slot.start!.totalMinutes.clamp(0, 24 * 60);
    int end = slot.end!.totalMinutes.clamp(0, 24 * 60);
    if (slot.end!.hour == 23 && slot.end!.minute == 59) {
      end = 24 * 60;
    }
    if (end > start) {
      ranges.add(_MinuteRange(start, end));
    }
  }
  return _mergeRanges(ranges);
}

List<HrAvailabilitySlot> _slotsFromRanges(List<_MinuteRange> ranges) {
  final List<_MinuteRange> merged = _mergeRanges(ranges);
  return <HrAvailabilitySlot>[
    for (final _MinuteRange range in merged)
      HrAvailabilitySlot(
        startTime: _formatMinute(range.start),
        endTime: _formatMinute(range.end, isEnd: true),
      ),
  ];
}

String _formatMinute(int minute, {bool isEnd = false}) {
  if (isEnd && minute >= 24 * 60) {
    return '23:59';
  }
  final int clamped = minute.clamp(0, 24 * 60 - (isEnd ? 1 : 0));
  final int hour = clamped ~/ 60;
  final int min = clamped % 60;
  return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}

List<_MinuteRange> _mergeRanges(List<_MinuteRange> input) {
  if (input.isEmpty) {
    return const <_MinuteRange>[];
  }
  final List<_MinuteRange> sorted = List<_MinuteRange>.from(input)
    ..sort((a, b) => a.start.compareTo(b.start));
  final List<_MinuteRange> merged = <_MinuteRange>[sorted.first];
  for (int i = 1; i < sorted.length; i++) {
    final _MinuteRange current = sorted[i];
    final _MinuteRange last = merged.last;
    if (current.start <= last.end) {
      merged[merged.length - 1] = _MinuteRange(
        last.start,
        current.end > last.end ? current.end : last.end,
      );
    } else {
      merged.add(current);
    }
  }
  return merged;
}

List<_MinuteRange> _addCoverage(
  List<_MinuteRange> ranges,
  int start,
  int end,
) {
  if (end <= start) {
    return ranges;
  }
  return _mergeRanges(<_MinuteRange>[...ranges, _MinuteRange(start, end)]);
}

List<_MinuteRange> _removeCoverage(
  List<_MinuteRange> ranges,
  int start,
  int end,
) {
  if (end <= start) {
    return ranges;
  }
  final List<_MinuteRange> next = <_MinuteRange>[];
  for (final _MinuteRange range in ranges) {
    if (range.end <= start || range.start >= end) {
      next.add(range);
      continue;
    }
    if (range.start < start) {
      next.add(_MinuteRange(range.start, start));
    }
    if (range.end > end) {
      next.add(_MinuteRange(end, range.end));
    }
  }
  return _mergeRanges(next);
}

double _coverageFraction(List<_MinuteRange> ranges, int start, int end) {
  if (end <= start) {
    return 0;
  }
  int covered = 0;
  for (final _MinuteRange range in ranges) {
    final int lo = range.start > start ? range.start : start;
    final int hi = range.end < end ? range.end : end;
    if (hi > lo) {
      covered += hi - lo;
    }
  }
  return (covered / (end - start)).clamp(0.0, 1.0);
}

_MinuteRange? _intersection(
  List<_MinuteRange> ranges,
  int start,
  int end,
) {
  int? lo;
  int? hi;
  for (final _MinuteRange range in ranges) {
    final int a = range.start > start ? range.start : start;
    final int b = range.end < end ? range.end : end;
    if (b <= a) {
      continue;
    }
    lo = lo == null || a < lo ? a : lo;
    hi = hi == null || b > hi ? b : hi;
  }
  if (lo == null || hi == null) {
    return null;
  }
  return _MinuteRange(lo, hi);
}

bool _isRangeEdge(
  List<_MinuteRange> ranges,
  int minute, {
  required bool isStart,
}) {
  for (final _MinuteRange range in ranges) {
    if (isStart && range.start == minute) {
      return true;
    }
    if (!isStart && range.end == minute) {
      return true;
    }
  }
  return false;
}

class _HourHeader extends StatelessWidget {
  const _HourHeader({
    required this.hour,
    required this.height,
    required this.compact,
  });

  final int hour;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool major = hour % 3 == 0;
    final String hh = hour.toString().padLeft(2, '0');

    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            compact ? hh : hh,
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: major ? scheme.primary : scheme.onSurface,
              fontWeight: major ? FontWeight.w800 : FontWeight.w600,
              fontSize: compact ? 11 : null,
              height: 1,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          if (!compact)
            Text(
              ':00',
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 9,
                height: 1.1,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            )
          else
            Text(
              'h',
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 8,
                height: 1,
              ),
            ),
          const SizedBox(height: 2),
          Container(
            height: major ? 5 : 3,
            width: major ? 2 : 1,
            decoration: BoxDecoration(
              color: major
                  ? scheme.primary.withValues(alpha: 0.75)
                  : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBulkActions extends StatelessWidget {
  const _WeekBulkActions({
    required this.onSelectAll,
    required this.onClearAll,
    required this.selectAllLabel,
    required this.clearAllLabel,
    required this.compact,
  });

  final VoidCallback onSelectAll;
  final VoidCallback? onClearAll;
  final String selectAllLabel;
  final String clearAllLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (compact) {
      return Row(
        children: <Widget>[
          Expanded(
            child: _BulkIconButton(
              icon: Icons.done_all_outlined,
              tooltip: selectAllLabel,
              foreground: scheme.primary,
              background: scheme.primary.withValues(alpha: 0.12),
              border: scheme.primary.withValues(alpha: 0.28),
              onPressed: onSelectAll,
            ),
          ),
          SizedBox(width: theme.spacing.xs),
          Expanded(
            child: _BulkIconButton(
              icon: Icons.remove_done_outlined,
              tooltip: clearAllLabel,
              foreground: onClearAll == null
                  ? scheme.onSurface.withValues(alpha: 0.38)
                  : scheme.error,
              background: onClearAll == null
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
                  : scheme.error.withValues(alpha: 0.10),
              border: onClearAll == null
                  ? scheme.outlineVariant.withValues(alpha: 0.45)
                  : scheme.error.withValues(alpha: 0.28),
              onPressed: onClearAll,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _BulkActionButton(
          icon: Icons.done_all_outlined,
          label: selectAllLabel,
          foreground: scheme.primary,
          background: scheme.primary.withValues(alpha: 0.12),
          border: scheme.primary.withValues(alpha: 0.28),
          onPressed: onSelectAll,
        ),
        SizedBox(height: theme.spacing.xs),
        _BulkActionButton(
          icon: Icons.remove_done_outlined,
          label: clearAllLabel,
          foreground: onClearAll == null
              ? scheme.onSurface.withValues(alpha: 0.38)
              : scheme.error,
          background: onClearAll == null
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
              : scheme.error.withValues(alpha: 0.10),
          border: onClearAll == null
              ? scheme.outlineVariant.withValues(alpha: 0.45)
              : scheme.error.withValues(alpha: 0.28),
          onPressed: onClearAll,
        ),
      ],
    );
  }
}

class _BulkIconButton extends StatelessWidget {
  const _BulkIconButton({
    required this.icon,
    required this.tooltip,
    required this.foreground,
    required this.background,
    required this.border,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color foreground;
  final Color background;
  final Color border;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(theme.radius.sm),
          child: Ink(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(theme.radius.sm),
              border: Border.all(color: border),
            ),
            child: SizedBox(
              height: 36,
              child: Icon(icon, size: 16, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulkActionButton extends StatelessWidget {
  const _BulkActionButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(theme.radius.sm),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({
    required this.day,
    required this.label,
    required this.hasHours,
    required this.locked,
    required this.compact,
    required this.rangesByDay,
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
  final bool compact;
  final Map<int, List<_MinuteRange>> rangesByDay;
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

  String get _shortLabel {
    final String trimmed = label.trim();
    if (trimmed.length <= 3) {
      return trimmed;
    }
    return trimmed.substring(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = locked
        ? scheme.onSurface.withValues(alpha: 0.38)
        : hasHours
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final Color fill = locked
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.28)
        : hasHours
        ? scheme.primary.withValues(alpha: 0.10)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.38);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(
          color: locked
              ? scheme.outlineVariant.withValues(alpha: 0.35)
              : hasHours
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: compact ? 6 : 8, end: 2),
        child: Row(
          children: <Widget>[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: locked
                    ? scheme.outline
                    : hasHours
                    ? scheme.primary
                    : scheme.outlineVariant,
              ),
            ),
            SizedBox(width: theme.spacing.xs),
            Expanded(
              child: Text(
                _shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (locked)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Icon(
                  Icons.lock_outline,
                  size: 13,
                  color: scheme.onSurface.withValues(alpha: 0.38),
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: copyToAllLabel,
                padding: EdgeInsets.zero,
                offset: const Offset(0, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.radius.md),
                ),
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
                    child: _DayMenuRow(
                      icon: Icons.copy_all_outlined,
                      label: copyToAllLabel,
                      enabled: hasHours,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'following',
                    enabled: hasHours,
                    child: _DayMenuRow(
                      icon: Icons.arrow_forward_outlined,
                      label: copyToFollowingLabel,
                      enabled: hasHours,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    enabled: false,
                    height: 30,
                    child: Text(
                      copyFromLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  for (final int sourceDay in kHrWeekDayOrder)
                    if (sourceDay != day)
                      PopupMenuItem<String>(
                        value: 'from:$sourceDay',
                        enabled:
                            !dayLocked(day) &&
                            (rangesByDay[sourceDay]?.isNotEmpty ?? false),
                        child: _DayMenuRow(
                          icon: Icons.calendar_view_day_outlined,
                          label: dayLabel(sourceDay),
                          enabled:
                              rangesByDay[sourceDay]?.isNotEmpty ?? false,
                          emphasize:
                              rangesByDay[sourceDay]?.isNotEmpty ?? false,
                        ),
                      ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'clear',
                    enabled: hasHours,
                    child: _DayMenuRow(
                      icon: Icons.clear_outlined,
                      label: clearLabel,
                      enabled: hasHours,
                      destructive: true,
                    ),
                  ),
                ],
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayMenuRow extends StatelessWidget {
  const _DayMenuRow({
    required this.icon,
    required this.label,
    required this.enabled,
    this.emphasize = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool emphasize;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color color = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : destructive
        ? scheme.error
        : emphasize
        ? scheme.primary
        : scheme.onSurface;

    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: emphasize || destructive
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _HalfHourCell extends StatelessWidget {
  const _HalfHourCell({
    required this.coverage,
    required this.selectedStart,
    required this.selectedEnd,
    required this.locked,
    required this.height,
    required this.selectedFill,
    required this.partialFill,
    required this.selectedEdge,
    required this.idleFill,
    required this.idleEdge,
    required this.lockedFill,
    required this.lockedEdge,
    required this.onPointerDown,
    required this.onPointerEnter,
    required this.onSecondaryTap,
  });

  final double coverage;
  final bool selectedStart;
  final bool selectedEnd;
  final bool locked;
  final double height;
  final Color selectedFill;
  final Color partialFill;
  final Color selectedEdge;
  final Color idleFill;
  final Color idleEdge;
  final Color lockedFill;
  final Color lockedEdge;
  final ValueChanged<PointerDownEvent>? onPointerDown;
  final VoidCallback? onPointerEnter;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final bool fullySelected = !locked && coverage >= 0.999;
    final bool partiallySelected = !locked && coverage > 0 && !fullySelected;
    final bool inRange = fullySelected || partiallySelected;
    final bool seamlessLeft = fullySelected && !selectedStart;
    final bool seamlessRight = fullySelected && !selectedEnd;

    final Color fill = locked
        ? lockedFill
        : fullySelected
        ? selectedFill
        : partiallySelected
        ? partialFill
        : idleFill;

    final BorderRadius radius = BorderRadius.horizontal(
      left: Radius.circular(inRange && selectedStart ? 5 : 0),
      right: Radius.circular(inRange && selectedEnd ? 5 : 0),
    );

    final Widget cell = Padding(
      padding: EdgeInsets.only(
        left: seamlessLeft ? 0 : (inRange ? 0 : 0.5),
        right: seamlessRight ? 0 : (inRange ? 0 : 0.5),
        top: 2,
        bottom: 2,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: inRange
              ? radius
              : BorderRadius.circular(locked ? 2 : 3),
          border: inRange
              ? null
              : Border.all(
                  color: locked ? lockedEdge : idleEdge,
                  width: 0.7,
                ),
        ),
        child: SizedBox(
          height: height - 4,
          width: double.infinity,
          child: partiallySelected
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: coverage.clamp(0.15, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selectedFill,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );

    if (locked || onPointerDown == null) {
      return cell;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onPointerEnter?.call(),
      child: Listener(
        onPointerDown: onPointerDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTap: onSecondaryTap,
          child: cell,
        ),
      ),
    );
  }
}

class _HourMinuteDialog extends StatefulWidget {
  const _HourMinuteDialog({
    required this.hour,
    required this.initialStartMinute,
    required this.initialEndMinute,
  });

  final int hour;
  final int initialStartMinute;
  final int initialEndMinute;

  @override
  State<_HourMinuteDialog> createState() => _HourMinuteDialogState();
}

class _HourMinuteDialogState extends State<_HourMinuteDialog> {
  late int _startMinute = widget.initialStartMinute.clamp(0, 59);
  late int _endMinute = widget.initialEndMinute.clamp(1, 60);

  String _labelForMinute(int minute) {
    final String hour = widget.hour.toString().padLeft(2, '0');
    if (minute >= 60) {
      final int nextHour = (widget.hour + 1) % 24;
      return '${nextHour.toString().padLeft(2, '0')}:00';
    }
    return '$hour:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool valid = _endMinute > _startMinute;

    return AppDialog(
      title: Text(l10n.hrRosterAdjustHourTimeTitle),
      icon: const Icon(Icons.schedule_outlined),
      showMaximizeButton: false,
      maxWidth: 420,
      initialMaximized: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.hrRosterAdjustHourTimeHint(
              widget.hour.toString().padLeft(2, '0'),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.hrRosterHourStartMinuteLabel,
            style: theme.textTheme.labelLarge,
          ),
          SizedBox(height: theme.spacing.xs),
          DropdownButton<int>(
            value: _startMinute,
            isExpanded: true,
            items: <DropdownMenuItem<int>>[
              for (int minute = 0; minute <= 59; minute++)
                DropdownMenuItem<int>(
                  value: minute,
                  child: Text(_labelForMinute(minute)),
                ),
            ],
            onChanged: (int? value) {
              if (value == null) {
                return;
              }
              setState(() => _startMinute = value);
            },
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.hrRosterHourEndMinuteLabel,
            style: theme.textTheme.labelLarge,
          ),
          SizedBox(height: theme.spacing.xs),
          DropdownButton<int>(
            value: _endMinute,
            isExpanded: true,
            items: <DropdownMenuItem<int>>[
              for (int minute = 1; minute <= 60; minute++)
                DropdownMenuItem<int>(
                  value: minute,
                  child: Text(_labelForMinute(minute)),
                ),
            ],
            onChanged: (int? value) {
              if (value == null) {
                return;
              }
              setState(() => _endMinute = value);
            },
          ),
          if (!valid) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              l10n.hrAvailabilityEndAfterStartError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          onPressed: () {
            if (!valid) {
              return;
            }
            Navigator.of(context).pop((
              startMinute: _startMinute,
              endMinute: _endMinute,
            ));
          },
          enabled: valid,
          icon: Icons.check,
          label: l10n.appDateRangeApplyAction,
        ),
        AppButton.close(
          onPressed: () => Navigator.of(context).pop(),
          label: l10n.commonCloseActionLabel,
        ),
      ],
    );
  }
}
