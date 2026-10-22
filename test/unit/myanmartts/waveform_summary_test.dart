import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/myanmartts/wav_encoder.dart';
import 'package:rnd_text_to_speech/myanmartts/waveform_summary.dart';

Uint8List _wav(List<double> samples, {int sampleRate = 8}) =>
    const WavEncoder().encodePcm16(samples: Float32List.fromList(samples), sampleRate: sampleRate);

void main() {
  test('each bar holds the loudest absolute sample of its slice', () {
    final WaveformSummary summary =
        WaveformSummary.fromPcm16Wav(wav: _wav(<double>[0.1, -0.8, 0.2, 0.0, 0.5, -0.25, 0.0, 0.0]), barCount: 4);

    expect(summary.peaks, hasLength(4));
    expect(summary.peaks[0], closeTo(0.8, 1e-3));
    expect(summary.peaks[1], closeTo(0.2, 1e-3));
    expect(summary.peaks[2], closeTo(0.5, 1e-3));
    expect(summary.peaks[3], 0);
  });

  test('duration comes from the sample count and the header sample rate', () {
    final WaveformSummary summary = WaveformSummary.fromPcm16Wav(wav: _wav(List<double>.filled(12, 0)), barCount: 4);
    expect(summary.duration, const Duration(milliseconds: 1500));
  });

  test('never makes more bars than samples', () {
    expect(WaveformSummary.fromPcm16Wav(wav: _wav(<double>[0.5, 0.5]), barCount: 120).peaks, hasLength(2));
  });

  test('a header-only or truncated file has no waveform', () {
    expect(WaveformSummary.fromPcm16Wav(wav: _wav(<double>[]), barCount: 10).isEmpty, isTrue);
    expect(WaveformSummary.fromPcm16Wav(wav: Uint8List(10), barCount: 10).isEmpty, isTrue);
  });

  test('the isolate helper gives the same result', () async {
    final Uint8List wav = _wav(<double>[0.1, -0.9, 0.3, 0.4]);
    final WaveformSummary direct = WaveformSummary.fromPcm16Wav(wav: wav, barCount: 2);
    final WaveformSummary isolated = await summarizeWaveformInIsolate(wav: wav, barCount: 2);
    expect(isolated.peaks, direct.peaks);
    expect(isolated.duration, direct.duration);
  });
}
