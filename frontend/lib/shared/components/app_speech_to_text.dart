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
/// null, speech is shown for every other editable field (including number,
/// phone, email, and datetime keyboards). Set false to force hide, true to
/// force show (still never on [obscureText]).
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
  return true;
}

/// How spoken transcripts are normalized before insertion.
enum AppSpeechTranscriptMode {
  /// Running prose: punctuation words and cardinal number phrases.
  text,

  /// Email-oriented tokens (`at`, `dot`, `underscore`, …).
  email,

  /// Integer / phone / date-time digit fields.
  digits,

  /// Amounts and decimal number fields.
  decimal,
}

/// Picks a transcript mode from a Flutter [TextInputType].
AppSpeechTranscriptMode appSpeechTranscriptModeForKeyboard(
  TextInputType? keyboardType,
) {
  if (keyboardType == TextInputType.emailAddress) {
    return AppSpeechTranscriptMode.email;
  }
  if (keyboardType == TextInputType.phone ||
      keyboardType == TextInputType.number ||
      keyboardType == TextInputType.datetime) {
    return AppSpeechTranscriptMode.digits;
  }
  if (keyboardType == const TextInputType.numberWithOptions() ||
      keyboardType == const TextInputType.numberWithOptions(decimal: true) ||
      keyboardType == const TextInputType.numberWithOptions(signed: true) ||
      keyboardType ==
          const TextInputType.numberWithOptions(signed: true, decimal: true)) {
    return AppSpeechTranscriptMode.decimal;
  }
  return AppSpeechTranscriptMode.text;
}

/// Normalizes a spoken transcript for the given [mode].
String appSpeechNormalizeTranscript(
  String transcript, {
  AppSpeechTranscriptMode mode = AppSpeechTranscriptMode.text,
}) {
  final String trimmed = transcript.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  return switch (mode) {
    AppSpeechTranscriptMode.digits => _normalizeSpokenNumberField(
      trimmed,
      allowDecimal: false,
    ),
    AppSpeechTranscriptMode.decimal => _normalizeSpokenNumberField(
      trimmed,
      allowDecimal: true,
    ),
    AppSpeechTranscriptMode.email => _normalizeSpokenEmail(trimmed),
    AppSpeechTranscriptMode.text => _normalizeSpokenText(trimmed),
  };
}

/// Convenience transform used by digit-only shared fields.
String appSpeechDigitsOnlyTranscript(
  String transcript, {
  bool allowDecimal = false,
}) {
  return appSpeechNormalizeTranscript(
    transcript,
    mode: allowDecimal
        ? AppSpeechTranscriptMode.decimal
        : AppSpeechTranscriptMode.digits,
  );
}

/// Default transform for free-text / search / select / rich-text fields.
String appSpeechTextTranscript(String transcript) {
  return appSpeechNormalizeTranscript(
    transcript,
    mode: AppSpeechTranscriptMode.text,
  );
}

/// Default transform for email fields.
String appSpeechEmailTranscript(String transcript) {
  return appSpeechNormalizeTranscript(
    transcript,
    mode: AppSpeechTranscriptMode.email,
  );
}

String Function(String transcript) appSpeechTranscriptTransformForMode(
  AppSpeechTranscriptMode mode,
) {
  return (String transcript) =>
      appSpeechNormalizeTranscript(transcript, mode: mode);
}

String Function(String transcript) appSpeechTranscriptTransformForKeyboard(
  TextInputType? keyboardType,
) {
  return appSpeechTranscriptTransformForMode(
    appSpeechTranscriptModeForKeyboard(keyboardType),
  );
}

// --- Token helpers -----------------------------------------------------------

List<String> _speechTokens(String transcript) {
  final String normalized = transcript
      .toLowerCase()
      .replaceAll(RegExp(r'[—–]'), '-')
      .replaceAllMapped(
        RegExp(r'(\d)[,\s]+(?=\d)'),
        (Match match) => match.group(1)!,
      );
  // Keep hyphenated number words as separate tokens ("twenty-five").
  final String spaced = normalized.replaceAll('-', ' ');
  return spaced
      .split(RegExp(r'\s+'))
      .map((String token) => token.trim())
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}

const Map<String, int> _speechOnes = <String, int>{
  'zero': 0,
  'oh': 0,
  'o': 0,
  'nought': 0,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
};

