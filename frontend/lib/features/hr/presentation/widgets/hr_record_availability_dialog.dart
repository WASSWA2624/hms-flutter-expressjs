import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

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
    initialMaximized: true,
    maxWidth: 980,
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
  late final HrWeeklyScheduleDraft _schedule = HrWeeklyScheduleDraft(
    weekdayDefaults: true,
  );

  String? _preference = 'AVAILABLE';
  DateTime? _effectiveFrom = DateTime.now();
  DateTime? _effectiveTo;
  String? _copyFromStaffId;
  bool _isLoadingCopy = false;

  @override
  void dispose() {
    _schedule.dispose();
    super.dispose();
  }

  Map<String, Object?> toBatchPayload() {
    return <String, Object?>{
      'preference': _preference,
      'status': _preference,
      'effective_from': _datePayload(_effectiveFrom),
      'effective_to': _datePayload(_effectiveTo),
      'days': _schedule.toAvailabilityDaysPayload(),
    };
  }

  String? validateSchedule(AppLocalizations l10n) {
    if (_effectiveFrom == null) {
      return l10n.hrFieldRequiredLabel(l10n.hrEffectiveFromLabel);
    }
    return _schedule.validate(l10n);
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
        setState(() {
          _schedule.applyEntitySlotsByDay(
            _activeAvailabilitiesByDay(availabilities),
          );
        });
      },
      failure: (_) {},
    );
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
        HrWeeklyScheduleEditor(
          schedule: _schedule,
          onChanged: () => setState(() {}),
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

String? _datePayload(DateTime? value) {
  if (value == null) {
    return null;
  }
  return DateTime(value.year, value.month, value.day).toUtc().toIso8601String();
}
