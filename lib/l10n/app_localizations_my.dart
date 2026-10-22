// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Burmese (`my`).
class AppLocalizationsMy extends AppLocalizations {
  AppLocalizationsMy([String locale = 'my']) : super(locale);

  @override
  String get appTitle => 'မြန်မာ စာမှ အသံ';

  @override
  String get inputLabel => 'မြန်မာစာ';

  @override
  String get inputHint =>
      'မြန်မာစာ (ယူနီကုဒ်) ကို ရိုက်ထည့်ပါ သို့မဟုတ် ကူးထည့်ပါ';

  @override
  String get sampleText => 'မင်္ဂလာပါ။ မြန်မာစာကို အသံဖြင့် ဖတ်ပြနေပါသည်။';

  @override
  String get speakButton => 'ဖတ်ပါ';

  @override
  String get stopButton => 'ရပ်ပါ';

  @override
  String get retryDetectionButton => 'Engine များကို ပြန်စစ်ပါ';

  @override
  String get engineLabel => 'အသံ Engine';

  @override
  String get speechRateLabel => 'အမြန်နှုန်း';

  @override
  String get pitchLabel => 'အသံအနိမ့်အမြင့်';

  @override
  String get statusDetecting => 'မြန်မာစကား ပြောနိုင်သော Engine ကို ရှာနေသည်…';

  @override
  String get statusNoBurmeseEngine =>
      'ထည့်သွင်းထားသော Engine များထဲတွင် မြန်မာဘာသာ (my-MM) ကို ပံ့ပိုးသည့် Engine မရှိပါ။ မြန်မာ TTS Engine တစ်ခုကို ထည့်သွင်းပြီး Android Settings › Text-to-speech output တွင် သတ်မှတ်ကာ ပြန်စစ်ပါ။';

  @override
  String get statusDetectionFailed => 'ဤစက်၏ အသံ Engine များကို ဖတ်၍ မရပါ။';

  @override
  String get errorEmptyText => 'မြန်မာစာ အရင်ထည့်ပါ။';

  @override
  String errorTextTooLong(int maxLength) {
    return 'စာသား ရှည်လွန်းသည်။ Engine သည် စာလုံး $maxLength လုံးအထိသာ လက်ခံသည်။';
  }

  @override
  String get errorSpeakFailed => 'Engine သည် ဤစာသားကို ဖတ်၍ မရပါ။';
}
