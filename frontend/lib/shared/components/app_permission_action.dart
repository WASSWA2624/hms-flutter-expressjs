import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/access_requirement_l10n.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';

/// Permission/entitlement-aware action button with hide vs disable semantics.
///
/// - **Hide** when the user lacks effective RBAC/ABAC/subscription permission
///   ([hideWhenDenied] default).
/// - **Disable** when authorized but [enabled]/[capabilityAllowed] block the
///   action; [blockedReason] is shown as the tooltip.
/// - Optional confirmation via [confirmTitle]/[confirmBody] before [onPressed].
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
    this.hideWhenDenied = true,
    this.capabilityAllowed = true,
    this.blockedReason,
    this.semanticLabel,
    this.tooltip,
    this.confirmTitle,
    this.confirmBody,
    this.confirmSubmitLabel,
    this.destructive = false,
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
  final bool capabilityAllowed;
  final String? blockedReason;
  final String? semanticLabel;
  final String? tooltip;
  final String? confirmTitle;
  final String? confirmBody;
  final String? confirmSubmitLabel;
  final bool destructive;

  bool get requiresConfirmation {
    final String? title = confirmTitle?.trim();
    final String? body = confirmBody?.trim();
    return title != null && title.isNotEmpty && body != null && body.isNotEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final policy = ref.watch(appAccessPolicyProvider);
    final bool isAllowed = requirement.isAllowed(policy);

    if (!isAllowed && hideWhenDenied) {
      return const SizedBox.shrink();
    }

    final bool canPress =
        enabled && isAllowed && capabilityAllowed && onPressed != null;
    final String resolvedTooltip = canPress
        ? (tooltip ?? label)
        : (!isAllowed
              ? accessRequirementDenialMessage(l10n, requirement, policy)
              : (blockedReason ?? tooltip ?? label));

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return AppButton(
      label: label,
      leadingIcon: icon,
      variant: variant,
      enabled: canPress,
      isLoading: isLoading,
      fullWidth: fullWidth,
      semanticLabel: semanticLabel,
      tooltip: resolvedTooltip,
      color: destructive && canPress ? colorScheme.error : null,
      onPressed: canPress ? () => _handlePress(context) : null,
    );
  }

  void _handlePress(BuildContext context) {
    final VoidCallback? onPressed = this.onPressed;
    if (onPressed == null) {
      return;
    }
    if (!requiresConfirmation) {
      onPressed();
      return;
    }

    showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppConfirmActionDialog(
          title: confirmTitle!,
          body: confirmBody!,
          submitLabel: confirmSubmitLabel ?? label,
          destructive: destructive,
          icon: Icon(icon),
        );
      },
    ).then((bool? confirmed) {
      if (confirmed == true) {
        onPressed();
      }
    });
  }
}
