import 'dart:typed_data';

/// MyanmarTTS ၏ အသံတစ်မျိုး — preset (app နှင့်အတူ ပါလာ) သို့မဟုတ် အသုံးပြုသူ အသံသွင်းထားသော custom။
class VoiceProfile {
  const VoiceProfile({
    required this.id,
    required this.labelEn,
    required this.labelMy,
    required this.embedding,
    required this.isCustom,
  });

  /// `assets/voices/presets.json` ၏ item တစ်ခု။
  factory VoiceProfile.fromPresetJson({required Map<String, dynamic> json}) => VoiceProfile(
        id: json[_ID] as String,
        labelEn: json[_LABEL_EN] as String,
        labelMy: json[_LABEL_MY] as String,
        embedding: _embeddingFromJson(values: json[_EMBEDDING] as List<dynamic>),
        isCustom: false,
      );

  /// Custom အသံကို အသုံးပြုသူ ပေးသော အမည်တစ်ခုတည်းဖြင့် သိမ်းသည် (ဘာသာစကား နှစ်မျိုးလုံးတွင် ထိုအမည်ပြ)။
  factory VoiceProfile.fromCustomJson({required Map<String, dynamic> json}) {
    final String name = json[_NAME] as String;
    return VoiceProfile(
      id: json[_ID] as String,
      labelEn: name,
      labelMy: name,
      embedding: _embeddingFromJson(values: json[_EMBEDDING] as List<dynamic>),
      isCustom: true,
    );
  }

  static const String _ID = 'id';
  static const String _NAME = 'name';
  static const String _LABEL_EN = 'label_en';
  static const String _LABEL_MY = 'label_my';
  static const String _EMBEDDING = 'embedding';

  final String id;
  final String labelEn;
  final String labelMy;

  /// Speaker embedding (အသံ လက်ဗွေ)။
  final Float32List embedding;
  final bool isCustom;

  Map<String, dynamic> toCustomJson() => <String, dynamic>{
        _ID: id,
        _NAME: labelEn,
        _EMBEDDING: embedding.toList(),
      };

  static Float32List _embeddingFromJson({required List<dynamic> values}) =>
      Float32List.fromList(values.cast<num>().map((num value) => value.toDouble()).toList());
}
