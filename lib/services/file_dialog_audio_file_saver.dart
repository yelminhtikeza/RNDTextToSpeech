import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

import '../config/myanmartts_config.dart';
import 'audio_file_saver.dart';

/// [AudioFileSaver] ကို Android Storage Access Framework ("Save as" dialog) ဖြင့် အကောင်အထည်ဖော်ထားခြင်း။
/// MediaStore ဖြင့် Downloads သို့ တိုက်ရိုက်ရေးခြင်းကို မရွေးခြင်းမှာ Android version အလိုက် permission
/// ကွဲပြားမှုကို ရှောင်ရန်နှင့် အသုံးပြုသူကိုယ်တိုင် နေရာ/အမည် ရွေးနိုင်ရန် ဖြစ်သည်။
class FileDialogAudioFileSaver implements AudioFileSaver {
  const FileDialogAudioFileSaver();

  static const String _LOG_NAME = 'myanmartts.save';

  @override
  Future<String?> saveWav({required Uint8List wav, required String fileName}) async {
    try {
      final String? savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: wav,
          fileName: fileName,
          mimeTypesFilter: const <String>[MyanmarTtsConfig.WAV_MIME_TYPE],
        ),
      );
      developer.log('action=saveWav bytes=${wav.length} result=${savedPath == null ? 'cancelled' : 'saved'}',
          name: _LOG_NAME);
      return savedPath;
    } on PlatformException catch (error, stackTrace) {
      developer.log('action=saveWav result=failed code=${error.code}',
          name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw AudioSaveException(platformMessage: error.message);
    }
  }
}
