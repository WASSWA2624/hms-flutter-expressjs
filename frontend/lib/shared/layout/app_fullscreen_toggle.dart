import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';
import 'package:hosspi_hms/shared/layout/app_fullscreen_platform_stub.dart'
    if (dart.library.html) 'package:hosspi_hms/shared/layout/app_fullscreen_platform_web.dart';

/// Shell-level full-screen control (web uses the document fullscreen API).
class AppFullscreenToggle extends StatefulWidget {
  const AppFullscreenToggle({
    required this.enterLabel,
    required this.exitLabel,
    super.key,
  });

  final String enterLabel;
  final String exitLabel;

  @override
  State<AppFullscreenToggle> createState() => _AppFullscreenToggleState();
}

class _AppFullscreenToggleState extends State<AppFullscreenToggle> {
  bool _isFullscreen = appFullscreenIsActive();

  @override
  Widget build(BuildContext context) {
    if (!appFullscreenIsSupported()) {
      return const SizedBox.shrink();
    }

    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool iconOnly =
        breakpoint == AppBreakpoint.xs || breakpoint == AppBreakpoint.sm;
    final String label = _isFullscreen ? widget.exitLabel : widget.enterLabel;
    final IconData icon = _isFullscreen
        ? Icons.fullscreen_exit
        : Icons.fullscreen;

    Future<void> toggle() async {
      await appFullscreenToggle();
      if (!mounted) {
        return;
      }
      setState(() {
        _isFullscreen = appFullscreenIsActive();
      });
    }

    if (iconOnly) {
      return AppIconButton(
        icon: icon,
        semanticLabel: label,
        tooltip: label,
        onPressed: toggle,
      );
    }

    return AppActionLabelScope(
      showLabels: true,
      forceIconOnly: false,
      child: AppButton.secondary(
        label: label,
        leadingIcon: icon,
        semanticLabel: label,
        tooltip: label,
        onPressed: toggle,
      ),
    );
  }
}
