import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/components.dart';

final class ResponsiveShellDestination {
  const ResponsiveShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.groupLabel,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? groupLabel;
  final int? badgeCount;
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
    super.connectivityStatus,
    super.showUserAvatar,
    super.compactTitle,
    super.onlineLabel,
    super.offlineLabel,
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
    super.onNotificationsSelected,
    super.onProfileSelected,
    super.onSettingsSelected,
    super.onChangePasswordSelected,
    super.onLogoutSelected,
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
    this.onNotificationsSelected,
    this.onProfileSelected,
    this.onSettingsSelected,
    this.onChangePasswordSelected,
    this.onLogoutSelected,
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
  final VoidCallback? onNotificationsSelected;
  final VoidCallback? onProfileSelected;
  final VoidCallback? onSettingsSelected;
  final VoidCallback? onChangePasswordSelected;
  final VoidCallback? onLogoutSelected;
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
                  onNotificationsSelected: widget.onNotificationsSelected,
                  onProfileSelected: widget.onProfileSelected,
                  onSettingsSelected: widget.onSettingsSelected,
                  onChangePasswordSelected: widget.onChangePasswordSelected,
                  onLogoutSelected: widget.onLogoutSelected,
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
                              searchLabel: widget.navigationSearchLabel,
                              searchHint: widget.navigationSearchHint,
                              noResultsLabel:
                                  widget.navigationSearchNoResultsLabel,
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
    required this.notificationsTooltip,
    required this.notificationsUnreadLabel,
    required this.profileLabel,
    required this.settingsLabel,
    required this.changePasswordLabel,
    required this.logoutLabel,
    required this.signedInLabel,
    required this.unreadNotificationCount,
    required this.systemIndicators,
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
              if (!isMobile && systemIndicators.isNotEmpty) ...<Widget>[
                SizedBox(width: theme.spacing.xs),
                _SystemIndicatorsBar(indicators: systemIndicators),
              ],
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
                  child: _UserAvatar(
                    status: connectivityStatus,
                    showStatusDot: isMobile,
                    onlineLabel: onlineLabel,
                    offlineLabel: offlineLabel,
                    profile: userProfile,
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
            border: Border.all(color: colors.foreground),
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

    return Semantics(
      button: true,
      label: unreadLabel,
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          iconSize: theme.appTokens.listIconSize,
          icon: Badge(
            isLabelVisible: hasUnread,
            label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
            backgroundColor: colorScheme.error,
            textColor: colorScheme.onError,
            child: const Icon(Icons.notifications_none_outlined),
          ),
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
        side: BorderSide(color: colorScheme.outlineVariant),
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
            child: _UserMenuItemLabel(
              icon: Icons.person_outline,
              label: profileLabel,
            ),
          ),
          PopupMenuItem<_UserMenuAction>(
            value: _UserMenuAction.settings,
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
            child: _UserMenuItemLabel(
              icon: Icons.settings_outlined,
              label: settingsLabel,
            ),
          ),
          PopupMenuItem<_UserMenuAction>(
            value: _UserMenuAction.changePassword,
            enabled: onChangePasswordSelected != null,
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
            child: _UserMenuItemLabel(
              icon: Icons.lock_reset_outlined,
              label: changePasswordLabel,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<_UserMenuAction>(
            value: _UserMenuAction.logout,
            enabled: onLogoutSelected != null,
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
            child: _UserMenuItemLabel(
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
                        fontWeight: FontWeight.w700,
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
        border: Border.all(color: colorScheme.outlineVariant),
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
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _UserMenuItemLabel extends StatelessWidget {
  const _UserMenuItemLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      children: <Widget>[
        SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            size: theme.appTokens.listIconSize,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

enum _UserMenuAction { profile, settings, changePassword, logout }

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
    this.profile,
  });

  final AppConnectivityStatus status;
  final bool showStatusDot;
  final String onlineLabel;
  final String offlineLabel;
  final UserMenuProfileData? profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String initials = _avatarInitials(profile);
    final Widget avatar = CircleAvatar(
      radius: _avatarRadius,
      backgroundColor: initials == '?'
          ? colorScheme.surfaceContainerHighest
          : colorScheme.primaryContainer,
      foregroundColor: initials == '?'
          ? colorScheme.onSurfaceVariant
          : colorScheme.onPrimaryContainer,
      child: initials == '?'
          ? const Icon(Icons.person_outline, size: _avatarIconSize)
          : _AvatarInitialsText(initials: initials, size: 13),
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
        fontWeight: FontWeight.w800,
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
      .replaceAll(RegExp(r'[@._-]+'), ' ')
      .split(RegExp(r'\s+'))
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
    final List<_NavigationListEntry> entries = _navigationListEntries(
      _indexedDestinations(destinations),
      showGroups: true,
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
                itemCount: entries.length,
                itemBuilder: (BuildContext context, int index) {
                  return _NavigationListEntryWidget(
                    entry: entries[index],
                    selectedIndex: selectedIndex,
                    showLabel: true,
                    onDestinationSelected: onDestinationSelected,
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
    super.key,
  });

  final List<ResponsiveShellDestination> destinations;
  final int selectedIndex;
  final bool collapsed;
  final double width;
  final String searchLabel;
  final String searchHint;
  final String noResultsLabel;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<SideNavigation> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void didUpdateWidget(SideNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.collapsed && widget.collapsed) {
      _clearSearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
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
      showGroups: !widget.collapsed,
    );

    return AnimatedContainer(
      duration: _sidebarAnimationDuration,
      curve: Curves.easeOutCubic,
      width: widget.width,
      color: colorScheme.surfaceContainerLowest,
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
}

class _NavigationListEntryWidget extends StatelessWidget {
  const _NavigationListEntryWidget({
    required this.entry,
    required this.selectedIndex,
    required this.showLabel,
    required this.onDestinationSelected,
  });

  final _NavigationListEntry entry;
  final int selectedIndex;
  final bool showLabel;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      _NavigationGroupHeaderEntry(:final label) => _ShellMenuGroupHeader(
        label: label,
      ),
      _NavigationDestinationEntry(:final destination) => _ShellMenuItem(
        destination: destination.destination,
        selected: destination.index == selectedIndex,
        showLabel: showLabel,
        onTap: () {
          onDestinationSelected(destination.index);
        },
      ),
    };
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.md,
        theme.spacing.md,
        theme.spacing.md,
        theme.spacing.xs,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
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
  const _NavigationDestinationEntry({required this.destination});

  final _IndexedShellDestination destination;
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
}) {
  final entries = <_NavigationListEntry>[];
  String? currentGroup;

  for (final _IndexedShellDestination destination in destinations) {
    final String? groupLabel = _nonEmpty(destination.destination.groupLabel);
    if (showGroups && groupLabel != null && groupLabel != currentGroup) {
      entries.add(_NavigationGroupHeaderEntry(label: groupLabel));
      currentGroup = groupLabel;
    } else if (showGroups && groupLabel == null) {
      currentGroup = null;
    }

    entries.add(_NavigationDestinationEntry(destination: destination));
  }

  return entries;
}

bool _destinationMatchesSearch(
  ResponsiveShellDestination destination,
  String normalizedQuery,
) {
  return _normalizeNavigationSearchText(
        destination.label,
      ).contains(normalizedQuery) ||
      _normalizeNavigationSearchText(
        destination.groupLabel ?? '',
      ).contains(normalizedQuery);
}

String _normalizeNavigationSearchText(String value) {
  return value.trim().toLowerCase();
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
    final int badgeCount = widget.destination.badgeCount ?? 0;
    final bool showIconBadge = badgeCount > 0 && !widget.showLabel;
    final Widget icon = Icon(
      widget.selected
          ? widget.destination.selectedIcon
          : widget.destination.icon,
      color: foregroundColor,
      size: theme.appTokens.listIconSize,
    );
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
          showIconBadge
              ? Badge(
                  label: Text(_compactBadgeCount(badgeCount)),
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
                widget.destination.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: widget.selected ? FontWeight.w700 : null,
                ),
              ),
            ),
            if (badgeCount > 0) ...<Widget>[
              SizedBox(width: theme.spacing.xs),
              _MenuItemCountBadge(count: badgeCount, selected: widget.selected),
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

class _MenuItemCountBadge extends StatelessWidget {
  const _MenuItemCountBadge({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? colorScheme.primary : colorScheme.secondaryContainer,
        border: Border.all(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xs,
          vertical: 1,
        ),
        child: Text(
          _compactBadgeCount(count),
          style: theme.textTheme.labelSmall?.copyWith(
            color: selected
                ? colorScheme.onPrimary
                : colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
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
