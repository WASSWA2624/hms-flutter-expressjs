import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Monday-first display order; values match API `day_of_week` (0 = Sunday).
const List<int> kHrWeekDayOrder = <int>[1, 2, 3, 4, 5, 6, 0];

/// Backward-compatible alias used by availability flows.
const List<int> kAvailabilityWeekDayOrder = kHrWeekDayOrder;

/// Default weekday schedule for new records (Mon–Fri).
const List<int> kDefaultAvailabilityWeekdays = <int>[1, 2, 3, 4, 5];

const AppTimeValue kDefaultAvailabilityStartTime = AppTimeValue(
  hour: 8,
  minute: 0,
);
const AppTimeValue kDefaultAvailabilityEndTime = AppTimeValue(
  hour: 17,
  minute: 0,
);

String hrDayLabel(AppLocalizations l10n, int day) {
  return switch (day) {
    0 => l10n.hrSundayLabel,
    1 => l10n.hrMondayLabel,
    2 => l10n.hrTuesdayLabel,
    3 => l10n.hrWednesdayLabel,
    4 => l10n.hrThursdayLabel,
    5 => l10n.hrFridayLabel,
    6 => l10n.hrSaturdayLabel,
    _ => l10n.profileUnknownValue,
  };
}

String hrShiftTypeLabel(AppLocalizations l10n, String? shiftType) {
  return switch (shiftType?.trim().toUpperCase()) {
    'DAY' => l10n.hrShiftTypeDay,
    'NIGHT' => l10n.hrShiftTypeNight,
    'SWING' => l10n.hrShiftTypeSwing,
    'ON_CALL' => l10n.hrShiftTypeOnCall,
    final String value when value.isNotEmpty => value,
    _ => l10n.profileUnknownValue,
  };
}

/// Mutable weekly schedule draft shared by availability and template flows.
final class HrWeeklyScheduleDraft {
  HrWeeklyScheduleDraft({
    Map<int, HrDayScheduleDraft>? days,
    bool weekdayDefaults = false,
  }) : days =
           days ??
           <int, HrDayScheduleDraft>{
             for (final int day in kHrWeekDayOrder)
               day:
                   weekdayDefaults && kDefaultAvailabilityWeekdays.contains(day)
                   ? HrDayScheduleDraft.weekdayDefault()
                   : HrDayScheduleDraft(),
           };

  final Map<int, HrDayScheduleDraft> days;

  void dispose() {
    for (final HrDayScheduleDraft day in days.values) {
      day.clear();
    }
  }

  List<Map<String, Object?>> toAvailabilityDaysPayload() {
    final List<Map<String, Object?>> result = <Map<String, Object?>>[];
    for (final int day in kHrWeekDayOrder) {
      final List<Map<String, Object?>> slots = days[day]!.toSlotPayloads();
      if (slots.isEmpty) {
        continue;
      }
      result.add(<String, Object?>{'day_of_week': day, 'time_slots': slots});
    }
    return result;
  }

  List<Map<String, Object?>> toTemplateWeeklySchedulePayload() =>
      toAvailabilityDaysPayload();

  String? validate(AppLocalizations l10n) {
    var scheduledDayCount = 0;
    for (final int day in kHrWeekDayOrder) {
      final HrDayScheduleDraft schedule = days[day]!;
      final List<HrScheduleSlotDraft> filledSlots = schedule.filledSlots;
      if (filledSlots.isEmpty) {
        continue;
      }
      scheduledDayCount += 1;

      for (final HrScheduleSlotDraft slot in filledSlots) {
        if (slot.start == null || slot.end == null) {
          continue;
        }
        if (!slot.end!.isAfter(slot.start!)) {
          return l10n.hrAvailabilityEndAfterStartError;
        }
      }

      if (hrScheduleSlotsOverlap(filledSlots)) {
        return l10n.hrAvailabilitySlotOverlapError;
      }
    }

    if (scheduledDayCount == 0) {
      return l10n.hrAvailabilityNoDaysSelectedError;
    }

    return null;
  }

  void applyEntitySlotsByDay(Map<int, List<HrAvailabilitySlot>> slotsByDay) {
    for (final int day in kHrWeekDayOrder) {
      days[day]!.replaceSlots(slotsByDay[day] ?? const <HrAvailabilitySlot>[]);
    }
  }

  void applyWeeklyScheduleJson(Object? raw) {
    final Map<int, List<HrAvailabilitySlot>> slotsByDay =
        <int, List<HrAvailabilitySlot>>{};
    if (raw is List<Object?>) {
      for (final Object? entry in raw) {
        if (entry is! Map) {
          continue;
        }
        final int? day = _parseDayOfWeek(entry['day_of_week']);
        if (day == null) {
          continue;
        }
        slotsByDay[day] = _parseTimeSlots(entry['time_slots']);
      }
    }
    applyEntitySlotsByDay(slotsByDay);
  }

