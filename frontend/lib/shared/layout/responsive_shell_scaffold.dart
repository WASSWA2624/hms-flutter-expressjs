import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_connectivity_indicator.dart';
import 'package:hosspi_hms/shared/layout/app_fullscreen_toggle.dart';
import 'package:hosspi_hms/shared/layout/app_shell_layout.dart';
import 'package:hosspi_hms/shared/layout/shell_navigation_loading.dart';

/// A destination's nested menu item — the one nesting level the sidebar allows.
///
/// Menus that own a hierarchy (Accounts & Finance) expose their categories here.
/// Anything below a category belongs to the workspace tab strip, not the menu.
final class ShellSubmenuItem {
  const ShellSubmenuItem({
    required this.id,
    required this.label,
    required this.icon,
    this.badgeCount,
    this.badgeTone,
    this.tooltip,
  });

  /// Stable identifier the host maps back to a location.
  final String id;
  final String label;
  final IconData icon;
  final int? badgeCount;
  final AppTabCountTone? badgeTone;
  final String? tooltip;
}

final class ResponsiveShellDestination {
  const ResponsiveShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.shortLabel,
    this.groupLabel,
    this.badgeCount,
    this.children = const <ShellSubmenuItem>[],
  });

  final String label;
  final String? shortLabel;
  final IconData icon;
  final IconData selectedIcon;
  final String? groupLabel;
  final int? badgeCount;

  /// Nested menu items, one level deep. Empty for flat destinations.
  final List<ShellSubmenuItem> children;

  bool get hasChildren => children.isNotEmpty;

  String displayLabel({required bool compact}) {
    if (compact) {
      return shortLabel ?? label;
    }
    return label;
  }
}

final class UserMenuProfileData {
  const UserMenuProfileData({
    this.name,
    this.email,
    this.title,
    this.overallRole,
    this.userType,
    this.initials,
  });

  final String? name;
  final String? email;
  final String? title;
  final String? overallRole;
  final String? userType;
  final String? initials;

