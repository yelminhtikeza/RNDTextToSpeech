import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rnd_text_to_speech/config/myanmartts_config.dart';
import 'package:rnd_text_to_speech/myanmartts/burmese_tokenizer.dart';
import 'package:rnd_text_to_speech/myanmartts/inverse_stft.dart';
import 'package:rnd_text_to_speech/myanmartts/length_regulator.dart';
import 'package:rnd_text_to_speech/myanmartts/magnitude_stft.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/myanmartts/onnx_myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/services/file_voice_library.dart';

/// Bundled model အစစ်နှင့် ONNX Runtime plugin အစစ်ဖြင့် pipeline တစ်ခုလုံးကို run သည်။
///
/// - ဖုန်းပေါ်တွင်: `flutter test integration_test -d <device>` — model load နှင့် ထုတ်လုပ်ချိန်ကို print ထုတ်သည်။
/// - Python parity: `tools/myanmartts_onnx/dump_parity.py` ဖြင့် ထုတ်ထားသော dir ကို
///   `--dart-define=MYANMARTTS_PARITY_DIR=<dir>` ဖြင့် ပေးပါက noise တူညီစွာဖြင့် Python နှင့် နှိုင်းယှဉ်သည်
///   (desktop တွင်သာ — ဖိုင်စနစ် လိုသည်)။
const String _SAMPLE_TEXT = 'မင်္ဂလာပါ။ မြန်မာစာကို အသံဖြင့် ဖတ်ပြနေပါသည်။';
const String _PARITY_DIR = String.fromEnvironment('MYANMARTTS_PARITY_DIR');

/// tools/myanmartts_onnx ၏ Python pipeline (bundled v2 int8 encoder + "original" preset) က ဤစာကြောင်းအတွက်
/// ခန့်မှန်းသော frame အရေအတွက် (v1 တွင် 423 — ADR 0003 ကြည့်)။
const int _EXPECTED_FRAMES = 422;
/// Waveform correlation အနိမ့်ဆုံး — sample တစ်ခုချင်း နှိုင်းယှဉ်ခြင်းကို မသုံးခြင်းမှာ plugin ၏ ORT 1.28 နှင့်
/// Python ORT 1.23 ၏ int8 kernel များ rounding မတူ၍ phase အနည်းငယ် ကွဲသောကြောင့် ဖြစ်သည်။
/// တိုင်းထားချက် (2026-10-22): int8 correlation 0.954 (spectral 0.993)၊ fp32 max diff 4e-4။
/// Tensor layout အမှားဖြစ်ပါက correlation သည် 0 နား ကျမည်။
const double _MIN_PARITY_CORRELATION = 0.9;
const double _MIN_RMS = 0.01;

