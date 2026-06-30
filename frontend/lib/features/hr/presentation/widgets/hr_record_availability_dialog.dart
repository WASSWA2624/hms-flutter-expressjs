import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Monday-first display order; values match API `day_of_week` (0 = Sunday).
const List<int> kAvailabilityWeekDayOrder = <int>[1, 2, 3, 4, 5, 6, 0];

/// Global entry point for recording a staff member's weekly availability.
Future<void> showHrRecordAvailabilityDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  await controller.ensureAssignmentReferenceData();

  final HrReferenceData referenceData =
      ref
          .read(hrWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (HrWorkspaceState state) => state.referenceData,
            failure: (_) => const HrReferenceData(),
          ) ??
      const HrReferenceData();

  final String? currentStaffId =
      ref
          .read(hrWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (HrWorkspaceState state) =>
                state.selectedStaff?.profile.effectiveId,
            failure: (_) => null,
          );

  final GlobalKey<_HrRecordAvailabilityFieldsState> fieldsKey =
      GlobalKey<_HrRecordAvailabilityFieldsState>();

  if (!context.mounted) {
    return;
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAvailabilityDialogTitle),
    icon: const Icon(Icons.schedule_outlined),
    submitLabel: l10n.hrRecordAvailabilityAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    maxWidth: 720,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _, [
      AppFailure? failure,
    ]) {
      return _HrRecordAvailabilityFields(
        key: fieldsKey,
        referenceData: referenceData,
        currentStaffId: currentStaffId,
        onLoadStaffSchedule: controller.loadStaffAvailabilities,
      );
    },
    onSubmit: () {
      final _HrRecordAvailabilityFieldsState? state = fieldsKey.currentState;
      final String? validationError = state?.validateSchedule(context.l10n);
      if (validationError != null) {
        return Future<AppFailure?>.value(
          AppFailure.validation(detailMessage: validationError),
        );
      }
      return controller.createAvailabilitySchedule(
        state?.toBatchPayload() ?? const <String, Object?>{},
      );
    },
  );

  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

class _HrRecordAvailabilityFields extends StatefulWidget {
  const _HrRecordAvailabilityFields({
    required this.referenceData,
    required this.onLoadStaffSchedule,
    this.currentStaffId,
    super.key,
  });

  final HrReferenceData referenceData;
  final String? currentStaffId;
  final Future<Result<List<HrStaffAvailability>>> Function(String staffProfileId)
  onLoadStaffSchedule;

  @override
  State<_HrRecordAvailabilityFields> createState() =>
      _HrRecordAvailabilityFieldsState();
}

