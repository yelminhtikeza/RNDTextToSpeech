import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import '../config/myanmartts_config.dart';
import '../config/tts_config.dart';
import '../models/engine_voice.dart';
import '../myanmartts/waveform_summary.dart';
import 'tts_service.dart';

/// [TtsService] ကို flutter_tts plugin ဖြင့် အကောင်အထည်ဖော်ထားခြင်း။
/// Plugin ၏ `dynamic` ပြန်တန်ဖိုးများကို ဤနေရာတွင်သာ type ပြောင်းပြီး ကျန် app သို့ မပေါက်ကြားစေပါ။
class FlutterTtsService implements TtsService {
  FlutterTtsService({
    required FlutterTts flutterTts,
    Future<Directory> Function()? temporaryDirectory,
    Duration synthesisStartTimeout = TtsConfig.SYNTHESIS_START_TIMEOUT,
  })  : _flutterTts = flutterTts,
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _synthesisStartTimeout = synthesisStartTimeout {
    // `awaitSynthCompletion` ကို မသုံးခြင်းမှာ plugin သည် engine error နှင့် stop တွင် ထို Future ကို ဘယ်တော့မှ မပြီးစေ၍
    // app က ထာဝရ စောင့်နေမည်ဖြစ်သောကြောင့်။ Handler ဖြင့် ကိုယ်တိုင် ခြေရာခံသည် (speak တွင်လည်း ခေါ်သော်လည်း
    // ဖိုင်ထုတ်နေချိန်တွင်သာ [_pendingSynthesis] ရှိ၍ မထိခိုက်)။
    _flutterTts
      ..setStartHandler(() => _hasSynthesisStarted = true)
      ..setCompletionHandler(() => _finishSynthesis(isWritten: true))
      ..setErrorHandler((dynamic message) {
        if (_pendingSynthesis != null) {
          developer.log('operation=synthesizeToFile result=engine_error message=$message', name: _LOG_NAME);
        }
        _finishSynthesis(isWritten: false);
      });
  }

  static const String _LOG_NAME = 'tts.service';

  final FlutterTts _flutterTts;
  final Future<Directory> Function() _temporaryDirectory;
  final Duration _synthesisStartTimeout;
  bool _isSpeakCompletionAwaited = false;
  Completer<bool>? _pendingSynthesis;
  bool _hasSynthesisStarted = false;

  @override
  Future<List<String>> getEngineNames() => _guard(
        operation: 'getEngines',
        action: () async {
          final Object? engines = await _flutterTts.getEngines;
          return engines is List ? engines.whereType<String>().toList() : <String>[];
        },
      );

  @override
  Future<void> selectEngine({required String engineName}) => _guard(
        operation: 'setEngine',
        action: () => _flutterTts.setEngine(engineName),
      );

  @override
  Future<List<String>> getLanguages() => _guard(
        operation: 'getLanguages',
        action: () async {
          // Android တွင် `TextToSpeech.availableLanguages` (လက်ရှိ engine) ကို `toLanguageTag()` ဖြင့် ပြန်ပေးသည်။
          final Object? languages = await _flutterTts.getLanguages;
          return languages is List ? languages.whereType<String>().toList() : <String>[];
        },
      );

  @override
  Future<bool> setLanguage({required String languageTag}) => _guard(
        operation: 'setLanguage',
        action: () async =>
            await _flutterTts.setLanguage(languageTag) == TtsConfig.PLATFORM_SUCCESS,
      );

  @override
  Future<List<EngineVoice>> getVoices() => _guard(
        operation: 'getVoices',
        action: () async {
          final Object? voices = await _flutterTts.getVoices;
          if (voices is! List) return <EngineVoice>[];
          return voices.whereType<Map<Object?, Object?>>().map(_toEngineVoice).nonNulls.toList();
        },
      );

