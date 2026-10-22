import 'dart:typed_data';

import 'package:rnd_text_to_speech/config/myanmartts_config.dart';
import 'package:rnd_text_to_speech/models/voice_profile.dart';
import 'package:rnd_text_to_speech/services/voice_library.dart';

/// Asset/ဖိုင်စနစ် မလိုဘဲ preset နှစ်ခုနှင့် custom အသံ သိမ်းခြင်းကို မှတ်တမ်းတင်သော fake။
class FakeVoiceLibrary implements VoiceLibrary {
  FakeVoiceLibrary({this.loadError, this.saveError, List<VoiceProfile>? customVoices})
      : savedCustomVoices = customVoices ?? <VoiceProfile>[];

  static final VoiceProfile original = _preset(id: 'original', labelEn: 'Original (female)', labelMy: 'မူလ', value: 0.1);
  static final VoiceProfile male = _preset(id: 'male_3', labelEn: 'Male 3', labelMy: 'အမျိုးသား ၃', value: 0.2);

  final VoiceLibraryException? loadError;
  final VoiceLibraryException? saveError;
  List<VoiceProfile> savedCustomVoices;
  int saveCallCount = 0;

  @override
  Future<List<VoiceProfile>> loadPresets() async {
    if (loadError case final VoiceLibraryException error) throw error;
    return <VoiceProfile>[original, male];
  }

  @override
  Future<List<VoiceProfile>> loadCustomVoices() async => savedCustomVoices;

  @override
  Future<void> saveCustomVoices({required List<VoiceProfile> voices}) async {
    if (saveError case final VoiceLibraryException error) throw error;
    saveCallCount++;
    savedCustomVoices = voices;
  }

  static VoiceProfile _preset({required String id, required String labelEn, required String labelMy, required double value}) =>
      VoiceProfile(
        id: id,
        labelEn: labelEn,
        labelMy: labelMy,
        embedding: Float32List(MyanmarTtsConfig.SPEAKER_EMBEDDING_SIZE)..fillRange(0, 4, value),
        isCustom: false,
      );
}
