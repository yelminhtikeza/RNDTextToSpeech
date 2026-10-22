import 'dart:math' as math;
import 'dart:typed_data';

/// Vocos ၏ "same" padding ISTFT (`vocoders/vocos/models/head.py`) ကို Dart သို့ ပြောင်းထားခြင်း။
/// ONNX graph ထဲတွင် မထည့်ခြင်းမှာ `irfft` နှင့် `fold` သည် ONNX သို့ ယုံကြည်စိတ်ချစွာ export မရ၍
/// DFT matrix ဖြင့် အစားထိုးပါက model ကို ~32 MB ကြီးစေသောကြောင့် ဖြစ်သည်။
class InverseStft {
  InverseStft({required this.fftSize, required this.hopLength})
      : assert(fftSize > 0 && fftSize & (fftSize - 1) == 0, 'fftSize must be a power of two'),
        _window = _periodicHann(size: fftSize),
        _cosTable = Float64List(fftSize ~/ 2),
        _sinTable = Float64List(fftSize ~/ 2),
        _bitReversed = _bitReversalTable(size: fftSize) {
    for (int index = 0; index < fftSize ~/ 2; index++) {
      final double angle = 2 * math.pi * index / fftSize;
      _cosTable[index] = math.cos(angle);
      _sinTable[index] = math.sin(angle);
    }
  }

  final int fftSize;
  final int hopLength;
  final Float64List _window;
  final Float64List _cosTable;
  final Float64List _sinTable;
  final Int32List _bitReversed;

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
      _inverseFft(real: frameReal, imag: frameImag);
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

  /// In-place radix-2 inverse FFT (1/N scaling ပါ)။ Hermitian input ဖြစ်သဖြင့် ရလဒ်သည် [real] တွင်သာ ရှိသည်။
  void _inverseFft({required Float64List real, required Float64List imag}) {
    for (int index = 0; index < fftSize; index++) {
      final int swapWith = _bitReversed[index];
      if (swapWith > index) {
        final double tempReal = real[index];
        real[index] = real[swapWith];
        real[swapWith] = tempReal;
        final double tempImag = imag[index];
        imag[index] = imag[swapWith];
        imag[swapWith] = tempImag;
      }
    }
    for (int size = 2; size <= fftSize; size <<= 1) {
      final int halfSize = size >> 1;
      final int tableStep = fftSize ~/ size;
      for (int start = 0; start < fftSize; start += size) {
        for (int offset = 0; offset < halfSize; offset++) {
          // Inverse transform ဖြစ်သဖြင့် twiddle သည် e^{+i·angle}
          final double twiddleReal = _cosTable[offset * tableStep];
          final double twiddleImag = _sinTable[offset * tableStep];
          final int even = start + offset;
          final int odd = even + halfSize;
          final double oddReal = real[odd] * twiddleReal - imag[odd] * twiddleImag;
          final double oddImag = real[odd] * twiddleImag + imag[odd] * twiddleReal;
          real[odd] = real[even] - oddReal;
          imag[odd] = imag[even] - oddImag;
          real[even] += oddReal;
          imag[even] += oddImag;
        }
      }
    }
    for (int index = 0; index < fftSize; index++) {
      real[index] /= fftSize;
    }
  }

  /// torch `hann_window(periodic=True)` နှင့် တူသည်။
  static Float64List _periodicHann({required int size}) => Float64List.fromList(<double>[
        for (int index = 0; index < size; index++) 0.5 - 0.5 * math.cos(2 * math.pi * index / size),
      ]);

  static Int32List _bitReversalTable({required int size}) {
    final int bits = size.bitLength - 1;
    final Int32List table = Int32List(size);
    for (int index = 0; index < size; index++) {
      int reversed = 0;
      for (int bit = 0; bit < bits; bit++) {
        reversed = (reversed << 1) | ((index >> bit) & 1);
      }
      table[index] = reversed;
    }
    return table;
  }
}
