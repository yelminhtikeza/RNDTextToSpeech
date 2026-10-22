import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/config/myanmartts_config.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_speaker.dart';
import 'package:rnd_text_to_speech/services/audio_output.dart';

const int _BINS = MyanmarTtsConfig.FFT_SIZE ~/ 2 + 1;
const int _WAV_HEADER_BYTES = 44;
const int _BYTES_PER_SAMPLE = 2;

/// exp(ln 1.5) = 1.5 → ceil = 2 ဖြစ်၍ token တိုင်း 2 frame ကြာစေသော fake model။
/// (ln 2 ကို မသုံးခြင်းမှာ float32 တွင် exp သည် 2 ထက် အနည်းငယ်ကျော်ပြီး ceil က 3 ဖြစ်သွားသောကြောင့်။)
const double _LOG_DURATION = 0.4054651; // ln 1.5

class _FakeModels implements MyanmarTtsModels {
  int loadFailures = 0;
  int loadCallCount = 0;
  final List<int> encodedTokenCounts = <int>[];
  final List<int> spectrumFrames = <int>[];
  final List<int> noiseLengths = <int>[];
  Completer<void>? holdSpectrum;

  @override
  Future<void> load() async {
    loadCallCount++;
    if (loadFailures > 0) {
      loadFailures--;
      throw const MyanmarTtsException(operation: 'load', platformMessage: 'asset missing');
    }
  }

  @override
  Future<EncoderOutput> encode({required Int64List tokens}) async {
    encodedTokenCounts.add(tokens.length);
    return EncoderOutput(
      features: Float32List(MyanmarTtsConfig.MEL_CHANNELS * tokens.length),
      logDurations: Float32List.fromList(List<double>.filled(tokens.length, _LOG_DURATION)),
    );
  }

  @override
  Future<StftSpectrum> generateSpectrum({
    required Float32List alignedFeatures,
    required int frames,
    required Float32List noise,
    required bool Function() isCancelled,
  }) async {
    spectrumFrames.add(frames);
    noiseLengths.add(noise.length);
    await holdSpectrum?.future;
    if (isCancelled()) throw const SynthesisCancelledException();
    return StftSpectrum(real: Float32List(_BINS * frames), imag: Float32List(_BINS * frames), frames: frames);
  }

  @override
  Future<void> dispose() async {}
}

class _FakeAudioOutput implements AudioOutput {
  final List<Uint8List> played = <Uint8List>[];
  Completer<void>? holdPlayback;
  int stopCallCount = 0;

  @override
  Future<void> playWav({required Uint8List wav}) async {
    played.add(wav);
    await holdPlayback?.future;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    holdPlayback?.complete();
    holdPlayback = null;
  }

  @override
  Future<void> dispose() async {}
}

/// ISTFT ကို isolate အစစ်ဖြင့် run သဖြင့် event queue ကို pump လုပ်ရုံဖြင့် မလုံလောက် — အခြေအနေ ပြည့်သည်အထိ စောင့်သည်။
Future<void> _waitUntil(bool Function() condition) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > const Duration(seconds: 5)) fail('condition not met in time');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late _FakeModels models;
  late _FakeAudioOutput audio;
  late MyanmarTtsSpeaker speaker;

  setUp(() {
    models = _FakeModels();
    audio = _FakeAudioOutput();
    speaker = MyanmarTtsSpeaker(models: models, audioOutput: audio, random: math.Random(1));
  });

  test('synthesizes one chunk into a playable 44.1 kHz WAV', () async {
    final Uint8List? downloadable = await speaker.speak(text: 'ကခ', lengthScale: 1.0);

    // "ကခ" -> blank,က,blank,ခ,blank = 5 tokens × 2 frames
    expect(models.encodedTokenCounts, <int>[5]);
    expect(models.spectrumFrames, <int>[10]);
    expect(models.noiseLengths, <int>[MyanmarTtsConfig.MEL_CHANNELS * 10]);
    expect(audio.played, hasLength(1));
    final ByteData header = ByteData.sublistView(audio.played.single);
    expect(header.getUint32(24, Endian.little), MyanmarTtsConfig.SAMPLE_RATE);
    // ISTFT output = frames × hop samples
    expect(audio.played.single.length, _WAV_HEADER_BYTES + 10 * MyanmarTtsConfig.HOP_LENGTH * _BYTES_PER_SAMPLE);
    expect(downloadable, audio.played.single);
  });

  test('length scale changes the number of frames', () async {
    await speaker.speak(text: 'ကခ', lengthScale: 0.5);
    expect(models.spectrumFrames, <int>[5]);
  });

  test('plays each sentence in order and skips chunks with nothing to say', () async {
    final Uint8List? downloadable = await speaker.speak(text: 'က။ hello။ ခဂ။', lengthScale: 1.0);

    expect(models.encodedTokenCounts, <int>[5, 7]);
    expect(audio.played, hasLength(2));
    // Download ဖိုင်သည် ဖွင့်ခဲ့သော အပိုင်းအားလုံးကို ပေါင်းထားသည်
    final int playedData = audio.played.fold<int>(0, (int sum, Uint8List wav) => sum + wav.length - _WAV_HEADER_BYTES);
    expect(downloadable!.length, _WAV_HEADER_BYTES + playedData);
  });

  test('synthesizes the next sentence while the current one plays', () async {
    audio.holdPlayback = Completer<void>();
    final Future<void> speaking = speaker.speak(text: 'က။ ခ။', lengthScale: 1.0);
    await _waitUntil(() => audio.played.isNotEmpty && models.spectrumFrames.length == 2);

    expect(audio.played, hasLength(1));
    expect(models.spectrumFrames, hasLength(2), reason: 'second chunk is prepared during playback');

    audio.holdPlayback!.complete();
    audio.holdPlayback = null;
    await speaking;
    expect(audio.played, hasLength(2));
  });

  test('stop during synthesis cancels without playing or throwing', () async {
    models.holdSpectrum = Completer<void>();
    final Future<void> speaking = speaker.speak(text: 'က', lengthScale: 1.0);
    await _waitUntil(() => models.spectrumFrames.isNotEmpty);

    await speaker.stop();
    models.holdSpectrum!.complete();
    await speaking;

    expect(audio.played, isEmpty);
  });

  test('stop during playback does not start the next sentence', () async {
    audio.holdPlayback = Completer<void>();
    final Future<Uint8List?> speaking = speaker.speak(text: 'က။ ခ။ ဂ။', lengthScale: 1.0);
    await _waitUntil(() => audio.played.isNotEmpty);

    await speaker.stop();

    expect(await speaking, isNull, reason: 'partial audio is not offered for download');
    expect(audio.played, hasLength(1));
    expect(audio.stopCallCount, 1);
  });

  test('load is shared between callers and retried after a failure', () async {
    models.loadFailures = 1;
    await expectLater(speaker.load(), throwsA(isA<MyanmarTtsException>()));

    await Future.wait(<Future<void>>[speaker.load(), speaker.load()]);
    expect(models.loadCallCount, 2);
  });
}