  void applyLegacyDefaultTimes(String? startTime, String? endTime) {
    final String? start = startTime?.trim();
    final String? end = endTime?.trim();
    if (start == null || start.isEmpty || end == null || end.isEmpty) {
      return;
    }
    applyEntitySlotsByDay(<int, List<HrAvailabilitySlot>>{
      for (final int day in kDefaultAvailabilityWeekdays)
        day: <HrAvailabilitySlot>[
          HrAvailabilitySlot(startTime: start, endTime: end),
        ],
    });
  }

  static HrWeeklyScheduleDraft fromTemplateExtra(Map<String, Object?> extra) {
    final HrWeeklyScheduleDraft draft = HrWeeklyScheduleDraft();
    final Object? weekly = extra['weekly_schedule_json'];
    if (weekly != null) {
      draft.applyWeeklyScheduleJson(weekly);
      return draft;
    }
    draft.applyLegacyDefaultTimes(
      extra['default_start_time']?.toString(),
      extra['default_end_time']?.toString(),
    );
    return draft;
  }
}

final class HrDayScheduleDraft {
  HrDayScheduleDraft() : slots = <HrScheduleSlotDraft>[HrScheduleSlotDraft()];

  factory HrDayScheduleDraft.weekdayDefault() {
    final HrDayScheduleDraft schedule = HrDayScheduleDraft();
    final HrScheduleSlotDraft slot = schedule.slots.first;
    slot.start = kDefaultAvailabilityStartTime;
    slot.end = kDefaultAvailabilityEndTime;
    return schedule;
  }

  final List<HrScheduleSlotDraft> slots;

  List<HrScheduleSlotDraft> get filledSlots => <HrScheduleSlotDraft>[
    for (final HrScheduleSlotDraft slot in slots)
      if (slot.start != null && slot.end != null) slot,
  ];

  void addSlot() => slots.add(HrScheduleSlotDraft());

  void removeSlotAt(int index) {
    slots.removeAt(index);
  }

  void clear() {
    slots.clear();
    slots.add(HrScheduleSlotDraft());
  }

  List<Map<String, Object?>> toSlotPayloads() => <Map<String, Object?>>[
    for (final HrScheduleSlotDraft slot in filledSlots)
      <String, Object?>{
        'start_time': slot.start!.format24(),
        'end_time': slot.end!.format24(),
      },
  ];

  List<HrAvailabilitySlot> toEntitySlots() => <HrAvailabilitySlot>[
    for (final HrScheduleSlotDraft slot in filledSlots)
      HrAvailabilitySlot(
        startTime: slot.start!.format24(),
        endTime: slot.end!.format24(),
      ),
  ];

  void replaceSlots(List<HrAvailabilitySlot> source) {
    slots.clear();
    if (source.isEmpty) {
      slots.add(HrScheduleSlotDraft());
      return;
    }
    for (final HrAvailabilitySlot slot in source) {
      final HrScheduleSlotDraft draft = HrScheduleSlotDraft();
      draft.start = AppTimeValue.parse(slot.startTime);
      draft.end = AppTimeValue.parse(slot.endTime);
      slots.add(draft);
    }
  }
}

final class HrScheduleSlotDraft {
  AppTimeValue? start;
  AppTimeValue? end;
}

bool hrScheduleSlotsOverlap(List<HrScheduleSlotDraft> slots) {
  final List<List<int>> ranges = <List<int>>[
    for (final HrScheduleSlotDraft slot in slots)
      if (slot.start != null && slot.end != null)
        <int>[slot.start!.totalMinutes, slot.end!.totalMinutes],
  ]..sort((List<int> a, List<int> b) => a[0].compareTo(b[0]));

  for (var index = 1; index < ranges.length; index += 1) {
    if (ranges[index][0] < ranges[index - 1][1]) {
      return true;
    }
  }
  return false;
}

int? _parseDayOfWeek(Object? value) {
  if (value is int) {
    return value >= 0 && value <= 6 ? value : null;
  }
  return int.tryParse(value?.toString() ?? '');
}

List<HrAvailabilitySlot> _parseTimeSlots(Object? raw) {
  if (raw is! List<Object?>) {
    return const <HrAvailabilitySlot>[];
  }
  return <HrAvailabilitySlot>[
        for (final Object? slot in raw)
          if (slot is Map)
            HrAvailabilitySlot(
              startTime: slot['start_time']?.toString() ?? '',
              endTime: slot['end_time']?.toString() ?? '',
            ),
      ]
      .where((HrAvailabilitySlot slot) {
        return slot.startTime.trim().isNotEmpty &&
            slot.endTime.trim().isNotEmpty;
      })
      .toList(growable: false);
}

