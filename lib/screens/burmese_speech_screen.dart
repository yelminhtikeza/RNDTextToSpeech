import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../config/tts_config.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_save_result.dart';
import '../models/burmese_speech_state.dart';
import '../providers/burmese_speech_controller.dart';
import '../widgets/app_button.dart';

class BurmeseSpeechScreen extends ConsumerStatefulWidget {
  const BurmeseSpeechScreen({super.key});

  @override
  ConsumerState<BurmeseSpeechScreen> createState() => _BurmeseSpeechScreenState();
}

/// StatefulWidget သုံးခြင်းမှာ TextEditingController ၏ lifecycle (dispose) အတွက်သာ ဖြစ်ပြီး
/// app state အားလုံးကို Riverpod controller တွင်သာ ထားသည်။
class _BurmeseSpeechScreenState extends ConsumerState<BurmeseSpeechScreen> {
  TextEditingController? _textController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sample စာသားသည် l10n မှ လာသဖြင့် context အသင့်ဖြစ်မှသာ ဖန်တီးနိုင်သည်။
    _textController ??=
        TextEditingController(text: AppLocalizations.of(context).sampleText);
  }

  @override
  void dispose() {
    _textController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BurmeseSpeechState speechState = ref.watch(burmeseSpeechControllerProvider);
    final BurmeseSpeechController controller =
        ref.read(burmeseSpeechControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.SPACING),
          children: <Widget>[
            _EngineStatusSection(speechState: speechState, controller: controller),
            const SizedBox(height: AppTheme.SPACING),
            TextField(
              controller: _textController,
              minLines: 4,
              maxLines: 10,
              maxLength: speechState.maxInputLength,
              onChanged: (_) => controller.discardGeneratedAudio(),
              decoration: InputDecoration(
                labelText: l10n.inputLabel,
                hintText: l10n.inputHint,
                border: const OutlineInputBorder(),
                errorText: _inputErrorText(l10n: l10n, speechState: speechState),
              ),
            ),
            _LabeledSlider(
              label: l10n.speechRateLabel,
              value: speechState.speechRate,
              min: TtsConfig.SPEECH_RATE_MIN,
              max: TtsConfig.SPEECH_RATE_MAX,
              onChanged: (double rate) => controller.updateSpeechRate(rate: rate),
            ),
            _LabeledSlider(
              label: l10n.pitchLabel,
              value: speechState.pitch,
              min: TtsConfig.PITCH_MIN,
              max: TtsConfig.PITCH_MAX,
              // MyanmarTTS model တွင် pitch ထိန်းချုပ်မှု မပါသဖြင့် slider ကို ပိတ်ပြီး အကြောင်းရင်း ပြသည်။
              onChanged: speechState.supportsPitch ? (double pitch) => controller.updatePitch(pitch: pitch) : null,
            ),
            if (!speechState.supportsPitch)
              Text(l10n.pitchNotSupported, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppTheme.SPACING),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: l10n.speakButton,
                    icon: Icons.record_voice_over,
                    isLoading: speechState.isSpeaking,
                    onPressed: speechState.canSpeak
                        ? () => controller.speak(text: _textController?.text ?? '')
                        : null,
                  ),
                ),
                const SizedBox(width: AppTheme.SPACING),
                Expanded(
                  child: AppButton(
                    label: l10n.stopButton,
                    icon: Icons.stop,
                    variant: AppButtonVariant.outlined,
                    onPressed: speechState.isSpeaking ? controller.stop : null,
                  ),
                ),
              ],
            ),
            if (speechState.supportsDownload) ...<Widget>[
              const SizedBox(height: AppTheme.SPACING),
              AppButton(
                label: l10n.downloadButton,
                icon: Icons.download,
                variant: AppButtonVariant.outlined,
                isLoading: speechState.isSavingAudio,
                onPressed: speechState.canDownload ? () => _downloadAudio(controller: controller, l10n: l10n) : null,
              ),
              if (!speechState.hasDownloadableAudio)
                Text(l10n.downloadHint, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAudio({
    required BurmeseSpeechController controller,
    required AppLocalizations l10n,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AudioSaveResult result = await controller.downloadAudio();
    final String? message = switch (result.status) {
      AudioSaveStatus.saved => l10n.downloadSaved,
      AudioSaveStatus.failed => result.platformMessage ?? l10n.downloadFailed,
      // အသုံးပြုသူကိုယ်တိုင် dialog ပိတ်ခြင်းဖြစ်၍ ဘာမျှ မပြပါ။
      AudioSaveStatus.cancelled => null,
    };
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Validation/ဖတ်မှု အမှားကို TextField အောက်တွင် ပြသည်။ Engine ၏ မူရင်းစာ ရှိပါက ထိုစာကိုသာ ပြသည်။
  String? _inputErrorText({
    required AppLocalizations l10n,
    required BurmeseSpeechState speechState,
  }) {
    return switch (speechState.error) {
      null => null,
      SpeechError.emptyText => l10n.errorEmptyText,
      SpeechError.textTooLong => l10n.errorTextTooLong(speechState.maxInputLength),
      SpeechError.noSpeakableText => l10n.errorNoSpeakableText,
      SpeechError.speakFailed => speechState.platformMessage ?? l10n.errorSpeakFailed,
      // Engine အမှားများကို engine အပိုင်းတွင် ပြပြီးဖြစ်သည်။
      SpeechError.modelLoadFailed || SpeechError.languageUnavailable => null,
    };
  }
}

class _EngineStatusSection extends StatelessWidget {
  const _EngineStatusSection({required this.speechState, required this.controller});

  final BurmeseSpeechState speechState;
  final BurmeseSpeechController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (speechState.status == SpeechStatus.detecting) {
      return _ProgressMessage(message: l10n.statusDetecting);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          // Engine စာရင်း ပြန်ရှာသည့်အခါ ရွေးထားချက်အသစ်ကို ပြရန် widget ကို ပြန်တည်ဆောက်သည်။
          key: ValueKey<String>('${speechState.engines.join()}|${speechState.selectedEngine}'),
          initialValue: speechState.selectedEngine,
          decoration: InputDecoration(
            labelText: l10n.engineLabel,
            border: const OutlineInputBorder(),
          ),
          items: speechState.engines
              .map((String engine) => DropdownMenuItem<String>(
                    value: engine,
                    child: Text(engine == TtsConfig.ON_DEVICE_ENGINE_ID ? l10n.engineOnDevice : engine),
                  ))
              .toList(),
          onChanged: speechState.canChooseEngine
              ? (String? engine) {
                  if (engine != null) controller.selectEngine(engineName: engine);
                }
              : null,
        ),
        if (speechState.status == SpeechStatus.loadingModel) ...<Widget>[
          const SizedBox(height: AppTheme.SPACING),
          _ProgressMessage(message: l10n.statusLoadingModel),
        ],
        if (speechState.status == SpeechStatus.engineUnavailable) ...<Widget>[
          const SizedBox(height: AppTheme.SPACING),
          _StatusMessage(
            message: speechState.platformMessage ?? _engineErrorText(l10n: l10n, error: speechState.error),
            onRetry: controller.detectBurmeseEngines,
          ),
        ],
      ],
    );
  }

  String _engineErrorText({required AppLocalizations l10n, required SpeechError? error}) {
    return error == SpeechError.modelLoadFailed ? l10n.errorModelLoadFailed : l10n.statusNoBurmeseEngine;
  }
}

class _ProgressMessage extends StatelessWidget {
  const _ProgressMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox.square(
          dimension: AppTheme.LOADER_SIZE,
          child: CircularProgressIndicator(strokeWidth: AppTheme.LOADER_STROKE),
        ),
        const SizedBox(width: AppTheme.SPACING),
        Expanded(child: Text(message)),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.SPACING),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message, style: TextStyle(color: colors.onErrorContainer)),
            const SizedBox(height: AppTheme.SPACING),
            AppButton(
              label: AppLocalizations.of(context).retryDetectionButton,
              icon: Icons.refresh,
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  /// null ဖြစ်လျှင် disabled။
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Expanded(
          flex: 3,
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: TtsConfig.SLIDER_DIVISIONS,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
