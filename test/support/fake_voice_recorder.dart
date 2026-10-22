import 'dart:typed_data';

import 'package:rnd_text_to_speech/myanmartts/wav_encoder.dart';
import 'package:rnd_text_to_speech/services/voice_recorder.dart';

/// Mic အစစ် မလိုဘဲ သတ်မှတ်ထားသော အရှည်ရှိ WAV ကို ပြန်ပေးသော recorder fake။
class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.hasPermission = true, this.recordedSeconds = 6, this.sampleRate = 44100, this.startError});

  final bool hasPermission;
  final int recordedSeconds;
  final int sampleRate;
  final VoiceRecorderException? startError;

  int startCallCount = 0;
  int cancelCallCount = 0;

  static Uint8List wavOf({required int seconds, required int sampleRate}) => const WavEncoder()
      .encodePcm16(samples: Float32List.fromList(List<double>.filled(seconds * sampleRate, 0.1)), sampleRate: sampleRate);

  @override
  Future<bool> requestPermission() async => hasPermission;

  @override
  Future<void> start() async {
    if (startError case final VoiceRecorderException error) throw error;
    startCallCount++;
  }

  @override
  Future<Uint8List> stop() async => wavOf(seconds: recordedSeconds, sampleRate: sampleRate);

  @override
  Future<void> cancel() async => cancelCallCount++;

  @override
  Future<void> dispose() async {}
}
