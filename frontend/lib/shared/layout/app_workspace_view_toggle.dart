import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

/// Orders/patients (or similar) view switch used by Lab, Radiology, etc.
class AppWorkspaceViewToggle extends StatelessWidget {
  const AppWorkspaceViewToggle({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.semanticLabel,
    this.tooltip,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final String? semanticLabel;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return AppButton.secondary(
      label: label,
      leadingIcon: icon,
      semanticLabel: semanticLabel ?? label,
      tooltip: tooltip ?? label,
      enabled: enabled,
      onPressed: onPressed,
    );
  }
}
