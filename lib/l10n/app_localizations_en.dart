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
      'No installed speech engine supports Burmese (my-MM). Install a Burmese TTS engine on this device, set it up in Android Settings › Text-to-speech output, then check again.';

  @override
  String get statusDetectionFailed =>
      'Could not read this device\'s speech engines.';

  @override
  String get errorEmptyText => 'Enter some Burmese text first.';

  @override
  String errorTextTooLong(int maxLength) {
    return 'Text is too long. The engine accepts at most $maxLength characters.';
  }

  @override
  String get errorSpeakFailed => 'The speech engine could not speak this text.';
}
