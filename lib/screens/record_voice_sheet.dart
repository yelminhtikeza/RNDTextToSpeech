import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../config/myanmartts_config.dart';
import '../l10n/app_localizations.dart';
import '../models/voice_recording_state.dart';
import '../providers/voice_recording_controller.dart';
import '../widgets/app_button.dart';

/// ကိုယ်ပိုင်အသံ (သို့မဟုတ် ခွင့်ပြုချက်ရထားသော အသံ) ကို ၅–၁၅ စက္ကန့် သွင်းပြီး အမည်ပေး၍ MyanmarTTS အသံအဖြစ် သိမ်းသည်။
/// သိမ်းပြီးပါက `true` ဖြင့် ပိတ်သည်။
class RecordVoiceSheet extends ConsumerStatefulWidget {
  const RecordVoiceSheet({super.key});

  @override
  ConsumerState<RecordVoiceSheet> createState() => _RecordVoiceSheetState();
}

/// StatefulWidget သုံးခြင်းမှာ TextEditingController ၏ lifecycle အတွက်သာ — recording state သည် Riverpod တွင်။
class _RecordVoiceSheetState extends ConsumerState<RecordVoiceSheet> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final VoiceRecordingState recording = ref.watch(voiceRecordingControllerProvider);
    final VoiceRecordingController controller = ref.read(voiceRecordingControllerProvider.notifier);

    return Padding(
      // Keyboard ပေါ်လာလျှင် အမည် field ကို မဖုံးစေရန်။
      padding: EdgeInsets.only(
        left: AppTheme.SPACING,
        right: AppTheme.SPACING,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.SPACING,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.recordSheetTitle, style: text.titleLarge),
            const SizedBox(height: AppTheme.SPACING),
            Text(l10n.recordInstructions),
            const SizedBox(height: AppTheme.SPACING),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.SPACING),
                child: Text(l10n.recordPromptText, style: text.titleMedium),
              ),
            ),
            const SizedBox(height: AppTheme.SPACING),
            Text(l10n.recordConsent, style: text.bodySmall),
            const SizedBox(height: AppTheme.SPACING),
            Text(
              l10n.recordElapsed(
                _seconds(duration: recording.elapsed),
                _seconds(duration: MyanmarTtsConfig.MAX_RECORDING),
              ),
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            const SizedBox(height: AppTheme.SPACING),
            if (!recording.hasRecording)
              AppButton(
                label: recording.isRecording ? l10n.recordStopButton : l10n.recordStartButton,
                icon: recording.isRecording ? Icons.stop : Icons.mic,
                onPressed: recording.isRecording ? controller.stopRecording : controller.startRecording,
              )
            else ...<Widget>[
              TextField(
                controller: _nameController,
                enabled: !recording.isSaving,
                decoration: InputDecoration(
                  labelText: l10n.voiceNameLabel,
                  hintText: l10n.voiceNameHint,
                  border: const OutlineInputBorder(),
                  errorText: recording.error == RecordingError.nameEmpty ? l10n.errorVoiceNameEmpty : null,
                ),
              ),
              const SizedBox(height: AppTheme.SPACING),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: l10n.recordAgainButton,
                      icon: Icons.refresh,
                      variant: AppButtonVariant.outlined,
                      onPressed: recording.isSaving ? null : controller.discardRecording,
                    ),
                  ),
                  const SizedBox(width: AppTheme.SPACING),
                  Expanded(
                    child: AppButton(
                      label: l10n.saveVoiceButton,
                      icon: Icons.check,
                      isLoading: recording.isSaving,
                      onPressed: () => _save(controller: controller),
                    ),
                  ),
                ],
              ),
            ],
            if (_errorText(l10n: l10n, recording: recording) case final String message) ...<Widget>[
              const SizedBox(height: AppTheme.SPACING),
              Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save({required VoiceRecordingController controller}) async {
    final NavigatorState navigator = Navigator.of(context);
    if (await controller.saveVoice(name: _nameController.text)) navigator.pop(true);
  }

  /// အမည်အမှားကို field အောက်တွင် ပြပြီးဖြစ်၍ ဤနေရာတွင် မပြပါ။
  static String? _errorText({required AppLocalizations l10n, required VoiceRecordingState recording}) =>
      switch (recording.error) {
        null || RecordingError.nameEmpty => null,
        RecordingError.permissionDenied => l10n.errorMicrophonePermission,
        RecordingError.tooShort => l10n.errorRecordingTooShort(MyanmarTtsConfig.MIN_RECORDING.inSeconds),
        RecordingError.failed => recording.platformMessage ?? l10n.errorVoiceSaveFailed,
      };

  static String _seconds({required Duration duration}) =>
      (duration.inMilliseconds / Duration.millisecondsPerSecond).toStringAsFixed(1);
}
