import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class TenantFacilitySetupWizard extends StatefulWidget {
  const TenantFacilitySetupWizard({
    required this.snapshot,
    required this.canManageTenant,
    required this.canManageFacility,
    required this.canCreateTenant,
    required this.onOpenStep,
    this.onSkipOptional,
    this.onManageTenants,
    this.onManageFacilities,
    this.onSelectFacility,
    super.key,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canManageTenant;
  final bool canManageFacility;
  final bool canCreateTenant;
  final ValueChanged<TenantFacilitySetupWizardStep> onOpenStep;
  final ValueChanged<TenantFacilitySetupWizardStep>? onSkipOptional;
  final VoidCallback? onManageTenants;
  final VoidCallback? onManageFacilities;
  final ValueChanged<String>? onSelectFacility;

  @override
  State<TenantFacilitySetupWizard> createState() =>
      _TenantFacilitySetupWizardState();
}

class _TenantFacilitySetupWizardState extends State<TenantFacilitySetupWizard> {
  TenantFacilitySetupWizardStep? _selectedStep;

  List<TenantFacilitySetupWizardStep> get _steps {
    return tenantFacilityVisibleWizardSteps(
      canManageTenant: widget.canManageTenant,
      canManageFacility: widget.canManageFacility,
    );
  }

  TenantFacilitySetupWizardStep get _currentStep {
    final List<TenantFacilitySetupWizardStep> steps = _steps;
    if (steps.isEmpty) {
      return TenantFacilitySetupWizardStep.facility;
    }
    final TenantFacilitySetupWizardStep? selected = _selectedStep;
    if (selected != null &&
        steps.contains(selected) &&
        tenantFacilityWizardStepReachable(widget.snapshot, steps, selected)) {
      return selected;
    }
    return tenantFacilityNextIncompleteWizardStep(
          widget.snapshot,
          steps: steps,
        ) ??
        steps.last;
  }

  @override
  void didUpdateWidget(covariant TenantFacilitySetupWizard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final TenantFacilitySetupWizardStep? selected = _selectedStep;
    if (selected == null) {
      return;
    }
    if (!_steps.contains(selected) ||
        !tenantFacilityWizardStepReachable(
          widget.snapshot,
          _steps,
          selected,
        )) {
      _selectedStep = null;
    }
  }

  void _selectStep(TenantFacilitySetupWizardStep step) {
    if (!tenantFacilityWizardStepReachable(widget.snapshot, _steps, step)) {
      return;
    }
    setState(() => _selectedStep = step);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<TenantFacilitySetupWizardStep> steps = _steps;
    if (steps.isEmpty) {
      return AppScreenSection(
        title: l10n.tenantFacilityWizardTitle,
        body: l10n.tenantFacilityPermissionRequired,
        child: const SizedBox.shrink(),
      );
    }

    final TenantFacilitySetupWizardStep current = _currentStep;
    final int currentIndex = steps.indexOf(current).clamp(0, steps.length - 1);
    final bool currentOptional = tenantFacilityWizardStepOptional(current);
    final bool currentCompleted = tenantFacilityWizardStepCompleted(
      widget.snapshot,
      current,
    );
    final TenantFacilitySetupWizardStep? nextStep =
        tenantFacilityNextIncompleteWizardStep(
          widget.snapshot,
          steps: steps,
        );

    return AppScreenSection(
      title: l10n.tenantFacilityWizardTitle,
      body: l10n.tenantFacilityWizardBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(theme.radius.md),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.md,
                theme.spacing.md,
                theme.spacing.md,
                theme.spacing.sm,
              ),
              child: AppWizardStepper(
                steps: <AppWizardStepItem>[
                  for (final TenantFacilitySetupWizardStep step in steps)
                    AppWizardStepItem(
                      id: step,
                      label: tenantFacilityWizardStepLabel(l10n, step),
                      optional: tenantFacilityWizardStepOptional(step),
                      completed: tenantFacilityWizardStepCompleted(
                        widget.snapshot,
                        step,
                      ),
                      enabled: tenantFacilityWizardStepReachable(
                        widget.snapshot,
                        steps,
                        step,
                      ),
                    ),
                ],
                currentIndex: currentIndex,
                showCurrentTitle: false,
                onStepSelected: (int index) => _selectStep(steps[index]),
              ),
            ),
          ),
          SizedBox(height: theme.spacing.lg),
          _SetupStepPanel(
            step: current,
            snapshot: widget.snapshot,
            optional: currentOptional,
            completed: currentCompleted,
            canManageTenant: widget.canManageTenant,
            canCreateTenant: widget.canCreateTenant,
            canManageFacility: widget.canManageFacility,
            onOpenStep: () => widget.onOpenStep(current),
            onSkipOptional: currentOptional && !currentCompleted
                ? () {
                    final int nextIndex = currentIndex + 1;
                    if (nextIndex < steps.length &&
                        tenantFacilityWizardStepReachable(
                          widget.snapshot,
                          steps,
                          steps[nextIndex],
                        )) {
                      _selectStep(steps[nextIndex]);
                    } else if (nextStep != null) {
                      _selectStep(nextStep);
                    }
                    widget.onSkipOptional?.call(current);
                  }
                : null,
            onManageTenants: widget.onManageTenants,
            onManageFacilities: widget.onManageFacilities,
            onSelectFacility: widget.onSelectFacility,
            onContinue: nextStep != null && nextStep != current
                ? () => _selectStep(nextStep)
                : null,
          ),
        ],
      ),
    );
  }
}

