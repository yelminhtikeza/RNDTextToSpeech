import '../config/myanmartts_config.dart';
import '../config/tts_config.dart';
import '../myanmartts/waveform_summary.dart';

enum SpeechStatus {
  /// Engine စာရင်း ရှာနေဆဲ သို့မဟုတ် Android engine/ဘာသာ ပြောင်းနေဆဲ။
  detecting,

  /// ဖုန်းပေါ် MyanmarTTS model များကို load လုပ်နေဆဲ (ပထမအကြိမ်တွင် ~97 MB ကူးရ၍ ကြာနိုင်)။
  loadingModel,
  ready,
  speaking,

  /// ထုတ်ပြီးသား အသံကို ပြန်ဖွင့်နေသည် (model ကို ထပ်မ run ပါ)။
  replaying,

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

  /// Android engine က ရွေးထားသော ဘာသာကို လက်မခံ။
  languageUnavailable,

  /// Android engine က ဘာသာ တစ်ခုမျှ မပြန်ပေး (သို့မဟုတ် စာရင်း ယူ၍ မရ)။
  noLanguages,

  /// MyanmarTTS အသံစာရင်း မရသေး/မရ (load မပြီး သို့မဟုတ် မအောင်မြင်)။
  voiceUnavailable,

  /// Android engine က ဖတ်ခဲ့သော အသံကို ပြန်ဖွင့်/download အတွက် ဖိုင်အဖြစ် မပေးနိုင်။
  audioUnavailable,
}

class BurmeseSpeechState {
  const BurmeseSpeechState({
    required this.status,
    this.engines = const <String>[],
    this.selectedEngine,
    this.languages = const <String>[],
    this.selectedLanguage,
    this.speechRate = TtsConfig.SPEECH_RATE_DEFAULT,
    this.pitch = TtsConfig.PITCH_DEFAULT,
    this.flowSteps = MyanmarTtsConfig.FLOW_STEPS_DEFAULT,
    this.cfgStrength = MyanmarTtsConfig.CFG_STRENGTH_DEFAULT,
    this.maxInputLength = TtsConfig.MAX_INPUT_LENGTH_FALLBACK,
    this.hasDownloadableAudio = false,
    this.waveform = WaveformSummary.empty,
    this.playbackPosition = Duration.zero,
    this.isPaused = false,
    this.supportsAudioExport = true,
    this.hasRenderableSpeech = false,
    this.isPreparingAudio = false,
    this.isSavingAudio = false,
    this.error,
    this.platformMessage,
  });

  const BurmeseSpeechState.initial() : this(status: SpeechStatus.detecting);

  final SpeechStatus status;

  /// [TtsConfig.ON_DEVICE_ENGINE_ID] နှင့် ထည့်သွင်းထားသော Android engine အားလုံး (ဘာသာဖြင့် မစစ်ထုတ်)။
  final List<String> engines;
  final String? selectedEngine;

  /// ရွေးထားသော engine ပံ့ပိုးသည့် ဘာသာများ (BCP 47 tag) — engine ပြောင်းတိုင်း ပြန်ယူသည်။
  final List<String> languages;
  final String? selectedLanguage;
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

  /// [waveform] အတွင်း ဖွင့်နေသော နေရာ — ဖတ်/ပြန်ဖွင့် မလုပ်နေချိန်တွင် ပြန်ဖွင့်မည့် အစ (seek ထားသည့်နေရာ) ဖြစ်သည်။
  final Duration playbackPosition;

  /// ဖတ်နေ/ပြန်ဖွင့်နေစဉ် ခေတ္တရပ်ထားခြင်း — status ကို မပြောင်းဘဲ ထားသဖြင့် Stop နှင့် အခြား ပိတ်ထားချက်များ ဆက်အလုပ်လုပ်သည်။
  final bool isPaused;

