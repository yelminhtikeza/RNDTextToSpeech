import 'dart:typed_data';

import 'fft.dart';

/// Vocos ၏ "same" padding ISTFT (`vocoders/vocos/models/head.py`) ကို Dart သို့ ပြောင်းထားခြင်း။
/// ONNX graph ထဲတွင် မထည့်ခြင်းမှာ `irfft` နှင့် `fold` သည် ONNX သို့ ယုံကြည်စိတ်ချစွာ export မရ၍
/// DFT matrix ဖြင့် အစားထိုးပါက model ကို ~32 MB ကြီးစေသောကြောင့် ဖြစ်သည်။
class InverseStft {
  InverseStft({required this.fftSize, required this.hopLength})
      : _fft = Fft(size: fftSize),
        _window = Fft.periodicHann(size: fftSize);

  final int fftSize;
  final int hopLength;
  final Fft _fft;
  final Float64List _window;

  int get binCount => fftSize ~/ 2 + 1;

  /// [real] နှင့် [imag] သည် `[binCount, frames]` (row-major, ONNX output ပုံစံအတိုင်း) ဖြစ်သည်။
  Float32List synthesize({required Float32List real, required Float32List imag, required int frames}) {
    final int outputLength = (frames - 1) * hopLength + fftSize;
    final Float64List signal = Float64List(outputLength);
    final Float64List envelope = Float64List(outputLength);
    final Float64List frameReal = Float64List(fftSize);
    final Float64List frameImag = Float64List(fftSize);

    for (int frame = 0; frame < frames; frame++) {
      _loadHermitianSpectrum(real: real, imag: imag, frame: frame, frames: frames, outReal: frameReal, outImag: frameImag);
      // Hermitian input ဖြစ်သဖြင့် ရလဒ်သည် real ဘက်တွင်သာ ရှိသည်။
      _fft.inverse(real: frameReal, imag: frameImag);
      final int offset = frame * hopLength;
      for (int sample = 0; sample < fftSize; sample++) {
        final double window = _window[sample];
        signal[offset + sample] += frameReal[sample] * window;
        envelope[offset + sample] += window * window;
      }
    }

    // Vocos "same" padding: အစနှင့်အဆုံး (win - hop) / 2 စီ ဖြတ်ပြီး window envelope ဖြင့် normalize လုပ်သည်။
    final int padding = (fftSize - hopLength) ~/ 2;
    final Float32List audio = Float32List(outputLength - 2 * padding);
    for (int index = 0; index < audio.length; index++) {
      audio[index] = signal[index + padding] / envelope[index + padding];
    }
    return audio;
  }

  /// numpy `irfft` အတိုင်း DC နှင့် Nyquist bin ၏ imaginary ကို လျစ်လျူရှုပြီး Hermitian spectrum အပြည့် တည်ဆောက်သည်။
  void _loadHermitianSpectrum({
    required Float32List real,
    required Float32List imag,
    required int frame,
    required int frames,
    required Float64List outReal,
    required Float64List outImag,
  }) {
    final int half = fftSize ~/ 2;
    for (int bin = 0; bin <= half; bin++) {
      outReal[bin] = real[bin * frames + frame];
      outImag[bin] = (bin == 0 || bin == half) ? 0 : imag[bin * frames + frame];
    }
    for (int bin = 1; bin < half; bin++) {
      outReal[fftSize - bin] = outReal[bin];
      outImag[fftSize - bin] = -outImag[bin];
    }
  }
}
