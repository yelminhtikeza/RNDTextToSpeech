import 'dart:async';
import 'dart:typed_data';

import 'package:rnd_text_to_speech/config/myanmartts_config.dart';

import 'package:rnd_text_to_speech/myanmartts/burmese_tokenizer.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_speaker.dart';
import 'package:rnd_text_to_speech/myanmartts/synthesis_settings.dart';
import 'package:rnd_text_to_speech/myanmartts/wav_encoder.dart';
import 'package:rnd_text_to_speech/myanmartts/waveform_summary.dart';

/// Controller test များအတွက် ONNX/audio မလိုသော speaker fake။
class FakeOnDeviceSpeaker implements OnDeviceSpeaker {
  FakeOnDeviceSpeaker({this.loadError, this.speakError});

  final MyanmarTtsException? loadError;
  final MyanmarTtsException? speakError;

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

  @override
  Future<SpokenAudio?> speak({required String text, required SynthesisSettings settings}) async {
    if (speakError case final MyanmarTtsException error) throw error;
    _wasStopped = false;
    spokenText = text;
    this.settings = settings;
    await pendingSpeak?.future;
    if (_wasStopped) return null;
    // Isolate မသုံးဘဲ တွက်သည် — widget test ၏ fake time တွင် isolate အစစ် မပြီးနိုင်သောကြောင့်။
    return SpokenAudio(
      wav: spokenAudio,
      waveform: WaveformSummary.fromPcm16Wav(wav: spokenAudio, barCount: MyanmarTtsConfig.WAVEFORM_BAR_COUNT),
    );
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    _wasStopped = true;
    pendingSpeak?.complete();
    pendingSpeak = null;
  }

  @override
  Future<void> dispose() async {}
}
