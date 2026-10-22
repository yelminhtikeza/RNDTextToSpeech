import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/main.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/providers/burmese_speech_controller.dart';
import 'package:rnd_text_to_speech/providers/voice_controller.dart';
import 'package:rnd_text_to_speech/providers/voice_recording_controller.dart';
import 'package:rnd_text_to_speech/widgets/waveform_view.dart';

import '../support/fake_audio_file_saver.dart';
import '../support/fake_on_device_speaker.dart';
import '../support/fake_tts_service.dart';
import '../support/fake_voice_library.dart';
import '../support/fake_voice_recorder.dart';

const String _BURMESE_ENGINE = 'com.example.burmese.tts';
const String _ON_DEVICE_LABEL = 'MyanmarTTS (on-device)';

Future<void> _pumpApp(
  WidgetTester tester, {
  FakeTtsService? system,
  FakeOnDeviceSpeaker? onDevice,
  FakeAudioFileSaver? saver,
  FakeVoiceLibrary? library,
}) async {
  // Screen သည် scroll ဖြစ်သော်လည်း ListView က မြင်ကွင်းပြင်ပ widget များကို မတည်ဆောက်သဖြင့်
  // control အားလုံး တည်ဆောက်မိစေရန် ဖုန်းအကျယ် (logical 400) ရှည်လျားသော မျက်နှာပြင် သုံးသည်။
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ttsServiceProvider.overrideWithValue(system ?? FakeTtsService()),
        onDeviceSpeakerProvider.overrideWithValue(onDevice ?? FakeOnDeviceSpeaker()),
        audioFileSaverProvider.overrideWithValue(saver ?? FakeAudioFileSaver()),
        voiceLibraryProvider.overrideWithValue(library ?? FakeVoiceLibrary()),
        voiceRecorderProvider.overrideWithValue(FakeVoiceRecorder()),
      ],
      child: const RndTextToSpeechApp(),
    ),
  );
  await tester.pumpAndSettle();
}

OutlinedButton _downloadButton(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.ancestor(of: find.text('Download'), matching: find.byType(OutlinedButton)));

FilledButton _speakButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.ancestor(of: find.text('Speak'), matching: find.byType(FilledButton)));

