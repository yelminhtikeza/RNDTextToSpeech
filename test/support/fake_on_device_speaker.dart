import 'dart:async';
import 'dart:typed_data';

import 'package:rnd_text_to_speech/config/myanmartts_config.dart';

import 'package:rnd_text_to_speech/myanmartts/burmese_tokenizer.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_speaker.dart';
import 'package:rnd_text_to_speech/myanmartts/synthesis_settings.dart';
import 'package:rnd_text_to_speech/myanmartts/wav_encoder.dart';
import 'package:rnd_text_to_speech/myanmartts/waveform_summary.dart';
import 'package:rnd_text_to_speech/services/audio_output.dart';

/// Controller test များအတွက် ONNX/audio မလိုသော speaker fake။
class FakeOnDeviceSpeaker implements OnDeviceSpeaker {
  FakeOnDeviceSpeaker({this.loadError, this.speakError, this.replayError});

  final MyanmarTtsException? loadError;
  final MyanmarTtsException? speakError;
  final AudioOutputException? replayError;

  final List<Uint8List> replayed = <Uint8List>[];

  /// createVoiceEmbedding() ပြန်ပေးမည့် လက်ဗွေ၊ ခေါ်ခဲ့သော recording များ။
  final Float32List createdEmbedding = Float32List(MyanmarTtsConfig.SPEAKER_EMBEDDING_SIZE)..[2] = 1;
  final List<({int samples, int sampleRate})> embeddingRequests = <({int samples, int sampleRate})>[];
  MyanmarTtsException? embeddingError;

  /// သတ်မှတ်ထားပါက replay() သည် stop() ခေါ်သည်အထိ ဆိုင်းငံ့နေမည်။
  Completer<void>? pendingReplay;

  /// Test က player position ကို ထုတ်ပေးရန်။
  final StreamController<Duration> positions = StreamController<Duration>.broadcast();
  final List<Duration> replayStarts = <Duration>[];
  final List<Duration> seeks = <Duration>[];
  final List<String> controls = <String>[];
  AudioOutputException? controlError;

  int loadCallCount = 0;
  String? spokenText;
  SynthesisSettings? settings;
  int stopCallCount = 0;

  /// အဆုံးထိ ဖတ်ပြီးချိန်တွင် ပြန်ပေးမည့် အသံ — 0.5 စက္ကန့် (44.1 kHz)၊ amplitude 0.5။
  final Uint8List spokenAudio = const WavEncoder().encodePcm16(
    samples: Float32List.fromList(List<double>.filled(22050, 0.5)),
    sampleRate: 44100,
  );
  bool _wasStopped = false;

  /// သတ်မှတ်ထားပါက speak() သည် stop() ခေါ်သည်အထိ ဆိုင်းငံ့နေမည်။
  Completer<void>? pendingSpeak;

  @override
  Future<void> load() async {
    loadCallCount++;
    if (loadError case final MyanmarTtsException error) throw error;
  }

  @override
  bool hasSpeakableText({required String text}) => const BurmeseTokenizer().hasSpeakableText(text: text);

  /// Isolate မသုံးဘဲ တွက်သည် — widget test ၏ fake time တွင် isolate အစစ် မပြီးနိုင်သောကြောင့်။
  WaveformSummary get spokenWaveform =>
      WaveformSummary.fromPcm16Wav(wav: spokenAudio, barsPerSecond: MyanmarTtsConfig.WAVEFORM_BARS_PER_SECOND);

  @override
  Stream<Duration> get positionChanges => positions.stream;

  @override
  Future<SpokenAudio?> speak({
    required String text,
    required SynthesisSettings settings,
    required void Function(WaveformSummary waveform) onWaveformChanged,
  }) async {
    if (speakError case final MyanmarTtsException error) throw error;
    _wasStopped = false;
    spokenText = text;
    this.settings = settings;
    onWaveformChanged(spokenWaveform);
    await pendingSpeak?.future;
    if (_wasStopped) return null;
    return SpokenAudio(wav: spokenAudio, waveform: spokenWaveform);
  }

  @override
  Future<Float32List> createVoiceEmbedding({required Float32List waveform, required int sampleRate}) async {
    if (embeddingError case final MyanmarTtsException error) throw error;
    embeddingRequests.add((samples: waveform.length, sampleRate: sampleRate));
    return createdEmbedding;
  }

  @override
  Future<void> replay({required Uint8List wav, Duration startAt = Duration.zero}) async {
    if (replayError case final AudioOutputException error) throw error;
    replayed.add(wav);
    replayStarts.add(startAt);
    await pendingReplay?.future;
  }

  @override
  Future<void> pause() async => _control(name: 'pause');

  @override
  Future<void> resume() async => _control(name: 'resume');

  @override
  Future<void> seek({required Duration position}) async {
    _control(name: 'seek');
    seeks.add(position);
  }

  void _control({required String name}) {
    if (controlError case final AudioOutputException error) throw error;
    controls.add(name);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    _wasStopped = true;
    pendingSpeak?.complete();
    pendingSpeak = null;
    pendingReplay?.complete();
    pendingReplay = null;
  }

  @override
  Future<void> dispose() async {}
}
