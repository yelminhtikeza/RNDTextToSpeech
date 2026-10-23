import 'dart:async';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../config/myanmartts_config.dart';
import '../services/audio_output.dart';
import 'burmese_tokenizer.dart';
import 'inverse_stft.dart';
import 'length_regulator.dart';
import 'magnitude_stft.dart';
import 'myanmar_tts_models.dart';
import 'synthesis_settings.dart';
import 'waveform_summary.dart';
import 'text_chunker.dart';
import 'wav_encoder.dart';

/// ဖုန်းပေါ်တွင် MyanmarTTS ဖြင့် စာဖတ်ပေးသည့် engine — controller က ဤ interface ကိုသာ သိသည်။
abstract interface class OnDeviceSpeaker {
  /// Model များကို ကြိုတင် load လုပ်သည်။ အကြိမ်များစွာ ခေါ်လည်း တစ်ကြိမ်သာ load ဖြစ်သည်။
  Future<void> load();

  /// ဖတ်စရာ မြန်မာစာလုံး ပါ/မပါ (Zawgyi သို့မဟုတ် အင်္ဂလိပ်သက်သက်ဆိုလျှင် မပါ)။
  bool hasSpeakableText({required String text});

  /// ဖတ်ပြီးဆုံးသည် သို့မဟုတ် [stop] ခေါ်သည်အထိ စောင့်သည်။
  /// အပိုင်းတစ်ခု စဖွင့်တိုင်း ယခုထိ ဖွင့်ခဲ့/ဖွင့်နေသော အသံ၏ waveform ကို [onWaveformChanged] ဖြင့် ပေးသည် (ဖတ်နေစဉ် ပြရန်)။
  /// အဆုံးထိ ဖတ်ပြီးပါက ကြားခဲ့သော အသံအားလုံးကို WAV တစ်ဖိုင်နှင့် waveform အဖြစ် ပြန်ပေးသည် (download/ပြသရန်)၊
  /// ရပ်လိုက်ပါက အပိုင်းလိုက်သာ ရှိ၍ null ပြန်ပေးသည်။
  Future<SpokenAudio?> speak({
    required String text,
    required SynthesisSettings settings,
    required void Function(WaveformSummary waveform) onWaveformChanged,
  });

  /// အသံသွင်းထားသော [waveform] (မည်သည့် sample rate မဆို) မှ အသံ လက်ဗွေ ကို တွက်သည် — အသံအသစ် ဖန်တီးရန်။
  Future<Float32List> createVoiceEmbedding({required Float32List waveform, required int sampleRate});

  /// ထုတ်ပြီးသား [wav] ကို model မ run ဘဲ [startAt] မှ ပြန်ဖွင့်သည်။ ဖွင့်ပြီးဆုံးသည် သို့မဟုတ် [stop] ခေါ်သည်အထိ စောင့်သည်။
  Future<void> replay({required Uint8List wav, Duration startAt = Duration.zero});

  /// [speak]/[replay] ၏ အသံတစ်ခုလုံးအတွင်း လက်ရှိ နေရာ — အပိုင်းလိုက် ဖတ်နေစဉ်လည်း ယခင်အပိုင်းများ၏ ကြာချိန်ကို ပေါင်းထားသည်။
  Stream<Duration> get positionChanges;

  /// ဖတ်နေစဉ် ခေတ္တရပ်လျှင် နောက်အပိုင်းကို ဆက်ထုတ်ထားသော်လည်း [resume] မခေါ်မချင်း မဖွင့်ပါ။
  Future<void> pause();

  Future<void> resume();

  /// [replay] ဖွင့်နေစဉ်/ခေတ္တရပ်ထားစဉ်သာ — အပိုင်းလိုက် ဖတ်နေစဉ် နောက်အပိုင်း မထုတ်ရသေး၍ မရ။
  Future<void> seek({required Duration position});

  Future<void> stop();

  Future<void> dispose();
}

