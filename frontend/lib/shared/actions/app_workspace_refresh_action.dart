import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

/// Standard refresh control for workspace toolbars (right cluster).
class AppWorkspaceRefreshAction extends StatelessWidget {
  const AppWorkspaceRefreshAction({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppButton(iconOnly: true, 
      icon: Icons.refresh,
      label: label,
      semanticLabel: label,
      tooltip: label,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}
