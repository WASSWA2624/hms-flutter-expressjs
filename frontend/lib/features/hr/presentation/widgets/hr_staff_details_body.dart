import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_department_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_position_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assignment_detail_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_availability_calendar.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_compensation_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart'
    hide
        hrReadRequirement,
        hrWriteRequirement,
        hrRosterWriteRequirement,
        hrRosterApproveRequirement,
        hrRosterPublishRequirement,
        hrPayrollRequirement,
        HrHumanResourcesAtomPermissions,
        HrLeaveRequestsAtomPermissions,
        HrShiftsAtomPermissions,
        HrPayrollDraftsAtomPermissions,
        showHrMutationSnackBar,
        readHrWorkspaceState;
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_leave_detail_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_payroll_wizard_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_record_availability_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_request_leave_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_calendar_preview.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_detail_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_actions.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_offboarding_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

typedef HrStaffShiftAction =
    Future<void> Function(BuildContext context, WidgetRef ref);

/// Comprehensive Staff details body for the HR staff dialog.
class HrStaffDetailsBody extends ConsumerWidget {
  const HrStaffDetailsBody({
    required this.state,
    required this.detail,
    required this.onAssignShift,
    required this.onSwapShift,
    super.key,
  });

  final HrWorkspaceState state;
  final HrStaffDetail detail;
  final HrStaffShiftAction onAssignShift;
  final HrStaffShiftAction onSwapShift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = HrHumanResourcesAtomPermissions.write.isAllowed(
      policy,
    );
    final bool canRosterWrite =
        HrHumanResourcesAtomPermissions.nestedRosterWrite.isAllowed(policy);
    final HrStaffProfile profile = detail.profile;
    final List<HrStaffCompensation> activeCompensations = detail.compensations
        .where((HrStaffCompensation row) => row.isActive)
        .toList(growable: false);
    final String? primaryRosterId = _primaryRosterId(detail.shiftAssignments);
    final bool hasRoster = (primaryRosterId ?? '').trim().isNotEmpty;
    final List<HrRosterDayPreview> rosterDays = _rosterDayPreviews(
      detail.shiftAssignments,
    );