  /// ရွေးထားသော engine ၏ အသံကို app ထဲသို့ ရနိုင်/မရနိုင် (waveform၊ player၊ download အတွက်)။
  /// MyanmarTTS အမြဲရ၊ Android engine သည် WAV ဖိုင်ထုတ်မှု မအောင်မြင်ဖူးမှ false ဖြစ်ပြီး speak သို့ ပြောင်းဖတ်သည်။
  final bool supportsAudioExport;

  /// Android engine က အဆုံးထိ အသံထွက်ဖတ်ပြီး ဖိုင်မထုတ်ရသေး — Play/Download နှိပ်မှသာ ထုတ်သည် (engine ကို နှစ်ခါ အလကား မခိုင်းရန်)။
  final bool hasRenderableSpeech;

  /// Play/Download အတွက် engine ဖိုင်ထုတ်နေဆဲ။
  final bool isPreparingAudio;
  final bool isSavingAudio;
  final SpeechError? error;

  /// Engine မှ ပြန်လာသော မူရင်းစာ — ပြင်ဆင်ခြင်းမပြုဘဲ ပြရန်။
  final String? platformMessage;

  bool get canSpeak => status == SpeechStatus.ready;

  bool get isSpeaking => status == SpeechStatus.speaking;

  bool get isReplaying => status == SpeechStatus.replaying;

  /// ဖတ်နေစဉ် သို့မဟုတ် ပြန်ဖွင့်နေစဉ် — Stop ခလုတ် ဖွင့်ရန်နှင့် ချိန်ညှိချက်များ ပိတ်ရန်။
  bool get isPlayingAudio => isSpeaking || isReplaying;

  /// ပြန်ဖွင့်/download လုပ်စရာ အသံ ရှိခြင်း — ထုတ်ပြီးသား သို့မဟုတ် တောင်းလျှင် ထုတ်နိုင်သော။
  bool get hasPlayableAudio => hasDownloadableAudio || hasRenderableSpeech;

  bool get canReplay => hasPlayableAudio && status == SpeechStatus.ready && !isPreparingAudio && !isSavingAudio;

  /// App ၏ player ဖြင့် ဖွင့်နေခြင်း — ပြန်ဖွင့်ခြင်း (engine မရွေး) သို့မဟုတ် MyanmarTTS ဖတ်နေခြင်း။
  /// Android engine ကိုယ်တိုင် speaker သို့ ဖတ်နေစဉ် (fallback) သို့မဟုတ် ဖိုင်ထုတ်နေစဉ် မဟုတ်။
  bool get isAppPlayerActive => isReplaying || (isSpeaking && isOnDeviceSelected);

  /// App ၏ player တွင်သာ ခေတ္တရပ်နိုင်သည် — flutter_tts ၏ Android pause မယုံကြည်ရ၍။
  bool get canPause => isAppPlayerActive;

  /// Seek လုပ်ရန် အသံ အပြည့်ရှိရမည် — အပိုင်းလိုက် ဖတ်နေစဉ် နောက်အပိုင်းများ မထုတ်ရသေး၍ မရ။
  bool get canSeek => hasDownloadableAudio && (status == SpeechStatus.ready || isReplaying);

  bool get isOnDeviceSelected => selectedEngine == TtsConfig.ON_DEVICE_ENGINE_ID;

  /// MyanmarTTS model တွင် pitch ထိန်းချုပ်မှု မပါသဖြင့် Android engine တွင်သာ ရသည်။
  bool get supportsPitch => !isOnDeviceSelected;

  /// အသံပြောင်းခြင်း (preset/အသံသွင်း) သည် MyanmarTTS တွင်သာ — Android engine ၏ အသံကို app က မထိန်းချုပ်။
  bool get supportsVoices => isOnDeviceSelected;

  /// Step နှင့် CFG သည် MyanmarTTS model ၏ ချိန်ညှိချက်ဖြစ်၍ Android engine တွင် မရှိ။
  bool get supportsQualityControls => isOnDeviceSelected;

  /// Android engine ၏ ဖိုင်ထုတ်မှုကို စမ်းပြီး မရမှသာ ဖျောက်သည် (docs/adr/0005)။
  bool get supportsDownload => supportsAudioExport;

