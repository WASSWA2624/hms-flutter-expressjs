import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/access_requirement_l10n.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

class AppPermissionActionButton extends ConsumerWidget {
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
    this.semanticLabel,
    this.tooltip,
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
  final String? semanticLabel;
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final policy = ref.watch(appAccessPolicyProvider);
    final bool isAllowed = requirement.isAllowed(policy);

    if (!isAllowed && hideWhenDenied) {
      return const SizedBox.shrink();
    }

    final bool canPress = enabled && isAllowed && onPressed != null;
    final String resolvedTooltip = canPress
        ? (tooltip ?? label)
        : (!isAllowed
              ? accessRequirementDenialMessage(l10n, requirement, policy)
              : (tooltip ?? label));

    return AppButton(
      label: label,
      leadingIcon: icon,
      variant: variant,
      enabled: canPress,
      isLoading: isLoading,
      fullWidth: fullWidth,
      semanticLabel: semanticLabel,
      tooltip: resolvedTooltip,
      onPressed: canPress ? onPressed : null,
    );
  }
}
