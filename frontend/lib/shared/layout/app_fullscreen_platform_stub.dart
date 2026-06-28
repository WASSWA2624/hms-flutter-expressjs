import 'package:flutter/foundation.dart';

final Set<VoidCallback> _fullscreenChangeListeners = <VoidCallback>{};

bool appFullscreenIsSupported() => false;

bool appFullscreenIsActive() => false;

Future<void> appFullscreenToggle() async {}

void appFullscreenAddChangeListener(VoidCallback listener) {
  _fullscreenChangeListeners.add(listener);
}

void appFullscreenRemoveChangeListener(VoidCallback listener) {
  _fullscreenChangeListeners.remove(listener);
}
