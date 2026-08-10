import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/settings/data/settings_staff_self_repository.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Leaves tab (`/settings?tab=leaves`) — staff self-service leave requests.
///
/// See [SettingsLeavesAtomPermissions] for the inventory → matrix map.
class SettingsLeavesSection extends ConsumerStatefulWidget {
  const SettingsLeavesSection({super.key});

  @override
  ConsumerState<SettingsLeavesSection> createState() =>
      _SettingsLeavesSectionState();
}

class _SettingsLeavesSectionState extends ConsumerState<SettingsLeavesSection> {
  static const List<String?> _statusFilters = <String?>[
    null,
    'REQUESTED',
    'APPROVED',
    'REJECTED',
    'CANCELLED',
  ];

  String? _statusFilter;
  bool _loading = true;
  AppFailure? _failure;
  List<HrStaffLeave> _leaves = const <HrStaffLeave>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    final Result<List<HrStaffLeave>> result = await ref
        .read(settingsStaffSelfRepositoryProvider)
        .listMyLeaves(status: _statusFilter);
    if (!mounted) {
      return;
    }
    result.when(
      success: (List<HrStaffLeave> items) {
        setState(() {
          _leaves = items;
          _loading = false;
          _failure = null;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _leaves = const <HrStaffLeave>[];
          _loading = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _requestLeave() async {
    final GlobalKey<_SettingsRequestLeaveFieldsState> fieldsKey =
        GlobalKey<_SettingsRequestLeaveFieldsState>();
    final bool? saved = await showAppWorkspaceMutationDialog(
      context: context,
      title: Text(context.l10n.hrLeaveDialogTitle),
      icon: const Icon(Icons.event_busy_outlined),
      submitLabel: context.l10n.hrRequestLeaveAction,
      cancelLabel: context.l10n.commonCancelActionLabel,
      submitIcon: Icons.save_outlined,
      maxWidth: 560,
      buildFields:
          (
            BuildContext context,
            GlobalKey<FormState> formKey,
            bool _, [
            AppFailure? failure,
          ]) {
            return _SettingsRequestLeaveFields(key: fieldsKey);
          },
      onSubmit: () async {
        final _SettingsRequestLeaveFieldsState? state = fieldsKey.currentState;
        final String? validationError = state?.validate(context.l10n);
        if (validationError != null) {
          return AppFailure.validation(detailMessage: validationError);
        }
        final Result<Object?> result = await ref
            .read(settingsStaffSelfRepositoryProvider)
            .createMyLeave(state?.toPayload() ?? const <String, Object?>{});
        return result.when(
          success: (_) => null,
          failure: (AppFailure failure) => failure,
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.settingsLeaveRequestSuccessMessage)),
        );
      await _load();
    }
  }

  void _onStatusFilter(String? status) {
    if (_statusFilter == status) {
      return;
    }
    setState(() => _statusFilter = status);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canRequest =
        SettingsLeavesAtomPermissions.request.isAllowed(accessPolicy);

    return AppAccessGate(
      requirement: SettingsLeavesAtomPermissions.tab,
      child: AppCollapsibleSection(
        title: l10n.settingsLeavesSectionTitle,
        description: l10n.settingsLeavesSectionBody,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (canRequest)
              Align(
                alignment: Alignment.centerRight,
                child: AppAccessActionGate(
                  requirement: SettingsLeavesAtomPermissions.request,
                  builder: (BuildContext context, bool _) {
                    return AppTabToolbarPrimary(
                      label: l10n.hrRequestLeaveAction,
                      icon: Icons.event_busy_outlined,
                      onPressed: () => unawaited(_requestLeave()),
                    );
                  },
                ),
              ),
            if (canRequest) SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                for (final String? status in _statusFilters)
                  FilterChip(
                    label: Text(_statusFilterLabel(l10n, status)),
                    selected: _statusFilter == status,
                    onSelected: (_) => _onStatusFilter(status),
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            _buildBody(l10n, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_loading) {
      return AppStateView(
        variant: AppStateViewVariant.loading,
        title: l10n.settingsLeavesLoadingTitle,
        body: l10n.settingsLeavesLoadingBody,
      );
    }

    final AppFailure? failure = _failure;
    if (failure != null) {
      if (failure.category == AppFailureCategory.notFound) {
        return AppStateView(
          title: l10n.settingsStaffProfileMissingTitle,
          body: l10n.settingsStaffProfileMissingBody,
          icon: Icons.badge_outlined,
        );
      }
      return AppFailureStateView(
        failure: failure,
        title: l10n.settingsLeavesUnavailableTitle,
        onRetry: () => unawaited(_load()),
      );
    }

    if (_leaves.isEmpty) {
      return AppStateView(
        title: l10n.settingsLeavesEmptyTitle,
        body: l10n.settingsLeavesEmptyBody,
        icon: Icons.event_available_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final HrStaffLeave leave in _leaves) ...<Widget>[
          _LeaveTile(leave: leave),
          SizedBox(height: theme.spacing.sm),
        ],
      ],
    );
  }
}

class _LeaveTile extends StatelessWidget {
  const _LeaveTile({required this.leave});

  final HrStaffLeave leave;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Locale locale = Localizations.localeOf(context);
    final String typeLabel = l10n.hrReferenceLeaveTypeLabel(leave.leaveType);
    final String status = (leave.status ?? '').trim().toUpperCase();
    final String range = _dateRange(leave, locale);
    final String? reason = leave.reason?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: theme.borders.all(),
        color: colors.surface,
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    typeLabel.isEmpty ? l10n.hrLeaveLabel : typeLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                ),
                AppStatusBadge(
                  label: _statusFilterLabel(l10n, status.isEmpty ? null : status),
                  tone: _leaveStatusTone(status),
                ),
              ],
            ),
            if (range.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                range,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (leave.isHalfDay) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                l10n.hrLeaveHalfDaySummary(
                  l10n.hrReferenceLeaveHalfDayPeriodLabel(leave.halfDayPeriod),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (reason != null && reason.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(reason, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  String _dateRange(HrStaffLeave leave, Locale locale) {
    final DateTime? start = leave.startDate;
    final DateTime? end = leave.endDate;
    if (start == null && end == null) {
      return '';
    }
    if (start != null && end != null) {
      final String from = AppFormatters.mediumDate(start, locale);
      final String to = AppFormatters.mediumDate(end, locale);
      return from == to ? from : '$from – $to';
    }
    final DateTime value = start ?? end!;
    return AppFormatters.mediumDate(value, locale);
  }
}

AppWorkspaceStatusTone _leaveStatusTone(String status) {
  return switch (status) {
    'APPROVED' => AppWorkspaceStatusTone.success,
    'REQUESTED' => AppWorkspaceStatusTone.warning,
    'REJECTED' || 'CANCELLED' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _statusFilterLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    '' => l10n.settingsLeaveStatusAll,
    'REQUESTED' => l10n.settingsLeaveStatusRequested,
    'APPROVED' => l10n.settingsLeaveStatusApproved,
    'REJECTED' => l10n.settingsLeaveStatusRejected,
    'CANCELLED' => l10n.settingsLeaveStatusCancelled,
    _ => status ?? l10n.settingsLeaveStatusAll,
  };
}

class _SettingsRequestLeaveFields extends StatefulWidget {
  const _SettingsRequestLeaveFields({super.key});

  @override
  State<_SettingsRequestLeaveFields> createState() =>
      _SettingsRequestLeaveFieldsState();
}

class _SettingsRequestLeaveFieldsState
    extends State<_SettingsRequestLeaveFields> {
  final TextEditingController _reasonController = TextEditingController();

  String? _leaveType = 'ANNUAL';
  String? _halfDayPeriod = 'MORNING';
  bool _isHalfDay = false;
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  static int _inclusiveDays(DateTime start, DateTime end) {
    final DateTime from = DateTime(start.year, start.month, start.day);
    final DateTime to = DateTime(end.year, end.month, end.day);
    return to.difference(from).inDays + 1;
  }

  List<AppSelectOption<String>> get _leaveTypeOptions {
    final AppLocalizations l10n = context.l10n;
    const List<String> codes = <String>[
      'ANNUAL',
      'SICK',
      'MATERNITY',
      'PATERNITY',
      'COMPASSIONATE',
      'UNPAID',
      'STUDY',
      'EMERGENCY',
      'OTHER',
    ];
    return <AppSelectOption<String>>[
      for (final String code in codes)
        AppSelectOption<String>(
          value: code,
          label: l10n.hrReferenceLeaveTypeLabel(code),
        ),
    ];
  }

  List<AppSelectOption<String>> get _halfDayPeriodOptions {
    final AppLocalizations l10n = context.l10n;
    return <AppSelectOption<String>>[
      AppSelectOption<String>(
        value: 'MORNING',
        label: l10n.hrReferenceLeaveHalfDayPeriodMorning,
      ),
      AppSelectOption<String>(
        value: 'AFTERNOON',
        label: l10n.hrReferenceLeaveHalfDayPeriodAfternoon,
      ),
    ];
  }

  String? validate(AppLocalizations l10n) {
    if ((_leaveType ?? '').trim().isEmpty) {
      return l10n.hrFieldRequiredLabel(l10n.hrLeaveTypeLabel);
    }
    if (_startDate == null) {
      return l10n.hrFieldRequiredLabel(l10n.hrStartDateLabel);
    }
    if (_endDate == null) {
      return l10n.hrFieldRequiredLabel(l10n.hrEndDateLabel);
    }
    if (_isHalfDay) {
      if ((_halfDayPeriod ?? '').trim().isEmpty) {
        return l10n.hrFieldRequiredLabel(l10n.hrLeaveHalfDayPeriodLabel);
      }
      if (_inclusiveDays(_startDate!, _endDate!) != 1) {
        return l10n.hrLeaveHalfDaySingleDayError;
      }
    }
    return null;
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'leave_type': _leaveType,
      'start_date': _datePayload(_startDate),
      'end_date': _datePayload(_endDate),
      'is_half_day': _isHalfDay,
      if (_isHalfDay) 'half_day_period': _halfDayPeriod,
      'reason': _reasonController.text.trim(),
    };
  }

  void _onStartChanged(DateTime? value) {
    setState(() {
      _startDate = value;
      if (value != null && (_isHalfDay || _endDate == null || _endDate!.isBefore(value))) {
        _endDate = DateTime(value.year, value.month, value.day);
      }
    });
  }

  void _onHalfDayChanged(bool? value) {
    final bool isHalfDay = value == true;
    setState(() {
      _isHalfDay = isHalfDay;
      if (isHalfDay) {
        final DateTime? start = _startDate;
        if (start != null) {
          _endDate = DateTime(start.year, start.month, start.day);
        }
        _halfDayPeriod ??= 'MORNING';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormSection(
      children: <Widget>[
        AppSelectField<String>(
          value: _leaveType,
          labelText: l10n.hrLeaveTypeLabel,
          isRequired: true,
          options: _leaveTypeOptions,
          onChanged: (String? value) => setState(() => _leaveType = value),
        ),
        AppDateField(
          value: _startDate,
          labelText: l10n.hrStartDateLabel,
          isRequired: true,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: _onStartChanged,
        ),
        AppCheckboxField(
          title: l10n.hrLeaveHalfDayLabel,
          subtitle: l10n.hrLeaveHalfDayHelper,
          value: _isHalfDay,
          onChanged: _onHalfDayChanged,
        ),
        if (_isHalfDay)
          AppSelectField<String>(
            value: _halfDayPeriod,
            labelText: l10n.hrLeaveHalfDayPeriodLabel,
            isRequired: true,
            options: _halfDayPeriodOptions,
            onChanged: (String? value) =>
                setState(() => _halfDayPeriod = value),
          ),
        AppDateField(
          value: _endDate,
          labelText: l10n.hrEndDateLabel,
          isRequired: true,
          enabled: !_isHalfDay,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _endDate = value),
        ),
        AppTextField(
          controller: _reasonController,
          labelText: l10n.hrReasonLabel,
          maxLines: 3,
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
