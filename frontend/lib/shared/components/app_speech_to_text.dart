import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_feedback.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Why speech-to-text is inactive for a field.
enum AppSpeechToTextBlockReason {
  offline,
  unavailable,
  permissionDenied,
  noMicrophone,
  fieldDisabled,
}

/// Result of preparing the platform speech engine.
enum AppSpeechInitStatus {
  ready,
  unavailable,
  permissionDenied,
  noMicrophone,
}

/// Platform speech adapter (mockable in tests).
abstract class AppSpeechRecognizer {
  bool get isListening;

  Future<AppSpeechInitStatus> ensureReady({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  });

  Future<void> startListening({
    required void Function(String words, {required bool isFinal}) onResult,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  });

  Future<void> stopListening();

  Future<void> cancelListening();
}

/// Default [speech_to_text] backed recognizer.
final class SpeechToTextAppSpeechRecognizer implements AppSpeechRecognizer {
  SpeechToTextAppSpeechRecognizer({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  AppSpeechInitStatus _lastStatus = AppSpeechInitStatus.unavailable;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<AppSpeechInitStatus> ensureReady({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    if (_initialized && _lastStatus == AppSpeechInitStatus.ready) {
      return AppSpeechInitStatus.ready;
    }

    try {
      final bool available = await _speech.initialize(
        onStatus: onStatus,
        onError: (error) {
          onError?.call(error.errorMsg);
        },
      );
      if (!available) {
        final bool permitted = await _speech.hasPermission;
        _lastStatus = permitted
            ? AppSpeechInitStatus.unavailable
            : AppSpeechInitStatus.permissionDenied;
        _initialized = true;
        return _lastStatus;
      }
      _initialized = true;
      _lastStatus = AppSpeechInitStatus.ready;
      return _lastStatus;
    } on Object catch (error) {
      onError?.call(error.toString());
      _lastStatus = AppSpeechInitStatus.unavailable;
      _initialized = true;
      return _lastStatus;
    }
  }

  @override
  Future<void> startListening({
    required void Function(String words, {required bool isFinal}) onResult,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, isFinal: result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stopListening() => _speech.stop();

  @override
  Future<void> cancelListening() => _speech.cancel();
}

/// Inserts [transcript] at the current selection/caret of [controller].
///
/// When [sessionPrefix]/[sessionSuffix] are provided (captured at listen
/// start), each call replaces the live dictation span so partial results do
/// not stack. Surrounding markdown-ish markup outside that span is preserved.
void insertSpeechTranscript(
  TextEditingController controller,
  String transcript, {
  required String sessionPrefix,
  required String sessionSuffix,
}) {
  final String next = '$sessionPrefix$transcript$sessionSuffix';
  final int caret = sessionPrefix.length + transcript.length;
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: caret.clamp(0, next.length)),
  );
}

({String prefix, String suffix}) captureSpeechSessionBounds(
  TextEditingController controller,
) {
  final TextSelection selection = controller.selection;
  final String text = controller.text;
  final int start = selection.isValid
      ? selection.start.clamp(0, text.length)
      : text.length;
  final int end = selection.isValid
      ? selection.end.clamp(0, text.length)
      : text.length;
  final int from = start <= end ? start : end;
  final int to = start <= end ? end : start;
  return (prefix: text.substring(0, from), suffix: text.substring(to));
}

/// Default speech visibility for shared text fields.
///
/// Opt out always for obscured/password fields. When [enableSpeechToText] is
/// null, also hide for numeric/phone/datetime/visible-password keyboards so
/// staff keep typing-only entry for codes and contact numbers.
bool appSpeechToTextEnabledForField({
  required bool? enableSpeechToText,
  required bool obscureText,
  TextInputType? keyboardType,
}) {
  if (obscureText) {
    return false;
  }
  if (enableSpeechToText == false) {
    return false;
  }
  if (enableSpeechToText == true) {
    return true;
  }
  return !_isDictationHostileKeyboard(keyboardType);
}

bool _isDictationHostileKeyboard(TextInputType? keyboardType) {
  if (keyboardType == null) {
    return false;
  }
  if (keyboardType == TextInputType.number ||
      keyboardType == TextInputType.phone ||
      keyboardType == TextInputType.datetime ||
      keyboardType == TextInputType.visiblePassword) {
    return true;
  }
  return keyboardType == const TextInputType.numberWithOptions() ||
      keyboardType == const TextInputType.numberWithOptions(decimal: true) ||
      keyboardType == const TextInputType.numberWithOptions(signed: true) ||
      keyboardType ==
          const TextInputType.numberWithOptions(signed: true, decimal: true);
}

/// Ensures only one field listens at a time.
final class AppSpeechToTextCoordinator extends ChangeNotifier {
  AppSpeechToTextCoordinator({AppSpeechRecognizer? recognizer})
    : _recognizer = recognizer ?? SpeechToTextAppSpeechRecognizer();

  static AppSpeechToTextCoordinator? _instance;

  static AppSpeechToTextCoordinator get instance =>
      _instance ??= AppSpeechToTextCoordinator();

  @visibleForTesting
  static set debugInstance(AppSpeechToTextCoordinator? value) {
    _instance = value;
  }

  final AppSpeechRecognizer _recognizer;
  Object? _activeOwner;
  String _sessionPrefix = '';
  String _sessionSuffix = '';
  AppSpeechInitStatus _initStatus = AppSpeechInitStatus.unavailable;
  String? _lastError;

  Object? get activeOwner => _activeOwner;
  bool get isListening => _activeOwner != null && _recognizer.isListening;
  AppSpeechInitStatus get initStatus => _initStatus;
  String? get lastError => _lastError;

  bool isListeningFor(Object owner) => _activeOwner == owner && isListening;

  Future<AppSpeechInitStatus> ensureReady() async {
    _initStatus = await _recognizer.ensureReady(
      onStatus: (_) => notifyListeners(),
      onError: (String error) {
        _lastError = error;
        notifyListeners();
      },
    );
    notifyListeners();
    return _initStatus;
  }

  /// Starts dictation for [owner]. If another field was listening, stops it
  /// and returns `true` so the caller can warn the user.
  Future<({bool started, bool stoppedOther})> start({
    required Object owner,
    required TextEditingController controller,
    required ValueChanged<String>? onChanged,
  }) async {
    var stoppedOther = false;
    if (_activeOwner != null && _activeOwner != owner) {
      await stop(owner: _activeOwner);
      stoppedOther = true;
    }

    final AppSpeechInitStatus status = await ensureReady();
    if (status != AppSpeechInitStatus.ready) {
      return (started: false, stoppedOther: stoppedOther);
    }

    final ({String prefix, String suffix}) bounds =
        captureSpeechSessionBounds(controller);
    _sessionPrefix = bounds.prefix;
    _sessionSuffix = bounds.suffix;
    _activeOwner = owner;
    _lastError = null;
    notifyListeners();

    try {
      await _recognizer.startListening(
        onResult: (String words, {required bool isFinal}) {
          if (_activeOwner != owner) {
            return;
          }
          insertSpeechTranscript(
            controller,
            words,
            sessionPrefix: _sessionPrefix,
            sessionSuffix: _sessionSuffix,
          );
          onChanged?.call(controller.text);
          if (isFinal) {
            // Keep listening until the user stops; refresh base for next utterance.
            final ({String prefix, String suffix}) nextBounds =
                captureSpeechSessionBounds(controller);
            _sessionPrefix = nextBounds.prefix;
            _sessionSuffix = nextBounds.suffix;
          }
          notifyListeners();
        },
        onStatus: (String status) {
          if (status == 'done' || status == 'notListening') {
            if (_activeOwner == owner && !_recognizer.isListening) {
              _activeOwner = null;
              notifyListeners();
            }
          } else {
            notifyListeners();
          }
        },
        onError: (String error) {
          _lastError = error;
          if (_activeOwner == owner) {
            _activeOwner = null;
          }
          notifyListeners();
        },
      );
    } on Object catch (error) {
      _lastError = error.toString();
      _activeOwner = null;
      notifyListeners();
      return (started: false, stoppedOther: stoppedOther);
    }

    notifyListeners();
    return (started: true, stoppedOther: stoppedOther);
  }

  Future<void> stop({Object? owner}) async {
    if (owner != null && _activeOwner != null && _activeOwner != owner) {
      return;
    }
    try {
      await _recognizer.stopListening();
    } on Object {
      // Best-effort stop on dispose/disable.
    }
    _activeOwner = null;
    notifyListeners();
  }

  Future<void> cancel({Object? owner}) async {
    if (owner != null && _activeOwner != null && _activeOwner != owner) {
      return;
    }
    try {
      await _recognizer.cancelListening();
    } on Object {
      // Best-effort cancel.
    }
    _activeOwner = null;
    notifyListeners();
  }
}

String appSpeechToTextBlockMessage(
  AppLocalizations l10n,
  AppSpeechToTextBlockReason reason,
) {
  return switch (reason) {
    AppSpeechToTextBlockReason.offline => l10n.speechToTextOfflineMessage,
    AppSpeechToTextBlockReason.unavailable =>
      l10n.speechToTextUnavailableMessage,
    AppSpeechToTextBlockReason.permissionDenied =>
      l10n.speechToTextPermissionDeniedMessage,
    AppSpeechToTextBlockReason.noMicrophone =>
      l10n.speechToTextNoMicrophoneMessage,
    AppSpeechToTextBlockReason.fieldDisabled =>
      l10n.speechToTextFieldDisabledMessage,
  };
}

/// Compact mic / stop control for shared text inputs.
class AppSpeechToTextButton extends ConsumerStatefulWidget {
  const AppSpeechToTextButton({
    required this.controller,
    this.enabled = true,
    this.onChanged,
    this.coordinator,
    this.dense = false,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final AppSpeechToTextCoordinator? coordinator;
  final bool dense;

  @override
  ConsumerState<AppSpeechToTextButton> createState() =>
      _AppSpeechToTextButtonState();
}

class _AppSpeechToTextButtonState extends ConsumerState<AppSpeechToTextButton> {
  late final AppSpeechToTextCoordinator _coordinator;
  AppSpeechInitStatus _initStatus = AppSpeechInitStatus.unavailable;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _coordinator = widget.coordinator ?? AppSpeechToTextCoordinator.instance;
    _coordinator.addListener(_handleCoordinatorChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmUp();
    });
  }

  @override
  void didUpdateWidget(covariant AppSpeechToTextButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled &&
        _coordinator.isListeningFor(widget.controller)) {
      _coordinator.stop(owner: widget.controller);
    }
  }

  @override
  void dispose() {
    if (_coordinator.isListeningFor(widget.controller)) {
      _coordinator.stop(owner: widget.controller);
    }
    _coordinator.removeListener(_handleCoordinatorChanged);
    super.dispose();
  }

  void _handleCoordinatorChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _warmUp() async {
    if (!mounted || _checking) {
      return;
    }
    setState(() => _checking = true);
    final AppSpeechInitStatus status = await _coordinator.ensureReady();
    if (!mounted) {
      return;
    }
    setState(() {
      _initStatus = status;
      _checking = false;
    });
  }

  AppSpeechToTextBlockReason? _blockReason({required bool online}) {
    if (!widget.enabled) {
      return AppSpeechToTextBlockReason.fieldDisabled;
    }
    if (!online) {
      return AppSpeechToTextBlockReason.offline;
    }
    return switch (_initStatus) {
      AppSpeechInitStatus.ready => null,
      AppSpeechInitStatus.permissionDenied =>
        AppSpeechToTextBlockReason.permissionDenied,
      AppSpeechInitStatus.noMicrophone =>
        AppSpeechToTextBlockReason.noMicrophone,
      AppSpeechInitStatus.unavailable =>
        AppSpeechToTextBlockReason.unavailable,
    };
  }

  Future<void> _toggle() async {
    final AppLocalizations l10n = context.l10n;
    final bool listening = _coordinator.isListeningFor(widget.controller);
    if (listening) {
      await _coordinator.stop(owner: widget.controller);
      return;
    }

    final AsyncValue<AppConnectivityStatus> connectivity = ref.read(
      appConnectivityStatusProvider,
    );
    final bool online = connectivity.maybeWhen(
      data: (AppConnectivityStatus status) => status.isOnline,
      orElse: () => true,
    );
    if (!online) {
      showAppSuccessSnackBar(context, l10n.speechToTextOfflineMessage);
      return;
    }

    setState(() => _checking = true);
    final ({bool started, bool stoppedOther}) result = await _coordinator.start(
      owner: widget.controller,
      controller: widget.controller,
      onChanged: widget.onChanged,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _initStatus = _coordinator.initStatus;
      _checking = false;
    });

    if (result.stoppedOther) {
      showAppSuccessSnackBar(context, l10n.speechToTextSwitchedFieldMessage);
    }
    if (!result.started) {
      final AppSpeechToTextBlockReason reason =
          _blockReason(online: true) ??
          AppSpeechToTextBlockReason.unavailable;
      showAppSuccessSnackBar(context, appSpeechToTextBlockMessage(l10n, reason));
      if (_coordinator.lastError != null &&
          reason == AppSpeechToTextBlockReason.unavailable) {
        showAppSuccessSnackBar(context, l10n.speechToTextErrorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AppConnectivityStatus> connectivity = ref.watch(
      appConnectivityStatusProvider,
    );
    final bool online = connectivity.maybeWhen(
      data: (AppConnectivityStatus status) => status.isOnline,
      orElse: () => true,
    );
    final bool listening = _coordinator.isListeningFor(widget.controller);
    final AppSpeechToTextBlockReason? blockReason = listening
        ? null
        : _blockReason(online: online);
    final bool canPress =
        widget.enabled && (listening || blockReason == null) && !_checking;
    final String tooltip = listening
        ? l10n.speechToTextStopTooltip
        : (blockReason == null
              ? l10n.speechToTextStartTooltip
              : appSpeechToTextBlockMessage(l10n, blockReason));

    return AppButton(
      iconOnly: true,
      dense: widget.dense,
      leadingIcon: listening ? Icons.stop : Icons.mic_none_outlined,
      label: listening
          ? l10n.speechToTextStopTooltip
          : l10n.speechToTextStartTooltip,
      semanticLabel: tooltip,
      tooltip: tooltip,
      enabled: canPress || listening,
      onPressed: (canPress || listening) ? _toggle : null,
    );
  }
}
