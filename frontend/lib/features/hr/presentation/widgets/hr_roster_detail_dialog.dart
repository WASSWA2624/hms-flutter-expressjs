import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_calendar_preview.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

const Map<int, String> _kWeekdayCodes = <int, String>{
  DateTime.monday: 'MON',
  DateTime.tuesday: 'TUE',
  DateTime.wednesday: 'WED',
  DateTime.thursday: 'THU',
  DateTime.friday: 'FRI',
  DateTime.saturday: 'SAT',
  DateTime.sunday: 'SUN',
};

String _rosterStatusLabel(AppLocalizations l10n, String? status) {
  switch ((status ?? '').trim().toUpperCase()) {
    case 'PUBLISHED':
      return l10n.hrRosterStatusCompleted;
    case 'DRAFT':
      return l10n.hrRosterStatusDraft;
    case 'DELETED':
      return l10n.hrRosterStatusDeleted;
    default:
      return (status ?? '').trim().isEmpty
          ? l10n.profileUnknownValue
          : status!;
  }
}

Future<void> showHrRosterDetailDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final String rosterId = item.rosterId ?? item.effectiveId;

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return FutureBuilder<Result<Map<String, Object?>>>(
        future: controller.getRoster(rosterId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Result<Map<String, Object?>>> snapshot,
            ) {
              final Result<Map<String, Object?>>? result = snapshot.data;
              final Map<String, Object?>? roster = result?.when(
                success: (Map<String, Object?> value) => value,
                failure: (_) => null,
              );
              final AppFailure? failure = result?.when(
                success: (_) => null,
                failure: (AppFailure value) => value,
              );

              return _HrRosterDetailShell(
                item: item,
                roster: roster,
                failure: failure,
                isLoading: snapshot.connectionState != ConnectionState.done,
              );
            },
      );
    },
  );
}

/// Opens roster detail by roster id (e.g. from staff detail).
Future<void> showHrRosterDetailByIdDialog(
  BuildContext context,
  WidgetRef ref, {
  required String rosterId,
  String? rosterName,
  String? status,
}) {
  return showHrRosterDetailDialog(
    context,
    ref,
    HrWorkItem(
      id: rosterId,
      queue: HrQueue.rosterDrafts,
      displayId: rosterId,
      rosterId: rosterId,
      rosterName: rosterName,
      status: status,
    ),
  );
}

@immutable
final class _RosterStaffRow {
  const _RosterStaffRow({
    required this.staffProfileId,
    this.displayId,
    this.name,
    this.staffNumber,
    this.position,
    this.practitionerType,
    this.staffCategory,
    this.source,
  });

  factory _RosterStaffRow.fromJson(Map<String, Object?> json) {
    return _RosterStaffRow(
      staffProfileId: (json['staff_profile_id'] ?? '').toString(),
      displayId: json['display_id']?.toString(),
      name: json['name']?.toString(),
      staffNumber: json['staff_number']?.toString(),
      position: json['position']?.toString(),
      practitionerType: json['practitioner_type']?.toString(),
      staffCategory: json['staff_category']?.toString(),
      source: json['source']?.toString(),
    );
  }

  final String staffProfileId;
  final String? displayId;
  final String? name;
  final String? staffNumber;
  final String? position;
  final String? practitionerType;
  final String? staffCategory;
  final String? source;

  String get title =>
      (name ?? staffNumber ?? displayId ?? staffProfileId).trim();
}

class _HrRosterDetailShell extends ConsumerStatefulWidget {
  const _HrRosterDetailShell({
    required this.item,
    required this.roster,
    required this.failure,
    required this.isLoading,
  });

  final HrWorkItem item;
  final Map<String, Object?>? roster;
  final AppFailure? failure;
  final bool isLoading;

  @override
  ConsumerState<_HrRosterDetailShell> createState() =>
      _HrRosterDetailShellState();
}