class _HrRecordAvailabilityFieldsState
    extends State<_HrRecordAvailabilityFields> {
  late final Map<int, _DayScheduleDraft> _days = <int, _DayScheduleDraft>{
    for (final int day in kAvailabilityWeekDayOrder) day: _DayScheduleDraft(),
  };

  String? _preference = 'AVAILABLE';
  DateTime? _effectiveFrom = DateTime.now();
  DateTime? _effectiveTo;
  String? _copyFromStaffId;
  bool _isLoadingCopy = false;

  @override
  void dispose() {
    for (final _DayScheduleDraft day in _days.values) {
      day.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> toBatchPayload() {
    final List<Map<String, Object?>> days = <Map<String, Object?>>[];
    for (final int day in kAvailabilityWeekDayOrder) {
      final List<Map<String, Object?>> slots = _days[day]!.toSlotPayloads();
      if (slots.isEmpty) {
        continue;
      }
      days.add(<String, Object?>{
        'day_of_week': day,
        'time_slots': slots,
      });
    }

    return <String, Object?>{
      'preference': _preference,
      'status': _preference,
      'effective_from': _datePayload(_effectiveFrom),
      'effective_to': _datePayload(_effectiveTo),
      'days': days,
    };
  }

  String? validateSchedule(AppLocalizations l10n) {
    if (_effectiveFrom == null) {
      return l10n.hrFieldRequiredLabel(l10n.hrEffectiveFromLabel);
    }

    var scheduledDayCount = 0;
    for (final int day in kAvailabilityWeekDayOrder) {
      final _DayScheduleDraft schedule = _days[day]!;
      final List<_AvailabilitySlotDraft> filledSlots = schedule.filledSlots;
      if (filledSlots.isEmpty) {
        continue;
      }
      scheduledDayCount += 1;

      for (final _AvailabilitySlotDraft slot in filledSlots) {
        if (!_isEndAfterStart(slot.start, slot.end)) {
          return l10n.hrAvailabilityEndAfterStartError;
        }
      }

      if (_slotsOverlap(filledSlots)) {
        return l10n.hrAvailabilitySlotOverlapError;
      }
    }

    if (scheduledDayCount == 0) {
      return l10n.hrAvailabilityNoDaysSelectedError;
    }

    return null;
  }

  Future<void> _copyFromStaff(String? staffProfileId) async {
    final String sourceId = staffProfileId?.trim() ?? '';
    if (sourceId.isEmpty) {
      return;
    }

    setState(() => _isLoadingCopy = true);
    final Result<List<HrStaffAvailability>> result =
        await widget.onLoadStaffSchedule(sourceId);
    if (!mounted) {
      return;
    }

    setState(() => _isLoadingCopy = false);

    result.when(
      success: (List<HrStaffAvailability> availabilities) {
        _applyCopiedSchedule(_activeAvailabilitiesByDay(availabilities));
      },
      failure: (_) {},
    );
  }

  void _applyCopiedSchedule(Map<int, List<HrAvailabilitySlot>> slotsByDay) {
    setState(() {
      for (final int day in kAvailabilityWeekDayOrder) {
        _days[day]!.replaceSlots(slotsByDay[day] ?? const <HrAvailabilitySlot>[]);
      }
    });
  }

  Map<int, List<HrAvailabilitySlot>> _activeAvailabilitiesByDay(
    List<HrStaffAvailability> availabilities,
  ) {
    final DateTime today = DateTime.now();
    final DateTime todayDate = DateTime(today.year, today.month, today.day);

    bool isActive(HrStaffAvailability item) {
      final DateTime? from = item.effectiveFrom;
      if (from != null) {
        final DateTime fromDate = DateTime(from.year, from.month, from.day);
        if (fromDate.isAfter(todayDate)) {
          return false;
        }
      }
      final DateTime? to = item.effectiveTo;
      if (to != null) {
        final DateTime toDate = DateTime(to.year, to.month, to.day);
        if (toDate.isBefore(todayDate)) {
          return false;
        }
      }
      return true;
    }

    final Map<int, HrStaffAvailability> latestByDay = <int, HrStaffAvailability>{};
    for (final HrStaffAvailability item in availabilities) {
      final int? day = item.dayOfWeek;
      if (day == null || !isActive(item)) {
        continue;
      }
      final HrStaffAvailability? existing = latestByDay[day];
      if (existing == null) {
        latestByDay[day] = item;
        continue;
      }
      final DateTime? existingFrom = existing.effectiveFrom;
      final DateTime? itemFrom = item.effectiveFrom;
      if (itemFrom != null &&
          (existingFrom == null || itemFrom.isAfter(existingFrom))) {
        latestByDay[day] = item;
      }
    }

    return <int, List<HrAvailabilitySlot>>{
      for (final MapEntry<int, HrStaffAvailability> entry in latestByDay.entries)
        entry.key: _slotsForAvailability(entry.value),
    };
  }

  List<HrAvailabilitySlot> _slotsForAvailability(HrStaffAvailability item) {
    if (item.timeSlots.isNotEmpty) {
      return item.timeSlots;
    }
    final String? start = item.startTime?.trim();
    final String? end = item.endTime?.trim();
    if (start != null &&
        start.isNotEmpty &&
        end != null &&
        end.isNotEmpty) {
      return <HrAvailabilitySlot>[
        HrAvailabilitySlot(startTime: start, endTime: end),
      ];
    }
    return const <HrAvailabilitySlot>[];
  }

  Future<void> _showDuplicateDialog(int sourceDay) async {
    final AppLocalizations l10n = context.l10n;
    final Set<int> selectedDays = <int>{};

    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AppDialog(
              title: Text(l10n.hrAvailabilityDuplicateToDialogTitle),
              icon: const Icon(Icons.content_copy_outlined),
              scrollable: true,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.hrAvailabilityDuplicateToDialogDescription(
                      hrDayLabel(l10n, sourceDay),
                    ),
                  ),
                  SizedBox(height: Theme.of(context).spacing.md),
                  for (final int day in kAvailabilityWeekDayOrder)
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
                AppButton.tertiary(
                  label: l10n.commonCancelActionLabel,
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                AppButton.primary(
                  label: l10n.hrAvailabilityDuplicateToAction,
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

    if (confirmed != true || !mounted) {
      return;
    }

    final List<HrAvailabilitySlot> sourceSlots =
        _days[sourceDay]!.toEntitySlots();
    setState(() {
      for (final int day in selectedDays) {
        _days[day]!.replaceSlots(sourceSlots);
      }
    });
  }

  List<AppSelectOption<String>> get _staffOptions {
    final String? currentId = widget.currentStaffId?.trim();
    return <AppSelectOption<String>>[
      for (final HrOption option in widget.referenceData.staffProfiles)
        if (currentId == null || option.value != currentId)
          AppSelectOption<String>(value: option.value, label: option.label),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppFormSection(
      children: <Widget>[
        if (_staffOptions.isNotEmpty) ...<Widget>[
          AppSelectField<String>.searchable(
            value: _copyFromStaffId,
            labelText: l10n.hrAvailabilityCopyFromStaffLabel,
            options: _staffOptions,
            enabled: !_isLoadingCopy,
            onChanged: (String? value) {
              setState(() => _copyFromStaffId = value);
              if (value != null) {
                _copyFromStaff(value);
              }
            },
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.secondary(
              label: l10n.hrAvailabilityCopyFromStaffAction,
              leadingIcon: Icons.person_search_outlined,
              isLoading: _isLoadingCopy,
              enabled: _copyFromStaffId != null && !_isLoadingCopy,
              onPressed: _copyFromStaffId == null
                  ? null
                  : () => _copyFromStaff(_copyFromStaffId),
            ),
          ),
          SizedBox(height: theme.spacing.sm),
        ],
        Text(
          l10n.hrAvailabilityWeekScheduleTitle,
          style: theme.textTheme.titleSmall,
        ),
        SizedBox(height: theme.spacing.xs),
        for (final int day in kAvailabilityWeekDayOrder)
          _DayScheduleSection(
            day: day,
            dayLabel: hrDayLabel(l10n, day),
            schedule: _days[day]!,
            onChanged: () => setState(() {}),
            onDuplicate: () => _showDuplicateDialog(day),
            duplicateLabel: l10n.hrAvailabilityDuplicateToAction,
            addSlotLabel: l10n.hrAddAvailabilitySlotAction,
            removeSlotLabel: l10n.hrRemoveAvailabilitySlotAction,
            startTimeLabel: l10n.hrStartTimeLabel,
            endTimeLabel: l10n.hrEndTimeLabel,
            timeHint: l10n.hrTimeHint,
            requiredFieldMessage: l10n.hrFieldRequiredLabel,
          ),
        AppSelectField<String>(
          value: _preference,
          labelText: l10n.hrAvailabilityPreferenceLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'PREFERRED',
              label: l10n.hrAvailabilityPreferred,
            ),
            AppSelectOption<String>(
              value: 'AVAILABLE',
              label: l10n.hrAvailabilityAvailable,
            ),
            AppSelectOption<String>(
              value: 'UNAVAILABLE',
              label: l10n.hrAvailabilityUnavailable,
            ),
          ],
          onChanged: (String? value) => setState(() => _preference = value),
        ),
        AppDateField(
          value: _effectiveFrom,
          labelText: l10n.hrEffectiveFromLabel,
          isRequired: true,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) =>
              setState(() => _effectiveFrom = value),
        ),
        AppDateField(
          value: _effectiveTo,
          labelText: l10n.hrEffectiveToLabel,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _effectiveTo = value),
        ),
      ],
    );
  }
}

class _DayScheduleSection extends StatelessWidget {
  const _DayScheduleSection({
    required this.day,
    required this.dayLabel,
    required this.schedule,
    required this.onChanged,
    required this.onDuplicate,
    required this.duplicateLabel,
    required this.addSlotLabel,
    required this.removeSlotLabel,
    required this.startTimeLabel,
    required this.endTimeLabel,
    required this.timeHint,
    required this.requiredFieldMessage,
  });

  final int day;
  final String dayLabel;
  final _DayScheduleDraft schedule;
  final VoidCallback onChanged;
  final VoidCallback onDuplicate;
  final String duplicateLabel;
  final String addSlotLabel;
  final String removeSlotLabel;
  final String startTimeLabel;
  final String endTimeLabel;
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
                      (_AvailabilitySlotDraft slot) =>
                          '${slot.start.trim()}-${slot.end.trim()}',
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
                if (schedule.filledSlots.isNotEmpty)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton.secondary(
                      label: duplicateLabel,
                      leadingIcon: Icons.content_copy_outlined,
                      onPressed: onDuplicate,
                    ),
                  ),
                for (var index = 0; index < schedule.slots.length; index += 1)
                  _AvailabilitySlotFields(
                    slot: schedule.slots[index],
                    canRemove: schedule.slots.length > 1,
                    startTimeLabel: startTimeLabel,
                    endTimeLabel: endTimeLabel,
                    timeHint: timeHint,
                    removeSlotLabel: removeSlotLabel,
                    requiredFieldMessage: requiredFieldMessage,
                    onRemove: () {
                      schedule.removeSlotAt(index);
                      onChanged();
                    },
                  ),
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

final class _DayScheduleDraft {
  _DayScheduleDraft() : slots = <_AvailabilitySlotDraft>[_AvailabilitySlotDraft()];

  final List<_AvailabilitySlotDraft> slots;

  List<_AvailabilitySlotDraft> get filledSlots => <_AvailabilitySlotDraft>[
    for (final _AvailabilitySlotDraft slot in slots)
      if (slot.start.trim().isNotEmpty && slot.end.trim().isNotEmpty) slot,
  ];

  void addSlot() => slots.add(_AvailabilitySlotDraft());

  void removeSlotAt(int index) {
    final _AvailabilitySlotDraft removed = slots.removeAt(index);
    removed.dispose();
  }

  List<Map<String, Object?>> toSlotPayloads() => <Map<String, Object?>>[
    for (final _AvailabilitySlotDraft slot in filledSlots)
      <String, Object?>{
        'start_time': slot.start.trim(),
        'end_time': slot.end.trim(),
      },
  ];

  List<HrAvailabilitySlot> toEntitySlots() => <HrAvailabilitySlot>[
    for (final _AvailabilitySlotDraft slot in filledSlots)
      HrAvailabilitySlot(startTime: slot.start.trim(), endTime: slot.end.trim()),
  ];

  void replaceSlots(List<HrAvailabilitySlot> source) {
    for (final _AvailabilitySlotDraft slot in slots) {
      slot.dispose();
    }
    slots.clear();
    if (source.isEmpty) {
      slots.add(_AvailabilitySlotDraft());
      return;
    }
    for (final HrAvailabilitySlot slot in source) {
      final _AvailabilitySlotDraft draft = _AvailabilitySlotDraft();
      draft.startController.text = slot.startTime;
      draft.endController.text = slot.endTime;
      slots.add(draft);
    }
  }

  void dispose() {
    for (final _AvailabilitySlotDraft slot in slots) {
      slot.dispose();
    }
  }
}

final class _AvailabilitySlotDraft {
  _AvailabilitySlotDraft();

  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

  String get start => startController.text;
  String get end => endController.text;

  void dispose() {
    startController.dispose();
    endController.dispose();
  }
}

class _AvailabilitySlotFields extends StatelessWidget {
  const _AvailabilitySlotFields({
    required this.slot,
    required this.canRemove,
    required this.onRemove,
    required this.startTimeLabel,
    required this.endTimeLabel,
    required this.timeHint,
    required this.removeSlotLabel,
    required this.requiredFieldMessage,
  });

  final _AvailabilitySlotDraft slot;
  final bool canRemove;
  final VoidCallback onRemove;
  final String startTimeLabel;
  final String endTimeLabel;
  final String timeHint;
  final String removeSlotLabel;
  final String Function(String fieldLabel) requiredFieldMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: AppTextField(
              controller: slot.startController,
              labelText: startTimeLabel,
              hintText: timeHint,
              isRequired: true,
              validator: AppValidators.requiredText(
                requiredFieldMessage(startTimeLabel),
              ),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: AppTextField(
              controller: slot.endController,
              labelText: endTimeLabel,
              hintText: timeHint,
              isRequired: true,
              validator: AppValidators.requiredText(
                requiredFieldMessage(endTimeLabel),
              ),
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

String? _datePayload(DateTime? value) {
  if (value == null) {
    return null;
  }
  return DateTime(value.year, value.month, value.day).toUtc().toIso8601String();
}

bool _isEndAfterStart(String start, String end) {
  return _timeToMinutes(end) > _timeToMinutes(start);
}

int _timeToMinutes(String raw) {
  final List<String> parts = raw.trim().split(':');
  if (parts.length < 2) {
    return 0;
  }
  final int hours = int.tryParse(parts[0]) ?? 0;
  final int minutes = int.tryParse(parts[1]) ?? 0;
  return hours * 60 + minutes;
}

bool _slotsOverlap(List<_AvailabilitySlotDraft> slots) {
  final List<List<int>> ranges = <List<int>>[
    for (final _AvailabilitySlotDraft slot in slots)
      <int>[_timeToMinutes(slot.start), _timeToMinutes(slot.end)],
  ]..sort((List<int> a, List<int> b) => a[0].compareTo(b[0]));

  for (var index = 1; index < ranges.length; index += 1) {
    if (ranges[index][0] < ranges[index - 1][1]) {
      return true;
    }
  }
  return false;
}