  @override
  Future<bool> setVoice({required EngineVoice voice}) => _guard(
        operation: 'setVoice',
        action: () async =>
            await _flutterTts.setVoice(<String, String>{
              TtsConfig.VOICE_KEY_NAME: voice.name,
              TtsConfig.VOICE_KEY_LOCALE: voice.locale,
            }) ==
            TtsConfig.PLATFORM_SUCCESS,
      );

  /// Data မဒေါင်းရသေးသော အသံ (ရွေးလျှင် အသံမထွက်) နှင့် အမည်/locale မပါသော entry ကို ဖယ်သည်။
  static EngineVoice? _toEngineVoice(Map<Object?, Object?> voice) {
    final Object? name = voice[TtsConfig.VOICE_KEY_NAME];
    final Object? locale = voice[TtsConfig.VOICE_KEY_LOCALE];
    final Object? features = voice[TtsConfig.VOICE_KEY_FEATURES];
    if (name is! String || locale is! String) return null;
    if (features is String &&
        features.split(TtsConfig.VOICE_FEATURE_SEPARATOR).contains(TtsConfig.VOICE_FEATURE_NOT_INSTALLED)) {
      return null;
    }
    return EngineVoice(
      name: name,
      locale: locale,
      requiresNetwork: voice[TtsConfig.VOICE_KEY_NETWORK_REQUIRED] == TtsConfig.VOICE_NETWORK_REQUIRED_TRUE,
    );
  }

  @override
  Future<void> setSpeechRate({required double rate}) => _guard(
        operation: 'setSpeechRate',
        action: () => _flutterTts.setSpeechRate(rate),
      );

  @override
  Future<void> setPitch({required double pitch}) => _guard(
        operation: 'setPitch',
        action: () => _flutterTts.setPitch(pitch),
      );

  @override
  Future<int> getMaxInputLength() => _guard(
        operation: 'getMaxSpeechInputLength',
        action: () async =>
            await _flutterTts.getMaxSpeechInputLength ?? TtsConfig.MAX_INPUT_LENGTH_FALLBACK,
      );

  @override
  Future<bool> speak({required String text}) => _guard(
        operation: 'speak',
        action: () async {
          // speak() ၏ Future ကို ဖတ်ပြီးမှ complete ဖြစ်စေရန် — completion handler
          // callback ကို state နှင့် ချိတ်ရသည့် နည်းထက် ရိုးရှင်းပြီး stop() ခေါ်လျှင်လည်း complete ဖြစ်သည်။
          if (!_isSpeakCompletionAwaited) {
            await _flutterTts.awaitSpeakCompletion(true);
            _isSpeakCompletionAwaited = true;
          }
          return await _flutterTts.speak(text) == TtsConfig.PLATFORM_SUCCESS;
        },
      );

  @override
  Future<SpokenAudio?> synthesizeAudio({required String text}) async {
    final Uint8List? wav = await _synthesizeToWav(text: text);
    if (wav == null) return null;
    try {
      return await spokenAudioFromEngineWavInIsolate(wav: wav, barsPerSecond: MyanmarTtsConfig.WAVEFORM_BARS_PER_SECOND);
    } on FormatException catch (error) {
      // 16-bit PCM မဟုတ်သော engine (ဥပမာ float/8-bit) — speak ဖြင့် ဆက်ဖတ်နိုင်ရန် null ပြန်ပေးသည်။
      developer.log('operation=decodeSynthesizedFile result=unsupported_format', name: _LOG_NAME, error: error);
      return null;
    }
  }