  bool get canDownload =>
      supportsDownload && hasPlayableAudio && !isSpeaking && !isSavingAudio && !isPreparingAudio;

  /// Engine ရှာပြီးမှ (load မပြီးသေးလည်း) engine ပြောင်းရန် စာရင်းကို ပြနိုင်သည်။
  bool get canChooseEngine => engines.isNotEmpty && status != SpeechStatus.detecting && !isPlayingAudio;

  /// ဘာသာ တစ်ခုထက်ပိုမှသာ ရွေးစရာ ရှိသည် (MyanmarTTS တွင် မြန်မာ တစ်ခုတည်း)။
  bool get canChooseLanguage => languages.length > 1 && canChooseEngine;

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
    Duration? playbackPosition,
    bool? isPaused,
    bool? supportsAudioExport,
    bool? hasRenderableSpeech,
    bool? isPreparingAudio,
    bool? isSavingAudio,
  }) {
    // error/platformMessage ကို copy မလုပ်ခြင်းမှာ လုပ်ဆောင်ချက်အသစ်တိုင်း ယခင်အမှားကို ရှင်းရန် ဖြစ်သည်။
    return BurmeseSpeechState(
      status: status ?? this.status,
      engines: engines ?? this.engines,
      selectedEngine: selectedEngine ?? this.selectedEngine,
      languages: languages,
      selectedLanguage: selectedLanguage,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      flowSteps: flowSteps ?? this.flowSteps,
      cfgStrength: cfgStrength ?? this.cfgStrength,
      maxInputLength: maxInputLength ?? this.maxInputLength,
      hasDownloadableAudio: hasDownloadableAudio ?? this.hasDownloadableAudio,
      waveform: waveform ?? this.waveform,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      isPaused: isPaused ?? this.isPaused,
      supportsAudioExport: supportsAudioExport ?? this.supportsAudioExport,
      hasRenderableSpeech: hasRenderableSpeech ?? this.hasRenderableSpeech,
      isPreparingAudio: isPreparingAudio ?? this.isPreparingAudio,
      isSavingAudio: isSavingAudio ?? this.isSavingAudio,
    );
  }

  /// copyWith ၏ `??` ဖြင့် [selectedLanguage] ကို null ပြန်ထား၍ မရသဖြင့် ဘာသာစာရင်းကို ဤ method ဖြင့်သာ အစားထိုးသည် —
  /// engine အသစ်တွင် ဘာသာ မရှိပါက ယခင် engine ၏ ဘာသာ မကျန်ရစ်စေရန်။
  BurmeseSpeechState withLanguages({required List<String> languages, required String? selectedLanguage}) {
    return BurmeseSpeechState(
      status: status,
      engines: engines,
      selectedEngine: selectedEngine,
      languages: languages,
      selectedLanguage: selectedLanguage,
      speechRate: speechRate,
      pitch: pitch,
      flowSteps: flowSteps,
      cfgStrength: cfgStrength,
      maxInputLength: maxInputLength,
      hasDownloadableAudio: hasDownloadableAudio,
      waveform: waveform,
      playbackPosition: playbackPosition,
      isPaused: isPaused,
      supportsAudioExport: supportsAudioExport,
      hasRenderableSpeech: hasRenderableSpeech,
      isPreparingAudio: isPreparingAudio,
      isSavingAudio: isSavingAudio,
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
      languages: languages,
      selectedLanguage: selectedLanguage,
      speechRate: speechRate,
      pitch: pitch,
      flowSteps: flowSteps,
      cfgStrength: cfgStrength,
      maxInputLength: maxInputLength,
      hasDownloadableAudio: hasDownloadableAudio,
      waveform: waveform,
      playbackPosition: playbackPosition,
      isPaused: isPaused,
      supportsAudioExport: supportsAudioExport,
      hasRenderableSpeech: hasRenderableSpeech,
      isPreparingAudio: isPreparingAudio,
      isSavingAudio: isSavingAudio,
      error: error,
      platformMessage: platformMessage,
    );
  }
}
