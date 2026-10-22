import 'dart:typed_data';

/// Mic မှ WAV အသံသွင်းသည့် boundary — recording flow ကို ဖုန်းအစစ် မလိုဘဲ test လုပ်နိုင်ရန်။
abstract interface class VoiceRecorder {
  /// Mic permission ကို တောင်းပြီး ရ/မရ ပြန်ပေးသည်။
  Future<bool> requestPermission();

  Future<void> start();

  /// သွင်းထားသော 16-bit PCM WAV bytes။
  Future<Uint8List> stop();

  /// သွင်းထားသမျှကို ပယ်ပြီး ယာယီဖိုင်ကို ဖျက်သည်။
  Future<void> cancel();

  Future<void> dispose();
}

class VoiceRecorderException implements Exception {
  const VoiceRecorderException({required this.operation, this.platformMessage});

  final String operation;
  final String? platformMessage;

  @override
  String toString() => 'VoiceRecorderException($operation): $platformMessage';
}
