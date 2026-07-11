import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
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
    this.onManageTenants,
    this.onManageFacilities,
    this.onSelectFacility,
    this.onOpenCatalog,
    super.key,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canManageTenant;
  final bool canManageFacility;
  final bool canCreateTenant;
  final ValueChanged<TenantFacilitySetupWizardStep> onOpenStep;
  final VoidCallback? onManageTenants;
  final VoidCallback? onManageFacilities;
  final ValueChanged<String>? onSelectFacility;
  final VoidCallback? onOpenCatalog;

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

  void _advanceFrom(TenantFacilitySetupWizardStep current) {
    final List<TenantFacilitySetupWizardStep> steps = _steps;
    final int currentIndex = steps.indexOf(current);
    if (currentIndex < 0) {
      return;
    }
    final int nextIndex = currentIndex + 1;
    if (nextIndex < steps.length &&
        tenantFacilityWizardStepReachable(
          widget.snapshot,
          steps,
          steps[nextIndex],
        )) {
      _selectStep(steps[nextIndex]);
      return;
    }
    final TenantFacilitySetupWizardStep? nextIncomplete =
        tenantFacilityNextIncompleteWizardStep(
          widget.snapshot,
          steps: steps,
        );
    if (nextIncomplete != null && nextIncomplete != current) {
      _selectStep(nextIncomplete);
    }
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
    final bool hasRecords = tenantFacilityWizardStepHasRecords(
      widget.snapshot,
      current,
    );
    final TenantFacilitySetupWizardStep? nextStep = currentIndex + 1 < steps.length
        ? steps[currentIndex + 1]
        : null;
    final bool nextReachable = nextStep != null &&
        tenantFacilityWizardStepReachable(
          widget.snapshot,
          steps,
          nextStep,
        );

    // Optional empty: Skip for now. Otherwise continue to next when reachable.
    final VoidCallback? navigationAction;
    final String? navigationLabel;
    final IconData? navigationIcon;
    if (currentOptional && !hasRecords) {
      navigationAction = () => _advanceFrom(current);
      navigationLabel = l10n.tenantFacilitySkipOptionalAction;
      navigationIcon = Icons.skip_next_outlined;
    } else if (nextStep != null && nextReachable) {
      final TenantFacilitySetupWizardStep continueStep = nextStep;
      navigationAction = () => _selectStep(continueStep);
      navigationLabel = tenantFacilityWizardContinueToStepLabel(
        l10n,
        continueStep,
      );
      navigationIcon = Icons.arrow_forward;
    } else {
      navigationAction = null;
      navigationLabel = null;
      navigationIcon = null;
    }

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
                progressCaption: tenantFacilityWizardProgressCaption(
                  currentIndex: currentIndex,
                  totalSteps: steps.length,
                  stepLabel: tenantFacilityWizardStepLabel(l10n, current),
                  optional: currentOptional,
                ),
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
            hasRecords: hasRecords,
            canManageTenant: widget.canManageTenant,
            canCreateTenant: widget.canCreateTenant,
            canManageFacility: widget.canManageFacility,
            onOpenStep: () => widget.onOpenStep(current),
            onManageTenants: widget.onManageTenants,
            onManageFacilities: widget.onManageFacilities,
            onSelectFacility: widget.onSelectFacility,
            onOpenCatalog: widget.onOpenCatalog,
            navigationLabel: navigationLabel,
            navigationIcon: navigationIcon,
            onNavigate: navigationAction,
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
    required this.hasRecords,
    required this.canManageTenant,
    required this.canCreateTenant,
    required this.canManageFacility,
    required this.onOpenStep,
    this.onManageTenants,
    this.onManageFacilities,
    this.onSelectFacility,
    this.onOpenCatalog,
    this.navigationLabel,
    this.navigationIcon,
    this.onNavigate,
  });

  final TenantFacilitySetupWizardStep step;
  final FacilitySetupSnapshot snapshot;
  final bool optional;
  final bool completed;
  final bool hasRecords;
  final bool canManageTenant;
  final bool canCreateTenant;
  final bool canManageFacility;
  final VoidCallback onOpenStep;
  final VoidCallback? onManageTenants;
  final VoidCallback? onManageFacilities;
  final ValueChanged<String>? onSelectFacility;
  final VoidCallback? onOpenCatalog;
  final String? navigationLabel;
  final IconData? navigationIcon;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String title = tenantFacilityWizardStepLabel(l10n, step);
    final bool wide = AppBreakpoints.of(context).index >= AppBreakpoint.md.index;

    final List<Widget> actions = <Widget>[
      AppButton.primary(
        label: tenantFacilityWizardPrimaryActionLabel(
          l10n,
          step: step,
          snapshot: snapshot,
          canCreateTenant: canCreateTenant,
        ),
        leadingIcon: tenantFacilityWizardPrimaryActionIcon(
          step: step,
          snapshot: snapshot,
        ),
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
      if (step == TenantFacilitySetupWizardStep.facility &&
          snapshot.facility?.id != null &&
          onOpenCatalog != null)
        AppButton.tertiary(
          label: l10n.clinicalCatalogConfigurationTitle,
          leadingIcon: Icons.medical_information_outlined,
          onPressed: onOpenCatalog,
        ),
      if (onNavigate != null && navigationLabel != null)
        AppButton.tertiary(
          label: navigationLabel!,
          leadingIcon: navigationIcon ?? Icons.arrow_forward,
          onPressed: onNavigate,
        ),
    ];

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
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _headerIdentity(l10n, theme, colorScheme, title)),
                  SizedBox(width: theme.spacing.md),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Wrap(
                        spacing: theme.spacing.sm,
                        runSpacing: theme.spacing.sm,
                        alignment: WrapAlignment.end,
                        children: actions,
                      ),
                    ),
                  ),
                ],
              )
            else ...<Widget>[
              _headerIdentity(l10n, theme, colorScheme, title),
              SizedBox(height: theme.spacing.md),
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: actions,
              ),
            ],
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
            _SetupStepRecordsTable(
              step: step,
              snapshot: snapshot,
              onOpenStep: onOpenStep,
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

  Widget _headerIdentity(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
    String title,
  ) {
    return Row(
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
                tenantFacilityWizardStepSummary(l10n, snapshot, step),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupStepRecordsTable extends StatelessWidget {
  const _SetupStepRecordsTable({
    required this.step,
    required this.snapshot,
    required this.onOpenStep,
  });

  final TenantFacilitySetupWizardStep step;
  final FacilitySetupSnapshot snapshot;
  final VoidCallback onOpenStep;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return switch (step) {
      TenantFacilitySetupWizardStep.tenant => _singleRecordTable(
          context,
          l10n: l10n,
          name: snapshot.tenant?.name,
          status: snapshot.tenant == null
              ? null
              : tenantFacilityActiveStatusLabel(
                  l10n,
                  snapshot.tenant!.isActive,
                ),
          emptyMessage: tenantFacilityWizardStepEmptyMessage(l10n, step),
        ),
      TenantFacilitySetupWizardStep.facility => _singleRecordTable(
          context,
          l10n: l10n,
          name: snapshot.facility?.name,
          status: snapshot.facility == null
              ? null
              : tenantFacilityFacilityTypeLabel(l10n, snapshot.facility!.type),
          emptyMessage: tenantFacilityWizardStepEmptyMessage(l10n, step),
        ),
      TenantFacilitySetupWizardStep.branches => _listTable<BranchProfile>(
          context,
          l10n: l10n,
          items: snapshot.branches,
          nameOf: (BranchProfile item) => item.name,
          statusOf: (BranchProfile item) =>
              tenantFacilityActiveStatusLabel(l10n, item.isActive),
          emptyMessage: l10n.tenantFacilityNoBranches,
        ),
      TenantFacilitySetupWizardStep.departments =>
        _listTable<DepartmentProfile>(
          context,
          l10n: l10n,
          items: snapshot.departments,
          nameOf: (DepartmentProfile item) => item.name,
          statusOf: (DepartmentProfile item) =>
              tenantFacilityDepartmentTypeLabel(l10n, item.type),
          emptyMessage: l10n.tenantFacilityNoDepartments,
        ),
      TenantFacilitySetupWizardStep.units => _listTable<UnitProfile>(
          context,
          l10n: l10n,
          items: snapshot.units,
          nameOf: (UnitProfile item) => item.name,
          statusOf: (UnitProfile item) =>
              tenantFacilityActiveStatusLabel(l10n, item.isActive),
          emptyMessage: l10n.tenantFacilityNoUnits,
        ),
      TenantFacilitySetupWizardStep.wards => _listTable<WardProfile>(
          context,
          l10n: l10n,
          items: snapshot.wards,
          nameOf: (WardProfile item) => item.name,
          statusOf: (WardProfile item) =>
              tenantFacilityWardTypeLabel(l10n, item.type),
          emptyMessage: l10n.tenantFacilityNoWards,
        ),
      TenantFacilitySetupWizardStep.rooms => _listTable<RoomProfile>(
          context,
          l10n: l10n,
          items: snapshot.rooms,
          nameOf: (RoomProfile item) => item.name,
          statusOf: (RoomProfile item) => item.floor?.trim().isNotEmpty == true
              ? item.floor!
              : '—',
          emptyMessage: l10n.tenantFacilityNoRooms,
        ),
      TenantFacilitySetupWizardStep.beds => _listTable<BedProfile>(
          context,
          l10n: l10n,
          items: snapshot.beds,
          nameOf: (BedProfile item) => item.label,
          statusOf: (BedProfile item) =>
              tenantFacilityBedStatusLabel(l10n, item.status),
          emptyMessage: l10n.tenantFacilityNoBeds,
        ),
    };
  }

  Widget _singleRecordTable(
    BuildContext context, {
    required AppLocalizations l10n,
    required String? name,
    required String? status,
    required String emptyMessage,
  }) {
    if (name == null || name.trim().isEmpty) {
      return _SetupEmptyRecords(message: emptyMessage);
    }

    return _listTable<_NamedStatusRow>(
      context,
      l10n: l10n,
      items: <_NamedStatusRow>[
        _NamedStatusRow(name: name, status: status ?? '—'),
      ],
      nameOf: (_NamedStatusRow item) => item.name,
      statusOf: (_NamedStatusRow item) => item.status,
      emptyMessage: emptyMessage,
    );
  }

  Widget _listTable<T>(
    BuildContext context, {
    required AppLocalizations l10n,
    required List<T> items,
    required String Function(T item) nameOf,
    required String Function(T item) statusOf,
    required String emptyMessage,
  }) {
    final ThemeData theme = Theme.of(context);
    if (items.isEmpty) {
      return _SetupEmptyRecords(message: emptyMessage);
    }

    return SizedBox(
      height: items.length > 6 ? 320 : null,
      child: AppListTable<T>(
        items: items,
        shrinkWrap: items.length <= 6,
        physics: items.length <= 6
            ? const NeverScrollableScrollPhysics()
            : null,
        maxVisibleItems: 8,
        displayMode: AppListTableDisplayMode.table,
        itemKeyBuilder: (T item) => ValueKey<String>(nameOf(item)),
        onRowSelected: (_) => onOpenStep(),
        emptyBuilder: (_) => _SetupEmptyRecords(message: emptyMessage),
        columns: <AppListTableColumn<T>>[
          AppListTableColumn<T>(
            label: l10n.tenantFacilityTenantNameLabel,
            cellBuilder: (_, T item) => Text(nameOf(item)),
          ),
          AppListTableColumn<T>(
            label: l10n.tenantFacilityTenantStatusLabel,
            cellBuilder: (_, T item) => Text(statusOf(item)),
          ),
        ],
        mobileItemBuilder: (BuildContext context, T item) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(nameOf(item)),
            subtitle: Text(statusOf(item)),
            trailing: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onTap: onOpenStep,
          );
        },
      ),
    );
  }
}

class _SetupEmptyRecords extends StatelessWidget {
  const _SetupEmptyRecords({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.lg,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _NamedStatusRow {
  const _NamedStatusRow({required this.name, required this.status});

  final String name;
  final String status;
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
