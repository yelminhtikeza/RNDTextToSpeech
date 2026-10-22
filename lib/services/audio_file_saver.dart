import 'dart:typed_data';

/// ထုတ်ထားသော အသံကို အသုံးပြုသူ ရွေးသော နေရာတွင် သိမ်းသည့် boundary။
abstract interface class AudioFileSaver {
  /// "Save as" dialog ဖွင့်ပြီး သိမ်းသည်။ သိမ်းပြီးပါက နေရာ (path/URI) ကို၊ အသုံးပြုသူ ပယ်ဖျက်ပါက null ကို ပြန်ပေးသည်။
  Future<String?> saveWav({required Uint8List wav, required String fileName});
}

class AudioSaveException implements Exception {
  const AudioSaveException({this.platformMessage});

  final String? platformMessage;

  @override
  String toString() => 'AudioSaveException: $platformMessage';
}
