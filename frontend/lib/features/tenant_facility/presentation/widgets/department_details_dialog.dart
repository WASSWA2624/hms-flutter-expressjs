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
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<bool?> showDepartmentDetailsDialog(
  BuildContext context, {
  required DepartmentProfile department,
  String? tenantName,
  String? facilityName,
  FacilitySetupSnapshot? snapshot,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => _DepartmentDetailsDialog(
      department: department,
      tenantName: tenantName,
      facilityName: facilityName,
      snapshot: snapshot,
    ),
  );
}

class _DepartmentDetailsDialog extends ConsumerStatefulWidget {
  const _DepartmentDetailsDialog({
    required this.department,
    this.tenantName,
    this.facilityName,
    this.snapshot,
  });

  final DepartmentProfile department;
  final String? tenantName;
  final String? facilityName;
  final FacilitySetupSnapshot? snapshot;

  @override
  ConsumerState<_DepartmentDetailsDialog> createState() =>
      _DepartmentDetailsDialogState();
}

class _DepartmentDetailsDialogState
    extends ConsumerState<_DepartmentDetailsDialog> {
  static const String _emptyValue = '—';

  late DepartmentProfile _department;
  bool _mutated = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _department = widget.department;
  }

  bool get _canEditStructure =>
      ref.read(appAccessPolicyProvider).canEditFacilitySetupStructure();

  bool get _canMutate => _canEditStructure && !_department.isDeleted && !_busy;

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
    if (_department.isDeleted) {
      return l10n.tenantFacilityStructureDeletedStatus;
    }
    return _department.isActive
        ? l10n.tenantFacilityStatusActive
        : l10n.tenantFacilityStatusInactive;
  }

  AppWorkspaceStatusTone _statusTone() {
    if (_department.isDeleted) {
      return AppWorkspaceStatusTone.error;
    }
    return _department.isActive
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.neutral;
  }

  IconData _typeIcon(DepartmentSetupType type) {
    return switch (type) {
      DepartmentSetupType.clinical => Icons.medical_services_outlined,
      DepartmentSetupType.administrative => Icons.apartment_outlined,
      DepartmentSetupType.support => Icons.support_agent_outlined,
      DepartmentSetupType.diagnostics => Icons.biotech_outlined,
      DepartmentSetupType.other => Icons.category_outlined,
    };
  }

  String _resolveTenantName() {
    final String? provided = widget.tenantName?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    final TenantProfile? tenant = snapshot?.tenant;
    if (tenant != null && tenant.id == _department.tenantId) {
      return tenant.name;
    }
    return _emptyValue;
  }

  String? _resolveFacilityName() {
    final String? provided = widget.facilityName?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    final String? facilityId = _department.facilityId?.trim();
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

  DepartmentProfile? _findDepartmentInSetup() {
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot == null) {
      return null;
    }
    for (final DepartmentProfile item in snapshot.departments) {
      if (item.id == _department.id ||
          item.mutationId == _department.mutationId) {
        return item;
      }
    }
    return null;
  }

  void _refreshDepartmentAfterMutation() {
    final Object? saved =
        ref.read(tenantFacilitySetupSubmissionProvider).lastSavedEntity;
    if (saved is DepartmentProfile &&
        (saved.id == _department.id ||
            saved.mutationId == _department.mutationId)) {
      setState(() {
        _department = saved;
      });
      return;
    }

    final DepartmentProfile? updated = _findDepartmentInSetup();
    if (updated != null) {
      setState(() {
        _department = updated;
      });
    }
  }

  Future<void> _editDepartment() async {
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
      await showTenantFacilityDepartmentFormDialog(
        context,
        snapshot,
        department: _department,
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
      _refreshDepartmentAfterMutation();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteDepartment() async {
    if (_busy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilitySoftDeleteStructureTitle,
        body: l10n.tenantFacilitySoftDeleteStructureBody(_department.name),
        highlightedText: _department.name,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final bool deleted = await ref
              .read(tenantFacilitySetupSubmissionProvider.notifier)
              .deleteDepartment(_department.mutationId);
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
    final String? displayId = tenantFacilityHumanFriendlyDisplayId(
      _department.displayId,
      opaqueId: _department.resourceUuid ?? _department.id,
    );
    final String? facilityName = _resolveFacilityName();
    final String shortName = _department.shortName?.trim().isNotEmpty == true
        ? _department.shortName!.trim()
        : _emptyValue;
    final String typeLabel = _departmentTypeLabel(l10n, _department.type);

    final List<_DepartmentDetailFact> facts = <_DepartmentDetailFact>[
      _DepartmentDetailFact(
        label: l10n.tenantFacilityDepartmentNameLabel,
        value: _department.name,
        icon: Icons.badge_outlined,
      ),
      _DepartmentDetailFact(
        label: l10n.tenantFacilityDepartmentShortNameLabel,
        value: shortName,
        icon: Icons.short_text_outlined,
      ),
      _DepartmentDetailFact(
        label: l10n.tenantFacilityDepartmentTypeLabel,
        value: typeLabel,
        icon: _typeIcon(_department.type),
      ),
      _DepartmentDetailFact(
        label: l10n.tenantFacilityTenantStatusLabel,
        value: statusLabel,
        icon: Icons.toggle_on_outlined,
      ),
      if (displayId != null)
        _DepartmentDetailFact(
          label: l10n.tenantFacilityDepartmentIdLabel,
          value: displayId,
          icon: Icons.tag_outlined,
        ),
      _DepartmentDetailFact(
        label: l10n.profileTenantLabel,
        value: _resolveTenantName(),
        icon: Icons.apartment_outlined,
      ),
      if (facilityName != null)
        _DepartmentDetailFact(
          label: l10n.profileFacilityLabel,
          value: facilityName,
          icon: Icons.local_hospital_outlined,
        ),
    ];

    return AppDialog(
      title: Text(l10n.tenantFacilityDepartmentDetailsTitle),
      icon: const Icon(Icons.domain_outlined),
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
                        _typeIcon(_department.type),
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
                          _department.name,
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
                            _DepartmentStatusBadge(
                              label: statusLabel,
                              tone: _statusTone(),
                            ),
                            Text(
                              typeLabel,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (displayId != null)
                              Text(
                                displayId,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
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
                  for (final _DepartmentDetailFact fact in facts)
                    SizedBox(
                      width: tileWidth,
                      child: _DepartmentFactTile(fact: fact),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      actions: <Widget>[
        if (_canEditStructure && !_department.isDeleted)
          AppButton.secondary(
            label: l10n.tenantFacilityEditDepartmentDetailsAction,
            leadingIcon: Icons.edit_outlined,
            enabled: _canMutate,
            onPressed: () => unawaited(_editDepartment()),
          ),
        if (_canEditStructure && !_department.isDeleted)
          AppButton.primary(
            label: l10n.tenantFacilityDeleteDepartmentDetailsAction,
            leadingIcon: Icons.delete_outline,
            color: colorScheme.error,
            enabled: _canMutate,
            isLoading: _busy,
            onPressed: () => unawaited(_deleteDepartment()),
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

final class _DepartmentDetailFact {
  const _DepartmentDetailFact({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _DepartmentFactTile extends StatelessWidget {
  const _DepartmentFactTile({required this.fact});

  final _DepartmentDetailFact fact;

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

class _DepartmentStatusBadge extends StatelessWidget {
  const _DepartmentStatusBadge({required this.label, required this.tone});

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

String _departmentTypeLabel(AppLocalizations l10n, DepartmentSetupType type) {
  return switch (type) {
    DepartmentSetupType.clinical => l10n.tenantFacilityDepartmentTypeClinical,
    DepartmentSetupType.administrative =>
      l10n.tenantFacilityDepartmentTypeAdministrative,
    DepartmentSetupType.support => l10n.tenantFacilityDepartmentTypeSupport,
    DepartmentSetupType.diagnostics =>
      l10n.tenantFacilityDepartmentTypeDiagnostics,
    DepartmentSetupType.other => l10n.tenantFacilityDepartmentTypeOther,
  };
}
