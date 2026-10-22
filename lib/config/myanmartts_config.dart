/// ဖုန်းပေါ်တွင် run သော MyanmarTTS (freococo/MyanmarTTS, CC0) ၏ ပုံသေတန်ဖိုးများ။
/// Model ကိုယ်တိုင်နှင့် ချိတ်ဆက်နေသော တန်ဖိုးများဖြစ်၍ `tools/myanmartts_onnx/` ရှိ export script နှင့် အမြဲ ကိုက်ညီရမည်။
abstract final class MyanmarTtsConfig {
  /// `flutter_onnxruntime` သည် asset ကို temp folder သို့ ဖိုင်အမည်ဖြင့် cache လုပ်သည်။
  /// Model ပြောင်းလျှင် အဟောင်းကို ဆက်မသုံးမိစေရန် ဖိုင်အမည်တွင် version ထည့်ထားသည် — model ပြောင်းတိုင်း တိုးရန်။
  static const String ENCODER_ASSET = 'assets/models/myanmartts_v1_encoder.onnx';
  static const String PRENET_ASSET = 'assets/models/myanmartts_v1_prenet.onnx';
  static const String ESTIMATOR_ASSET = 'assets/models/myanmartts_v1_estimator.onnx';
  static const String VOCODER_ASSET = 'assets/models/myanmartts_v1_vocos.onnx';

  static const int SAMPLE_RATE = 44100;
  static const int MEL_CHANNELS = 128;
  static const int FFT_SIZE = 2048;
  static const int HOP_LENGTH = 512;

  /// Flow-matching Euler step — ပုံသေ 16 ကို နားထောင်စမ်းသပ်ပြီး ရွေးထားသည်
  /// (docs/myanmartts-onnx/listening ရှိ ဖိုင် 5)။ Slider အပိုင်းအခြားနှင့် အဆင့် (4) သည် HF Space အတိုင်း။
  static const int FLOW_STEPS_DEFAULT = 16;
  static const int FLOW_STEPS_MIN = 4;
  static const int FLOW_STEPS_MAX = 32;
  static const int FLOW_STEPS_SLIDER_DIVISIONS = 7;

  /// Classifier-free guidance — ပုံသေနှင့် အပိုင်းအခြား (အဆင့် 0.5) သည် HF Space အတိုင်း။
  static const double CFG_STRENGTH_DEFAULT = 3.0;
  static const double CFG_STRENGTH_MIN = 1.0;
  static const double CFG_STRENGTH_MAX = 5.0;
  static const int CFG_SLIDER_DIVISIONS = 8;

  /// Token များကြားတွင် ထည့်သော blank token (StableTTS `intersperse`)။
  static const int BLANK_TOKEN = 0;

  /// Attention သည် frame အရေအတွက်၏ နှစ်ထပ်ကိန်းအလိုက် memory သုံးသဖြင့် စာရှည်ကို အပိုင်းခွဲ၍ ထုတ်သည်။
  /// စာလုံး 180 သည် အသံ ~18 စက္ကန့်ဖြစ်ပြီး PC ပေါ်တွင် စမ်းသပ်ပြီးဖြစ်သည်။ ဖုန်း memory အတွက် ထိုထက်နည်းအောင် ထားသည်။
  static const int MAX_CHUNK_CHARACTERS = 120;

  /// ONNX Runtime CPU thread — ဖုန်း၏ big core အရေအတွက်ခန့်။
  static const int INTRA_OP_THREADS = 4;

  /// Download လုပ်သော ဖိုင်အမည် — `<prefix><yyyyMMdd_HHmmss>.wav`။
  static const String DOWNLOAD_FILE_PREFIX = 'myanmartts_';
  static const String DOWNLOAD_FILE_EXTENSION = '.wav';
  static const String DOWNLOAD_TIMESTAMP_PATTERN = 'yyyyMMdd_HHmmss';
  static const String WAV_MIME_TYPE = 'audio/wav';

  /// Waveform တွင် ဆွဲမည့် bar အရေအတွက် — ဖုန်းအကျယ်တွင် bar တစ်ခု ~3 px ခန့်ဖြစ်စေရန်။
  static const int WAVEFORM_BAR_COUNT = 120;
}
