import 'package:flutter/material.dart';

/// Visual priority used by shared action rows and panels.
enum AppActionVariant { primary, secondary, tertiary }

/// Declarative action model for reusable, uniform module action bars.
@immutable
final class AppActionItem {
  const AppActionItem({
    required this.label,
    required this.leadingIcon,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.tooltip,
    this.semanticLabel,
    this.variant = AppActionVariant.secondary,
  });

  final String label;
  final IconData leadingIcon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final String? tooltip;
  final String? semanticLabel;
  final AppActionVariant variant;
}
