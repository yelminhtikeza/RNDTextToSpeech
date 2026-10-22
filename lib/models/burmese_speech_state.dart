import '../config/tts_config.dart';

enum SpeechStatus {
  /// Android TTS engine တစ်ခုချင်းစီကို မြန်မာဘာသာ ပံ့ပိုးမှု စစ်နေဆဲ။
  detecting,

  /// ဖုန်းပေါ် MyanmarTTS model များကို load လုပ်နေဆဲ (ပထမအကြိမ်တွင် ~97 MB ကူးရ၍ ကြာနိုင်)။
  loadingModel,
  ready,
  speaking,

  /// ရွေးထားသော engine ကို သုံး၍မရ — အကြောင်းရင်းကို [SpeechError] တွင် ကြည့်ပါ။
  /// Engine စာရင်းကို ဆက်ပြထားသဖြင့် အခြား engine သို့ ပြောင်းနိုင်သည်။
  engineUnavailable,
}

/// UI က ဘာသာပြန်စာသားအဖြစ် ပြောင်းပြမည့် အမှားအမျိုးအစား —
/// state ထဲတွင် စာသားမထည့်ခြင်းမှာ စာသားကို l10n ဖိုင်တစ်နေရာတည်းမှသာ ယူရန် ဖြစ်သည်။
enum SpeechError {
  emptyText,
  textTooLong,

  /// မြန်မာ (Unicode) စာလုံး မပါ — Zawgyi သို့မဟုတ် အင်္ဂလိပ်သက်သက်။
  noSpeakableText,
  speakFailed,

  /// ဖုန်းပေါ် model ကို load လုပ်၍ မရ။
  modelLoadFailed,

  /// Android engine က my-MM ကို လက်မခံ။
  languageUnavailable,
}

class BurmeseSpeechState {
  const BurmeseSpeechState({
    required this.status,
    this.engines = const <String>[],
    this.selectedEngine,
    this.speechRate = TtsConfig.SPEECH_RATE_DEFAULT,
    this.pitch = TtsConfig.PITCH_DEFAULT,
    this.maxInputLength = TtsConfig.MAX_INPUT_LENGTH_FALLBACK,
    this.error,
    this.platformMessage,
  });

  const BurmeseSpeechState.initial() : this(status: SpeechStatus.detecting);

  final SpeechStatus status;

  /// [TtsConfig.ON_DEVICE_ENGINE_ID] နှင့် မြန်မာဘာသာ ပံ့ပိုးကြောင်း စစ်ပြီးသော Android engine များ။
  final List<String> engines;
  final String? selectedEngine;
  final double speechRate;
  final double pitch;
  final int maxInputLength;
  final SpeechError? error;

  /// Engine မှ ပြန်လာသော မူရင်းစာ — ပြင်ဆင်ခြင်းမပြုဘဲ ပြရန်။
  final String? platformMessage;

  bool get canSpeak => status == SpeechStatus.ready;

  bool get isSpeaking => status == SpeechStatus.speaking;

  bool get isOnDeviceSelected => selectedEngine == TtsConfig.ON_DEVICE_ENGINE_ID;

  /// MyanmarTTS model တွင် pitch ထိန်းချုပ်မှု မပါသဖြင့် Android engine တွင်သာ ရသည်။
  bool get supportsPitch => !isOnDeviceSelected;

  /// Engine ရှာပြီးမှ (load မပြီးသေးလည်း) engine ပြောင်းရန် စာရင်းကို ပြနိုင်သည်။
  bool get canChooseEngine => engines.isNotEmpty && status != SpeechStatus.detecting && !isSpeaking;

  BurmeseSpeechState copyWith({
    SpeechStatus? status,
    List<String>? engines,
    String? selectedEngine,
    double? speechRate,
    double? pitch,
    int? maxInputLength,
  }) {
    // error/platformMessage ကို copy မလုပ်ခြင်းမှာ လုပ်ဆောင်ချက်အသစ်တိုင်း ယခင်အမှားကို ရှင်းရန် ဖြစ်သည်။
    return BurmeseSpeechState(
      status: status ?? this.status,
      engines: engines ?? this.engines,
      selectedEngine: selectedEngine ?? this.selectedEngine,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      maxInputLength: maxInputLength ?? this.maxInputLength,
    );
  }

  BurmeseSpeechState withError({
    required SpeechError error,
    required SpeechStatus status,
    String? platformMessage,
  }) {
    return BurmeseSpeechState(
      status: status,
      engines: engines,
      selectedEngine: selectedEngine,
      speechRate: speechRate,
      pitch: pitch,
      maxInputLength: maxInputLength,
      error: error,
      platformMessage: platformMessage,
    );
  }
}
