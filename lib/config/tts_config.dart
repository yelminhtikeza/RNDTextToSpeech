/// TTS အတွက် ပုံသေတန်ဖိုးများ — code ထဲတွင် hard-code မလုပ်ရန် ဤနေရာ၌သာ စုထားသည်။
abstract final class TtsConfig {
  /// ဖုန်းပေါ် MyanmarTTS ဖတ်နိုင်သော ဘာသာ — model ကို မြန်မာစာဖြင့်သာ train ထားသည်။
  static const String BURMESE_LANGUAGE_TAG = 'my-MM';

  /// Android engine ရွေးချိန်တွင် ဤဘာသာ (`my`၊ `my-MM` စသည်) ပါပါက ပုံသေ ရွေးပေးသည် — app ၏ အဓိက အသုံးပြုသူများ မြန်မာ ဖြစ်၍။
  static const String BURMESE_LANGUAGE_CODE = 'my';

  /// Android engine ၏ အသံ dropdown တွင် "ပုံသေ" (ဘာသာအတွက် engine ရွေးသော အသံ) ကို ကိုယ်စားပြုသည် —
  /// Android voice အမည်များ (`en-us-x-...`) နှင့် မတိုက်နိုင်သော ပုံစံ။
  static const String ENGINE_DEFAULT_VOICE_ID = 'engine-default';

  /// Android `TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED` — data မဒေါင်းရသေးသော အသံ (ရွေးလျှင် မထွက်) ကို ဖယ်ရန်။
  static const String VOICE_FEATURE_NOT_INSTALLED = 'notInstalled';

  /// flutter_tts `getVoices` ၏ map key များနှင့် feature ခွဲသည့် အမှတ်အသား (plugin source ကြည့်ပါ)။
  static const String VOICE_KEY_NAME = 'name';
  static const String VOICE_KEY_LOCALE = 'locale';
  static const String VOICE_KEY_NETWORK_REQUIRED = 'network_required';
  static const String VOICE_KEY_FEATURES = 'features';
  static const String VOICE_NETWORK_REQUIRED_TRUE = '1';
  static const String VOICE_FEATURE_SEPARATOR = '\t';

  /// BCP 47 tag ၏ subtag ခွဲသည့် အမှတ်အသား (ဥပမာ `en-US`)။
  static const String LANGUAGE_TAG_SEPARATOR = '-';

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

  /// Engine စာရင်းတွင် ဖုန်းပေါ် MyanmarTTS ကို ကိုယ်စားပြုသည့် ID — Android package name နှင့် မတိုက်စေရန်
  /// dot ပါသော်လည်း package မဟုတ်သည့် ပုံစံ ရွေးထားသည်။
  static const String ON_DEVICE_ENGINE_ID = 'on-device.myanmartts';

  /// flutter_tts `speak` သည် အောင်မြင်ပါက 1 ပြန်ပေးသည်။
  static const int PLATFORM_SUCCESS = 1;

  /// Engine ကို WAV ဖိုင်သို့ ထုတ်ခိုင်းပြီး ဤအချိန်အတွင်း မစပါက ဖိုင်ထုတ်မှု မပံ့ပိုးဟု ယူဆသည် —
  /// Android `synthesizeToFile` က ERROR ချက်ချင်းပြန်လျှင် flutter_tts သည် callback မပို့သဖြင့် ကိုယ်တိုင် ကန့်သတ်ရသည်။
  static const Duration SYNTHESIS_START_TIMEOUT = Duration(seconds: 5);

  /// Engine ထုတ်သော နောက်ဆုံးအသံ၏ ယာယီ WAV ဖိုင် — ထုတ်တိုင်း အစားထိုးသည် (app cache ထဲတွင်သာ)။
  static const String SYNTHESIS_TEMPORARY_FILE = 'engine_synthesis.wav';
}
