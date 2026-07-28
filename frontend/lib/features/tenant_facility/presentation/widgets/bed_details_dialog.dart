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

Future<bool?> showBedDetailsDialog(
  BuildContext context, {
  required BedProfile bed,
  String? tenantName,
  String? facilityName,
  String? wardName,
  String? roomName,
  FacilitySetupSnapshot? snapshot,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => _BedDetailsDialog(
      bed: bed,
      tenantName: tenantName,
      facilityName: facilityName,
      wardName: wardName,
      roomName: roomName,
      snapshot: snapshot,
    ),
  );
}

class _BedDetailsDialog extends ConsumerStatefulWidget {
  const _BedDetailsDialog({
    required this.bed,
    this.tenantName,
    this.facilityName,
    this.wardName,
    this.roomName,
    this.snapshot,
  });

  final BedProfile bed;
  final String? tenantName;
  final String? facilityName;
  final String? wardName;
  final String? roomName;
  final FacilitySetupSnapshot? snapshot;

  @override
  ConsumerState<_BedDetailsDialog> createState() => _BedDetailsDialogState();
}

class _BedDetailsDialogState extends ConsumerState<_BedDetailsDialog> {
  static const String _emptyValue = '—';

  late BedProfile _bed;
  bool _mutated = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bed = widget.bed;
  }

  bool get _canEditStructure =>
      ref.read(appAccessPolicyProvider).canEditFacilitySetupStructure();

  bool get _canMutate => _canEditStructure && !_bed.isDeleted && !_busy;

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
    if (_bed.isDeleted) {
      return l10n.tenantFacilityStructureDeletedStatus;
    }
    return tenantFacilityBedStatusLabel(l10n, _bed.status);
  }

  AppWorkspaceStatusTone _statusTone() {
    if (_bed.isDeleted) {
      return AppWorkspaceStatusTone.error;
    }
    return switch (_bed.status) {
      BedSetupStatus.available => AppWorkspaceStatusTone.success,
      BedSetupStatus.occupied => AppWorkspaceStatusTone.info,
      BedSetupStatus.reserved => AppWorkspaceStatusTone.warning,
      BedSetupStatus.cleaning ||
      BedSetupStatus.maintenance ||
      BedSetupStatus.blocked ||
      BedSetupStatus.outOfService =>
        AppWorkspaceStatusTone.neutral,
    };
  }

  String _resolveTenantName() {
    final String? provided = widget.tenantName?.trim();
    if (provided != null && provided.isNotEmpty && provided != _emptyValue) {
      return provided;
    }
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    final TenantProfile? tenant = snapshot?.tenant;
    if (tenant != null && tenant.id == _bed.tenantId) {
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
    final String facilityId = _bed.facilityId.trim();
    if (facilityId.isEmpty) {
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

  String _resolveWardName() {
    final String? provided = widget.wardName?.trim();
    if (provided != null && provided.isNotEmpty && provided != _emptyValue) {
      return provided;
    }
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot != null) {
      for (final WardProfile ward in snapshot.wards) {
        if (ward.id == _bed.wardId) {
          return ward.name;
        }
      }
    }
    final String wardId = _bed.wardId.trim();
    return wardId.isEmpty ? _emptyValue : wardId;
  }

  String _resolveRoomName() {
    final String? provided = widget.roomName?.trim();
    if (provided != null && provided.isNotEmpty && provided != _emptyValue) {
      return provided;
    }
    final String? roomId = _bed.roomId?.trim();
    if (roomId == null || roomId.isEmpty) {
      return _emptyValue;
    }
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot != null) {
      for (final RoomProfile room in snapshot.rooms) {
        if (room.id == roomId) {
          return room.name;
        }
      }
    }
    return roomId;
  }

  BedProfile? _findBedInSetup() {
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot == null) {
      return null;
    }
    for (final BedProfile item in snapshot.beds) {
      if (item.id == _bed.id) {
        return item;
      }
    }
    return null;
  }

  void _refreshBedAfterMutation() {
    final Object? saved =
        ref.read(tenantFacilitySetupSubmissionProvider).lastSavedEntity;
    if (saved is BedProfile && saved.id == _bed.id) {
      setState(() {
        _bed = saved;
      });
      return;
    }

    final BedProfile? updated = _findBedInSetup();
    if (updated != null) {
      setState(() {
        _bed = updated;
      });
    }
  }

  Future<void> _editBed() async {
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
      await showTenantFacilityBedFormDialog(
        context,
        snapshot,
        bed: _bed,
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
      _refreshBedAfterMutation();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteBed() async {
    if (_busy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilitySoftDeleteStructureTitle,
        body: l10n.tenantFacilitySoftDeleteStructureBody(_bed.label),
        highlightedText: _bed.label,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final bool deleted = await ref
              .read(tenantFacilitySetupSubmissionProvider.notifier)
              .deleteBed(_bed.id);
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
    final String wardName = _resolveWardName();
    final String roomName = _resolveRoomName();

    final List<_BedDetailFact> facts = <_BedDetailFact>[
      _BedDetailFact(
        label: l10n.tenantFacilityBedLabelLabel,
        value: _bed.label,
        icon: Icons.bed_outlined,
      ),
      _BedDetailFact(
        label: l10n.tenantFacilityBedWardLabel,
        value: wardName,
        icon: Icons.local_hospital_outlined,
      ),
      _BedDetailFact(
        label: l10n.tenantFacilityBedRoomLabel,
        value: roomName,
        icon: Icons.meeting_room_outlined,
      ),
      _BedDetailFact(
        label: l10n.tenantFacilityBedStatusLabel,
        value: statusLabel,
        icon: Icons.toggle_on_outlined,
      ),
      _BedDetailFact(
        label: l10n.profileTenantLabel,
        value: _resolveTenantName(),
        icon: Icons.apartment_outlined,
      ),
      if (facilityName != null)
        _BedDetailFact(
          label: l10n.profileFacilityLabel,
          value: facilityName,
          icon: Icons.local_hospital_outlined,
        ),
    ];

    return AppDialog(
      title: Text(l10n.tenantFacilityBedDetailsTitle),
      icon: const Icon(Icons.bed_outlined),
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
                        Icons.bed_outlined,
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
                          _bed.label,
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
                            _BedStatusBadge(
                              label: statusLabel,
                              tone: _statusTone(),
                            ),
                            Text(
                              wardName,
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
                  for (final _BedDetailFact fact in facts)
                    SizedBox(
                      width: tileWidth,
                      child: _BedFactTile(fact: fact),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      actions: <Widget>[
        if (_canEditStructure && !_bed.isDeleted)
          AppButton.secondary(
            label: l10n.tenantFacilityEditBedDetailsAction,
            leadingIcon: Icons.edit_outlined,
            enabled: _canMutate,
            onPressed: () => unawaited(_editBed()),
          ),
        if (_canEditStructure && !_bed.isDeleted)
          AppButton.primary(
            label: l10n.tenantFacilityDeleteBedDetailsAction,
            leadingIcon: Icons.delete_outline,
            color: colorScheme.error,
            enabled: _canMutate,
            isLoading: _busy,
            onPressed: () => unawaited(_deleteBed()),
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

final class _BedDetailFact {
  const _BedDetailFact({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _BedFactTile extends StatelessWidget {
  const _BedFactTile({required this.fact});

  final _BedDetailFact fact;

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

class _BedStatusBadge extends StatelessWidget {
  const _BedStatusBadge({required this.label, required this.tone});

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
