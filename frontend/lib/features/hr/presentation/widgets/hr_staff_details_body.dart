import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_department_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_position_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_assign_roster_dialog.dart';
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
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_request_leave_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_calendar_preview.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_actions.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_offboarding_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_payroll_management_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Comprehensive Staff details body for the HR staff dialog.
class HrStaffDetailsBody extends ConsumerWidget {
  const HrStaffDetailsBody({
    required this.state,
    required this.detail,
    super.key,
  });

  final HrWorkspaceState state;
  final HrStaffDetail detail;

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
    final bool canPayroll =
        HrHumanResourcesAtomPermissions.runPayroll.isAllowed(policy);
    final HrStaffProfile profile = detail.profile;
    final List<HrStaffCompensation> activeCompensations = detail.compensations
        .where((HrStaffCompensation row) => row.isActive)
        .toList(growable: false);
    final HrStaffRosterActionKind rosterKind = resolveStaffRosterActionKind(
      detail.shiftAssignments,
    );
    final bool hasRoster = rosterKind != HrStaffRosterActionKind.add;
    final String? primaryRosterId = _primaryRosterId(detail.shiftAssignments);
    final bool rosterEmpty = detail.shiftAssignments.every(
      (HrShiftAssignment row) =>
          row.startTime == null || row.endTime == null,
    );
    final List<HrRosterDayPreview> rosterDays = _rosterDayPreviews(
      detail.shiftAssignments,
    );
    final HrStaffAccessSummary? summary = detail.accessSummary;
    final List<HrUserRole> roles = summary?.userRoles ?? const <HrUserRole>[];
    final List<String> permissions =
        summary?.effectivePermissions ?? const <String>[];

    Future<void> addOrChangeRoster() => _onRosterHeaderAction(
      context,
      ref,
      hasRoster: hasRoster,
      rosterId: primaryRosterId,
    );

