/// Shared layout metrics for the responsive app shell.
///
/// Sidebar widths follow [`layouts.mdc`](../../../.cursor/layouts.mdc):
/// collapsed `64–80`, expanded `220–280`.
abstract final class AppShellLayout {
  static const double headerHeight = 44;

  static const double collapsedSidebarWidth = 72;
  static const double defaultSidebarWidth = 240;
  static const double minSidebarWidth = 220;
  static const double maxSidebarWidth = 280;

  static const double resizeHandleWidth = 6;
  static const double dividerWidth = 1;
}
