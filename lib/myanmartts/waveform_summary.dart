import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'wav_decoder.dart';
import 'wav_encoder.dart';

/// ထုတ်ထားသော အသံ၏ waveform ပုံ (bar တစ်ခုချင်း၏ အမြင့်ဆုံး amplitude) နှင့် ကြာချိန်။
/// Sample သန်းချီကို UI တွင် တိုက်ရိုက်မဆွဲဘဲ bar အနည်းငယ်အဖြစ် ချုံ့ထားသဖြင့် state ထဲ ထည့်နိုင်သည်။
/// Bar တစ်ခုသည် ပုံသေ အချိန်ပမာဏ ဖြစ်၍ အပိုင်းလိုက် ထုတ်သော အသံ၏ summary များကို [followedBy] ဖြင့် ဆက်နိုင်သည်။
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

  /// `WavEncoder.encodePcm16` ပုံစံ (44-byte header၊ 16-bit mono) WAV မှ တစ်စက္ကန့် [barsPerSecond] bar နှုန်းဖြင့် တွက်သည်။
  /// အသံတိုလည်း bar အနည်းဆုံး တစ်ခု ရှိသည်။ Header မပြည့်သော data ဆိုပါက [empty] ပြန်ပေးသည်။
  static WaveformSummary fromPcm16Wav({required Uint8List wav, required int barsPerSecond}) {
    if (wav.length <= _HEADER_BYTES || barsPerSecond <= 0) return empty;
    final ByteData data = ByteData.sublistView(wav);
    final int sampleRate = data.getUint32(_SAMPLE_RATE_OFFSET, Endian.little);
    final int sampleCount = (wav.length - _HEADER_BYTES) ~/ _BYTES_PER_SAMPLE;
    if (sampleRate == 0 || sampleCount == 0) return empty;

    final int bars = math.min(math.max(1, (sampleCount * barsPerSecond / sampleRate).round()), sampleCount);
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

  /// နောက်အပိုင်း၏ အသံကို အဆုံးတွင် ဆက်သည် (bar နှုန်း တူရမည်)။
  WaveformSummary followedBy(WaveformSummary next) => WaveformSummary(
        peaks: List<double>.unmodifiable(<double>[...peaks, ...next.peaks]),
        duration: duration + next.duration,
      );

  /// Bar [maxBars] ထက်များပါက အုပ်စုလိုက် အမြင့်ဆုံးကို ယူ၍ ချုံ့သည် (အသံရှည်ကို ဖုန်းအကျယ်တွင် ဆံ့စေရန်)။
  List<double> downsampledPeaks({required int maxBars}) {
    if (peaks.length <= maxBars) return peaks;
    final List<double> result = List<double>.filled(maxBars, 0);
    for (int index = 0; index < peaks.length; index++) {
      final int bar = index * maxBars ~/ peaks.length;
      if (peaks[index] > result[bar]) result[bar] = peaks[index];
    }
    return result;
  }
}

/// အဆုံးထိ ဖတ်ပြီးသော အသံ — download လုပ်မည့် WAV နှင့် ဖန်သားပြင်တွင် ပြမည့် waveform။
class SpokenAudio {
  const SpokenAudio({required this.wav, required this.waveform});

  final Uint8List wav;
  final WaveformSummary waveform;
}

/// Android engine ထုတ်သော WAV (sample rate/chunk/channel အမျိုးမျိုး) ကို app ၏ ပုံစံ (44-byte header၊ 16-bit mono) သို့
/// ပြောင်းပြီး waveform တွက်သည် — waveform၊ player၊ download အားလုံးက ပုံစံတစ်မျိုးတည်းကိုသာ ကိုင်ရန်။
/// 16-bit PCM မဟုတ်ပါက [FormatException] ပစ်သည်။
SpokenAudio spokenAudioFromEngineWav({required Uint8List wav, required int barsPerSecond}) {
  final ({Float32List samples, int sampleRate}) decoded = const WavDecoder().decodePcm16(wav: wav);
  final Uint8List normalized =
      const WavEncoder().encodePcm16(samples: decoded.samples, sampleRate: decoded.sampleRate);
  return SpokenAudio(
    wav: normalized,
    waveform: WaveformSummary.fromPcm16Wav(wav: normalized, barsPerSecond: barsPerSecond),
  );
}

/// မိနစ်ချီ engine အသံကို decode/encode လုပ်ရာတွင် UI မထစ်စေရန်။
Future<SpokenAudio> spokenAudioFromEngineWavInIsolate({required Uint8List wav, required int barsPerSecond}) =>
    Isolate.run(() => spokenAudioFromEngineWav(wav: wav, barsPerSecond: barsPerSecond));

/// စာရှည် (မိနစ်ချီ အသံ = sample သန်းချီ) တွင် UI မထစ်စေရန် isolate ဖြင့် တွက်သည်။
/// Top-level ဖြစ်ရခြင်းမှာ closure က speaker (AudioPlayer ပါ) ကို မဖမ်းမိစေရန် ဖြစ်သည်။
Future<WaveformSummary> summarizeWaveformInIsolate({required Uint8List wav, required int barsPerSecond}) =>
    Isolate.run(() => WaveformSummary.fromPcm16Wav(wav: wav, barsPerSecond: barsPerSecond));
