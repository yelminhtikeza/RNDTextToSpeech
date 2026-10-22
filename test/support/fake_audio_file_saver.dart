import 'dart:typed_data';

import 'package:rnd_text_to_speech/services/audio_file_saver.dart';

/// "Save as" dialog အစား အသုံးပြုသူ၏ ရွေးချယ်မှုကို ပုံတူဖန်တီးသော fake။
class FakeAudioFileSaver implements AudioFileSaver {
  FakeAudioFileSaver({this.isCancelled = false, this.error});

  final bool isCancelled;
  final AudioSaveException? error;

  Uint8List? savedWav;
  String? savedFileName;

  @override
  Future<String?> saveWav({required Uint8List wav, required String fileName}) async {
    if (error case final AudioSaveException failure) throw failure;
    if (isCancelled) return null;
    savedWav = wav;
    savedFileName = fileName;
    return '/storage/emulated/0/Download/$fileName';
  }
}
