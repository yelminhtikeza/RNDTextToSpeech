import 'dart:async';
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
import '../models/engine_voice.dart';
import '../models/voice_profile.dart';
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
import 'voice_controller.dart';

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

/// အသံထွက်ခြင်း၏ business logic တစ်ခုတည်းသော နေရာ —
/// engine/ဘာသာ ရွေးခြင်း၊ input စစ်ဆေးခြင်း၊ ဖတ်ခြင်း/ရပ်ခြင်း။
///
/// Engine နှစ်မျိုး ရှိသည် — ဖုန်းပေါ် MyanmarTTS (ပုံသေ၊ မြန်မာသာ) နှင့် ထည့်သွင်းထားသော Android TTS engine အားလုံး
/// (third-party၊ engine ပံ့ပိုးသည့် ဘာသာ မည်သည်ကိုမဆို ရွေးနိုင် — docs/adr/0004)။
/// Android engine ကို fallback အဖြစ် ဆက်ထားခြင်းမှာ MyanmarTTS က အသံတစ်မျိုးတည်းသာ ရှိပြီး
/// စက်အဟောင်းများတွင် နှေးနိုင်သောကြောင့် ဖြစ်သည် (docs/adr/0002)။
class BurmeseSpeechController extends Notifier<BurmeseSpeechState> {
  static const String _LOG_NAME = 'tts.controller';

  /// Plugin သည် stop() ခေါ်လျှင် ဆိုင်းငံ့နေသော speak() ကို 0 (မအောင်မြင်) ဖြင့် ပြီးစေသည်။
  /// အသုံးပြုသူကိုယ်တိုင် ရပ်ခြင်းကို အမှားအဖြစ် မပြမိစေရန် ဤ flag ဖြင့် ခွဲခြားသည်။
  bool _isStopRequested = false;

  /// Download အတွက် နောက်ဆုံးဖတ်ခဲ့သော အသံ — MB အနည်းငယ်ရှိ၍ widget rebuild တိုင်း မကူးရန် state အပြင်တွင် ထားသည်။
  Uint8List? _downloadableAudio;

  /// WAV ဖိုင်ထုတ်မှု မအောင်မြင်ခဲ့သော Android engine များ — ဖတ်တိုင်း အလကား မထုတ်စေရန် (app ဖွင့်ထားစဉ်သာ မှတ်)။
  final Set<String> _enginesWithoutAudioExport = <String>{};

  /// Android engine ဖြင့် အဆုံးထိ ဖတ်ခဲ့သော စာနှင့် ထိုအချိန်၏ ဘာသာ/အသံ/နှုန်း/pitch — Play/Download နှိပ်မှ ကြားခဲ့သည့်အတိုင်း
  /// ဖိုင်ထုတ်ရန် (slider/အသံကို နောက်မှ ပြောင်းထားလည်း)။
  _SpokenSettings? _renderableSpeech;

  /// ရွေးထားသော Android engine ၏ အသံအားလုံး — ဘာသာ ပြောင်းတိုင်း engine ကို ထပ်မမေးဘဲ စစ်ထုတ်ရန်။
  List<EngineVoice> _engineVoices = const <EngineVoice>[];

  /// ထုတ်နေသော engine အသံ၏ အမှတ်စဉ် — စာပြင်/ထပ်ဖတ်/engine ပြောင်းပြီးမှ ရောက်လာသော ဟောင်းနေသည့် ရလဒ်ကို လျစ်လျူရှုရန်။
  int _audioGeneration = 0;

  TtsService get _tts => ref.read(ttsServiceProvider);

  OnDeviceSpeaker get _onDevice => ref.read(onDeviceSpeakerProvider);

  @override
  BurmeseSpeechState build() {
    final StreamSubscription<Duration> positions = _onDevice.positionChanges.listen(_onPlaybackPosition);
    ref.onDispose(positions.cancel);
    Future<void>.microtask(detectEngines);
    return const BurmeseSpeechState.initial();
  }

