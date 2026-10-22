import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../config/myanmartts_config.dart';
import '../models/voice_recording_state.dart';
import '../models/voice_state.dart';
import '../myanmartts/wav_decoder.dart';
import '../services/record_voice_recorder.dart';
import '../services/voice_recorder.dart';
import 'voice_controller.dart';

final voiceRecorderProvider = Provider.autoDispose<VoiceRecorder>((Ref ref) {
  final RecordVoiceRecorder recorder = RecordVoiceRecorder(recorder: AudioRecorder());
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// အသံသွင်း sheet ပိတ်လျှင် recorder နှင့် timer ကို ရှင်းရန် autoDispose ဖြစ်သည်။
final voiceRecordingControllerProvider =
    NotifierProvider.autoDispose<VoiceRecordingController, VoiceRecordingState>(VoiceRecordingController.new);

/// အသံအသစ် သွင်းခြင်း session တစ်ခု — permission၊ အချိန်ကန့်သတ်ချက်၊ အမည်ပေး၍ သိမ်းခြင်း။
class VoiceRecordingController extends Notifier<VoiceRecordingState> {
  static const String _LOG_NAME = 'myanmartts.recording';
  static const Duration _TICK = Duration(milliseconds: 200);
  static const WavDecoder _DECODER = WavDecoder();

  Timer? _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  Uint8List? _recordedWav;

  /// Build တွင် တစ်ကြိမ်သာ ယူထားသည် — dispose ချိန်တွင် ref ကို သုံး၍ မရသောကြောင့်။
  late VoiceRecorder _recorder;

  @override
  VoiceRecordingState build() {
    // Recorder provider ကို sheet ဖွင့်ထားသရွေ့ ရှင်သန်စေရန် watch လုပ်သည်။
    final VoiceRecorder recorder = ref.watch(voiceRecorderProvider);
    _recorder = recorder;
    ref.onDispose(() {
      _ticker?.cancel();
      // ပိတ်လိုက်ချိန် သွင်းဆဲဖြစ်ပါက mic ကို ပိတ်ပြီး ယာယီဖိုင် မကျန်စေရန်။
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        unawaited(recorder.cancel().catchError((Object error) {
          developer.log('action=cancelOnClose result=failed', name: _LOG_NAME, error: error);
        }));
      }
    });
    return const VoiceRecordingState();
  }

  Future<void> startRecording() async {
    try {
      if (!await _recorder.requestPermission()) {
        state = state.withError(error: RecordingError.permissionDenied, phase: RecordingPhase.idle);
        return;
      }
      await _recorder.start();
    } on VoiceRecorderException catch (error) {
      state = state.withError(error: RecordingError.failed, phase: RecordingPhase.idle, platformMessage: error.platformMessage);
      return;
    }
    _recordedWav = null;
    _stopwatch
      ..reset()
      ..start();
    state = const VoiceRecordingState(phase: RecordingPhase.recording);
    _ticker = Timer.periodic(_TICK, (_) => _onTick());
  }

  Future<void> stopRecording() async {
    _ticker?.cancel();
    _stopwatch.stop();
    final Duration elapsed = _stopwatch.elapsed;
    try {
      final Uint8List wav = await _recorder.stop();
      if (!ref.mounted) return;
      // Stopwatch သည် mic စတင်ချိန်ပါ ပါဝင်သဖြင့် အရှည်ကို WAV ထဲက အမှန်တကယ် sample များဖြင့် တိုင်းသည်။
      final ({Float32List samples, int sampleRate}) decoded = _DECODER.decodePcm16(wav: wav);
      final Duration recorded =
          Duration(microseconds: decoded.samples.length * Duration.microsecondsPerSecond ~/ decoded.sampleRate);
      developer.log('action=stop elapsed_ms=${elapsed.inMilliseconds} recorded_ms=${recorded.inMilliseconds}',
          name: _LOG_NAME);
      if (recorded < MyanmarTtsConfig.MIN_RECORDING) {
        state = state.withError(error: RecordingError.tooShort, phase: RecordingPhase.idle);
        return;
      }
      _recordedWav = wav;
      state = VoiceRecordingState(phase: RecordingPhase.recorded, elapsed: recorded);
    } on FormatException catch (error) {
      if (!ref.mounted) return;
      state = state.withError(error: RecordingError.failed, phase: RecordingPhase.idle, platformMessage: error.message);
    } on VoiceRecorderException catch (error) {
      if (!ref.mounted) return;
      state = state.withError(error: RecordingError.failed, phase: RecordingPhase.idle, platformMessage: error.platformMessage);
    }
  }

  void discardRecording() {
    _recordedWav = null;
    state = const VoiceRecordingState();
  }

  /// အမည်ပေး၍ သိမ်းသည်။ အောင်မြင်ပါက true (sheet ပိတ်ရန်)။
  Future<bool> saveVoice({required String name}) async {
    final Uint8List? wav = _recordedWav;
    final String trimmedName = name.trim();
    if (wav == null) return false;
    if (trimmedName.isEmpty) {
      state = state.withError(error: RecordingError.nameEmpty, phase: RecordingPhase.recorded);
      return false;
    }

    state = state.copyWith(phase: RecordingPhase.saving);
    final VoiceChangeResult result =
        await ref.read(voiceControllerProvider.notifier).addRecordedVoice(name: trimmedName, wav: wav);
    if (!ref.mounted) return result.status == VoiceChangeStatus.done;
    switch (result.status) {
      case VoiceChangeStatus.done:
        _recordedWav = null;
        state = const VoiceRecordingState();
        return true;
      case VoiceChangeStatus.tooShort:
        state = state.withError(error: RecordingError.tooShort, phase: RecordingPhase.idle);
        return false;
      case VoiceChangeStatus.failed:
        state = state.withError(
            error: RecordingError.failed, phase: RecordingPhase.recorded, platformMessage: result.platformMessage);
        return false;
    }
  }

  void _onTick() {
    final Duration elapsed = _stopwatch.elapsed;
    if (elapsed >= MyanmarTtsConfig.MAX_RECORDING) {
      unawaited(stopRecording());
      return;
    }
    state = state.copyWith(elapsed: elapsed);
  }
}
