import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

typedef RoomsBedsNextActionCallback = Future<void> Function(BedBoardItem item);

class RoomsBedsNextActionCallbacks {
  const RoomsBedsNextActionCallbacks({
    required this.onAssign,
    required this.onRelease,
    required this.onCompleteTransfer,
    required this.onMarkAvailable,
    required this.onOpenDetail,
  });

  final RoomsBedsNextActionCallback onAssign;
  final RoomsBedsNextActionCallback onRelease;
  final RoomsBedsNextActionCallback onCompleteTransfer;
  final RoomsBedsNextActionCallback onMarkAvailable;
  final RoomsBedsNextActionCallback onOpenDetail;
}

bool roomsBedsNextActionIsEnabled({
  required RoomsBedsNextActionKind kind,
  required BedBoardItem item,
  required bool canAdminBeds,
  required bool canIpdWrite,
  required bool isSaving,
}) {
  return switch (kind) {
    RoomsBedsNextActionKind.assign =>
      canIpdWrite && !isSaving && item.isAvailable,
    RoomsBedsNextActionKind.release =>
      canIpdWrite &&
          !isSaving &&
          item.isOccupied &&
          item.currentAdmissionId != null &&
          !item.hasOpenTransfer,
    RoomsBedsNextActionKind.completeTransfer =>
      canIpdWrite &&
          !isSaving &&
          item.hasOpenTransfer &&
          item.currentAdmissionId != null,
    RoomsBedsNextActionKind.markAvailable =>
      canAdminBeds && !isSaving && !item.isOccupied,
    RoomsBedsNextActionKind.openHousekeeping => canAdminBeds,
    RoomsBedsNextActionKind.openOperations => canAdminBeds,
    RoomsBedsNextActionKind.viewDetail => true,
  };
}

String? roomsBedsNextActionDisabledReason(
  AppLocalizations l10n,
  RoomsBedsNextActionKind kind, {
  required bool canAdminBeds,
  required bool canIpdWrite,
}) {
  return switch (kind) {
    RoomsBedsNextActionKind.assign ||
    RoomsBedsNextActionKind.release ||
    RoomsBedsNextActionKind.completeTransfer =>
      canIpdWrite ? null : l10n.accessDeniedPermissionRequired,
    RoomsBedsNextActionKind.markAvailable ||
    RoomsBedsNextActionKind.openHousekeeping ||
    RoomsBedsNextActionKind.openOperations =>
      canAdminBeds ? null : l10n.accessDeniedPermissionRequired,
    RoomsBedsNextActionKind.viewDetail => null,
  };
}

class RoomsBedsNextActionButton extends ConsumerWidget {
  const RoomsBedsNextActionButton({
    required this.item,
    required this.state,
    required this.canAdminBeds,
    required this.canIpdWrite,
    required this.callbacks,
    super.key,
  });

  final BedBoardItem item;
  final RoomsBedsWorkspaceState state;
  final bool canAdminBeds;
  final bool canIpdWrite;
  final RoomsBedsNextActionCallbacks callbacks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RoomsBedsNextActionKind kind = roomsBedsPrimaryNextActionKind(item);
    final String label = roomsBedsPrimaryNextActionLabel(l10n, item);
    final bool enabled = roomsBedsNextActionIsEnabled(
      kind: kind,
      item: item,
      canAdminBeds: canAdminBeds,
      canIpdWrite: canIpdWrite,
      isSaving: state.isSaving,
    );
    final String? disabledReason = enabled
        ? null
        : roomsBedsNextActionDisabledReason(
            l10n,
            kind,
            canAdminBeds: canAdminBeds,
            canIpdWrite: canIpdWrite,
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: disabledReason,
      child: Tooltip(
        message: disabledReason ?? label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => _handleAction(context, kind) : null,
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    _iconForKind(kind),
                    size: 14,
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: enabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!enabled) ...<Widget>[
                    SizedBox(width: theme.spacing.xs),
                    Icon(
                      Icons.lock_outlined,
                      size: 12,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    RoomsBedsNextActionKind kind,
  ) async {
    switch (kind) {
      case RoomsBedsNextActionKind.assign:
        await callbacks.onAssign(item);
      case RoomsBedsNextActionKind.release:
        await callbacks.onRelease(item);
      case RoomsBedsNextActionKind.completeTransfer:
        await callbacks.onCompleteTransfer(item);
      case RoomsBedsNextActionKind.markAvailable:
        await callbacks.onMarkAvailable(item);
      case RoomsBedsNextActionKind.openHousekeeping:
        if (context.mounted) {
          context.go(AppRoutes.housekeeping.location());
        }
      case RoomsBedsNextActionKind.openOperations:
        if (context.mounted) {
          context.go(AppRoutes.operations.location());
        }
      case RoomsBedsNextActionKind.viewDetail:
        await callbacks.onOpenDetail(item);
    }
  }

  IconData _iconForKind(RoomsBedsNextActionKind kind) {
    return switch (kind) {
      RoomsBedsNextActionKind.assign => Icons.login_outlined,
      RoomsBedsNextActionKind.release => Icons.logout_outlined,
      RoomsBedsNextActionKind.completeTransfer => Icons.move_down_outlined,
      RoomsBedsNextActionKind.markAvailable => Icons.check_circle_outline,
      RoomsBedsNextActionKind.openHousekeeping =>
        Icons.cleaning_services_outlined,
      RoomsBedsNextActionKind.openOperations => Icons.handyman_outlined,
      RoomsBedsNextActionKind.viewDetail => Icons.open_in_new_outlined,
    };
  }
}

class RoomsBedsBedMobileItem extends StatelessWidget {
  const RoomsBedsBedMobileItem({
    required this.item,
    required this.state,
    required this.canAdminBeds,
    required this.canIpdWrite,
    required this.callbacks,
    super.key,
  });

  final BedBoardItem item;
  final RoomsBedsWorkspaceState state;
  final bool canAdminBeds;
  final bool canIpdWrite;
  final RoomsBedsNextActionCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppListItemRow(
      title: item.label,
      subtitle: _joinDisplay(<String?>[
        roomsBedsLocationLabel(l10n, item),
        roomsBedsAssignmentLabel(l10n, item),
      ]),
      leadingIcon: item.isOccupied
          ? Icons.person_pin_circle_outlined
          : Icons.bed_outlined,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          AppWorkspaceStatusBadge(
            status: roomsBedsStatusBadge(l10n, item.status),
          ),
          RoomsBedsNextActionButton(
            item: item,
            state: state,
            canAdminBeds: canAdminBeds,
            canIpdWrite: canIpdWrite,
            callbacks: callbacks,
          ),
        ],
      ),
    );
  }

  String _joinDisplay(Iterable<String?> values) {
    return values
        .map((String? value) => value?.trim() ?? '')
        .where((String value) => value.isNotEmpty)
        .join(' | ');
  }
}
