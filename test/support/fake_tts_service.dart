import 'dart:async';

import 'package:rnd_text_to_speech/services/tts_service.dart';

/// စက်အစစ်မလိုဘဲ engine အခြေအနေအမျိုးမျိုးကို ပြန်ဖန်တီးရန် fake။
class FakeTtsService implements TtsService {
  FakeTtsService({
    this.engines = const <String>[],
    this.burmeseEngines = const <String>{},
    this.maxInputLength = 4000,
    this.isSpeakSuccessful = true,
    this.failingOperation,
  });

  final List<String> engines;
  final Set<String> burmeseEngines;
  final int maxInputLength;
  final bool isSpeakSuccessful;

  /// ဤ operation ကို ခေါ်လျှင် [TtsServiceException] ပစ်မည်။
  final String? failingOperation;

  String? activeEngine;
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
  Future<bool> isLanguageAvailable({required String languageTag}) async =>
      burmeseEngines.contains(activeEngine);

  @override
  Future<bool> setLanguage({required String languageTag}) async =>
      burmeseEngines.contains(activeEngine);

  @override
  Future<void> setSpeechRate({required double rate}) async => appliedRate = rate;

  @override
  Future<void> setPitch({required double pitch}) async => appliedPitch = pitch;

  @override
  Future<int> getMaxInputLength() async => maxInputLength;

  @override
  Future<bool> speak({required String text}) async {
    _failIf(operation: 'speak');
    spokenText = text;
    final Completer<bool>? pending = pendingSpeak;
    return pending == null ? isSpeakSuccessful : pending.future;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    // Plugin သည် stop တွင် ဆိုင်းငံ့နေသော speak ကို 0 (false) ဖြင့် ပြီးစေသည်။
    pendingSpeak?.complete(false);
    pendingSpeak = null;
  }
}
