import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

class AppPermissionActionButton extends StatelessWidget {
  const AppPermissionActionButton({
    required this.requirement,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.enabled = true,
    this.isLoading = false,
    this.fullWidth = false,
    this.hideWhenDenied = false,
    super.key,
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

  @override
  Widget build(BuildContext context) {
    return AppAccessActionGate(
      requirement: requirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed && hideWhenDenied) {
          return const SizedBox.shrink();
        }

        return AppButton(
          label: label,
          leadingIcon: icon,
          variant: variant,
          enabled: enabled && isAllowed,
          isLoading: isLoading,
          fullWidth: fullWidth,
          onPressed: enabled && isAllowed ? onPressed : null,
        );
      },
    );
  }
}