class MyanmarTtsSpeaker implements OnDeviceSpeaker {
  MyanmarTtsSpeaker({
    required MyanmarTtsModels models,
    required AudioOutput audioOutput,
    math.Random? random,
  })  : _models = models,
        _audioOutput = audioOutput,
        _random = random ?? math.Random();

  static const String _LOG_NAME = 'myanmartts.speaker';
  static const BurmeseTokenizer _TOKENIZER = BurmeseTokenizer();
  static const LengthRegulator _REGULATOR = LengthRegulator();
  static const TextChunker _CHUNKER = TextChunker(maxCharacters: MyanmarTtsConfig.MAX_CHUNK_CHARACTERS);
  static const WavEncoder _WAV_ENCODER = WavEncoder();

  final MyanmarTtsModels _models;
  final AudioOutput _audioOutput;
  final math.Random _random;
  Future<void>? _loading;
  bool _isStopRequested = false;

  /// ဖွင့်နေသော အပိုင်း မတိုင်မီ အပိုင်းများ၏ ကြာချိန် — player ၏ အပိုင်းအတွင်း position ကို အသံတစ်ခုလုံး၏ position သို့ ပြောင်းရန်။
  Duration _playbackOffset = Duration.zero;

  /// ခေတ္တရပ်ထားစဉ် နောက်အပိုင်း မဖွင့်စေရန် တံခါး — null ဆိုလျှင် ဖွင့်ခွင့်ရှိသည်။
  Completer<void>? _resumeGate;

  /// Player ပေါ်တွင် WAV ဖွင့်နေဆဲ ဟုတ်/မဟုတ် — အပိုင်းကြား (ဖွင့်ပြီး၍ release ဖြစ်နေသော player) ကို pause/resume မခေါ်မိစေရန်။
  bool _isOutputPlaying = false;

  @override
  Stream<Duration> get positionChanges =>
      _audioOutput.positionChanges.map((Duration position) => _playbackOffset + position);

  @override
  Future<void> load() {
    // မအောင်မြင်ပါက နောက်တစ်ကြိမ် ပြန်ကြိုးစားနိုင်ရန် cache ကို ရှင်းသည်။
    return _loading ??= _models.load().catchError((Object error) {
      _loading = null;
      throw error;
    });
  }

  @override
  bool hasSpeakableText({required String text}) => _TOKENIZER.hasSpeakableText(text: text);

  @override
  Future<SpokenAudio?> speak({
    required String text,
    required SynthesisSettings settings,
    required void Function(WaveformSummary waveform) onWaveformChanged,
  }) async {
    await load();
    _isStopRequested = false;
    _resumeGate = null;
    final List<String> chunks =
        _CHUNKER.split(text: text).where((String chunk) => hasSpeakableText(text: chunk)).toList();
    if (chunks.isEmpty) return null;
    final List<Uint8List> played = <Uint8List>[];
    WaveformSummary waveform = WaveformSummary.empty;

    // အပိုင်း i ဖွင့်နေစဉ် အပိုင်း i+1 ကို ကြိုထုတ်ထားသဖြင့် ဝါကျကြား တိတ်ဆိတ်ချိန် မရှိသလောက် ဖြစ်သည်။
    Future<SpokenAudio>? pending = _synthesizeChunk(text: chunks.first, settings: settings);
    try {
      for (int index = 0; index < chunks.length; index++) {
        final SpokenAudio chunk = await pending!;
        pending = index + 1 < chunks.length
            ? _synthesizeChunk(text: chunks[index + 1], settings: settings)
            : null;
        await _resumeGate?.future;
        if (_isStopRequested) return null;
        _playbackOffset = waveform.duration;
        waveform = waveform.followedBy(chunk.waveform);
        onWaveformChanged(waveform);
        await _playOutput(wav: chunk.wav, startAt: Duration.zero);
        if (_isStopRequested) return null;
        played.add(chunk.wav);
      }
      return SpokenAudio(
        wav: _WAV_ENCODER.concatenatePcm16(wavs: played, sampleRate: MyanmarTtsConfig.SAMPLE_RATE),
        waveform: waveform,
      );
    } on SynthesisCancelledException {
      return null;
    } finally {
      // ရပ်လိုက်၍ မစောင့်တော့သော ကြိုထုတ်မှု၏ cancel exception ကို unhandled မဖြစ်စေရန်။
      pending?.ignore();
    }
  }