/// Python ဖြင့် တိုင်းထားချက် — preset ၈ ခုတွင် 0.73–0.98၊ မူလအသံတွင် ~0.98။
const double _MIN_VOICE_SIMILARITY = 0.9;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late OnnxMyanmarTtsModels models;
  late Float32List originalVoice;
  const BurmeseTokenizer tokenizer = BurmeseTokenizer();
  const LengthRegulator regulator = LengthRegulator();

  setUpAll(() async {
    models = OnnxMyanmarTtsModels(onnxRuntime: OnnxRuntime());
    final Stopwatch stopwatch = Stopwatch()..start();
    await models.load();
    // Bundled presets.json ၏ ပထမ (မူလ) အသံ — app ၏ ပုံသေအသံ နှင့် တူသည်။
    originalVoice = (await FileVoiceLibrary(bundle: rootBundle).loadPresets()).first.embedding;
    // ignore: avoid_print
    print('myanmartts load: ${stopwatch.elapsedMilliseconds} ms');
  });

  tearDownAll(() => models.dispose());

  Future<({Float32List audio, int frames, Duration elapsed})> synthesize({required Float32List Function(int) noise}) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final EncoderOutput encoded =
        await models.encode(tokens: tokenizer.tokenize(text: _SAMPLE_TEXT), speaker: originalVoice);
    final List<int> durations = regulator.durations(logDurations: encoded.logDurations, lengthScale: 1.0);
    final int frames = durations.fold<int>(0, (int sum, int value) => sum + value);
    final Float32List aligned =
        regulator.expand(features: encoded.features, channels: MyanmarTtsConfig.MEL_CHANNELS, durations: durations);
    final StftSpectrum spectrum = await models.generateSpectrum(
      alignedFeatures: aligned,
      frames: frames,
      noise: noise(aligned.length),
      flowSteps: MyanmarTtsConfig.FLOW_STEPS_DEFAULT,
      cfgStrength: MyanmarTtsConfig.CFG_STRENGTH_DEFAULT,
      speaker: originalVoice,
      isCancelled: () => false,
    );
    final Float32List audio = InverseStft(fftSize: MyanmarTtsConfig.FFT_SIZE, hopLength: MyanmarTtsConfig.HOP_LENGTH)
        .synthesize(real: spectrum.real, imag: spectrum.imag, frames: spectrum.frames);
    return (audio: audio, frames: frames, elapsed: stopwatch.elapsed);
  }

  testWidgets('synthesizes audible Burmese speech with the bundled models', (WidgetTester tester) async {
    final math.Random random = math.Random(0);
    final ({Float32List audio, int frames, Duration elapsed}) result = await synthesize(
      noise: (int length) => Float32List.fromList(<double>[
        for (int index = 0; index < length; index++)
          math.sqrt(-2 * math.log(1 - random.nextDouble())) * math.cos(2 * math.pi * random.nextDouble()),
      ]),
    );

    final double seconds = result.audio.length / MyanmarTtsConfig.SAMPLE_RATE;
    final double rms = math.sqrt(result.audio.fold<double>(0, (double sum, double v) => sum + v * v) / result.audio.length);
    // ignore: avoid_print
    print('myanmartts synth: ${result.elapsed.inMilliseconds} ms for ${seconds.toStringAsFixed(2)} s audio '
        '(rtf ${(result.elapsed.inMilliseconds / 1000 / seconds).toStringAsFixed(2)}), rms=${rms.toStringAsFixed(3)}');

    expect(result.frames, _EXPECTED_FRAMES);
    expect(result.audio.length, _EXPECTED_FRAMES * MyanmarTtsConfig.HOP_LENGTH);
    expect(result.audio.every((double v) => v.isFinite), isTrue);
    expect(rms, greaterThan(_MIN_RMS));

    // အသံသွင်း လမ်းကြောင်း (Dart STFT + reference.onnx) — ထုတ်ထားသောအသံ၏ လက်ဗွေသည် မူလအသံနှင့် တူရမည်။
    final ({Float32List magnitude, int frames}) spectrum =
        MagnitudeStft(fftSize: MyanmarTtsConfig.FFT_SIZE, hopLength: MyanmarTtsConfig.HOP_LENGTH)
            .analyze(waveform: result.audio);
    final Float32List embedding = await models.embedSpeaker(magnitude: spectrum.magnitude, frames: spectrum.frames);
    final double similarity = _cosine(embedding, originalVoice);
    // ignore: avoid_print
    print('myanmartts voice: generated-speech fingerprint similarity to its voice = ${similarity.toStringAsFixed(3)}');
    expect(similarity, greaterThan(_MIN_VOICE_SIMILARITY));
  });

  testWidgets('matches the Python ONNX pipeline given the same noise', (WidgetTester tester) async {
    final Float32List noise = File('$_PARITY_DIR/noise.f32').readAsBytesSync().buffer.asFloat32List();
    final Float32List expected = File('$_PARITY_DIR/audio.f32').readAsBytesSync().buffer.asFloat32List();

    final ({Float32List audio, int frames, Duration elapsed}) result = await synthesize(noise: (_) => noise);
    // မကိုက်ညီပါက Python ဘက်တွင် spectrum ဖြင့် ခွဲခြမ်းစိတ်ဖြာနိုင်ရန် Dart ရလဒ်ကို သိမ်းသည်။
    File('$_PARITY_DIR/dart_audio.f32').writeAsBytesSync(result.audio.buffer.asUint8List());

    expect(result.audio.length, expected.length);
    final double correlation = _pearson(result.audio, expected);
    // ignore: avoid_print
    print('myanmartts parity: waveform correlation vs Python = ${correlation.toStringAsFixed(4)}');
    expect(correlation, greaterThan(_MIN_PARITY_CORRELATION));
  }, skip: _PARITY_DIR.isEmpty);
}

double _pearson(Float32List a, Float32List b) {
  final int n = a.length;
  final double meanA = a.fold<double>(0, (double sum, double v) => sum + v) / n;
  final double meanB = b.fold<double>(0, (double sum, double v) => sum + v) / n;
  double covariance = 0, varianceA = 0, varianceB = 0;
  for (int index = 0; index < n; index++) {
    final double da = a[index] - meanA;
    final double db = b[index] - meanB;
    covariance += da * db;
    varianceA += da * da;
    varianceB += db * db;
  }
  return covariance / math.sqrt(varianceA * varianceB);
}

double _cosine(Float32List a, Float32List b) {
  double dot = 0, normA = 0, normB = 0;
  for (int index = 0; index < a.length; index++) {
    dot += a[index] * b[index];
    normA += a[index] * a[index];
    normB += b[index] * b[index];
  }
  return dot / math.sqrt(normA * normB);
}
