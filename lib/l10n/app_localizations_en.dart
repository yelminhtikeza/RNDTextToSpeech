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
  String get inputLabel => 'Burmese text';

  @override
  String get inputHint => 'Type or paste Burmese (Unicode) text';

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
  String get speechRateLabel => 'Speed';

  @override
  String get pitchLabel => 'Pitch';

  @override
  String get statusDetecting => 'Looking for an engine that speaks Burmese…';

  @override
  String get statusNoBurmeseEngine =>
      'This speech engine does not support Burmese (my-MM). Choose another engine, or install a Burmese TTS engine and check again.';

  @override
  String get errorEmptyText => 'Enter some Burmese text first.';

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
  String generatedAudioDuration(String seconds) {
    return 'Generated audio · $seconds s';
  }
}