class _HrRosterDetailShellState extends ConsumerState<_HrRosterDetailShell> {
  Map<String, Object?>? _roster;
  bool _busy = false;
  final Set<String> _selectedStaffIds = <String>{};
  final TextEditingController _staffSearchController = TextEditingController();
  String _staffSearchQuery = '';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _roster = widget.roster;
  }

  @override
  void didUpdateWidget(covariant _HrRosterDetailShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roster != null) {
      _roster = widget.roster;
    }
  }

  @override
  void dispose() {
    _staffSearchController.dispose();
    super.dispose();
  }

  String get _rosterId =>
      widget.item.rosterId ??
      (_roster?['human_friendly_id'] ?? widget.item.effectiveId).toString();

  List<_RosterStaffRow> get _staffRows {
    final Object? raw = _roster?['staff'];
    if (raw is! List) {
      return const <_RosterStaffRow>[];
    }
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(
          (Map<Object?, Object?> item) =>
              _RosterStaffRow.fromJson(Map<String, Object?>.from(item)),
        )
        .where((row) => row.staffProfileId.isNotEmpty)
        .toList(growable: false);
  }

  List<_RosterStaffRow> get _visibleStaff {
    final String needle = _staffSearchQuery.trim().toLowerCase();
    return _staffRows.where((_RosterStaffRow row) {
      if (_categoryFilter != null &&
          (_rowCategory(row) != _categoryFilter)) {
        return false;
      }
      if (needle.isEmpty) {
        return true;
      }
      return <String?>[
        row.name,
        row.staffNumber,
        row.displayId,
        row.position,
        row.practitionerType,
        row.staffCategory,
        row.source,
      ].whereType<String>().any(
        (String value) => value.toLowerCase().contains(needle),
      );
    }).toList(growable: false);
  }

  String? _rowCategory(_RosterStaffRow row) {
    final String raw = (row.staffCategory ?? '').trim().toUpperCase();
    return raw.isEmpty ? null : raw;
  }

  String _informativeName(AppLocalizations l10n) {
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    final String rawName = (roster['name'] ?? widget.item.rosterName ?? '')
        .toString()
        .trim();
    final String period =
        (roster['period_label'] ?? widget.item.periodLabel ?? '').toString();
    final bool looksLikeDates =
        rawName.isEmpty ||
        RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(rawName) ||
        rawName == period;
    if (!looksLikeDates) {
      return rawName;
    }
    final String scope =
        (roster['department_name'] ??
                roster['facility_name'] ??
                '')
            .toString()
            .trim();
    final String status = _rosterStatusLabel(
      l10n,
      _isDeleted
          ? 'DELETED'
          : (roster['status'] ?? widget.item.status)?.toString(),
    );
    return <String?>[
      scope.isEmpty ? null : scope,
      period.isEmpty ? null : period,
      status,
    ].whereType<String>().join(' · ').ifEmpty(l10n.hrRosterDraftTitle);
  }

  Future<void> _reloadRoster() async {
    final Result<Map<String, Object?>> result = await ref
        .read(hrWorkspaceControllerProvider.notifier)
        .getRoster(_rosterId);
    if (!mounted) {
      return;
    }
    result.when(
      success: (Map<String, Object?> value) {
        setState(() {
          _roster = value;
          _selectedStaffIds.removeWhere(
            (String id) =>
                !_staffRows.any((row) => row.staffProfileId == id),
          );
        });
      },
      failure: (AppFailure failure) => showHrMutationSnackBar(context, failure),
    );
  }

  Future<void> _showPeriodDetails(HrRosterPeriodDetails details) async {
    await showHrRosterPeriodDetailsDialog(context, details: details);
  }

  Future<void> _addStaff() async {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceState? state = readHrWorkspaceState(ref);
    String? staffProfileId;
    String? staffCategory = 'FULL_TIME';
    final bool? saved = await showAppWorkspaceMutationDialog(
      context: context,
      title: Text(l10n.hrRosterAddStaffAction),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      submitLabel: l10n.hrRosterAddStaffAction,
      cancelLabel: l10n.commonCancelActionLabel,
      submitIcon: Icons.person_add_alt_1_outlined,
      buildFields:
          (
            BuildContext context,
            GlobalKey<FormState> formKey,
            bool _, [
            AppFailure? failure,
          ]) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setLocal) {
                return AppFormSection(
                  children: <Widget>[
                    AppSelectField<String>.searchable(
                      value: staffProfileId,
                      labelText: l10n.hrRosterSelectStaffLabel,
                      isRequired: true,
                      options: hrSelectOptions(
                        state?.referenceData.staffProfiles ??
                            const <HrOption>[],
                      ),
                      validator: AppValidators.requiredValue(
                        l10n.hrFieldRequiredLabel(
                          l10n.hrRosterSelectStaffLabel,
                        ),
                      ),
                      onChanged: (String? value) =>
                          setLocal(() => staffProfileId = value),
                    ),
                    AppSelectField<String>(
                      value: staffCategory,
                      labelText: l10n.hrRosterStaffCategoryLabel,
                      options: _staffCategoryOptions(l10n),
                      onChanged: (String? value) {
                        if (value != null) {
                          setLocal(() => staffCategory = value);
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
      onSubmit: () async {
        if (staffProfileId == null || staffProfileId!.isEmpty) {
          return AppFailure.validation();
        }
        setState(() => _busy = true);
        final Result<Map<String, Object?>> result = await ref
            .read(hrWorkspaceControllerProvider.notifier)
            .attachRosterStaff(
              rosterId: _rosterId,
              staffProfileId: staffProfileId!,
              staffCategory: staffCategory,
            );
        setState(() => _busy = false);
        return result.when(
          success: (Map<String, Object?> value) {
            setState(() => _roster = value);
            return null;
          },
          failure: (AppFailure failure) => failure,
        );
      },
    );
    if (saved == true && mounted) {
      showHrMutationSnackBar(context, null);
    }
  }

  Future<void> _removeStaff(String staffProfileId) async {
    setState(() => _busy = true);
    final Result<Map<String, Object?>> result = await ref
        .read(hrWorkspaceControllerProvider.notifier)
        .detachRosterStaff(rosterId: _rosterId, staffProfileId: staffProfileId);
    setState(() => _busy = false);
    result.when(
      success: (Map<String, Object?> value) {
        setState(() {
          _roster = value;
          _selectedStaffIds.remove(staffProfileId);
        });
        showHrMutationSnackBar(context, null);
      },
      failure: (AppFailure failure) => showHrMutationSnackBar(context, failure),
    );
  }

  Future<void> _removeSelected() async {
    if (_selectedStaffIds.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    AppFailure? failure;
    for (final String id in _selectedStaffIds.toList(growable: false)) {
      final Result<Map<String, Object?>> result = await ref
          .read(hrWorkspaceControllerProvider.notifier)
          .detachRosterStaff(rosterId: _rosterId, staffProfileId: id);
      final AppFailure? next = result.when(
        success: (Map<String, Object?> value) {
          _roster = value;
          return null;
        },
        failure: (AppFailure value) => value,
      );
      if (next != null) {
        failure = next;
        break;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _selectedStaffIds.clear();
    });
    showHrMutationSnackBar(context, failure);
  }

  bool get _isDeleted {
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    if (roster['deleted_at'] != null) {
      return true;
    }
    if (roster['is_deleted'] == true) {
      return true;
    }
    final String status =
        (roster['status'] ?? widget.item.status ?? '').toString().toUpperCase();
    return status == 'DELETED';
  }

  Future<void> _deleteRoster() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppConfirmActionDialog(
          title: l10n.hrRosterDeleteConfirmTitle,
          body: l10n.hrRosterDeleteConfirmMessage,
          submitLabel: l10n.hrRosterDeleteAction,
          destructive: true,
          submitLeadingIcon: Icons.delete_outline,
          onConfirm: () async {
            setState(() => _busy = true);
            final AppFailure? failure = await ref
                .read(hrWorkspaceControllerProvider.notifier)
                .deleteRoster(_rosterId);
            if (!mounted) {
              return failure;
            }
            setState(() => _busy = false);
            if (failure == null) {
              showHrMutationSnackBar(context, null);
              await Navigator.of(context).maybePop();
            }
            return failure;
          },
        );
      },
    );
    if (confirmed == true && mounted && _busy) {
      setState(() => _busy = false);
    }
  }

  Future<void> _restoreRoster() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppConfirmActionDialog(
          title: l10n.hrRosterRestoreConfirmTitle,
          body: l10n.hrRosterRestoreConfirmMessage,
          submitLabel: l10n.hrRosterRestoreAction,
          submitLeadingIcon: Icons.restore_outlined,
          onConfirm: () async {
            setState(() => _busy = true);
            final AppFailure? failure = await ref
                .read(hrWorkspaceControllerProvider.notifier)
                .restoreRoster(_rosterId);
            if (!mounted) {
              return failure;
            }
            setState(() => _busy = false);
            if (failure == null) {
              showHrMutationSnackBar(context, null);
              await _reloadRoster();
            }
            return failure;
          },
        );
      },
    );
    if (confirmed == true && mounted && _busy) {
      setState(() => _busy = false);
    }
  }

  Future<void> _permanentDeleteRoster() async {
    final AppLocalizations l10n = context.l10n;
    final String confirmName = _informativeName(l10n);
    final String? typed = await showAppDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppTextInputActionDialog(
          title: l10n.hrRosterPermanentDeleteConfirmTitle,
          description: l10n.hrRosterPermanentDeleteConfirmMessage,
          fieldLabel: l10n.tenantFacilityPermanentDeleteConfirmFieldLabel(
            confirmName,
          ),
          submitLabel: l10n.hrRosterPermanentDeleteAction,
          cancelLabel: l10n.commonCancelActionLabel,
          requiredMessage: l10n.validationRequired,
          confirmExactValue: confirmName,
          confirmMismatchMessage:
              l10n.tenantFacilityPermanentDeleteConfirmFieldLabel(confirmName),
          destructive: true,
          minLines: 1,
          maxLines: 1,
          icon: const Icon(Icons.delete_forever_outlined),
        );
      },
    );
    if (!mounted || typed == null) {
      return;
    }
    if (typed.trim().toLowerCase() != confirmName.trim().toLowerCase()) {
      return;
    }

    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppConfirmActionDialog(
          title: l10n.hrRosterPermanentDeleteConfirmTitle,
          body: l10n.hrRosterPermanentDeleteConfirmMessage,
          highlightedText: confirmName,
          submitLabel: l10n.hrRosterPermanentDeleteAction,
          destructive: true,
          submitLeadingIcon: Icons.delete_forever_outlined,
          onConfirm: () async {
            setState(() => _busy = true);
            final AppFailure? failure = await ref
                .read(hrWorkspaceControllerProvider.notifier)
                .permanentDeleteRoster(_rosterId);
            if (!mounted) {
              return failure;
            }
            setState(() => _busy = false);
            if (failure == null) {
              showHrMutationSnackBar(context, null);
              await Navigator.of(context).maybePop();
            }
            return failure;
          },
        );
      },
    );
    if (confirmed == true && mounted && _busy) {
      setState(() => _busy = false);
    }
  }

  Future<void> _editRoster() async {
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    final HrRosterTemplateDialogResult editResult = await showHrEditRosterDialog(
      context,
      ref,
      rosterId: _rosterId,
      roster: roster,
    );
    if (!mounted) {
      return;
    }
    if (editResult.usedExisting != null) {
      Navigator.of(context).pop();
      await showHrRosterDetailByIdDialog(
        context,
        ref,
        rosterId: editResult.usedExisting!.id,
        rosterName: editResult.usedExisting!.name,
        status: editResult.usedExisting!.status,
      );
      return;
    }
    if (!editResult.saved) {
      return;
    }
    await _reloadRoster();
  }

  Future<void> _printRoster() async {
    final AppLocalizations l10n = context.l10n;
    final HrRosterPrintOptionsController options =
        HrRosterPrintOptionsController();

    String buildBodyHtml() => _buildPrintHtml(l10n, options.selectedSections);

    try {
      if (!mounted) {
        return;
      }
      await PrintDocumentTemplates.registry(
        ref: ref,
        context: context,
        title: _informativeName(l10n),
        subtitle: _rosterId,
        bodyHtml: buildBodyHtml(),
        bodyHtmlBuilder: buildBodyHtml,
        previewDialogTitle: l10n.hrRosterPrintDialogTitle,
        previewSectionsExtra: HrRosterPrintOptionsSection(controller: options),
        previewDocumentRevision: options,
        isPrintEnabled: () => options.canPrint,
      );
    } finally {
      options.dispose();
    }
  }

  String _buildPrintHtml(
    AppLocalizations l10n,
    Set<HrRosterPrintSection> sections,
  ) {
    final StringBuffer buffer = StringBuffer();
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    if (sections.contains(HrRosterPrintSection.overview)) {
      buffer.writeln(
        '<h2>${hrRosterEscapeHtml(l10n.hrRosterOverviewSectionTitle)}</h2>',
      );
      buffer.writeln(
        '<table style="width:100%;border-collapse:collapse;margin:0 0 16px;font-size:12px;">'
        '<tbody>',
      );
      void row(String label, String value) {
        buffer.writeln(
          '<tr>'
          '<td style="padding:8px 10px;width:34%;color:#546E7A;border-bottom:1px solid #ECEFF1;">${hrRosterEscapeHtml(label)}</td>'
          '<td style="padding:8px 10px;border-bottom:1px solid #ECEFF1;font-weight:600;">${hrRosterEscapeHtml(value)}</td>'
          '</tr>',
        );
      }

      row(l10n.hrRosterOverviewNameLabel, _informativeName(l10n));
      row(l10n.hrRosterOverviewIdLabel, _rosterId);
      row(
        l10n.hrRosterOverviewPeriodLabel,
        (roster['period_label'] ?? widget.item.periodLabel ?? '').toString(),
      );
      row(
        l10n.hrRosterOverviewStatusLabel,
        _rosterStatusLabel(l10n, roster['status']?.toString()),
      );
      row(
        l10n.hrRosterRecurringLabel,
        roster['is_recurring'] == true
            ? l10n.commonYesLabel
            : l10n.commonNoLabel,
      );
      row(
        l10n.hrRosterAttachedStaffTitle,
        _staffRows.length.toString(),
      );
      buffer.writeln('</tbody></table>');
    }
    if (sections.contains(HrRosterPrintSection.schedule)) {
      buffer.writeln(hrRosterPrintScheduleHtml(l10n, _previewDays()));
    }
    if (sections.contains(HrRosterPrintSection.staff)) {
      buffer.writeln(
        '<h2>${hrRosterEscapeHtml(l10n.hrRosterAttachedStaffTitle)}</h2>',
      );
      buffer.writeln(
        '<table style="width:100%;border-collapse:collapse;font-size:12px;">'
        '<thead><tr>'
        '<th style="text-align:left;padding:8px;border-bottom:2px solid #CFD8DC;">${hrRosterEscapeHtml(l10n.hrRosterNameLabel)}</th>'
        '<th style="text-align:left;padding:8px;border-bottom:2px solid #CFD8DC;">${hrRosterEscapeHtml(l10n.hrStaffNumberLabel)}</th>'
        '<th style="text-align:left;padding:8px;border-bottom:2px solid #CFD8DC;">${hrRosterEscapeHtml(l10n.hrPositionLabel)}</th>'
        '<th style="text-align:left;padding:8px;border-bottom:2px solid #CFD8DC;">${hrRosterEscapeHtml(l10n.hrRosterStaffCategoryLabel)}</th>'
        '</tr></thead><tbody>',
      );
      if (_staffRows.isEmpty) {
        buffer.writeln(
          '<tr><td colspan="4" style="padding:10px;color:#78909C;">${hrRosterEscapeHtml(l10n.hrRosterNoStaffLabel)}</td></tr>',
        );
      } else {
        for (final _RosterStaffRow row in _staffRows) {
          buffer.writeln(
            '<tr>'
            '<td style="padding:8px;border-bottom:1px solid #ECEFF1;">${hrRosterEscapeHtml(row.title)}</td>'
            '<td style="padding:8px;border-bottom:1px solid #ECEFF1;">${hrRosterEscapeHtml(row.staffNumber ?? row.displayId ?? '')}</td>'
            '<td style="padding:8px;border-bottom:1px solid #ECEFF1;">${hrRosterEscapeHtml(row.position ?? '')}</td>'
            '<td style="padding:8px;border-bottom:1px solid #ECEFF1;">${hrRosterEscapeHtml(_staffCategoryLabel(l10n, row.staffCategory))}</td>'
            '</tr>',
          );
        }
      }
      buffer.writeln('</tbody></table>');
    }
    return buffer.toString();
  }

  List<HrRosterDayPreview> _previewDays() {
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    final DateTime? start = _parseDate(roster['period_start']) ?? widget.item.startAt;
    final DateTime? end = _parseDate(roster['period_end']) ?? widget.item.endAt;
    if (start == null || end == null) {
      return const <HrRosterDayPreview>[];
    }
    final Map<String, Object?> constraints = _map(roster['constraints']);
    final Set<String> working = <String>{
      for (final Object? day in (constraints['working_days'] as List?) ??
          <Object?>['MON', 'TUE', 'WED', 'THU', 'FRI'])
        day.toString().toUpperCase(),
    };
    final Set<String> holidays = <String>{
      for (final Object? day
          in (constraints['public_holidays'] as List?) ?? const <Object?>[])
        day.toString(),
    };
    final bool respectHolidays = constraints['respect_public_holidays'] != false;
    final (int startHour, int startMinute) = _parseHourMinute(
      constraints['default_start_time']?.toString(),
      8,
      0,
    );
    final (int endHour, int endMinute) = _parseHourMinute(
      constraints['default_end_time']?.toString(),
      17,
      0,
    );
    final int dayStartMinutes = startHour * 60 + startMinute;
    final int dayEndMinutes = _dayEndMinutesSafe(
      dayStartMinutes,
      endHour * 60 + endMinute,
    );

    final Map<String, List<HrRosterShiftWindow>> shiftsByDay =
        <String, List<HrRosterShiftWindow>>{};
    for (final Object? shiftRaw
        in (roster['shifts'] as List?) ?? const <Object?>[]) {
      if (shiftRaw is! Map) {
        continue;
      }
      final Map<String, Object?> shift = Map<String, Object?>.from(shiftRaw);
      final DateTime? shiftStart = _parseDate(shift['start_time']);
      final DateTime? shiftEnd = _parseDate(shift['end_time']);
      if (shiftStart == null || shiftEnd == null) {
        continue;
      }
      final String key = hrRosterDateKey(shiftStart);
      final List<String> names = <String>[];
      for (final Object? assignmentRaw
          in (shift['assignments'] as List?) ?? const <Object?>[]) {
        if (assignmentRaw is! Map) {
          continue;
        }
        final Map<String, Object?> assignment = Map<String, Object?>.from(
          assignmentRaw,
        );
        final Map<String, Object?> profile = _map(assignment['staff_profile']);
        final Map<String, Object?> user = _map(profile['user']);
        final Map<String, Object?> userProfile = _map(user['profile']);
        final String name =
            <String?>[
                  userProfile['first_name']?.toString(),
                  userProfile['last_name']?.toString(),
                ]
                .whereType<String>()
                .where((String part) => part.trim().isNotEmpty)
                .join(' ')
                .ifEmpty(
                  profile['staff_number']?.toString() ??
                      profile['human_friendly_id']?.toString() ??
                      '',
                );
        if (name.isNotEmpty) {
          names.add(name);
        }
      }
      shiftsByDay
          .putIfAbsent(key, () => <HrRosterShiftWindow>[])
          .add(
            HrRosterShiftWindow(
              start: shiftStart,
              end: shiftEnd,
              staffNames: names,
              shiftType: shift['shift_type']?.toString(),
            ),
          );
    }

    final List<HrRosterDayPreview> days = <HrRosterDayPreview>[];
    DateTime cursor = DateTime(start.year, start.month, start.day);
    final DateTime last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      final String key = hrRosterDateKey(cursor);
      final String code = _kWeekdayCodes[cursor.weekday] ?? 'MON';
      final bool holiday = holidays.contains(key);
      final bool treatedAsHoliday = respectHolidays && holiday;
      final bool workingDay = working.contains(code);
      final List<HrRosterShiftWindow> dayShifts =
          List<HrRosterShiftWindow>.from(
            shiftsByDay[key] ?? const <HrRosterShiftWindow>[],
          )..sort(
            (HrRosterShiftWindow a, HrRosterShiftWindow b) =>
                a.start.compareTo(b.start),
          );
      days.add(
        HrRosterDayPreview(
          date: cursor,
          label: key,
          isHoliday: holiday,
          isWorkingDay: workingDay && !treatedAsHoliday,
          dayStartMinutes: dayStartMinutes,
          dayEndMinutes: dayEndMinutes,
          shifts: dayShifts,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<_RosterStaffRow> visible = _visibleStaff;
    final bool canWriteStaff = HrShiftsAtomPermissions.write.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );

    final bool showActionLabels =
        AppBreakpoints.of(context).showsToolbarActionLabels;

    return AppActionLabelScope(
      showLabels: showActionLabels,
      forceIconOnly: !showActionLabels,
      child: AppDialog(
      title: Text(l10n.hrRosterDetailDialogTitle),
      icon: const Icon(Icons.calendar_month_outlined),
      scrollable: true,
      maxWidth: 1100,
      stackActionsWhenCompact: false,
      denseActions: true,
      content: widget.isLoading && _roster == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.failure != null && _roster == null)
                  Text(
                    widget.failure!.detailMessage ?? widget.failure!.messageKey,
                  )
                else ...<Widget>[
                  AppCollapsibleSection(
                    title: l10n.hrRosterOverviewSectionTitle,
                    titleIcon: Icons.info_outline,
                    child: AppInfoSheetGrid(
                      emptyValue: l10n.profileUnknownValue,
                      spacing: theme.spacing.lg,
                      runSpacing: theme.spacing.sm,
                      layout: AppInfoSheetLayout.inline,
                      items: _overviewItems(l10n),
                    ),
                  ),
                  SizedBox(height: theme.spacing.lg),
                  AppCollapsibleSection(
                    title: l10n.hrRosterPreviewSectionTitle,
                    titleIcon: Icons.calendar_month_outlined,
                    contentPadding: EdgeInsets.only(bottom: theme.spacing.md),
                    child: _previewDays().isEmpty
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(
                              theme.spacing.md,
                              theme.spacing.md,
                              theme.spacing.md,
                              0,
                            ),
                            child: Text(l10n.hrRosterNoSchedulePreviewLabel),
                          )
                        : HrRosterCalendarPreview(
                            days: _previewDays(),
                            onShowDetails: _showPeriodDetails,
                          ),
                  ),
                  SizedBox(height: theme.spacing.xl),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.groups_outlined,
                        size: theme.appTokens.listIconSize,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: theme.spacing.sm),
                      Expanded(
                        child: Text(
                          l10n.hrRosterAttachedStaffTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: AppFontWeight.emphasis,
                          ),
                        ),
                      ),
                      Text(
                        l10n.hrRosterAssignedStaffCountChip(_staffRows.length),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.sm),
                  AppListTable<_RosterStaffRow>(
                    page: AppPage<_RosterStaffRow>(
                      items: visible,
                      request: AppPageRequest(
                        pageSize: visible.isEmpty ? 20 : visible.length,
                      ),
                      totalItemCount: visible.length,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    forceCompact: true,
                    padEmptyRows: false,
                    maxVisibleItems: visible.isEmpty ? 1 : visible.length,
                    enableExport: true,
                    columnVisibilityStorageKey: 'hr_roster_assigned_staff_v2',
                    columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
                    search: AppListTableSearch<_RosterStaffRow>(
                      controller: _staffSearchController,
                      semanticLabel: l10n.hrSearchLabel,
                      hintText: l10n.hrSearchHint,
                      clearLabel: l10n.hrClearFiltersAction,
                      matcher: (_RosterStaffRow row, String query) => true,
                      onSubmitted: (String value) =>
                          setState(() => _staffSearchQuery = value),
                      onClear: () => setState(() {
                        _staffSearchQuery = '';
                        _categoryFilter = null;
                      }),
                      showAdvancedFilterButton: true,
                      advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
                      advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
                      advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                      advancedFilterResetLabel: l10n.hrClearFiltersAction,
                      allFieldsLabel: l10n.opdAllFieldsFilterLabel,
                      filterGroups: <AppSearchBarFilterGroup>[
                        AppSearchBarFilterGroup(
                          key: 'category',
                          label: l10n.hrRosterStaffCategoryLabel,
                          allLabel: l10n.opdAllFieldsFilterLabel,
                          choices: <AppSearchBarFilterChoice>[
                            for (final AppSelectOption<String> option
                                in _staffCategoryOptions(l10n))
                              AppSearchBarFilterChoice(
                                value: option.value,
                                label: option.label,
                              ),
                          ],
                        ),
                      ],
                      filterValue: AppSearchBarFilterValue(
                        options: <String, String>{
                          if (_categoryFilter != null)
                            'category': _categoryFilter!,
                        },
                      ),
                      onFilterChanged: (AppSearchBarFilterValue value) {
                        setState(() {
                          _categoryFilter = value.option('category');
                        });
                      },
                      trailingActions: <AppSearchBarAction>[
                        if (canWriteStaff && !_isDeleted)
                          AppSearchBarAction(
                            icon: Icons.person_remove_outlined,
                            label: l10n.hrRosterRemoveSelectedStaffAction,
                            tooltip: l10n.hrRosterRemoveSelectedStaffAction,
                            destructive: true,
                            enabled: !_busy && _selectedStaffIds.isNotEmpty,
                            onPressed: _busy || _selectedStaffIds.isEmpty
                                ? null
                                : _removeSelected,
                          ),
                        if (canWriteStaff && !_isDeleted)
                          AppSearchBarAction(
                            icon: Icons.person_add_alt_1_outlined,
                            label: l10n.hrRosterAddStaffAction,
                            tooltip: l10n.hrRosterAddStaffAction,
                            enabled: !_busy,
                            onPressed: _busy ? null : _addStaff,
                          ),
                      ],
                    ),
                    columns: _staffColumns(l10n, visible: visible),
                    emptyBuilder: (_) => Text(l10n.hrRosterNoStaffLabel),
                    mobileItemBuilder:
                        (BuildContext context, _RosterStaffRow row) {
                          return AppListTableMobileItem(
                            title: row.title,
                            caption:
                                row.staffNumber ??
                                row.displayId ??
                                row.staffProfileId,
                            meta: <AppListTableMobileMeta>[
                              if ((row.staffCategory ?? '').isNotEmpty)
                                AppListTableMobileMeta(
                                  label: _staffCategoryLabel(
                                    l10n,
                                    row.staffCategory,
                                  ),
                                ),
                            ],
                          );
                        },
                  ),
                ],
              ],
            ),
      actions: <Widget>[
        if (_isDeleted) ...<Widget>[
          AppAccessActionGate(
            requirement: HrShiftsAtomPermissions.write,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                leadingIcon: Icons.restore_outlined,
                label: l10n.hrRosterRestoreAction,
                tooltip: l10n.hrRosterRestoreAction,
                dense: true,
                enabled: isAllowed && !_busy && _roster != null,
                onPressed: !isAllowed || _busy || _roster == null
                    ? null
                    : _restoreRoster,
              );
            },
          ),
          AppAccessActionGate(
            requirement: HrShiftsAtomPermissions.write,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                leadingIcon: Icons.delete_forever_outlined,
                label: l10n.hrRosterPermanentDeleteAction,
                tooltip: l10n.hrRosterPermanentDeleteAction,
                dense: true,
                color: Theme.of(context).colorScheme.error,
                enabled: isAllowed && !_busy && _roster != null,
                onPressed: !isAllowed || _busy || _roster == null
                    ? null
                    : _permanentDeleteRoster,
              );
            },
          ),
        ] else ...<Widget>[
          AppAccessActionGate(
            requirement: HrShiftsAtomPermissions.write,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                leadingIcon: Icons.edit_outlined,
                label: l10n.commonEditActionLabel,
                tooltip: l10n.hrRosterEditDialogTitle,
                dense: true,
                enabled: isAllowed && !_busy && _roster != null,
                onPressed: !isAllowed || _busy || _roster == null
                    ? null
                    : _editRoster,
              );
            },
          ),
          AppAccessActionGate(
            requirement: HrShiftsAtomPermissions.write,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                leadingIcon: Icons.delete_outline,
                label: l10n.hrRosterDeleteAction,
                tooltip: l10n.hrRosterDeleteAction,
                dense: true,
                color: Theme.of(context).colorScheme.error,
                enabled: isAllowed && !_busy && _roster != null,
                onPressed: !isAllowed || _busy || _roster == null
                    ? null
                    : _deleteRoster,
              );
            },
          ),
        ],
        AppButton.secondary(
          leadingIcon: Icons.print_outlined,
          label: l10n.commonPrintActionLabel,
          tooltip: l10n.commonPrintActionLabel,
          dense: true,
          enabled: _roster != null && !_busy,
          onPressed: _roster == null || _busy ? null : _printRoster,
        ),
        AppButton.close(
          label: l10n.commonCloseActionLabel,
          tooltip: l10n.commonCloseActionLabel,
          dense: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    ),
    );
  }

  List<AppInfoSheetItem> _overviewItems(AppLocalizations l10n) {
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    return <AppInfoSheetItem>[
      AppInfoSheetItem(
        label: l10n.hrRosterOverviewNameLabel,
        value: _informativeName(l10n),
      ),
      AppInfoSheetItem(
        label: l10n.hrRosterOverviewIdLabel,
        value: _rosterId,
        copyable: true,
      ),
      AppInfoSheetItem(
        label: l10n.hrRosterOverviewPeriodLabel,
        value:
            (roster['period_label'] ?? widget.item.periodLabel)?.toString() ??
            '',
      ),
      AppInfoSheetItem(
        label: l10n.hrRosterOverviewRecurringLabel,
        value: (roster['is_recurring'] == true || widget.item.isRecurring)
            ? l10n.commonYesLabel
            : l10n.commonNoLabel,
      ),
      AppInfoSheetItem(
        label: l10n.hrRosterOverviewStatusLabel,
        value: _rosterStatusLabel(
          l10n,
          _isDeleted
              ? 'DELETED'
              : (roster['status'] ?? widget.item.status)?.toString(),
        ),
      ),
      AppInfoSheetItem(
        label: l10n.hrRosterOverviewAssignedStaffLabel,
        value: _staffRows.length.toString(),
      ),
      if ((roster['facility_name'] ?? '').toString().trim().isNotEmpty)
        AppInfoSheetItem(
          label: l10n.hrRosterOverviewFacilityLabel,
          value: roster['facility_name']?.toString(),
        ),
      if ((roster['department_name'] ?? '').toString().trim().isNotEmpty)
        AppInfoSheetItem(
          label: l10n.hrRosterOverviewDepartmentLabel,
          value: roster['department_name']?.toString(),
        ),
    ];
  }

  List<AppListTableColumn<_RosterStaffRow>> _staffColumns(
    AppLocalizations l10n, {
    required List<_RosterStaffRow> visible,
  }) {
    final bool allSelected =
        visible.isNotEmpty &&
        visible.every(
          (_RosterStaffRow row) =>
              _selectedStaffIds.contains(row.staffProfileId),
        );
    final bool noneSelected = visible.every(
      (_RosterStaffRow row) => !_selectedStaffIds.contains(row.staffProfileId),
    );

    return <AppListTableColumn<_RosterStaffRow>>[
      AppListTableColumn<_RosterStaffRow>(
        id: 'select',
        label: l10n.hrRosterSelectAllStaffAction,
        alwaysVisible: true,
        fixedWidth: 44,
        headerBuilder: (BuildContext context) {
          return Center(
            child: Checkbox(
              tristate: true,
              value: allSelected
                  ? true
                  : noneSelected
                  ? false
                  : null,
              onChanged: _busy || visible.isEmpty
                  ? null
                  : (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedStaffIds.addAll(
                            visible.map(
                              (_RosterStaffRow row) => row.staffProfileId,
                            ),
                          );
                        } else {
                          for (final _RosterStaffRow row in visible) {
                            _selectedStaffIds.remove(row.staffProfileId);
                          }
                        }
                      });
                    },
            ),
          );
        },
        cellBuilder: (BuildContext context, _RosterStaffRow row) {
          final bool selected = _selectedStaffIds.contains(row.staffProfileId);
          return Center(
            child: Checkbox(
              value: selected,
              onChanged: _busy
                  ? null
                  : (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedStaffIds.add(row.staffProfileId);
                        } else {
                          _selectedStaffIds.remove(row.staffProfileId);
                        }
                      });
                    },
            ),
          );
        },
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'name',
        label: l10n.hrRosterNameLabel,
        preferredWidth: 168,
        sortComparator: (_RosterStaffRow left, _RosterStaffRow right) =>
            appListTableCompareText(left.title, right.title),
        cellBuilder: (BuildContext context, _RosterStaffRow row) {
          final ThemeData theme = Theme.of(context);
          return Text(
            row.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: AppFontWeight.emphasis,
            ),
          );
        },
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'staff_number',
        label: l10n.hrStaffNumberLabel,
        preferredWidth: 280,
        sortComparator: (_RosterStaffRow left, _RosterStaffRow right) =>
            appListTableCompareText(
              left.staffNumber ?? left.displayId,
              right.staffNumber ?? right.displayId,
            ),
        cellBuilder: (BuildContext context, _RosterStaffRow row) {
          return AppCopyableIdentifierCell(
            title: row.staffNumber ?? row.displayId ?? row.staffProfileId,
            identifier: row.displayId ?? row.staffProfileId,
          );
        },
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'position',
        label: l10n.hrPositionLabel,
        fixedWidth: 168,
        sortComparator: (_RosterStaffRow left, _RosterStaffRow right) =>
            appListTableCompareText(left.position, right.position),
        cellBuilder: (BuildContext context, _RosterStaffRow row) {
          final ThemeData theme = Theme.of(context);
          return Text(
            (row.position ?? '').ifEmpty(context.l10n.profileUnknownValue),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          );
        },
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'practitioner_type',
        label: l10n.hrPractitionerTypeLabel,
        fixedWidth: 128,
        sortComparator: (_RosterStaffRow left, _RosterStaffRow right) =>
            appListTableCompareText(
              left.practitionerType,
              right.practitionerType,
            ),
        cellBuilder: (BuildContext context, _RosterStaffRow row) {
          final String value = (row.practitionerType ?? '').trim();
          return Text(
            value.isEmpty
                ? context.l10n.profileUnknownValue
                : context.l10n.hrReferencePractitionerTypeLabel(
                    value,
                    fallback: value,
                  ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'category',
        label: l10n.hrRosterStaffCategoryLabel,
        fixedWidth: 120,
        sortComparator: (_RosterStaffRow left, _RosterStaffRow right) =>
            appListTableCompareText(left.staffCategory, right.staffCategory),
        cellBuilder: (BuildContext context, _RosterStaffRow row) => Text(
          _staffCategoryLabel(context.l10n, row.staffCategory),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'actions',
        label: l10n.patientsQuickActionsTitle,
        alwaysVisible: true,
        fixedWidth: 120,
        cellBuilder: (BuildContext context, _RosterStaffRow row) {
          return Align(
            alignment: Alignment.centerLeft,
            child: AppAccessActionGate(
              requirement: HrShiftsAtomPermissions.write,
              builder: (BuildContext context, bool isAllowed) {
                return AppButton.tertiary(
                  leadingIcon: Icons.person_remove_outlined,
                  label: l10n.hrRosterRemoveStaffAction,
                  tooltip: l10n.hrRosterRemoveStaffAction,
                  dense: true,
                  color: Theme.of(context).colorScheme.error,
                  enabled: isAllowed && !_busy,
                  onPressed: !isAllowed || _busy
                      ? null
                      : () => _removeStaff(row.staffProfileId),
                );
              },
            ),
          );
        },
      ),
    ];
  }
}

