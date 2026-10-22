import '../config/myanmartts_config.dart';
import '../config/tts_config.dart';
import '../myanmartts/waveform_summary.dart';

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
    this.flowSteps = MyanmarTtsConfig.FLOW_STEPS_DEFAULT,
    this.cfgStrength = MyanmarTtsConfig.CFG_STRENGTH_DEFAULT,
    this.maxInputLength = TtsConfig.MAX_INPUT_LENGTH_FALLBACK,
    this.hasDownloadableAudio = false,
    this.waveform = WaveformSummary.empty,
    this.isSavingAudio = false,
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

  /// MyanmarTTS သီးသန့် — အသံအရည်အသွေးနှင့် အမြန်နှုန်း ချိန်ခွင်လျှာ။
  final int flowSteps;
  final double cfgStrength;
  final int maxInputLength;

  /// နောက်ဆုံး အဆုံးထိ ဖတ်ခဲ့သော MyanmarTTS အသံ ရှိ/မရှိ — စာပြင်လျှင်၊ engine ပြောင်းလျှင် ရှင်းသည်။
  final bool hasDownloadableAudio;

  /// ထုတ်ထားသော (download လုပ်မည့်) အသံ၏ waveform — [hasDownloadableAudio] နှင့် အတူ ရှင်းသည်။
  final WaveformSummary waveform;
  final bool isSavingAudio;
  final SpeechError? error;

  /// Engine မှ ပြန်လာသော မူရင်းစာ — ပြင်ဆင်ခြင်းမပြုဘဲ ပြရန်။
  final String? platformMessage;

  bool get canSpeak => status == SpeechStatus.ready;

  bool get isSpeaking => status == SpeechStatus.speaking;

  bool get isOnDeviceSelected => selectedEngine == TtsConfig.ON_DEVICE_ENGINE_ID;

  /// MyanmarTTS model တွင် pitch ထိန်းချုပ်မှု မပါသဖြင့် Android engine တွင်သာ ရသည်။
  bool get supportsPitch => !isOnDeviceSelected;

  /// Step နှင့် CFG သည် MyanmarTTS model ၏ ချိန်ညှိချက်ဖြစ်၍ Android engine တွင် မရှိ။
  bool get supportsQualityControls => isOnDeviceSelected;

  /// ထုတ်ထားသော အသံကို MyanmarTTS တွင်သာ ရနိုင်သည် — Android engine များ၏ ဖိုင်ထုတ်မှု မယုံကြည်ရ၍ (third-party)။
  bool get supportsDownload => isOnDeviceSelected;

  bool get canDownload => supportsDownload && hasDownloadableAudio && !isSpeaking && !isSavingAudio;

  /// Engine ရှာပြီးမှ (load မပြီးသေးလည်း) engine ပြောင်းရန် စာရင်းကို ပြနိုင်သည်။
  bool get canChooseEngine => engines.isNotEmpty && status != SpeechStatus.detecting && !isSpeaking;

  BurmeseSpeechState copyWith({
    SpeechStatus? status,
    List<String>? engines,
    String? selectedEngine,
    double? speechRate,
    double? pitch,
    int? flowSteps,
    double? cfgStrength,
    int? maxInputLength,
    bool? hasDownloadableAudio,
    WaveformSummary? waveform,
    bool? isSavingAudio,
  }) {
    // error/platformMessage ကို copy မလုပ်ခြင်းမှာ လုပ်ဆောင်ချက်အသစ်တိုင်း ယခင်အမှားကို ရှင်းရန် ဖြစ်သည်။
    return BurmeseSpeechState(
      status: status ?? this.status,
      engines: engines ?? this.engines,
      selectedEngine: selectedEngine ?? this.selectedEngine,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      flowSteps: flowSteps ?? this.flowSteps,
      cfgStrength: cfgStrength ?? this.cfgStrength,
      maxInputLength: maxInputLength ?? this.maxInputLength,
      hasDownloadableAudio: hasDownloadableAudio ?? this.hasDownloadableAudio,
      waveform: waveform ?? this.waveform,
      isSavingAudio: isSavingAudio ?? this.isSavingAudio,
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
      flowSteps: flowSteps,
      cfgStrength: cfgStrength,
      maxInputLength: maxInputLength,
      hasDownloadableAudio: hasDownloadableAudio,
      waveform: waveform,
      isSavingAudio: isSavingAudio,
      error: error,
      platformMessage: platformMessage,
    );
  }
}
