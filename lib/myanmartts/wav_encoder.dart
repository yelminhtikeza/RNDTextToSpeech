import 'dart:typed_data';

/// Float PCM ကို 16-bit mono WAV bytes အဖြစ် ပြောင်းသည် — audioplayers သို့ memory မှ တိုက်ရိုက်ပေးရန်။
class WavEncoder {
  const WavEncoder();

  static const int _HEADER_BYTES = 44;
  static const int _BYTES_PER_SAMPLE = 2;
  static const int _BITS_PER_SAMPLE = 16;
  static const int _PCM_FORMAT = 1;
  static const int _MONO = 1;
  static const int _FMT_CHUNK_BYTES = 16;
  static const int _MAX_PCM16 = 32767;

  Uint8List encodePcm16({required Float32List samples, required int sampleRate}) {
    final int dataBytes = samples.length * _BYTES_PER_SAMPLE;
    final ByteData bytes = ByteData(_HEADER_BYTES + dataBytes);
    _writeAscii(bytes: bytes, offset: 0, text: 'RIFF');
    bytes.setUint32(4, _HEADER_BYTES - 8 + dataBytes, Endian.little);
    _writeAscii(bytes: bytes, offset: 8, text: 'WAVE');
    _writeAscii(bytes: bytes, offset: 12, text: 'fmt ');
    bytes.setUint32(16, _FMT_CHUNK_BYTES, Endian.little);
    bytes.setUint16(20, _PCM_FORMAT, Endian.little);
    bytes.setUint16(22, _MONO, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * _BYTES_PER_SAMPLE, Endian.little);
    bytes.setUint16(32, _BYTES_PER_SAMPLE, Endian.little);
    bytes.setUint16(34, _BITS_PER_SAMPLE, Endian.little);
    _writeAscii(bytes: bytes, offset: 36, text: 'data');
    bytes.setUint32(40, dataBytes, Endian.little);

    for (int index = 0; index < samples.length; index++) {
      // Vocoder output သည် ±1 ကို အနည်းငယ် ကျော်နိုင်သဖြင့် wrap-around ဆူညံသံ မဖြစ်စေရန် clip လုပ်သည်။
      final double clipped = samples[index].clamp(-1.0, 1.0);
      bytes.setInt16(_HEADER_BYTES + index * _BYTES_PER_SAMPLE, (clipped * _MAX_PCM16).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  static void _writeAscii({required ByteData bytes, required int offset, required String text}) {
    for (int index = 0; index < text.length; index++) {
      bytes.setUint8(offset + index, text.codeUnitAt(index));
    }
  }
}
