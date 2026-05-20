import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
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
    this.hideWhenDenied = false,
    this.tooltip,
    this.semanticLabel,
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
  final String? tooltip;
  final String? semanticLabel;
}
