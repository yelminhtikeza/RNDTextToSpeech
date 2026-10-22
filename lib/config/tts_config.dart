/// မြန်မာ TTS အတွက် ပုံသေတန်ဖိုးများ — code ထဲတွင် hard-code မလုပ်ရန် ဤနေရာ၌သာ စုထားသည်။
abstract final class TtsConfig {
  /// Android `Locale.forLanguageTag` သို့ ပို့မည့် မြန်မာ language tag။
  /// Engine အချို့က "my" ကိုသာ မှတ်ပုံတင်ထားသော်လည်း country မတူလည်း
  /// `isLanguageAvailable` သည် LANG_AVAILABLE (>= 0) ပြန်ပေးသဖြင့် "my-MM" တစ်ခုတည်း လုံလောက်သည်။
  static const String BURMESE_LANGUAGE_TAG = 'my-MM';

  /// flutter_tts သည် Android ၏ ပုံမှန်နှုန်း 1.0 ကို 0.5 အဖြစ် ပြောင်းထားသည် (plugin source ကြည့်ပါ)။
  static const double SPEECH_RATE_DEFAULT = 0.5;
  static const double SPEECH_RATE_MIN = 0.1;
  static const double SPEECH_RATE_MAX = 1.0;

  static const double PITCH_DEFAULT = 1.0;
  static const double PITCH_MIN = 0.5;
  static const double PITCH_MAX = 2.0;

  static const int SLIDER_DIVISIONS = 19;

  /// Engine က အရှည်ကန့်သတ်ချက် မပြန်ပေးနိုင်ပါက သုံးမည့်တန်ဖိုး —
  /// Android `TextToSpeech.getMaxSpeechInputLength()` ၏ ပုံသေတန်ဖိုး ဖြစ်သည်။
  static const int MAX_INPUT_LENGTH_FALLBACK = 4000;

  /// flutter_tts `speak` သည် အောင်မြင်ပါက 1 ပြန်ပေးသည်။
  static const int PLATFORM_SUCCESS = 1;
}
