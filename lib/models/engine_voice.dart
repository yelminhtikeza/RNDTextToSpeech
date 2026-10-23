/// Android engine တစ်ခု၏ အသံ (Android `Voice`) — engine က လူအမည်/ကျားမ မပေးသဖြင့် [name] သည် code (ဥပမာ `en-us-x-iol-local`) ဖြစ်သည်။
class EngineVoice {
  const EngineVoice({required this.name, required this.locale, required this.requiresNetwork});

  final String name;

  /// BCP 47 tag (ဥပမာ `en-US`) — ရွေးထားသော ဘာသာနှင့် တိုက်စစ်ရန်။
  final String locale;

  /// Online အသံ — internet မရှိလျှင် မထွက်နိုင်သဖြင့် UI တွင် မှတ်ပြရန်။
  final bool requiresNetwork;
}
