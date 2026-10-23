import 'dart:async';

import 'dart:typed_data';

import 'package:rnd_text_to_speech/models/engine_voice.dart';
import 'package:rnd_text_to_speech/myanmartts/wav_encoder.dart';
import 'package:rnd_text_to_speech/myanmartts/waveform_summary.dart';
import 'package:rnd_text_to_speech/services/tts_service.dart';

/// စက်အစစ်မလိုဘဲ engine အခြေအနေအမျိုးမျိုးကို ပြန်ဖန်တီးရန် fake။
class FakeTtsService implements TtsService {
  FakeTtsService({
    this.engines = const <String>[],
    this.languagesByEngine = const <String, List<String>>{},
    this.rejectedLanguages = const <String>{},
    this.maxInputLength = 4000,
    this.isSpeakSuccessful = true,
    this.failingOperation,
    this.exportingEngines = const <String>{},
    this.voicesByEngine = const <String, List<EngineVoice>>{},
    this.rejectedVoices = const <String>{},
  });

  final Map<String, List<EngineVoice>> voicesByEngine;

  /// setVoice က 0 ပြန်ပေးမည့် အသံအမည်များ။
  final Set<String> rejectedVoices;

  /// setLanguage ခေါ်လျှင် engine ၏ ပုံသေ (null) သို့ ပြန်ရောက်သည် — Android အတိုင်း။
  String? activeVoice;

  /// ဖတ်ချိန်/ဖိုင်ထုတ်ချိန်တွင် engine ၌ ရှိနေသော အသံ။
  String? voiceWhenSpoken;
  String? voiceWhenSynthesized;

  /// WAV ဖိုင်ထုတ်နိုင်သော engine များ — မပါသော engine သည် synthesizeAudio တွင် null (မပံ့ပိုး) ပြန်ပေးသည်။
  final Set<String> exportingEngines;

  /// ဖိုင်ထုတ်ပေးမည့် အသံ — 1 စက္ကန့် (22.05 kHz၊ Google engine ကဲ့သို့)၊ amplitude 0.25။
  static final SpokenAudio exportedAudio = spokenAudioFromEngineWav(
    wav: const WavEncoder().encodePcm16(samples: Float32List.fromList(List<double>.filled(22050, 0.25)), sampleRate: 22050),
    barsPerSecond: 20,
  );

  int synthesizeCallCount = 0;
  int speakCallCount = 0;

  /// သတ်မှတ်ထားပါက synthesizeAudio သည် stop() ခေါ်သည်အထိ ဆိုင်းငံ့နေမည်။
  Completer<void>? pendingSynthesis;

  final List<String> engines;
  /// Engine တစ်ခုချင်း ပံ့ပိုးသည့် ဘာသာ — မပါသော engine သည် ဘာသာ မရှိ။
  final Map<String, List<String>> languagesByEngine;

  /// စာရင်းတွင် ပါသော်လည်း setLanguage က 0 ပြန်ပေးမည့် ဘာသာ (engine ၏ voice data မထည့်ရသေးခြင်းမျိုး)။
  final Set<String> rejectedLanguages;
  final int maxInputLength;
  final bool isSpeakSuccessful;

  /// ဤ operation ကို ခေါ်လျှင် [TtsServiceException] ပစ်မည်။
  final String? failingOperation;

  String? activeEngine;
  String? activeLanguage;
  String? spokenText;
  double? appliedRate;
  double? appliedPitch;
  int stopCallCount = 0;

  /// သတ်မှတ်ထားပါက speak() သည် stop() ခေါ်သည်အထိ ဆိုင်းငံ့နေမည် — plugin ၏ အပြုအမူအတိုင်း။
  Completer<bool>? pendingSpeak;

  void _failIf({required String operation}) {
    if (failingOperation == operation) {
      throw TtsServiceException(operation: operation, platformMessage: '$operation failed');
    }
  }

  @override
  Future<List<String>> getEngineNames() async {
    _failIf(operation: 'getEngines');
    return engines;
  }

  @override
  Future<void> selectEngine({required String engineName}) async {
    _failIf(operation: 'setEngine');
    activeEngine = engineName;
  }

  @override
  Future<List<String>> getLanguages() async {
    _failIf(operation: 'getLanguages');
    return languagesByEngine[activeEngine] ?? const <String>[];
  }

  @override
  Future<bool> setLanguage({required String languageTag}) async {
    final bool isSupported = (languagesByEngine[activeEngine] ?? const <String>[]).contains(languageTag) &&
        !rejectedLanguages.contains(languageTag);
    if (isSupported) {
      activeLanguage = languageTag;
      activeVoice = null;
    }
    return isSupported;
  }

  @override
  Future<List<EngineVoice>> getVoices() async {
    _failIf(operation: 'getVoices');
    return voicesByEngine[activeEngine] ?? const <EngineVoice>[];
  }

  @override
  Future<bool> setVoice({required EngineVoice voice}) async {
    if (rejectedVoices.contains(voice.name)) return false;
    activeVoice = voice.name;
    return true;
  }

  @override
  Future<void> setSpeechRate({required double rate}) async => appliedRate = rate;

  @override
  Future<void> setPitch({required double pitch}) async => appliedPitch = pitch;

  @override
  Future<int> getMaxInputLength() async => maxInputLength;

  @override
  Future<bool> speak({required String text}) async {
    _failIf(operation: 'speak');
    speakCallCount++;
    voiceWhenSpoken = activeVoice;
    spokenText = text;
    final Completer<bool>? pending = pendingSpeak;
    return pending == null ? isSpeakSuccessful : pending.future;
  }

  @override
  Future<SpokenAudio?> synthesizeAudio({required String text}) async {
    _failIf(operation: 'synthesizeToFile');
    synthesizeCallCount++;
    final Completer<void>? pending = pendingSynthesis;
    if (pending != null) {
      await pending.future;
      return null;
    }
    if (!exportingEngines.contains(activeEngine)) return null;
    voiceWhenSynthesized = activeVoice;
    spokenText = text;
    return exportedAudio;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    pendingSynthesis?.complete();
    pendingSynthesis = null;
    // Plugin သည် stop တွင် ဆိုင်းငံ့နေသော speak ကို 0 (false) ဖြင့် ပြီးစေသည်။
    pendingSpeak?.complete(false);
    pendingSpeak = null;
  }
}
