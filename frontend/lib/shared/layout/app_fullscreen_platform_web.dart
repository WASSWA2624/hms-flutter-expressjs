import 'package:web/web.dart' as web;

bool appFullscreenIsSupported() => true;

bool appFullscreenIsActive() {
  return web.document.fullscreenElement != null;
}

Future<void> appFullscreenToggle() async {
  if (web.document.fullscreenElement != null) {
    web.document.exitFullscreen();
    return;
  }

  web.document.documentElement?.requestFullscreen();
}