  bool get hasDetails {
    return _hasText(name) ||
        _hasText(email) ||
        _hasText(title) ||
        _hasText(overallRole) ||
        _hasText(userType);
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

enum ShellSystemIndicatorSeverity { info, warning, error }

final class ShellSystemIndicator {
  const ShellSystemIndicator({
    required this.label,
    required this.icon,
    this.severity = ShellSystemIndicatorSeverity.warning,
  });

  final String label;
  final IconData icon;
  final ShellSystemIndicatorSeverity severity;
}

class ResponsiveAppShell extends ResponsiveShellScaffold {
  const ResponsiveAppShell({
    required super.title,
    required super.destinations,
    required super.selectedIndex,
    required super.onDestinationSelected,
    required super.child,
    super.selectedChildId,
    super.onChildSelected,
    super.connectivityStatus,
    super.showUserAvatar,
    super.compactTitle,
    super.onlineLabel,
    super.offlineLabel,
    super.fullscreenEnterLabel,
    super.fullscreenExitLabel,
    super.openMenuTooltip,
    super.closeDrawerTooltip,
    super.toggleSidebarTooltip,
    super.navigationSearchLabel,
    super.navigationSearchHint,
    super.navigationSearchNoResultsLabel,
    super.accountTooltip,
    super.notificationsTooltip,
    super.notificationsUnreadLabel,
    super.profileLabel,
    super.settingsLabel,
    super.changePasswordLabel,
    super.logoutLabel,
    super.signedInLabel,
    super.userProfile,
    super.unreadNotificationCount,
    super.systemIndicators,
    super.headerTrailingActions,
    super.onNotificationsSelected,
    super.onProfileSelected,
    super.onSettingsSelected,
    super.onChangePasswordSelected,
    super.onLogoutSelected,
    super.initialSidebarCollapsed = false,
    super.onSidebarCollapsedChanged,
    super.isShellLoading = false,
    super.shellRouteKey,
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
    this.selectedChildId,
    this.onChildSelected,
    this.connectivityStatus = AppConnectivityStatus.online,
    this.showUserAvatar = true,
    this.compactTitle,
    this.onlineLabel = 'Online',
    this.offlineLabel = 'Offline',
    this.fullscreenEnterLabel = 'Full screen',
    this.fullscreenExitLabel = 'Exit full screen',
    this.openMenuTooltip = 'Open navigation menu',
    this.closeDrawerTooltip = 'Close navigation menu',
    this.toggleSidebarTooltip = 'Toggle sidebar',
    this.navigationSearchLabel = 'Search menu',
    this.navigationSearchHint = 'Search menu',
    this.navigationSearchNoResultsLabel = 'No menu items found',
    this.accountTooltip = 'Account',
    this.notificationsTooltip = 'Notifications',
    this.notificationsUnreadLabel = 'No unread notifications',
    this.profileLabel = 'Profile',
    this.settingsLabel = 'Settings',
    this.changePasswordLabel = 'Change password',
    this.logoutLabel = 'Logout',
    this.signedInLabel = 'Signed in',
    this.userProfile,
    this.unreadNotificationCount = 0,
    this.systemIndicators = const <ShellSystemIndicator>[],
    this.headerTrailingActions,
    this.onNotificationsSelected,
    this.onProfileSelected,
    this.onSettingsSelected,
    this.onChangePasswordSelected,
    this.onLogoutSelected,
    this.initialSidebarCollapsed = false,
    this.onSidebarCollapsedChanged,
    this.isShellLoading = false,
    this.shellRouteKey,
    super.key,
  });

  final String title;
  final List<ResponsiveShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// [ShellMenuLeaf.id] of the active nested menu item, when one is open.
  final String? selectedChildId;

  /// Called with a [ShellMenuLeaf.id]; the host maps it back to a location.
  final ValueChanged<String>? onChildSelected;
  final AppConnectivityStatus connectivityStatus;
  final bool showUserAvatar;
  final String? compactTitle;
  final String onlineLabel;
  final String offlineLabel;
  final String fullscreenEnterLabel;
  final String fullscreenExitLabel;
  final String openMenuTooltip;
  final String closeDrawerTooltip;
  final String toggleSidebarTooltip;
  final String navigationSearchLabel;
  final String navigationSearchHint;
  final String navigationSearchNoResultsLabel;
  final String accountTooltip;
  final String notificationsTooltip;
  final String notificationsUnreadLabel;
  final String profileLabel;
  final String settingsLabel;
  final String changePasswordLabel;
  final String logoutLabel;
  final String signedInLabel;
  final UserMenuProfileData? userProfile;
  final int unreadNotificationCount;
  final List<ShellSystemIndicator> systemIndicators;
  final Widget? headerTrailingActions;
  final VoidCallback? onNotificationsSelected;
  final VoidCallback? onProfileSelected;
  final VoidCallback? onSettingsSelected;
  final VoidCallback? onChangePasswordSelected;
  final VoidCallback? onLogoutSelected;
  final bool initialSidebarCollapsed;
  final ValueChanged<bool>? onSidebarCollapsedChanged;
  final bool isShellLoading;
  final String? shellRouteKey;
  final Widget child;

  @override
  State<ResponsiveShellScaffold> createState() =>
      _ResponsiveShellScaffoldState();
}

class _ResponsiveShellScaffoldState extends State<ResponsiveShellScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late bool _sidebarCollapsed;
  double _sidebarWidth = AppShellLayout.defaultSidebarWidth;

  @override
  void initState() {
    super.initState();
    _sidebarCollapsed = widget.initialSidebarCollapsed;
  }

  @override
  void didUpdateWidget(ResponsiveShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSidebarCollapsed != widget.initialSidebarCollapsed &&
        widget.initialSidebarCollapsed != _sidebarCollapsed) {
      _sidebarCollapsed = widget.initialSidebarCollapsed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final AppBreakpoint breakpoint = AppBreakpoints.fromConstraints(
          constraints,
        );
        final bool useDrawer = breakpoint.usesDrawerNavigation;
        final bool canNavigate = widget.destinations.length > 1;
        final int effectiveSelectedIndex = widget.destinations.isEmpty
            ? 0
            : widget.selectedIndex.clamp(0, widget.destinations.length - 1);

        return Scaffold(
          key: _scaffoldKey,
          drawer: useDrawer && canNavigate
              ? _MobileShellDrawer(
                  title: widget.compactTitle ?? widget.title,
                  destinations: widget.destinations,
                  selectedIndex: effectiveSelectedIndex,
                  selectedChildId: widget.selectedChildId,
                  closeTooltip: widget.closeDrawerTooltip,
                  onDestinationSelected: _selectMobileDestination,
                  onChildSelected: _selectMobileChild,
                )
              : null,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                RepaintBoundary(
                  child: AppMenuBar(
                    title: widget.title,
                    compactTitle: widget.compactTitle,
                    breakpoint: breakpoint,
                    connectivityStatus: widget.connectivityStatus,
                    onlineLabel: widget.onlineLabel,
                    offlineLabel: widget.offlineLabel,
                    fullscreenEnterLabel: widget.fullscreenEnterLabel,
                    fullscreenExitLabel: widget.fullscreenExitLabel,
                    showUserAvatar: widget.showUserAvatar,
                    accountTooltip: widget.accountTooltip,
                    notificationsTooltip: widget.notificationsTooltip,
                    notificationsUnreadLabel: widget.notificationsUnreadLabel,
                    profileLabel: widget.profileLabel,
                    settingsLabel: widget.settingsLabel,
                    changePasswordLabel: widget.changePasswordLabel,
                    logoutLabel: widget.logoutLabel,
                    signedInLabel: widget.signedInLabel,
                    userProfile: widget.userProfile,
                    unreadNotificationCount: widget.unreadNotificationCount,
                    systemIndicators: widget.systemIndicators,
                    headerTrailingActions: widget.headerTrailingActions,
                    onNotificationsSelected: widget.onNotificationsSelected,
                    onProfileSelected: widget.onProfileSelected,
                    onSettingsSelected: widget.onSettingsSelected,
                    onChangePasswordSelected: widget.onChangePasswordSelected,
                    onLogoutSelected: widget.onLogoutSelected,
                    toggleTooltip: useDrawer
                        ? widget.openMenuTooltip
                        : widget.toggleSidebarTooltip,
                    onToggleNavigation: useDrawer
                        ? _openMobileDrawer
                        : _toggleDesktopSidebar,
                  ),
                ),
                AppShellLoadingBar(visible: widget.isShellLoading),
                Expanded(
                  child: ShellNavigationScope(
                    deferLoadingToShell: true,
                    child: _ShellBody(
                      useDrawer: useDrawer,
                      shellRouteKey: widget.shellRouteKey,
                      isShellLoading: widget.isShellLoading,
                      destinations: widget.destinations,
                      selectedIndex: effectiveSelectedIndex,
                      selectedChildId: widget.selectedChildId,
                      sidebarCollapsed: _sidebarCollapsed,
                      sidebarWidth: _sidebarCollapsed
                          ? AppShellLayout.collapsedSidebarWidth
                          : _sidebarWidth,
                      navigationSearchLabel: widget.navigationSearchLabel,
                      navigationSearchHint: widget.navigationSearchHint,
                      navigationSearchNoResultsLabel:
                          widget.navigationSearchNoResultsLabel,
                      onDestinationSelected: widget.onDestinationSelected,
                      onChildSelected: widget.onChildSelected,
                      onResizeSidebar: _resizeSidebar,
                      child: widget.child,
                    ),
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
    final bool nextCollapsed = !_sidebarCollapsed;
    setState(() {
      _sidebarCollapsed = nextCollapsed;
    });
    widget.onSidebarCollapsedChanged?.call(nextCollapsed);
  }

  void _resizeSidebar(double delta) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + delta).clamp(
        AppShellLayout.minSidebarWidth,
        AppShellLayout.maxSidebarWidth,
      );
    });
  }

  void _selectMobileDestination(int index) {
    Navigator.of(context).pop();
    if (index != widget.selectedIndex) {
      widget.onDestinationSelected(index);
    }
  }

  void _selectMobileChild(String childId) {
    Navigator.of(context).pop();
    if (childId != widget.selectedChildId) {
      widget.onChildSelected?.call(childId);
    }
  }
}

