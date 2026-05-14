import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_template/app/theme/app_theme_extensions.dart';
import 'package:flutter_template/core/network/app_connectivity_status.dart';
import 'package:flutter_template/core/responsive/app_breakpoints.dart';
import 'package:flutter_template/shared/components/components.dart';

final class ResponsiveShellDestination {
  const ResponsiveShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class ResponsiveAppShell extends ResponsiveShellScaffold {
  const ResponsiveAppShell({
    required super.title,
    required super.destinations,
    required super.selectedIndex,
    required super.onDestinationSelected,
    required super.child,
    super.connectivityStatus,
    super.showUserAvatar,
    super.compactTitle,
    super.onlineLabel,
    super.offlineLabel,
    super.openMenuTooltip,
    super.closeDrawerTooltip,
    super.toggleSidebarTooltip,
    super.accountTooltip,
    super.key,
  });
}

class ResponsiveShellScaffold extends StatefulWidget {
  const ResponsiveShellScaffold({
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.connectivityStatus = AppConnectivityStatus.online,
    this.showUserAvatar = true,
    this.compactTitle,
    this.onlineLabel = 'Online',
    this.offlineLabel = 'Offline',
    this.openMenuTooltip = 'Open navigation menu',
    this.closeDrawerTooltip = 'Close navigation menu',
    this.toggleSidebarTooltip = 'Toggle sidebar',
    this.accountTooltip = 'Account',
    super.key,
  });

  final String title;
  final List<ResponsiveShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final AppConnectivityStatus connectivityStatus;
  final bool showUserAvatar;
  final String? compactTitle;
  final String onlineLabel;
  final String offlineLabel;
  final String openMenuTooltip;
  final String closeDrawerTooltip;
  final String toggleSidebarTooltip;
  final String accountTooltip;
  final Widget child;

  @override
  State<ResponsiveShellScaffold> createState() =>
      _ResponsiveShellScaffoldState();
}

class _ResponsiveShellScaffoldState extends State<ResponsiveShellScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarCollapsed = false;
  double _sidebarWidth = _defaultSidebarWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final AppBreakpoint breakpoint = AppBreakpoints.fromConstraints(
          constraints,
        );
        final bool isMobile = breakpoint.isMobile;
        final bool canNavigate = widget.destinations.length > 1;
        final int effectiveSelectedIndex = widget.destinations.isEmpty
            ? 0
            : widget.selectedIndex.clamp(0, widget.destinations.length - 1);

        return Scaffold(
          key: _scaffoldKey,
          drawer: isMobile && canNavigate
              ? _MobileShellDrawer(
                  title: widget.title,
                  destinations: widget.destinations,
                  selectedIndex: effectiveSelectedIndex,
                  closeTooltip: widget.closeDrawerTooltip,
                  onDestinationSelected: _selectMobileDestination,
                )
              : null,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                AppMenuBar(
                  title: widget.title,
                  compactTitle: widget.compactTitle,
                  breakpoint: breakpoint,
                  connectivityStatus: widget.connectivityStatus,
                  onlineLabel: widget.onlineLabel,
                  offlineLabel: widget.offlineLabel,
                  showUserAvatar: widget.showUserAvatar,
                  accountTooltip: widget.accountTooltip,
                  toggleTooltip: isMobile
                      ? widget.openMenuTooltip
                      : widget.toggleSidebarTooltip,
                  onToggleNavigation: isMobile
                      ? _openMobileDrawer
                      : _toggleDesktopSidebar,
                ),
                Expanded(
                  child: isMobile
                      ? widget.child
                      : Row(
                          children: <Widget>[
                            SideNavigation(
                              destinations: widget.destinations,
                              selectedIndex: effectiveSelectedIndex,
                              collapsed: _sidebarCollapsed,
                              width: _sidebarCollapsed
                                  ? _collapsedSidebarWidth
                                  : _sidebarWidth,
                              onDestinationSelected:
                                  widget.onDestinationSelected,
                            ),
                            if (!_sidebarCollapsed)
                              _SidebarResizeHandle(onDrag: _resizeSidebar),
                            const VerticalDivider(width: _dividerWidth),
                            Expanded(child: widget.child),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openMobileDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _toggleDesktopSidebar() {
    setState(() {
      _sidebarCollapsed = !_sidebarCollapsed;
    });
  }

  void _resizeSidebar(double delta) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + delta).clamp(
        _minSidebarWidth,
        _maxSidebarWidth,
      );
    });
  }

  void _selectMobileDestination(int index) {
    Navigator.of(context).pop();
    if (index != widget.selectedIndex) {
      widget.onDestinationSelected(index);
    }
  }
}

