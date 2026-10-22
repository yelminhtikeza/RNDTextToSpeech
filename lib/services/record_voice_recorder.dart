import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../config/myanmartts_config.dart';
import 'voice_recorder.dart';

/// [VoiceRecorder] ကို `record` package ဖြင့် အကောင်အထည်ဖော်ထားခြင်း။
/// Model ၏ 44.1 kHz ဖြင့် တိုက်ရိုက်သွင်းသဖြင့် resample မလိုသလောက် ဖြစ်သည် (mic မပေးနိုင်ပါက speaker က resample လုပ်)။
/// ယာယီဖိုင်ကို ဖတ်ပြီးချင်း ဖျက်သည် — ကိုယ်ရေးကိုယ်တာ အသံ ဖုန်းထဲ မကျန်စေရန်။
class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder({required AudioRecorder recorder}) : _recorder = recorder;

  static const String _LOG_NAME = 'myanmartts.recorder';
  static const String _TEMPORARY_FILE = 'voice_recording.wav';

  final AudioRecorder _recorder;

  @override
  Future<bool> requestPermission() => _guard(operation: 'permission', action: () => _recorder.hasPermission());

  @override
  Future<void> start() => _guard(
        operation: 'start',
        action: () async {
          await _recorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: MyanmarTtsConfig.SAMPLE_RATE,
              numChannels: MyanmarTtsConfig.RECORDING_CHANNELS,
            ),
            path: await _temporaryPath(),
          );
          developer.log('action=start result=ok', name: _LOG_NAME);
        },
      );

  @override
  Future<Uint8List> stop() => _guard(
        operation: 'stop',
        action: () async {
          final String? path = await _recorder.stop();
          if (path == null) throw const VoiceRecorderException(operation: 'stop');
          final File file = File(path);
          try {
            final Uint8List bytes = await file.readAsBytes();
            developer.log('action=stop bytes=${bytes.length} result=ok', name: _LOG_NAME);
            return bytes;
          } finally {
            await _deleteQuietly(file: file);
          }
        },
      );

  @override
  Future<void> cancel() => _guard(operation: 'cancel', action: () => _recorder.cancel());

  @override
  Future<void> dispose() => _recorder.dispose();

  static Future<String> _temporaryPath() async => '${(await getTemporaryDirectory()).path}/$_TEMPORARY_FILE';

  static Future<void> _deleteQuietly({required File file}) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      // ဖျက်၍မရလည်း temp directory ဖြစ်၍ OS က နောက်မှ ရှင်းမည် — log သာ ထုတ်သည်။
      developer.log('action=deleteRecording result=failed', name: _LOG_NAME, error: error);
    }
  }

  Future<T> _guard<T>({required String operation, required Future<T> Function() action}) async {
    try {
      return await action();
    } on PlatformException catch (error, stackTrace) {
      developer.log('action=$operation result=failed code=${error.code}',
          name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw VoiceRecorderException(operation: operation, platformMessage: error.message);
    } on FileSystemException catch (error, stackTrace) {
      developer.log('action=$operation result=io_failed', name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw VoiceRecorderException(operation: operation, platformMessage: error.message);
    }
  }
}