class _ShellBody extends StatelessWidget {
  const _ShellBody({
    required this.useDrawer,
    required this.shellRouteKey,
    required this.isShellLoading,
    required this.destinations,
    required this.selectedIndex,
    required this.selectedChildId,
    required this.sidebarCollapsed,
    required this.sidebarWidth,
    required this.navigationSearchLabel,
    required this.navigationSearchHint,
    required this.navigationSearchNoResultsLabel,
    required this.onDestinationSelected,
    required this.onChildSelected,
    required this.onResizeSidebar,
    required this.child,
  });

  final bool useDrawer;
  final String? shellRouteKey;
  final bool isShellLoading;
  final List<ResponsiveShellDestination> destinations;
  final int selectedIndex;
  final String? selectedChildId;
  final bool sidebarCollapsed;
  final double sidebarWidth;
  final String navigationSearchLabel;
  final String navigationSearchHint;
  final String navigationSearchNoResultsLabel;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<String>? onChildSelected;
  final ValueChanged<double> onResizeSidebar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget routeChild = shellRouteKey == null
        ? child
        : ShellRouteChildRetention(
            routeKey: shellRouteKey!,
            isLoading: isShellLoading,
            child: child,
          );

    if (useDrawer) {
      return routeChild;
    }

    return Row(
      children: <Widget>[
        RepaintBoundary(
          child: SideNavigation(
            destinations: destinations,
            selectedIndex: selectedIndex,
            selectedChildId: selectedChildId,
            collapsed: sidebarCollapsed,
            width: sidebarWidth,
            searchLabel: navigationSearchLabel,
            searchHint: navigationSearchHint,
            noResultsLabel: navigationSearchNoResultsLabel,
            onDestinationSelected: onDestinationSelected,
            onChildSelected: onChildSelected,
          ),
        ),
        if (!sidebarCollapsed) _SidebarResizeHandle(onDrag: onResizeSidebar),
        const VerticalDivider(width: AppShellLayout.dividerWidth),
        Expanded(child: RepaintBoundary(child: routeChild)),
      ],
    );
  }
}

class AppMenuBar extends StatelessWidget {
  const AppMenuBar({
    required this.title,
    required this.breakpoint,
    required this.connectivityStatus,
    required this.onlineLabel,
    required this.offlineLabel,
    required this.fullscreenEnterLabel,
    required this.fullscreenExitLabel,
    required this.showUserAvatar,
    required this.accountTooltip,
    required this.notificationsTooltip,
    required this.notificationsUnreadLabel,
    required this.profileLabel,
    required this.settingsLabel,
    required this.changePasswordLabel,
    required this.logoutLabel,
    required this.signedInLabel,
    required this.unreadNotificationCount,
    required this.systemIndicators,
    this.headerTrailingActions,
    required this.toggleTooltip,
    required this.onToggleNavigation,
    this.onNotificationsSelected,
    this.compactTitle,
    this.onProfileSelected,
    this.onSettingsSelected,
    this.onChangePasswordSelected,
    this.onLogoutSelected,
    this.userProfile,
    super.key,
  });

  final String title;
  final String? compactTitle;
  final AppBreakpoint breakpoint;
  final AppConnectivityStatus connectivityStatus;
  final String onlineLabel;
  final String offlineLabel;
  final String fullscreenEnterLabel;
  final String fullscreenExitLabel;
  final bool showUserAvatar;
  final String accountTooltip;
  final String notificationsTooltip;
  final String notificationsUnreadLabel;
  final String profileLabel;
  final String settingsLabel;
  final String changePasswordLabel;
  final String logoutLabel;
  final String signedInLabel;
  final int unreadNotificationCount;
  final List<ShellSystemIndicator> systemIndicators;
  final Widget? headerTrailingActions;
  final String toggleTooltip;
  final VoidCallback onToggleNavigation;
  final VoidCallback? onNotificationsSelected;
  final VoidCallback? onProfileSelected;
  final VoidCallback? onSettingsSelected;
  final VoidCallback? onChangePasswordSelected;
  final VoidCallback? onLogoutSelected;
  final UserMenuProfileData? userProfile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isMobile = breakpoint.isMobile;
    final bool hideTitle = breakpoint == AppBreakpoint.xs;
    final String effectiveTitle = isMobile ? compactTitle ?? title : title;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: theme.borders.only(bottom: true),
      ),
      child: SizedBox(
        height: AppShellLayout.headerHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
          child: Row(
            children: <Widget>[
              AppButton(
                iconOnly: true,
                dense: true,
                label: toggleTooltip,

                semanticLabel: toggleTooltip,
                tooltip: toggleTooltip,
                leadingIcon: Icons.menu,
                onPressed: onToggleNavigation,
              ),
              SizedBox(width: theme.spacing.xs),
              const AppLogo(size: _headerBrandHeight),
              if (!hideTitle) SizedBox(width: theme.spacing.sm),
              Expanded(
                child: hideTitle
                    ? const SizedBox.shrink()
                    : Text(
                        effectiveTitle,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontSize: _headerBrandHeight,
                          height: 1,
                          fontWeight: AppFontWeight.bold,
                        ),
                      ),
              ),
              if (!isMobile && systemIndicators.isNotEmpty) ...<Widget>[
                SizedBox(width: theme.spacing.xs),
                _SystemIndicatorsBar(indicators: systemIndicators),
              ],
              if (headerTrailingActions != null) ...<Widget>[
                SizedBox(width: theme.spacing.xs),
                headerTrailingActions!,
              ],
              AppConnectivityIndicator(
                status: connectivityStatus,
                onlineLabel: onlineLabel,
                offlineLabel: offlineLabel,
              ),
              AppFullscreenToggle(
                enterLabel: fullscreenEnterLabel,
                exitLabel: fullscreenExitLabel,
              ),
              SizedBox(width: theme.spacing.xs),
              if (onNotificationsSelected != null ||
                  unreadNotificationCount > 0)
                _NotificationButton(
                  tooltip: notificationsTooltip,
                  unreadLabel: notificationsUnreadLabel,
                  unreadCount: unreadNotificationCount,
                  onPressed: onNotificationsSelected,
                ),
              if (showUserAvatar) ...<Widget>[
                SizedBox(width: theme.spacing.xs),
                _UserMenuButton(
                  tooltip: accountTooltip,
                  profileLabel: profileLabel,
                  settingsLabel: settingsLabel,
                  changePasswordLabel: changePasswordLabel,
                  logoutLabel: logoutLabel,
                  signedInLabel: signedInLabel,
                  profile: userProfile,
                  onProfileSelected: onProfileSelected,
                  onSettingsSelected: onSettingsSelected,
                  onChangePasswordSelected: onChangePasswordSelected,
                  onLogoutSelected: onLogoutSelected,
                  child: _UserAvatar(profile: userProfile),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemIndicatorsBar extends StatelessWidget {
  const _SystemIndicatorsBar({required this.indicators});

  final List<ShellSystemIndicator> indicators;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < indicators.length; index += 1) ...<Widget>[
          _SystemIndicatorBadge(indicator: indicators[index]),
          if (index < indicators.length - 1) SizedBox(width: theme.spacing.xs),
        ],
      ],
    );
  }
}

