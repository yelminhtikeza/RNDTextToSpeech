import '../config/tts_config.dart';

enum SpeechStatus {
  /// Engine တစ်ခုချင်းစီကို မြန်မာဘာသာ ပံ့ပိုးမှု စစ်နေဆဲ။
  detecting,
  ready,
  speaking,

  /// Engine ရှိသော်လည်း မြန်မာဘာသာ ပံ့ပိုးသည့် engine မရှိ။
  noBurmeseEngine,

  /// Engine စာရင်းကိုပင် ဖတ်မရ။
  detectionFailed,
}

/// UI က ဘာသာပြန်စာသားအဖြစ် ပြောင်းပြမည့် အမှားအမျိုးအစား —
/// state ထဲတွင် စာသားမထည့်ခြင်းမှာ စာသားကို l10n ဖိုင်တစ်နေရာတည်းမှသာ ယူရန် ဖြစ်သည်။
enum SpeechError { emptyText, textTooLong, speakFailed }

class BurmeseSpeechState {
  const BurmeseSpeechState({
    required this.status,
    this.burmeseEngines = const <String>[],
    this.selectedEngine,
    this.speechRate = TtsConfig.SPEECH_RATE_DEFAULT,
    this.pitch = TtsConfig.PITCH_DEFAULT,
    this.maxInputLength = TtsConfig.MAX_INPUT_LENGTH_FALLBACK,
    this.error,
    this.platformMessage,
  });

  const BurmeseSpeechState.initial() : this(status: SpeechStatus.detecting);

  final SpeechStatus status;

  /// မြန်မာဘာသာ ပံ့ပိုးကြောင်း စစ်ဆေးပြီးသော engine များသာ။
  final List<String> burmeseEngines;
  final String? selectedEngine;
  final double speechRate;
  final double pitch;
  final int maxInputLength;
  final SpeechError? error;

  /// Engine မှ ပြန်လာသော မူရင်းစာ — ပြင်ဆင်ခြင်းမပြုဘဲ ပြရန်။
  final String? platformMessage;

  bool get canSpeak => status == SpeechStatus.ready;

  bool get isSpeaking => status == SpeechStatus.speaking;

  BurmeseSpeechState copyWith({
    SpeechStatus? status,
    List<String>? burmeseEngines,
    String? selectedEngine,
    double? speechRate,
    double? pitch,
    int? maxInputLength,
  }) {
    // error/platformMessage ကို copy မလုပ်ခြင်းမှာ လုပ်ဆောင်ချက်အသစ်တိုင်း ယခင်အမှားကို ရှင်းရန် ဖြစ်သည်။
    return BurmeseSpeechState(
      status: status ?? this.status,
      burmeseEngines: burmeseEngines ?? this.burmeseEngines,
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
      burmeseEngines: burmeseEngines,
      selectedEngine: selectedEngine,
      speechRate: speechRate,
      pitch: pitch,
      maxInputLength: maxInputLength,
      error: error,
      platformMessage: platformMessage,
    );
  }
}
