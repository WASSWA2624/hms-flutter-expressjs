import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_rich_text_editor.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/components/app_speech_to_text.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';

import 'component_test_app.dart';

final class _FakeSpeechRecognizer implements AppSpeechRecognizer {
  AppSpeechInitStatus initStatus = AppSpeechInitStatus.ready;
  bool _listening = false;
  void Function(String words, {required bool isFinal})? onResult;

  @override
  bool get isListening => _listening;

  @override
  Future<AppSpeechInitStatus> ensureReady({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    return initStatus;
  }

  @override
  Future<void> startListening({
    required void Function(String words, {required bool isFinal}) onResult,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    this.onResult = onResult;
    _listening = true;
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
  }

  @override
  Future<void> cancelListening() async {
    _listening = false;
  }

  void emit(String words, {bool isFinal = false}) {
    onResult?.call(words, isFinal: isFinal);
  }
}

void main() {
  late _FakeSpeechRecognizer recognizer;
  late AppSpeechToTextCoordinator coordinator;

  setUp(() {
    recognizer = _FakeSpeechRecognizer();
    coordinator = AppSpeechToTextCoordinator(recognizer: recognizer);
    AppSpeechToTextCoordinator.debugInstance = coordinator;
  });

  tearDown(() {
    AppSpeechToTextCoordinator.debugInstance = null;
  });

  Future<void> pumpSpeechApp(
    WidgetTester tester,
    Widget child, {
    AppConnectivityStatus connectivity = AppConnectivityStatus.online,
  }) async {
    await pumpComponent(
      tester,
      ProviderScope(
        overrides: [
          appConnectivityStatusProvider.overrideWith(
            (Ref ref) => Stream<AppConnectivityStatus>.value(connectivity),
          ),
        ],
        child: child,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  test('insertSpeechTranscript preserves surrounding markup markers', () {
    final TextEditingController controller = TextEditingController(
      text: '**bold** middle __under__',
    );
    controller.selection = const TextSelection(baseOffset: 9, extentOffset: 15);

    final ({String prefix, String suffix}) bounds =
        captureSpeechSessionBounds(controller);
    insertSpeechTranscript(
      controller,
      'spoken',
      sessionPrefix: bounds.prefix,
      sessionSuffix: bounds.suffix,
    );

    expect(controller.text, '**bold** spoken __under__');
    expect(controller.selection.baseOffset, '**bold** spoken'.length);
  });

  test('appSpeechToTextEnabledForField hides passwords only by default', () {
    expect(
      appSpeechToTextEnabledForField(
        enableSpeechToText: null,
        obscureText: true,
        keyboardType: TextInputType.text,
      ),
      isFalse,
    );
    expect(
      appSpeechToTextEnabledForField(
        enableSpeechToText: false,
        obscureText: false,
        keyboardType: TextInputType.multiline,
      ),
      isFalse,
    );
    expect(
      appSpeechToTextEnabledForField(
        enableSpeechToText: null,
        obscureText: false,
        keyboardType: TextInputType.number,
      ),
      isTrue,
    );
    expect(
      appSpeechToTextEnabledForField(
        enableSpeechToText: null,
        obscureText: false,
        keyboardType: TextInputType.phone,
      ),
      isTrue,
    );
    expect(
      appSpeechToTextEnabledForField(
        enableSpeechToText: null,
        obscureText: false,
        keyboardType: TextInputType.multiline,
      ),
      isTrue,
    );
  });

  test('appSpeechDigitsOnlyTranscript extracts spoken digits', () {
    expect(appSpeechDigitsOnlyTranscript('seven eight three'), '783');
    expect(
      appSpeechDigitsOnlyTranscript('one two point five', allowDecimal: true),
      '12.5',
    );
    expect(
      appSpeechDigitsOnlyTranscript('1,250.50', allowDecimal: true),
      '1250.50',
    );
  });

  test('parseSpokenEnglishNumber understands cardinal phrases', () {
    expect(
      parseSpokenEnglishNumber('one thousand two hundred twenty-five'),
      '1225',
    );
    expect(parseSpokenEnglishNumber('one thousand two hundred twenty five'), '1225');
    expect(parseSpokenEnglishNumber('fifteen'), '15');
    expect(parseSpokenEnglishNumber('twelve point five'), '12.5');
    expect(parseSpokenEnglishNumber('two million'), '2000000');
  });

  test('number fields use cardinal phrases and digit sequences', () {
    expect(
      appSpeechNormalizeTranscript(
        'one thousand two hundred twenty-five',
        mode: AppSpeechTranscriptMode.digits,
      ),
      '1225',
    );
    expect(
      appSpeechNormalizeTranscript(
        'one two two five',
        mode: AppSpeechTranscriptMode.digits,
      ),
      '1225',
    );
    expect(
      appSpeechNormalizeTranscript(
        'one thousand point five',
        mode: AppSpeechTranscriptMode.decimal,
      ),
      '1000.5',
    );
  });

  test('email and text modes apply spoken punctuation', () {
    expect(
      appSpeechEmailTranscript('jane underscore doe at example dot com'),
      'jane_doe@example.com',
    );
    expect(
      appSpeechTextTranscript(
        'hello period buy one thousand units question mark',
      ),
      'hello. buy 1000 units?',
    );
  });

  testWidgets('mic toggles to stop while listening and inserts text', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController(text: 'Hello ');
    controller.selection = const TextSelection.collapsed(offset: 6);

    await pumpSpeechApp(
      tester,
      AppTextField(
        controller: controller,
        labelText: 'Note',
        enableSpeechToText: true,
      ),
    );

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTextField)),
    );
    expect(find.byTooltip(l10n.speechToTextStartTooltip), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.speechToTextStartTooltip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byTooltip(l10n.speechToTextStopTooltip), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);

    recognizer.emit('world', isFinal: true);
    await tester.pump();

    expect(controller.text, 'Hello world');

    await tester.tap(find.byTooltip(l10n.speechToTextStopTooltip));
    await tester.pump();
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
  });

  testWidgets('offline disables speech control with localized reason', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();

    await pumpSpeechApp(
      tester,
      AppTextField(
        controller: controller,
        labelText: 'Note',
        enableSpeechToText: true,
      ),
      connectivity: AppConnectivityStatus.offline,
    );

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTextField)),
    );
    expect(find.byTooltip(l10n.speechToTextOfflineMessage), findsOneWidget);
  });

  testWidgets('searchable select and number fields expose speech controls', (
    WidgetTester tester,
  ) async {
    await pumpSpeechApp(
      tester,
      Column(
        children: <Widget>[
          AppSelectField<String>.searchable(
            labelText: 'Facility',
            options: const <AppSelectOption<String>>[
              AppSelectOption<String>(value: 'a', label: 'Alpha'),
              AppSelectOption<String>(value: 'b', label: 'Beta'),
            ],
            onChanged: (_) {},
          ),
          AppTextField(
            controller: TextEditingController(),
            labelText: 'Quantity',
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );

    expect(find.byIcon(Icons.mic_none_outlined), findsNWidgets(2));
  });

  testWidgets('opt-out and password fields hide speech controls', (
    WidgetTester tester,
  ) async {
    await pumpSpeechApp(
      tester,
      Column(
        children: <Widget>[
          AppTextField(
            controller: TextEditingController(),
            labelText: 'Secret',
            obscureText: true,
            enableObscureTextToggle: true,
            showObscuredTextLabel: 'Show',
            hideObscuredTextLabel: 'Hide',
          ),
          AppTextField(
            controller: TextEditingController(),
            labelText: 'Code',
            enableSpeechToText: false,
          ),
        ],
      ),
    );

    expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
    expect(find.byIcon(Icons.stop), findsNothing);
  });

  testWidgets('rich text caret insert preserves surrounding markup', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: '**keep** | tail',
    );
    controller.selection = const TextSelection.collapsed(offset: 9);

    await pumpSpeechApp(
      tester,
      AppRichTextEditor(
        controller: controller,
        labelText: 'Clinical note',
      ),
    );

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppRichTextEditor)),
    );
    await tester.tap(find.byTooltip(l10n.speechToTextStartTooltip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    recognizer.emit('spoken', isFinal: true);
    await tester.pump();

    expect(controller.text, '**keep** spoken| tail');
  });

  testWidgets('starting speech on a second field stops the first', (
    WidgetTester tester,
  ) async {
    final TextEditingController first = TextEditingController(text: 'A');
    final TextEditingController second = TextEditingController(text: 'B');
    first.selection = const TextSelection.collapsed(offset: 1);
    second.selection = const TextSelection.collapsed(offset: 1);

    await pumpSpeechApp(
      tester,
      Column(
        children: <Widget>[
          AppTextField(
            controller: first,
            labelText: 'First',
            enableSpeechToText: true,
          ),
          AppTextField(
            controller: second,
            labelText: 'Second',
            enableSpeechToText: true,
          ),
        ],
      ),
    );

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.text('First')),
    );

    await tester.tap(find.byTooltip(l10n.speechToTextStartTooltip).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(coordinator.isListeningFor(first), isTrue);

    await tester.tap(find.byTooltip(l10n.speechToTextStartTooltip).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(coordinator.isListeningFor(first), isFalse);
    expect(coordinator.isListeningFor(second), isTrue);
    expect(find.text(l10n.speechToTextSwitchedFieldMessage), findsOneWidget);
  });
}
