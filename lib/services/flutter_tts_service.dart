import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../config/tts_config.dart';
import 'tts_service.dart';

/// [TtsService] ကို flutter_tts plugin ဖြင့် အကောင်အထည်ဖော်ထားခြင်း။
/// Plugin ၏ `dynamic` ပြန်တန်ဖိုးများကို ဤနေရာတွင်သာ type ပြောင်းပြီး ကျန် app သို့ မပေါက်ကြားစေပါ။
class FlutterTtsService implements TtsService {
  FlutterTtsService({required FlutterTts flutterTts}) : _flutterTts = flutterTts;

  static const String _LOG_NAME = 'tts.service';

  final FlutterTts _flutterTts;
  bool _isSpeakCompletionAwaited = false;

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
  Future<bool> isLanguageAvailable({required String languageTag}) => _guard(
        operation: 'isLanguageAvailable',
        action: () async => await _flutterTts.isLanguageAvailable(languageTag) == true,
      );

  @override
  Future<bool> setLanguage({required String languageTag}) => _guard(
        operation: 'setLanguage',
        action: () async =>
            await _flutterTts.setLanguage(languageTag) == TtsConfig.PLATFORM_SUCCESS,
      );

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
  Future<void> stop() => _guard(
        operation: 'stop',
        action: () => _flutterTts.stop(),
      );

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
