import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/config/myanmartts_config.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_speaker.dart';
import 'package:rnd_text_to_speech/myanmartts/synthesis_settings.dart';
import 'package:rnd_text_to_speech/myanmartts/waveform_summary.dart';
import 'package:rnd_text_to_speech/services/audio_output.dart';

const int _BINS = MyanmarTtsConfig.FFT_SIZE ~/ 2 + 1;
final Float32List _speaker = Float32List(MyanmarTtsConfig.SPEAKER_EMBEDDING_SIZE)..[0] = 0.5;
final Float32List _embedded = Float32List(MyanmarTtsConfig.SPEAKER_EMBEDDING_SIZE)..[1] = 0.25;
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
  final List<(int, double)> stepsAndCfg = <(int, double)>[];
  final List<Float32List> speakers = <Float32List>[];
  final List<int> embeddedFrames = <int>[];
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
  Future<EncoderOutput> encode({required Int64List tokens, required Float32List speaker}) async {
    speakers.add(speaker);
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
    required int flowSteps,
    required double cfgStrength,
    required Float32List speaker,
    required bool Function() isCancelled,
  }) async {
    speakers.add(speaker);
    spectrumFrames.add(frames);
    stepsAndCfg.add((flowSteps, cfgStrength));
    noiseLengths.add(noise.length);
    await holdSpectrum?.future;
    if (isCancelled()) throw const SynthesisCancelledException();
    return StftSpectrum(real: Float32List(_BINS * frames), imag: Float32List(_BINS * frames), frames: frames);
  }

  @override
  Future<Float32List> embedSpeaker({required Float32List magnitude, required int frames}) async {
    embeddedFrames.add(frames);
    expect(magnitude.length, _BINS * frames);
    return _embedded;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeAudioOutput implements AudioOutput {
  final List<Uint8List> played = <Uint8List>[];
  final List<Duration> startPositions = <Duration>[];
  final List<String> controls = <String>[];
  final List<Duration> seeks = <Duration>[];
  final StreamController<Duration> positions = StreamController<Duration>.broadcast();
  Completer<void>? holdPlayback;
  int stopCallCount = 0;

  @override
  Stream<Duration> get positionChanges => positions.stream;

  @override
  Future<void> playWav({required Uint8List wav, Duration startAt = Duration.zero}) async {
    played.add(wav);
    startPositions.add(startAt);
    await holdPlayback?.future;
  }

  @override
  Future<void> pause() async => controls.add('pause');

  @override
  Future<void> resume() async => controls.add('resume');

  @override
  Future<void> seek({required Duration position}) async => seeks.add(position);

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
  late List<WaveformSummary> waveforms;

  setUp(() {
    waveforms = <WaveformSummary>[];
    models = _FakeModels();
    audio = _FakeAudioOutput();
    speaker = MyanmarTtsSpeaker(models: models, audioOutput: audio, random: math.Random(1));
  });

  test('synthesizes one chunk into a playable 44.1 kHz WAV', () async {
    final SpokenAudio? spoken = await speaker.speak(onWaveformChanged: waveforms.add, text: 'ကခ', settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0));

    // "ကခ" -> blank,က,blank,ခ,blank = 5 tokens × 2 frames
    expect(models.encodedTokenCounts, <int>[5]);
    expect(models.spectrumFrames, <int>[10]);
    expect(models.noiseLengths, <int>[MyanmarTtsConfig.MEL_CHANNELS * 10]);
    expect(audio.played, hasLength(1));
    final ByteData header = ByteData.sublistView(audio.played.single);
    expect(header.getUint32(24, Endian.little), MyanmarTtsConfig.SAMPLE_RATE);
    // ISTFT output = frames × hop samples
    expect(audio.played.single.length, _WAV_HEADER_BYTES + 10 * MyanmarTtsConfig.HOP_LENGTH * _BYTES_PER_SAMPLE);
    expect(spoken!.wav, audio.played.single);
    // 10 frames × 512 hop = 5120 samples
    expect(spoken.waveform.duration, Duration(microseconds: 5120 * 1000000 ~/ MyanmarTtsConfig.SAMPLE_RATE));
    // 0.116 s × 20 bar/s ≈ 2 bar
    expect(spoken.waveform.peaks, hasLength(2));
    expect(waveforms, <WaveformSummary>[spoken.waveform], reason: 'shown as soon as the chunk starts playing');
  });

  test('grows the waveform chunk by chunk and reports positions across the whole audio', () async {
    audio.holdPlayback = Completer<void>();
    final List<Duration> positions = <Duration>[];
    final StreamSubscription<Duration> subscription = speaker.positionChanges.listen(positions.add);
    addTearDown(subscription.cancel);
    final Future<SpokenAudio?> speaking = speaker.speak(
      onWaveformChanged: waveforms.add,
      text: 'က။ ခ။',
      settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0),
    );
    await _waitUntil(() => audio.played.isNotEmpty);
    final Duration firstChunk = waveforms.single.duration;

    audio.holdPlayback!.complete();
    audio.holdPlayback = Completer<void>();
    await _waitUntil(() => audio.played.length == 2);
    audio.positions.add(const Duration(milliseconds: 10));
    await pumpEventQueue();
    audio.holdPlayback!.complete();
    audio.holdPlayback = null;
    final SpokenAudio? spoken = await speaking;

    expect(waveforms, hasLength(2));
    expect(waveforms.last.duration, greaterThan(firstChunk));
    expect(spoken!.waveform.peaks, waveforms.last.peaks);
    expect(positions, <Duration>[firstChunk + const Duration(milliseconds: 10)]);
  });

  test('pause holds the next chunk until resume', () async {
    audio.holdPlayback = Completer<void>();
    final Future<SpokenAudio?> speaking = speaker.speak(
      onWaveformChanged: waveforms.add,
      text: 'က။ ခ။',
      settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0),
    );
    await _waitUntil(() => audio.played.isNotEmpty && models.spectrumFrames.length == 2);

    await speaker.pause();
    audio.holdPlayback!.complete();
    audio.holdPlayback = null;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(audio.played, hasLength(1), reason: 'the next chunk waits while paused');
    expect(audio.controls, <String>['pause']);

    await speaker.resume();
    expect(await speaking, isNotNull);
    expect(audio.played, hasLength(2));
    expect(audio.controls, <String>['pause'], reason: 'nothing was playing to resume between chunks');
  });

  test('stop while paused ends speaking', () async {
    audio.holdPlayback = Completer<void>();
    final Future<SpokenAudio?> speaking = speaker.speak(
      onWaveformChanged: waveforms.add,
      text: 'က။ ခ။',
      settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0),
    );
    await _waitUntil(() => audio.played.isNotEmpty);

    await speaker.pause();
    await speaker.stop();

    expect(await speaking, isNull);
    expect(audio.played, hasLength(1));
  });

  test('forwards steps and CFG to the model for every chunk', () async {
    await speaker.speak(
      onWaveformChanged: waveforms.add,
      text: 'က။ ခ။',
      settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0, flowSteps: 8, cfgStrength: 4.5),
    );
    expect(models.stepsAndCfg, <(int, double)>[(8, 4.5), (8, 4.5)]);
  });

  test('uses the chosen defaults when steps and CFG are not given', () async {
    await speaker.speak(onWaveformChanged: waveforms.add, text: 'က', settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0));
    expect(models.stepsAndCfg.single, (MyanmarTtsConfig.FLOW_STEPS_DEFAULT, MyanmarTtsConfig.CFG_STRENGTH_DEFAULT));
  });

  test('length scale changes the number of frames', () async {
    await speaker.speak(onWaveformChanged: waveforms.add, text: 'ကခ', settings: SynthesisSettings(speaker: _speaker, lengthScale: 0.5));
    expect(models.spectrumFrames, <int>[5]);
  });

  test('plays each sentence in order and skips chunks with nothing to say', () async {
    final SpokenAudio? spoken = await speaker.speak(onWaveformChanged: waveforms.add, text: 'က။ hello။ ခဂ။', settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0));

    expect(models.encodedTokenCounts, <int>[5, 7]);
    expect(audio.played, hasLength(2));
    // Download ဖိုင်သည် ဖွင့်ခဲ့သော အပိုင်းအားလုံးကို ပေါင်းထားသည်
    final int playedData = audio.played.fold<int>(0, (int sum, Uint8List wav) => sum + wav.length - _WAV_HEADER_BYTES);
    expect(spoken!.wav.length, _WAV_HEADER_BYTES + playedData);
  });

  test('synthesizes the next sentence while the current one plays', () async {
    audio.holdPlayback = Completer<void>();
    final Future<void> speaking = speaker.speak(onWaveformChanged: waveforms.add, text: 'က။ ခ။', settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0));
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
    final Future<void> speaking = speaker.speak(onWaveformChanged: waveforms.add, text: 'က', settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0));
    await _waitUntil(() => models.spectrumFrames.isNotEmpty);

    await speaker.stop();
    models.holdSpectrum!.complete();
    await speaking;

    expect(audio.played, isEmpty);
  });

  test('stop during playback does not start the next sentence', () async {
    audio.holdPlayback = Completer<void>();
    final Future<SpokenAudio?> speaking = speaker.speak(onWaveformChanged: waveforms.add, text: 'က။ ခ။ ဂ။', settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0));
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

  test('replay plays the given audio without touching the models', () async {
    final Uint8List wav = Uint8List.fromList(<int>[1, 2, 3]);

    await speaker.replay(wav: wav);

    expect(audio.played, <Uint8List>[wav]);
    expect(models.encodedTokenCounts, isEmpty);
  });

  test('replay can start part-way and seek, pause and resume the player', () async {
    final Uint8List wav = Uint8List.fromList(<int>[1, 2, 3]);
    audio.holdPlayback = Completer<void>();
    final Future<void> replaying = speaker.replay(wav: wav, startAt: const Duration(seconds: 2));
    await pumpEventQueue();

    await speaker.pause();
    await speaker.seek(position: const Duration(seconds: 1));
    await speaker.resume();
    await speaker.stop();
    await replaying;

    expect(audio.startPositions, <Duration>[const Duration(seconds: 2)]);
    expect(audio.controls, <String>['pause', 'resume']);
    expect(audio.seeks, <Duration>[const Duration(seconds: 1)]);
  });

  test('passes the selected voice to the encoder and every estimator run', () async {
    await speaker.speak(onWaveformChanged: waveforms.add, text: 'က', settings: SynthesisSettings(speaker: _speaker, lengthScale: 1.0));
    expect(models.speakers, hasLength(2));
    expect(models.speakers.every((Float32List s) => identical(s, _speaker)), isTrue);
  });

  test('creates a voice embedding from a recording at the model sample rate', () async {
    // 1 s @ 44.1 kHz → reflect pad 768 ×2 → 1 + (44100 + 1536 - 2048) / 512 = 86 frames
    final Float32List embedding = await speaker.createVoiceEmbedding(
      waveform: Float32List(MyanmarTtsConfig.SAMPLE_RATE),
      sampleRate: MyanmarTtsConfig.SAMPLE_RATE,
    );
    expect(embedding, _embedded);
    expect(models.embeddedFrames, <int>[86]);
  });

  test('resamples a 16 kHz recording to 44.1 kHz before analysis', () async {
    await speaker.createVoiceEmbedding(waveform: Float32List(16000), sampleRate: 16000);
    expect(models.embeddedFrames, <int>[86]);
  });
}
