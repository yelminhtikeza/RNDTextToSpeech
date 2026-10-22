import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../config/tts_config.dart';
import '../models/burmese_speech_state.dart';
import '../myanmartts/myanmar_tts_models.dart';
import '../myanmartts/myanmar_tts_speaker.dart';
import '../myanmartts/onnx_myanmar_tts_models.dart';
import '../services/audio_output.dart';
import '../services/audioplayers_audio_output.dart';
import '../services/flutter_tts_service.dart';
import '../services/tts_service.dart';

final ttsServiceProvider = Provider<TtsService>(
  (Ref ref) => FlutterTtsService(flutterTts: FlutterTts()),
);

final onDeviceSpeakerProvider = Provider<OnDeviceSpeaker>((Ref ref) {
  final MyanmarTtsSpeaker speaker = MyanmarTtsSpeaker(
    models: OnnxMyanmarTtsModels(onnxRuntime: OnnxRuntime()),
    audioOutput: AudioplayersAudioOutput(player: AudioPlayer()),
  );
  ref.onDispose(speaker.dispose);
  return speaker;
});

final burmeseSpeechControllerProvider =
    NotifierProvider<BurmeseSpeechController, BurmeseSpeechState>(BurmeseSpeechController.new);

/// မြန်မာ အသံထွက်ခြင်း၏ business logic တစ်ခုတည်းသော နေရာ —
/// engine ရှာဖွေခြင်း၊ input စစ်ဆေးခြင်း၊ ဖတ်ခြင်း/ရပ်ခြင်း။
///
/// Engine နှစ်မျိုး ရှိသည် — ဖုန်းပေါ် MyanmarTTS (ပုံသေ) နှင့် အသုံးပြုသူ ထည့်သွင်းထားသော Android TTS engine များ (third-party)။
/// Android engine ကို fallback အဖြစ် ဆက်ထားခြင်းမှာ MyanmarTTS က အသံတစ်မျိုးတည်းသာ ရှိပြီး
/// စက်အဟောင်းများတွင် နှေးနိုင်သောကြောင့် ဖြစ်သည် (docs/adr/0002)။
class BurmeseSpeechController extends Notifier<BurmeseSpeechState> {
  static const String _LOG_NAME = 'tts.controller';

  /// Plugin သည် stop() ခေါ်လျှင် ဆိုင်းငံ့နေသော speak() ကို 0 (မအောင်မြင်) ဖြင့် ပြီးစေသည်။
  /// အသုံးပြုသူကိုယ်တိုင် ရပ်ခြင်းကို အမှားအဖြစ် မပြမိစေရန် ဤ flag ဖြင့် ခွဲခြားသည်။
  bool _isStopRequested = false;

  TtsService get _tts => ref.read(ttsServiceProvider);

  OnDeviceSpeaker get _onDevice => ref.read(onDeviceSpeakerProvider);

  @override
  BurmeseSpeechState build() {
    Future<void>.microtask(detectBurmeseEngines);
    return const BurmeseSpeechState.initial();
  }

  /// Android engine တစ်ခုချင်းစီသို့ ပြောင်းပြီး မြန်မာဘာသာ ပံ့ပိုးမှုကို စစ်ကာ ဖုန်းပေါ် engine ၏ နောက်တွင် ထည့်သည်။
  /// Android engine ရှာ၍ မရခြင်းသည် ဖုန်းပေါ် engine ရှိနေသဖြင့် အမှားမဟုတ်ပါ — log သာ ထုတ်သည်။
  Future<void> detectBurmeseEngines() async {
    state = const BurmeseSpeechState.initial();
    final List<String> systemEngines = await _detectSystemBurmeseEngines();
    if (!ref.mounted) return;
    state = state.copyWith(engines: <String>[TtsConfig.ON_DEVICE_ENGINE_ID, ...systemEngines]);
    await selectEngine(engineName: TtsConfig.ON_DEVICE_ENGINE_ID);
  }