const Map<String, int> _speechTeens = <String, int>{
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
};

const Map<String, int> _speechTens = <String, int>{
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fourty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
};

const Map<String, int> _speechScales = <String, int>{
  'hundred': 100,
  'thousand': 1000,
  'million': 1000000,
  'billion': 1000000000,
};

bool _isSpokenNumberAtom(String token, {bool allowAnd = false}) {
  if (token == 'and') {
    return allowAnd;
  }
  if (_speechOnes.containsKey(token) ||
      _speechTeens.containsKey(token) ||
      _speechTens.containsKey(token) ||
      _speechScales.containsKey(token) ||
      token == 'point' ||
      token == 'dot') {
    return true;
  }
  return RegExp(r'^\d+(\.\d+)?$').hasMatch(token);
}

bool _spokenNumberPhraseNeedsCardinal(List<String> tokens) {
  for (final String token in tokens) {
    if (_speechTeens.containsKey(token) ||
        _speechTens.containsKey(token) ||
        _speechScales.containsKey(token)) {
      return true;
    }
  }
  return false;
}

/// Parses a spoken English cardinal / decimal phrase into a numeric string.
///
/// Examples: `one thousand two hundred twenty-five` → `1225`,
/// `twelve point five` → `12.5`.
String? parseSpokenEnglishNumber(
  String transcript, {
  bool allowDecimal = true,
}) {
  final List<String> tokens = _speechTokens(transcript)
      .where((String token) => token != 'and')
      .toList(growable: false);
  if (tokens.isEmpty) {
    return null;
  }

  final int pointIndex = tokens.indexWhere(
    (String token) => token == 'point' || token == 'dot',
  );
  final List<String> wholeTokens = pointIndex >= 0
      ? tokens.sublist(0, pointIndex)
      : tokens;
  final List<String> fractionTokens = pointIndex >= 0
      ? tokens.sublist(pointIndex + 1)
      : const <String>[];

  if (!allowDecimal && fractionTokens.isNotEmpty) {
    return null;
  }

  final int? whole = wholeTokens.isEmpty
      ? (pointIndex >= 0 ? 0 : null)
      : _parseSpokenCardinalTokens(wholeTokens);
  if (whole == null) {
    return null;
  }

  if (fractionTokens.isEmpty) {
    return whole.toString();
  }

  final String fractionDigits = _spokenFractionDigits(fractionTokens);
  if (fractionDigits.isEmpty) {
    return whole.toString();
  }
  return '$whole.$fractionDigits';
}

int? _parseSpokenCardinalTokens(List<String> tokens) {
  if (tokens.isEmpty) {
    return null;
  }
  if (!_spokenNumberPhraseNeedsCardinal(tokens) &&
      tokens.every(
        (String token) =>
            _speechOnes.containsKey(token) || RegExp(r'^\d+$').hasMatch(token),
      )) {
    // Digit-by-digit: "one two two five" → 1225, not 1+2+2+5.
    return null;
  }

  var total = 0;
  var current = 0;
  var sawNumber = false;

  for (final String token in tokens) {
    final int? arabic = int.tryParse(token);
    if (arabic != null) {
      current += arabic;
      sawNumber = true;
      continue;
    }
    final int? one = _speechOnes[token];
    if (one != null) {
      current += one;
      sawNumber = true;
      continue;
    }
    final int? teen = _speechTeens[token];
    if (teen != null) {
      current += teen;
      sawNumber = true;
      continue;
    }
    final int? ten = _speechTens[token];
    if (ten != null) {
      current += ten;
      sawNumber = true;
      continue;
    }
    final int? scale = _speechScales[token];
    if (scale != null) {
      if (scale == 100) {
        current = (current == 0 ? 1 : current) * 100;
      } else {
        total += (current == 0 ? 1 : current) * scale;
        current = 0;
      }
      sawNumber = true;
      continue;
    }
    return null;
  }

  if (!sawNumber) {
    return null;
  }
  return total + current;
}

