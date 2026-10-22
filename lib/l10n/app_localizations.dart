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
  /// **'Burmese text'**
  String get inputLabel;

  /// No description provided for @inputHint.
  ///
  /// In en, this message translates to:
  /// **'Type or paste Burmese (Unicode) text'**
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
  /// **'Looking for an engine that speaks Burmese…'**
  String get statusDetecting;

  /// No description provided for @statusNoBurmeseEngine.
  ///
  /// In en, this message translates to:
  /// **'This speech engine does not support Burmese (my-MM). Choose another engine, or install a Burmese TTS engine and check again.'**
  String get statusNoBurmeseEngine;

  /// No description provided for @errorEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Enter some Burmese text first.'**
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

  /// No description provided for @generatedAudioDuration.
  ///
  /// In en, this message translates to:
  /// **'Generated audio · {seconds} s'**
  String generatedAudioDuration(String seconds);

  /// No description provided for @playButton.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playButton;
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