    final List<Widget> sections = <Widget>[
      _StaffProfileSection(
        state: state,
        detail: detail,
        canWrite: canWrite,
      ),
      HrStaffDetailActions(
        state: state,
        detail: detail,
        onAssignDepartment: showHrAssignDepartmentDialog,
        onAssignPosition: showHrAssignPositionDialog,
        onRecordAvailability: showHrRecordAvailabilityDialog,
        onAssignShift: onAssignShift,
        onSwapShift: onSwapShift,
        onRequestLeave: (BuildContext context, WidgetRef ref) =>
            showHrRequestLeaveDialog(context, ref),
        onCompensation:
            (BuildContext context, WidgetRef ref, HrStaffProfile staff) =>
                showHrCompensationDialog(
                  context,
                  ref,
                  staff,
                  detail.compensations,
                ),
        onRunPayroll:
            (BuildContext context, WidgetRef ref, HrStaffProfile staff) =>
                showHrPayrollWizardDialog(context, ref, staff),
        onAssignRole: showHrAssignRoleDialog,
        onModuleAccess: (BuildContext context, HrStaffDetail staffDetail) {
          showHrModuleAccessDialog(context, ref, staffDetail.accessSummary);
        },
        onOffboardStaff:
            (BuildContext context, WidgetRef ref, HrStaffDetail d) =>
                showHrStaffOffboardingDialog(
                  context,
                  ref,
                  d,
                  onOpenPayroll: () =>
                      showHrPayrollWizardDialog(context, ref, d.profile),
                ),
      ),
      AppCollapsibleSection(
        title: l10n.hrStaffRostersSectionTitle,
        titleIcon: Icons.calendar_month_outlined,
        description: l10n.hrStaffRostersSectionBody,
        initiallyExpanded: true,
        headerActions: <Widget>[
          if (canRosterWrite && !profile.isSeparated && !state.isMutating)
            AppButton.primary(
              label: hasRoster
                  ? l10n.hrChangeRosterAction
                  : l10n.hrAddRosterAction,
              leadingIcon: hasRoster
                  ? Icons.edit_calendar_outlined
                  : Icons.add_outlined,
              onPressed: () => unawaited(
                _onRosterHeaderAction(
                  context,
                  ref,
                  hasRoster: hasRoster,
                  rosterId: primaryRosterId,
                ),
              ),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (rosterDays.every((HrRosterDayPreview day) => day.shifts.isEmpty))
              AppStateView(
                title: l10n.hrStaffRostersEmptyTitle,
                body: l10n.hrStaffRostersEmptyBody,
                icon: Icons.event_available_outlined,
              )
            else
              HrRosterCalendarPreview(
                days: rosterDays,
                onShowDetails: (HrRosterPeriodDetails details) {
                  unawaited(
                    showHrRosterPeriodDetailsDialog(context, details: details),
                  );
                },
              ),
            if (detail.availabilities.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              Text(
                l10n.hrAvailabilitySectionTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeight.emphasis,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              HrAvailabilityCalendar(
                availabilities: detail.availabilities,
                leaves: detail.leaves,
                onDayTap: (int day) {
                  HrStaffAvailability? availability;
                  for (final HrStaffAvailability item
                      in detail.availabilities) {
                    if (item.dayOfWeek == day) {
                      availability = item;
                      break;
                    }
                  }
                  showHrAvailabilityDaySheet(
                    context,
                    dayOfWeek: day,
                    availability: availability,
                    onEdit: canRosterWrite
                        ? () => showHrRecordAvailabilityDialog(context, ref)
                        : null,
                    onAddSlot: canRosterWrite
                        ? () => showHrRecordAvailabilityDialog(context, ref)
                        : null,
                  );
                },
              ),
            ],
          ],
        ),
      ),
      AppCollapsibleSection(
        title: l10n.hrStaffLeavesSectionTitle,
        titleIcon: Icons.event_busy_outlined,
        description: l10n.hrStaffLeavesSectionBody,
        initiallyExpanded: true,
        headerActions: <Widget>[
          if (canWrite && !profile.isSeparated && !state.isMutating)
            AppButton.primary(
              label: l10n.hrRequestLeaveAction,
              leadingIcon: Icons.event_busy_outlined,
              onPressed: () =>
                  unawaited(showHrRequestLeaveDialog(context, ref)),
            ),
        ],
        child: detail.leaves.isEmpty
            ? AppStateView(
                title: l10n.hrNoLeaveLabel,
                body: l10n.hrStaffLeavesEmptyBody,
                icon: Icons.event_available_outlined,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final HrStaffLeave leave in detail.leaves) ...<Widget>[
                    _CompactRecordTile(
                      title: _leaveTitle(context, leave),
                      subtitle: _leaveSubtitle(context, leave),
                      trailing: AppStatusBadge(
                        label: _statusLabel(context, leave.status),
                        tone: _leaveTone(leave.status),
                      ),
                      onTap: () => showHrLeaveDetailDialog(context, leave),
                    ),
                    SizedBox(height: theme.spacing.sm),
                  ],
                ],
              ),
      ),
      AppCollapsibleSection(
        title: l10n.hrStaffPayrollSectionTitle,
        titleIcon: Icons.payments_outlined,
        description: l10n.hrStaffPayrollSectionBody,
        initiallyExpanded: true,
        headerActions: <Widget>[
          if (canWrite && !state.isMutating)
            AppButton.secondary(
              label: l10n.hrCompensationAction,
              leadingIcon: Icons.price_change_outlined,
              onPressed: () => unawaited(
                showHrCompensationDialog(
                  context,
                  ref,
                  profile,
                  detail.compensations,
                ),
              ),
            ),
          if (canWrite &&
              !state.isMutating &&
              activeCompensations.isNotEmpty)
            AppButton.primary(
              label: l10n.hrRunPayrollAction,
              leadingIcon: Icons.payments_outlined,
              onPressed: () => unawaited(
                showHrPayrollWizardDialog(context, ref, profile),
              ),
            ),
        ],
        child: _PayrollSummary(
          profile: profile,
          compensations: activeCompensations,
        ),
      ),
      AppCollapsibleSection(
        title: l10n.hrStaffPermissionsSectionTitle,
        titleIcon: Icons.shield_outlined,
        description: l10n.hrStaffPermissionsSectionBody,
        initiallyExpanded: true,
        child: _PermissionsReadonlySection(detail: detail),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: appCollapsibleSectionSpacing(context, sections),
    );
  }

  Future<void> _onRosterHeaderAction(
    BuildContext context,
    WidgetRef ref, {
    required bool hasRoster,
    required String? rosterId,
  }) async {
    if (hasRoster && (rosterId ?? '').trim().isNotEmpty) {
      await showHrRosterDetailByIdDialog(
        context,
        ref,
        rosterId: rosterId!.trim(),
      );
      if (context.mounted) {
        await ref
            .read(hrWorkspaceControllerProvider.notifier)
            .selectStaff(detail.profile);
      }
      return;
    }

    final bool created = await showHrCreateRosterDialog(
      context,
      ref,
      attachStaffProfileIds: <String>[detail.profile.effectiveId],
    );
    if (created && context.mounted) {
      await ref
          .read(hrWorkspaceControllerProvider.notifier)
          .selectStaff(detail.profile);
    }
  }
}

