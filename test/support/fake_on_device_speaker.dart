import 'dart:async';
import 'dart:typed_data';

import 'package:rnd_text_to_speech/myanmartts/burmese_tokenizer.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_models.dart';
import 'package:rnd_text_to_speech/myanmartts/myanmar_tts_speaker.dart';

/// Controller test များအတွက် ONNX/audio မလိုသော speaker fake။
class FakeOnDeviceSpeaker implements OnDeviceSpeaker {
  FakeOnDeviceSpeaker({this.loadError, this.speakError});

  final MyanmarTtsException? loadError;
  final MyanmarTtsException? speakError;

  int loadCallCount = 0;
  String? spokenText;
  double? lengthScale;
  int stopCallCount = 0;

  /// အဆုံးထိ ဖတ်ပြီးချိန်တွင် ပြန်ပေးမည့် အသံ။
  final Uint8List spokenAudio = Uint8List.fromList(<int>[1, 2, 3, 4]);
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
  Future<Uint8List?> speak({required String text, required double lengthScale}) async {
    if (speakError case final MyanmarTtsException error) throw error;
    _wasStopped = false;
    spokenText = text;
    this.lengthScale = lengthScale;
    await pendingSpeak?.future;
    return _wasStopped ? null : spokenAudio;
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
