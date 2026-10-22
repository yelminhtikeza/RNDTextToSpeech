import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/config/tts_config.dart';
import 'package:rnd_text_to_speech/models/burmese_speech_state.dart';
import 'package:rnd_text_to_speech/providers/burmese_speech_controller.dart';

import '../support/fake_tts_service.dart';

const String _GOOGLE = 'com.google.android.tts';
const String _BURMESE_ENGINE = 'com.example.burmese.tts';
const String _BURMESE_TEXT = 'မင်္ဂလာပါ';

/// Controller ကို ဖန်တီးပြီး build() မှ စတင်သော engine ရှာဖွေမှု ပြီးသည်အထိ စောင့်သည်။
Future<ProviderContainer> _createDetectedContainer({required FakeTtsService fake}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [ttsServiceProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  container.read(burmeseSpeechControllerProvider);
  await pumpEventQueue();
  return container;
}

BurmeseSpeechState _stateOf(ProviderContainer container) =>
    container.read(burmeseSpeechControllerProvider);

BurmeseSpeechController _controllerOf(ProviderContainer container) =>
    container.read(burmeseSpeechControllerProvider.notifier);

void main() {
  group('detectBurmeseEngines', () {
    test('selects the Burmese-capable engine even when it is not first', () async {
      final FakeTtsService fake = FakeTtsService(
        engines: <String>[_GOOGLE, _BURMESE_ENGINE],
        burmeseEngines: <String>{_BURMESE_ENGINE},
      );
      final ProviderContainer container = await _createDetectedContainer(fake: fake);

      expect(_stateOf(container).status, SpeechStatus.ready);
      expect(_stateOf(container).burmeseEngines, <String>[_BURMESE_ENGINE]);
      expect(_stateOf(container).selectedEngine, _BURMESE_ENGINE);
      expect(fake.activeEngine, _BURMESE_ENGINE);
    });

    test('reports noBurmeseEngine when no engine supports my-MM', () async {
      final FakeTtsService fake = FakeTtsService(engines: <String>[_GOOGLE]);
      final ProviderContainer container = await _createDetectedContainer(fake: fake);

      expect(_stateOf(container).status, SpeechStatus.noBurmeseEngine);
      expect(_stateOf(container).canSpeak, isFalse);
    });

    test('reports noBurmeseEngine when the device has no engines', () async {
      final ProviderContainer container =
          await _createDetectedContainer(fake: FakeTtsService());

      expect(_stateOf(container).status, SpeechStatus.noBurmeseEngine);
    });

    test('reports detectionFailed with the platform message', () async {
      final FakeTtsService fake = FakeTtsService(failingOperation: 'getEngines');
      final ProviderContainer container = await _createDetectedContainer(fake: fake);

      expect(_stateOf(container).status, SpeechStatus.detectionFailed);
      expect(_stateOf(container).platformMessage, 'getEngines failed');
    });
  });

  group('speak', () {
    late FakeTtsService fake;
    late ProviderContainer container;

    setUp(() async {
      fake = FakeTtsService(
        engines: <String>[_BURMESE_ENGINE],
        burmeseEngines: <String>{_BURMESE_ENGINE},
        maxInputLength: 20,
      );
      container = await _createDetectedContainer(fake: fake);
    });

    test('speaks trimmed text with the chosen rate and pitch', () async {
      _controllerOf(container).updateSpeechRate(rate: 0.8);
      _controllerOf(container).updatePitch(pitch: 1.5);

      await _controllerOf(container).speak(text: '  $_BURMESE_TEXT  ');

      expect(fake.spokenText, _BURMESE_TEXT);
      expect(fake.appliedRate, 0.8);
      expect(fake.appliedPitch, 1.5);
      expect(_stateOf(container).status, SpeechStatus.ready);
      expect(_stateOf(container).error, isNull);
    });

    test('rejects blank text without calling the engine', () async {
      await _controllerOf(container).speak(text: '   ');

      expect(_stateOf(container).error, SpeechError.emptyText);
      expect(fake.spokenText, isNull);
    });

    test('rejects text longer than the engine limit', () async {
      await _controllerOf(container).speak(text: 'က' * 21);

      expect(_stateOf(container).error, SpeechError.textTooLong);
      expect(fake.spokenText, isNull);
    });

    test('accepts text exactly at the engine limit', () async {
      await _controllerOf(container).speak(text: 'က' * 20);

      expect(_stateOf(container).error, isNull);
      expect(fake.spokenText, 'က' * 20);
    });

    test('reports speakFailed with the platform message when the engine throws', () async {
      final FakeTtsService failingFake = FakeTtsService(
        engines: <String>[_BURMESE_ENGINE],
        burmeseEngines: <String>{_BURMESE_ENGINE},
        failingOperation: 'speak',
      );
      final ProviderContainer failingContainer =
          await _createDetectedContainer(fake: failingFake);

      await _controllerOf(failingContainer).speak(text: _BURMESE_TEXT);

      expect(_stateOf(failingContainer).error, SpeechError.speakFailed);
      expect(_stateOf(failingContainer).platformMessage, 'speak failed');
      expect(_stateOf(failingContainer).status, SpeechStatus.ready);
    });

    test('reports speakFailed when the engine returns failure', () async {
      final FakeTtsService rejectingFake = FakeTtsService(
        engines: <String>[_BURMESE_ENGINE],
        burmeseEngines: <String>{_BURMESE_ENGINE},
        isSpeakSuccessful: false,
      );
      final ProviderContainer rejectingContainer =
          await _createDetectedContainer(fake: rejectingFake);

      await _controllerOf(rejectingContainer).speak(text: _BURMESE_TEXT);

      expect(_stateOf(rejectingContainer).error, SpeechError.speakFailed);
    });

    test('user stop is not reported as a failure', () async {
      fake.pendingSpeak = Completer<bool>();
      final Future<void> speaking = _controllerOf(container).speak(text: _BURMESE_TEXT);
      await pumpEventQueue();
      expect(_stateOf(container).status, SpeechStatus.speaking);

      await _controllerOf(container).stop();
      await speaking;

      expect(fake.stopCallCount, 1);
      expect(_stateOf(container).status, SpeechStatus.ready);
      expect(_stateOf(container).error, isNull);
    });

    test('a new action clears the previous error', () async {
      await _controllerOf(container).speak(text: '');
      expect(_stateOf(container).error, SpeechError.emptyText);

      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      expect(_stateOf(container).error, isNull);
    });
  });

  test('defaults match TtsConfig', () {
    const BurmeseSpeechState state = BurmeseSpeechState.initial();

    expect(state.speechRate, TtsConfig.SPEECH_RATE_DEFAULT);
    expect(state.pitch, TtsConfig.PITCH_DEFAULT);
    expect(state.status, SpeechStatus.detecting);
  });
}