class _SystemIndicatorBadge extends StatelessWidget {
  const _SystemIndicatorBadge({required this.indicator});

  final ShellSystemIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _SystemIndicatorColors colors = _systemIndicatorColors(
      theme,
      indicator.severity,
    );

    return Tooltip(
      message: indicator.label,
      child: Semantics(
        label: indicator.label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            border: theme.borders.all(color: colors.foreground),
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.xs),
            child: Icon(
              indicator.icon,
              size: theme.appTokens.listIconSize,
              color: colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

final class _SystemIndicatorColors {
  const _SystemIndicatorColors({
    required this.foreground,
    required this.background,
  });

  final Color foreground;
  final Color background;
}

_SystemIndicatorColors _systemIndicatorColors(
  ThemeData theme,
  ShellSystemIndicatorSeverity severity,
) {
  final ColorScheme colorScheme = theme.colorScheme;

  return switch (severity) {
    ShellSystemIndicatorSeverity.info => _SystemIndicatorColors(
      foreground: colorScheme.primary,
      background: colorScheme.primaryContainer,
    ),
    ShellSystemIndicatorSeverity.warning => _SystemIndicatorColors(
      foreground: colorScheme.tertiary,
      background: colorScheme.tertiaryContainer,
    ),
    ShellSystemIndicatorSeverity.error => _SystemIndicatorColors(
      foreground: colorScheme.error,
      background: colorScheme.errorContainer,
    ),
  };
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.tooltip,
    required this.unreadLabel,
    required this.unreadCount,
    required this.onPressed,
  });

  final String tooltip;
  final String unreadLabel;
  final int unreadCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool hasUnread = unreadCount > 0;

    return AppButton(
      iconOnly: true,
      label: unreadLabel,
      semanticLabel: unreadLabel,
      tooltip: tooltip,
      onPressed: onPressed,
      iconWidget: Badge(
        isLabelVisible: hasUnread,
        label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
        backgroundColor: colorScheme.error,
        textColor: colorScheme.onError,
        child: Icon(
          Icons.notifications_none_outlined,
          size: theme.appTokens.listIconSize,
        ),
      ),
    );
  }
}

class _UserMenuButton extends StatelessWidget {
  const _UserMenuButton({
    required this.tooltip,
    required this.profileLabel,
    required this.settingsLabel,
    required this.changePasswordLabel,
    required this.logoutLabel,
    required this.signedInLabel,
    required this.child,
    this.onProfileSelected,
    this.onSettingsSelected,
    this.onChangePasswordSelected,
    this.onLogoutSelected,
    this.profile,
  });

  final String tooltip;
  final String profileLabel;
  final String settingsLabel;
  final String changePasswordLabel;
  final String logoutLabel;
  final String signedInLabel;
  final Widget child;
  final VoidCallback? onProfileSelected;
  final VoidCallback? onSettingsSelected;
  final VoidCallback? onChangePasswordSelected;
  final VoidCallback? onLogoutSelected;
  final UserMenuProfileData? profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return PopupMenuButton<_UserMenuAction>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        side: theme.borders.side(),
      ),
      onSelected: (_UserMenuAction action) {
        switch (action) {
          case _UserMenuAction.profile:
            onProfileSelected?.call();
            break;
          case _UserMenuAction.settings:
            onSettingsSelected?.call();
            break;
          case _UserMenuAction.changePassword:
            onChangePasswordSelected?.call();
            break;
          case _UserMenuAction.logout:
            onLogoutSelected?.call();
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<_UserMenuAction>>[
          _UserMenuHeaderEntry(profile: profile, signedInLabel: signedInLabel),
          PopupMenuDivider(height: theme.spacing.xs),
          PopupMenuItem<_UserMenuAction>(
            value: _UserMenuAction.profile,
            enabled: onProfileSelected != null,
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
            child: AppMenuItemLabel(
              icon: Icons.person_outline,
              label: profileLabel,
            ),
          ),
          PopupMenuItem<_UserMenuAction>(
            value: _UserMenuAction.settings,
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
            child: AppMenuItemLabel(
              icon: Icons.settings_outlined,
              label: settingsLabel,
            ),
          ),
          PopupMenuItem<_UserMenuAction>(
            value: _UserMenuAction.changePassword,
            enabled: onChangePasswordSelected != null,
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
            child: AppMenuItemLabel(
              icon: Icons.lock_reset_outlined,
              label: changePasswordLabel,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<_UserMenuAction>(
            value: _UserMenuAction.logout,
            enabled: onLogoutSelected != null,
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
            child: AppMenuItemLabel(
              icon: Icons.logout_outlined,
              label: logoutLabel,
            ),
          ),
        ];
      },
      child: Semantics(button: true, label: tooltip, child: child),
    );
  }
}

class _UserMenuHeaderEntry extends PopupMenuEntry<_UserMenuAction> {
  const _UserMenuHeaderEntry({required this.signedInLabel, this.profile});

  final UserMenuProfileData? profile;
  final String signedInLabel;

