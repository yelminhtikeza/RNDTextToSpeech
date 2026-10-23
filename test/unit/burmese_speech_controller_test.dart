import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/config/myanmartts_config.dart';
import 'package:rnd_text_to_speech/config/tts_config.dart';
import 'package:rnd_text_to_speech/models/audio_save_result.dart';
import 'package:rnd_text_to_speech/models/burmese_speech_state.dart';
import 'package:rnd_text_to_speech/models/engine_voice.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/providers/burmese_speech_controller.dart';
import 'package:rnd_text_to_speech/providers/voice_controller.dart';
import 'package:rnd_text_to_speech/services/audio_file_saver.dart';
import 'package:rnd_text_to_speech/services/audio_output.dart';

import '../support/fake_audio_file_saver.dart';
import '../support/fake_on_device_speaker.dart';
import '../support/fake_tts_service.dart';
import '../support/fake_voice_library.dart';

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
      voiceLibraryProvider.overrideWithValue(FakeVoiceLibrary()),
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
      languagesByEngine: <String, List<String>>{
        _GOOGLE: <String>['fr-FR', 'en-US'],
        _BURMESE_ENGINE: <String>['en-US', 'my'],
      },
    );

void main() {
  group('detectEngines', () {
    test('lists the on-device engine first, then every Android engine unfiltered', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
      final ProviderContainer container =
          await _createDetectedContainer(system: _systemWithBurmese(), onDevice: onDevice);

      expect(_stateOf(container).engines, <String>[_ON_DEVICE, _GOOGLE, _BURMESE_ENGINE]);
      expect(_stateOf(container).selectedEngine, _ON_DEVICE);
      expect(_stateOf(container).status, SpeechStatus.ready);
      expect(onDevice.loadCallCount, 1);
    });

    test('the on-device engine offers Burmese only', () async {
      final ProviderContainer container = await _createDetectedContainer(system: _systemWithBurmese());

      expect(_stateOf(container).languages, <String>[TtsConfig.BURMESE_LANGUAGE_TAG]);
      expect(_stateOf(container).selectedLanguage, TtsConfig.BURMESE_LANGUAGE_TAG);
      expect(_stateOf(container).canChooseLanguage, isFalse);
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
    test('lists the engine languages sorted and prefers Burmese', () async {
      final FakeTtsService system = _systemWithBurmese();
      final ProviderContainer container = await _createDetectedContainer(system: system);

      await _controllerOf(container).selectEngine(engineName: _BURMESE_ENGINE);

      expect(_stateOf(container).languages, <String>['en-US', 'my']);
      expect(_stateOf(container).selectedLanguage, 'my');
      expect(system.activeLanguage, 'my');
      expect(_stateOf(container).canChooseLanguage, isTrue);
      expect(_stateOf(container).status, SpeechStatus.ready);
    });

    test('an engine without Burmese defaults to its first language', () async {
      final FakeTtsService system = _systemWithBurmese();
      final ProviderContainer container = await _createDetectedContainer(system: system);

      await _controllerOf(container).selectEngine(engineName: _GOOGLE);

      expect(_stateOf(container).languages, <String>['en-US', 'fr-FR']);
      expect(_stateOf(container).selectedLanguage, 'en-US');
      expect(system.activeLanguage, 'en-US');
      expect(_stateOf(container).canSpeak, isTrue);
    });

    test('the user can choose any language the engine supports', () async {
      final FakeTtsService system = _systemWithBurmese();
      final ProviderContainer container = await _createDetectedContainer(system: system);
      await _controllerOf(container).selectEngine(engineName: _GOOGLE);

      await _controllerOf(container).selectLanguage(languageTag: 'fr-FR');

      expect(_stateOf(container).selectedLanguage, 'fr-FR');
      expect(system.activeLanguage, 'fr-FR');
      expect(_stateOf(container).status, SpeechStatus.ready);
    });

    test('a language the engine cannot load is reported and another can be chosen', () async {
      final FakeTtsService system = FakeTtsService(
        engines: <String>[_GOOGLE],
        languagesByEngine: <String, List<String>>{_GOOGLE: <String>['en-US', 'fr-FR']},
        rejectedLanguages: <String>{'fr-FR'},
      );
      final ProviderContainer container = await _createDetectedContainer(system: system);
      await _controllerOf(container).selectEngine(engineName: _GOOGLE);

      await _controllerOf(container).selectLanguage(languageTag: 'fr-FR');
      expect(_stateOf(container).status, SpeechStatus.engineUnavailable);
      expect(_stateOf(container).error, SpeechError.languageUnavailable);
      expect(_stateOf(container).canChooseLanguage, isTrue);

      await _controllerOf(container).selectLanguage(languageTag: 'en-US');
      expect(_stateOf(container).status, SpeechStatus.ready);
      expect(_stateOf(container).error, isNull);
    });

    test('an engine that reports no languages is unavailable and keeps no stale language', () async {
      final ProviderContainer container =
          await _createDetectedContainer(system: FakeTtsService(engines: <String>[_GOOGLE]));

      await _controllerOf(container).selectEngine(engineName: _GOOGLE);

      expect(_stateOf(container).status, SpeechStatus.engineUnavailable);
      expect(_stateOf(container).error, SpeechError.noLanguages);
      expect(_stateOf(container).languages, isEmpty);
      expect(_stateOf(container).selectedLanguage, isNull);
    });

    test('a failing language query keeps the platform message', () async {
      final ProviderContainer container = await _createDetectedContainer(
        system: FakeTtsService(engines: <String>[_GOOGLE], failingOperation: 'getLanguages'),
      );

      await _controllerOf(container).selectEngine(engineName: _GOOGLE);

      expect(_stateOf(container).error, SpeechError.noLanguages);
      expect(_stateOf(container).platformMessage, 'getLanguages failed');
    });

    test('switching back to the on-device engine restores Burmese', () async {
      final ProviderContainer container = await _createDetectedContainer(system: _systemWithBurmese());
      await _controllerOf(container).selectEngine(engineName: _GOOGLE);

      await _controllerOf(container).selectEngine(engineName: _ON_DEVICE);

      expect(_stateOf(container).languages, <String>[TtsConfig.BURMESE_LANGUAGE_TAG]);
      expect(_stateOf(container).selectedLanguage, TtsConfig.BURMESE_LANGUAGE_TAG);
    });

    test('selectLanguage is ignored for the on-device engine', () async {
      final FakeTtsService system = _systemWithBurmese();
      final ProviderContainer container = await _createDetectedContainer(system: system);

      await _controllerOf(container).selectLanguage(languageTag: 'en-US');

      expect(_stateOf(container).selectedLanguage, TtsConfig.BURMESE_LANGUAGE_TAG);
      expect(system.activeLanguage, isNull);
    });

    test('pitch is only supported by Android engines', () async {
      final ProviderContainer container = await _createDetectedContainer(system: _systemWithBurmese());
      expect(_stateOf(container).supportsPitch, isFalse);

      await _controllerOf(container).selectEngine(engineName: _BURMESE_ENGINE);
      expect(_stateOf(container).supportsPitch, isTrue);
      expect(_stateOf(container).supportsQualityControls, isFalse);
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
      expect(onDevice.settings!.lengthScale, 1.0);
      expect(onDevice.settings!.flowSteps, MyanmarTtsConfig.FLOW_STEPS_DEFAULT);
      expect(onDevice.settings!.cfgStrength, MyanmarTtsConfig.CFG_STRENGTH_DEFAULT);
      expect(_stateOf(container).status, SpeechStatus.ready);
    });

    test('a faster speech rate shortens the audio', () async {
      _controllerOf(container).updateSpeechRate(rate: 1.0);
      await _controllerOf(container).speak(text: _BURMESE_TEXT);

      expect(onDevice.settings!.lengthScale, 0.5);
    });

    test('uses the chosen steps and CFG', () async {
      _controllerOf(container).updateFlowSteps(steps: 8);
      _controllerOf(container).updateCfgStrength(cfgStrength: 4.5);
      await _controllerOf(container).speak(text: _BURMESE_TEXT);

      expect(onDevice.settings!.flowSteps, 8);
      expect(onDevice.settings!.cfgStrength, 4.5);
    });

    test('changing steps or CFG keeps the already spoken audio downloadable', () async {
      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      _controllerOf(container).updateFlowSteps(steps: 32);
      _controllerOf(container).updateCfgStrength(cfgStrength: 1.0);

      expect(_stateOf(container).hasDownloadableAudio, isTrue);
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
        languagesByEngine: <String, List<String>>{_BURMESE_ENGINE: <String>['my-MM']},
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
        languagesByEngine: <String, List<String>>{_BURMESE_ENGINE: <String>['my-MM']},
        failingOperation: 'speak',
      );
      final ProviderContainer failing = await _createDetectedContainer(system: failingSystem);
      await _controllerOf(failing).selectEngine(engineName: _BURMESE_ENGINE);

      await _controllerOf(failing).speak(text: _BURMESE_TEXT);

      expect(_stateOf(failing).error, SpeechError.speakFailed);
      expect(_stateOf(failing).platformMessage, 'speak failed');
    });
  });

  group('audio export from Android engines (rendered on demand)', () {
    late FakeTtsService system;
    late FakeOnDeviceSpeaker onDevice;
    late ProviderContainer container;

    Future<void> useEngine({required Set<String> exporting, String? failingOperation}) async {
      system = FakeTtsService(
        engines: <String>[_GOOGLE],
        languagesByEngine: <String, List<String>>{_GOOGLE: <String>['en-US']},
        exportingEngines: exporting,
        failingOperation: failingOperation,
      );
      onDevice = FakeOnDeviceSpeaker();
      container = await _createDetectedContainer(system: system, onDevice: onDevice);
      await _controllerOf(container).selectEngine(engineName: _GOOGLE);
    }

    test('speaks aloud immediately and renders nothing until Play or Download is used', () async {
      await useEngine(exporting: <String>{_GOOGLE});

      await _controllerOf(container).speak(text: 'hello');

      expect(system.speakCallCount, 1);
      expect(system.synthesizeCallCount, 0, reason: 'no double work unless the user asks');
      expect(_stateOf(container).hasRenderableSpeech, isTrue);
      expect(_stateOf(container).canReplay, isTrue);
      expect(_stateOf(container).canDownload, isTrue);
      expect(_stateOf(container).waveform.isEmpty, isTrue);
    });

    test('Play renders the file once with the settings that were heard, then plays it', () async {
      await useEngine(exporting: <String>{_GOOGLE});
      _controllerOf(container).updatePitch(pitch: 1.5);
      await _controllerOf(container).speak(text: 'hello');
      _controllerOf(container).updatePitch(pitch: 0.7);

      await _controllerOf(container).replayGeneratedAudio();
      await _controllerOf(container).replayGeneratedAudio();

      expect(system.synthesizeCallCount, 1, reason: 'the rendered file is reused');
      expect(system.appliedPitch, 1.5, reason: 'renders what was heard, not the moved slider');
      expect(onDevice.replayed, hasLength(2));
      expect(_stateOf(container).waveform.duration, const Duration(seconds: 1));
      expect(_stateOf(container).isPreparingAudio, isFalse);
    });

    test('Download renders the file and saves it', () async {
      final FakeAudioFileSaver saver = FakeAudioFileSaver();
      system = FakeTtsService(
        engines: <String>[_GOOGLE],
        languagesByEngine: <String, List<String>>{_GOOGLE: <String>['en-US']},
        exportingEngines: <String>{_GOOGLE},
      );
      container = await _createDetectedContainer(system: system, saver: saver);
      await _controllerOf(container).selectEngine(engineName: _GOOGLE);
      await _controllerOf(container).speak(text: 'hello');

      final AudioSaveResult result = await _controllerOf(container).downloadAudio();

      expect(result.status, AudioSaveStatus.saved);
      expect(saver.savedWav, FakeTtsService.exportedAudio.wav);
      expect(_stateOf(container).isSavingAudio, isFalse);
    });

    test('an engine that cannot write files explains why and is remembered', () async {
      await useEngine(exporting: const <String>{});
      await _controllerOf(container).speak(text: 'hello');

      await _controllerOf(container).replayGeneratedAudio();

      expect(_stateOf(container).error, SpeechError.audioUnavailable);
      expect(_stateOf(container).supportsDownload, isFalse);
      expect(_stateOf(container).canReplay, isFalse);
      expect(onDevice.replayed, isEmpty);

      await _controllerOf(container).speak(text: 'hello');
      expect(_stateOf(container).hasRenderableSpeech, isFalse, reason: 'no Play offered again for this engine');
    });

    test('Download on an engine that cannot write files reports unavailable', () async {
      await useEngine(exporting: const <String>{}, failingOperation: 'synthesizeToFile');
      await _controllerOf(container).speak(text: 'hello');

      final AudioSaveResult result = await _controllerOf(container).downloadAudio();

      expect(result.status, AudioSaveStatus.unavailable);
      expect(_stateOf(container).error, SpeechError.audioUnavailable);
    });

    test('a stopped reading offers nothing to replay or render', () async {
      await useEngine(exporting: <String>{_GOOGLE});
      system.pendingSpeak = Completer<bool>();
      final Future<void> speaking = _controllerOf(container).speak(text: 'hello');
      await pumpEventQueue();

      await _controllerOf(container).stop();
      await speaking;

      expect(_stateOf(container).hasPlayableAudio, isFalse);
      expect(system.synthesizeCallCount, 0);
    });

    test('editing the text while rendering cancels it without marking the engine unsupported', () async {
      await useEngine(exporting: <String>{_GOOGLE});
      await _controllerOf(container).speak(text: 'hello');
      system.pendingSynthesis = Completer<void>();
      final Future<void> replaying = _controllerOf(container).replayGeneratedAudio();
      await pumpEventQueue();
      expect(_stateOf(container).isPreparingAudio, isTrue);

      _controllerOf(container).discardGeneratedAudio();
      await replaying;

      expect(system.stopCallCount, 1, reason: 'the engine stops rendering');
      expect(_stateOf(container).isPreparingAudio, isFalse);
      expect(_stateOf(container).hasPlayableAudio, isFalse);
      expect(_stateOf(container).supportsDownload, isTrue);
      expect(_stateOf(container).error, isNull);
      expect(onDevice.replayed, isEmpty);
    });

    test('rendered engine audio can be paused and stopped through the app player', () async {
      await useEngine(exporting: <String>{_GOOGLE});
      await _controllerOf(container).speak(text: 'hello');
      onDevice.pendingReplay = Completer<void>();
      final Future<void> replaying = _controllerOf(container).replayGeneratedAudio();
      await pumpEventQueue();
      expect(_stateOf(container).isReplaying, isTrue);

      await _controllerOf(container).togglePause();
      expect(onDevice.controls, <String>['pause']);

      await _controllerOf(container).stop();
      await replaying;
      expect(onDevice.stopCallCount, 1);
      expect(_stateOf(container).canDownload, isTrue, reason: 'stopping playback keeps the rendered audio');
    });
  });

  group('Android engine voices', () {
    const EngineVoice usLocal = EngineVoice(name: 'en-us-x-b', locale: 'en-US', requiresNetwork: false);
    const EngineVoice usNetwork = EngineVoice(name: 'en-us-x-a', locale: 'en-US', requiresNetwork: true);
    const EngineVoice french = EngineVoice(name: 'fr-fr-x-a', locale: 'fr-FR', requiresNetwork: false);
    late FakeTtsService system;
    late ProviderContainer container;

    Future<void> useEngine({Set<String> rejected = const <String>{}, String? failingOperation}) async {
      system = FakeTtsService(
        engines: <String>[_GOOGLE],
        languagesByEngine: <String, List<String>>{_GOOGLE: <String>['en-US', 'fr-FR']},
        voicesByEngine: <String, List<EngineVoice>>{_GOOGLE: <EngineVoice>[usLocal, french, usNetwork]},
        exportingEngines: <String>{_GOOGLE},
        rejectedVoices: rejected,
        failingOperation: failingOperation,
      );
      container = await _createDetectedContainer(system: system);
      await _controllerOf(container).selectEngine(engineName: _GOOGLE);
    }

    test('lists the voices of the selected language by name, with the engine default selected', () async {
      await useEngine();

      expect(_stateOf(container).engineVoices, <EngineVoice>[usNetwork, usLocal]);
      expect(_stateOf(container).selectedEngineVoice, TtsConfig.ENGINE_DEFAULT_VOICE_ID);
      expect(_stateOf(container).canChooseEngineVoice, isTrue);

      await _controllerOf(container).selectLanguage(languageTag: 'fr-FR');
      expect(_stateOf(container).engineVoices, <EngineVoice>[french]);
      expect(_stateOf(container).selectedEngineVoice, TtsConfig.ENGINE_DEFAULT_VOICE_ID);
    });

    test('speaks and renders with the chosen voice', () async {
      await useEngine();
      await _controllerOf(container).selectEngineVoice(voiceId: usLocal.name);

      await _controllerOf(container).speak(text: 'hello');
      await _controllerOf(container).replayGeneratedAudio();

      expect(system.voiceWhenSpoken, usLocal.name);
      expect(system.voiceWhenSynthesized, usLocal.name);
    });

    test('choosing Default goes back to the engine voice', () async {
      await useEngine();
      await _controllerOf(container).selectEngineVoice(voiceId: usLocal.name);
      await _controllerOf(container).selectEngineVoice(voiceId: TtsConfig.ENGINE_DEFAULT_VOICE_ID);

      await _controllerOf(container).speak(text: 'hello');

      expect(system.voiceWhenSpoken, isNull);
    });

    test('changing the voice discards audio made with the previous voice', () async {
      await useEngine();
      await _controllerOf(container).speak(text: 'hello');
      expect(_stateOf(container).hasPlayableAudio, isTrue);

      await _controllerOf(container).selectEngineVoice(voiceId: usLocal.name);

      expect(_stateOf(container).hasPlayableAudio, isFalse);
    });

    test('a rejected voice falls back to Default and says why without blocking Speak', () async {
      await useEngine(rejected: <String>{usNetwork.name});

      await _controllerOf(container).selectEngineVoice(voiceId: usNetwork.name);

      expect(_stateOf(container).error, SpeechError.engineVoiceUnavailable);
      expect(_stateOf(container).selectedEngineVoice, TtsConfig.ENGINE_DEFAULT_VOICE_ID);
      expect(_stateOf(container).canSpeak, isTrue);
    });

    test('a failing voice list leaves only the engine default', () async {
      await useEngine(failingOperation: 'getVoices');

      expect(_stateOf(container).supportsEngineVoices, isFalse);
      expect(_stateOf(container).status, SpeechStatus.ready);
    });

    test('MyanmarTTS does not show engine voices', () async {
      await useEngine();
      await _controllerOf(container).selectEngine(engineName: _ON_DEVICE);

      expect(_stateOf(container).supportsEngineVoices, isFalse);
      expect(_stateOf(container).supportsVoices, isTrue);
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
      // 0.5 s × 20 bar/s
      expect(_stateOf(container).waveform.peaks, hasLength(10));
      expect(_stateOf(container).waveform.duration, const Duration(milliseconds: 500));

      final AudioSaveResult result = await _controllerOf(container).downloadAudio();
      expect(result.status, AudioSaveStatus.saved);
      expect(saver.savedWav, onDevice.spokenAudio);
      expect(saver.savedFileName, matches(RegExp(r'^speech_\d{8}_\d{6}\.wav$')));
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
      expect(_stateOf(container).waveform.isEmpty, isTrue);
    });

    test('editing the text or switching engine discards the audio', () async {
      final ProviderContainer container = await _createDetectedContainer(system: _systemWithBurmese());
      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      _controllerOf(container).discardGeneratedAudio();
      expect(_stateOf(container).hasDownloadableAudio, isFalse);
      expect(_stateOf(container).waveform.isEmpty, isTrue);

      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      await _controllerOf(container).selectEngine(engineName: _BURMESE_ENGINE);
      expect(_stateOf(container).hasDownloadableAudio, isFalse);
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

  group('replay', () {
    test('replays the stored audio without generating it again', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
      final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice);
      expect(_stateOf(container).canReplay, isFalse);

      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      onDevice.spokenText = null;
      await _controllerOf(container).replayGeneratedAudio();

      expect(onDevice.replayed, <Object>[onDevice.spokenAudio]);
      expect(onDevice.spokenText, isNull, reason: 'replay must not run the model');
      expect(_stateOf(container).status, SpeechStatus.ready);
      expect(_stateOf(container).canReplay, isTrue, reason: 'can replay again');
    });

    test('is replaying while audio plays and Stop ends it', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
      final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice);
      await _controllerOf(container).speak(text: _BURMESE_TEXT);

      onDevice.pendingReplay = Completer<void>();
      final Future<void> replaying = _controllerOf(container).replayGeneratedAudio();
      await pumpEventQueue();
      expect(_stateOf(container).isReplaying, isTrue);
      expect(_stateOf(container).isPlayingAudio, isTrue);
      expect(_stateOf(container).canSpeak, isFalse);
      expect(_stateOf(container).canChooseEngine, isFalse);

      await _controllerOf(container).stop();
      await replaying;

      expect(_stateOf(container).status, SpeechStatus.ready);
      expect(_stateOf(container).error, isNull);
      expect(_stateOf(container).hasDownloadableAudio, isTrue, reason: 'stopping a replay keeps the audio');
    });

    test('the waveform appears while speaking, before the audio is complete', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker()..pendingSpeak = Completer<void>();
      final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice);

      final Future<void> speaking = _controllerOf(container).speak(text: _BURMESE_TEXT);
      await pumpEventQueue();

      expect(_stateOf(container).isSpeaking, isTrue);
      expect(_stateOf(container).waveform.isEmpty, isFalse);
      expect(_stateOf(container).canSeek, isFalse, reason: 'later chunks do not exist yet');
      onDevice.pendingSpeak!.complete();
      await speaking;
    });

    test('tracks the playback position in steps and resets it when playback ends', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
      final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice);
      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      onDevice.pendingReplay = Completer<void>();
      final Future<void> replaying = _controllerOf(container).replayGeneratedAudio();
      await pumpEventQueue();

      onDevice.positions.add(const Duration(milliseconds: 200));
      await pumpEventQueue();
      expect(_stateOf(container).playbackPosition, const Duration(milliseconds: 200));

      onDevice.positions.add(const Duration(milliseconds: 230));
      await pumpEventQueue();
      expect(_stateOf(container).playbackPosition, const Duration(milliseconds: 200),
          reason: 'changes smaller than the step do not rebuild the screen');

      onDevice.pendingReplay!.complete();
      await replaying;
      expect(_stateOf(container).playbackPosition, Duration.zero);
    });

    test('pause and resume toggle the player', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
      final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice);
      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      onDevice.pendingReplay = Completer<void>();
      final Future<void> replaying = _controllerOf(container).replayGeneratedAudio();
      await pumpEventQueue();

      await _controllerOf(container).togglePause();
      expect(_stateOf(container).isPaused, isTrue);
      expect(_stateOf(container).isReplaying, isTrue, reason: 'Stop stays available while paused');
      await _controllerOf(container).togglePause();
      expect(_stateOf(container).isPaused, isFalse);
      expect(onDevice.controls, <String>['pause', 'resume']);

      await _controllerOf(container).togglePause();
      await _controllerOf(container).stop();
      await replaying;
      expect(_stateOf(container).isPaused, isFalse);
    });

    test('seeking while replaying moves the player; seeking while idle starts from there', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
      final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice);
      await _controllerOf(container).speak(text: _BURMESE_TEXT);

      onDevice.pendingReplay = Completer<void>();
      final Future<void> replaying = _controllerOf(container).seekGeneratedAudio(fraction: 0.5);
      await pumpEventQueue();
      expect(onDevice.replayStarts, <Duration>[const Duration(milliseconds: 250)]);

      await _controllerOf(container).seekGeneratedAudio(fraction: 0.2);
      expect(onDevice.seeks, <Duration>[const Duration(milliseconds: 100)]);
      expect(_stateOf(container).playbackPosition, const Duration(milliseconds: 100));

      await _controllerOf(container).stop();
      await replaying;
    });

    test('a failing pause shows the platform message without stopping playback', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker()
        ..controlError = const AudioOutputException(operation: 'pause', platformMessage: 'player released');
      final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice);
      await _controllerOf(container).speak(text: _BURMESE_TEXT);
      onDevice.pendingReplay = Completer<void>();
      final Future<void> replaying = _controllerOf(container).replayGeneratedAudio();
      await pumpEventQueue();

      await _controllerOf(container).togglePause();

      expect(_stateOf(container).platformMessage, 'player released');
      expect(_stateOf(container).isReplaying, isTrue);
      expect(_stateOf(container).isPaused, isFalse);
      await _controllerOf(container).stop();
      await replaying;
    });

    test('Android engines cannot be paused', () async {
      final FakeTtsService system = FakeTtsService(
        engines: <String>[_BURMESE_ENGINE],
        languagesByEngine: <String, List<String>>{_BURMESE_ENGINE: <String>['my-MM']},
      )..pendingSpeak = Completer<bool>();
      final ProviderContainer container = await _createDetectedContainer(system: system);
      await _controllerOf(container).selectEngine(engineName: _BURMESE_ENGINE);
      final Future<void> speaking = _controllerOf(container).speak(text: _BURMESE_TEXT);
      await pumpEventQueue();

      expect(_stateOf(container).canPause, isFalse);
      await _controllerOf(container).stop();
      await speaking;
    });

    test('does nothing when there is no generated audio', () async {
      final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
      final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice);

      await _controllerOf(container).replayGeneratedAudio();

      expect(onDevice.replayed, isEmpty);
      expect(_stateOf(container).status, SpeechStatus.ready);
    });

    test('a playback failure shows the platform message', () async {
      final ProviderContainer container = await _createDetectedContainer(
        onDevice: FakeOnDeviceSpeaker(
          replayError: const AudioOutputException(operation: 'play', platformMessage: 'audio focus lost'),
        ),
      );
      await _controllerOf(container).speak(text: _BURMESE_TEXT);

      await _controllerOf(container).replayGeneratedAudio();

      expect(_stateOf(container).error, SpeechError.speakFailed);
      expect(_stateOf(container).platformMessage, 'audio focus lost');
      expect(_stateOf(container).status, SpeechStatus.ready);
    });
  });

  test('speaks with the selected voice', () async {
    final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
    final ProviderContainer container = await _createDetectedContainer(onDevice: onDevice);
    expect(_stateOf(container).supportsVoices, isTrue);

    await _controllerOf(container).speak(text: _BURMESE_TEXT);
    expect(onDevice.settings!.speaker, FakeVoiceLibrary.original.embedding, reason: 'default is the first preset');

    container.read(voiceControllerProvider.notifier).selectVoice(voiceId: 'male_3');
    await _controllerOf(container).speak(text: _BURMESE_TEXT);
    expect(onDevice.settings!.speaker, FakeVoiceLibrary.male.embedding);
  });
}
