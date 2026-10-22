import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/voice_profile.dart';
import '../models/voice_state.dart';
import '../providers/voice_controller.dart';
import '../screens/record_voice_sheet.dart';
import 'app_button.dart';

/// MyanmarTTS အသံ ရွေးခြင်း — preset နှင့် အသုံးပြုသူ အသံသွင်းထားသော အသံများ၊ အသံအသစ်သွင်းခြင်း၊ ဖျက်ခြင်း။
class VoiceSection extends ConsumerWidget {
  const VoiceSection({super.key, required this.isEnabled});

  /// ဖတ်နေစဉ်/ပြန်ဖွင့်နေစဉ် အသံ မပြောင်းစေရန်။
  final bool isEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final VoiceState voiceState = ref.watch(voiceControllerProvider);
    final VoiceController controller = ref.read(voiceControllerProvider.notifier);
    final VoiceProfile? selected = voiceState.selectedVoice;

    if (voiceState.status == VoiceLibraryStatus.failed) {
      return Text(
        voiceState.platformMessage ?? l10n.errorVoiceUnavailable,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          // အသံ ထည့်/ဖျက်ပြီးနောက် ရွေးထားချက်အသစ်ကို ပြရန် widget ကို ပြန်တည်ဆောက်သည်။
          key: ValueKey<String>('${voiceState.voices.length}|${voiceState.selectedVoiceId}'),
          initialValue: voiceState.selectedVoiceId,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.voiceLabel, border: const OutlineInputBorder()),
          items: <DropdownMenuItem<String>>[
            for (final VoiceProfile voice in voiceState.voices)
              DropdownMenuItem<String>(
                value: voice.id,
                child: Text(
                  voice.isCustom ? l10n.customVoiceLabel(voice.labelEn) : _presetLabel(context: context, voice: voice),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: isEnabled && voiceState.isReady
              ? (String? voiceId) {
                  if (voiceId != null) controller.selectVoice(voiceId: voiceId);
                }
              : null,
        ),
        const SizedBox(height: AppTheme.SPACING),
        Wrap(
          spacing: AppTheme.SPACING,
          runSpacing: AppTheme.SPACING,
          children: <Widget>[
            AppButton(
              label: l10n.recordVoiceButton,
              icon: Icons.mic,
              variant: AppButtonVariant.outlined,
              onPressed: isEnabled && voiceState.isReady ? () => _openRecorder(context: context) : null,
            ),
            if (selected != null && selected.isCustom)
              AppButton(
                label: l10n.deleteVoiceButton,
                icon: Icons.delete_outline,
                variant: AppButtonVariant.outlined,
                onPressed: isEnabled ? () => _confirmDelete(context: context, controller: controller, voice: selected) : null,
              ),
          ],
        ),
      ],
    );
  }

  static String _presetLabel({required BuildContext context, required VoiceProfile voice}) =>
      Localizations.localeOf(context).languageCode == _BURMESE_LANGUAGE ? voice.labelMy : voice.labelEn;

  static const String _BURMESE_LANGUAGE = 'my';

  static Future<void> _openRecorder({required BuildContext context}) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String addedMessage = AppLocalizations.of(context).voiceAdded;
    final bool? added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => const RecordVoiceSheet(),
    );
    if (added ?? false) messenger.showSnackBar(SnackBar(content: Text(addedMessage)));
  }

  static Future<void> _confirmDelete({
    required BuildContext context,
    required VoiceController controller,
    required VoiceProfile voice,
  }) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.deleteVoiceTitle),
        content: Text(l10n.deleteVoiceMessage(voice.labelEn)),
        actions: <Widget>[
          AppButton(
            label: l10n.cancelButton,
            icon: Icons.close,
            variant: AppButtonVariant.outlined,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton(
            label: l10n.deleteVoiceButton,
            icon: Icons.delete_outline,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    final VoiceChangeResult result = await controller.deleteVoice(voiceId: voice.id);
    if (result.status == VoiceChangeStatus.failed) {
      messenger.showSnackBar(SnackBar(content: Text(result.platformMessage ?? l10n.errorVoiceSaveFailed)));
    }
  }
}
