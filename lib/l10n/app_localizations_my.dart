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
      'ဤ Engine သည် မြန်မာဘာသာ (my-MM) ကို မပံ့ပိုးပါ။ အခြား Engine ကို ရွေးပါ သို့မဟုတ် မြန်မာ TTS Engine ထည့်သွင်းပြီး ပြန်စစ်ပါ။';

  @override
  String get errorEmptyText => 'မြန်မာစာ အရင်ထည့်ပါ။';

  @override
  String errorTextTooLong(int maxLength) {
    return 'စာသား ရှည်လွန်းသည်။ Engine သည် စာလုံး $maxLength လုံးအထိသာ လက်ခံသည်။';
  }

  @override
  String get errorSpeakFailed => 'Engine သည် ဤစာသားကို ဖတ်၍ မရပါ။';

  @override
  String get engineOnDevice => 'MyanmarTTS (ဖုန်းပေါ်တွင်)';

  @override
  String get statusLoadingModel =>
      'ဖုန်းပေါ် မြန်မာအသံကို ဖွင့်နေသည်… ပထမဆုံးအကြိမ်တွင် အချိန်အနည်းငယ် ကြာနိုင်သည်။';

  @override
  String get errorNoSpeakableText =>
      'ဖတ်စရာ မြန်မာ ယူနီကုဒ်စာ မရှိပါ။ ဇော်ဂျီနှင့် မြန်မာမဟုတ်သော စာကို မဖတ်နိုင်ပါ။';

  @override
  String get errorModelLoadFailed =>
      'ဖုန်းပေါ် မြန်မာအသံကို ဖွင့်၍ မရပါ။ အခြား Engine ကို ရွေးပါ သို့မဟုတ် ပြန်ကြိုးစားပါ။';

  @override
  String get pitchNotSupported =>
      'MyanmarTTS တွင် အသံအနိမ့်အမြင့်ကို ချိန်၍ မရပါ။';

  @override
  String get downloadButton => 'ဒေါင်းလုဒ်';

  @override
  String get downloadSaved => 'အသံဖိုင် သိမ်းပြီးပါပြီ။';

  @override
  String get downloadFailed => 'အသံဖိုင်ကို သိမ်း၍ မရပါ။';

  @override
  String get downloadHint => 'အသံကို ဒေါင်းလုဒ်လုပ်ရန် စာကို အရင်ဖတ်ပါ။';

  @override
  String get flowStepsLabel => 'Step';

  @override
  String get flowStepsHint =>
      'Step များလေ အသံကြည်လေ ဖြစ်သော်လည်း ထုတ်ရန် ကြာလေ ဖြစ်သည် (အချိန်သည် step အရေအတွက်နှင့် အချိုးကျ)။';

  @override
  String get cfgLabel => 'CFG';

  @override
  String get cfgHint =>
      'အသံသည် စာကို မည်မျှ တင်းကျပ်စွာ လိုက်မည်နည်း။ 1 တွင် လွင့်/ဝါးနိုင်၊ ~3 မျှတ၊ 4–5 ပိုပြတ်သားသော်လည်း တင်းမာနိုင်။';

  @override
  String generatedAudioDuration(String seconds) {
    return 'ထုတ်ထားသော အသံ · $seconds စက္ကန့်';
  }
}
