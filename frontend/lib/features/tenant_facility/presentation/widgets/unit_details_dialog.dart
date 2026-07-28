import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<bool?> showUnitDetailsDialog(
  BuildContext context, {
  required UnitProfile unit,
  String? tenantName,
  String? facilityName,
  String? departmentName,
  FacilitySetupSnapshot? snapshot,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => _UnitDetailsDialog(
      unit: unit,
      tenantName: tenantName,
      facilityName: facilityName,
      departmentName: departmentName,
      snapshot: snapshot,
    ),
  );
}

class _UnitDetailsDialog extends ConsumerStatefulWidget {
  const _UnitDetailsDialog({
    required this.unit,
    this.tenantName,
    this.facilityName,
    this.departmentName,
    this.snapshot,
  });

  final UnitProfile unit;
  final String? tenantName;
  final String? facilityName;
  final String? departmentName;
  final FacilitySetupSnapshot? snapshot;

  @override
  ConsumerState<_UnitDetailsDialog> createState() => _UnitDetailsDialogState();
}

class _UnitDetailsDialogState extends ConsumerState<_UnitDetailsDialog> {
  static const String _emptyValue = '—';

  late UnitProfile _unit;
  bool _mutated = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _unit = widget.unit;
  }

  bool get _canEditStructure =>
      ref.read(appAccessPolicyProvider).canEditFacilitySetupStructure();

  bool get _canMutate => _canEditStructure && !_unit.isDeleted && !_busy;

  FacilitySetupSnapshot? get _effectiveSnapshot {
    final AsyncValue<Result<FacilitySetupSnapshot>> setup =
        ref.read(tenantFacilitySetupControllerProvider);
    final FacilitySetupSnapshot? fromController = setup.value?.when(
      success: (FacilitySetupSnapshot value) => value,
      failure: (_) => null,
    );
    return fromController ?? widget.snapshot;
  }

  String _statusLabel(AppLocalizations l10n) {
    if (_unit.isDeleted) {
      return l10n.tenantFacilityStructureDeletedStatus;
    }
    return _unit.isActive
        ? l10n.tenantFacilityStatusActive
        : l10n.tenantFacilityStatusInactive;
  }

  AppWorkspaceStatusTone _statusTone() {
    if (_unit.isDeleted) {
      return AppWorkspaceStatusTone.error;
    }
    return _unit.isActive
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.neutral;
  }

  String _resolveTenantName() {
    final String? provided = widget.tenantName?.trim();
    if (provided != null && provided.isNotEmpty && provided != _emptyValue) {
      return provided;
    }
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    final TenantProfile? tenant = snapshot?.tenant;
    if (tenant != null && tenant.id == _unit.tenantId) {
      return tenant.name;
    }
    return _emptyValue;
  }

  String? _resolveFacilityName() {
    final String? provided = widget.facilityName?.trim();
    if (provided != null &&
        provided.isNotEmpty &&
        provided != _emptyValue) {
      return provided;
    }
    final String? facilityId = _unit.facilityId?.trim();
    if (facilityId == null || facilityId.isEmpty) {
      return null;
    }
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot == null) {
      return null;
    }
    final FacilityProfile? facility = snapshot.facility;
    if (facility != null && facility.id == facilityId) {
      return facility.name;
    }
    for (final FacilityProfile item in snapshot.facilities) {
      if (item.id == facilityId) {
        return item.name;
      }
    }
    return null;
  }

  String _resolveDepartmentName() {
    final String? provided = widget.departmentName?.trim();
    if (provided != null &&
        provided.isNotEmpty &&
        provided != _emptyValue) {
      return provided;
    }
    final String? departmentId = _unit.departmentId?.trim();
    if (departmentId == null || departmentId.isEmpty) {
      return _emptyValue;
    }
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot == null) {
      return departmentId;
    }
    for (final DepartmentProfile department in snapshot.departments) {
      if (department.id == departmentId) {
        return department.name;
      }
    }
    return departmentId;
  }

  UnitProfile? _findUnitInSetup() {
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot == null) {
      return null;
    }
    for (final UnitProfile item in snapshot.units) {
      if (item.id == _unit.id) {
        return item;
      }
    }
    return null;
  }

  void _refreshUnitAfterMutation() {
    final Object? saved =
        ref.read(tenantFacilitySetupSubmissionProvider).lastSavedEntity;
    if (saved is UnitProfile && saved.id == _unit.id) {
      setState(() {
        _unit = saved;
      });
      return;
    }

    final UnitProfile? updated = _findUnitInSetup();
    if (updated != null) {
      setState(() {
        _unit = updated;
      });
    }
  }

  Future<void> _editUnit() async {
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot == null || _busy) {
      return;
    }

    final int versionBefore =
        ref.read(tenantFacilitySetupSubmissionProvider).successVersion;

    setState(() {
      _busy = true;
    });
    try {
      await showTenantFacilityUnitFormDialog(
        context,
        snapshot,
        unit: _unit,
        openDetailsOnSave: false,
      );
      if (!mounted) {
        return;
      }

      final TenantFacilitySetupSubmissionState submission =
          ref.read(tenantFacilitySetupSubmissionProvider);
      if (submission.successVersion <= versionBefore) {
        return;
      }

      _mutated = true;
      _refreshUnitAfterMutation();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteUnit() async {
    if (_busy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilitySoftDeleteStructureTitle,
        body: l10n.tenantFacilitySoftDeleteStructureBody(_unit.name),
        highlightedText: _unit.name,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final bool deleted = await ref
              .read(tenantFacilitySetupSubmissionProvider.notifier)
              .deleteUnit(_unit.id);
          if (deleted) {
            return null;
          }
          return ref.read(tenantFacilitySetupSubmissionProvider).failure ??
              const AppFailure.unexpected();
        },
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String statusLabel = _statusLabel(l10n);
    final String? facilityName = _resolveFacilityName();
    final String departmentName = _resolveDepartmentName();

    final List<_UnitDetailFact> facts = <_UnitDetailFact>[
      _UnitDetailFact(
        label: l10n.tenantFacilityUnitNameLabel,
        value: _unit.name,
        icon: Icons.badge_outlined,
      ),
      _UnitDetailFact(
        label: l10n.tenantFacilityUnitDepartmentLabel,
        value: departmentName,
        icon: Icons.domain_outlined,
      ),
      _UnitDetailFact(
        label: l10n.tenantFacilityTenantStatusLabel,
        value: statusLabel,
        icon: Icons.toggle_on_outlined,
      ),
      _UnitDetailFact(
        label: l10n.profileTenantLabel,
        value: _resolveTenantName(),
        icon: Icons.apartment_outlined,
      ),
      if (facilityName != null)
        _UnitDetailFact(
          label: l10n.profileFacilityLabel,
          value: facilityName,
          icon: Icons.local_hospital_outlined,
        ),
    ];

    return AppDialog(
      title: Text(l10n.tenantFacilityUnitDetailsTitle),
      icon: const Icon(Icons.account_tree_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 720,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(theme.radius.md),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(theme.radius.sm),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(theme.spacing.sm),
                      child: Icon(
                        Icons.account_tree_outlined,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: theme.spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _unit.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: theme.spacing.xs),
                        Wrap(
                          spacing: theme.spacing.sm,
                          runSpacing: theme.spacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            _UnitStatusBadge(
                              label: statusLabel,
                              tone: _statusTone(),
                            ),
                            if (departmentName != _emptyValue)
                              Text(
                                departmentName,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: theme.spacing.md),
          if (_busy)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.md),
              child: const Center(
                child: AppLoadingIndicator.compact(expand: false),
              ),
            ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              final int columns = width >= 640
                  ? 3
                  : width >= 420
                  ? 2
                  : 1;
              final double gap = theme.spacing.sm;
              final double tileWidth =
                  (width - (gap * (columns - 1))) / columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: <Widget>[
                  for (final _UnitDetailFact fact in facts)
                    SizedBox(
                      width: tileWidth,
                      child: _UnitFactTile(fact: fact),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      actions: <Widget>[
        if (_canEditStructure && !_unit.isDeleted)
          AppButton.secondary(
            label: l10n.tenantFacilityEditUnitDetailsAction,
            leadingIcon: Icons.edit_outlined,
            enabled: _canMutate,
            onPressed: () => unawaited(_editUnit()),
          ),
        if (_canEditStructure && !_unit.isDeleted)
          AppButton.primary(
            label: l10n.tenantFacilityDeleteUnitDetailsAction,
            leadingIcon: Icons.delete_outline,
            color: colorScheme.error,
            enabled: _canMutate,
            isLoading: _busy,
            onPressed: () => unawaited(_deleteUnit()),
          ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          enabled: !_busy,
          onPressed: () => Navigator.of(context).pop(_mutated ? true : null),
        ),
      ],
    );
  }
}

final class _UnitDetailFact {
  const _UnitDetailFact({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _UnitFactTile extends StatelessWidget {
  const _UnitFactTile({required this.fact});

  final _UnitDetailFact fact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              fact.icon,
              size: 18,
              color: colorScheme.primary,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    fact.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs / 2),
                  Text(
                    fact.value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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

class _UnitStatusBadge extends StatelessWidget {
  const _UnitStatusBadge({required this.label, required this.tone});

  final String label;
  final AppWorkspaceStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color foreground = switch (tone) {
      AppWorkspaceStatusTone.success => colorScheme.primary,
      AppWorkspaceStatusTone.error => colorScheme.error,
      AppWorkspaceStatusTone.warning => colorScheme.tertiary,
      AppWorkspaceStatusTone.info => colorScheme.secondary,
      AppWorkspaceStatusTone.neutral => colorScheme.onSurfaceVariant,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: foreground.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
