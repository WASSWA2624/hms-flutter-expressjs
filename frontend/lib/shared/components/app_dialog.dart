import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/src/app_field_label.dart';

class AppDialog extends StatefulWidget {
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
  State<AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<AppDialog> {
  static const double _desktopMinWidth = 360;
  static const double _desktopMinHeight = 280;

  Offset _dragOffset = Offset.zero;
  Size? _desktopSize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Size viewport = MediaQuery.sizeOf(context);
    final bool compact = viewport.width < 600;
    final bool desktopInteractive = !compact;
    final EdgeInsets insetPadding = EdgeInsets.symmetric(
      horizontal: compact ? theme.spacing.md : theme.spacing.xl,
      vertical: compact ? theme.spacing.md : theme.spacing.xl,
    );
    final double maxHeight = math.max(
      theme.spacing.none,
      viewport.height - insetPadding.vertical,
    );
    final double availableWidth = math.max(
      theme.spacing.none,
      viewport.width - insetPadding.horizontal,
    );
    final double defaultWidth = math.min(widget.maxWidth, availableWidth);
    final Size? desktopSize = _desktopSize;
    final BoxConstraints dialogConstraints = BoxConstraints(
      maxWidth: desktopInteractive
          ? (desktopSize?.width ?? defaultWidth)
          : widget.maxWidth,
      maxHeight: desktopInteractive
          ? (desktopSize?.height ?? maxHeight)
          : maxHeight,
    );

    final Widget dialogContent = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: _DialogBody(
        title: widget.title,
        content: widget.content,
        actions: widget.actions,
        icon: widget.icon,
        scrollable: widget.scrollable,
        compact: compact,
        showCloseButton: widget.showCloseButton,
        closeEnabled: widget.closeEnabled,
        onHeaderDragUpdate: desktopInteractive
            ? (DragUpdateDetails details) {
                _handleDrag(details, viewport, insetPadding);
              }
            : null,
      ),
    );

    Widget dialogBody = ConstrainedBox(
      constraints: desktopInteractive
          ? BoxConstraints(maxHeight: dialogConstraints.maxHeight)
          : dialogConstraints,
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: dialogContent,
      ),
    );

    if (desktopInteractive) {
      dialogBody = SizedBox(
        width: dialogConstraints.maxWidth,
        child: dialogBody,
      );
    }

    if (desktopInteractive) {
      dialogBody = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          dialogBody,
          PositionedDirectional(
            end: theme.spacing.xs,
            bottom: theme.spacing.xs,
            child: _DialogResizeHandle(
              onDragUpdate: (DragUpdateDetails details) {
                _handleResize(details, viewport, insetPadding, defaultWidth);
              },
            ),
          ),
        ],
      );
    }

    Widget dialog = Dialog(
      insetPadding: insetPadding,
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.antiAlias,
      backgroundColor: colorScheme.surface,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.28),
      child: dialogBody,
    );

    if (desktopInteractive) {
      dialog = Transform.translate(offset: _dragOffset, child: dialog);
    }

    if (widget.semanticLabel != null) {
      dialog = Semantics(
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        label: widget.semanticLabel,
        child: dialog,
      );
    }

    return FocusTraversalGroup(child: dialog);
  }

  void _handleDrag(
    DragUpdateDetails details,
    Size viewport,
    EdgeInsets insetPadding,
  ) {
    final double maxX = math.max(0, viewport.width / 2 - insetPadding.left);
    final double maxY = math.max(0, viewport.height / 2 - insetPadding.top);
    final Offset next = _dragOffset + details.delta;
    setState(() {
      _dragOffset = Offset(
        next.dx.clamp(-maxX, maxX).toDouble(),
        next.dy.clamp(-maxY, maxY).toDouble(),
      );
    });
  }

  void _handleResize(
    DragUpdateDetails details,
    Size viewport,
    EdgeInsets insetPadding,
    double defaultWidth,
  ) {
    final double availableWidth = math.max(
      _desktopMinWidth,
      viewport.width - insetPadding.horizontal,
    );
    final double availableHeight = math.max(
      _desktopMinHeight,
      viewport.height - insetPadding.vertical,
    );
    final Size current = _desktopSize ?? Size(defaultWidth, availableHeight);
    setState(() {
      _desktopSize = Size(
        (current.width + details.delta.dx)
            .clamp(_desktopMinWidth, availableWidth)
            .toDouble(),
        (current.height + details.delta.dy)
            .clamp(_desktopMinHeight, availableHeight)
            .toDouble(),
      );
    });
  }
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({
    required this.actions,
    required this.scrollable,
    required this.compact,
    required this.showCloseButton,
    required this.closeEnabled,
    this.onHeaderDragUpdate,
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
  final ValueChanged<DragUpdateDetails>? onHeaderDragUpdate;

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
          onDragUpdate: onHeaderDragUpdate,
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
    this.onDragUpdate,
  });

  final Widget? title;
  final Widget? icon;
  final TextStyle titleStyle;
  final bool showCloseButton;
  final bool closeEnabled;
  final bool compact;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;

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

    final Widget header = DecoratedBox(
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

    final ValueChanged<DragUpdateDetails>? dragHandler = onDragUpdate;
    if (dragHandler == null) {
      return header;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: dragHandler,
        child: header,
      ),
    );
  }
}

class _DialogResizeHandle extends StatelessWidget {
  const _DialogResizeHandle({required this.onDragUpdate});

  final ValueChanged<DragUpdateDetails> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onDragUpdate,
        child: Tooltip(
          message: 'Resize dialog',
          child: SizedBox.square(
            dimension: theme.appTokens.minInteractiveDimension,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.open_in_full,
                size: theme.appTokens.listIconSize - 2,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
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