String _spokenFractionDigits(List<String> tokens) {
  final StringBuffer buffer = StringBuffer();
  for (final String token in tokens) {
    final int? arabic = int.tryParse(token);
    if (arabic != null) {
      buffer.write(token);
      continue;
    }
    final int? one = _speechOnes[token];
    if (one != null) {
      buffer.write(one);
      continue;
    }
    final int? teen = _speechTeens[token];
    if (teen != null) {
      buffer.write(teen);
      continue;
    }
    final int? ten = _speechTens[token];
    if (ten != null) {
      buffer.write(ten);
      continue;
    }
  }
  return buffer.toString();
}

String _digitSequenceFromTokens(List<String> tokens, {required bool allowDecimal}) {
  final StringBuffer buffer = StringBuffer();
  var wroteDecimal = false;
  for (final String token in tokens) {
    if (allowDecimal && (token == 'point' || token == 'dot')) {
      if (!wroteDecimal && !buffer.toString().contains('.')) {
        buffer.write('.');
        wroteDecimal = true;
      }
      continue;
    }
    final int? one = _speechOnes[token];
    if (one != null) {
      buffer.write(one);
      continue;
    }
    final int? teen = _speechTeens[token];
    if (teen != null) {
      buffer.write(teen);
      continue;
    }
    final int? ten = _speechTens[token];
    if (ten != null) {
      buffer.write(ten);
      continue;
    }
    for (final int codeUnit in token.codeUnits) {
      final String char = String.fromCharCode(codeUnit);
      if (RegExp(r'[0-9]').hasMatch(char)) {
        buffer.write(char);
      } else if (allowDecimal && (char == '.' || char == ',') && !wroteDecimal) {
        buffer.write('.');
        wroteDecimal = true;
      }
    }
  }
  return buffer.toString();
}

String _normalizeSpokenNumberField(
  String transcript, {
  required bool allowDecimal,
}) {
  final String? cardinal = parseSpokenEnglishNumber(
    transcript,
    allowDecimal: allowDecimal,
  );
  if (cardinal != null) {
    return cardinal;
  }
  return _digitSequenceFromTokens(
    _speechTokens(transcript),
    allowDecimal: allowDecimal,
  );
}

// --- Email / text ------------------------------------------------------------

const Map<String, String> _speechEmailSymbols = <String, String>{
  'at': '@',
  'dot': '.',
  'period': '.',
  'underscore': '_',
  'underline': '_',
  'dash': '-',
  'hyphen': '-',
  'minus': '-',
  'plus': '+',
};

const List<(List<String> phrase, String replacement)> _speechTextPhrases =
    <(List<String>, String)>[
      (<String>['question', 'mark'], '?'),
      (<String>['exclamation', 'mark'], '!'),
      (<String>['exclamation', 'point'], '!'),
      (<String>['full', 'stop'], '.'),
      (<String>['new', 'line'], '\n'),
      (<String>['new', 'paragraph'], '\n\n'),
      (<String>['open', 'paren'], '('),
      (<String>['close', 'paren'], ')'),
      (<String>['open', 'parenthesis'], '('),
      (<String>['close', 'parenthesis'], ')'),
      (<String>['open', 'quote'], '"'),
      (<String>['close', 'quote'], '"'),
      (<String>['under', 'score'], '_'),
    ];

const Map<String, String> _speechTextSymbols = <String, String>{
  'period': '.',
  'comma': ',',
  'colon': ':',
  'semicolon': ';',
  'slash': '/',
  'backslash': r'\',
  'apostrophe': "'",
  'quote': '"',
  'ampersand': '&',
  'percent': '%',
  'hash': '#',
  'pound': '#',
  'at': '@',
  'dot': '.',
  'underscore': '_',
  'dash': '-',
  'hyphen': '-',
  'plus': '+',
};

String _normalizeSpokenEmail(String transcript) {
  final List<String> tokens = _speechTokens(transcript);
  final StringBuffer buffer = StringBuffer();
  for (var i = 0; i < tokens.length; i++) {
    if (i + 1 < tokens.length &&
        tokens[i] == 'under' &&
        tokens[i + 1] == 'score') {
      buffer.write('_');
      i++;
      continue;
    }
    final String? symbol = _speechEmailSymbols[tokens[i]];
    if (symbol != null) {
      buffer.write(symbol);
      continue;
    }
    buffer.write(tokens[i]);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), '');
}

