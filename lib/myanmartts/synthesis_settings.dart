import 'dart:typed_data';

import '../config/myanmartts_config.dart';

/// MyanmarTTS တစ်ကြိမ်ဖတ်ရာတွင် သုံးမည့် ချိန်ညှိချက်များ — controller → speaker → model သို့ တစ်စုတည်း ပို့ရန်။
class SynthesisSettings {
  const SynthesisSettings({
    required this.lengthScale,
    required this.speaker,
    this.flowSteps = MyanmarTtsConfig.FLOW_STEPS_DEFAULT,
    this.cfgStrength = MyanmarTtsConfig.CFG_STRENGTH_DEFAULT,
  });

  /// 1.0 = ပုံမှန်အမြန်နှုန်း၊ ငယ်လေ မြန်လေ (frame duration multiplier)။
  final double lengthScale;

  /// Flow-matching Euler step အရေအတွက် — များလေ အသံကြည်လေ၊ နှေးလေ (အချိန်သည် step နှင့် အချိုးကျ)။
  final int flowSteps;

  /// Classifier-free guidance — စာနှင့် reference အသံကို မည်မျှ တင်းကျပ်စွာ လိုက်မည်နည်း။
  /// 1.0 = guidance မရှိ၊ ~3 = မျှတ၊ မြင့်လွန်းလျှင် အသံ တင်းမာ/သတ္တုသံ ဖြစ်နိုင်။
  final double cfgStrength;

  /// ရွေးထားသော အသံ၏ လက်ဗွေ (speaker embedding၊ [MyanmarTtsConfig.SPEAKER_EMBEDDING_SIZE] ခု)။
  final Float32List speaker;
}
