import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/myanmartts/wav_decoder.dart';
import 'package:rnd_text_to_speech/myanmartts/wav_encoder.dart';

/// 44-byte header မဟုတ်သော WAV (LIST chunk ပါ၊ stereo) ကို လက်ဖြင့် တည်ဆောက်သည်။
Uint8List _stereoWavWithListChunk() {
  final BytesBuilder bytes = BytesBuilder();
  void ascii(String text) => bytes.add(text.codeUnits);
  void u32(int value) => bytes.add((ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List());
  void u16(int value) => bytes.add((ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List());
  void i16(int value) => bytes.add((ByteData(2)..setInt16(0, value, Endian.little)).buffer.asUint8List());
  ascii('RIFF');
  u32(0);
  ascii('WAVE');
  ascii('LIST');
  u32(3); // odd size → 1 byte padding
  bytes.add(<int>[1, 2, 3, 0]);
  ascii('fmt ');
  u32(16);
  u16(1);
  u16(2);
  u32(48000);
  u32(48000 * 4);
  u16(4);
  u16(16);
  ascii('data');
  u32(8);
  i16(16384);
  i16(0); // frame 1: L=0.5, R=0 → 0.25
  i16(-32768);
  i16(-32768); // frame 2: -1
  return bytes.toBytes();
}

void main() {
  const WavDecoder decoder = WavDecoder();

  test('round-trips what WavEncoder writes', () {
    final Uint8List wav =
        const WavEncoder().encodePcm16(samples: Float32List.fromList(<double>[0.5, -0.25]), sampleRate: 44100);
    final ({Float32List samples, int sampleRate}) decoded = decoder.decodePcm16(wav: wav);
    expect(decoded.sampleRate, 44100);
    expect(decoded.samples[0], closeTo(0.5, 1e-4));
    expect(decoded.samples[1], closeTo(-0.25, 1e-4));
  });

  test('skips extra chunks, honours padding and mixes stereo to mono', () {
    final ({Float32List samples, int sampleRate}) decoded = decoder.decodePcm16(wav: _stereoWavWithListChunk());
    expect(decoded.sampleRate, 48000);
    expect(decoded.samples.toList(), <double>[0.25, -1.0]);
  });

  test('rejects non-WAV and non-PCM16 data', () {
    expect(() => decoder.decodePcm16(wav: Uint8List.fromList('not a wav file'.codeUnits)),
        throwsA(isA<FormatException>()));
    final Uint8List float = const WavEncoder().encodePcm16(samples: Float32List(2), sampleRate: 8000);
    ByteData.sublistView(float).setUint16(20, 3, Endian.little); // IEEE float
    expect(() => decoder.decodePcm16(wav: float), throwsA(isA<FormatException>()));
  });

  test('a truncated header is a FormatException, not a RangeError', () {
    final Uint8List wav = const WavEncoder().encodePcm16(samples: Float32List(4), sampleRate: 8000);
    expect(() => decoder.decodePcm16(wav: wav.sublist(0, 24)), throwsA(isA<FormatException>()));
  });
}
