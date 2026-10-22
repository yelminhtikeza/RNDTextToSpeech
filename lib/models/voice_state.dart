import 'voice_profile.dart';

enum VoiceLibraryStatus { loading, ready, failed }

class VoiceState {
  const VoiceState({
    required this.status,
    this.voices = const <VoiceProfile>[],
    this.selectedVoiceId,
    this.platformMessage,
  });

  const VoiceState.loading() : this(status: VoiceLibraryStatus.loading);

  final VoiceLibraryStatus status;

  /// Preset များ (ပထမ = ပုံသေ) နောက်တွင် custom အသံများ။
  final List<VoiceProfile> voices;
  final String? selectedVoiceId;

  /// Load မအောင်မြင်ပါက platform မှ မူရင်းစာ။
  final String? platformMessage;

  VoiceProfile? get selectedVoice {
    for (final VoiceProfile voice in voices) {
      if (voice.id == selectedVoiceId) return voice;
    }
    return null;
  }

  bool get isReady => status == VoiceLibraryStatus.ready;

  VoiceState copyWith({List<VoiceProfile>? voices, String? selectedVoiceId}) => VoiceState(
        status: status,
        voices: voices ?? this.voices,
        selectedVoiceId: selectedVoiceId ?? this.selectedVoiceId,
      );
}

enum VoiceChangeStatus { done, tooShort, failed }

/// အသံ ထည့်/ဖျက်ခြင်း၏ ရလဒ် — UI က တစ်ကြိမ်သာ ပြရမည်ဖြစ်၍ state ထဲ မထည့်ဘဲ ပြန်ပေးသည်။
class VoiceChangeResult {
  const VoiceChangeResult({required this.status, this.platformMessage});

  final VoiceChangeStatus status;
  final String? platformMessage;
}