  /// ထည့်သွင်းထားသော Android engine အားလုံးကို ဖုန်းပေါ် engine ၏ နောက်တွင် ထည့်ပြီး ဖုန်းပေါ် engine ကို ရွေးသည်။
  /// Engine တစ်ခုချင်း ဘာသာကို ကြိုမစစ်တော့ပါ — ရွေးမှသာ ဘာသာစာရင်း ယူသဖြင့် app စဖွင့်ချိန် မြန်သည်။
  /// Android engine ရှာ၍ မရခြင်းသည် ဖုန်းပေါ် engine ရှိနေသဖြင့် အမှားမဟုတ်ပါ — log သာ ထုတ်သည်။
  Future<void> detectEngines() async {
    state = const BurmeseSpeechState.initial();
    final List<String> systemEngines = await _detectSystemEngines();
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

  /// Android engine ၏ ဘာသာ ပြောင်းသည်။ MyanmarTTS တွင် မြန်မာ တစ်ခုတည်းသာ ရှိ၍ ဤ method ကို မခေါ်ရပါ။
  Future<void> selectLanguage({required String languageTag}) async {
    if (state.isOnDeviceSelected || !state.languages.contains(languageTag)) return;
    state = state.copyWith(status: SpeechStatus.detecting).withLanguages(
          languages: state.languages,
          selectedLanguage: languageTag,
        );
    await _applySystemLanguage(languageTag: languageTag);
  }

  /// Android engine ၏ အသံ ပြောင်းသည်။ ကြားခဲ့သော အသံနှင့် မကိုက်တော့သဖြင့် ယခင်ထုတ်ထားသော အသံကို ဖျက်သည်။
  Future<void> selectEngineVoice({required String voiceId}) async {
    final String? languageTag = state.selectedLanguage;
    if (!state.canChooseEngineVoice || languageTag == null) return;
    discardGeneratedAudio();
    state = state.copyWith(selectedEngineVoice: voiceId);
    try {
      final bool isApplied = await _applyEngineVoice(languageTag: languageTag, voiceId: voiceId);
      if (!ref.mounted) return;
      developer.log('action=selectEngineVoice engine=${state.selectedEngine} voice=$voiceId result=$isApplied',
          name: _LOG_NAME);
      if (!isApplied) _rejectEngineVoice();
    } on TtsServiceException catch (error) {
      if (!ref.mounted) return;
      _rejectEngineVoice(platformMessage: error.platformMessage);
    }
  }

  /// လက်မခံသော အသံကို ပုံသေသို့ ပြန်ထားပြီး အကြောင်းရင်း ပြသည် — ဖတ်ခြင်းကို မပိတ်ပါ။
  void _rejectEngineVoice({String? platformMessage}) {
    state = state
        .copyWith(selectedEngineVoice: TtsConfig.ENGINE_DEFAULT_VOICE_ID)
        .withError(error: SpeechError.engineVoiceUnavailable, status: state.status, platformMessage: platformMessage);
  }

  /// ဘာသာကို အရင်သတ်မှတ်ခြင်းဖြင့် engine ၏ ပုံသေ အသံသို့ ပြန်ရောက်ပြီး ရွေးထားသော အသံ ရှိမှသာ ထပ်ပြောင်းသည်။
  Future<bool> _applyEngineVoice({required String languageTag, required String voiceId}) async {
    if (!await _tts.setLanguage(languageTag: languageTag)) return false;
    if (voiceId == TtsConfig.ENGINE_DEFAULT_VOICE_ID) return true;
    final EngineVoice? voice = _engineVoices.where((EngineVoice candidate) => candidate.name == voiceId).firstOrNull;
    return voice != null && await _tts.setVoice(voice: voice);
  }

  /// ဘာသာ tag တူသော အသံများကို အမည်အစဉ်ဖြင့် — "အသံ 1၊ 2…" နံပါတ် မပြောင်းစေရန်။
  List<EngineVoice> _engineVoicesFor({required String languageTag}) => _engineVoices
      .where((EngineVoice voice) => voice.locale == languageTag)
      .toList()
    ..sort((EngineVoice a, EngineVoice b) => a.name.compareTo(b.name));

  /// အသံစာရင်း မရခြင်းသည် ပုံသေ အသံဖြင့် ဆက်ဖတ်နိုင်သဖြင့် အမှားမဟုတ် — log သာ ထုတ်သည်။
  Future<List<EngineVoice>> _loadEngineVoices() async {
    try {
      return await _tts.getVoices();
    } on TtsServiceException catch (error) {
      developer.log('action=getVoices engine=${state.selectedEngine} result=failed', name: _LOG_NAME, error: error);
      return const <EngineVoice>[];
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

  /// MyanmarTTS ဖတ်နေစဉ်/ပြန်ဖွင့်နေစဉ် ခေတ္တရပ်ခြင်း နှင့် ဆက်ဖွင့်ခြင်း။
  Future<void> togglePause() async {
    if (!state.canPause) return;
    final bool willPause = !state.isPaused;
    try {
      if (willPause) {
        await _onDevice.pause();
      } else {
        await _onDevice.resume();
      }
      if (!ref.mounted) return;
      developer.log('action=${willPause ? 'pause' : 'resume'} result=ok', name: _LOG_NAME);
      state = state.copyWith(isPaused: willPause);
    } on AudioOutputException catch (error) {
      _reportPlaybackFailure(platformMessage: error.platformMessage);
    }
  }

  /// Waveform ပေါ်တွင် နှိပ်/ဆွဲသော နေရာ ([fraction] 0–1) သို့ ရွှေ့သည်။
  /// ပြန်ဖွင့်နေစဉ်/ခေတ္တရပ်ထားစဉ်ဆိုလျှင် player ကို seek လုပ်ပြီး၊ မဖွင့်ရသေးလျှင် ထိုနေရာမှ စဖွင့်သည်။
  Future<void> seekGeneratedAudio({required double fraction}) async {
    if (!state.canSeek) return;
    final Duration position = state.waveform.duration * fraction.clamp(0.0, 1.0);
    if (!state.isReplaying) {
      await replayGeneratedAudio(startAt: position);
      return;
    }
    try {
      await _onDevice.seek(position: position);
      if (!ref.mounted) return;
      state = state.copyWith(playbackPosition: position);
    } on AudioOutputException catch (error) {
      _reportPlaybackFailure(platformMessage: error.platformMessage);
    }
  }

  Future<void> stop() async {
    _isStopRequested = true;
    // Android engine ၏ အသံကိုလည်း ဖိုင်ထုတ်ပြီးပါက app ၏ player ဖြင့် ဖွင့်သဖြင့် player ကိုပါ ရပ်ရသည်။
    if (state.isOnDeviceSelected || state.isReplaying) await _onDevice.stop();
    if (!state.isOnDeviceSelected) {
      try {
        await _tts.stop();
      } on TtsServiceException catch (error) {
        // ရပ်၍မရလည်း ဖတ်ခြင်းသည် အလိုအလျောက် ပြီးဆုံးမည်ဖြစ်သဖြင့် log သာ ထုတ်ပြီး state ကို ready သို့ ပြန်ထားသည်။
        developer.log('action=stop result=failed', name: _LOG_NAME, error: error);
      }
    }
    if (!ref.mounted) return;
    state = state.copyWith(status: SpeechStatus.ready, isPaused: false, playbackPosition: Duration.zero);
  }

  /// နောက်ဆုံးထုတ်ထားသော အသံကို [startAt] မှ ပြန်ဖွင့်သည် — model ကို ထပ်မ run သဖြင့် ချက်ချင်းစပြီး ကြားခဲ့သည့်အတိုင်း တူညီသည်။
  Future<void> replayGeneratedAudio({Duration startAt = Duration.zero}) async {
    if (!state.canReplay || !await _ensureGeneratedAudio()) return;
    final Uint8List? audio = _downloadableAudio;
    if (audio == null || !ref.mounted) return;
    state = state.copyWith(status: SpeechStatus.replaying, isPaused: false, playbackPosition: startAt);
    try {
      await _onDevice.replay(wav: audio, startAt: startAt);
      if (!ref.mounted) return;
      developer.log('action=replay bytes=${audio.length} start_ms=${startAt.inMilliseconds} result=ok', name: _LOG_NAME);
      state = state.copyWith(status: SpeechStatus.ready, isPaused: false, playbackPosition: Duration.zero);
    } on AudioOutputException catch (error) {
      _reportSpeakFailure(platformMessage: error.platformMessage);
    }
  }

  /// စာပြင်လိုက်လျှင် ယခင်အသံသည် စာနှင့် မကိုက်တော့သဖြင့် download မပေးတော့ရန်။
  void discardGeneratedAudio() {
    _cancelAudioPreparation();
    if (_downloadableAudio == null && _renderableSpeech == null && !state.hasPlayableAudio) return;
    _downloadableAudio = null;
    _renderableSpeech = null;
    state = state.copyWith(
      hasDownloadableAudio: false,
      hasRenderableSpeech: false,
      waveform: WaveformSummary.empty,
      playbackPosition: Duration.zero,
    );
  }

  /// နောက်ဆုံးဖတ်ခဲ့သော အသံကို WAV ဖိုင်အဖြစ် သိမ်းသည်။
  Future<AudioSaveResult> downloadAudio() async {
    if (!state.canDownload) return const AudioSaveResult(status: AudioSaveStatus.failed);
    // Download ခလုတ်ကို ဖိုင်ထုတ်နေစဉ်ကပင် loading ပြရန် အရင်သတ်မှတ်သည်။
    state = state.copyWith(isSavingAudio: true);
    try {
      if (!await _ensureGeneratedAudio()) {
        // စာပြင်/ထပ်ဖတ်၍ ဖိုင်ထုတ်ခြင်း ဖျက်သိမ်းခံရပါက ဘာမျှမပြ၊ engine က မပေးနိုင်မှသာ unavailable။
        return AudioSaveResult(
          status: state.supportsAudioExport ? AudioSaveStatus.cancelled : AudioSaveStatus.unavailable,
        );
      }
      final Uint8List? audio = _downloadableAudio;
      if (audio == null) return const AudioSaveResult(status: AudioSaveStatus.failed);
      final String? savedPath = await ref.read(audioFileSaverProvider).saveWav(wav: audio, fileName: _downloadFileName());
      developer.log('action=download bytes=${audio.length} result=${savedPath == null ? 'cancelled' : 'saved'}',
          name: _LOG_NAME);
      return AudioSaveResult(status: savedPath == null ? AudioSaveStatus.cancelled : AudioSaveStatus.saved);
    } on AudioSaveException catch (error) {
      return AudioSaveResult(status: AudioSaveStatus.failed, platformMessage: error.platformMessage);
    } finally {
      if (ref.mounted) _finishSaving();
    }
  }

  /// copyWith သည် အမှားကို ရှင်းသဖြင့် ဖိုင်ထုတ်၍မရကြောင်း ([SpeechError.audioUnavailable]) ကို မပျောက်စေရန် ထိန်းထားသည်။
  void _finishSaving() {
    final BurmeseSpeechState saved = state.copyWith(isSavingAudio: false);
    final SpeechError? error = state.error;
    state = error == null
        ? saved
        : saved.withError(error: error, status: saved.status, platformMessage: state.platformMessage);
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

  Future<List<String>> _detectSystemEngines() async {
    try {
      final List<String> engines = await _tts.getEngineNames();
      developer.log('action=detect engines=$engines', name: _LOG_NAME);
      return engines;
    } on TtsServiceException catch (error) {
      developer.log('action=detect result=failed', name: _LOG_NAME, error: error);
      return const <String>[];
    }
  }

  Future<void> _selectOnDeviceEngine() async {
    state = state
        .copyWith(
          status: SpeechStatus.loadingModel,
          selectedEngine: TtsConfig.ON_DEVICE_ENGINE_ID,
          maxInputLength: TtsConfig.MAX_INPUT_LENGTH_FALLBACK,
          supportsAudioExport: true,
        )
        .withLanguages(
          languages: const <String>[TtsConfig.BURMESE_LANGUAGE_TAG],
          selectedLanguage: TtsConfig.BURMESE_LANGUAGE_TAG,
        );
    try {
      await _onDevice.load();
      // အသံစာရင်း မရသေးမီ "ready" မဖြစ်စေရန် — မဟုတ်ပါက ချက်ချင်းနှိပ်လျှင် voiceUnavailable ဖြစ်မည်။
      await ref.read(voiceControllerProvider.notifier).ensureLoaded();
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
    state = state
        .copyWith(
          status: SpeechStatus.detecting,
          selectedEngine: engineName,
          supportsAudioExport: !_enginesWithoutAudioExport.contains(engineName),
        )
        .withLanguages(languages: const <String>[], selectedLanguage: null);
    final List<String> languages;
    try {
      await _tts.selectEngine(engineName: engineName);
      languages = List<String>.of(await _tts.getLanguages())..sort();
      _engineVoices = await _loadEngineVoices();
      final int maxInputLength = await _tts.getMaxInputLength();
      if (!ref.mounted) return;
      state = state.copyWith(maxInputLength: maxInputLength);
    } on TtsServiceException catch (error) {
      if (!ref.mounted) return;
      state = state.withError(
        error: SpeechError.noLanguages,
        status: SpeechStatus.engineUnavailable,
        platformMessage: error.platformMessage,
      );
      return;
    }
    developer.log('action=selectEngine engine=$engineName languages=${languages.length}', name: _LOG_NAME);
    if (languages.isEmpty) {
      state = state.withError(error: SpeechError.noLanguages, status: SpeechStatus.engineUnavailable);
      return;
    }
    final String defaultLanguage = _defaultLanguageOf(languages: languages);
    state = state.withLanguages(languages: languages, selectedLanguage: defaultLanguage);
    await _applySystemLanguage(languageTag: defaultLanguage);
  }

  /// မြန်မာ ပါပါက မြန်မာ (app ၏ အဓိက အသုံးပြုသူ)၊ မပါပါက အက္ခရာစဉ် ပထမ ဘာသာ။
  static String _defaultLanguageOf({required List<String> languages}) {
    if (languages.contains(TtsConfig.BURMESE_LANGUAGE_TAG)) return TtsConfig.BURMESE_LANGUAGE_TAG;
    return languages.firstWhere(_isBurmese, orElse: () => languages.first);
  }

  static bool _isBurmese(String languageTag) =>
      languageTag.split(TtsConfig.LANGUAGE_TAG_SEPARATOR).first == TtsConfig.BURMESE_LANGUAGE_CODE;

  Future<void> _applySystemLanguage({required String languageTag}) async {
    try {
      final bool isLanguageSet = await _tts.setLanguage(languageTag: languageTag);
      if (!ref.mounted) return;
      developer.log('action=selectLanguage engine=${state.selectedEngine} language=$languageTag '
          'result=$isLanguageSet', name: _LOG_NAME);
      state = isLanguageSet
          ? state.copyWith(status: SpeechStatus.ready, engineVoices: _engineVoicesFor(languageTag: languageTag))
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
    final VoiceProfile? voice = ref.read(voiceControllerProvider).selectedVoice;
    if (voice == null) {
      state = state.withError(error: SpeechError.voiceUnavailable, status: SpeechStatus.ready);
      return;
    }
    try {
      // Slider ၏ speech rate (0.5 = ပုံမှန်) ကို duration multiplier အဖြစ် ပြောင်းသည် — rate မြင့်လေ အသံတိုလေ။
      final SpokenAudio? audio = await _onDevice.speak(
        text: text,
        // အပိုင်းတစ်ခု စဖွင့်တိုင်း waveform ကို ချဲ့ပြသဖြင့် ဖတ်နေစဉ် ဘယ်နေရာ ရောက်နေကြောင်း မြင်ရသည်။
        onWaveformChanged: (WaveformSummary waveform) {
          if (ref.mounted && state.isSpeaking) state = state.copyWith(waveform: waveform);
        },
        settings: SynthesisSettings(
          lengthScale: TtsConfig.SPEECH_RATE_DEFAULT / state.speechRate,
          speaker: voice.embedding,
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
        playbackPosition: Duration.zero,
        isPaused: false,
      );
    } on MyanmarTtsException catch (error) {
      _reportSpeakFailure(platformMessage: error.platformMessage);
    } on AudioOutputException catch (error) {
      _reportSpeakFailure(platformMessage: error.platformMessage);
    }
  }

  /// WAV ဖိုင်ထုတ်နိုင်သော engine ဆိုလျှင် ဖိုင်ထုတ်ပြီး app ၏ player ဖြင့် ဖွင့်သည် (waveform/pause/seek/download ရ)။
  /// မထုတ်နိုင်ပါက ထို engine ကို မှတ်ထားပြီး engine ကိုယ်တိုင် speaker သို့ ဖတ်စေသည် (fallback)။
  /// Engine ကို ချက်ချင်း အသံထွက်ဖတ်စေပြီး (မစောင့်ရ) အဆုံးထိ ဖတ်ပြီးမှ တူညီသောစာကို နောက်ကွယ်တွင် WAV ဖိုင်သို့ ထပ်ထုတ်ကာ
  /// waveform/player/download ပေးသည်။ Android သည် engine ဖတ်နေသော အသံကို app သို့ မပေးသဖြင့် ထပ်ထုတ်ရခြင်း ဖြစ်သည် (ADR 0005)။
  Future<void> _speakWithSystemEngine({required String text}) async {
    try {
      final _SpokenSettings settings = _SpokenSettings(
        text: text,
        languageTag: state.selectedLanguage,
        voiceId: state.selectedEngineVoice,
        rate: state.speechRate,
        pitch: state.pitch,
      );
      await _applySpokenSettings(settings: settings);
      final bool isSpoken = await _tts.speak(text: text);
      if (!ref.mounted) return;
      developer.log(
        'action=speak length=${text.length} engine=${state.selectedEngine} result=$isSpoken',
        name: _LOG_NAME,
      );
      // ရပ်လိုက်သော အသံကို ပြန်ဖွင့်/download မပေး (MyanmarTTS နည်းတူ — ကြားခဲ့သည်နှင့် မကိုက်)။
      if (_isStopRequested) return;
      if (!isSpoken) {
        state = state.withError(error: SpeechError.speakFailed, status: SpeechStatus.ready);
        return;
      }
      if (state.supportsAudioExport) _renderableSpeech = settings;
      state = state.copyWith(status: SpeechStatus.ready, hasRenderableSpeech: _renderableSpeech != null);
    } on TtsServiceException catch (error) {
      _reportSpeakFailure(platformMessage: error.platformMessage);
    }
  }

  /// Slider/အသံ ပြောင်းတိုင်း platform ကို မခေါ်ဘဲ ဖတ်ခါနီး/ဖိုင်ထုတ်ခါနီးမှ သတ်မှတ်သည် — ဖိုင်ထုတ်ရာတွင် ကြားခဲ့သည့် setting
  /// ကို ပြန်သုံးပြီးနောက် engine သည် ထို setting ဖြင့် ကျန်နေနိုင်၍ ဖတ်တိုင်း လက်ရှိ ရွေးချယ်မှုကို ပြန်သတ်မှတ်ရသည်။
  Future<void> _applySpokenSettings({required _SpokenSettings settings}) async {
    final String? languageTag = settings.languageTag;
    if (languageTag != null) await _applyEngineVoice(languageTag: languageTag, voiceId: settings.voiceId);
    await _tts.setSpeechRate(rate: settings.rate);
    await _tts.setPitch(pitch: settings.pitch);
  }

  /// ထုတ်ပြီးသား အသံ ရှိ/မရှိ — Android engine ၏ ဖတ်ခဲ့သောစာ ဆိုလျှင် ယခုမှ ဖိုင်ထုတ်သည် (option C၊ ADR 0005)။
  /// ဖိုင်ထုတ်မှု မရပါက engine ကို မှတ်ထားပြီး Play/Download ကို ဖျောက်ကာ အကြောင်းရင်း ပြသည်။
  Future<bool> _ensureGeneratedAudio() async {
    if (_downloadableAudio != null) return true;
    final _SpokenSettings? speech = _renderableSpeech;
    if (speech == null) return false;
    final int generation = ++_audioGeneration;
    state = state.copyWith(isPreparingAudio: true);
    SpokenAudio? audio;
    try {
      await _applySpokenSettings(settings: speech);
      audio = await _exportSystemAudio(text: speech.text);
    } on TtsServiceException catch (error) {
      developer.log('action=exportAudio result=failed', name: _LOG_NAME, error: error);
    }
    if (!ref.mounted || generation != _audioGeneration) return false;
    _renderableSpeech = null;
    if (audio == null) {
      final String? engine = state.selectedEngine;
      if (engine != null) _enginesWithoutAudioExport.add(engine);
      state = state
          .copyWith(isPreparingAudio: false, hasRenderableSpeech: false, supportsAudioExport: false)
          .withError(error: SpeechError.audioUnavailable, status: state.status);
      return false;
    }
    _downloadableAudio = audio.wav;
    state = state.copyWith(
      isPreparingAudio: false,
      hasRenderableSpeech: false,
      hasDownloadableAudio: true,
      waveform: audio.waveform,
    );
    return true;
  }

  /// ထုတ်နေဆဲ ဖိုင်ကို ရပ်ပြီး ရလဒ်ကို လျစ်လျူရှုသည် — နောက် speak သည် engine ၏ queue တွင် ဖိုင်ထုတ်မှုနောက်၌ မစောင့်ရစေရန်။
  void _cancelAudioPreparation() {
    _audioGeneration++;
    if (!state.isPreparingAudio) return;
    state = state.copyWith(isPreparingAudio: false);
    unawaited(_stopSystemEngineQuietly());
  }

  Future<void> _stopSystemEngineQuietly() async {
    try {
      await _tts.stop();
    } on TtsServiceException catch (error) {
      // ဖိုင်ထုတ်ခြင်းကို ရပ်၍မရလည်း ရလဒ်ကို လျစ်လျူရှုပြီးဖြစ်၍ log သာ ထုတ်သည်။
      developer.log('action=cancelAudioPreparation result=failed', name: _LOG_NAME, error: error);
    }
  }

  /// ဖိုင်ထုတ်မှု platform အမှားကိုလည်း "မပံ့ပိုး" အဖြစ်သာ ယူသည် — speak ဖြင့် ဆက်ဖတ်နိုင်သေးသဖြင့် အသုံးပြုသူကို အမှား မပြ။
  Future<SpokenAudio?> _exportSystemAudio({required String text}) async {
    try {
      final SpokenAudio? audio = await _tts.synthesizeAudio(text: text);
      developer.log('action=exportAudio engine=${state.selectedEngine} result=${audio == null ? 'unavailable' : 'ok'}',
          name: _LOG_NAME);
      return audio;
    } on TtsServiceException catch (error) {
      developer.log('action=exportAudio engine=${state.selectedEngine} result=failed', name: _LOG_NAME, error: error);
      return null;
    }
  }

  /// Frame တိုင်း မဟုတ်ဘဲ [MyanmarTtsConfig.PLAYBACK_POSITION_STEP] ထက် ပြောင်းမှသာ state ပြင်သည်။
  void _onPlaybackPosition(Duration position) {
    if (!ref.mounted || !state.isAppPlayerActive) return;
    if ((position - state.playbackPosition).abs() < MyanmarTtsConfig.PLAYBACK_POSITION_STEP) return;
    state = state.copyWith(playbackPosition: position);
  }

  /// Pause/seek မအောင်မြင်ခြင်းသည် ဖွင့်ခြင်းကို မရပ်စေသဖြင့် status ကို မပြောင်းဘဲ အမှားသာ ပြသည်။
  void _reportPlaybackFailure({required String? platformMessage}) {
    if (!ref.mounted) return;
    developer.log('action=playbackControl result=failed', name: _LOG_NAME);
    state = state.withError(error: SpeechError.speakFailed, status: state.status, platformMessage: platformMessage);
  }

  void _reportSpeakFailure({required String? platformMessage}) {
    if (!ref.mounted) return;
    developer.log('action=speak engine=${state.selectedEngine} result=failed', name: _LOG_NAME);
    state = state.copyWith(isPaused: false, playbackPosition: Duration.zero).withError(
      error: SpeechError.speakFailed,
      status: SpeechStatus.ready,
      platformMessage: platformMessage,
    );
  }
}

/// Android engine ဖြင့် ဖတ်ခဲ့သော စာနှင့် setting — ဖိုင်ထုတ်ချိန်တွင် ကြားခဲ့သည့်အတိုင်း ပြန်သုံးရန်။
class _SpokenSettings {
  const _SpokenSettings({
    required this.text,
    required this.languageTag,
    required this.voiceId,
    required this.rate,
    required this.pitch,
  });

  final String text;
  final String? languageTag;
  final String voiceId;
  final double rate;
  final double pitch;
}
