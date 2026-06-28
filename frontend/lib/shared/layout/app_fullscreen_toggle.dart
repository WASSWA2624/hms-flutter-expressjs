import 'package:flutter/material.dart';
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
  late bool _isFullscreen;
  late final VoidCallback _fullscreenChangeListener;

  @override
  void initState() {
    super.initState();
    _isFullscreen = appFullscreenIsActive();
    _fullscreenChangeListener = () {
      if (!mounted) {
        return;
      }
      final bool active = appFullscreenIsActive();
      if (_isFullscreen != active) {
        setState(() {
          _isFullscreen = active;
        });
      }
    };
    appFullscreenAddChangeListener(_fullscreenChangeListener);
  }

  @override
  void dispose() {
    appFullscreenRemoveChangeListener(_fullscreenChangeListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!appFullscreenIsSupported()) {
      return const SizedBox.shrink();
    }

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

    return AppIconButton(
      icon: icon,
      semanticLabel: label,
      tooltip: label,
      onPressed: toggle,
    );
  }
}
