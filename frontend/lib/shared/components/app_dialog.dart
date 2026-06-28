import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_field_label.dart';

class AppDialog extends StatefulWidget {
  const AppDialog({
    this.title,
    this.content,
    this.actions = const <Widget>[],
    this.icon,
    this.semanticLabel,
    this.scrollable = false,
    this.showCloseButton = true,
    this.showMaximizeButton = true,
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
  final bool showMaximizeButton;
  final bool closeEnabled;
  final double maxWidth;

  @override
  State<AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<AppDialog> {
  static const double _desktopMinWidth = 360;
  static const double _desktopMinHeight = 280;
  static const double _snackBarClearance = 88;
  static const double _resizeHandleThickness = 6;

  final GlobalKey _dialogShellKey = GlobalKey(debugLabel: 'appDialogShell');

  Offset _dragOffset = Offset.zero;
  Size? _desktopSize;
  Size? _preMaximizeSize;
  Offset? _preMaximizeDragOffset;
  bool _isMaximized = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Size viewport = MediaQuery.sizeOf(context);
    final bool compact = viewport.width < 600;
    final bool desktopInteractive = !compact;
    final EdgeInsets insetPadding = _isMaximized
        ? EdgeInsets.zero
        : _dialogInsetPadding(theme, compact);
    final double maxHeight = _isMaximized
        ? viewport.height
        : math.max(theme.spacing.none, viewport.height - insetPadding.vertical);
    final double availableWidth = _isMaximized
        ? viewport.width
        : math.max(
            theme.spacing.none,
            viewport.width - insetPadding.horizontal,
          );
    final double defaultWidth = widget.maxWidth.isFinite
        ? math.min(widget.maxWidth, availableWidth)
        : availableWidth;
    final Size? desktopSize = _desktopSize;
    final BoxConstraints dialogConstraints = BoxConstraints(
      maxWidth: desktopInteractive
          ? (desktopSize?.width ?? defaultWidth)
          : defaultWidth,
      maxHeight: desktopInteractive
          ? (desktopSize?.height ?? maxHeight)
          : maxHeight,
    );
    final bool resizeEnabled = desktopInteractive && !_isMaximized;

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
        fillHeight: desktopInteractive && desktopSize != null,
        compact: compact,
        showCloseButton: widget.showCloseButton,
        showMaximizeButton: widget.showMaximizeButton && desktopInteractive,
        isMaximized: _isMaximized,
        closeEnabled: widget.closeEnabled,
        onMaximizeToggle: desktopInteractive ? _toggleMaximize : null,
        onHeaderDragUpdate: desktopInteractive && !_isMaximized
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
        key: _dialogShellKey,
        width: dialogConstraints.maxWidth,
        height: desktopSize == null ? null : dialogConstraints.maxHeight,
        child: dialogBody,
      );
    }

    if (resizeEnabled) {
      dialogBody = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          dialogBody,
          PositionedDirectional(
            top: 0,
            end: 0,
            bottom: _resizeHandleThickness,
            width: _resizeHandleThickness,
            child: _DialogResizeHandle(
              axis: Axis.horizontal,
              tooltip: 'Resize width',
              onDragUpdate: (DragUpdateDetails details) {
                _handleResize(
                  details,
                  viewport,
                  insetPadding,
                  defaultWidth,
                  axis: Axis.horizontal,
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: _resizeHandleThickness,
            bottom: 0,
            height: _resizeHandleThickness,
            child: _DialogResizeHandle(
              axis: Axis.vertical,
              tooltip: 'Resize height',
              onDragUpdate: (DragUpdateDetails details) {
                _handleResize(
                  details,
                  viewport,
                  insetPadding,
                  defaultWidth,
                  axis: Axis.vertical,
                );
              },
            ),
          ),
          PositionedDirectional(
            end: 0,
            bottom: 0,
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

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (widget.closeEnabled) {
            Navigator.of(context).maybePop();
          }
        },
      },
      child: Focus(autofocus: true, child: FocusTraversalGroup(child: dialog)),
    );
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

  EdgeInsets _dialogInsetPadding(ThemeData theme, bool compact) {
    final double horizontalInset = compact
        ? theme.spacing.md
        : theme.spacing.xl;
    final double topInset = compact ? theme.spacing.md : theme.spacing.xl;
    return EdgeInsets.only(
      left: horizontalInset,
      top: topInset,
      right: horizontalInset,
      bottom: topInset + _snackBarClearance,
    );
  }

  void _toggleMaximize() {
    final Size viewport = MediaQuery.sizeOf(context);
    final ThemeData theme = Theme.of(context);
    final EdgeInsets insetPadding = _dialogInsetPadding(theme, false);
    final double availableWidth = math.max(
      _desktopMinWidth,
      viewport.width - insetPadding.horizontal,
    );
    final double availableHeight = math.max(
      _desktopMinHeight,
      viewport.height - insetPadding.vertical,
    );
    final double defaultWidth = widget.maxWidth.isFinite
        ? math.min(widget.maxWidth, availableWidth)
        : availableWidth;

    if (_isMaximized) {
      setState(() {
        _isMaximized = false;
        _desktopSize = _preMaximizeSize;
        _dragOffset = _preMaximizeDragOffset ?? Offset.zero;
        _preMaximizeSize = null;
        _preMaximizeDragOffset = null;
      });
      return;
    }

    final Size currentSize =
        _desktopSize ??
        _measuredShellSize(defaultWidth, availableWidth, availableHeight);
    setState(() {
      _preMaximizeSize = currentSize;
      _preMaximizeDragOffset = _dragOffset;
      _isMaximized = true;
      _desktopSize = Size(viewport.width, viewport.height);
      _dragOffset = Offset.zero;
    });
  }

  void _handleResize(
    DragUpdateDetails details,
    Size viewport,
    EdgeInsets insetPadding,
    double defaultWidth, {
    Axis? axis,
  }) {
    if (_isMaximized) {
      setState(() {
        _isMaximized = false;
        _preMaximizeSize = null;
        _preMaximizeDragOffset = null;
      });
    }

    final double availableWidth = math.max(
      _desktopMinWidth,
      viewport.width - insetPadding.horizontal,
    );
    final double availableHeight = math.max(
      _desktopMinHeight,
      viewport.height - insetPadding.vertical,
    );
    final Size current =
        _desktopSize ??
        _measuredShellSize(defaultWidth, availableWidth, availableHeight);
    setState(() {
      final double nextWidth = axis == Axis.vertical
          ? current.width
          : math.max(_desktopMinWidth, current.width + details.delta.dx);
      final double nextHeight = axis == Axis.horizontal
          ? current.height
          : math.max(_desktopMinHeight, current.height + details.delta.dy);
      _desktopSize = Size(nextWidth, nextHeight);
    });
  }

  Size _measuredShellSize(
    double defaultWidth,
    double availableWidth,
    double availableHeight,
  ) {
    final Size? measured = _dialogShellKey.currentContext?.size;
    if (measured != null) {
      return Size(
        math.max(_desktopMinWidth, measured.width),
        math.max(_desktopMinHeight, measured.height),
      );
    }
    return Size(defaultWidth, availableHeight);
  }
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({
    required this.actions,
    required this.scrollable,
    required this.fillHeight,
    required this.compact,
    required this.showCloseButton,
    required this.showMaximizeButton,
    required this.isMaximized,
    required this.closeEnabled,
    this.onMaximizeToggle,
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
  final bool fillHeight;
  final bool compact;
  final bool showCloseButton;
  final bool showMaximizeButton;
  final bool isMaximized;
  final bool closeEnabled;
  final VoidCallback? onMaximizeToggle;
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
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DialogHeader(
          title: title,
          icon: icon,
          titleStyle: titleStyle,
          showCloseButton: showCloseButton,
          showMaximizeButton: showMaximizeButton,
          isMaximized: isMaximized,
          closeEnabled: closeEnabled,
          compact: compact,
          onMaximizeToggle: onMaximizeToggle,
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
    required this.showMaximizeButton,
    required this.isMaximized,
    required this.closeEnabled,
    required this.compact,
    this.onMaximizeToggle,
    this.onDragUpdate,
  });

  final Widget? title;
  final Widget? icon;
  final TextStyle titleStyle;
  final bool showCloseButton;
  final bool showMaximizeButton;
  final bool isMaximized;
  final bool closeEnabled;
  final bool compact;
  final VoidCallback? onMaximizeToggle;
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
            if (showMaximizeButton)
              AppButton(
                iconOnly: true,
                leadingIcon: isMaximized
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                label: isMaximized ? 'Restore dialog' : 'Maximize dialog',
                semanticLabel: isMaximized
                    ? 'Restore dialog'
                    : 'Maximize dialog',
                tooltip: isMaximized ? 'Restore dialog' : 'Maximize dialog',
                onPressed: onMaximizeToggle,
              ),
            if (showCloseButton)
              AppButton(
                iconOnly: true,
                leadingIcon: Icons.close,
                label: MaterialLocalizations.of(context).closeButtonTooltip,
                semanticLabel: MaterialLocalizations.of(
                  context,
                ).closeButtonTooltip,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                enabled: closeEnabled,
                onPressed: closeEnabled
                    ? () {
                        Navigator.of(context).maybePop();
                      }
                    : null,
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
  const _DialogResizeHandle({
    required this.onDragUpdate,
    this.axis,
    this.tooltip = 'Resize dialog',
  });

  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final Axis? axis;
  final String tooltip;

  SystemMouseCursor get _cursor {
    return switch (axis) {
      Axis.horizontal => SystemMouseCursors.resizeLeftRight,
      Axis.vertical => SystemMouseCursors.resizeUpDown,
      _ => SystemMouseCursors.resizeDownRight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool showCornerIcon = axis == null;

    final Widget handle = showCornerIcon
        ? SizedBox.square(
            dimension: theme.appTokens.minInteractiveDimension,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.open_in_full,
                size: theme.appTokens.listIconSize - 2,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          )
        : const SizedBox.expand();

    return MouseRegion(
      cursor: _cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onDragUpdate,
        child: Tooltip(message: tooltip, child: handle),
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
