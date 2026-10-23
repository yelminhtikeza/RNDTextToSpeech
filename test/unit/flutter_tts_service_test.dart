import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:rnd_text_to_speech/models/engine_voice.dart';
import 'package:rnd_text_to_speech/myanmartts/waveform_summary.dart';
import 'package:rnd_text_to_speech/services/flutter_tts_service.dart';

const MethodChannel _CHANNEL = MethodChannel('flutter_tts');
const Duration _START_TIMEOUT = Duration(milliseconds: 50);

/// Android engine ကဲ့သို့ 22.05 kHz stereo 16-bit WAV (header 44 byte)။ Sample တိုင်း L=0.5၊ R=0။
Uint8List _stereoWav({required int frames}) {
  const int sampleRate = 22050;
  final ByteData data = ByteData(44 + frames * 4);
  void ascii(int offset, String text) {
    for (int index = 0; index < text.length; index++) {
      data.setUint8(offset + index, text.codeUnitAt(index));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + frames * 4, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 2, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 4, Endian.little);
  data.setUint16(32, 4, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frames * 4, Endian.little);
  for (int frame = 0; frame < frames; frame++) {
    data.setInt16(44 + frame * 4, 16384, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporary;
  late FlutterTts flutterTts;
  late FlutterTtsService service;
  late List<String> calls;
  List<Object?> platformVoices = <Object?>[];
  Map<Object?, Object?>? setVoiceArguments;

  /// synthesizeToFile ခေါ်ချိန်တွင် platform (engine) ဘက်မှ လုပ်မည့်အရာ။
  late Future<void> Function(String path) onSynthesize;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('tts_service_test');
    addTearDown(() => temporary.deleteSync(recursive: true));
    calls = <String>[];
    onSynthesize = (_) async {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_CHANNEL,
        (MethodCall call) async {
      calls.add(call.method);
      if (call.method == 'getVoices') return platformVoices;
      if (call.method == 'setVoice') {
        setVoiceArguments = call.arguments as Map<Object?, Object?>;
        return 1;
      }
      if (call.method == 'synthesizeToFile') {
        final Map<Object?, Object?> arguments = call.arguments as Map<Object?, Object?>;
        expect(arguments['isFullPath'], isTrue, reason: 'must write into the app folder, not shared Music');
        // Plugin သည် ချက်ချင်း 1 ပြန်ပြီး engine က နောက်မှ callback ပို့သည်။
        Future<void>.microtask(() => onSynthesize(arguments['fileName']! as String));
      }
      return 1;
    });
    addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_CHANNEL, null));
    flutterTts = FlutterTts();
    service = FlutterTtsService(
      flutterTts: flutterTts,
      temporaryDirectory: () async => temporary,
      synthesisStartTimeout: _START_TIMEOUT,
    );
  });

  Future<void> engineCallback(String method, [Object? arguments]) =>
      flutterTts.platformCallHandler(MethodCall(method, arguments));

  test('reads and normalizes the file the engine wrote and keeps it until the next one', () async {
    late String writtenPath;
    onSynthesize = (String path) async {
      writtenPath = path;
      await engineCallback('synth.onStart');
      File(path).writeAsBytesSync(_stereoWav(frames: 22050));
      await engineCallback('synth.onComplete');
    };

    final SpokenAudio? audio = await service.synthesizeAudio(text: 'hello');

    expect(audio, isNotNull);
    expect(audio!.waveform.duration, const Duration(seconds: 1));
    expect(audio.waveform.peaks.first, closeTo(0.25, 1e-3), reason: 'stereo is mixed down to mono');
    expect(ByteData.sublistView(audio.wav).getUint16(22, Endian.little), 1, reason: 'app format is mono');
    expect(File(writtenPath).existsSync(), isTrue, reason: 'the latest audio stays until it is overwritten');
    expect(calls, isNot(contains('awaitSynthCompletion')), reason: 'the plugin never resolves it on error or stop');
  });

  test('lists installed voices, flags online ones and skips voices whose data is not downloaded', () async {
    platformVoices = <Object?>[
      <Object?, Object?>{'name': 'en-us-x-a-local', 'locale': 'en-US', 'network_required': '0', 'features': ''},
      <Object?, Object?>{'name': 'en-us-x-a-network', 'locale': 'en-US', 'network_required': '1', 'features': 'x'},
      <Object?, Object?>{
        'name': 'en-gb-x-b-local',
        'locale': 'en-GB',
        'network_required': '0',
        'features': 'embeddedTts\tnotInstalled',
      },
      <Object?, Object?>{'locale': 'en-US'},
    ];

    final List<EngineVoice> voices = await service.getVoices();

    expect(voices.map((EngineVoice voice) => voice.name), <String>['en-us-x-a-local', 'en-us-x-a-network']);
    expect(voices.map((EngineVoice voice) => voice.requiresNetwork), <bool>[false, true]);
  });

  test('setVoice sends the name and locale the plugin matches on', () async {
    final bool isSet = await service.setVoice(
      voice: const EngineVoice(name: 'en-us-x-a-local', locale: 'en-US', requiresNetwork: false),
    );

    expect(isSet, isTrue);
    expect(setVoiceArguments, <String, String>{'name': 'en-us-x-a-local', 'locale': 'en-US'});
  });

  test('gives up when the engine never starts (file output unsupported)', () async {
    expect(await service.synthesizeAudio(text: 'hello'), isNull);
  });

  test('a slow engine that has started is not cut off by the start timeout', () async {
    onSynthesize = (String path) async {
      await engineCallback('synth.onStart');
      await Future<void>.delayed(_START_TIMEOUT * 3);
      File(path).writeAsBytesSync(_stereoWav(frames: 100));
      await engineCallback('synth.onComplete');
    };

    expect(await service.synthesizeAudio(text: 'hello'), isNotNull);
  });

  test('an engine error returns null', () async {
    onSynthesize = (String path) async {
      await engineCallback('synth.onStart');
      await engineCallback('synth.onError', 'Error from TextToSpeech (synth) - -5');
    };

    expect(await service.synthesizeAudio(text: 'hello'), isNull);
  });

  test('stop releases a synthesis that is still running', () async {
    onSynthesize = (String path) => engineCallback('synth.onStart');
    final Future<SpokenAudio?> synthesis = service.synthesizeAudio(text: 'hello');
    await Future<void>.delayed(Duration.zero);

    await service.stop();

    expect(await synthesis, isNull);
    expect(calls, contains('stop'));
  });

  test('never returns the previous file when the engine reports success without writing', () async {
    File('${temporary.path}/engine_synthesis.wav').writeAsBytesSync(_stereoWav(frames: 100));
    onSynthesize = (String path) async {
      await engineCallback('synth.onStart');
      await engineCallback('synth.onComplete');
    };

    expect(await service.synthesizeAudio(text: 'hello'), isNull);
  });

  test('a failed run leaves no partial file behind', () async {
    late String writtenPath;
    onSynthesize = (String path) async {
      writtenPath = path;
      await engineCallback('synth.onStart');
      File(path).writeAsBytesSync(Uint8List(10));
      await engineCallback('synth.onError', 'disk full');
    };

    expect(await service.synthesizeAudio(text: 'hello'), isNull);
    expect(File(writtenPath).existsSync(), isFalse);
  });

  test('a completed but empty or non-PCM16 file returns null', () async {
    onSynthesize = (String path) async {
      await engineCallback('synth.onStart');
      File(path).writeAsBytesSync(Uint8List.fromList('RIFF\u0000\u0000\u0000\u0000WAVE'.codeUnits));
      await engineCallback('synth.onComplete');
    };
    expect(await service.synthesizeAudio(text: 'hello'), isNull);

    onSynthesize = (String path) async {
      await engineCallback('synth.onStart');
      await engineCallback('synth.onComplete');
    };
    expect(await service.synthesizeAudio(text: 'hello'), isNull, reason: 'no file was written');
  });
}
