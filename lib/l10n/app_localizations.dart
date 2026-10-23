import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_my.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('my'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Burmese Text to Speech'**
  String get appTitle;

  /// No description provided for @inputLabel.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get inputLabel;

  /// No description provided for @inputHint.
  ///
  /// In en, this message translates to:
  /// **'Type or paste the text to read aloud'**
  String get inputHint;

  /// No description provided for @sampleText.
  ///
  /// In en, this message translates to:
  /// **'မင်္ဂလာပါ။ မြန်မာစာကို အသံဖြင့် ဖတ်ပြနေပါသည်။'**
  String get sampleText;

  /// No description provided for @speakButton.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get speakButton;

  /// No description provided for @stopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopButton;

  /// No description provided for @retryDetectionButton.
  ///
  /// In en, this message translates to:
  /// **'Check engines again'**
  String get retryDetectionButton;

  /// No description provided for @engineLabel.
  ///
  /// In en, this message translates to:
  /// **'Speech engine'**
  String get engineLabel;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @engineVoiceDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get engineVoiceDefault;

  /// No description provided for @engineVoiceNumbered.
  ///
  /// In en, this message translates to:
  /// **'Voice {number}'**
  String engineVoiceNumbered(int number);

  /// No description provided for @engineVoiceOnline.
  ///
  /// In en, this message translates to:
  /// **'Voice {number} · online'**
  String engineVoiceOnline(int number);

  /// No description provided for @errorEngineVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This voice could not be used. The engine default voice is used instead.'**
  String get errorEngineVoiceUnavailable;

  /// No description provided for @errorNoLanguages.
  ///
  /// In en, this message translates to:
  /// **'This speech engine did not report any languages. Choose another engine, or check its settings and try again.'**
  String get errorNoLanguages;

  /// No description provided for @errorLanguageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This speech engine cannot speak {language}. Choose another language or engine.'**
  String errorLanguageUnavailable(String language);

  /// No description provided for @speechRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speechRateLabel;

  /// No description provided for @pitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get pitchLabel;

  /// No description provided for @statusDetecting.
  ///
  /// In en, this message translates to:
  /// **'Looking for speech engines…'**
  String get statusDetecting;

  /// No description provided for @errorEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Enter some text first.'**
  String get errorEmptyText;

  /// No description provided for @errorTextTooLong.
  ///
  /// In en, this message translates to:
  /// **'Text is too long. The engine accepts at most {maxLength} characters.'**
  String errorTextTooLong(int maxLength);

  /// No description provided for @errorSpeakFailed.
  ///
  /// In en, this message translates to:
  /// **'The speech engine could not speak this text.'**
  String get errorSpeakFailed;

  /// No description provided for @engineOnDevice.
  ///
  /// In en, this message translates to:
  /// **'MyanmarTTS (on-device)'**
  String get engineOnDevice;

  /// No description provided for @statusLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Loading the on-device Burmese voice… The first launch can take a while.'**
  String get statusLoadingModel;

  /// No description provided for @errorNoSpeakableText.
  ///
  /// In en, this message translates to:
  /// **'No Burmese Unicode text to read. Zawgyi and non-Burmese text are not supported.'**
  String get errorNoSpeakableText;

  /// No description provided for @errorModelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the on-device Burmese voice. Choose another engine or try again.'**
  String get errorModelLoadFailed;

  /// No description provided for @pitchNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Pitch is not adjustable with MyanmarTTS.'**
  String get pitchNotSupported;

  /// No description provided for @downloadButton.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadButton;

  /// No description provided for @downloadSaved.
  ///
  /// In en, this message translates to:
  /// **'Audio saved.'**
  String get downloadSaved;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the audio.'**
  String get downloadFailed;

  /// No description provided for @downloadHint.
  ///
  /// In en, this message translates to:
  /// **'Speak the text first to download its audio.'**
  String get downloadHint;

  /// No description provided for @statusPreparingAudio.
  ///
  /// In en, this message translates to:
  /// **'Preparing the audio…'**
  String get statusPreparingAudio;

  /// No description provided for @errorAudioUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This speech engine cannot provide its audio, so it cannot be replayed or downloaded.'**
  String get errorAudioUnavailable;

  /// No description provided for @flowStepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get flowStepsLabel;

  /// No description provided for @flowStepsHint.
  ///
  /// In en, this message translates to:
  /// **'More steps sound clearer but take longer to generate (time grows with the step count).'**
  String get flowStepsHint;

  /// No description provided for @cfgLabel.
  ///
  /// In en, this message translates to:
  /// **'CFG'**
  String get cfgLabel;

  /// No description provided for @cfgHint.
  ///
  /// In en, this message translates to:
  /// **'How strictly the voice follows the text. 1 can drift or mumble, about 3 is balanced, and 4–5 is sharper but can sound strained.'**
  String get cfgHint;

  /// No description provided for @playbackTime.
  ///
  /// In en, this message translates to:
  /// **'{position} / {duration}'**
  String playbackTime(String position, String duration);

  /// No description provided for @playButton.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playButton;

  /// No description provided for @pauseButton.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseButton;

  /// No description provided for @resumeButton.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeButton;

  /// No description provided for @voiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceLabel;

  /// No description provided for @customVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} (recorded)'**
  String customVoiceLabel(String name);

  /// No description provided for @recordVoiceButton.
  ///
  /// In en, this message translates to:
  /// **'Record a voice'**
  String get recordVoiceButton;

  /// No description provided for @deleteVoiceButton.
  ///
  /// In en, this message translates to:
  /// **'Delete voice'**
  String get deleteVoiceButton;

  /// No description provided for @deleteVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this voice?'**
  String get deleteVoiceTitle;

  /// No description provided for @deleteVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from this phone.'**
  String deleteVoiceMessage(String name);

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @voiceAdded.
  ///
  /// In en, this message translates to:
  /// **'Voice added.'**
  String get voiceAdded;

  /// No description provided for @errorVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voices could not be loaded.'**
  String get errorVoiceUnavailable;

  /// No description provided for @errorVoiceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the voice.'**
  String get errorVoiceSaveFailed;

  /// No description provided for @recordSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a voice'**
  String get recordSheetTitle;

  /// No description provided for @recordInstructions.
  ///
  /// In en, this message translates to:
  /// **'In a quiet place, read the sentence below clearly at a normal pace. Speak for at least 5 seconds.'**
  String get recordInstructions;

  /// No description provided for @recordPromptText.
  ///
  /// In en, this message translates to:
  /// **'မင်္ဂလာပါ။ ကျွန်ုပ်၏ အသံကို မှတ်တမ်းတင်နေပါသည်။ ယနေ့ ရာသီဥတု သာယာပြီး လူတိုင်း ကျန်းမာ ပျော်ရွှင်ကြပါစေ။'**
  String get recordPromptText;

  /// No description provided for @recordConsent.
  ///
  /// In en, this message translates to:
  /// **'Only record your own voice or a voice you have permission to use. The recording is not kept — only a voice fingerprint is saved on this phone.'**
  String get recordConsent;

  /// No description provided for @recordElapsed.
  ///
  /// In en, this message translates to:
  /// **'{elapsed} / {max} s'**
  String recordElapsed(String elapsed, String max);

  /// No description provided for @recordStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get recordStartButton;

  /// No description provided for @recordStopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get recordStopButton;

  /// No description provided for @recordAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Record again'**
  String get recordAgainButton;

  /// No description provided for @voiceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice name'**
  String get voiceNameLabel;

  /// No description provided for @voiceNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: My voice'**
  String get voiceNameHint;

  /// No description provided for @saveVoiceButton.
  ///
  /// In en, this message translates to:
  /// **'Save voice'**
  String get saveVoiceButton;

  /// No description provided for @errorVoiceNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this voice.'**
  String get errorVoiceNameEmpty;

  /// No description provided for @errorMicrophonePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is needed to record a voice.'**
  String get errorMicrophonePermission;

  /// No description provided for @errorRecordingTooShort.
  ///
  /// In en, this message translates to:
  /// **'Recording is too short. Speak for at least {seconds} seconds.'**
  String errorRecordingTooShort(int seconds);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'my'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'my':
      return AppLocalizationsMy();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