class _SetupStepPanel extends StatelessWidget {
  const _SetupStepPanel({
    required this.step,
    required this.snapshot,
    required this.optional,
    required this.completed,
    required this.canManageTenant,
    required this.canCreateTenant,
    required this.canManageFacility,
    required this.onOpenStep,
    this.onSkipOptional,
    this.onManageTenants,
    this.onManageFacilities,
    this.onSelectFacility,
    this.onContinue,
  });

  final TenantFacilitySetupWizardStep step;
  final FacilitySetupSnapshot snapshot;
  final bool optional;
  final bool completed;
  final bool canManageTenant;
  final bool canCreateTenant;
  final bool canManageFacility;
  final VoidCallback onOpenStep;
  final VoidCallback? onSkipOptional;
  final VoidCallback? onManageTenants;
  final VoidCallback? onManageFacilities;
  final ValueChanged<String>? onSelectFacility;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String title = tenantFacilityWizardStepLabel(l10n, step);
    final String summary = tenantFacilityWizardStepSummary(
      l10n,
      snapshot,
      step,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colorScheme.primary.withValues(alpha: 0.06),
            colorScheme.surfaceContainerLowest,
            colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(theme.radius.lg),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(theme.radius.md),
                  ),
                  child: Icon(
                    tenantFacilityWizardStepIcon(step),
                    color: colorScheme.primary,
                  ),
                ),
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: theme.spacing.sm,
                        runSpacing: theme.spacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (optional)
                            _StepBadge(
                              label: 'Optional',
                              tone: colorScheme.tertiary,
                            ),
                          _StepBadge(
                            label: completed
                                ? l10n.tenantFacilityStatusActive
                                : l10n.nursingChecklistPendingStatus,
                            tone: completed
                                ? theme.statusColors.success
                                : colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacing.xs),
                      Text(
                        summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (step == TenantFacilitySetupWizardStep.tenant &&
                canCreateTenant) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              _SetupTenantContextPicker(selectedTenantId: snapshot.tenant?.id),
            ],
            if (step == TenantFacilitySetupWizardStep.facility &&
                snapshot.facilities.length > 1 &&
                onSelectFacility != null) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              AppSelectField<String>(
                labelText: l10n.tenantFacilityFacilitySectionTitle,
                value: snapshot.facility?.id,
                allowClear: false,
                options: <AppSelectOption<String>>[
                  for (final FacilityProfile facility in snapshot.facilities)
                    AppSelectOption<String>(
                      value: facility.id,
                      label: facility.name,
                    ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    onSelectFacility!(value);
                  }
                },
              ),
            ],
            SizedBox(height: theme.spacing.lg),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                AppButton.primary(
                  label: _primaryActionLabel(l10n),
                  leadingIcon: completed
                      ? Icons.edit_outlined
                      : Icons.add_circle_outline,
                  onPressed: onOpenStep,
                ),
                if (step == TenantFacilitySetupWizardStep.tenant &&
                    canManageTenant &&
                    onManageTenants != null)
                  AppButton.secondary(
                    label: l10n.tenantFacilityManageTenantsTitle,
                    leadingIcon: Icons.corporate_fare_outlined,
                    onPressed: onManageTenants,
                  ),
                if (step == TenantFacilitySetupWizardStep.facility &&
                    canManageFacility &&
                    onManageFacilities != null)
                  AppButton.secondary(
                    label: l10n.tenantFacilityManageFacilitiesTitle,
                    leadingIcon: Icons.domain_outlined,
                    onPressed: onManageFacilities,
                  ),
                if (onSkipOptional != null)
                  AppButton.tertiary(
                    label: l10n.commonNextActionLabel,
                    leadingIcon: Icons.skip_next_outlined,
                    onPressed: onSkipOptional,
                  ),
                if (onContinue != null)
                  AppButton.secondary(
                    label: l10n.tenantFacilityWizardContinueAction,
                    leadingIcon: Icons.play_arrow_outlined,
                    onPressed: onContinue,
                  ),
              ],
            ),
            if (!canManageTenant &&
                step == TenantFacilitySetupWizardStep.tenant) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              AppFormInformationBanner(
                title: l10n.tenantFacilityPermissionsTitle,
                message: l10n.tenantFacilityPermissionRequired,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _primaryActionLabel(AppLocalizations l10n) {
    return switch (step) {
      TenantFacilitySetupWizardStep.tenant => completed
          ? l10n.tenantFacilityEditTenantAction
          : (canCreateTenant
                ? l10n.tenantFacilityCreateTenantAction
                : l10n.tenantFacilityEditTenantAction),
      TenantFacilitySetupWizardStep.branches =>
        l10n.tenantFacilityBranchesSectionTitle,
      TenantFacilitySetupWizardStep.facility => completed
          ? l10n.tenantFacilityEditFacilityAction
          : l10n.tenantFacilityCreateFacilityTitle,
      TenantFacilitySetupWizardStep.departments =>
        l10n.tenantFacilityDepartmentsListTitle,
      TenantFacilitySetupWizardStep.units => l10n.tenantFacilityUnitsListTitle,
      TenantFacilitySetupWizardStep.wards => l10n.tenantFacilityWardsLabel,
      TenantFacilitySetupWizardStep.rooms => l10n.tenantFacilityRoomsLabel,
      TenantFacilitySetupWizardStep.beds => l10n.tenantFacilityBedsLabel,
    };
  }
}

