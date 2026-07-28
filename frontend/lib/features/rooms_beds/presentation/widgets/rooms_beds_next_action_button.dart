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

bool roomsBedsNextActionIsNavigation(RoomsBedsNextActionKind kind) {
  return kind == RoomsBedsNextActionKind.openHousekeeping ||
      kind == RoomsBedsNextActionKind.openOperations;
}

bool roomsBedsNextActionIsWrite(RoomsBedsNextActionKind kind) {
  return switch (kind) {
    RoomsBedsNextActionKind.assign ||
    RoomsBedsNextActionKind.release ||
    RoomsBedsNextActionKind.completeTransfer ||
    RoomsBedsNextActionKind.markAvailable => true,
    RoomsBedsNextActionKind.openHousekeeping ||
    RoomsBedsNextActionKind.openOperations ||
    RoomsBedsNextActionKind.viewDetail => false,
  };
}

bool roomsBedsNextActionIsAuthorized({
  required RoomsBedsNextActionKind kind,
  required bool canAdminBeds,
  required bool canIpdWrite,
}) {
  return switch (kind) {
    RoomsBedsNextActionKind.assign ||
    RoomsBedsNextActionKind.release ||
    RoomsBedsNextActionKind.completeTransfer => canIpdWrite,
    RoomsBedsNextActionKind.markAvailable => canAdminBeds,
    RoomsBedsNextActionKind.openHousekeeping ||
    RoomsBedsNextActionKind.openOperations ||
    RoomsBedsNextActionKind.viewDetail => true,
  };
}

bool roomsBedsNextActionIsEnabled({
  required RoomsBedsNextActionKind kind,
  required BedBoardItem item,
  required bool canAdminBeds,
  required bool canIpdWrite,
  required bool isSaving,
}) {
  if (!roomsBedsNextActionIsAuthorized(
    kind: kind,
    canAdminBeds: canAdminBeds,
    canIpdWrite: canIpdWrite,
  )) {
    return false;
  }
  return switch (kind) {
    RoomsBedsNextActionKind.assign => !isSaving && item.isAvailable,
    RoomsBedsNextActionKind.release =>
      !isSaving &&
          item.isOccupied &&
          item.currentAdmissionId != null &&
          !item.hasOpenTransfer,
    RoomsBedsNextActionKind.completeTransfer =>
      !isSaving && item.hasOpenTransfer && item.currentAdmissionId != null,
    RoomsBedsNextActionKind.markAvailable => !isSaving && !item.isOccupied,
    RoomsBedsNextActionKind.openHousekeeping ||
    RoomsBedsNextActionKind.openOperations => true,
    RoomsBedsNextActionKind.viewDetail => true,
  };
}

/// Whether the next-action control should render. Unauthorized writes and
/// review-only [viewDetail] are omitted — row select opens detail.
bool roomsBedsNextActionShouldRender({
  required RoomsBedsNextActionKind kind,
  required bool canAdminBeds,
  required bool canIpdWrite,
}) {
  if (kind == RoomsBedsNextActionKind.viewDetail) {
    return false;
  }
  return roomsBedsNextActionIsAuthorized(
    kind: kind,
    canAdminBeds: canAdminBeds,
    canIpdWrite: canIpdWrite,
  );
}

class RoomsBedsNextActionButton extends ConsumerWidget {
  const RoomsBedsNextActionButton({
    required this.item,
    required this.state,
    required this.canAdminBeds,
    required this.canIpdWrite,
    required this.callbacks,
    this.compact = false,
    super.key,
  });

  final BedBoardItem item;
  final RoomsBedsWorkspaceState state;
  final bool canAdminBeds;
  final bool canIpdWrite;
  final RoomsBedsNextActionCallbacks callbacks;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RoomsBedsNextActionKind kind = roomsBedsPrimaryNextActionKind(item);

    if (!roomsBedsNextActionShouldRender(
      kind: kind,
      canAdminBeds: canAdminBeds,
      canIpdWrite: canIpdWrite,
    )) {
      return const SizedBox.shrink();
    }

    final String label = roomsBedsPrimaryNextActionLabel(l10n, item);
    final bool enabled = roomsBedsNextActionIsEnabled(
      kind: kind,
      item: item,
      canAdminBeds: canAdminBeds,
      canIpdWrite: canIpdWrite,
      isSaving: state.isSaving,
    );
    final bool isNarrow =
        compact || MediaQuery.sizeOf(context).width < 600;

    if (isNarrow) {
      return AppButton.secondary(
        label: label,
        icon: _iconForKind(kind),
        iconOnly: true,
        tooltip: label,
        semanticLabel: label,
        enabled: enabled,
        onPressed: enabled ? () => _handleAction(context, kind) : null,
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
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
      RoomsBedsNextActionKind.completeTransfer => AppActionIcons.transfer,
      RoomsBedsNextActionKind.markAvailable => Icons.check_circle_outline,
      RoomsBedsNextActionKind.openHousekeeping =>
        Icons.cleaning_services_outlined,
      RoomsBedsNextActionKind.openOperations => Icons.handyman_outlined,
      RoomsBedsNextActionKind.viewDetail => Icons.open_in_new_outlined,
    };
  }
}
