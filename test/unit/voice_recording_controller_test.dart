import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/models/voice_recording_state.dart';
import 'package:rnd_text_to_speech/providers/burmese_speech_controller.dart';
import 'package:rnd_text_to_speech/providers/voice_controller.dart';
import 'package:rnd_text_to_speech/providers/voice_recording_controller.dart';
import 'package:rnd_text_to_speech/services/voice_recorder.dart';

import '../support/fake_on_device_speaker.dart';
import '../support/fake_voice_library.dart';
import '../support/fake_voice_recorder.dart';

Future<ProviderContainer> _create({required FakeVoiceRecorder recorder}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      voiceRecorderProvider.overrideWithValue(recorder),
      voiceLibraryProvider.overrideWithValue(FakeVoiceLibrary()),
      onDeviceSpeakerProvider.overrideWithValue(FakeOnDeviceSpeaker()),
    ],
  );
  addTearDown(container.dispose);
  // autoDispose provider ကို test တစ်လျှောက် ရှင်သန်စေရန်။
  container.listen(voiceRecordingControllerProvider, (_, _) {});
  await container.read(voiceControllerProvider.notifier).ensureLoaded();
  return container;
}

VoiceRecordingState _stateOf(ProviderContainer c) => c.read(voiceRecordingControllerProvider);

VoiceRecordingController _controllerOf(ProviderContainer c) => c.read(voiceRecordingControllerProvider.notifier);

void main() {
  test('records, names and saves a voice, selecting it', () async {
    final FakeVoiceRecorder recorder = FakeVoiceRecorder();
    final ProviderContainer container = await _create(recorder: recorder);

    await _controllerOf(container).startRecording();
    expect(_stateOf(container).isRecording, isTrue);
    await _controllerOf(container).stopRecording();
    expect(_stateOf(container).phase, RecordingPhase.recorded);
    expect(_stateOf(container).elapsed, const Duration(seconds: 6), reason: 'length comes from the WAV itself');

    expect(await _controllerOf(container).saveVoice(name: '  Ko Ko  '), isTrue);
    expect(container.read(voiceControllerProvider).selectedVoice?.labelEn, 'Ko Ko');
    expect(_stateOf(container).phase, RecordingPhase.idle);
  });

  test('denied microphone permission is reported and recording does not start', () async {
    final FakeVoiceRecorder recorder = FakeVoiceRecorder(hasPermission: false);
    final ProviderContainer container = await _create(recorder: recorder);

    await _controllerOf(container).startRecording();

    expect(_stateOf(container).error, RecordingError.permissionDenied);
    expect(recorder.startCallCount, 0);
  });

  test('a recording shorter than the minimum is rejected right after stopping', () async {
    final ProviderContainer container = await _create(recorder: FakeVoiceRecorder(recordedSeconds: 2));

    await _controllerOf(container).startRecording();
    await _controllerOf(container).stopRecording();

    expect(_stateOf(container).error, RecordingError.tooShort);
    expect(_stateOf(container).hasRecording, isFalse);
  });

  test('an empty name keeps the recording and asks for a name', () async {
    final ProviderContainer container = await _create(recorder: FakeVoiceRecorder());
    await _controllerOf(container).startRecording();
    await _controllerOf(container).stopRecording();

    expect(await _controllerOf(container).saveVoice(name: '   '), isFalse);

    expect(_stateOf(container).error, RecordingError.nameEmpty);
    expect(_stateOf(container).hasRecording, isTrue);
  });

  test('a recorder failure shows the platform message', () async {
    final ProviderContainer container = await _create(
      recorder: FakeVoiceRecorder(startError: const VoiceRecorderException(operation: 'start', platformMessage: 'mic busy')),
    );

    await _controllerOf(container).startRecording();

    expect(_stateOf(container).error, RecordingError.failed);
    expect(_stateOf(container).platformMessage, 'mic busy');
  });

  test('closing while recording cancels the recorder', () async {
    final FakeVoiceRecorder recorder = FakeVoiceRecorder();
    final ProviderContainer container = await _create(recorder: recorder);
    await _controllerOf(container).startRecording();

    container.dispose();
    await pumpEventQueue();

    expect(recorder.cancelCallCount, 1);
  });
}