  Future<void> selectEngine({required String engineName}) async {
    if (engineName == TtsConfig.ON_DEVICE_ENGINE_ID) {
      await _selectOnDeviceEngine();
    } else {
      await _selectSystemEngine(engineName: engineName);
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
    final SpeechError? inputError = _validateInput(text: trimmedText);
    if (inputError != null) {
      state = state.withError(error: inputError, status: state.status);
      return;
    }

    _isStopRequested = false;
    state = state.copyWith(status: SpeechStatus.speaking);
    if (state.isOnDeviceSelected) {
      await _speakOnDevice(text: trimmedText);
    } else {
      await _speakWithSystemEngine(text: trimmedText);
    }
  }

  Future<void> stop() async {
    _isStopRequested = true;
    if (state.isOnDeviceSelected) {
      await _onDevice.stop();
    } else {
      try {
        await _tts.stop();
      } on TtsServiceException catch (error) {
        // ရပ်၍မရလည်း ဖတ်ခြင်းသည် အလိုအလျောက် ပြီးဆုံးမည်ဖြစ်သဖြင့် log သာ ထုတ်ပြီး state ကို ready သို့ ပြန်ထားသည်။
        developer.log('action=stop result=failed', name: _LOG_NAME, error: error);
      }
    }
    if (!ref.mounted) return;
    state = state.copyWith(status: SpeechStatus.ready);
  }

  SpeechError? _validateInput({required String text}) {
    if (text.isEmpty) return SpeechError.emptyText;
    if (text.length > state.maxInputLength) return SpeechError.textTooLong;
    if (state.isOnDeviceSelected && !_onDevice.hasSpeakableText(text: text)) return SpeechError.noSpeakableText;
    return null;
  }

  Future<List<String>> _detectSystemBurmeseEngines() async {
    try {
      final List<String> engines = await _tts.getEngineNames();
      final List<String> burmeseEngines = <String>[];
      for (final String engine in engines) {
        await _tts.selectEngine(engineName: engine);
        if (await _tts.isLanguageAvailable(languageTag: TtsConfig.BURMESE_LANGUAGE_TAG)) {
          burmeseEngines.add(engine);
        }
      }
      developer.log('action=detect engines=$engines burmese=$burmeseEngines', name: _LOG_NAME);
      return burmeseEngines;
    } on TtsServiceException catch (error) {
      developer.log('action=detect result=failed', name: _LOG_NAME, error: error);
      return const <String>[];
    }
  }

  Future<void> _selectOnDeviceEngine() async {
    state = state.copyWith(
      status: SpeechStatus.loadingModel,
      selectedEngine: TtsConfig.ON_DEVICE_ENGINE_ID,
      maxInputLength: TtsConfig.MAX_INPUT_LENGTH_FALLBACK,
    );
    try {
      await _onDevice.load();
      if (!ref.mounted) return;
      developer.log('action=selectEngine engine=${TtsConfig.ON_DEVICE_ENGINE_ID} result=ok', name: _LOG_NAME);
      state = state.copyWith(status: SpeechStatus.ready);
    } on MyanmarTtsException catch (error) {
      if (!ref.mounted) return;
      state = state.withError(
        error: SpeechError.modelLoadFailed,
        status: SpeechStatus.engineUnavailable,
        platformMessage: error.platformMessage,
      );
    }
  }

  Future<void> _selectSystemEngine({required String engineName}) async {
    state = state.copyWith(status: SpeechStatus.detecting, selectedEngine: engineName);
    try {
      await _tts.selectEngine(engineName: engineName);
      final bool isLanguageSet = await _tts.setLanguage(languageTag: TtsConfig.BURMESE_LANGUAGE_TAG);
      final int maxInputLength = await _tts.getMaxInputLength();
      if (!ref.mounted) return;
      developer.log('action=selectEngine engine=$engineName languageSet=$isLanguageSet', name: _LOG_NAME);
      state = isLanguageSet
          ? state.copyWith(status: SpeechStatus.ready, maxInputLength: maxInputLength)
          : state.withError(error: SpeechError.languageUnavailable, status: SpeechStatus.engineUnavailable);
    } on TtsServiceException catch (error) {
      if (!ref.mounted) return;
      state = state.withError(
        error: SpeechError.languageUnavailable,
        status: SpeechStatus.engineUnavailable,
        platformMessage: error.platformMessage,
      );
    }
  }

  Future<void> _speakOnDevice({required String text}) async {
    try {
      // Slider ၏ speech rate (0.5 = ပုံမှန်) ကို duration multiplier အဖြစ် ပြောင်းသည် — rate မြင့်လေ အသံတိုလေ။
      await _onDevice.speak(text: text, lengthScale: TtsConfig.SPEECH_RATE_DEFAULT / state.speechRate);
      if (!ref.mounted) return;
      developer.log('action=speak engine=${TtsConfig.ON_DEVICE_ENGINE_ID} length=${text.length} result=ok',
          name: _LOG_NAME);
      state = state.copyWith(status: SpeechStatus.ready);
    } on MyanmarTtsException catch (error) {
      _reportSpeakFailure(platformMessage: error.platformMessage);
    } on AudioOutputException catch (error) {
      _reportSpeakFailure(platformMessage: error.platformMessage);
    }
  }

  Future<void> _speakWithSystemEngine({required String text}) async {
    try {
      // Slider ရွှေ့တိုင်း platform ကို မခေါ်ဘဲ ဖတ်ခါနီးမှ တစ်ကြိမ်သာ သတ်မှတ်သည်။
      await _tts.setSpeechRate(rate: state.speechRate);
      await _tts.setPitch(pitch: state.pitch);
      final bool isSpoken = await _tts.speak(text: text);
      if (!ref.mounted) return;
      developer.log(
        'action=speak length=${text.length} engine=${state.selectedEngine} result=$isSpoken',
        name: _LOG_NAME,
      );
      state = isSpoken || _isStopRequested
          ? state.copyWith(status: SpeechStatus.ready)
          : state.withError(error: SpeechError.speakFailed, status: SpeechStatus.ready);
    } on TtsServiceException catch (error) {
      _reportSpeakFailure(platformMessage: error.platformMessage);
    }
  }

  void _reportSpeakFailure({required String? platformMessage}) {
    if (!ref.mounted) return;
    developer.log('action=speak engine=${state.selectedEngine} result=failed', name: _LOG_NAME);
    state = state.withError(
      error: SpeechError.speakFailed,
      status: SpeechStatus.ready,
      platformMessage: platformMessage,
    );
  }
}
