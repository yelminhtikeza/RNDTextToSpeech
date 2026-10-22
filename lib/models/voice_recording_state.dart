enum RecordingPhase { idle, recording, recorded, saving }

/// UI က ဘာသာပြန်စာအဖြစ် ပြမည့် အသံသွင်း အမှား။
enum RecordingError { permissionDenied, tooShort, nameEmpty, failed }

class VoiceRecordingState {
  const VoiceRecordingState({
    this.phase = RecordingPhase.idle,
    this.elapsed = Duration.zero,
    this.error,
    this.platformMessage,
  });

  final RecordingPhase phase;
  final Duration elapsed;
  final RecordingError? error;

  /// Platform မှ မူရင်းအမှားစာ — ပြင်ဆင်ခြင်းမပြုဘဲ ပြရန်။
  final String? platformMessage;

  bool get isRecording => phase == RecordingPhase.recording;

  bool get isSaving => phase == RecordingPhase.saving;

  bool get hasRecording => phase == RecordingPhase.recorded || phase == RecordingPhase.saving;

  VoiceRecordingState copyWith({RecordingPhase? phase, Duration? elapsed}) =>
      VoiceRecordingState(phase: phase ?? this.phase, elapsed: elapsed ?? this.elapsed);

  VoiceRecordingState withError({required RecordingError error, required RecordingPhase phase, String? platformMessage}) =>
      VoiceRecordingState(phase: phase, elapsed: elapsed, error: error, platformMessage: platformMessage);
}