/// Reusable weekly schedule editor for availability and schedule templates.
class HrWeeklyScheduleEditor extends StatelessWidget {
  const HrWeeklyScheduleEditor({
    required this.schedule,
    required this.onChanged,
    this.readOnly = false,
    this.showSectionTitle = true,
    this.sectionTitle,
    super.key,
  });

  final HrWeeklyScheduleDraft schedule;
  final VoidCallback onChanged;
  final bool readOnly;
  final bool showSectionTitle;
  final String? sectionTitle;

  Future<void> _showDuplicateDialog(BuildContext context, int sourceDay) async {
    final AppLocalizations l10n = context.l10n;
    final Set<int> selectedDays = <int>{};

    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AppDialog(
              title: Text(l10n.hrScheduleDuplicateToDialogTitle),
              icon: const Icon(Icons.content_copy_outlined),
              scrollable: true,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.hrScheduleDuplicateToDialogDescription(
                      hrDayLabel(l10n, sourceDay),
                    ),
                  ),
                  SizedBox(height: Theme.of(context).spacing.md),
                  for (final int day in kHrWeekDayOrder)
                    if (day != sourceDay)
                      AppCheckboxField(
                        title: hrDayLabel(l10n, day),
                        value: selectedDays.contains(day),
                        onChanged: (bool checked) {
                          setDialogState(() {
                            if (checked) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                      ),
                ],
              ),
              actions: <Widget>[
                AppButton.close(
                  leadingIcon: AppActionIcons.cancel,
                  label: l10n.commonCancelActionLabel,
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                AppButton.primary(
                  label: l10n.hrDuplicateScheduleToAction,
                  enabled: selectedDays.isNotEmpty,
                  onPressed: selectedDays.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final List<HrAvailabilitySlot> sourceSlots = schedule.days[sourceDay]!
        .toEntitySlots();
    for (final int day in selectedDays) {
      schedule.days[day]!.replaceSlots(sourceSlots);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    final Widget days = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final int day in kHrWeekDayOrder)
          _HrDayScheduleSection(
            dayLabel: hrDayLabel(l10n, day),
            schedule: schedule.days[day]!,
            readOnly: readOnly,
            onChanged: onChanged,
            onDuplicate: readOnly
                ? null
                : () => _showDuplicateDialog(context, day),
            duplicateLabel: l10n.hrDuplicateScheduleToAction,
            addSlotLabel: l10n.hrAddScheduleSlotAction,
            removeSlotLabel: l10n.hrRemoveScheduleSlotAction,
            startTimeLabel: l10n.hrStartTimeLabel,
            endTimeLabel: l10n.hrEndTimeLabel,
            pickerButtonLabel: l10n.appTimePickerAction,
            invalidTimeMessage: l10n.appTimeInvalidMessage,
            hourLabelText: l10n.appTimeHourLabel,
            minuteLabelText: l10n.appTimeMinuteLabel,
            hour12LabelText: l10n.appTime12HourLabel,
            hour24LabelText: l10n.appTime24HourLabel,
            timeHint: l10n.hrTimeHint,
            requiredFieldMessage: l10n.hrFieldRequiredLabel,
          ),
      ],
    );

    if (!showSectionTitle) {
      return days;
    }

    return AppCollapsibleSection(
      title: sectionTitle ?? l10n.hrWeeklyScheduleSectionTitle,
      child: days,
    );
  }
}

class _HrDayScheduleSection extends StatelessWidget {
  const _HrDayScheduleSection({
    required this.dayLabel,
    required this.schedule,
    required this.onChanged,
    required this.duplicateLabel,
    required this.addSlotLabel,
    required this.removeSlotLabel,
    required this.startTimeLabel,
    required this.endTimeLabel,
    required this.pickerButtonLabel,
    required this.invalidTimeMessage,
    required this.hourLabelText,
    required this.minuteLabelText,
    required this.hour12LabelText,
    required this.hour24LabelText,
    required this.timeHint,
    required this.requiredFieldMessage,
    this.readOnly = false,
    this.onDuplicate,
  });

  final String dayLabel;
  final HrDayScheduleDraft schedule;
  final VoidCallback onChanged;
  final VoidCallback? onDuplicate;
  final bool readOnly;
  final String duplicateLabel;
  final String addSlotLabel;
  final String removeSlotLabel;
  final String startTimeLabel;
  final String endTimeLabel;
  final String pickerButtonLabel;
  final String invalidTimeMessage;
  final String hourLabelText;
  final String minuteLabelText;
  final String hour12LabelText;
  final String hour24LabelText;
  final String timeHint;
  final String Function(String fieldLabel) requiredFieldMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.only(bottom: theme.spacing.sm),
      child: ExpansionTile(
        initiallyExpanded: schedule.filledSlots.isNotEmpty,
        title: Text(dayLabel),
        subtitle: schedule.filledSlots.isEmpty
            ? null
            : Text(
                schedule.filledSlots
                    .map(
                      (HrScheduleSlotDraft slot) =>
                          '${slot.start!.format24()}-${slot.end!.format24()}',
                    )
                    .join(', '),
              ),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spacing.md,
              0,
              theme.spacing.md,
              theme.spacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!readOnly &&
                    schedule.filledSlots.isNotEmpty &&
                    onDuplicate != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton.secondary(
                      label: duplicateLabel,
                      leadingIcon: Icons.content_copy_outlined,
                      onPressed: onDuplicate,
                    ),
                  ),
                for (var index = 0; index < schedule.slots.length; index += 1)
                  _HrScheduleSlotFields(
                    slot: schedule.slots[index],
                    canRemove: !readOnly && schedule.slots.length > 1,
                    readOnly: readOnly,
                    startTimeLabel: startTimeLabel,
                    endTimeLabel: endTimeLabel,
                    pickerButtonLabel: pickerButtonLabel,
                    invalidTimeMessage: invalidTimeMessage,
                    hourLabelText: hourLabelText,
                    minuteLabelText: minuteLabelText,
                    hour12LabelText: hour12LabelText,
                    hour24LabelText: hour24LabelText,
                    timeHint: timeHint,
                    removeSlotLabel: removeSlotLabel,
                    requiredFieldMessage: requiredFieldMessage,
                    onChanged: onChanged,
                    onRemove: () {
                      schedule.removeSlotAt(index);
                      onChanged();
                    },
                  ),
                if (!readOnly)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton.secondary(
                      label: addSlotLabel,
                      leadingIcon: Icons.add,
                      onPressed: () {
                        schedule.addSlot();
                        onChanged();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HrScheduleSlotFields extends StatelessWidget {
  const _HrScheduleSlotFields({
    required this.slot,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    required this.startTimeLabel,
    required this.endTimeLabel,
    required this.pickerButtonLabel,
    required this.invalidTimeMessage,
    required this.hourLabelText,
    required this.minuteLabelText,
    required this.hour12LabelText,
    required this.hour24LabelText,
    required this.timeHint,
    required this.removeSlotLabel,
    required this.requiredFieldMessage,
    this.readOnly = false,
  });

  final HrScheduleSlotDraft slot;
  final bool canRemove;
  final bool readOnly;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final String startTimeLabel;
  final String endTimeLabel;
  final String pickerButtonLabel;
  final String invalidTimeMessage;
  final String hourLabelText;
  final String minuteLabelText;
  final String hour12LabelText;
  final String hour24LabelText;
  final String timeHint;
  final String removeSlotLabel;
  final String Function(String fieldLabel) requiredFieldMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (readOnly) {
      if (slot.start == null || slot.end == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.xs),
        child: Text('${slot.start!.format24()}-${slot.end!.format24()}'),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: AppTimeField(
              value: slot.start,
              labelText: startTimeLabel,
              hintText: timeHint,
              hourLabelText: hourLabelText,
              minuteLabelText: minuteLabelText,
              hour12LabelText: hour12LabelText,
              hour24LabelText: hour24LabelText,
              pickerButtonLabel: pickerButtonLabel,
              invalidTimeMessage: invalidTimeMessage,
              isRequired: true,
              validator: AppValidators.requiredValue<AppTimeValue>(
                requiredFieldMessage(startTimeLabel),
              ),
              onChanged: (AppTimeValue? value) {
                slot.start = value;
                onChanged();
              },
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: AppTimeField(
              value: slot.end,
              labelText: endTimeLabel,
              hintText: timeHint,
              hourLabelText: hourLabelText,
              minuteLabelText: minuteLabelText,
              hour12LabelText: hour12LabelText,
              hour24LabelText: hour24LabelText,
              pickerButtonLabel: pickerButtonLabel,
              invalidTimeMessage: invalidTimeMessage,
              isRequired: true,
              validator: AppValidators.requiredValue<AppTimeValue>(
                requiredFieldMessage(endTimeLabel),
              ),
              onChanged: (AppTimeValue? value) {
                slot.end = value;
                onChanged();
              },
            ),
          ),
          if (canRemove) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.remove_circle_outline,
              label: removeSlotLabel,
              semanticLabel: removeSlotLabel,
              tooltip: removeSlotLabel,
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}