  @override
  Future<Float32List> createVoiceEmbedding({required Float32List waveform, required int sampleRate}) async {
    await load();
    final ({Float32List magnitude, int frames}) spectrum =
        await analyzeReferenceInIsolate(waveform: waveform, sampleRate: sampleRate);
    final Float32List embedding =
        await _models.embedSpeaker(magnitude: spectrum.magnitude, frames: spectrum.frames);
    developer.log('action=createVoiceEmbedding samples=${waveform.length} rate=$sampleRate frames=${spectrum.frames}',
        name: _LOG_NAME);
    return embedding;
  }

  @override
  Future<void> replay({required Uint8List wav, Duration startAt = Duration.zero}) async {
    _isStopRequested = false;
    _resumeGate = null;
    _playbackOffset = Duration.zero;
    await _playOutput(wav: wav, startAt: startAt);
  }

  @override
  Future<void> pause() async {
    _resumeGate ??= Completer<void>();
    if (_isOutputPlaying) await _audioOutput.pause();
  }

  @override
  Future<void> resume() async {
    _openResumeGate();
    if (_isOutputPlaying) await _audioOutput.resume();
  }

  @override
  Future<void> seek({required Duration position}) => _audioOutput.seek(position: position - _playbackOffset);

  @override
  Future<void> stop() async {
    _isStopRequested = true;
    // ခေတ္တရပ်ထားစဉ် ရပ်လျှင် တံခါးတွင် စောင့်နေသော speak ကို လွှတ်ရန်။
    _openResumeGate();
    await _audioOutput.stop();
  }

  void _openResumeGate() {
    final Completer<void>? gate = _resumeGate;
    _resumeGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  Future<void> _playOutput({required Uint8List wav, required Duration startAt}) async {
    _isOutputPlaying = true;
    try {
      await _audioOutput.playWav(wav: wav, startAt: startAt);
    } finally {
      _isOutputPlaying = false;
    }
  }

  /// အပိုင်းတစ်ခု ထုတ်ပြီး ၎င်း၏ waveform ကိုပါ တွက်သည် (ဖွင့်ချိန်တွင် ချက်ချင်း ပြနိုင်ရန်)။
  Future<SpokenAudio> _synthesizeChunk({required String text, required SynthesisSettings settings}) async {
    final Uint8List wav = await _synthesize(text: text, settings: settings);
    return SpokenAudio(
      wav: wav,
      waveform: await summarizeWaveformInIsolate(wav: wav, barsPerSecond: MyanmarTtsConfig.WAVEFORM_BARS_PER_SECOND),
    );
  }

  @override
  Future<void> dispose() async {
    await _audioOutput.dispose();
    await _models.dispose();
  }

  Future<Uint8List> _synthesize({required String text, required SynthesisSettings settings}) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Int64List tokens = _TOKENIZER.tokenize(text: text);
    final EncoderOutput encoded = await _models.encode(tokens: tokens, speaker: settings.speaker);
    final List<int> durations = _REGULATOR.durations(logDurations: encoded.logDurations, lengthScale: settings.lengthScale);
    final int frames = durations.fold<int>(0, (int sum, int value) => sum + value);
    final Float32List aligned = _REGULATOR.expand(
      features: encoded.features,
      channels: MyanmarTtsConfig.MEL_CHANNELS,
      durations: durations,
    );
    final StftSpectrum spectrum = await _models.generateSpectrum(
      alignedFeatures: aligned,
      frames: frames,
      noise: _gaussianNoise(length: aligned.length),
      flowSteps: settings.flowSteps,
      cfgStrength: settings.cfgStrength,
      speaker: settings.speaker,
      isCancelled: () => _isStopRequested,
    );
    final Uint8List wav = await renderWavInIsolate(spectrum: spectrum);
    developer.log(
      'action=synthesize characters=${text.length} frames=$frames steps=${settings.flowSteps} '
      'cfg=${settings.cfgStrength} elapsed_ms=${stopwatch.elapsedMilliseconds}',
      name: _LOG_NAME,
    );
    return wav;
  }

