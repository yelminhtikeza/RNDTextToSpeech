import 'dart:math' as math;
import 'dart:typed_data';

/// In-place radix-2 complex FFT — vocoder ၏ ISTFT နှင့် အသံသွင်း reference ၏ STFT နှစ်ခုလုံး မျှဝေသုံးသည်။
class Fft {
  Fft({required this.size})
      : assert(size > 0 && size & (size - 1) == 0, 'size must be a power of two'),
        _cosTable = Float64List(size ~/ 2),
        _sinTable = Float64List(size ~/ 2),
        _bitReversed = _bitReversalTable(size: size) {
    for (int index = 0; index < size ~/ 2; index++) {
      final double angle = 2 * math.pi * index / size;
      _cosTable[index] = math.cos(angle);
      _sinTable[index] = math.sin(angle);
    }
  }

  final int size;
  final Float64List _cosTable;
  final Float64List _sinTable;
  final Int32List _bitReversed;

  /// e^{-i·2πkn/N} (scaling မပါ) — numpy `fft` နှင့် တူသည်။
  void forward({required Float64List real, required Float64List imag}) =>
      _transform(real: real, imag: imag, sign: -1);

  /// e^{+i·2πkn/N} နှင့် 1/N scaling — numpy `ifft` နှင့် တူသည်။
  void inverse({required Float64List real, required Float64List imag}) {
    _transform(real: real, imag: imag, sign: 1);
    for (int index = 0; index < size; index++) {
      real[index] /= size;
      imag[index] /= size;
    }
  }

  void _transform({required Float64List real, required Float64List imag, required int sign}) {
    for (int index = 0; index < size; index++) {
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
    for (int span = 2; span <= size; span <<= 1) {
      final int halfSpan = span >> 1;
      final int tableStep = size ~/ span;
      for (int start = 0; start < size; start += span) {
        for (int offset = 0; offset < halfSpan; offset++) {
          final double twiddleReal = _cosTable[offset * tableStep];
          final double twiddleImag = sign * _sinTable[offset * tableStep];
          final int even = start + offset;
          final int odd = even + halfSpan;
          final double oddReal = real[odd] * twiddleReal - imag[odd] * twiddleImag;
          final double oddImag = real[odd] * twiddleImag + imag[odd] * twiddleReal;
          real[odd] = real[even] - oddReal;
          imag[odd] = imag[even] - oddImag;
          real[even] += oddReal;
          imag[even] += oddImag;
        }
      }
    }
  }

  /// torch `hann_window(periodic=True)` နှင့် တူသည်။
  static Float64List periodicHann({required int size}) => Float64List.fromList(<double>[
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
