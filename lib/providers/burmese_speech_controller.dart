import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../config/tts_config.dart';
import '../models/burmese_speech_state.dart';
import '../services/flutter_tts_service.dart';
import '../services/tts_service.dart';

final ttsServiceProvider = Provider<TtsService>(
  (Ref ref) => FlutterTtsService(flutterTts: FlutterTts()),
);

final burmeseSpeechControllerProvider =
    NotifierProvider<BurmeseSpeechController, BurmeseSpeechState>(BurmeseSpeechController.new);

/// မြန်မာ အသံထွက်ခြင်း၏ business logic တစ်ခုတည်းသော နေရာ —
/// engine ရှာဖွေခြင်း၊ input စစ်ဆေးခြင်း၊ ဖတ်ခြင်း/ရပ်ခြင်း။
class BurmeseSpeechController extends Notifier<BurmeseSpeechState> {
  static const String _LOG_NAME = 'tts.controller';

  /// Plugin သည် stop() ခေါ်လျှင် ဆိုင်းငံ့နေသော speak() ကို 0 (မအောင်မြင်) ဖြင့် ပြီးစေသည်။
  /// အသုံးပြုသူကိုယ်တိုင် ရပ်ခြင်းကို အမှားအဖြစ် မပြမိစေရန် ဤ flag ဖြင့် ခွဲခြားသည်။
  bool _isStopRequested = false;

  TtsService get _tts => ref.read(ttsServiceProvider);

  @override
  BurmeseSpeechState build() {
    Future<void>.microtask(detectBurmeseEngines);
    return const BurmeseSpeechState.initial();
  }

  /// Engine တစ်ခုချင်းစီသို့ ပြောင်းပြီး မြန်မာဘာသာ ပံ့ပိုးမှုကို စစ်သည်။
  /// စက်၏ default engine တစ်ခုတည်းကို မစစ်ခြင်းမှာ — Google TTS ကဲ့သို့ default engine
  /// အများစုတွင် မြန်မာအသံ မပါသော်လည်း တခြား engine ထည့်ထားနိုင်သောကြောင့် ဖြစ်သည်။
  Future<void> detectBurmeseEngines() async {
    state = const BurmeseSpeechState.initial();
    try {
      final List<String> engines = await _tts.getEngineNames();
      final List<String> burmeseEngines = <String>[];
      for (final String engine in engines) {
        await _tts.selectEngine(engineName: engine);
        if (await _tts.isLanguageAvailable(languageTag: TtsConfig.BURMESE_LANGUAGE_TAG)) {
          burmeseEngines.add(engine);
        }
      }
      if (!ref.mounted) return;
      developer.log(
        'action=detect engines=$engines burmese=$burmeseEngines',
        name: _LOG_NAME,
      );

      if (burmeseEngines.isEmpty) {
        state = state.copyWith(status: SpeechStatus.noBurmeseEngine);
        return;
      }
      state = state.copyWith(burmeseEngines: burmeseEngines);
      await selectEngine(engineName: burmeseEngines.first);
    } on TtsServiceException catch (error) {
      if (!ref.mounted) return;
      state = BurmeseSpeechState(
        status: SpeechStatus.detectionFailed,
        platformMessage: error.platformMessage,
      );
    }
  }

  Future<void> selectEngine({required String engineName}) async {
    state = state.copyWith(status: SpeechStatus.detecting, selectedEngine: engineName);
    try {
      await _tts.selectEngine(engineName: engineName);
      final bool isLanguageSet =
          await _tts.setLanguage(languageTag: TtsConfig.BURMESE_LANGUAGE_TAG);
      final int maxInputLength = await _tts.getMaxInputLength();
      if (!ref.mounted) return;
      developer.log(
        'action=selectEngine engine=$engineName languageSet=$isLanguageSet',
        name: _LOG_NAME,
      );
      state = state.copyWith(
        status: isLanguageSet ? SpeechStatus.ready : SpeechStatus.noBurmeseEngine,
        maxInputLength: maxInputLength,
      );
    } on TtsServiceException catch (error) {
      if (!ref.mounted) return;
      state = BurmeseSpeechState(
        status: SpeechStatus.detectionFailed,
        platformMessage: error.platformMessage,
      );
    }
  }

  void updateSpeechRate({required double rate}) {
    state = state.copyWith(speechRate: rate);
  }

  void updatePitch({required double pitch}) {
    state = state.copyWith(pitch: pitch);
  }

  Future<void> speak({required String text}) async {
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      state = state.withError(error: SpeechError.emptyText, status: state.status);
      return;
    }
    if (trimmedText.length > state.maxInputLength) {
      state = state.withError(error: SpeechError.textTooLong, status: state.status);
      return;
    }

    _isStopRequested = false;
    state = state.copyWith(status: SpeechStatus.speaking);
    try {
      // Slider ရွှေ့တိုင်း platform ကို မခေါ်ဘဲ ဖတ်ခါနီးမှ တစ်ကြိမ်သာ သတ်မှတ်သည်။
      await _tts.setSpeechRate(rate: state.speechRate);
      await _tts.setPitch(pitch: state.pitch);
      final bool isSpoken = await _tts.speak(text: trimmedText);
      if (!ref.mounted) return;
      developer.log(
        'action=speak length=${trimmedText.length} engine=${state.selectedEngine} result=$isSpoken',
        name: _LOG_NAME,
      );
      state = isSpoken || _isStopRequested
          ? state.copyWith(status: SpeechStatus.ready)
          : state.withError(error: SpeechError.speakFailed, status: SpeechStatus.ready);
    } on TtsServiceException catch (error) {
      if (!ref.mounted) return;
      state = state.withError(
        error: SpeechError.speakFailed,
        status: SpeechStatus.ready,
        platformMessage: error.platformMessage,
      );
    }
  }

  Future<void> stop() async {
    _isStopRequested = true;
    try {
      await _tts.stop();
    } on TtsServiceException catch (error) {
      // ရပ်၍မရလည်း ဖတ်ခြင်းသည် အလိုအလျောက် ပြီးဆုံးမည်ဖြစ်သဖြင့် log သာ ထုတ်ပြီး state ကို ready သို့ ပြန်ထားသည်။
      developer.log('action=stop result=failed', name: _LOG_NAME, error: error);
    }
    if (!ref.mounted) return;
    state = state.copyWith(status: SpeechStatus.ready);
  }
}
