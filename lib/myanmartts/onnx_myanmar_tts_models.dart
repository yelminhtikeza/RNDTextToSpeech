import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../config/myanmartts_config.dart';
import 'myanmar_tts_models.dart';

/// [MyanmarTtsModels] ကို flutter_onnxruntime ဖြင့် အကောင်အထည်ဖော်ထားခြင်း။
///
/// Estimator graph ထဲတွင် Euler step (`x + dt·v`) ပါဝင်သဖြင့် step loop တစ်လျှောက် `x` နှင့် prenet output
/// သည် native ဘက်တွင်သာ ရှိနေပြီး platform channel မှတဆင့် ပြန်မကူးရပါ — step 16 ခုတွင် MB ဆယ်ဂဏန်းခန့် သက်သာသည်။
class OnnxMyanmarTtsModels implements MyanmarTtsModels {
  OnnxMyanmarTtsModels({required OnnxRuntime onnxRuntime}) : _onnxRuntime = onnxRuntime;

  static const String _LOG_NAME = 'myanmartts.onnx';

  final OnnxRuntime _onnxRuntime;
  OrtSession? _encoder;
  OrtSession? _prenet;
  OrtSession? _estimator;
  OrtSession? _vocoder;

  @override
  Future<void> load() => _guard(
        operation: 'load',
        action: () async {
          final OrtSessionOptions options =
              OrtSessionOptions(intraOpNumThreads: MyanmarTtsConfig.INTRA_OP_THREADS);
          final Stopwatch stopwatch = Stopwatch()..start();
          // Asset တစ်ခုချင်း အစဉ်လိုက် load လုပ်ခြင်းမှာ 57 MB vocoder အပါအဝင် byte များ
          // တပြိုင်နက် memory ထဲ မရောက်စေရန် ဖြစ်သည်။
          _encoder = await _createSession(asset: MyanmarTtsConfig.ENCODER_ASSET, options: options);
          _prenet = await _createSession(asset: MyanmarTtsConfig.PRENET_ASSET, options: options);
          _estimator = await _createSession(asset: MyanmarTtsConfig.ESTIMATOR_ASSET, options: options);
          _vocoder = await _createSession(asset: MyanmarTtsConfig.VOCODER_ASSET, options: options);
          developer.log('action=load result=ok elapsed_ms=${stopwatch.elapsedMilliseconds}', name: _LOG_NAME);
        },
      );

  @override
  Future<EncoderOutput> encode({required Int64List tokens}) => _guard(
        operation: 'encode',
        action: () async {
          final OrtValue input = await OrtValue.fromList(tokens, <int>[1, tokens.length]);
          final Map<String, OrtValue> outputs = await _requireSession(_encoder).run(<String, OrtValue>{'tokens': input});
          try {
            return EncoderOutput(
              features: await _readFloats(value: outputs['mu_x']),
              logDurations: await _readFloats(value: outputs['logw']),
            );
          } finally {
            await _disposeAll(values: <OrtValue?>[input, ...outputs.values]);
          }
        },
      );