void main() {
  testWidgets('speaks the sample text with the on-device engine by default', (WidgetTester tester) async {
    final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
    await _pumpApp(tester, onDevice: onDevice);

    expect(find.text(_ON_DEVICE_LABEL), findsOneWidget);
    expect(find.text('Pitch is not adjustable with MyanmarTTS.'), findsOneWidget);
    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();

    expect(onDevice.spokenText, isNotEmpty);
  });

  testWidgets('can switch to an installed Android engine', (WidgetTester tester) async {
    final FakeTtsService system = FakeTtsService(
      engines: <String>[_BURMESE_ENGINE],
      burmeseEngines: <String>{_BURMESE_ENGINE},
    );
    await _pumpApp(tester, system: system);

    await tester.tap(find.text(_ON_DEVICE_LABEL));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_BURMESE_ENGINE).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();

    expect(system.spokenText, isNotEmpty);
    expect(find.text('Pitch is not adjustable with MyanmarTTS.'), findsNothing);
  });

  testWidgets('shows the model load error and disables Speak', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      onDevice: FakeOnDeviceSpeaker(loadError: const MyanmarTtsException(operation: 'load')),
    );

    expect(find.textContaining('Could not load the on-device Burmese voice'), findsOneWidget);
    expect(find.text('Check engines again'), findsOneWidget);
    expect(_speakButton(tester).onPressed, isNull);
  });

  testWidgets('shows validation errors inline under the input', (WidgetTester tester) async {
    final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
    await _pumpApp(tester, onDevice: onDevice);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    expect(find.text('Enter some Burmese text first.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No Burmese Unicode text'), findsOneWidget);
    expect(onDevice.spokenText, isNull);
  });

  testWidgets('Download saves the spoken audio and confirms it', (WidgetTester tester) async {
    final FakeAudioFileSaver saver = FakeAudioFileSaver();
    await _pumpApp(tester, saver: saver);

    expect(_downloadButton(tester).onPressed, isNull);
    expect(find.text('Speak the text first to download its audio.'), findsOneWidget);

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    expect(_downloadButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(saver.savedWav, isNotNull);
    expect(find.text('Audio saved.'), findsOneWidget);
  });

  testWidgets('editing the text disables Download again', (WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ကခ');
    await tester.pump();

    expect(_downloadButton(tester).onPressed, isNull);
  });

  testWidgets('Download is hidden for Android engines', (WidgetTester tester) async {
    final FakeTtsService system = FakeTtsService(
      engines: <String>[_BURMESE_ENGINE],
      burmeseEngines: <String>{_BURMESE_ENGINE},
    );
    await _pumpApp(tester, system: system);

    await tester.tap(find.text(_ON_DEVICE_LABEL));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_BURMESE_ENGINE).last);
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsNothing);
  });

  testWidgets('Steps and CFG sliders show their values for MyanmarTTS only', (WidgetTester tester) async {
    final FakeTtsService system = FakeTtsService(
      engines: <String>[_BURMESE_ENGINE],
      burmeseEngines: <String>{_BURMESE_ENGINE},
    );
    await _pumpApp(tester, system: system);

    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('CFG'), findsOneWidget);
    expect(find.text('3.0'), findsOneWidget);

    await tester.tap(find.text(_ON_DEVICE_LABEL));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_BURMESE_ENGINE).last);
    await tester.pumpAndSettle();

    expect(find.text('Steps'), findsNothing);
    expect(find.text('CFG'), findsNothing);
  });

  testWidgets('shows the waveform and duration of generated audio until the text changes',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    expect(find.byType(WaveformView), findsNothing);

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    expect(find.byType(WaveformView), findsOneWidget);
    expect(find.text('Generated audio · 0.5 s'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ကခ');
    await tester.pump();
    expect(find.byType(WaveformView), findsNothing);
  });

  testWidgets('Play replays the generated audio next to the waveform', (WidgetTester tester) async {
    final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
    await _pumpApp(tester, onDevice: onDevice);
    expect(find.text('Play'), findsNothing);

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(onDevice.replayed, hasLength(1));
  });

  testWidgets('chooses a preset voice for MyanmarTTS', (WidgetTester tester) async {
    final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
    await _pumpApp(tester, onDevice: onDevice);

    expect(find.text('Original (female)'), findsOneWidget);
    await tester.tap(find.text('Original (female)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male 3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();

    expect(onDevice.settings!.speaker, FakeVoiceLibrary.male.embedding);
    expect(find.text('Delete voice'), findsNothing, reason: 'presets cannot be deleted');
  });

  testWidgets('records, saves, uses and deletes your own voice', (WidgetTester tester) async {
    final FakeVoiceLibrary library = FakeVoiceLibrary();
    final FakeOnDeviceSpeaker onDevice = FakeOnDeviceSpeaker();
    await _pumpApp(tester, onDevice: onDevice, library: library);

    await tester.tap(find.text('Record a voice'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Only record your own voice'), findsOneWidget);

    await tester.tap(find.text('Start recording'));
    await tester.pump();
    await tester.tap(find.text('Stop').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save voice'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name for this voice.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Voice name'), 'Ko Ko');
    await tester.tap(find.text('Save voice'));
    await tester.pumpAndSettle();

    expect(find.text('Voice added.'), findsOneWidget);
    expect(find.text('Ko Ko (recorded)'), findsOneWidget);
    expect(library.savedCustomVoices, hasLength(1));

    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();
    expect(onDevice.settings!.speaker, onDevice.createdEmbedding);

    await tester.tap(find.text('Delete voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete voice').last);
    await tester.pumpAndSettle();
    expect(find.text('Ko Ko (recorded)'), findsNothing);
    expect(find.text('Original (female)'), findsOneWidget);
    expect(library.savedCustomVoices, isEmpty);
  });

  testWidgets('voice controls are hidden for Android engines', (WidgetTester tester) async {
    final FakeTtsService system = FakeTtsService(
      engines: <String>[_BURMESE_ENGINE],
      burmeseEngines: <String>{_BURMESE_ENGINE},
    );
    await _pumpApp(tester, system: system);
    expect(find.text('Record a voice'), findsOneWidget);

    await tester.tap(find.text(_ON_DEVICE_LABEL));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_BURMESE_ENGINE).last);
    await tester.pumpAndSettle();

    expect(find.text('Record a voice'), findsNothing);
    expect(find.text('Voice'), findsNothing);
  });
}
