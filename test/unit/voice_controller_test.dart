import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/models/voice_profile.dart';
import 'package:rnd_text_to_speech/models/voice_state.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/providers/burmese_speech_controller.dart';
import 'package:rnd_text_to_speech/providers/voice_controller.dart';
import 'package:rnd_text_to_speech/services/voice_library.dart';

import '../support/fake_on_device_speaker.dart';
import '../support/fake_voice_library.dart';
import '../support/fake_voice_recorder.dart';

Future<ProviderContainer> _createLoadedContainer({
  FakeVoiceLibrary? library,
  FakeOnDeviceSpeaker? speaker,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      voiceLibraryProvider.overrideWithValue(library ?? FakeVoiceLibrary()),
      onDeviceSpeakerProvider.overrideWithValue(speaker ?? FakeOnDeviceSpeaker()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(voiceControllerProvider.notifier).ensureLoaded();
  return container;
}

VoiceState _stateOf(ProviderContainer container) => container.read(voiceControllerProvider);

VoiceController _controllerOf(ProviderContainer container) => container.read(voiceControllerProvider.notifier);

void main() {
  test('loads presets then custom voices and selects the first preset', () async {
    final VoiceProfile custom = VoiceProfile(
      id: 'custom_1',
      labelEn: 'Ko Ko',
      labelMy: 'Ko Ko',
      embedding: FakeVoiceLibrary.male.embedding,
      isCustom: true,
    );
    final ProviderContainer container =
        await _createLoadedContainer(library: FakeVoiceLibrary(customVoices: <VoiceProfile>[custom]));

    expect(_stateOf(container).isReady, isTrue);
    expect(_stateOf(container).voices.map((VoiceProfile v) => v.id), <String>['original', 'male_3', 'custom_1']);
    expect(_stateOf(container).selectedVoice?.id, 'original');
  });

  test('reports a load failure with the platform message', () async {
    final ProviderContainer container = await _createLoadedContainer(
      library: FakeVoiceLibrary(loadError: const VoiceLibraryException(operation: 'loadPresets', platformMessage: 'asset missing')),
    );
    expect(_stateOf(container).status, VoiceLibraryStatus.failed);
    expect(_stateOf(container).platformMessage, 'asset missing');
  });

  test('selecting a voice changes the selected embedding', () async {
    final ProviderContainer container = await _createLoadedContainer();
    _controllerOf(container).selectVoice(voiceId: 'male_3');
    expect(_stateOf(container).selectedVoice?.embedding, FakeVoiceLibrary.male.embedding);
  });

  group('addRecordedVoice', () {
    test('creates, saves and selects a custom voice from the recording', () async {
      final FakeVoiceLibrary library = FakeVoiceLibrary();
      final FakeOnDeviceSpeaker speaker = FakeOnDeviceSpeaker();
      final ProviderContainer container = await _createLoadedContainer(library: library, speaker: speaker);

      final VoiceChangeResult result = await _controllerOf(container)
          .addRecordedVoice(name: 'Ma Ma', wav: FakeVoiceRecorder.wavOf(seconds: 6, sampleRate: 48000));

      expect(result.status, VoiceChangeStatus.done);
      expect(speaker.embeddingRequests.single, (samples: 6 * 48000, sampleRate: 48000));
      final VoiceProfile selected = _stateOf(container).selectedVoice!;
      expect(selected.isCustom, isTrue);
      expect(selected.labelEn, 'Ma Ma');
      expect(selected.embedding, speaker.createdEmbedding);
      expect(library.savedCustomVoices.map((VoiceProfile v) => v.id), <String>[selected.id],
          reason: 'only custom voices are written to storage');
    });

    test('rejects a recording shorter than the minimum without computing an embedding', () async {
      final FakeOnDeviceSpeaker speaker = FakeOnDeviceSpeaker();
      final ProviderContainer container = await _createLoadedContainer(speaker: speaker);

      final VoiceChangeResult result = await _controllerOf(container)
          .addRecordedVoice(name: 'Short', wav: FakeVoiceRecorder.wavOf(seconds: 3, sampleRate: 44100));

      expect(result.status, VoiceChangeStatus.tooShort);
      expect(speaker.embeddingRequests, isEmpty);
    });

    test('a broken WAV, a model failure or a save failure is reported and nothing is added', () async {
      final FakeOnDeviceSpeaker failingSpeaker = FakeOnDeviceSpeaker()
        ..embeddingError = const MyanmarTtsException(operation: 'embedSpeaker', platformMessage: 'ort failed');
      final ProviderContainer container = await _createLoadedContainer(
        speaker: failingSpeaker,
        library: FakeVoiceLibrary(saveError: const VoiceLibraryException(operation: 'save', platformMessage: 'disk full')),
      );
      final VoiceController controller = _controllerOf(container);

      final VoiceChangeResult badWav = await controller.addRecordedVoice(name: 'X', wav: FakeVoiceRecorder.wavOf(seconds: 0, sampleRate: 8000).sublist(0, 20));
      final VoiceChangeResult modelFailed =
          await controller.addRecordedVoice(name: 'X', wav: FakeVoiceRecorder.wavOf(seconds: 6, sampleRate: 16000));

      expect(badWav.status, VoiceChangeStatus.failed);
      expect(modelFailed.status, VoiceChangeStatus.failed);
      expect(modelFailed.platformMessage, 'ort failed');
      expect(_stateOf(container).voices, hasLength(2));

      failingSpeaker.embeddingError = null;
      final VoiceChangeResult saveFailed =
          await controller.addRecordedVoice(name: 'X', wav: FakeVoiceRecorder.wavOf(seconds: 6, sampleRate: 16000));
      expect(saveFailed.platformMessage, 'disk full');
      expect(_stateOf(container).voices, hasLength(2));
    });
  });

  group('deleteVoice', () {
    test('removes a custom voice and falls back to the default when it was selected', () async {
      final FakeVoiceLibrary library = FakeVoiceLibrary();
      final ProviderContainer container = await _createLoadedContainer(library: library);
      await _controllerOf(container)
          .addRecordedVoice(name: 'Mine', wav: FakeVoiceRecorder.wavOf(seconds: 6, sampleRate: 44100));
      final String customId = _stateOf(container).selectedVoiceId!;

      final VoiceChangeResult result = await _controllerOf(container).deleteVoice(voiceId: customId);

      expect(result.status, VoiceChangeStatus.done);
      expect(_stateOf(container).voices, hasLength(2));
      expect(_stateOf(container).selectedVoiceId, 'original');
      expect(library.savedCustomVoices, isEmpty);
    });

    test('presets cannot be deleted', () async {
      final ProviderContainer container = await _createLoadedContainer();
      await _controllerOf(container).deleteVoice(voiceId: 'male_3');
      expect(_stateOf(container).voices, hasLength(2));
    });
  });
}
