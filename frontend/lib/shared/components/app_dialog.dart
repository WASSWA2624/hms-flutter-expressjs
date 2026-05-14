import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    this.title,
    this.content,
    this.actions = const <Widget>[],
    this.icon,
    this.semanticLabel,
    this.scrollable = false,
    super.key,
  });

  static const double _maxWidth = 560;

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final Widget? icon;
  final String? semanticLabel;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxWidth, maxHeight: maxHeight),
        child: _DialogBody(
          title: title,
          content: content,
          actions: actions,
          icon: icon,
          scrollable: scrollable,
          compact: compact,
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final EdgeInsets padding = EdgeInsets.all(
      compact ? theme.spacing.md : theme.spacing.lg,
    );
    final TextStyle titleStyle =
        theme.textTheme.titleLarge ??
        TextStyle(color: colorScheme.onSurface, fontSize: 22);
    final TextStyle contentStyle =
        theme.textTheme.bodyMedium ?? TextStyle(color: colorScheme.onSurface);
    final List<Widget> header = <Widget>[
      if (icon != null) ...<Widget>[
        Center(
          child: IconTheme.merge(
            data: IconThemeData(color: colorScheme.primary),
            child: icon!,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
      ],
      if (title != null) DefaultTextStyle(style: titleStyle, child: title!),
    ];
    final Widget? dialogContent = content == null
        ? null
        : DefaultTextStyle(style: contentStyle, child: content!);

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ...header,
          if (dialogContent != null) ...<Widget>[
            if (header.isNotEmpty) SizedBox(height: theme.spacing.md),
            if (scrollable)
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: dialogContent,
                ),
              )
            else
              dialogContent,
          ],
          if (actions.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.lg),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: theme.spacing.sm,
              overflowSpacing: theme.spacing.sm,
              children: actions,
            ),
          ],
        ],
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

  if (previousFocus case final FocusNode node
      when node.context != null && node.canRequestFocus) {
    node.requestFocus();
  }

  return result;
}
