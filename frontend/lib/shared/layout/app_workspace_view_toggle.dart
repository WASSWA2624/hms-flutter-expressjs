import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

/// Orders/patients (or similar) view switch used by Lab, Radiology, etc.
class AppWorkspaceViewToggle extends StatelessWidget {
  const AppWorkspaceViewToggle({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppButton.secondary(
      label: label,
      leadingIcon: icon,
      enabled: enabled,
      onPressed: onPressed,
    );
  }
}
