import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../config/myanmartts_config.dart';
import '../models/voice_profile.dart';
import 'voice_library.dart';

/// Preset ကို asset JSON မှ၊ custom အသံကို app support directory ရှိ JSON ဖိုင်မှ ဖတ်/ရေးသည်။
/// Custom အသံသည် embedding (256 float) နှင့် အမည်သာ ဖြစ်၍ database မလိုဘဲ JSON ဖိုင်တစ်ခုဖြင့် လုံလောက်သည်။
/// အသံသွင်းထားသော မူရင်းအသံဖိုင်ကို မသိမ်းခြင်းမှာ ကိုယ်ရေးကိုယ်တာ အသံ ဖုန်းထဲ မကျန်စေရန် ဖြစ်သည်။
class FileVoiceLibrary implements VoiceLibrary {
  const FileVoiceLibrary({required AssetBundle bundle}) : _bundle = bundle;

  static const String _LOG_NAME = 'myanmartts.voices';
  static const String _PRESETS_KEY = 'presets';
  static const String _VOICES_KEY = 'voices';

  final AssetBundle _bundle;

  @override
  Future<List<VoiceProfile>> loadPresets() => _guard(
        operation: 'loadPresets',
        action: () async {
          final Map<String, dynamic> json =
              jsonDecode(await _bundle.loadString(MyanmarTtsConfig.VOICE_PRESETS_ASSET)) as Map<String, dynamic>;
          return <VoiceProfile>[
            for (final dynamic item in json[_PRESETS_KEY] as List<dynamic>)
              VoiceProfile.fromPresetJson(json: item as Map<String, dynamic>),
          ];
        },
      );

  @override
  Future<List<VoiceProfile>> loadCustomVoices() => _guard(
        operation: 'loadCustomVoices',
        action: () async {
          final File file = await _customVoicesFile();
          if (!await file.exists()) return const <VoiceProfile>[];
          final Map<String, dynamic> json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          return <VoiceProfile>[
            for (final dynamic item in json[_VOICES_KEY] as List<dynamic>)
              VoiceProfile.fromCustomJson(json: item as Map<String, dynamic>),
          ];
        },
      );

  @override
  Future<void> saveCustomVoices({required List<VoiceProfile> voices}) => _guard(
        operation: 'saveCustomVoices',
        action: () async {
          final File file = await _customVoicesFile();
          await file.parent.create(recursive: true);
          // ယာယီဖိုင်သို့ ရေးပြီး rename လုပ်ခြင်းဖြင့် ရေးနေစဉ် app ပိတ်သွားလျှင်လည်း ဖိုင်ဟောင်း မပျက်စေရန်။
          final File temporary = File('${file.path}.tmp');
          await temporary.writeAsString(jsonEncode(<String, dynamic>{
            _VOICES_KEY: <Map<String, dynamic>>[for (final VoiceProfile voice in voices) voice.toCustomJson()],
          }), flush: true);
          await temporary.rename(file.path);
          developer.log('action=saveCustomVoices count=${voices.length} result=ok', name: _LOG_NAME);
        },
      );

  static Future<File> _customVoicesFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/${MyanmarTtsConfig.CUSTOM_VOICES_FILE}');

  Future<T> _guard<T>({required String operation, required Future<T> Function() action}) async {
    try {
      return await action();
    } on FileSystemException catch (error, stackTrace) {
      developer.log('action=$operation result=failed', name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw VoiceLibraryException(operation: operation, platformMessage: error.message);
    } on FormatException catch (error, stackTrace) {
      developer.log('action=$operation result=corrupt', name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw VoiceLibraryException(operation: operation, platformMessage: error.message);
    } on FlutterError catch (error, stackTrace) {
      // rootBundle သည် asset မတွေ့ပါက FlutterError ပစ်သည်။
      developer.log('action=$operation result=missing_asset', name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw VoiceLibraryException(operation: operation, platformMessage: error.message);
    }
  }
}