  Future<Uint8List?> _synthesizeToWav({required String text}) async {
    final File file = File('${(await _temporaryDirectory()).path}/${TtsConfig.SYNTHESIS_TEMPORARY_FILE}');
    final Completer<bool> synthesis = Completer<bool>();
    _pendingSynthesis = synthesis;
    _hasSynthesisStarted = false;
    // Engine မစပါက (ဖိုင်ထုတ်မှု မပံ့ပိုး) callback မလာသဖြင့် ကန့်သတ်ချိန်ပြီးလျှင် လက်လျှော့သည်။
    final Timer startTimeout = Timer(_synthesisStartTimeout, () {
      if (_hasSynthesisStarted || !identical(_pendingSynthesis, synthesis)) return;
      developer.log('operation=synthesizeToFile result=not_started', name: _LOG_NAME);
      _finishSynthesis(isWritten: false);
    });
    Uint8List? wav;
    try {
      // Engine က "ပြီးပြီ" ဟုဆိုသော်လည်း မရေးခဲ့ပါက ယခင်အသံကို မှားဖတ်မိစေရန် အရင်ဖျက်သည်။
      await _deleteQuietly(file: file);
      await _guard(
        operation: 'synthesizeToFile',
        action: () => _flutterTts.synthesizeToFile(text, file.path, true),
      );
      if (!await synthesis.future) return null;
      wav = await _readWav(file: file);
      return wav;
    } finally {
      startTimeout.cancel();
      if (identical(_pendingSynthesis, synthesis)) _pendingSynthesis = null;
      // အောင်မြင်ပါက နောက်တစ်ကြိမ် ထုတ်သည်အထိ ထားပြီး (အစားထိုးမည်)၊ မအောင်မြင်ပါက တစ်ဝက်ရေးထားသော ဖိုင် မကျန်စေရန် ဖျက်သည်။
      if (wav == null) await _deleteQuietly(file: file);
    }
  }

  @override
  Future<void> stop() {
    // Plugin က ဖိုင်ထုတ်ခြင်း ရပ်ကြောင်း callback မပို့သဖြင့် စောင့်နေသူကို ကိုယ်တိုင် လွှတ်သည်။
    _finishSynthesis(isWritten: false);
    return _guard(
      operation: 'stop',
      action: () => _flutterTts.stop(),
    );
  }

  void _finishSynthesis({required bool isWritten}) {
    final Completer<bool>? synthesis = _pendingSynthesis;
    _pendingSynthesis = null;
    if (synthesis != null && !synthesis.isCompleted) synthesis.complete(isWritten);
  }

  /// Engine က "ပြီးပြီ" ဟုဆိုသော်လည်း ဖိုင် မရှိ/ဗလာ ဖြစ်နိုင်သဖြင့် (engine အချို့) null အဖြစ် ပြန်ပေး၍ speak သို့ ပြောင်းစေသည်။
  Future<Uint8List?> _readWav({required File file}) async {
    try {
      final Uint8List wav = await file.readAsBytes();
      return wav.isEmpty ? null : wav;
    } on FileSystemException catch (error, stackTrace) {
      developer.log('operation=readSynthesizedFile result=failed', name: _LOG_NAME, error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// ယာယီဖိုင် ဖျက်၍ မရခြင်းသည် engine က အစားထိုးရေးမည်ဖြစ်၍ log သာ ထုတ်သည်။
  Future<void> _deleteQuietly({required File file}) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      developer.log('operation=deleteSynthesizedFile result=failed', name: _LOG_NAME, error: error);
    }
  }

  /// Platform channel အမှားအားလုံးကို log ထုတ်ပြီး [TtsServiceException] အဖြစ် တစ်နေရာတည်းတွင် ပြောင်းသည်။
  Future<T> _guard<T>({
    required String operation,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'operation=$operation result=failed code=${error.code} message=${error.message}',
        name: _LOG_NAME,
        error: error,
        stackTrace: stackTrace,
      );
      throw TtsServiceException(operation: operation, platformMessage: error.message);
    } on MissingPluginException catch (error, stackTrace) {
      developer.log(
        'operation=$operation result=unsupported_platform',
        name: _LOG_NAME,
        error: error,
        stackTrace: stackTrace,
      );
      throw TtsServiceException(operation: operation, platformMessage: error.message);
    }
  }
}
