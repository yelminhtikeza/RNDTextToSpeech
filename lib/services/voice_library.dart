import '../models/voice_profile.dart';

/// Preset အသံ (app asset) နှင့် custom အသံ (ဖုန်း storage) ကို ဖတ်/သိမ်းသည့် boundary။
abstract interface class VoiceLibrary {
  Future<List<VoiceProfile>> loadPresets();

  Future<List<VoiceProfile>> loadCustomVoices();

  Future<void> saveCustomVoices({required List<VoiceProfile> voices});
}

class VoiceLibraryException implements Exception {
  const VoiceLibraryException({required this.operation, this.platformMessage});

  final String operation;
  final String? platformMessage;

  @override
  String toString() => 'VoiceLibraryException($operation): $platformMessage';
}
