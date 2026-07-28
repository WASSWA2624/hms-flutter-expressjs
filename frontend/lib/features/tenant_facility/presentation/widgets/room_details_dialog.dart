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

Future<bool?> showRoomDetailsDialog(
  BuildContext context, {
  required RoomProfile room,
  String? tenantName,
  String? facilityName,
  String? wardName,
  FacilitySetupSnapshot? snapshot,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => _RoomDetailsDialog(
      room: room,
      tenantName: tenantName,
      facilityName: facilityName,
      wardName: wardName,
      snapshot: snapshot,
    ),
  );
}

class _RoomDetailsDialog extends ConsumerStatefulWidget {
  const _RoomDetailsDialog({
    required this.room,
    this.tenantName,
    this.facilityName,
    this.wardName,
    this.snapshot,
  });

  final RoomProfile room;
  final String? tenantName;
  final String? facilityName;
  final String? wardName;
  final FacilitySetupSnapshot? snapshot;

  @override
  ConsumerState<_RoomDetailsDialog> createState() => _RoomDetailsDialogState();
}

class _RoomDetailsDialogState extends ConsumerState<_RoomDetailsDialog> {
  static const String _emptyValue = '—';

  late RoomProfile _room;
  bool _mutated = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
  }

  bool get _canEditStructure =>
      ref.read(appAccessPolicyProvider).canEditFacilitySetupStructure();

  bool get _canMutate => _canEditStructure && !_room.isDeleted && !_busy;

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
    if (_room.isDeleted) {
      return l10n.tenantFacilityStructureDeletedStatus;
    }
    return l10n.tenantFacilityTenantStatusActive;
  }

  AppWorkspaceStatusTone _statusTone() {
    if (_room.isDeleted) {
      return AppWorkspaceStatusTone.error;
    }
    return AppWorkspaceStatusTone.success;
  }

  String _resolveTenantName() {
    final String? provided = widget.tenantName?.trim();
    if (provided != null && provided.isNotEmpty && provided != _emptyValue) {
      return provided;
    }
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    final TenantProfile? tenant = snapshot?.tenant;
    if (tenant != null && tenant.id == _room.tenantId) {
      return tenant.name;
    }
    return _emptyValue;
  }

  String _resolveFacilityName() {
    final String? provided = widget.facilityName?.trim();
    if (provided != null && provided.isNotEmpty && provided != _emptyValue) {
      return provided;
    }
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot == null) {
      return _emptyValue;
    }
    final FacilityProfile? facility = snapshot.facility;
    if (facility != null && facility.id == _room.facilityId) {
      return facility.name;
    }
    for (final FacilityProfile item in snapshot.facilities) {
      if (item.id == _room.facilityId) {
        return item.name;
      }
    }
    return _emptyValue;
  }

  String _resolveWardName() {
    final String? provided = widget.wardName?.trim();
    if (provided != null && provided.isNotEmpty && provided != _emptyValue) {
      return provided;
    }
    final String? wardId = _room.wardId?.trim();
    if (wardId == null || wardId.isEmpty) {
      return context.l10n.tenantFacilityRoomOutpatientLabel;
    }
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot == null) {
      return wardId;
    }
    for (final WardProfile ward in snapshot.wards) {
      if (ward.id == wardId) {
        return ward.name;
      }
    }
    return wardId;
  }

  RoomProfile? _findRoomInSetup() {
    final FacilitySetupSnapshot? snapshot = _effectiveSnapshot;
    if (snapshot == null) {
      return null;
    }
    for (final RoomProfile item in snapshot.rooms) {
      if (item.id == _room.id) {
        return item;
      }
    }
    return null;
  }

  void _refreshRoomAfterMutation() {
    final Object? saved =
        ref.read(tenantFacilitySetupSubmissionProvider).lastSavedEntity;
    if (saved is RoomProfile && saved.id == _room.id) {
      setState(() {
        _room = saved;
      });
      return;
    }

    final RoomProfile? updated = _findRoomInSetup();
    if (updated != null) {
      setState(() {
        _room = updated;
      });
    }
  }

  Future<void> _editRoom() async {
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
      await showTenantFacilityRoomFormDialog(
        context,
        snapshot,
        room: _room,
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
      _refreshRoomAfterMutation();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteRoom() async {
    if (_busy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmActionDialog(
        title: l10n.tenantFacilitySoftDeleteStructureTitle,
        body: l10n.tenantFacilitySoftDeleteStructureBody(_room.name),
        highlightedText: _room.name,
        submitLabel: l10n.tenantFacilityDeleteConfirmAction,
        destructive: true,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () async {
          final bool deleted = await ref
              .read(tenantFacilitySetupSubmissionProvider.notifier)
              .deleteRoom(_room.id);
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
    final String floor = _room.floor?.trim().isNotEmpty == true
        ? _room.floor!.trim()
        : _emptyValue;

    final List<_RoomDetailFact> facts = <_RoomDetailFact>[
      _RoomDetailFact(
        label: l10n.tenantFacilityRoomNameLabel,
        value: _room.name,
        icon: Icons.meeting_room_outlined,
      ),
      _RoomDetailFact(
        label: l10n.tenantFacilityRoomWardLabel,
        value: _resolveWardName(),
        icon: Icons.local_hospital_outlined,
      ),
      _RoomDetailFact(
        label: l10n.tenantFacilityRoomFloorLabel,
        value: floor,
        icon: Icons.layers_outlined,
      ),
      _RoomDetailFact(
        label: l10n.tenantFacilityTenantStatusLabel,
        value: statusLabel,
        icon: Icons.toggle_on_outlined,
      ),
      _RoomDetailFact(
        label: l10n.profileFacilityLabel,
        value: _resolveFacilityName(),
        icon: Icons.local_hospital_outlined,
      ),
      _RoomDetailFact(
        label: l10n.profileTenantLabel,
        value: _resolveTenantName(),
        icon: Icons.apartment_outlined,
      ),
    ];

    return AppDialog(
      title: Text(l10n.tenantFacilityRoomDetailsTitle),
      icon: const Icon(Icons.meeting_room_outlined),
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
                        Icons.meeting_room_outlined,
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
                          _room.name,
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
                            _RoomStatusBadge(
                              label: statusLabel,
                              tone: _statusTone(),
                            ),
                            Text(
                              _resolveWardName(),
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
                  for (final _RoomDetailFact fact in facts)
                    SizedBox(
                      width: tileWidth,
                      child: _RoomFactTile(fact: fact),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      actions: <Widget>[
        if (_canEditStructure && !_room.isDeleted)
          AppButton.secondary(
            label: l10n.tenantFacilityEditRoomDetailsAction,
            leadingIcon: Icons.edit_outlined,
            enabled: _canMutate,
            onPressed: () => unawaited(_editRoom()),
          ),
        if (_canEditStructure && !_room.isDeleted)
          AppButton.primary(
            label: l10n.tenantFacilityDeleteRoomDetailsAction,
            leadingIcon: Icons.delete_outline,
            color: colorScheme.error,
            enabled: _canMutate,
            isLoading: _busy,
            onPressed: () => unawaited(_deleteRoom()),
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

final class _RoomDetailFact {
  const _RoomDetailFact({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _RoomFactTile extends StatelessWidget {
  const _RoomFactTile({required this.fact});

  final _RoomDetailFact fact;

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

class _RoomStatusBadge extends StatelessWidget {
  const _RoomStatusBadge({required this.label, required this.tone});

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
