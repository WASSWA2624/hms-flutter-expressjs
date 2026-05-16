import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/src/app_field_label.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    this.title,
    this.content,
    this.actions = const <Widget>[],
    this.icon,
    this.semanticLabel,
    this.scrollable = false,
    this.showCloseButton = true,
    this.closeEnabled = true,
    this.maxWidth = _defaultMaxWidth,
    super.key,
  });

  static const double _defaultMaxWidth = 600;

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final Widget? icon;
  final String? semanticLabel;
  final bool scrollable;
  final bool showCloseButton;
  final bool closeEnabled;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Size viewport = MediaQuery.sizeOf(context);
    final bool compact = viewport.width < 600;
    final EdgeInsets insetPadding = EdgeInsets.symmetric(
      horizontal: compact ? theme.spacing.md : theme.spacing.xl,
      vertical: compact ? theme.spacing.md : theme.spacing.xl,
    );
    final double maxHeight = math.max(
      theme.spacing.none,
      viewport.height - insetPadding.vertical,
    );

    Widget dialog = Dialog(
      insetPadding: insetPadding,
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.antiAlias,
      backgroundColor: colorScheme.surface,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.28),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: _DialogBody(
            title: title,
            content: content,
            actions: actions,
            icon: icon,
            scrollable: scrollable,
            compact: compact,
            showCloseButton: showCloseButton,
            closeEnabled: closeEnabled,
          ),
        ),
      ),
    );

    if (semanticLabel != null) {
      dialog = Semantics(
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        label: semanticLabel,
        child: dialog,
      );
    }

    return FocusTraversalGroup(child: dialog);
  }
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({
    required this.actions,
    required this.scrollable,
    required this.compact,
    required this.showCloseButton,
    required this.closeEnabled,
    this.title,
    this.content,
    this.icon,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final Widget? icon;
  final bool scrollable;
  final bool compact;
  final bool showCloseButton;
  final bool closeEnabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final EdgeInsets bodyPadding = EdgeInsets.all(
      compact ? theme.spacing.md : theme.spacing.lg,
    );
    final TextStyle titleStyle =
        (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge) ??
        TextStyle(color: colorScheme.onSurface, fontSize: compact ? 18 : 22);
    final TextStyle contentStyle =
        theme.textTheme.bodyMedium ?? TextStyle(color: colorScheme.onSurface);
    final Widget? dialogContent = content == null
        ? null
        : AppFieldRequirementScope(
            showOptionalIndicators: true,
            child: DefaultTextStyle(style: contentStyle, child: content!),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DialogHeader(
          title: title,
          icon: icon,
          titleStyle: titleStyle,
          showCloseButton: showCloseButton,
          closeEnabled: closeEnabled,
          compact: compact,
        ),
        if (dialogContent != null)
          Flexible(
            child: Padding(
              padding: bodyPadding,
              child: scrollable
                  ? SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: dialogContent,
                    )
                  : dialogContent,
            ),
          ),
        if (actions.isNotEmpty)
          _DialogActions(actions: actions, compact: compact),
      ],
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.icon,
    required this.titleStyle,
    required this.showCloseButton,
    required this.closeEnabled,
    required this.compact,
  });

  final Widget? title;
  final Widget? icon;
  final TextStyle titleStyle;
  final bool showCloseButton;
  final bool closeEnabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final EdgeInsetsGeometry padding = EdgeInsetsDirectional.only(
      start: compact ? theme.spacing.md : theme.spacing.lg,
      top: compact ? theme.spacing.sm : theme.spacing.md,
      bottom: compact ? theme.spacing.sm : theme.spacing.md,
      end: theme.spacing.xs,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              IconTheme.merge(
                data: IconThemeData(
                  color: colorScheme.primary,
                  size: theme.appTokens.listIconSize,
                ),
                child: icon!,
              ),
              SizedBox(width: theme.spacing.sm),
            ],
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : DefaultTextStyle(
                      style: titleStyle.copyWith(color: colorScheme.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      child: title!,
                    ),
            ),
            if (showCloseButton)
              Tooltip(
                message: MaterialLocalizations.of(context).closeButtonTooltip,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: closeEnabled
                      ? () {
                          Navigator.of(context).maybePop();
                        }
                      : null,
                  icon: const Icon(Icons.close),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({required this.actions, required this.compact});

  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final EdgeInsets padding = EdgeInsets.all(
      compact ? theme.spacing.md : theme.spacing.lg,
    ).copyWith(top: theme.spacing.sm);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: padding,
        child: OverflowBar(
          alignment: MainAxisAlignment.end,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: theme.spacing.sm,
          overflowSpacing: theme.spacing.sm,
          children: actions,
        ),
      ),
    );
  }
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  TraversalEdgeBehavior traversalEdgeBehavior =
      TraversalEdgeBehavior.closedLoop,
  bool requestFocus = true,
  RouteSettings? routeSettings,
}) async {
  final FocusNode? previousFocus = FocusManager.instance.primaryFocus;
  final T? result = await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    traversalEdgeBehavior: traversalEdgeBehavior,
    requestFocus: requestFocus,
    routeSettings: routeSettings,
    builder: (BuildContext context) {
      return FocusTraversalGroup(child: builder(context));
    },
  );

  if (previousFocus case final FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? previousContext = node.context;
      if (previousContext != null &&
          previousContext.mounted &&
          node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }

  return result;
}
