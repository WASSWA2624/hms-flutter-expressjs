import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_dialog_title.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_field_label.dart';
import 'package:hosspi_hms/shared/layout/app_dialog_insets.dart';

class AppDialog extends StatefulWidget {
  const AppDialog({
    this.title,
    this.content,
    this.actions = const <Widget>[],
    this.icon,
    this.semanticLabel,
    this.scrollable = false,
    this.pinActionsToBottom = false,
    this.showCloseButton = true,
    this.showMaximizeButton = true,
    this.resizable = true,
    this.closeEnabled = true,
    this.initialMaximized = true,
    this.maxWidth = _defaultMaxWidth,
    super.key,
  });

  static const double _defaultMaxWidth = 600;
  @visibleForTesting
  static const Key shellKey = ValueKey<String>('appDialogShell');

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final Widget? icon;
  final String? semanticLabel;
  final bool scrollable;
  final bool pinActionsToBottom;
  final bool showCloseButton;
  final bool showMaximizeButton;
  final bool resizable;
  final bool closeEnabled;
  final bool initialMaximized;
  final double maxWidth;

  @override
  State<AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<AppDialog> {
  final GlobalKey _dialogShellKey = GlobalKey(debugLabel: 'appDialogShell');

  Offset _dragOffset = Offset.zero;
  Size? _desktopSize;
  Size? _preMaximizeSize;
  Offset? _preMaximizeDragOffset;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMaximized) {
      _isMaximized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppDesignTokens designTokens = theme.appTokens;
    final Size viewport = MediaQuery.sizeOf(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool compact = breakpoint.index < AppBreakpoint.md.index;
    final bool desktopInteractive = breakpoint.index >= AppBreakpoint.md.index;
    final EdgeInsets insetPadding = AppDialogInsets.paddingFor(
      breakpoint,
      designTokens: designTokens,
      maximized: _isMaximized,
    );
    final double maxHeight = math.max(
      theme.spacing.none,
      viewport.height - insetPadding.vertical,
    );
    final double availableWidth = math.max(
      theme.spacing.none,
      viewport.width - insetPadding.horizontal,
    );
    final double defaultWidth = widget.maxWidth.isFinite
        ? math.min(widget.maxWidth, availableWidth)
        : availableWidth;
    final double defaultScrollableHeight = _defaultScrollableShellHeight(
      maxHeight,
      designTokens,
    );
    final Size? desktopSize = _desktopSize;
    final double shellWidth = _isMaximized
        ? availableWidth
        : (desktopSize?.width ?? defaultWidth);
    final double shellHeight = _isMaximized
        ? maxHeight
        : (desktopSize?.height ??
              (widget.scrollable && desktopInteractive
                  ? defaultScrollableHeight
                  : maxHeight));
    final BoxConstraints dialogConstraints = BoxConstraints(
      maxWidth: _isMaximized || desktopInteractive ? shellWidth : defaultWidth,
      maxHeight: shellHeight,
    );
    final bool resizeEnabled =
        desktopInteractive && !_isMaximized && widget.resizable;
    final bool pinFooter =
        widget.pinActionsToBottom && widget.actions.isNotEmpty;
    final bool fillShellHeight =
        pinFooter ||
        _isMaximized ||
        (desktopInteractive && desktopSize != null) ||
        (desktopInteractive && widget.scrollable && !_isMaximized);

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
        fillHeight: fillShellHeight,
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

    final bool enforceShellHeight = pinFooter || fillShellHeight;
    Widget dialogBody = ConstrainedBox(
      constraints: desktopInteractive
          ? BoxConstraints(
              minHeight: enforceShellHeight ? dialogConstraints.maxHeight : 0,
              maxHeight: dialogConstraints.maxHeight,
            )
          : enforceShellHeight
          ? BoxConstraints(
              minHeight: dialogConstraints.maxHeight,
              maxHeight: dialogConstraints.maxHeight,
            )
          : dialogConstraints,
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: dialogContent,
      ),
    );

    if (desktopInteractive || pinFooter || _isMaximized) {
      dialogBody = SizedBox(
        key: desktopInteractive || _isMaximized ? AppDialog.shellKey : null,
        width: _isMaximized || desktopInteractive
            ? dialogConstraints.maxWidth
            : null,
        height: fillShellHeight ? dialogConstraints.maxHeight : null,
        child: KeyedSubtree(
          key: desktopInteractive || _isMaximized ? _dialogShellKey : null,
          child: dialogBody,
        ),
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
            bottom: designTokens.dialogResizeHandleThickness,
            width: designTokens.dialogResizeHandleThickness,
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
            right: designTokens.dialogResizeHandleThickness,
            bottom: 0,
            height: designTokens.dialogResizeHandleThickness,
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
      alignment: _isMaximized && desktopInteractive
          ? Alignment.topCenter
          : Alignment.center,
      elevation: theme.dialogTheme.elevation ?? 24,
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

  void _toggleMaximize() {
    final Size viewport = MediaQuery.sizeOf(context);
    final ThemeData theme = Theme.of(context);
    final AppDesignTokens designTokens = theme.appTokens;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final EdgeInsets normalInsetPadding = AppDialogInsets.paddingFor(
      breakpoint,
      designTokens: designTokens,
      maximized: false,
    );
    final double insetAvailableWidth = math.max(
      designTokens.dialogMinWidth,
      viewport.width - normalInsetPadding.horizontal,
    );
    final double insetAvailableHeight = math.max(
      designTokens.dialogMinHeight,
      viewport.height - normalInsetPadding.vertical,
    );
    final double defaultWidth = widget.maxWidth.isFinite
        ? math.min(widget.maxWidth, insetAvailableWidth)
        : insetAvailableWidth;

    if (_isMaximized) {
      final Size restoredSize =
          _preMaximizeSize ??
          Size(
            defaultWidth,
            math.min(insetAvailableHeight, insetAvailableHeight * 0.85),
          );
      setState(() {
        _isMaximized = false;
        _desktopSize = restoredSize;
        _dragOffset = _preMaximizeDragOffset ?? Offset.zero;
        _preMaximizeSize = null;
        _preMaximizeDragOffset = null;
      });
      return;
    }

    final Size currentSize =
        _desktopSize ??
        _measuredShellSize(
          designTokens,
          defaultWidth,
          insetAvailableWidth,
          insetAvailableHeight,
        );
    final Size maximizedSize = AppDialogInsets.availableSizeFor(
      viewport,
      breakpoint,
      designTokens: designTokens,
      maximized: true,
    );
    setState(() {
      _preMaximizeSize = currentSize;
      _preMaximizeDragOffset = _dragOffset;
      _isMaximized = true;
      _desktopSize = maximizedSize;
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
    final ThemeData theme = Theme.of(context);
    final AppDesignTokens designTokens = theme.appTokens;

    if (_isMaximized) {
      setState(() {
        _isMaximized = false;
        _preMaximizeSize = null;
        _preMaximizeDragOffset = null;
      });
    }

    final double availableWidth = math.max(
      designTokens.dialogMinWidth,
      viewport.width - insetPadding.horizontal,
    );
    final double availableHeight = math.max(
      designTokens.dialogMinHeight,
      viewport.height - insetPadding.vertical,
    );
    final Size current =
        _desktopSize ??
        _measuredShellSize(
          designTokens,
          defaultWidth,
          availableWidth,
          availableHeight,
        );
    setState(() {
      final double nextWidth = axis == Axis.vertical
          ? current.width
          : math.min(
              availableWidth,
              math.max(
                designTokens.dialogMinWidth,
                current.width + details.delta.dx,
              ),
            );
      final double nextHeight = axis == Axis.horizontal
          ? current.height
          : math.min(
              availableHeight,
              math.max(
                designTokens.dialogMinHeight,
                current.height + details.delta.dy,
              ),
            );
      _desktopSize = Size(nextWidth, nextHeight);
    });
  }

  static double _defaultScrollableShellHeight(
    double maxHeight,
    AppDesignTokens designTokens,
  ) {
    return math.max(
      designTokens.dialogMinHeight,
      math.min(maxHeight, maxHeight * 0.75),
    );
  }

  Size _measuredShellSize(
    AppDesignTokens designTokens,
    double defaultWidth,
    double availableWidth,
    double availableHeight,
  ) {
    final Size? measured = _dialogShellKey.currentContext?.size;
    if (measured != null) {
      return Size(
        math.max(designTokens.dialogMinWidth, measured.width),
        math.max(designTokens.dialogMinHeight, measured.height),
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
        ((compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge) ??
                TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: compact ? 18 : 22,
                ))
            .copyWith(fontWeight: FontWeight.w700);
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
          fillHeight
              ? Expanded(
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
                )
              : Padding(
                  padding: bodyPadding,
                  child: scrollable
                      ? SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: dialogContent,
                        )
                      : dialogContent,
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
                      child: normalizeDialogTitleWidget(title!),
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
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: padding,
        child: actions.length <= 2
            ? Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int i = 0; i < actions.length; i++)
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: i == 0 ? 0 : theme.spacing.sm,
                          ),
                          child: actions[i],
                        ),
                    ],
                  ),
                ),
              )
            : OverflowBar(
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
    builder: (BuildContext dialogContext) {
      return FocusTraversalGroup(child: builder(dialogContext));
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