  @override
  double get height => 134;

  @override
  bool represents(_UserMenuAction? value) => false;

  @override
  State<_UserMenuHeaderEntry> createState() => _UserMenuHeaderEntryState();
}

class _UserMenuHeaderEntryState extends State<_UserMenuHeaderEntry> {
  @override
  Widget build(BuildContext context) {
    return _UserMenuHeader(
      profile: widget.profile,
      signedInLabel: widget.signedInLabel,
    );
  }
}

class _UserMenuHeader extends StatelessWidget {
  const _UserMenuHeader({required this.signedInLabel, this.profile});

  final UserMenuProfileData? profile;
  final String signedInLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String name = _textOrFallback(profile?.name, signedInLabel);
    final String? email = _nonEmpty(profile?.email);
    final String? title = _nonEmpty(profile?.title);
    final List<String> chips = <String>{
      if (_nonEmpty(profile?.overallRole) case final String role) role,
      if (_nonEmpty(profile?.userType) case final String userType) userType,
    }.toList(growable: false);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.md,
        theme.spacing.md,
        theme.spacing.md,
        theme.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: _AvatarInitialsText(
                  initials: _avatarInitials(profile),
                  size: 15,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                    if (email != null) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (title != null) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                for (final String chip in chips) _UserMenuChip(label: chip),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UserMenuChip extends StatelessWidget {
  const _UserMenuChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        border: theme.borders.all(),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xs,
          vertical: 2,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
      ),
    );
  }
}

enum _UserMenuAction { profile, settings, changePassword, logout }

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({this.profile});

  final UserMenuProfileData? profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String initials = _avatarInitials(profile);

    return CircleAvatar(
      radius: _avatarRadius,
      backgroundColor: initials == '?'
          ? colorScheme.surfaceContainerHighest
          : colorScheme.primaryContainer,
      foregroundColor: initials == '?'
          ? colorScheme.onSurfaceVariant
          : colorScheme.onPrimaryContainer,
      child: initials == '?'
          ? const Icon(Icons.person_outline, size: 17)
          : _AvatarInitialsText(initials: initials, size: 13),
    );
  }
}

class _AvatarInitialsText extends StatelessWidget {
  const _AvatarInitialsText({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: size,
        fontWeight: AppFontWeight.emphasis,
      ),
    );
  }
}

