/// Cancels an in-flight AI format request.
final class AppSpeechAiAbort {
  void Function()? _onAbort;

  void attach(void Function() onAbort) {
    _onAbort = onAbort;
  }

  void abort() {
    _onAbort?.call();
  }
}

/// Optional backend formatter. Returns null to keep the STT text.
typedef AppSpeechAiFormatter =
    Future<String?> Function({
      required String transcript,
      required String mode,
      required AppSpeechAiAbort abort,
      String? locale,
      String? hint,
    });
