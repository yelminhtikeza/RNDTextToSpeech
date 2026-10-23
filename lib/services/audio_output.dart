import 'dart:typed_data';

/// Memory ထဲရှိ WAV ကို ဖွင့်သည့် boundary — speaker ကို စက်အစစ်မလိုဘဲ test လုပ်နိုင်ရန် interface ခွဲထားသည်။
abstract interface class AudioOutput {
  /// [startAt] မှ စဖွင့်ပြီး ဖွင့်ပြီးဆုံးသည် သို့မဟုတ် [stop] ခေါ်သည်အထိ စောင့်သည် ([pause] ထားစဉ်လည်း ဆက်စောင့်သည်)။
  Future<void> playWav({required Uint8List wav, Duration startAt = Duration.zero});

  /// ဖွင့်နေသော WAV အတွင်း လက်ရှိ နေရာ — ဖွင့်နေစဉ်သာ ထုတ်သည်။
  Stream<Duration> get positionChanges;

  Future<void> pause();

  Future<void> resume();

  Future<void> seek({required Duration position});

  Future<void> stop();

  Future<void> dispose();
}

class AudioOutputException implements Exception {
  const AudioOutputException({required this.operation, this.platformMessage});

  final String operation;
  final String? platformMessage;

  @override
  String toString() => 'AudioOutputException($operation): $platformMessage';
}
