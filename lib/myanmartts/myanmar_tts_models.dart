import 'dart:typed_data';

/// MyanmarTTS ONNX model လေးခု (encoder, prenet, estimator, vocos) နှင့် ဆက်သွယ်သည့် boundary။
/// Interface ခွဲထားခြင်းမှာ speaker pipeline ကို native plugin မလိုဘဲ test လုပ်နိုင်ရန် ဖြစ်သည်။
abstract interface class MyanmarTtsModels {
  /// Asset များကို ဖတ်ပြီး ONNX session များ ဖန်တီးသည် — ပထမအကြိမ်တွင် ~97 MB ကူးရသဖြင့် ကြာနိုင်သည်။
  Future<void> load();

  Future<EncoderOutput> encode({required Int64List tokens, required Float32List speaker});

  /// Flow-matching step [flowSteps] ခုနှင့် vocoder ကို run ပြီး complex spectrum ကို ပြန်ပေးသည်။
  /// Step တစ်ခုချင်းကြားတွင် [isCancelled] ကို စစ်ပြီး true ဖြစ်ပါက [SynthesisCancelledException] ပစ်သည်။
  Future<StftSpectrum> generateSpectrum({
    required Float32List alignedFeatures,
    required int frames,
    required Float32List noise,
    required int flowSteps,
    required double cfgStrength,
    required Float32List speaker,
    required bool Function() isCancelled,
  });

  /// အသံသွင်းထားသော clip ၏ magnitude STFT (`[binCount, frames]`) မှ speaker embedding (အသံ လက်ဗွေ) တွက်သည်။
  Future<Float32List> embedSpeaker({required Float32List magnitude, required int frames});

  Future<void> dispose();
}

class EncoderOutput {
  const EncoderOutput({required this.features, required this.logDurations});

  /// `[MEL_CHANNELS, tokens]` row-major။
  final Float32List features;
  final Float32List logDurations;
}

class StftSpectrum {
  const StftSpectrum({required this.real, required this.imag, required this.frames});

  /// `[binCount, frames]` row-major။
  final Float32List real;
  final Float32List imag;
  final int frames;
}

/// Model load/run မအောင်မြင်ခြင်း — [platformMessage] ကို UI တွင် မပြောင်းဘဲ ပြရန် ထိန်းထားသည်။
class MyanmarTtsException implements Exception {
  const MyanmarTtsException({required this.operation, this.platformMessage});

  final String operation;
  final String? platformMessage;

  @override
  String toString() => 'MyanmarTtsException($operation): $platformMessage';
}

/// အသုံးပြုသူ ရပ်လိုက်၍ ထုတ်လုပ်မှု ရပ်တန့်ခြင်း — အမှားမဟုတ်ပါ။
class SynthesisCancelledException implements Exception {
  const SynthesisCancelledException();
}
