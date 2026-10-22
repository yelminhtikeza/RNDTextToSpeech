import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/myanmartts/length_regulator.dart';
import 'package:rnd_text_to_speech/myanmartts/text_chunker.dart';
import 'package:rnd_text_to_speech/myanmartts/wav_encoder.dart';

void main() {
  group('LengthRegulator', () {
    const LengthRegulator regulator = LengthRegulator();

    test('durations are ceil(exp(logw)) at normal speed', () {
      final Float32List logw = Float32List.fromList(<double>[0.0, 1.0, -3.0]);
      // exp: 1.0, 2.718, 0.0498 -> ceil: 1, 3, 1
      expect(regulator.durations(logDurations: logw, lengthScale: 1.0), <int>[1, 3, 1]);
    });

    test('a faster speed shortens durations but never to zero frames overall', () {
      final Float32List logw = Float32List.fromList(<double>[-5.0, -5.0]);
      expect(regulator.durations(logDurations: logw, lengthScale: 0.4), <int>[1, 0]);
    });

    test('expand repeats each token column per channel', () {
      // channels=2, tokens=3, row-major [channel, token]
      final Float32List features = Float32List.fromList(<double>[1, 2, 3, 10, 20, 30]);
      final Float32List expanded =
          regulator.expand(features: features, channels: 2, durations: <int>[2, 0, 1]);
      expect(expanded.toList(), <double>[1, 1, 3, 10, 10, 30]);
    });
  });

  group('WavEncoder', () {
    const WavEncoder encoder = WavEncoder();

    test('writes a 44-byte RIFF header and 16-bit samples', () {
      final Uint8List wav = encoder.encodePcm16(
        samples: Float32List.fromList(<double>[0.0, 1.0, -1.0, 2.0]),
        sampleRate: 44100,
      );
      final ByteData data = ByteData.sublistView(wav);

      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(data.getUint32(24, Endian.little), 44100);
      expect(data.getUint32(40, Endian.little), 8);
      expect(wav.length, 44 + 8);
      expect(data.getInt16(46, Endian.little), 32767);
      expect(data.getInt16(48, Endian.little), -32767);
      // ±1 ကျော်သော sample ကို clip လုပ်သည်
      expect(data.getInt16(50, Endian.little), 32767);
    });
  });

  test('WavEncoder concatenates WAVs into one file with a corrected header', () {
    const WavEncoder encoder = WavEncoder();
    final Uint8List first = encoder.encodePcm16(samples: Float32List.fromList(<double>[0.5, -0.5]), sampleRate: 44100);
    final Uint8List second = encoder.encodePcm16(samples: Float32List.fromList(<double>[0.25]), sampleRate: 44100);

    final Uint8List combined = encoder.concatenatePcm16(wavs: <Uint8List>[first, second], sampleRate: 44100);
    final ByteData data = ByteData.sublistView(combined);

    expect(combined.length, 44 + 6);
    expect(data.getUint32(4, Endian.little), 36 + 6);
    expect(data.getUint32(40, Endian.little), 6);
    expect(combined.sublist(44), <int>[...first.sublist(44), ...second.sublist(44)]);
  });

  group('TextChunker', () {
    const TextChunker chunker = TextChunker(maxCharacters: 10);

    test('splits on sentence ends and newlines, keeping the terminator', () {
      expect(chunker.split(text: 'ကခ။ ဂဃ\nင'), <String>['ကခ။', 'ဂဃ', 'င']);
    });

    test('splits a long sentence on spaces before hard-cutting', () {
      expect(chunker.split(text: 'ကကကက ခခခခ ဂဂဂဂ'), <String>['ကကကက ခခခခ', 'ဂဂဂဂ']);
    });

    test('hard-cuts a run with no break opportunity', () {
      expect(chunker.split(text: 'က' * 25), <String>['က' * 10, 'က' * 10, 'က' * 5]);
    });

    test('drops blank chunks', () {
      expect(chunker.split(text: ' ။ \n\n'), <String>['။']);
    });
  });
}
