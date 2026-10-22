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
  /// အဆုံးထိ ဖတ်ပြီးပါက ကြားခဲ့သော အသံအားလုံးကို WAV တစ်ဖိုင်နှင့် waveform အဖြစ် ပြန်ပေးသည် (download/ပြသရန်)၊
  /// ရပ်လိုက်ပါက အပိုင်းလိုက်သာ ရှိ၍ null ပြန်ပေးသည်။
  Future<SpokenAudio?> speak({required String text, required SynthesisSettings settings});

  /// ထုတ်ပြီးသား [wav] ကို model မ run ဘဲ ပြန်ဖွင့်သည်။ ဖွင့်ပြီးဆုံးသည် သို့မဟုတ် [stop] ခေါ်သည်အထိ စောင့်သည်။
  Future<void> replay({required Uint8List wav});

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
  Future<SpokenAudio?> speak({required String text, required SynthesisSettings settings}) async {
    await load();
    _isStopRequested = false;
    final List<String> chunks =
        _CHUNKER.split(text: text).where((String chunk) => hasSpeakableText(text: chunk)).toList();
    if (chunks.isEmpty) return null;
    final List<Uint8List> played = <Uint8List>[];

    // အပိုင်း i ဖွင့်နေစဉ် အပိုင်း i+1 ကို ကြိုထုတ်ထားသဖြင့် ဝါကျကြား တိတ်ဆိတ်ချိန် မရှိသလောက် ဖြစ်သည်။
    Future<Uint8List>? pending = _synthesize(text: chunks.first, settings: settings);
    try {
      for (int index = 0; index < chunks.length; index++) {
        final Uint8List wav = await pending!;
        pending = index + 1 < chunks.length
            ? _synthesize(text: chunks[index + 1], settings: settings)
            : null;
        if (_isStopRequested) return null;
        await _audioOutput.playWav(wav: wav);
        if (_isStopRequested) return null;
        played.add(wav);
      }
      final Uint8List wav = _WAV_ENCODER.concatenatePcm16(wavs: played, sampleRate: MyanmarTtsConfig.SAMPLE_RATE);
      return SpokenAudio(
        wav: wav,
        waveform: await summarizeWaveformInIsolate(wav: wav, barCount: MyanmarTtsConfig.WAVEFORM_BAR_COUNT),
      );
    } on SynthesisCancelledException {
      return null;
    } finally {
      // ရပ်လိုက်၍ မစောင့်တော့သော ကြိုထုတ်မှု၏ cancel exception ကို unhandled မဖြစ်စေရန်။
      pending?.ignore();
    }
  }

  @override
  Future<void> replay({required Uint8List wav}) async {
    _isStopRequested = false;
    await _audioOutput.playWav(wav: wav);
  }

  @override
  Future<void> stop() async {
    _isStopRequested = true;
    await _audioOutput.stop();
  }

  @override
  Future<void> dispose() async {
    await _audioOutput.dispose();
    await _models.dispose();
  }

  Future<Uint8List> _synthesize({required String text, required SynthesisSettings settings}) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Int64List tokens = _TOKENIZER.tokenize(text: text);
    final EncoderOutput encoded = await _models.encode(tokens: tokens);
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

Uint8List renderWav({required StftSpectrum spectrum}) {
  final InverseStft inverse =
      InverseStft(fftSize: MyanmarTtsConfig.FFT_SIZE, hopLength: MyanmarTtsConfig.HOP_LENGTH);
  final Float32List samples = inverse.synthesize(real: spectrum.real, imag: spectrum.imag, frames: spectrum.frames);
  return const WavEncoder().encodePcm16(samples: samples, sampleRate: MyanmarTtsConfig.SAMPLE_RATE);
}
