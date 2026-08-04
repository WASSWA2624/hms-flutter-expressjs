import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum HrAvailabilityCalendarMode { week, month }

/// Week/month calendar for recurring staff availability with leave overlay.
class HrAvailabilityCalendar extends StatefulWidget {
  const HrAvailabilityCalendar({
    required this.availabilities,
    required this.leaves,
    this.onDayTap,
    this.onRecordAvailability,
    super.key,
  });

  final List<HrStaffAvailability> availabilities;
  final List<HrStaffLeave> leaves;
  final void Function(int dayOfWeek)? onDayTap;
  final VoidCallback? onRecordAvailability;

  @override
  State<HrAvailabilityCalendar> createState() => _HrAvailabilityCalendarState();
}

class _HrAvailabilityCalendarState extends State<HrAvailabilityCalendar> {
  HrAvailabilityCalendarMode _mode = HrAvailabilityCalendarMode.week;

  HrStaffAvailability? _availabilityForDay(int day) {
    for (final HrStaffAvailability item in widget.availabilities) {
      if (item.dayOfWeek == day) {
        return item;
      }
    }
    return null;
  }

  bool _hasApprovedLeaveOnDay(int day) {
    for (final HrStaffLeave leave in widget.leaves) {
      if ((leave.status ?? '').trim().toUpperCase() != 'APPROVED') {
        continue;
      }
      final DateTime? start = leave.startDate;
      final DateTime? end = leave.endDate ?? leave.startDate;
      if (start == null) {
        continue;
      }
      final DateTime cursor = DateTime.now();
      for (int offset = 0; offset < 7; offset++) {
        final DateTime date = cursor.add(Duration(days: offset));
        if (date.weekday % 7 == day &&
            !date.isBefore(start) &&
            !date.isAfter(end!)) {
          return true;
        }
      }
    }
    return false;
  }

  Color _dayColor(BuildContext context, int day) {
    final ThemeData theme = Theme.of(context);
    if (_hasApprovedLeaveOnDay(day)) {
      return theme.colorScheme.tertiaryContainer.withValues(alpha: 0.65);
    }
    final HrStaffAvailability? availability = _availabilityForDay(day);
    if (availability == null) {
      return theme.colorScheme.surfaceContainerHighest;
    }
    final String status = (availability.status ?? availability.preference ?? '')
        .trim()
        .toUpperCase();
    if (status.contains('UNAVAILABLE') || status.contains('BLOCK')) {
      return theme.colorScheme.surfaceContainerHighest;
    }
    return theme.colorScheme.primaryContainer.withValues(alpha: 0.45);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (widget.availabilities.isEmpty) {
      return AppStateView(
        icon: Icons.schedule_outlined,
        title: l10n.hrNoAvailabilityLabel,
        body: l10n.hrAvailabilityCalendarEmptyBody,
        action: widget.onRecordAvailability == null
            ? null
            : AppButton.secondary(
                label: l10n.hrRecordAvailabilityAction,
                onPressed: widget.onRecordAvailability,
              ),
      );
    }

    const List<int> days = kAvailabilityWeekDayOrder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _mode == HrAvailabilityCalendarMode.week
                    ? l10n.hrAvailabilityWeekViewLabel
                    : l10n.hrAvailabilityMonthViewLabel,
                style: theme.textTheme.titleSmall,
              ),
            ),
            AppButton.tertiary(
              label: _mode == HrAvailabilityCalendarMode.week
                  ? l10n.hrAvailabilityMonthViewLabel
                  : l10n.hrAvailabilityWeekViewLabel,
              onPressed: () => setState(() {
                _mode = _mode == HrAvailabilityCalendarMode.week
                    ? HrAvailabilityCalendarMode.month
                    : HrAvailabilityCalendarMode.week;
              }),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: theme.spacing.xs,
            crossAxisSpacing: theme.spacing.xs,
            childAspectRatio: 1.2,
          ),
          itemCount: days.length,
          itemBuilder: (BuildContext context, int index) {
            final int day = days[index];
            final HrStaffAvailability? availability = _availabilityForDay(day);
            return Material(
              color: _dayColor(context, day),
              borderRadius: BorderRadius.circular(theme.radius.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(theme.radius.sm),
                onTap: widget.onDayTap == null
                    ? null
                    : () => widget.onDayTap!(day),
                child: Padding(
                  padding: EdgeInsets.all(theme.spacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hrDayLabel(l10n, day),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: AppFontWeight.emphasis,
                        ),
                      ),
                      if (availability != null)
                        Expanded(
                          child: Text(
                            hrAvailabilitySlotSummary(availability),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        SizedBox(height: theme.spacing.sm),
        Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            _LegendDot(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
              label: l10n.hrAvailabilityLegendAvailableLabel,
            ),
            _LegendDot(
              color: theme.colorScheme.surfaceContainerHighest,
              label: l10n.hrAvailabilityLegendUnavailableLabel,
            ),
            _LegendDot(
              color: theme.colorScheme.tertiaryContainer.withValues(
                alpha: 0.65,
              ),
              label: l10n.hrAvailabilityLegendLeaveLabel,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(theme.radius.xs),
          ),
        ),
        SizedBox(width: theme.spacing.xs),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

Future<void> showHrAvailabilityDaySheet(
  BuildContext context, {
  required int dayOfWeek,
  required HrStaffAvailability? availability,
  VoidCallback? onEdit,
  VoidCallback? onAddSlot,
}) async {
  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final Locale locale = Localizations.localeOf(context);
  final List<HrAvailabilitySlot> slots = availability == null
      ? const <HrAvailabilitySlot>[]
      : hrDedupedAvailabilitySlots(availability);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            theme.spacing.md,
            theme.spacing.sm,
            theme.spacing.md,
            theme.spacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                hrDayLabel(l10n, dayOfWeek),
                style: theme.textTheme.titleMedium,
              ),
              if (availability?.effectiveFrom != null ||
                  availability?.effectiveTo != null) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                Text(
                  hrJoinDisplay(<String?>[
                    availability?.effectiveFrom == null
                        ? null
                        : AppFormatters.shortDate(
                            availability!.effectiveFrom!,
                            locale,
                          ),
                    availability?.effectiveTo == null
                        ? null
                        : AppFormatters.shortDate(
                            availability!.effectiveTo!,
                            locale,
                          ),
                  ]),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              SizedBox(height: theme.spacing.md),
              if (slots.isEmpty)
                Text(l10n.hrAvailabilityDayEmptyLabel)
              else
                ...slots.map(
                  (HrAvailabilitySlot slot) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text('${slot.startTime} – ${slot.endTime}'),
                    subtitle: Text(
                      hrJoinDisplay(<String?>[
                        availability?.status,
                        availability?.preference,
                      ]),
                    ),
                  ),
                ),
              SizedBox(height: theme.spacing.sm),
              if ((slots.isEmpty && onAddSlot != null) ||
                  (slots.isNotEmpty && onEdit != null))
                AppButton.secondary(
                  label: slots.isEmpty
                      ? l10n.hrAvailabilityAddSlotAction
                      : l10n.hrAvailabilityEditDayAction,
                  leadingIcon: Icons.edit_outlined,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    if (slots.isEmpty) {
                      onAddSlot!();
                    } else {
                      onEdit!();
                    }
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