class _SetupTenantContextPicker extends ConsumerStatefulWidget {
  const _SetupTenantContextPicker({this.selectedTenantId});

  final String? selectedTenantId;

  @override
  ConsumerState<_SetupTenantContextPicker> createState() =>
      _SetupTenantContextPickerState();
}

class _SetupTenantContextPickerState
    extends ConsumerState<_SetupTenantContextPicker> {
  List<TenantProfile> _tenants = const <TenantProfile>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final Result<AppPage<TenantProfile>> result = await ref
        .read(tenantFacilityRepositoryProvider)
        .listTenants(request: const AppPageRequest(pageSize: 100));
    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<TenantProfile> page) {
        setState(() {
          _tenants = page.items
              .where((TenantProfile tenant) => !tenant.isDeleted)
              .toList(growable: false);
          _loading = false;
        });
      },
      failure: (_) {
        setState(() => _loading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (_loading || _tenants.length < 2) {
      return const SizedBox.shrink();
    }

    return AppSelectField<String>(
      labelText: l10n.tenantFacilityTenantSectionTitle,
      value: widget.selectedTenantId,
      allowClear: false,
      options: <AppSelectOption<String>>[
        for (final TenantProfile tenant in _tenants)
          AppSelectOption<String>(value: tenant.id, label: tenant.name),
      ],
      onChanged: (String? value) {
        if (value == null) {
          return;
        }
        unawaited(
          ref
              .read(tenantFacilitySetupControllerProvider.notifier)
              .selectTenant(value),
        );
      },
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: tone,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TenantFacilityPermissionStrip extends StatelessWidget {
  const TenantFacilityPermissionStrip({
    required this.canManageTenant,
    required this.canManageFacility,
    super.key,
  });

  final bool canManageTenant;
  final bool canManageFacility;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Wrap(
                spacing: theme.spacing.md,
                runSpacing: theme.spacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    l10n.tenantFacilityPermissionsTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _PermissionChip(
                    label: l10n.tenantFacilityTenantAdminPermission,
                    allowed: canManageTenant,
                  ),
                  _PermissionChip(
                    label: l10n.tenantFacilityFacilityAdminPermission,
                    allowed: canManageFacility,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.label, required this.allowed});

  final String label;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Color tone = allowed
        ? theme.statusColors.success
        : theme.colorScheme.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          allowed ? Icons.lock_open_outlined : Icons.lock_outline,
          size: 16,
          color: tone,
        ),
        SizedBox(width: theme.spacing.xs),
        Text(
          '$label · ${allowed ? l10n.tenantFacilityPermissionAllowed : l10n.tenantFacilityPermissionDenied}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: tone,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
