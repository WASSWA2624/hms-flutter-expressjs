import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum AppFormSectionDensity { compact, regular, spacious }

/// Form field groups that share the app's titled section chrome.
///
/// When framed with a title, builds [AppWorkspaceDetailPanel] (collapsible by
/// default). Untitled or explicitly unframed layouts stay as plain columns.
class AppFormSection extends StatelessWidget {
  const AppFormSection({
    required this.children,
    this.title,
    this.description,
    this.density = AppFormSectionDensity.regular,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.framed,
    this.collapsible = true,
    this.initiallyExpanded = true,
    super.key,
  });

  final String? title;
  final String? description;
  final List<Widget> children;
  final AppFormSectionDensity density;
  final CrossAxisAlignment crossAxisAlignment;

  /// When null, titled sections are framed so adjacent blocks stay distinct.
  final bool? framed;

  /// Forwarded to [AppWorkspaceDetailPanel] for framed titled sections.
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final double gap = _gap(theme);
    final String? resolvedTitle = title?.trim().isNotEmpty == true
        ? title
        : null;
    final bool showFrame = framed ?? resolvedTitle != null;

    final Widget body = Column(
      crossAxisAlignment: showFrame
          ? CrossAxisAlignment.stretch
          : crossAxisAlignment,
      children: <Widget>[
        if (resolvedTitle != null && !showFrame) ...<Widget>[
          Text(resolvedTitle, style: textTheme.titleMedium),
          if (description != null) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            Text(description!, style: textTheme.bodyMedium),
          ],
          SizedBox(height: gap),
        ],
        for (var index = 0; index < children.length; index++) ...<Widget>[
          children[index],
          if (index < children.length - 1) SizedBox(height: gap),
        ],
      ],
    );

    if (!showFrame) {
      return body;
    }

    if (resolvedTitle != null) {
      return AppWorkspaceDetailPanel(
        title: resolvedTitle,
        description: description,
        collapsible: collapsible,
        initiallyExpanded: initiallyExpanded,
        child: body,
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            context.responsiveRadius(theme.radius.lg),
          ),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: _framePadding(theme), child: body),
      ),
    );
  }

  EdgeInsetsGeometry _framePadding(ThemeData theme) {
    return EdgeInsets.all(switch (density) {
      AppFormSectionDensity.compact => theme.spacing.sm,
      AppFormSectionDensity.regular => theme.spacing.md,
      AppFormSectionDensity.spacious => theme.spacing.lg,
    });
  }

  double _gap(ThemeData theme) {
    return switch (density) {
      AppFormSectionDensity.compact => theme.appTokens.formGapCompact,
      AppFormSectionDensity.regular => theme.appTokens.formGapRegular,
      AppFormSectionDensity.spacious => theme.appTokens.formGapSpacious,
    };
  }
}
