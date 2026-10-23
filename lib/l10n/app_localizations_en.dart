// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Burmese Text to Speech';

  @override
  String get inputLabel => 'Text';

  @override
  String get inputHint => 'Type or paste the text to read aloud';

  @override
  String get sampleText => 'မင်္ဂလာပါ။ မြန်မာစာကို အသံဖြင့် ဖတ်ပြနေပါသည်။';

  @override
  String get speakButton => 'Speak';

  @override
  String get stopButton => 'Stop';

  @override
  String get retryDetectionButton => 'Check engines again';

  @override
  String get engineLabel => 'Speech engine';

  @override
  String get languageLabel => 'Language';

  @override
  String get errorNoLanguages =>
      'This speech engine did not report any languages. Choose another engine, or check its settings and try again.';

  @override
  String errorLanguageUnavailable(String language) {
    return 'This speech engine cannot speak $language. Choose another language or engine.';
  }

  @override
  String get speechRateLabel => 'Speed';

  @override
  String get pitchLabel => 'Pitch';

  @override
  String get statusDetecting => 'Looking for speech engines…';

  @override
  String get errorEmptyText => 'Enter some text first.';

  @override
  String errorTextTooLong(int maxLength) {
    return 'Text is too long. The engine accepts at most $maxLength characters.';
  }

  @override
  String get errorSpeakFailed => 'The speech engine could not speak this text.';

  @override
  String get engineOnDevice => 'MyanmarTTS (on-device)';

  @override
  String get statusLoadingModel =>
      'Loading the on-device Burmese voice… The first launch can take a while.';

  @override
  String get errorNoSpeakableText =>
      'No Burmese Unicode text to read. Zawgyi and non-Burmese text are not supported.';

  @override
  String get errorModelLoadFailed =>
      'Could not load the on-device Burmese voice. Choose another engine or try again.';

  @override
  String get pitchNotSupported => 'Pitch is not adjustable with MyanmarTTS.';

  @override
  String get downloadButton => 'Download';

  @override
  String get downloadSaved => 'Audio saved.';

  @override
  String get downloadFailed => 'Could not save the audio.';

  @override
  String get downloadHint => 'Speak the text first to download its audio.';

  @override
  String get statusPreparingAudio => 'Preparing the audio…';

  @override
  String get errorAudioUnavailable =>
      'This speech engine cannot provide its audio, so it cannot be replayed or downloaded.';

  @override
  String get flowStepsLabel => 'Steps';

  @override
  String get flowStepsHint =>
      'More steps sound clearer but take longer to generate (time grows with the step count).';

  @override
  String get cfgLabel => 'CFG';

  @override
  String get cfgHint =>
      'How strictly the voice follows the text. 1 can drift or mumble, about 3 is balanced, and 4–5 is sharper but can sound strained.';

  @override
  String playbackTime(String position, String duration) {
    return '$position / $duration';
  }

  @override
  String get playButton => 'Play';

  @override
  String get pauseButton => 'Pause';

  @override
  String get resumeButton => 'Resume';

  @override
  String get voiceLabel => 'Voice';

  @override
  String customVoiceLabel(String name) {
    return '$name (recorded)';
  }

  @override
  String get recordVoiceButton => 'Record a voice';

  @override
  String get deleteVoiceButton => 'Delete voice';

  @override
  String get deleteVoiceTitle => 'Delete this voice?';

  @override
  String deleteVoiceMessage(String name) {
    return '\"$name\" will be removed from this phone.';
  }

  @override
  String get cancelButton => 'Cancel';

  @override
  String get voiceAdded => 'Voice added.';

  @override
  String get errorVoiceUnavailable => 'Voices could not be loaded.';

  @override
  String get errorVoiceSaveFailed => 'Could not save the voice.';

  @override
  String get recordSheetTitle => 'Record a voice';

  @override
  String get recordInstructions =>
      'In a quiet place, read the sentence below clearly at a normal pace. Speak for at least 5 seconds.';

  @override
  String get recordPromptText =>
      'မင်္ဂလာပါ။ ကျွန်ုပ်၏ အသံကို မှတ်တမ်းတင်နေပါသည်။ ယနေ့ ရာသီဥတု သာယာပြီး လူတိုင်း ကျန်းမာ ပျော်ရွှင်ကြပါစေ။';

  @override
  String get recordConsent =>
      'Only record your own voice or a voice you have permission to use. The recording is not kept — only a voice fingerprint is saved on this phone.';

  @override
  String recordElapsed(String elapsed, String max) {
    return '$elapsed / $max s';
  }

  @override
  String get recordStartButton => 'Start recording';

  @override
  String get recordStopButton => 'Stop';

  @override
  String get recordAgainButton => 'Record again';

  @override
  String get voiceNameLabel => 'Voice name';

  @override
  String get voiceNameHint => 'For example: My voice';

  @override
  String get saveVoiceButton => 'Save voice';

  @override
  String get errorVoiceNameEmpty => 'Enter a name for this voice.';

  @override
  String get errorMicrophonePermission =>
      'Microphone permission is needed to record a voice.';

  @override
  String errorRecordingTooShort(int seconds) {
    return 'Recording is too short. Speak for at least $seconds seconds.';
  }
}
