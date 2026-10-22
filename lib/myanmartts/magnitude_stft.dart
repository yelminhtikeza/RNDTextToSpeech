import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';

/// MyanmarTTS `LinearSpectrogram` (reflect pad + STFT center=False + `sqrt(|X|² + 1e-6)`) ကို Dart သို့ ပြောင်းထားခြင်း။
/// အသံသွင်းထားသော reference ကို `reference.onnx` (mel + reference encoder) သို့ ပို့ရန်။
/// torch.stft သည် complex output ဖြစ်၍ ONNX သို့ export မရသဖြင့် ဤနေရာတွင် တွက်သည်။
/// Python reference (`tools/myanmartts_onnx/common.py` ၏ `magnitude_stft`) နှင့် fixture ဖြင့် စစ်ထားသည်။
class MagnitudeStft {
  MagnitudeStft({required this.fftSize, required this.hopLength})
      : _fft = Fft(size: fftSize),
        _window = Fft.periodicHann(size: fftSize);

  static const double _MAGNITUDE_EPSILON = 1e-6;

  final int fftSize;
  final int hopLength;
  final Fft _fft;
  final Float64List _window;

  int get binCount => fftSize ~/ 2 + 1;

  /// [waveform] (44.1 kHz) → `[binCount, frames]` (row-major, `reference.onnx` input ပုံစံ)။
  ({Float32List magnitude, int frames}) analyze({required Float32List waveform}) {
    final Float64List padded = _reflectPad(waveform: waveform, padding: (fftSize - hopLength) ~/ 2);
    final int frames = padded.length < fftSize ? 0 : 1 + (padded.length - fftSize) ~/ hopLength;
    final Float32List magnitude = Float32List(binCount * frames);
    final Float64List real = Float64List(fftSize);
    final Float64List imag = Float64List(fftSize);

    for (int frame = 0; frame < frames; frame++) {
      final int offset = frame * hopLength;
      for (int sample = 0; sample < fftSize; sample++) {
        real[sample] = padded[offset + sample] * _window[sample];
        imag[sample] = 0;
      }
      _fft.forward(real: real, imag: imag);
      for (int bin = 0; bin < binCount; bin++) {
        magnitude[bin * frames + frame] =
            math.sqrt(real[bin] * real[bin] + imag[bin] * imag[bin] + _MAGNITUDE_EPSILON);
      }
    }
    return (magnitude: magnitude, frames: frames);
  }

  /// numpy/torch `reflect` padding (အစွန်းကို ထပ်မပါဘဲ ပြန်ကြည့်ခြင်း)။
  static Float64List _reflectPad({required Float32List waveform, required int padding}) {
    final int length = waveform.length;
    final Float64List padded = Float64List(length + 2 * padding);
    for (int index = 0; index < padded.length; index++) {
      int source = index - padding;
      if (source < 0) source = -source;
      if (source >= length) source = 2 * (length - 1) - source;
      padded[index] = waveform[source.clamp(0, length - 1)];
    }
    return padded;
  }
}
