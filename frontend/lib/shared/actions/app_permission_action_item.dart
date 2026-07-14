import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/shared/actions/app_action_lifecycle.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

/// Declarative permission-gated action model for reusable action rows.
@immutable
final class AppPermissionActionItem {
  const AppPermissionActionItem({
    required this.requirement,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.enabled = true,
    this.isLoading = false,
    this.fullWidth = false,
    this.hideWhenDenied = true,
    this.capabilityAllowed = true,
    this.blockedReason,
    this.tooltip,
    this.semanticLabel,
    this.placement = AppActionPlacement.inline,
    this.confirmTitle,
    this.confirmBody,
    this.confirmSubmitLabel,
    this.destructive = false,
  });

  final AccessRequirement requirement;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool enabled;
  final bool isLoading;
  final bool fullWidth;
  final bool hideWhenDenied;

  /// When false, the action stays visible (if permitted) but disabled because
  /// backend workflow/resource capabilities disallow it.
  final bool capabilityAllowed;

  /// Localized prerequisite/capability reason shown when disabled.
  final String? blockedReason;
  final String? tooltip;
  final String? semanticLabel;

  /// Where the action should render (inline row vs overflow menu).
  final AppActionPlacement placement;

  /// When set with [confirmBody], the action asks for confirmation before
  /// invoking [onPressed]. Success/failure feedback remains caller-owned.
  final String? confirmTitle;
  final String? confirmBody;
  final String? confirmSubmitLabel;

  /// Destructive styling for critical confirmations; icons are never sole meaning.
  final bool destructive;

  bool get requiresConfirmation {
    final String? title = confirmTitle?.trim();
    final String? body = confirmBody?.trim();
    return title != null &&
        title.isNotEmpty &&
        body != null &&
        body.isNotEmpty;
  }

  bool get isOverflow => placement == AppActionPlacement.overflow;
}