String _avatarInitials(UserMenuProfileData? profile) {
  final String? explicitInitials = _nonEmpty(profile?.initials);
  if (explicitInitials != null) {
    return explicitInitials.length > 2
        ? explicitInitials.substring(0, 2).toUpperCase()
        : explicitInitials.toUpperCase();
  }

  final String? source = _nonEmpty(profile?.name) ?? _nonEmpty(profile?.email);
  if (source == null) {
    return '?';
  }

  final List<String> words = source
      .replaceAll(_initialsDelimiterPattern, ' ')
      .split(_whitespacePattern)
      .where((String word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return '?';
  }
  if (words.length == 1) {
    return words.first.substring(0, 1).toUpperCase();
  }

  return <String>[
    words.first.substring(0, 1),
    words.last.substring(0, 1),
  ].join().toUpperCase();
}

String _textOrFallback(String? value, String fallback) {
  return _nonEmpty(value) ?? fallback;
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

class _MobileShellDrawer extends StatefulWidget {
  const _MobileShellDrawer({
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.selectedChildId,
    required this.closeTooltip,
    required this.onDestinationSelected,
    required this.onChildSelected,
  });

  final String title;
  final List<ResponsiveShellDestination> destinations;
  final int selectedIndex;
  final String? selectedChildId;
  final String closeTooltip;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<String> onChildSelected;

  @override
  State<_MobileShellDrawer> createState() => _MobileShellDrawerState();
}

class _MobileShellDrawerState extends State<_MobileShellDrawer> {
  final Set<int> _expandedDestinations = <int>{};

  @override
  void initState() {
    super.initState();
    final String? childId = widget.selectedChildId;
    if (childId != null && childId.isNotEmpty) {
      _expandedDestinations.addAll(
        _destinationsOwningChild(
          _indexedDestinations(widget.destinations),
          childId,
        ),
      );
    }
  }

  void _toggleExpansion(int destinationIndex) {
    setState(() {
      if (!_expandedDestinations.remove(destinationIndex)) {
        _expandedDestinations.add(destinationIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String title = widget.title;
    final String closeTooltip = widget.closeTooltip;
    final TextStyle? drawerTitleStyle = theme.textTheme.titleMedium?.copyWith(
      color: colorScheme.primary,
      fontWeight: AppFontWeight.emphasis,
      height: 1,
    );
    final double drawerBrandHeight =
        drawerTitleStyle?.fontSize ?? _drawerBrandHeightFallback;
    final List<_NavigationListEntry> entries = _navigationListEntries(
      _indexedDestinations(widget.destinations),
      showGroups: false,
      selectedChildId: widget.selectedChildId,
      expandedDestinations: _expandedDestinations,
    );

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
                    // Match the mark to the title's own size rather than a
                    // fixed constant. The previous 48 also overflowed this
                    // header, which is only _drawerHeaderHeight (40) tall.
                    AppLogo(size: drawerBrandHeight),
                    SizedBox(width: theme.spacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: drawerTitleStyle,
                      ),
                    ),
                    AppButton(
                      iconOnly: true,
                      label: closeTooltip,

                      semanticLabel: closeTooltip,
                      tooltip: closeTooltip,
                      leadingIcon: Icons.close,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: AppShellLayout.dividerWidth),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
                itemCount: entries.length,
                itemBuilder: (BuildContext context, int index) {
                  return _NavigationListEntryWidget(
                    entry: entries[index],
                    selectedIndex: widget.selectedIndex,
                    showLabel: true,
                    useShortLabel: true,
                    onDestinationSelected: widget.onDestinationSelected,
                    onChildSelected: widget.onChildSelected,
                    onExpansionToggled: _toggleExpansion,
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

class SideNavigation extends StatefulWidget {
  const SideNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.collapsed,
    required this.width,
    required this.searchLabel,
    required this.searchHint,
    required this.noResultsLabel,
    required this.onDestinationSelected,
    this.selectedChildId,
    this.onChildSelected,
    super.key,
  });

  final List<ResponsiveShellDestination> destinations;
  final int selectedIndex;
  final String? selectedChildId;
  final bool collapsed;
  final double width;
  final String searchLabel;
  final String searchHint;
  final String noResultsLabel;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<String>? onChildSelected;

  @override
  State<SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<SideNavigation> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _expandedDestinations = <int>{};

  @override
  void initState() {
    super.initState();
    _revealSelectedChild();
  }

  @override
  void didUpdateWidget(SideNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.collapsed && widget.collapsed) {
      _clearSearch();
    }
    if (oldWidget.selectedChildId != widget.selectedChildId) {
      _revealSelectedChild();
    }
  }

  /// Deep links land on a submenu item, so its parent opens without a tap.
  void _revealSelectedChild() {
    final String? childId = widget.selectedChildId;
    if (childId == null || childId.isEmpty) {
      return;
    }
    _expandedDestinations.addAll(
      _destinationsOwningChild(
        _indexedDestinations(widget.destinations),
        childId,
      ),
    );
  }

  void _toggleExpansion(int destinationIndex) {
    setState(() {
      if (!_expandedDestinations.remove(destinationIndex)) {
        _expandedDestinations.add(destinationIndex);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSidebarTokens sidebar = theme.sidebarTokens;
    final String normalizedQuery = widget.collapsed
        ? ''
        : _normalizeNavigationSearchText(_searchQuery);
    final List<_IndexedShellDestination> visibleDestinations =
        _indexedDestinations(widget.destinations)
            .where((_IndexedShellDestination indexedDestination) {
              if (normalizedQuery.isEmpty) {
                return true;
              }
              return _destinationMatchesSearch(
                indexedDestination.destination,
                normalizedQuery,
              );
            })
            .toList(growable: false);
    final List<_NavigationListEntry> entries = _navigationListEntries(
      visibleDestinations,
      showGroups: false,
      // The collapsed rail has no room for labels, so nested items stay closed.
      showChildren: !widget.collapsed,
      selectedChildId: widget.selectedChildId,
      expandedDestinations: _expandedDestinations,
      normalizedQuery: normalizedQuery,
    );

    return AnimatedContainer(
      duration: _sidebarAnimationDuration,
      curve: Curves.easeOutCubic,
      width: widget.width,
      decoration: BoxDecoration(
        color: sidebar.backgroundColor,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: sidebar.shadowColor,
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          if (!widget.collapsed)
            _SidebarSearchField(
              controller: _searchController,
              semanticLabel: widget.searchLabel,
              hintText: widget.searchHint,
              onChanged: _handleSearchChanged,
            ),
          Expanded(
            child: entries.isEmpty
                ? _SidebarNavigationEmptyState(label: widget.noResultsLabel)
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
                    itemCount: entries.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _NavigationListEntryWidget(
                        entry: entries[index],
                        selectedIndex: widget.selectedIndex,
                        showLabel: !widget.collapsed,
                        onDestinationSelected: _selectDestination,
                        onChildSelected: _selectChild,
                        onExpansionToggled: _toggleExpansion,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery = '';
  }

  void _selectDestination(int index) {
    if (index != widget.selectedIndex) {
      widget.onDestinationSelected(index);
    }
  }

  void _selectChild(String childId) {
    if (childId != widget.selectedChildId) {
      widget.onChildSelected?.call(childId);
    }
  }
}

class _NavigationListEntryWidget extends StatelessWidget {
  const _NavigationListEntryWidget({
    required this.entry,
    required this.selectedIndex,
    required this.showLabel,
    this.useShortLabel = false,
    required this.onDestinationSelected,
    this.onChildSelected,
    this.onExpansionToggled,
  });

  final _NavigationListEntry entry;
  final int selectedIndex;
  final bool showLabel;
  final bool useShortLabel;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<String>? onChildSelected;
  final ValueChanged<int>? onExpansionToggled;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      _NavigationGroupHeaderEntry(:final label) => _ShellMenuGroupHeader(
        label: label,
      ),
      _NavigationDestinationEntry(
        :final destination,
        :final expandable,
        :final expanded,
      ) =>
        _ShellMenuItem(
          destination: destination.destination,
          selected: destination.index == selectedIndex,
          showLabel: showLabel,
          useShortLabel: useShortLabel,
          expandable: expandable && showLabel,
          expanded: expanded,
          onTap: () {
            // Opening a parent menu both navigates and reveals its children.
            if (expandable && showLabel) {
              onExpansionToggled?.call(destination.index);
            }
            onDestinationSelected(destination.index);
          },
        ),
      _NavigationSubmenuEntry(:final item, :final selected) => _ShellSubMenuItem(
        label: item.label,
        icon: item.icon,
        selected: selected,
        badgeCount: item.badgeCount,
        badgeTone: item.badgeTone,
        tooltip: item.tooltip,
        onTap: () => onChildSelected?.call(item.id),
      ),
    };
  }
}

/// Row for a nested menu item: an expandable category or a navigable leaf.
class _ShellSubMenuItem extends StatefulWidget {
  const _ShellSubMenuItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badgeCount,
    this.badgeTone,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int? badgeCount;
  final AppTabCountTone? badgeTone;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  State<_ShellSubMenuItem> createState() => _ShellSubMenuItemState();
}

class _ShellSubMenuItemState extends State<_ShellSubMenuItem> {
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
    final AppSidebarTokens sidebar = theme.sidebarTokens;
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isInteractive = _hovered || _focused;
    final Color backgroundColor = widget.selected
        ? sidebar.selectedBackgroundColor
        : isInteractive
        ? sidebar.hoverBackgroundColor
        : Colors.transparent;
    final Color foregroundColor = widget.selected
        ? sidebar.selectedForegroundColor
        : isInteractive
        ? sidebar.hoverForegroundColor
        : sidebar.defaultForegroundColor;
    final BorderRadius itemRadius = BorderRadius.circular(
      sidebar.itemBorderRadius,
    );
    final int badgeCount = widget.badgeCount ?? 0;

    final Widget content = AnimatedContainer(
      duration: _menuAnimationDuration,
      height: sidebar.itemHeight,
      margin: EdgeInsets.only(
        // Indented one step to read as a child of the destination above it.
        left: theme.spacing.sm + theme.spacing.lg,
        right: theme.spacing.sm,
        top: theme.spacing.xs,
        bottom: theme.spacing.xs,
      ),
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: itemRadius,
        border: _focused
            ? theme.borders.all(
                color: widget.selected
                    ? sidebar.selectedForegroundColor.withValues(alpha: 0.48)
                    : sidebar.focusBorderColor,
                width: _focusIndicatorWidth,
              )
            : null,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            widget.icon,
            color: foregroundColor,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                fontWeight: widget.selected
                    ? AppFontWeight.emphasis
                    : AppFontWeight.regular,
              ),
            ),
          ),
          if (badgeCount > 0) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            _MenuItemCountBadge(
              count: badgeCount,
              selected: widget.selected,
              sidebar: sidebar,
              tone: widget.badgeTone,
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
            message: widget.tooltip ?? '',
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
                label: widget.label,
                onTap: widget.onTap,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    canRequestFocus: false,
                    onTap: widget.onTap,
                    borderRadius: itemRadius,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    splashColor: colorScheme.primary.withValues(alpha: 0.1),
                    highlightColor: colorScheme.primary.withValues(alpha: 0.06),
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

class _SidebarSearchField extends StatelessWidget {
  const _SidebarSearchField({
    required this.controller,
    required this.semanticLabel,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String semanticLabel;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.sm,
        theme.spacing.sm,
        theme.spacing.sm,
        theme.spacing.xs,
      ),
      child: AppSearchBar(
        controller: controller,
        semanticLabel: semanticLabel,
        hintText: hintText,
        onChanged: onChanged,
      ),
    );
  }
}

class _SidebarNavigationEmptyState extends StatelessWidget {
  const _SidebarNavigationEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ShellMenuGroupHeader extends StatelessWidget {
  const _ShellMenuGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.md,
        theme.spacing.lg,
        theme.spacing.md,
        theme.spacing.xs,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
          fontWeight: AppFontWeight.emphasis,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

sealed class _NavigationListEntry {
  const _NavigationListEntry();
}

final class _NavigationGroupHeaderEntry extends _NavigationListEntry {
  const _NavigationGroupHeaderEntry({required this.label});

  final String label;
}

final class _NavigationDestinationEntry extends _NavigationListEntry {
  const _NavigationDestinationEntry({
    required this.destination,
    this.expandable = false,
    this.expanded = false,
  });

  final _IndexedShellDestination destination;
  final bool expandable;
  final bool expanded;
}

/// Nested menu row under a destination.
final class _NavigationSubmenuEntry extends _NavigationListEntry {
  const _NavigationSubmenuEntry({required this.item, required this.selected});

  final ShellSubmenuItem item;
  final bool selected;
}

final class _IndexedShellDestination {
  const _IndexedShellDestination({
    required this.index,
    required this.destination,
  });

  final int index;
  final ResponsiveShellDestination destination;
}

List<_IndexedShellDestination> _indexedDestinations(
  List<ResponsiveShellDestination> destinations,
) {
  return <_IndexedShellDestination>[
    for (var index = 0; index < destinations.length; index += 1)
      _IndexedShellDestination(index: index, destination: destinations[index]),
  ];
}

List<_NavigationListEntry> _navigationListEntries(
  List<_IndexedShellDestination> destinations, {
  required bool showGroups,
  bool showChildren = true,
  String? selectedChildId,
  Set<int> expandedDestinations = const <int>{},
  String normalizedQuery = '',
}) {
  final entries = <_NavigationListEntry>[];
  final bool searching = normalizedQuery.isNotEmpty;
  String? currentGroup;

  for (final _IndexedShellDestination destination in destinations) {
    final String? groupLabel = _nonEmpty(destination.destination.groupLabel);
    if (showGroups && groupLabel != null && groupLabel != currentGroup) {
      entries.add(_NavigationGroupHeaderEntry(label: groupLabel));
      currentGroup = groupLabel;
    } else if (showGroups && groupLabel == null) {
      currentGroup = null;
    }

    final bool expandable = showChildren && destination.destination.hasChildren;
    // A search narrows to matches, so every surviving submenu opens.
    final bool expanded =
        expandable &&
        (searching || expandedDestinations.contains(destination.index));

    entries.add(
      _NavigationDestinationEntry(
        destination: destination,
        expandable: expandable,
        expanded: expanded,
      ),
    );

    if (!expanded) {
      continue;
    }
    for (final ShellSubmenuItem item in destination.destination.children) {
      if (searching && !_submenuItemMatchesSearch(item, normalizedQuery)) {
        continue;
      }
      entries.add(
        _NavigationSubmenuEntry(
          item: item,
          selected: item.id == selectedChildId,
        ),
      );
    }
  }

  return entries;
}

/// Destination indexes owning [childId], so a deep link reveals its menu item.
Set<int> _destinationsOwningChild(
  List<_IndexedShellDestination> destinations,
  String childId,
) {
  return <int>{
    for (final _IndexedShellDestination destination in destinations)
      if (destination.destination.children.any(
        (ShellSubmenuItem item) => item.id == childId,
      ))
        destination.index,
  };
}

bool _submenuItemMatchesSearch(
  ShellSubmenuItem item,
  String normalizedQuery,
) {
  return _normalizeNavigationSearchText(item.label).contains(normalizedQuery);
}

bool _destinationMatchesSearch(
  ResponsiveShellDestination destination,
  String normalizedQuery,
) {
  return _normalizeNavigationSearchText(
        destination.label,
      ).contains(normalizedQuery) ||
      _normalizeNavigationSearchText(
        destination.shortLabel ?? '',
      ).contains(normalizedQuery) ||
      _normalizeNavigationSearchText(
        destination.groupLabel ?? '',
      ).contains(normalizedQuery) ||
      destination.children.any(
        (ShellSubmenuItem item) =>
            _submenuItemMatchesSearch(item, normalizedQuery),
      );
}

String _normalizeNavigationSearchText(String value) {
  return value.trim().toLowerCase();
}

class _ShellMenuItem extends StatefulWidget {
  const _ShellMenuItem({
    required this.destination,
    required this.selected,
    required this.showLabel,
    this.useShortLabel = false,
    this.expandable = false,
    this.expanded = false,
    required this.onTap,
  });

  final ResponsiveShellDestination destination;
  final bool selected;
  final bool showLabel;
  final bool useShortLabel;
  final bool expandable;
  final bool expanded;
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
    final AppSidebarTokens sidebar = theme.sidebarTokens;
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isInteractive = _hovered || _focused;
    final Color backgroundColor = widget.selected
        ? sidebar.selectedBackgroundColor
        : isInteractive
        ? sidebar.hoverBackgroundColor
        : Colors.transparent;
    final Color foregroundColor = widget.selected
        ? sidebar.selectedForegroundColor
        : isInteractive
        ? sidebar.hoverForegroundColor
        : sidebar.defaultForegroundColor;
    final int badgeCount = widget.destination.badgeCount ?? 0;
    final bool showIconBadge = badgeCount > 0 && !widget.showLabel;
    final String visibleLabel = widget.destination.displayLabel(
      compact: widget.useShortLabel,
    );
    final Widget icon = Icon(
      widget.selected
          ? widget.destination.selectedIcon
          : widget.destination.icon,
      color: foregroundColor,
      size: theme.appTokens.listIconSize,
    );
    final BorderRadius itemRadius = BorderRadius.circular(
      sidebar.itemBorderRadius,
    );
    final Widget content = AnimatedContainer(
      duration: _menuAnimationDuration,
      height: sidebar.itemHeight,
      margin: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: widget.showLabel ? theme.spacing.sm : theme.spacing.none,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: itemRadius,
        border: _focused
            ? theme.borders.all(color: widget.selected
                    ? sidebar.selectedForegroundColor.withValues(alpha: 0.48)
                    : sidebar.focusBorderColor,
                width: _focusIndicatorWidth)
            : null,
      ),
      child: Row(
        mainAxisAlignment: widget.showLabel
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: <Widget>[
          showIconBadge
              ? Badge(
                  label: Text(_compactBadgeCount(badgeCount)),
                  backgroundColor: widget.selected
                      ? sidebar.selectedForegroundColor.withValues(alpha: 0.24)
                      : sidebar.badgeAccentBackgroundColor,
                  textColor: widget.selected
                      ? sidebar.selectedForegroundColor
                      : sidebar.badgeAccentForegroundColor,
                  smallSize: 7,
                  largeSize: 16,
                  padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
                  child: icon,
                )
              : icon,
          if (widget.showLabel) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                visibleLabel,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: widget.selected
                      ? AppFontWeight.emphasis
                      : AppFontWeight.regular,
                ),
              ),
            ),
            if (badgeCount > 0) ...<Widget>[
              SizedBox(width: theme.spacing.xs),
              _MenuItemCountBadge(
                count: badgeCount,
                selected: widget.selected,
                sidebar: sidebar,
              ),
            ],
            if (widget.expandable) ...<Widget>[
              SizedBox(width: theme.spacing.xs),
              Icon(
                widget.expanded ? Icons.expand_less : Icons.expand_more,
                color: foregroundColor,
                size: theme.appTokens.listIconSize,
              ),
            ],
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
                    borderRadius: itemRadius,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    splashColor: colorScheme.primary.withValues(alpha: 0.1),
                    highlightColor: colorScheme.primary.withValues(alpha: 0.06),
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

class _MenuItemCountBadge extends StatelessWidget {
  const _MenuItemCountBadge({
    required this.count,
    required this.selected,
    required this.sidebar,
    this.tone,
  });

  final int count;
  final bool selected;
  final AppSidebarTokens sidebar;

  /// Urgency carried over from the tab strip this menu item replaced.
  final AppTabCountTone? tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color background = switch (tone) {
      AppTabCountTone.warning => colorScheme.tertiaryContainer,
      AppTabCountTone.danger => colorScheme.errorContainer,
      _ => sidebar.badgeAccentBackgroundColor,
    };
    final Color foreground = switch (tone) {
      AppTabCountTone.warning => colorScheme.onTertiaryContainer,
      AppTabCountTone.danger => colorScheme.onErrorContainer,
      _ => sidebar.badgeAccentForegroundColor,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? sidebar.selectedForegroundColor.withValues(alpha: 0.22)
            : background,
        borderRadius: BorderRadius.circular(theme.radius.full),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: 2,
        ),
        child: Text(
          _compactBadgeCount(count),
          style: theme.textTheme.labelSmall?.copyWith(
            color: selected ? sidebar.selectedForegroundColor : foreground,
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
      ),
    );
  }
}

String _compactBadgeCount(int count) {
  if (count > 99) {
    return '99+';
  }
  return count.toString();
}

class _SidebarResizeHandle extends StatelessWidget {
  const _SidebarResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = theme.borders.faint;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          onDrag(details.delta.dx);
        },
        child: SizedBox(
          width: AppShellLayout.resizeHandleWidth,
          child: Center(
            child: SizedBox(
              width: AppShellLayout.dividerWidth,
              height: double.infinity,
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

final RegExp _initialsDelimiterPattern = RegExp(r'[@._-]+');
final RegExp _whitespacePattern = RegExp(r'\s+');

const double _drawerHeaderHeight = AppShellLayout.headerHeight;
/// Shared height for the header logo and the app name beside it, so the two
/// read as one lockup. The title sets `height: 1`, making its line box equal
/// its font size. Stays inside the dense icon-only [AppButton] slot
/// (40 min − VisualDensity.compact → 32).
const double _headerBrandHeight = 28;

/// Fallback when the drawer title's style carries no explicit font size; the
/// drawer normally sizes its mark from [TextTheme.titleMedium].
const double _drawerBrandHeightFallback = 16;
const double _avatarRadius = 13;
const double _focusIndicatorWidth = 2;
const Duration _menuAnimationDuration = Duration(milliseconds: 120);
const Duration _sidebarAnimationDuration = Duration(milliseconds: 180);
