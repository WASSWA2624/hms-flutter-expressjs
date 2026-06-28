import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

final Set<VoidCallback> _fullscreenChangeListeners = <VoidCallback>{};
web.EventListener? _documentFullscreenListener;

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

void appFullscreenAddChangeListener(VoidCallback listener) {
  _fullscreenChangeListeners.add(listener);
  _documentFullscreenListener ??= ((web.Event _) {
    for (final VoidCallback callback
        in _fullscreenChangeListeners.toList(growable: false)) {
      callback();
    }
  }).toJS;
  web.document.addEventListener(
    'fullscreenchange',
    _documentFullscreenListener!,
  );
}

void appFullscreenRemoveChangeListener(VoidCallback listener) {
  _fullscreenChangeListeners.remove(listener);
  if (_fullscreenChangeListeners.isEmpty && _documentFullscreenListener != null) {
    web.document.removeEventListener(
      'fullscreenchange',
      _documentFullscreenListener!,
    );
    _documentFullscreenListener = null;
  }
}