    final List<Widget> sections = <Widget>[
      _StaffProfileBlock(detail: detail),
      HrStaffDetailActions(
        state: state,
        detail: detail,
        onAssignDepartment: showHrAssignDepartmentDialog,
        onAssignPosition: showHrAssignPositionDialog,
        onRoster: (BuildContext context, WidgetRef ref) =>
            unawaited(addOrChangeRoster()),
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
        onManagePayroll:
            (BuildContext context, WidgetRef ref, HrStaffDetail staffDetail) =>
                showHrStaffPayrollManagementDialog(
                  context,
                  ref,
                  staffDetail.profile,
                  staffDetail.compensations,
                ),
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
                  onOpenPayroll: () => showHrStaffPayrollManagementDialog(
                    context,
                    ref,
                    d.profile,
                    d.compensations,
                  ),
                ),
      ),
      AppCollapsibleSection(
        title: l10n.hrStaffRostersSectionTitle,
        titleIcon: Icons.calendar_month_outlined,
        initiallyExpanded: hasRoster,
        headerActions: <Widget>[
          if (canRosterWrite &&
              !profile.isSeparated &&
              !state.isMutating &&
              hasRoster)
            AppButton.secondary(
              label: hrStaffRosterActionLabel(l10n, rosterKind),
              leadingIcon: Icons.edit_calendar_outlined,
              onPressed: () => unawaited(addOrChangeRoster()),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (rosterEmpty)
              AppStateView(
                variant: AppStateViewVariant.empty,
                title: l10n.hrStaffRostersEmptyTitle,
                body: l10n.hrStaffRostersEmptyBody,
                icon: Icons.event_available_outlined,
                action: canRosterWrite && !profile.isSeparated && !state.isMutating
                    ? AppButton.primary(
                        label: hrStaffRosterActionLabel(l10n, rosterKind),
                        leadingIcon: Icons.add_outlined,
                        onPressed: () => unawaited(addOrChangeRoster()),
                      )
                    : null,
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
          ],
        ),
      ),
      AppCollapsibleSection(
        title: l10n.hrStaffLeavesSectionTitle,
        titleIcon: Icons.event_busy_outlined,
        initiallyExpanded: false,
        headerActions: <Widget>[
          if (canWrite &&
              !profile.isSeparated &&
              !state.isMutating &&
              detail.leaves.isNotEmpty)
            AppButton.secondary(
              label: l10n.hrRequestLeaveAction,
              leadingIcon: Icons.event_busy_outlined,
              onPressed: () =>
                  unawaited(showHrRequestLeaveDialog(context, ref)),
            ),
        ],
        child: detail.leaves.isEmpty
            ? AppStateView(
                variant: AppStateViewVariant.empty,
                title: l10n.hrNoLeaveLabel,
                body: l10n.hrStaffLeavesEmptyBody,
                icon: Icons.event_available_outlined,
                action: canWrite && !profile.isSeparated && !state.isMutating
                    ? AppButton.primary(
                        label: l10n.hrRequestLeaveAction,
                        leadingIcon: Icons.event_busy_outlined,
                        onPressed: () =>
                            unawaited(showHrRequestLeaveDialog(context, ref)),
                      )
                    : null,
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
        initiallyExpanded: false,
        headerActions: <Widget>[
          if (!state.isMutating) ...<Widget>[
            if (canWrite && activeCompensations.isNotEmpty)
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
            if (canPayroll)
              AppButton.primary(
                label: l10n.hrManagePayrollAction,
                leadingIcon: Icons.account_balance_wallet_outlined,
                onPressed: () => unawaited(
                  showHrStaffPayrollManagementDialog(
                    context,
                    ref,
                    profile,
                    detail.compensations,
                  ),
                ),
              ),
          ],
        ],
        child: activeCompensations.isEmpty && profile.consultationFee == null
            ? AppStateView(
                variant: AppStateViewVariant.empty,
                title: l10n.hrNoCompensationLabel,
                body: l10n.hrStaffPayrollEmptyBody,
                icon: Icons.price_change_outlined,
                action: canWrite && !state.isMutating
                    ? AppButton.primary(
                        label: canPayroll
                            ? l10n.hrManagePayrollAction
                            : l10n.hrCompensationAction,
                        leadingIcon: canPayroll
                            ? Icons.account_balance_wallet_outlined
                            : Icons.price_change_outlined,
                        onPressed: () => unawaited(
                          canPayroll
                              ? showHrStaffPayrollManagementDialog(
                                  context,
                                  ref,
                                  profile,
                                  detail.compensations,
                                )
                              : showHrCompensationDialog(
                                  context,
                                  ref,
                                  profile,
                                  detail.compensations,
                                ),
                        ),
                      )
                    : null,
              )
            : _PayrollSummary(
                profile: profile,
                compensations: activeCompensations,
              ),
      ),
      AppCollapsibleSection(
        title: l10n.hrRolesSectionTitle,
        titleIcon: Icons.badge_outlined,
        initiallyExpanded: false,
        headerActions: <Widget>[
          AppButton.secondary(
            label: l10n.hrManageRolesAction,
            leadingIcon: Icons.manage_accounts_outlined,
            onPressed: () => unawaited(
              showManageRolesPermissionsDialog(
                context,
                ref,
              ),
            ),
          ),
        ],
        child: roles.isEmpty
            ? AppStateView(
                variant: AppStateViewVariant.empty,
                title: l10n.hrNoRolesLabel,
                body: l10n.hrStaffRolesEmptyBody,
                icon: Icons.badge_outlined,
                action: AppButton.primary(
                  label: l10n.hrManageRolesAction,
                  leadingIcon: Icons.manage_accounts_outlined,
                  onPressed: () => unawaited(
                    showManageRolesPermissionsDialog(
                      context,
                      ref,
                    ),
                  ),
                ),
              )
            : Wrap(
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
      ),
      AppCollapsibleSection(
        title: l10n.hrStaffPermissionsSectionTitle,
        titleIcon: Icons.shield_outlined,
        initiallyExpanded: false,
        headerActions: <Widget>[
          AppButton.secondary(
            label: l10n.hrManageUserPermissionsAction,
            leadingIcon: Icons.lock_open_outlined,
            onPressed: () => unawaited(_openUserPermissions(context, ref)),
          ),
        ],
        child: permissions.isEmpty
            ? AppStateView(
                variant: AppStateViewVariant.empty,
                title: l10n.hrStaffPermissionsEmptyTitle,
                body: l10n.hrStaffPermissionsEmptyBody,
                icon: Icons.shield_outlined,
                action: AppButton.primary(
                  label: l10n.hrManageUserPermissionsAction,
                  leadingIcon: Icons.lock_open_outlined,
                  onPressed: () =>
                      unawaited(_openUserPermissions(context, ref)),
                ),
              )
            : Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  for (final String permission in permissions.take(24))
                    Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Text(
                        permission,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  if (permissions.length > 24)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        l10n.hrStaffPermissionsMoreLabel(
                          permissions.length - 24,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: appCollapsibleSectionSpacing(context, sections),
    );
  }

  Future<void> _openUserPermissions(BuildContext context, WidgetRef ref) async {
    final HrStaffProfile profile = detail.profile;
    final String userId =
        (profile.userDisplayId ?? profile.userId ?? '').trim();
    if (userId.isEmpty) {
      await showManageUsersDialog(context, ref);
      return;
    }
    await showHrAccessUserDetailDialog(
      context,
      ref,
      HrAccessUser(
        id: userId,
        displayId: profile.userDisplayId,
        email: profile.userEmail,
        profileName: profile.displayName,
        staffProfileId: profile.effectiveId,
        staffProfileName: profile.displayName,
      ),
    );
  }

  Future<void> _onRosterHeaderAction(
    BuildContext context,
    WidgetRef ref, {
    required bool hasRoster,
    required String? rosterId,
  }) async {
    final bool saved = await showHrAssignRosterDialog(
      context,
      ref,
      staff: detail.profile,
      currentRosterId: hasRoster ? rosterId : null,
    );
    if (saved && context.mounted) {
      showHrMutationSnackBar(context, null);
      await ref
          .read(hrWorkspaceControllerProvider.notifier)
          .selectStaff(detail.profile);
    }
  }
}

class _StaffProfileBlock extends ConsumerWidget {
  const _StaffProfileBlock({required this.detail});

  final HrStaffDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final HrStaffProfile profile = detail.profile;
    final bool hasLinkedUser =
        (profile.userEmail ?? profile.userDisplayId ?? profile.userId ?? '')
            .trim()
            .isNotEmpty;

    return AppPatientDetails(
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

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      children: <Widget>[
        for (final _PayrollMetric metric in metrics)
          _MetricChip(metric: metric),
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
