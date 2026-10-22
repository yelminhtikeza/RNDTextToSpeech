import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// ထုတ်ထားသော အသံ၏ waveform ပုံ (bar တစ်ခုချင်း၏ အမြင့်ဆုံး amplitude) နှင့် ကြာချိန်။
/// Sample သန်းချီကို UI တွင် တိုက်ရိုက်မဆွဲဘဲ bar အနည်းငယ်အဖြစ် ချုံ့ထားသဖြင့် state ထဲ ထည့်နိုင်သည်။
class WaveformSummary {
  const WaveformSummary({required this.peaks, required this.duration});

  static const WaveformSummary empty = WaveformSummary(peaks: <double>[], duration: Duration.zero);

  /// 0.0–1.0 ရှိ bar အမြင့်များ။
  final List<double> peaks;
  final Duration duration;

  bool get isEmpty => peaks.isEmpty;

  static const int _HEADER_BYTES = 44;
  static const int _SAMPLE_RATE_OFFSET = 24;
  static const int _BYTES_PER_SAMPLE = 2;
  static const double _PCM16_FULL_SCALE = 32768;
  static const int _MICROSECONDS_PER_SECOND = 1000000;

  /// `WavEncoder.encodePcm16` ပုံစံ (44-byte header၊ 16-bit mono) WAV မှ တွက်သည်။
  /// Header မပြည့်သော data ဆိုပါက [empty] ပြန်ပေးသည်။
  static WaveformSummary fromPcm16Wav({required Uint8List wav, required int barCount}) {
    if (wav.length <= _HEADER_BYTES || barCount <= 0) return empty;
    final ByteData data = ByteData.sublistView(wav);
    final int sampleRate = data.getUint32(_SAMPLE_RATE_OFFSET, Endian.little);
    final int sampleCount = (wav.length - _HEADER_BYTES) ~/ _BYTES_PER_SAMPLE;
    if (sampleRate == 0 || sampleCount == 0) return empty;

    final int bars = math.min(barCount, sampleCount);
    final List<double> peaks = List<double>.filled(bars, 0);
    for (int sample = 0; sample < sampleCount; sample++) {
      final int bar = sample * bars ~/ sampleCount;
      final double amplitude =
          data.getInt16(_HEADER_BYTES + sample * _BYTES_PER_SAMPLE, Endian.little).abs() / _PCM16_FULL_SCALE;
      if (amplitude > peaks[bar]) peaks[bar] = amplitude;
    }
    return WaveformSummary(
      peaks: peaks,
      duration: Duration(microseconds: sampleCount * _MICROSECONDS_PER_SECOND ~/ sampleRate),
    );
  }
}

/// အဆုံးထိ ဖတ်ပြီးသော အသံ — download လုပ်မည့် WAV နှင့် ဖန်သားပြင်တွင် ပြမည့် waveform။
class SpokenAudio {
  const SpokenAudio({required this.wav, required this.waveform});

  final Uint8List wav;
  final WaveformSummary waveform;
}

/// စာရှည် (မိနစ်ချီ အသံ = sample သန်းချီ) တွင် UI မထစ်စေရန် isolate ဖြင့် တွက်သည်။
/// Top-level ဖြစ်ရခြင်းမှာ closure က speaker (AudioPlayer ပါ) ကို မဖမ်းမိစေရန် ဖြစ်သည်။
Future<WaveformSummary> summarizeWaveformInIsolate({required Uint8List wav, required int barCount}) =>
    Isolate.run(() => WaveformSummary.fromPcm16Wav(wav: wav, barCount: barCount));
