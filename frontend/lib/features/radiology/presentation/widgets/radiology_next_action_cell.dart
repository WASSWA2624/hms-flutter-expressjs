import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';

typedef RadiologyDetailDialogOpener =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      RadiologyWorkspaceState state,
      RadiologyOrder order, {
      required bool canWork,
      required bool canRequest,
      required bool canViewBilling,
    });

typedef RadiologyNextActionLabelResolver =
    String Function(BuildContext context, RadiologyOrder order);

class RadiologyNextActionCell extends ConsumerWidget {
  const RadiologyNextActionCell({
    required this.order,
    required this.state,
    required this.canWork,
    required this.canRequest,
    required this.canViewBilling,
    required this.resolveLabel,
    required this.openDetailDialog,
    this.compact = false,
    super.key,
  });

  final RadiologyOrder order;
  final RadiologyWorkspaceState state;
  final bool canWork;
  final bool canRequest;
  final bool canViewBilling;
  final RadiologyNextActionLabelResolver resolveLabel;
  final RadiologyDetailDialogOpener openDetailDialog;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String label = resolveLabel(context, order);
    if (order.normalizedStatus == 'CANCELLED') {
      return _RadiologyNextActionText(label: label);
    }

    return _RadiologyCompactNextActionButton(
      label: label,
      compact: compact,
      onPressed: () => openDetailDialog(
        context,
        ref,
        state,
        order,
        canWork: canWork,
        canRequest: canRequest,
        canViewBilling: canViewBilling,
      ),
    );
  }
}

class _RadiologyNextActionText extends StatelessWidget {
  const _RadiologyNextActionText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _RadiologyCompactNextActionButton extends StatelessWidget {
  const _RadiologyCompactNextActionButton({
    required this.label,
    required this.onPressed,
    required this.compact,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    return Semantics(
      button: true,
      enabled: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 40 : 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.xs,
                  vertical: compact ? 2 : theme.spacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.arrow_forward_outlined,
                      size: compact ? 16 : 18,
                      color: primaryColor,
                    ),
                    SizedBox(width: theme.spacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
