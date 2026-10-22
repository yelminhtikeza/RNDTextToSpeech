import 'dart:math' as math;
import 'dart:typed_data';

/// Encoder ၏ token တစ်ခုချင်းစီ feature ကို ခန့်မှန်းထားသော ကြာချိန် (frame) အတိုင်း ထပ်ပွားပေးသည်
/// (StableTTS `synthesise` ၏ `generate_path` + matmul နှင့် တူညီ)။
/// ONNX graph ထဲတွင် မထည့်ခြင်းမှာ output length သည် data ပေါ်မူတည်၍ export ခက်သောကြောင့် ဖြစ်သည်။
class LengthRegulator {
  const LengthRegulator();

  /// `ceil(exp(logw)) * lengthScale` ကို frame အရေအတွက် ကိန်းပြည့်အဖြစ် ပြန်ပေးသည်။
  /// [lengthScale] 1.0 တွင် Python reference နှင့် အတိအကျ တူသည်။ အခြားတန်ဖိုးတွင် round လုပ်သဖြင့်
  /// token အချို့ 0 frame ဖြစ်နိုင်သော်လည်း စုစုပေါင်း အနည်းဆုံး 1 frame ရှိစေသည်။
  List<int> durations({required Float32List logDurations, required double lengthScale}) {
    final List<int> frames = <int>[
      for (final double logDuration in logDurations)
        (math.exp(logDuration).ceilToDouble() * lengthScale).round(),
    ];
    if (frames.fold<int>(0, (int sum, int value) => sum + value) == 0 && frames.isNotEmpty) {
      frames[0] = 1;
    }
    return frames;
  }

  /// [features] သည် `[channels, tokens]` (row-major) ဖြစ်ပြီး `[channels, sum(durations)]` ကို ပြန်ပေးသည်။
  Float32List expand({
    required Float32List features,
    required int channels,
    required List<int> durations,
  }) {
    final int tokenCount = durations.length;
    final int frameCount = durations.fold<int>(0, (int sum, int value) => sum + value);
    final Float32List expanded = Float32List(channels * frameCount);
    for (int channel = 0; channel < channels; channel++) {
      final int sourceRow = channel * tokenCount;
      int targetIndex = channel * frameCount;
      for (int token = 0; token < tokenCount; token++) {
        final double value = features[sourceRow + token];
        for (int repeat = 0; repeat < durations[token]; repeat++) {
          expanded[targetIndex++] = value;
        }
      }
    }
    return expanded;
  }
}
