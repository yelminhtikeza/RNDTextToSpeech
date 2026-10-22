import 'dart:typed_data';

/// အသံသွင်းထားသော 16-bit PCM WAV ကို mono float sample အဖြစ် ဖတ်သည်။
/// Header သည် 44 byte မဟုတ်နိုင်သဖြင့် (Android encoder အချို့က `LIST` chunk ထည့်သည်) chunk များကို ရှာဖတ်သည်။
class WavDecoder {
  const WavDecoder();

  static const int _RIFF_HEADER_BYTES = 12;
  static const int _CHUNK_HEADER_BYTES = 8;
  static const int _PCM_FORMAT = 1;
  static const int _FMT_MIN_BYTES = 16;
  static const int _BITS_PER_SAMPLE = 16;
  static const double _PCM16_FULL_SCALE = 32768;

  /// ပံ့ပိုးမထားသော format ဖြစ်ပါက [FormatException] ပစ်သည်။
  ({Float32List samples, int sampleRate}) decodePcm16({required Uint8List wav}) {
    final ByteData data = ByteData.sublistView(wav);
    if (wav.length < _RIFF_HEADER_BYTES ||
        String.fromCharCodes(wav, 0, 4) != 'RIFF' ||
        String.fromCharCodes(wav, 8, 12) != 'WAVE') {
      throw const FormatException('not a RIFF/WAVE file');
    }

    int? channels;
    int? sampleRate;
    int offset = _RIFF_HEADER_BYTES;
    while (offset + _CHUNK_HEADER_BYTES <= wav.length) {
      final String id = String.fromCharCodes(wav, offset, offset + 4);
      final int size = data.getUint32(offset + 4, Endian.little);
      final int body = offset + _CHUNK_HEADER_BYTES;
      if (id == 'fmt ') {
        // ဖြတ်တောက်ခံရသော ဖိုင်တွင် RangeError အစား FormatException ဖြစ်စေရန် ကြိုစစ်သည်။
        if (size < _FMT_MIN_BYTES || body + _FMT_MIN_BYTES > wav.length) {
          throw const FormatException('truncated fmt chunk');
        }
        final int format = data.getUint16(body, Endian.little);
        final int bits = data.getUint16(body + 14, Endian.little);
        if (format != _PCM_FORMAT || bits != _BITS_PER_SAMPLE) {
          throw FormatException('unsupported WAV encoding: format=$format bits=$bits');
        }
        channels = data.getUint16(body + 2, Endian.little);
        sampleRate = data.getUint32(body + 4, Endian.little);
      } else if (id == 'data') {
        if (channels == null || sampleRate == null) throw const FormatException('data chunk before fmt chunk');
        // အသံသွင်းဆဲ ရပ်လိုက်ပါက size သည် ဖိုင်အရှည်ထက် ကျော်နိုင်သဖြင့် ရှိသလောက်သာ ဖတ်သည်။
        final int available = (wav.length - body).clamp(0, size);
        return (samples: _toMono(data: data, start: body, bytes: available, channels: channels), sampleRate: sampleRate);
      }
      // RIFF chunk များသည် even byte တွင် align ဖြစ်ရသည်။
      offset = body + size + (size.isOdd ? 1 : 0);
    }
    throw const FormatException('no data chunk');
  }

  static Float32List _toMono({required ByteData data, required int start, required int bytes, required int channels}) {
    final int frameBytes = channels * 2;
    final Float32List samples = Float32List(bytes ~/ frameBytes);
    for (int frame = 0; frame < samples.length; frame++) {
      double sum = 0;
      for (int channel = 0; channel < channels; channel++) {
        sum += data.getInt16(start + frame * frameBytes + channel * 2, Endian.little);
      }
      samples[frame] = sum / channels / _PCM16_FULL_SCALE;
    }
    return samples;
  }
}
