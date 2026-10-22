/// စက်ပေါ်ရှိ TTS engine နှင့် ဆက်သွယ်သည့် boundary။
/// Interface ခွဲထားခြင်းမှာ controller ကို စက်အစစ်မလိုဘဲ test လုပ်နိုင်ရန် ဖြစ်သည်။
abstract interface class TtsService {
  /// ထည့်သွင်းထားသော engine package name များ (ဥပမာ `com.google.android.tts`)။
  Future<List<String>> getEngineNames();

  /// Engine ကို ပြောင်းပြီး initialize ပြီးသည်အထိ စောင့်သည်။
  Future<void> selectEngine({required String engineName});

  Future<bool> isLanguageAvailable({required String languageTag});

  Future<bool> setLanguage({required String languageTag});

  Future<void> setSpeechRate({required double rate});

  Future<void> setPitch({required double pitch});

  Future<int> getMaxInputLength();

  /// ဖတ်ပြီးဆုံးသည်အထိ စောင့်ပြီး အောင်မြင်/မအောင်မြင် ပြန်ပေးသည်။
  Future<bool> speak({required String text});

  Future<void> stop();
}

/// Platform channel မှ ပြန်လာသော အမှားကို domain အမှားအဖြစ် ပြောင်းထားခြင်း။
/// [platformMessage] ကို UI တွင် မပြောင်းလဲဘဲ ပြရန် ထိန်းထားသည်။
class TtsServiceException implements Exception {
  const TtsServiceException({required this.operation, this.platformMessage});

  final String operation;
  final String? platformMessage;

  @override
  String toString() => 'TtsServiceException($operation): $platformMessage';
}
