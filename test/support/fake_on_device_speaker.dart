import 'dart:async';

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
  Future<void> speak({required String text, required double lengthScale}) async {
    if (speakError case final MyanmarTtsException error) throw error;
    spokenText = text;
    this.lengthScale = lengthScale;
    await pendingSpeak?.future;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    pendingSpeak?.complete();
    pendingSpeak = null;
  }

  @override
  Future<void> dispose() async {}
}
