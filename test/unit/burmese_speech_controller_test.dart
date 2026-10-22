import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/config/tts_config.dart';
import 'package:rnd_text_to_speech/models/audio_save_result.dart';
import 'package:rnd_text_to_speech/models/burmese_speech_state.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/providers/burmese_speech_controller.dart';
import 'package:rnd_text_to_speech/services/audio_file_saver.dart';

import '../support/fake_audio_file_saver.dart';
import '../support/fake_on_device_speaker.dart';
import '../support/fake_tts_service.dart';

const String _GOOGLE = 'com.google.android.tts';
const String _BURMESE_ENGINE = 'com.example.burmese.tts';
const String _BURMESE_TEXT = 'မင်္ဂလာပါ';
const String _ON_DEVICE = TtsConfig.ON_DEVICE_ENGINE_ID;

/// Controller ကို ဖန်တီးပြီး build() မှ စတင်သော engine ရှာဖွေမှု ပြီးသည်အထိ စောင့်သည်။
Future<ProviderContainer> _createDetectedContainer({
  FakeTtsService? system,
  FakeOnDeviceSpeaker? onDevice,
  FakeAudioFileSaver? saver,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      ttsServiceProvider.overrideWithValue(system ?? FakeTtsService()),
      onDeviceSpeakerProvider.overrideWithValue(onDevice ?? FakeOnDeviceSpeaker()),
      audioFileSaverProvider.overrideWithValue(saver ?? FakeAudioFileSaver()),
    ],
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

FakeTtsService _systemWithBurmese() => FakeTtsService(
      engines: <String>[_GOOGLE, _BURMESE_ENGINE],
      burmeseEngines: <String>{_BURMESE_ENGINE},
    );

void main() {
  group('detectBurmeseEngines', () {
    test('lists the on-device engine first, then Burmese-capable Android engines', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
      final ProviderContainer container =
          await _createDetectedContainer(system: _systemWithBurmese(), onDevice: onDevice);

      expect(_stateOf(container).engines, <String>[_ON_DEVICE, _BURMESE_ENGINE]);
      expect(_stateOf(container).selectedEngine, _ON_DEVICE);
      expect(_stateOf(container).status, SpeechStatus.ready);
      expect(onDevice.loadCallCount, 1);
    });

    test('the on-device engine works when no Android engine supports Burmese', () async {
      final ProviderContainer container =
          await _createDetectedContainer(system: FakeTtsService(engines: <String>[_GOOGLE]));

      expect(_stateOf(container).engines, <String>[_ON_DEVICE]);
      expect(_stateOf(container).canSpeak, isTrue);
    });

    test('a failing Android engine scan is not fatal', () async {
      final ProviderContainer container =
          await _createDetectedContainer(system: FakeTtsService(failingOperation: 'getEngines'));

      expect(_stateOf(container).engines, <String>[_ON_DEVICE]);
      expect(_stateOf(container).status, SpeechStatus.ready);
    });

    test('model load failure keeps the engine list so the user can switch', () async {
      final ProviderContainer container = await _createDetectedContainer(
        system: _systemWithBurmese(),
        onDevice: FakeOnDeviceSpeaker(
          loadError: const MyanmarTtsException(operation: 'load', platformMessage: 'model missing'),
        ),
      );

      expect(_stateOf(container).status, SpeechStatus.engineUnavailable);
      expect(_stateOf(container).error, SpeechError.modelLoadFailed);
      expect(_stateOf(container).platformMessage, 'model missing');
      expect(_stateOf(container).canChooseEngine, isTrue);

      await _controllerOf(container).selectEngine(engineName: _BURMESE_ENGINE);
      expect(_stateOf(container).status, SpeechStatus.ready);
      expect(_stateOf(container).error, isNull);
    });
  });

  group('selectEngine (Android)', () {
    test('an engine that rejects my-MM is reported as unavailable', () async {
      final ProviderContainer container =
          await _createDetectedContainer(system: FakeTtsService(engines: <String>[_GOOGLE]));

      await _controllerOf(container).selectEngine(engineName: _GOOGLE);

      expect(_stateOf(container).status, SpeechStatus.engineUnavailable);
      expect(_stateOf(container).error, SpeechError.languageUnavailable);
    });

    test('pitch is only supported by Android engines', () async {
      final ProviderContainer container = await _createDetectedContainer(system: _systemWithBurmese());
      expect(_stateOf(container).supportsPitch, isFalse);

      await _controllerOf(container).selectEngine(engineName: _BURMESE_ENGINE);
      expect(_stateOf(container).supportsPitch, isTrue);
    });
  });

  group('speak on-device', () {
    late FakeOnDeviceSpeaker onDevice;
    late ProviderContainer container;

    setUp(() async {
      onDevice = FakeOnDeviceSpeaker();
      container = await _createDetectedContainer(onDevice: onDevice);
    });

    test('speaks trimmed text at normal length scale by default', () async {
      await _controllerOf(container).speak(text: '  $_BURMESE_TEXT  ');

      expect(onDevice.spokenText, _BURMESE_TEXT);
      expect(onDevice.lengthScale, 1.0);
      expect(_stateOf(container).status, SpeechStatus.ready);
    });

    test('a faster speech rate shortens the audio', () async {
      _controllerOf(container).updateSpeechRate(rate: 1.0);
      await _controllerOf(container).speak(text: _BURMESE_TEXT);

      expect(onDevice.lengthScale, 0.5);
    });

    test('rejects Zawgyi-only or non-Burmese text inline', () async {
      await _controllerOf(container).speak(text: 'hello');

      expect(_stateOf(container).error, SpeechError.noSpeakableText);
      expect(onDevice.spokenText, isNull);
    });

    test('rejects blank text without calling the engine', () async {
      await _controllerOf(container).speak(text: '   ');

      expect(_stateOf(container).error, SpeechError.emptyText);
      expect(onDevice.spokenText, isNull);
    });

    test('rejects text longer than the input limit', () async {
      await _controllerOf(container).speak(text: 'က' * (TtsConfig.MAX_INPUT_LENGTH_FALLBACK + 1));

      expect(_stateOf(container).error, SpeechError.textTooLong);
    });

    test('stop ends speaking without an error', () async {
      onDevice.pendingSpeak = Completer<void>();
      final Future<void> speaking = _controllerOf(container).speak(text: _BURMESE_TEXT);
      await pumpEventQueue();
      expect(_stateOf(container).status, SpeechStatus.speaking);

      await _controllerOf(container).stop();
      await speaking;

      expect(onDevice.stopCallCount, 1);
      expect(_stateOf(container).status, SpeechStatus.ready);
      expect(_stateOf(container).error, isNull);
    });

    test('synthesis failure shows the platform message', () async {
      final ProviderContainer failing = await _createDetectedContainer(
        onDevice: FakeOnDeviceSpeaker(
          speakError: const MyanmarTtsException(operation: 'generateSpectrum', platformMessage: 'out of memory'),
        ),
      );

      await _controllerOf(failing).speak(text: _BURMESE_TEXT);

      expect(_stateOf(failing).error, SpeechError.speakFailed);
      expect(_stateOf(failing).platformMessage, 'out of memory');
      expect(_stateOf(failing).status, SpeechStatus.ready);
    });
  });

  group('speak with an Android engine', () {
    late FakeTtsService system;
    late ProviderContainer container;

    setUp(() async {
      system = FakeTtsService(
        engines: <String>[_BURMESE_ENGINE],
        burmeseEngines: <String>{_BURMESE_ENGINE},
        maxInputLength: 20,
      );
      container = await _createDetectedContainer(system: system);
      await _controllerOf(container).selectEngine(engineName: _BURMESE_ENGINE);
    });

    test('speaks with the chosen rate and pitch', () async {
      _controllerOf(container).updateSpeechRate(rate: 0.8);
      _controllerOf(container).updatePitch(pitch: 1.5);

      await _controllerOf(container).speak(text: _BURMESE_TEXT);

      expect(system.spokenText, _BURMESE_TEXT);
      expect(system.appliedRate, 0.8);
      expect(system.appliedPitch, 1.5);
      expect(_stateOf(container).status, SpeechStatus.ready);
    });

    test('uses the engine input limit', () async {
      await _controllerOf(container).speak(text: 'က' * 21);
      expect(_stateOf(container).error, SpeechError.textTooLong);

      await _controllerOf(container).speak(text: 'က' * 20);
      expect(_stateOf(container).error, isNull);
    });

    test('user stop is not reported as a failure', () async {
      system.pendingSpeak = Completer<bool>();
      final Future<void> speaking = _controllerOf(container).speak(text: _BURMESE_TEXT);
      await pumpEventQueue();

      await _controllerOf(container).stop();
      await speaking;

      expect(system.stopCallCount, 1);
      expect(_stateOf(container).error, isNull);
    });

    test('engine failure reports speakFailed with the platform message', () async {
      final FakeTtsService failingSystem = FakeTtsService(
        engines: <String>[_BURMESE_ENGINE],
        burmeseEngines: <String>{_BURMESE_ENGINE},
        failingOperation: 'speak',
      );
      final ProviderContainer failing = await _createDetectedContainer(system: failingSystem);
      await _controllerOf(failing).selectEngine(engineName: _BURMESE_ENGINE);

      await _controllerOf(failing).speak(text: _BURMESE_TEXT);

      expect(_stateOf(failing).error, SpeechError.speakFailed);
      expect(_stateOf(failing).platformMessage, 'speak failed');
    });
  });

  group('download', () {
    test('audio becomes downloadable after on-device speech finishes', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
      final FakeAudioFileSaver saver = FakeAudioFileSaver();
      final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice, saver: saver);
      expect(_stateOf(container).canDownload, isFalse);

      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      expect(_stateOf(container).canDownload, isTrue);

      final AudioSaveResult result = await _controllerOf(container).downloadAudio();
      expect(result.status, AudioSaveStatus.saved);
      expect(saver.savedWav, onDevice.spokenAudio);
      expect(saver.savedFileName, matches(RegExp(r'^myanmartts_\d{8}_\d{6}\.wav$')));
      expect(_stateOf(container).isSavingAudio, isFalse);
    });

    test('a stopped reading leaves nothing to download', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker()..pendingSpeak = Completer<void>();
      final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice);

      final Future<void> speaking = _controllerOf(container).speak(text: _BURMESE_TEXT);
      await pumpEventQueue();
      await _controllerOf(container).stop();
      await speaking;

      expect(_stateOf(container).hasDownloadableAudio, isFalse);
    });

    test('editing the text or switching engine discards the audio', () async {
      final ProviderContainer container = await _createDetectedContainer(system: _systemWithBurmese());
      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      _controllerOf(container).discardGeneratedAudio();
      expect(_stateOf(container).hasDownloadableAudio, isFalse);

      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      await _controllerOf(container).selectEngine(engineName: _BURMESE_ENGINE);
      expect(_stateOf(container).hasDownloadableAudio, isFalse);
      expect(_stateOf(container).supportsDownload, isFalse);
    });

    test('a cancelled save dialog is reported as cancelled', () async {
      final ProviderContainer container =
          await _createDetectedContainer(saver: FakeAudioFileSaver(isCancelled: true));
      await _controllerOf(container).speak(text: _BURMESE_TEXT);

      final AudioSaveResult result = await _controllerOf(container).downloadAudio();

      expect(result.status, AudioSaveStatus.cancelled);
      expect(_stateOf(container).canDownload, isTrue, reason: 'the user can try again');
    });

    test('a failed save keeps the platform message', () async {
      final ProviderContainer container = await _createDetectedContainer(
        saver: FakeAudioFileSaver(error: const AudioSaveException(platformMessage: 'disk full')),
      );
      await _controllerOf(container).speak(text: _BURMESE_TEXT);

      final AudioSaveResult result = await _controllerOf(container).downloadAudio();

      expect(result.status, AudioSaveStatus.failed);
      expect(result.platformMessage, 'disk full');
    });
  });
}
