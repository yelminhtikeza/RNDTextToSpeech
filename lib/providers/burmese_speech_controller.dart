import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

import '../config/myanmartts_config.dart';
import '../config/tts_config.dart';
import '../models/audio_save_result.dart';
import '../models/burmese_speech_state.dart';
import '../myanmartts/myanmar_tts_models.dart';
import '../myanmartts/myanmar_tts_speaker.dart';
import '../myanmartts/onnx_myanmar_tts_models.dart';
import '../myanmartts/synthesis_settings.dart';
import '../myanmartts/waveform_summary.dart';
import '../services/audio_file_saver.dart';
import '../services/audio_output.dart';
import '../services/audioplayers_audio_output.dart';
import '../services/file_dialog_audio_file_saver.dart';
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

final audioFileSaverProvider = Provider<AudioFileSaver>((Ref ref) => const FileDialogAudioFileSaver());

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

  /// Download အတွက် နောက်ဆုံးဖတ်ခဲ့သော အသံ — MB အနည်းငယ်ရှိ၍ widget rebuild တိုင်း မကူးရန် state အပြင်တွင် ထားသည်။
  Uint8List? _downloadableAudio;

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
    discardGeneratedAudio();
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

  /// Slider ရွှေ့ချိန်တွင် state သာ ပြောင်းပြီး နောက်တစ်ကြိမ် ဖတ်သည့်အခါမှ သုံးသည်။
  /// ဖတ်ပြီးသား download အသံကို မဖျက်ပါ — စာနှင့် ကိုက်ညီနေဆဲ (ကြားခဲ့သည့်အတိုင်း) ဖြစ်သောကြောင့်။
  void updateFlowSteps({required int steps}) {
    state = state.copyWith(flowSteps: steps);
  }

  void updateCfgStrength({required double cfgStrength}) {
    state = state.copyWith(cfgStrength: cfgStrength);
  }

  Future<void> speak({required String text}) async {
    final String trimmedText = text.trim();
    final SpeechError? inputError = _validateInput(text: trimmedText);
    if (inputError != null) {
      state = state.withError(error: inputError, status: state.status);
      return;
    }

    _isStopRequested = false;
    discardGeneratedAudio();
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

  /// နောက်ဆုံးထုတ်ထားသော အသံကို ပြန်ဖွင့်သည် — model ကို ထပ်မ run သဖြင့် ချက်ချင်းစပြီး ကြားခဲ့သည့်အတိုင်း တူညီသည်။
  Future<void> replayGeneratedAudio() async {
    final Uint8List? audio = _downloadableAudio;
    if (audio == null || !state.canReplay) return;
    state = state.copyWith(status: SpeechStatus.replaying);
    try {
      await _onDevice.replay(wav: audio);
      if (!ref.mounted) return;
      developer.log('action=replay bytes=${audio.length} result=ok', name: _LOG_NAME);
      state = state.copyWith(status: SpeechStatus.ready);
    } on AudioOutputException catch (error) {
      _reportSpeakFailure(platformMessage: error.platformMessage);
    }
  }

  /// စာပြင်လိုက်လျှင် ယခင်အသံသည် စာနှင့် မကိုက်တော့သဖြင့် download မပေးတော့ရန်။
  void discardGeneratedAudio() {
    if (_downloadableAudio == null && !state.hasDownloadableAudio) return;
    _downloadableAudio = null;
    state = state.copyWith(hasDownloadableAudio: false, waveform: WaveformSummary.empty);
  }

  /// နောက်ဆုံးဖတ်ခဲ့သော အသံကို WAV ဖိုင်အဖြစ် သိမ်းသည်။
  Future<AudioSaveResult> downloadAudio() async {
    final Uint8List? audio = _downloadableAudio;
    if (audio == null || !state.canDownload) {
      return const AudioSaveResult(status: AudioSaveStatus.failed);
    }
    state = state.copyWith(isSavingAudio: true);
    try {
      final String? savedPath = await ref.read(audioFileSaverProvider).saveWav(wav: audio, fileName: _downloadFileName());
      developer.log('action=download bytes=${audio.length} result=${savedPath == null ? 'cancelled' : 'saved'}',
          name: _LOG_NAME);
      return AudioSaveResult(status: savedPath == null ? AudioSaveStatus.cancelled : AudioSaveStatus.saved);
    } on AudioSaveException catch (error) {
      return AudioSaveResult(status: AudioSaveStatus.failed, platformMessage: error.platformMessage);
    } finally {
      if (ref.mounted) state = state.copyWith(isSavingAudio: false);
    }
  }

  static String _downloadFileName() =>
      '${MyanmarTtsConfig.DOWNLOAD_FILE_PREFIX}'
      '${DateFormat(MyanmarTtsConfig.DOWNLOAD_TIMESTAMP_PATTERN).format(DateTime.now())}'
      '${MyanmarTtsConfig.DOWNLOAD_FILE_EXTENSION}';

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
      final SpokenAudio? audio = await _onDevice.speak(
        text: text,
        settings: SynthesisSettings(
          lengthScale: TtsConfig.SPEECH_RATE_DEFAULT / state.speechRate,
          flowSteps: state.flowSteps,
          cfgStrength: state.cfgStrength,
        ),
      );
      if (!ref.mounted) return;
      developer.log('action=speak engine=${TtsConfig.ON_DEVICE_ENGINE_ID} length=${text.length} '
          'result=${audio == null ? 'stopped' : 'ok'}', name: _LOG_NAME);
      _downloadableAudio = audio?.wav;
      state = state.copyWith(
        status: SpeechStatus.ready,
        hasDownloadableAudio: audio != null,
        waveform: audio?.waveform ?? WaveformSummary.empty,
      );
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
