import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/myanmartts_config.dart';
import '../models/voice_profile.dart';
import '../models/voice_state.dart';
import '../myanmartts/myanmar_tts_models.dart';
import '../myanmartts/wav_decoder.dart';
import '../services/file_voice_library.dart';
import '../services/voice_library.dart';
import 'burmese_speech_controller.dart';

final voiceLibraryProvider = Provider<VoiceLibrary>((Ref ref) => FileVoiceLibrary(bundle: rootBundle));

final voiceControllerProvider = NotifierProvider<VoiceController, VoiceState>(VoiceController.new);

/// MyanmarTTS အသံ ရွေးခြင်း၊ အသံသွင်း၍ ထည့်ခြင်း၊ ဖျက်ခြင်း၏ logic တစ်ခုတည်းသော နေရာ။
/// Speech controller နှင့် ခွဲထားခြင်းမှာ အသံစာရင်းသည် engine/ဖတ်ခြင်း state နှင့် သီးခြား lifecycle ရှိသောကြောင့် ဖြစ်သည်။
class VoiceController extends Notifier<VoiceState> {
  static const String _LOG_NAME = 'myanmartts.voices';
  static const String _CUSTOM_ID_PREFIX = 'custom_';
  static const WavDecoder _DECODER = WavDecoder();

  /// Speech controller က ဖတ်ခြင်း မစမီ စောင့်နိုင်ရန် — load ကို တစ်ကြိမ်သာ လုပ်သည်။
  Future<void>? _loading;

  VoiceLibrary get _library => ref.read(voiceLibraryProvider);

  @override
  VoiceState build() {
    Future<void>.microtask(ensureLoaded);
    return const VoiceState.loading();
  }

  Future<void> ensureLoaded() => _loading ??= loadVoices();

  Future<void> loadVoices() async {
    state = const VoiceState.loading();
    try {
      final List<VoiceProfile> presets = await _library.loadPresets();
      final List<VoiceProfile> custom = await _library.loadCustomVoices();
      if (!ref.mounted) return;
      developer.log('action=loadVoices presets=${presets.length} custom=${custom.length}', name: _LOG_NAME);
      state = VoiceState(
        status: VoiceLibraryStatus.ready,
        voices: <VoiceProfile>[...presets, ...custom],
        selectedVoiceId: presets.isEmpty ? null : presets.first.id,
      );
    } on VoiceLibraryException catch (error) {
      if (!ref.mounted) return;
      state = VoiceState(status: VoiceLibraryStatus.failed, platformMessage: error.platformMessage);
    }
  }

  void selectVoice({required String voiceId}) {
    state = state.copyWith(selectedVoiceId: voiceId);
  }

  /// အသံသွင်းထားသော [wav] မှ လက်ဗွေ တွက်ပြီး custom အသံအဖြစ် သိမ်းကာ ရွေးထားသည်။
  Future<VoiceChangeResult> addRecordedVoice({required String name, required Uint8List wav}) async {
    final ({Float32List samples, int sampleRate}) decoded;
    try {
      decoded = _DECODER.decodePcm16(wav: wav);
    } on FormatException catch (error) {
      developer.log('action=addVoice result=bad_wav', name: _LOG_NAME, error: error);
      return VoiceChangeResult(status: VoiceChangeStatus.failed, platformMessage: error.message);
    }
    if (decoded.samples.length < decoded.sampleRate * MyanmarTtsConfig.MIN_RECORDING.inSeconds) {
      return const VoiceChangeResult(status: VoiceChangeStatus.tooShort);
    }

    try {
      final Float32List embedding = await ref
          .read(onDeviceSpeakerProvider)
          .createVoiceEmbedding(waveform: decoded.samples, sampleRate: decoded.sampleRate);
      final VoiceProfile voice = VoiceProfile(
        id: '$_CUSTOM_ID_PREFIX${DateTime.now().microsecondsSinceEpoch}',
        labelEn: name,
        labelMy: name,
        embedding: embedding,
        isCustom: true,
      );
      final List<VoiceProfile> voices = <VoiceProfile>[...state.voices, voice];
      await _library.saveCustomVoices(voices: _customOnly(voices: voices));
      if (!ref.mounted) return const VoiceChangeResult(status: VoiceChangeStatus.done);
      developer.log('action=addVoice id=${voice.id} result=ok', name: _LOG_NAME);
      state = state.copyWith(voices: voices, selectedVoiceId: voice.id);
      return const VoiceChangeResult(status: VoiceChangeStatus.done);
    } on MyanmarTtsException catch (error) {
      return VoiceChangeResult(status: VoiceChangeStatus.failed, platformMessage: error.platformMessage);
    } on VoiceLibraryException catch (error) {
      return VoiceChangeResult(status: VoiceChangeStatus.failed, platformMessage: error.platformMessage);
    }
  }

  /// Custom အသံကိုသာ ဖျက်နိုင်သည်။ ရွေးထားသော အသံကို ဖျက်ပါက ပုံသေ (ပထမ preset) သို့ ပြန်သွားသည်။
  Future<VoiceChangeResult> deleteVoice({required String voiceId}) async {
    final List<VoiceProfile> voices = <VoiceProfile>[
      for (final VoiceProfile voice in state.voices)
        if (!(voice.isCustom && voice.id == voiceId)) voice,
    ];
    try {
      await _library.saveCustomVoices(voices: _customOnly(voices: voices));
    } on VoiceLibraryException catch (error) {
      return VoiceChangeResult(status: VoiceChangeStatus.failed, platformMessage: error.platformMessage);
    }
    if (!ref.mounted) return const VoiceChangeResult(status: VoiceChangeStatus.done);
    developer.log('action=deleteVoice id=$voiceId result=ok', name: _LOG_NAME);
    final bool wasSelected = state.selectedVoiceId == voiceId;
    state = state.copyWith(voices: voices, selectedVoiceId: wasSelected ? voices.first.id : null);
    return const VoiceChangeResult(status: VoiceChangeStatus.done);
  }

  static List<VoiceProfile> _customOnly({required List<VoiceProfile> voices}) =>
      voices.where((VoiceProfile voice) => voice.isCustom).toList();
}