  @override
  Future<StftSpectrum> generateSpectrum({
    required Float32List alignedFeatures,
    required int frames,
    required Float32List noise,
    required bool Function() isCancelled,
  }) =>
      _guard(
        operation: 'generateSpectrum',
        action: () async {
          final List<int> melShape = <int>[1, MyanmarTtsConfig.MEL_CHANNELS, frames];
          final List<OrtValue> owned = <OrtValue>[];
          try {
            final OrtValue features = await OrtValue.fromList(alignedFeatures, melShape);
            owned.add(features);
            final Map<String, OrtValue> prenetOutputs =
                await _requireSession(_prenet).run(<String, OrtValue>{'mu_y': features});
            owned.addAll(prenetOutputs.values);
            final OrtValue conditioning = prenetOutputs['mu_proj']!;

            const double stepSize = 1 / MyanmarTtsConfig.FLOW_STEPS;
            final OrtValue dt = await OrtValue.fromList(Float32List.fromList(<double>[stepSize]), <int>[1]);
            final OrtValue cfg =
                await OrtValue.fromList(Float32List.fromList(<double>[MyanmarTtsConfig.CFG_STRENGTH]), <int>[1]);
            owned.addAll(<OrtValue>[dt, cfg]);

            OrtValue x = await OrtValue.fromList(noise, melShape);
            owned.add(x);
            for (int step = 0; step < MyanmarTtsConfig.FLOW_STEPS; step++) {
              if (isCancelled()) throw const SynthesisCancelledException();
              final OrtValue t = await OrtValue.fromList(Float32List.fromList(<double>[step * stepSize]), <int>[1]);
              final Map<String, OrtValue> stepOutputs = await _requireSession(_estimator)
                  .run(<String, OrtValue>{'x': x, 'mu_proj': conditioning, 't': t, 'dt': dt, 'cfg': cfg});
              owned.remove(x);
              await _disposeAll(values: <OrtValue>[x, t]);
              x = stepOutputs['x_next']!;
              owned.add(x);
            }

            if (isCancelled()) throw const SynthesisCancelledException();
            final Map<String, OrtValue> vocoderOutputs =
                await _requireSession(_vocoder).run(<String, OrtValue>{'mel': x});
            owned.addAll(vocoderOutputs.values);
            return StftSpectrum(
              real: await _readFloats(value: vocoderOutputs['real']),
              imag: await _readFloats(value: vocoderOutputs['imag']),
              frames: frames,
            );
          } finally {
            // OrtValue များသည် native memory ဖြစ်၍ GC မှ မရှင်းပေးပါ — အောင်မြင်/မအောင်မြင် မရွေး ရှင်းရမည်။
            await _disposeAll(values: owned);
          }
        },
      );

  @override
  Future<void> dispose() async {
    for (final OrtSession? session in <OrtSession?>[_encoder, _prenet, _estimator, _vocoder]) {
      await session?.close();
    }
    _encoder = _prenet = _estimator = _vocoder = null;
  }

  Future<OrtSession> _createSession({required String asset, required OrtSessionOptions options}) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final OrtSession session = await _onnxRuntime.createSessionFromAsset(asset, options: options);
    developer.log('action=createSession asset=$asset elapsed_ms=${stopwatch.elapsedMilliseconds}', name: _LOG_NAME);
    return session;
  }

  OrtSession _requireSession(OrtSession? session) {
    if (session == null) {
      throw const MyanmarTtsException(operation: 'run_before_load');
    }
    return session;
  }

  static Future<Float32List> _readFloats({required OrtValue? value}) async {
    if (value == null) {
      throw const MyanmarTtsException(operation: 'missing_output');
    }
    final List<dynamic> values = await value.asFlattenedList();
    return Float32List.fromList(values.cast<num>().map((num v) => v.toDouble()).toList());
  }

  static Future<void> _disposeAll({required Iterable<OrtValue?> values}) async {
    for (final OrtValue? value in values) {
      await value?.dispose();
    }
  }

  /// Plugin အမှားအားလုံးကို log ထုတ်ပြီး [MyanmarTtsException] အဖြစ် တစ်နေရာတည်းတွင် ပြောင်းသည်။
  Future<T> _guard<T>({required String operation, required Future<T> Function() action}) async {
    try {
      return await action();
    } on PlatformException catch (error, stackTrace) {
      developer.log('action=$operation result=failed code=${error.code}',
          name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw MyanmarTtsException(operation: operation, platformMessage: error.message);
    } on MissingPluginException catch (error, stackTrace) {
      developer.log('action=$operation result=unsupported_platform', name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw MyanmarTtsException(operation: operation, platformMessage: error.message);
    } on ArgumentError catch (error, stackTrace) {
      developer.log('action=$operation result=invalid_tensor', name: _LOG_NAME, error: error, stackTrace: stackTrace);
      throw MyanmarTtsException(operation: operation, platformMessage: error.message?.toString());
    }
  }
}