List<AppSelectOption<String>> _staffCategoryOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'FULL_TIME',
      label: l10n.hrRosterStaffCategoryFullTime,
    ),
    AppSelectOption<String>(
      value: 'PART_TIME',
      label: l10n.hrRosterStaffCategoryPartTime,
    ),
    AppSelectOption<String>(
      value: 'LOCUM',
      label: l10n.hrRosterStaffCategoryLocum,
    ),
    AppSelectOption<String>(
      value: 'SPECIALIST',
      label: l10n.hrRosterStaffCategorySpecialist,
    ),
    AppSelectOption<String>(
      value: 'CONTRACT',
      label: l10n.hrRosterStaffCategoryContract,
    ),
    AppSelectOption<String>(
      value: 'OTHER',
      label: l10n.hrRosterStaffCategoryOther,
    ),
  ];
}

String _staffCategoryLabel(AppLocalizations l10n, String? raw) {
  return switch ((raw ?? '').trim().toUpperCase()) {
    'FULL_TIME' => l10n.hrRosterStaffCategoryFullTime,
    'PART_TIME' => l10n.hrRosterStaffCategoryPartTime,
    'LOCUM' => l10n.hrRosterStaffCategoryLocum,
    'SPECIALIST' => l10n.hrRosterStaffCategorySpecialist,
    'CONTRACT' => l10n.hrRosterStaffCategoryContract,
    'OTHER' => l10n.hrRosterStaffCategoryOther,
    _ => (raw ?? '').trim().isEmpty ? l10n.profileUnknownValue : raw!,
  };
}

DateTime? _parseDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return <String, Object?>{};
}

(int, int) _parseHourMinute(String? raw, int fallbackHour, int fallbackMinute) {
  final List<String> parts = (raw ?? '').split(':');
  if (parts.length >= 2) {
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour != null && minute != null) {
      return (hour.clamp(0, 23), minute.clamp(0, 59));
    }
  }
  return (fallbackHour, fallbackMinute);
}

int _dayEndMinutesSafe(int startMinutes, int endMinutes) {
  if (endMinutes > startMinutes) {
    return endMinutes;
  }
  return startMinutes + 60;
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

