import 'dart:async';
import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../config/myanmartts_config.dart';
import 'audio_output.dart';

/// [AudioOutput] ကို audioplayers ဖြင့် အကောင်အထည်ဖော်ထားခြင်း။
/// WAV ကို ဖိုင်မရေးဘဲ [BytesSource] ဖြင့် memory မှ တိုက်ရိုက်ဖွင့်သည် (Android API 23+)။
class AudioplayersAudioOutput implements AudioOutput {
  AudioplayersAudioOutput({required AudioPlayer player}) : _player = player;

  static const String _LOG_NAME = 'myanmartts.audio';

  final AudioPlayer _player;
  Completer<void>? _playback;

  @override
  Stream<Duration> get positionChanges => _player.onPositionChanged;

  @override
  Future<void> playWav({required Uint8List wav, Duration startAt = Duration.zero}) async {
    final Completer<void> playback = Completer<void>();
    _playback = playback;
    final StreamSubscription<void> completion = _player.onPlayerComplete.listen((_) {
      if (!playback.isCompleted) playback.complete();
    });
    try {
      await _player.play(BytesSource(wav, mimeType: MyanmarTtsConfig.WAV_MIME_TYPE), position: startAt);
      await playback.future;
    } on PlatformException catch (error, stackTrace) {
      developer.log('action=play result=failed code=${error.code}', name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw AudioOutputException(operation: 'play', platformMessage: error.message);
    } finally {
      await completion.cancel();
    }
  }

  @override
  Future<void> pause() => _guard(operation: 'pause', action: _player.pause);

  @override
  Future<void> resume() => _guard(operation: 'resume', action: _player.resume);

  @override
  Future<void> seek({required Duration position}) => _guard(operation: 'seek', action: () => _player.seek(position));

  @override
  Future<void> stop() async {
    // ဖွင့်ခြင်းကို စောင့်နေသူကို ချက်ချင်း ပြန်လွှတ်ရန် completer ကို အရင်ပြီးစေသည်။
    final Completer<void>? playback = _playback;
    if (playback != null && !playback.isCompleted) playback.complete();
    try {
      await _player.stop();
    } on PlatformException catch (error, stackTrace) {
      // ရပ်၍မရလည်း ဖိုင်ဖွင့်ခြင်းသည် အလိုလို ပြီးဆုံးမည်ဖြစ်၍ log သာ ထုတ်သည်။
      developer.log('action=stop result=failed code=${error.code}', name: _LOG_NAME, error: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> dispose() => _player.dispose();

  /// Pause/resume/seek မအောင်မြင်ခြင်းသည် ဖွင့်ခြင်းကို မထိခိုက်သဖြင့် log ထုတ်ပြီး UI သို့ [AudioOutputException] အဖြစ် ပို့သည်။
  Future<void> _guard({required String operation, required Future<void> Function() action}) async {
    try {
      await action();
    } on PlatformException catch (error, stackTrace) {
      developer.log('action=$operation result=failed code=${error.code}',
          name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw AudioOutputException(operation: operation, platformMessage: error.message);
    }
  }
}