class AppMenuBar extends StatelessWidget {
  const AppMenuBar({
    required this.title,
    required this.breakpoint,
    required this.connectivityStatus,
    required this.onlineLabel,
    required this.offlineLabel,
    required this.showUserAvatar,
    required this.accountTooltip,
    required this.toggleTooltip,
    required this.onToggleNavigation,
    this.compactTitle,
    super.key,
  });

  final String title;
  final String? compactTitle;
  final AppBreakpoint breakpoint;
  final AppConnectivityStatus connectivityStatus;
  final String onlineLabel;
  final String offlineLabel;
  final bool showUserAvatar;
  final String accountTooltip;
  final String toggleTooltip;
  final VoidCallback onToggleNavigation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isMobile = breakpoint.isMobile;
    final bool hideTitle = breakpoint == AppBreakpoint.xs;
    final String effectiveTitle = isMobile ? compactTitle ?? title : title;
    final double logoSize = isMobile ? _mobileHeaderLogoSize : _headerLogoSize;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: theme.appTokens.dividerThickness,
          ),
        ),
      ),
      child: SizedBox(
        height: _headerHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
          child: Row(
            children: <Widget>[
              AppIconButton(
                semanticLabel: toggleTooltip,
                tooltip: toggleTooltip,
                icon: Icons.menu,
                onPressed: onToggleNavigation,
              ),
              SizedBox(width: theme.spacing.xs),
              AppLogo(size: logoSize),
              if (!hideTitle) SizedBox(width: theme.spacing.sm),
              Expanded(
                child: hideTitle
                    ? const SizedBox.shrink()
                    : Text(
                        effectiveTitle,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (!isMobile)
                _ConnectivityBadge(
                  status: connectivityStatus,
                  onlineLabel: onlineLabel,
                  offlineLabel: offlineLabel,
                ),
              if (showUserAvatar) ...<Widget>[
                SizedBox(width: theme.spacing.sm),
                Tooltip(
                  message: accountTooltip,
                  child: _UserAvatar(
                    status: connectivityStatus,
                    showStatusDot: isMobile,
                    onlineLabel: onlineLabel,
                    offlineLabel: offlineLabel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectivityBadge extends StatelessWidget {
  const _ConnectivityBadge({
    required this.status,
    required this.onlineLabel,
    required this.offlineLabel,
  });

  final AppConnectivityStatus status;
  final String onlineLabel;
  final String offlineLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isOnline = status.isOnline;
    final Color foregroundColor = isOnline
        ? theme.statusColors.success
        : theme.statusColors.error;
    final Color backgroundColor = isOnline
        ? theme.statusColors.successContainer
        : theme.statusColors.errorContainer;
    final String label = isOnline ? onlineLabel : offlineLabel;

    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(color: backgroundColor),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.circle, size: _statusDotSize, color: foregroundColor),
              SizedBox(width: theme.spacing.xs),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.status,
    required this.showStatusDot,
    required this.onlineLabel,
    required this.offlineLabel,
  });

  final AppConnectivityStatus status;
  final bool showStatusDot;
  final String onlineLabel;
  final String offlineLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Widget avatar = CircleAvatar(
      radius: _avatarRadius,
      backgroundColor: colorScheme.surfaceContainerHighest,
      foregroundColor: colorScheme.onSurfaceVariant,
      child: const Icon(Icons.person_outline, size: _avatarIconSize),
    );

    if (!showStatusDot) {
      return avatar;
    }

    final bool isOnline = status.isOnline;
    final Color dotColor = isOnline
        ? theme.statusColors.success
        : colorScheme.outline;
    final String statusLabel = isOnline ? onlineLabel : offlineLabel;

    return Semantics(
      label: statusLabel,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: _avatarStatusDotSize),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileShellDrawer extends StatelessWidget {
  const _MobileShellDrawer({
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.closeTooltip,
    required this.onDestinationSelected,
  });

  final String title;
  final List<ResponsiveShellDestination> destinations;
  final int selectedIndex;
  final String closeTooltip;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: _drawerHeaderHeight,
              child: Padding(
                padding: EdgeInsets.only(
                  left: theme.spacing.md,
                  right: theme.spacing.xs,
                ),
                child: Row(
                  children: <Widget>[
                    const AppLogo(size: _drawerLogoSize),
                    SizedBox(width: theme.spacing.sm),
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AppIconButton(
                      semanticLabel: closeTooltip,
                      tooltip: closeTooltip,
                      icon: Icons.close,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: _dividerWidth),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
                itemCount: destinations.length,
                itemBuilder: (BuildContext context, int index) {
                  return _ShellMenuItem(
                    destination: destinations[index],
                    selected: index == selectedIndex,
                    showLabel: true,
                    onTap: () {
                      onDestinationSelected(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SideNavigation extends StatelessWidget {
  const SideNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.collapsed,
    required this.width,
    required this.onDestinationSelected,
    super.key,
  });

  final List<ResponsiveShellDestination> destinations;
  final int selectedIndex;
  final bool collapsed;
  final double width;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: _sidebarAnimationDuration,
      curve: Curves.easeOutCubic,
      width: width,
      color: colorScheme.surfaceContainerLowest,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
        itemCount: destinations.length,
        itemBuilder: (BuildContext context, int index) {
          return _ShellMenuItem(
            destination: destinations[index],
            selected: index == selectedIndex,
            showLabel: !collapsed,
            onTap: () {
              if (index != selectedIndex) {
                onDestinationSelected(index);
              }
            },
          );
        },
      ),
    );
  }
}

class _ShellMenuItem extends StatefulWidget {
  const _ShellMenuItem({
    required this.destination,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final ResponsiveShellDestination destination;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  State<_ShellMenuItem> createState() => _ShellMenuItemState();
}

class _ShellMenuItemState extends State<_ShellMenuItem> {
  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      };

  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color selectedColor = colorScheme.secondaryContainer;
    final Color hoverColor = colorScheme.surfaceContainerHighest;
    final Color focusColor = colorScheme.primary;
    final Color foregroundColor = widget.selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    final Widget content = AnimatedContainer(
      duration: _menuAnimationDuration,
      height: _menuItemHeight,
      margin: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: widget.showLabel ? theme.spacing.sm : theme.spacing.none,
      ),
      decoration: BoxDecoration(
        color: widget.selected
            ? selectedColor
            : _hovered || _focused
            ? hoverColor
            : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: widget.selected || _focused
                ? colorScheme.primary
                : Colors.transparent,
            width: _selectedIndicatorWidth,
          ),
          top: _focused
              ? BorderSide(color: focusColor, width: _focusIndicatorWidth)
              : BorderSide.none,
          right: _focused
              ? BorderSide(color: focusColor, width: _focusIndicatorWidth)
              : BorderSide.none,
          bottom: _focused
              ? BorderSide(color: focusColor, width: _focusIndicatorWidth)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisAlignment: widget.showLabel
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            widget.selected
                ? widget.destination.selectedIcon
                : widget.destination.icon,
            color: foregroundColor,
            size: theme.appTokens.listIconSize,
          ),
          if (widget.showLabel) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                widget.destination.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: widget.selected ? FontWeight.w700 : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: Focus(
          onFocusChange: (bool focused) {
            setState(() {
              _focused = focused;
            });
          },
          child: Tooltip(
            message: widget.showLabel ? '' : widget.destination.label,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) {
                setState(() {
                  _hovered = true;
                });
              },
              onExit: (_) {
                setState(() {
                  _hovered = false;
                });
              },
              child: Semantics(
                button: true,
                selected: widget.selected,
                enabled: true,
                label: widget.destination.label,
                onTap: widget.onTap,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    canRequestFocus: false,
                    onTap: widget.onTap,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    splashColor: colorScheme.primary.withValues(alpha: 0.08),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarResizeHandle extends StatelessWidget {
  const _SidebarResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.outlineVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          onDrag(details.delta.dx);
        },
        child: SizedBox(
          width: _resizeHandleWidth,
          child: Center(
            child: SizedBox(
              width: _dividerWidth,
              height: double.infinity,
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

const double _headerHeight = 44;
const double _drawerHeaderHeight = 44;
const double _headerLogoSize = 24;
const double _mobileHeaderLogoSize = 22;
const double _drawerLogoSize = 24;
const double _defaultSidebarWidth = 208;
const double _minSidebarWidth = 160;
const double _maxSidebarWidth = 272;
const double _collapsedSidebarWidth = 72;
const double _resizeHandleWidth = 6;
const double _dividerWidth = 1;
const double _statusDotSize = 7;
const double _avatarRadius = 13;
const double _avatarIconSize = 17;
const double _avatarStatusDotSize = 7;
const double _selectedIndicatorWidth = 2;
const double _focusIndicatorWidth = 2;
const double _menuItemHeight = 36;
const Duration _menuAnimationDuration = Duration(milliseconds: 120);
const Duration _sidebarAnimationDuration = Duration(milliseconds: 180);