  /// Flow matching ၏ အစ noise (Box–Muller ဖြင့် standard normal)။
  Float32List _gaussianNoise({required int length}) {
    final Float32List noise = Float32List(length);
    for (int index = 0; index < length; index += 2) {
      final double radius = math.sqrt(-2 * math.log(1 - _random.nextDouble()));
      final double angle = 2 * math.pi * _random.nextDouble();
      noise[index] = radius * math.cos(angle);
      if (index + 1 < length) noise[index + 1] = radius * math.sin(angle);
    }
    return noise;
  }
}

/// FFT ~400 ကြိမ်ကို UI thread တွင် မလုပ်ဘဲ isolate ဖြင့် run၍ animation မထစ်စေရန်။
/// Top-level ဖြစ်ရခြင်းမှာ instance method ထဲမှ closure သည် `this` (AudioPlayer ပါ) ကို
/// ဖမ်းမိနိုင်ပြီး isolate သို့ ပို့၍ မရသောကြောင့် ဖြစ်သည်။
Future<Uint8List> renderWavInIsolate({required StftSpectrum spectrum}) =>
    Isolate.run(() => renderWav(spectrum: spectrum));

/// အသံသွင်း reference ကို 44.1 kHz သို့ ပြောင်းပြီး magnitude STFT တွက်သည် (FFT ရာချီ — UI မထစ်စေရန် isolate)။
Future<({Float32List magnitude, int frames})> analyzeReferenceInIsolate({
  required Float32List waveform,
  required int sampleRate,
}) =>
    Isolate.run(() => MagnitudeStft(fftSize: MyanmarTtsConfig.FFT_SIZE, hopLength: MyanmarTtsConfig.HOP_LENGTH)
        .analyze(waveform: resampleLinear(waveform: waveform, from: sampleRate, to: MyanmarTtsConfig.SAMPLE_RATE)));

/// Linear interpolation resample — mic က 44.1 kHz မပေးနိုင်သော ဖုန်းအတွက်သာ။ Reference encoder သည် mel
/// (ကြမ်းသော frequency band) ကိုသာ ကြည့်သဖြင့် high-quality resampler မလိုပါ။
Float32List resampleLinear({required Float32List waveform, required int from, required int to}) {
  if (from == to || waveform.isEmpty) return waveform;
  final int length = (waveform.length * to / from).floor();
  final Float32List output = Float32List(length);
  final double step = from / to;
  for (int index = 0; index < length; index++) {
    final double position = index * step;
    final int left = position.floor();
    final int right = (left + 1).clamp(0, waveform.length - 1);
    final double fraction = position - left;
    output[index] = waveform[left] * (1 - fraction) + waveform[right] * fraction;
  }
  return output;
}

Uint8List renderWav({required StftSpectrum spectrum}) {
  final InverseStft inverse =
      InverseStft(fftSize: MyanmarTtsConfig.FFT_SIZE, hopLength: MyanmarTtsConfig.HOP_LENGTH);
  final Float32List samples = inverse.synthesize(real: spectrum.real, imag: spectrum.imag, frames: spectrum.frames);
  return const WavEncoder().encodePcm16(samples: samples, sampleRate: MyanmarTtsConfig.SAMPLE_RATE);
}
