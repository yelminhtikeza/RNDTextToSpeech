import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/config/myanmartts_config.dart';
import 'package:rnd_text_to_speech/myanmartts/burmese_tokenizer.dart';
import 'package:rnd_text_to_speech/myanmartts/inverse_stft.dart';

/// Python reference (tools/myanmartts_onnx/make_dart_fixtures.py) မှ ထုတ်ထားသော fixture။
const String _FIXTURE_PATH = 'test/fixtures/myanmartts_reference.json';
const double _ISTFT_TOLERANCE = 1e-5;

Map<String, dynamic> _loadFixture() =>
    jsonDecode(File(_FIXTURE_PATH).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final Map<String, dynamic> fixture = _loadFixture();

  group('BurmeseTokenizer matches the Python frontend', () {
    const BurmeseTokenizer tokenizer = BurmeseTokenizer();

    test('vocabulary has the 98 symbols the model was trained on', () {
      expect(BurmeseTokenizer.vocabularySize, 98);
    });

    for (final dynamic testCase in fixture['tokens'] as List<dynamic>) {
      final String text = testCase['text'] as String;
      test('tokenizes ${jsonEncode(text)}', () {
        final List<int> expected = (testCase['tokens'] as List<dynamic>).cast<int>();
        expect(tokenizer.tokenize(text: text).toList(), expected);
      });
    }

    test('text without Burmese characters is not speakable', () {
      expect(tokenizer.hasSpeakableText(text: 'abc'), isFalse);
      expect(tokenizer.hasSpeakableText(text: '   '), isFalse);
      expect(tokenizer.hasSpeakableText(text: 'က'), isTrue);
      expect(tokenizer.hasSpeakableText(text: '၁၂'), isTrue);
      // ပုဒ်ဖြတ်သက်သက် — model ကို ဆူညံသံသာ ထုတ်စေမည်
      expect(tokenizer.hasSpeakableText(text: 'hello။ ၊ !'), isFalse);
    });
  });

  test('InverseStft matches numpy irfft + overlap-add', () {
    final Map<String, dynamic> istft = fixture['istft'] as Map<String, dynamic>;
    final int frames = istft['frames'] as int;
    final InverseStft inverse =
        InverseStft(fftSize: MyanmarTtsConfig.FFT_SIZE, hopLength: MyanmarTtsConfig.HOP_LENGTH);
    final int bins = inverse.binCount;

    // make_dart_fixtures.py ၏ closed-form spectrum ကို တူညီစွာ ပြန်တည်ဆောက်သည်။
    final Float32List real = Float32List(bins * frames);
    final Float32List imag = Float32List(bins * frames);
    for (int bin = 0; bin < bins; bin++) {
      for (int frame = 0; frame < frames; frame++) {
        real[bin * frames + frame] = math.sin(0.013 * bin + 0.7 * frame) * math.exp(-bin / 400.0);
        imag[bin * frames + frame] = math.cos(0.007 * bin - 0.3 * frame) * math.exp(-bin / 300.0);
      }
    }

    final Float32List audio = inverse.synthesize(real: real, imag: imag, frames: frames);
    final List<double> expected = (istft['audio'] as List<dynamic>).cast<num>().map((num v) => v.toDouble()).toList();

    expect(audio.length, expected.length);
    double maxDiff = 0;
    for (int index = 0; index < audio.length; index++) {
      maxDiff = math.max(maxDiff, (audio[index] - expected[index]).abs());
    }
    expect(maxDiff, lessThan(_ISTFT_TOLERANCE));
  });
}