String _normalizeSpokenText(String transcript) {
  final List<String> tokens = _speechTokens(transcript);
  final List<String> output = <String>[];
  var index = 0;
  while (index < tokens.length) {
    final int? phraseEnd = _matchTextPhrase(tokens, index);
    if (phraseEnd != null) {
      final List<String> phrase = tokens.sublist(index, phraseEnd);
      output.add(_replacementForTextPhrase(phrase));
      index = phraseEnd;
      continue;
    }

    if (_isSpokenNumberAtom(tokens[index])) {
      final int numberEnd = _consumeNumberPhrase(tokens, index);
      final List<String> numberTokens = tokens.sublist(index, numberEnd);
      final String phrase = numberTokens.join(' ');
      final String digits = _digitSequenceFromTokens(
        numberTokens,
        allowDecimal: true,
      );
      final String? parsed = parseSpokenEnglishNumber(phrase) ??
          (digits.isEmpty ? null : digits);
      if (parsed != null && parsed.isNotEmpty) {
        output.add(parsed);
        index = numberEnd;
        continue;
      }
    }

    final String? symbol = _speechTextSymbols[tokens[index]];
    if (symbol != null) {
      output.add(symbol);
      index++;
      continue;
    }

    output.add(tokens[index]);
    index++;
  }

  return _joinSpokenTextTokens(output);
}

int? _matchTextPhrase(List<String> tokens, int index) {
  for (final (List<String> phrase, String _) in _speechTextPhrases) {
    if (index + phrase.length > tokens.length) {
      continue;
    }
    var matches = true;
    for (var i = 0; i < phrase.length; i++) {
      if (tokens[index + i] != phrase[i]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return index + phrase.length;
    }
  }
  return null;
}

String _replacementForTextPhrase(List<String> phrase) {
  for (final (List<String> candidate, String replacement) in _speechTextPhrases) {
    if (candidate.length == phrase.length) {
      var matches = true;
      for (var i = 0; i < candidate.length; i++) {
        if (candidate[i] != phrase[i]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return replacement;
      }
    }
  }
  return phrase.join(' ');
}

int _consumeNumberPhrase(List<String> tokens, int start) {
  var end = start;
  while (end < tokens.length) {
    final String token = tokens[end];
    if (token == 'and') {
      final bool nextIsNumber =
          end + 1 < tokens.length && _isSpokenNumberAtom(tokens[end + 1]);
      if (nextIsNumber) {
        end++;
        continue;
      }
      break;
    }
    if (!_isSpokenNumberAtom(token)) {
      break;
    }
    end++;
  }
  return end;
}

String _joinSpokenTextTokens(List<String> tokens) {
  final StringBuffer buffer = StringBuffer();
  for (var i = 0; i < tokens.length; i++) {
    final String token = tokens[i];
    if (token.isEmpty) {
      continue;
    }
    final bool isPunctuation = RegExp(r'''^[.,:;!?%@#&/\\_"'()]+$''').hasMatch(
      token,
    );
    final bool isNewline = token.contains('\n');
    if (buffer.isEmpty || isNewline) {
      buffer.write(token);
      continue;
    }
    if (isPunctuation) {
      // Trim a trailing space before punctuation.
      final String current = buffer.toString();
      if (current.endsWith(' ')) {
        buffer.clear();
        buffer.write(current.trimRight());
      }
      buffer.write(token);
      if (token == '.' ||
          token == ',' ||
          token == ';' ||
          token == ':' ||
          token == '!' ||
          token == '?') {
        buffer.write(' ');
      }
      continue;
    }
    if (!buffer.toString().endsWith(' ') &&
        !buffer.toString().endsWith('\n') &&
        !buffer.toString().endsWith('(')) {
      buffer.write(' ');
    }
    buffer.write(token);
  }
  return buffer.toString().replaceAll(RegExp(r'[ \t]+\n'), '\n').trimRight();
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
    String Function(String transcript)? transcriptTransform,
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
          final String transcript =
              (transcriptTransform ?? appSpeechTextTranscript).call(words);
          insertSpeechTranscript(
            controller,
            transcript,
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
    this.transcriptTransform,
    this.coordinator,
    this.dense = false,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  /// Optional sanitizer (e.g. [appSpeechDigitsOnlyTranscript] for phone/date).
  final String Function(String transcript)? transcriptTransform;
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
      transcriptTransform:
          widget.transcriptTransform ?? appSpeechTextTranscript,
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