class _StaffProfileSection extends ConsumerWidget {
  const _StaffProfileSection({
    required this.state,
    required this.detail,
    required this.canWrite,
  });

  final HrWorkspaceState state;
  final HrStaffDetail detail;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final HrStaffProfile profile = detail.profile;
    final bool hasLinkedUser =
        (profile.userEmail ?? profile.userDisplayId ?? profile.userId ?? '')
            .trim()
            .isNotEmpty;
    final List<HrStaffAssignment> activeAssignments = detail.assignments
        .where((HrStaffAssignment row) => row.isActive)
        .toList(growable: false);

    return AppCollapsibleSection(
      title: l10n.hrStaffDetailsSectionTitle,
      titleIcon: Icons.badge_outlined,
      description: l10n.hrStaffDetailsSectionBody,
      initiallyExpanded: true,
      collapsible: false,
      headerActions: <Widget>[
        if (!profile.isSeparated && !state.isMutating && canWrite)
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.edit_outlined,
            label: l10n.hrEditStaffAction,
            semanticLabel: l10n.hrEditStaffAction,
            tooltip: l10n.hrEditStaffAction,
            onPressed: () => showHrStaffOnboardingDialog(
              context,
              ref,
              staff: profile,
            ),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppPatientDetails(
            semanticLabel: l10n.hrStaffDetailTitle,
            patientName: profile.displayName,
            patientNumber: profile.staffNumber ?? profile.effectiveId,
            patientNumberLabel: l10n.hrStaffNumberLabel,
            showAvatar: false,
            persistExpandPreference: false,
            initiallyExpanded: true,
            compactSupportingText: hrJoinDisplay(<String?>[
              profile.position,
              l10n.hrReferencePractitionerTypeLabel(
                profile.practitionerType,
                fallback: profile.practitionerType,
              ),
            ]),
            status: profile.isSeparated
                ? AppWorkspaceStatus(
                    label: _apiLabel(context, profile.status),
                    tone: AppWorkspaceStatusTone.error,
                    icon: Icons.person_off_outlined,
                  )
                : AppWorkspaceStatus(
                    label: _apiLabel(context, profile.status),
                    tone: AppWorkspaceStatusTone.success,
                  ),
            expandedFields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.hrPositionLabel,
                value: profile.position ?? '',
                icon: Icons.work_outline,
              ),
              AppWorkspacePatientContextField(
                label: l10n.hrPractitionerTypeLabel,
                value: l10n.hrReferencePractitionerTypeLabel(
                  profile.practitionerType,
                  fallback: profile.practitionerType,
                ),
                icon: Icons.medical_information_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.hrDepartmentLabel,
                value:
                    profile.departmentName ?? profile.departmentDisplayId ?? '',
                icon: Icons.apartment_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.hrHireDateLabel,
                value: profile.hireDate == null
                    ? ''
                    : AppFormatters.mediumDate(
                        profile.hireDate!,
                        Localizations.localeOf(context),
                      ),
                icon: Icons.calendar_today_outlined,
              ),
              if (hasLinkedUser) ...<AppWorkspacePatientContextField>[
                AppWorkspacePatientContextField(
                  label: l10n.hrEmailLabel,
                  value: profile.userEmail ?? '',
                  icon: Icons.email_outlined,
                ),
                AppWorkspacePatientContextField(
                  label: l10n.hrUserIdLabel,
                  value: profile.userDisplayId ?? profile.userId ?? '',
                  icon: Icons.badge_outlined,
                  copyable: true,
                ),
              ],
              if (profile.isSeparated) ...<AppWorkspacePatientContextField>[
                AppWorkspacePatientContextField(
                  label: l10n.hrSeparationTypeLabel,
                  value: hrSeparationTypeLabel(l10n, profile.separationType),
                  icon: Icons.person_off_outlined,
                ),
                AppWorkspacePatientContextField(
                  label: l10n.hrLastWorkingDayLabel,
                  value: profile.separationDate == null
                      ? ''
                      : AppFormatters.mediumDate(
                          profile.separationDate!,
                          Localizations.localeOf(context),
                        ),
                  icon: Icons.event_outlined,
                ),
              ],
            ],
          ),
          if (activeAssignments.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            Text(
              l10n.hrAssignmentsSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            for (final HrStaffAssignment assignment in activeAssignments)
              Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.xs),
                child: _CompactRecordTile(
                  title: hrAssignmentTitle(assignment, l10n),
                  subtitle: hrAssignmentSubtitle(context, assignment, l10n),
                  trailing: assignment.isPrimary
                      ? AppStatusBadge(
                          label: l10n.hrPrimaryAssignmentLabel,
                          tone: AppWorkspaceStatusTone.info,
                        )
                      : null,
                  onTap: () => showHrAssignmentDetailDialog(
                    context,
                    ref,
                    detail,
                    assignment,
                    isMutating: state.isMutating,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PayrollSummary extends StatelessWidget {
  const _PayrollSummary({
    required this.profile,
    required this.compensations,
  });

  final HrStaffProfile profile;
  final List<HrStaffCompensation> compensations;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final List<_PayrollMetric> metrics = <_PayrollMetric>[];

    for (final HrStaffCompensation row in compensations) {
      final String payType = (row.payType ?? '').trim().toUpperCase();
      metrics.add(
        _PayrollMetric(
          label: l10n.hrReferenceCompensationPayTypeLabel(
            payType,
            fallback: payType,
          ),
          value: _money(row.rate, row.currency, locale),
          hint: hrDateRange(context, row.effectiveFrom, row.effectiveTo),
        ),
      );
    }

    if (profile.consultationFee != null &&
        !compensations.any(
          (HrStaffCompensation row) =>
              (row.payType ?? '').toUpperCase() == 'PER_CONSULTATION',
        )) {
      metrics.add(
        _PayrollMetric(
          label: l10n.hrConsultationFeeLabel,
          value: _money(
            profile.consultationFee,
            profile.consultationCurrency,
            locale,
          ),
        ),
      );
    }

    if (metrics.isEmpty) {
      return AppStateView(
        title: l10n.hrNoCompensationLabel,
        body: l10n.hrStaffPayrollEmptyBody,
        icon: Icons.price_change_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            for (final _PayrollMetric metric in metrics)
              _MetricChip(metric: metric),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        Text(
          l10n.hrStaffPayrollPaidHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _money(num? amount, String? currency, Locale locale) {
    if (amount == null) {
      return '—';
    }
    final String formatted = AppFormatters.decimal(amount, locale);
    final String code = (currency ?? '').trim();
    return code.isEmpty ? formatted : '$formatted $code';
  }
}

class _PayrollMetric {
  const _PayrollMetric({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.metric});

  final _PayrollMetric metric;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: theme.borders.all(),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              metric.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              metric.value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
            if ((metric.hint ?? '').trim().isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                metric.hint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionsReadonlySection extends StatelessWidget {
  const _PermissionsReadonlySection({required this.detail});

  final HrStaffDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final HrStaffAccessSummary? summary = detail.accessSummary;
    final List<HrUserRole> roles = summary?.userRoles ?? const <HrUserRole>[];
    final List<String> permissions =
        summary?.effectivePermissions ?? const <String>[];
    final List<HrModuleAccess> modules = (summary?.moduleAccess ??
            const <HrModuleAccess>[])
        .where((HrModuleAccess row) => row.granted)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.radius.md),
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.hrStaffPermissionsManageHint,
                  style: theme.textTheme.bodyMedium,
                ),
                SizedBox(height: theme.spacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton.secondary(
                    label: l10n.hrManageAccessAction,
                    leadingIcon: Icons.manage_accounts_outlined,
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      GoRouter.of(context).go(
                        AppRoutes.hr.location(
                          queryParameters: const <String, String>{
                            'section': 'access',
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (roles.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.hrRolesSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final HrUserRole role in roles)
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(
                    l10n.hrReferenceRoleLabel(
                      role.roleName,
                      fallback: role.roleName ?? role.roleId,
                    ),
                    style: theme.textTheme.labelMedium,
                  ),
                ),
            ],
          ),
        ],
        if (modules.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.hrModuleAccessSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final HrModuleAccess module in modules.take(12))
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  avatar: Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    module.label ?? module.slug,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
            ],
          ),
        ],
        if (permissions.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.hrEffectivePermissionsTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final String permission in permissions.take(18))
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(
                    permission,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              if (permissions.length > 18)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    l10n.hrStaffPermissionsMoreLabel(permissions.length - 18),
                  ),
                ),
            ],
          ),
        ],
        if (roles.isEmpty && modules.isEmpty && permissions.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.md),
            child: Text(
              l10n.hrNoRolesLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactRecordTile extends StatelessWidget {
  const _CompactRecordTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radius.md),
        side: theme.borders.side(),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.radius.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                    if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: theme.spacing.xs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                SizedBox(width: theme.spacing.sm),
                trailing!,
              ],
              if (onTap != null) ...<Widget>[
                SizedBox(width: theme.spacing.xs),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String? _primaryRosterId(List<HrShiftAssignment> assignments) {
  final Map<String, int> counts = <String, int>{};
  for (final HrShiftAssignment assignment in assignments) {
    final String id = (assignment.rosterId ?? '').trim();
    if (id.isEmpty) {
      continue;
    }
    counts[id] = (counts[id] ?? 0) + 1;
  }
  if (counts.isEmpty) {
    return null;
  }
  final List<MapEntry<String, int>> ranked = counts.entries.toList()
    ..sort(
      (MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value),
    );
  return ranked.first.key;
}

List<HrRosterDayPreview> _rosterDayPreviews(
  List<HrShiftAssignment> assignments,
) {
  final DateTime now = DateTime.now();
  final DateTime from = DateTime(now.year, now.month);
  final DateTime to = DateTime(now.year, now.month + 1, 0);
  final Map<String, List<HrRosterShiftWindow>> byDay =
      <String, List<HrRosterShiftWindow>>{};

  for (final HrShiftAssignment assignment in assignments) {
    final DateTime? start = assignment.startTime?.toLocal();
    final DateTime? end = assignment.endTime?.toLocal();
    if (start == null || end == null) {
      continue;
    }
    if (start.isBefore(from) || start.isAfter(to.add(const Duration(days: 1)))) {
      // Still include nearby shifts outside the month when present.
    }
    final String key = hrRosterDateKey(start);
    byDay
        .putIfAbsent(key, () => <HrRosterShiftWindow>[])
        .add(
          HrRosterShiftWindow(
            start: start,
            end: end,
            staffNames: const <String>[],
            shiftType: assignment.shiftType,
          ),
        );
  }

  DateTime rangeStart = from;
  DateTime rangeEnd = to;
  if (byDay.isNotEmpty) {
    final List<DateTime> dated = byDay.keys
        .map(DateTime.parse)
        .toList(growable: false)
      ..sort();
    if (dated.first.isBefore(rangeStart)) {
      rangeStart = DateTime(dated.first.year, dated.first.month);
    }
    if (dated.last.isAfter(rangeEnd)) {
      rangeEnd = DateTime(dated.last.year, dated.last.month + 1, 0);
    }
  }

  final List<HrRosterDayPreview> days = <HrRosterDayPreview>[];
  DateTime cursor = rangeStart;
  while (!cursor.isAfter(rangeEnd)) {
    final String key = hrRosterDateKey(cursor);
    final List<HrRosterShiftWindow> dayShifts =
        List<HrRosterShiftWindow>.from(
          byDay[key] ?? const <HrRosterShiftWindow>[],
        )..sort(
          (HrRosterShiftWindow a, HrRosterShiftWindow b) =>
              a.start.compareTo(b.start),
        );
    final bool weekend =
        cursor.weekday == DateTime.saturday ||
        cursor.weekday == DateTime.sunday;
    days.add(
      HrRosterDayPreview(
        date: cursor,
        label: key,
        isHoliday: false,
        isWorkingDay: dayShifts.isNotEmpty || !weekend,
        dayStartMinutes: 8 * 60,
        dayEndMinutes: 17 * 60,
        shifts: dayShifts,
      ),
    );
    cursor = cursor.add(const Duration(days: 1));
  }
  return days;
}

String _leaveTitle(BuildContext context, HrStaffLeave leave) {
  final AppLocalizations l10n = context.l10n;
  return l10n.hrReferenceLeaveTypeLabel(
    leave.leaveType,
    fallback: leave.leaveType ?? l10n.hrLeaveLabel,
  );
}

String _leaveSubtitle(BuildContext context, HrStaffLeave leave) {
  return hrDateRange(context, leave.startDate, leave.endDate);
}

String _statusLabel(BuildContext context, String? status) {
  return _apiLabel(context, status);
}

AppWorkspaceStatusTone _leaveTone(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'APPROVED' => AppWorkspaceStatusTone.success,
    'REQUESTED' => AppWorkspaceStatusTone.warning,
    'REJECTED' || 'CANCELLED' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String _apiLabel(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return '';
  }
  final AppLocalizations l10n = context.l10n;
  final String leaveType = l10n.hrReferenceLeaveTypeLabel(
    normalized,
    fallback: '',
  );
  if (leaveType.isNotEmpty && leaveType != normalized) {
    return leaveType;
  }
  return switch (normalized.toUpperCase()) {
    'REQUESTED' => l10n.settingsLeaveStatusRequested,
    'APPROVED' => l10n.settingsLeaveStatusApproved,
    'REJECTED' => l10n.settingsLeaveStatusRejected,
    'CANCELLED' => l10n.settingsLeaveStatusCancelled,
    'ACTIVE' => l10n.hrAssignmentActiveLabel,
    'INACTIVE' => l10n.hrAssignmentEndedLabel,
    _ => normalized,
  };
}
