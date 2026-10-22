enum AudioSaveStatus { saved, cancelled, failed }

/// Download ၏ ရလဒ် — UI က snackbar ဖြင့် တစ်ကြိမ်သာ ပြရမည်ဖြစ်၍ state ထဲ မထည့်ဘဲ ပြန်ပေးသည်။
class AudioSaveResult {
  const AudioSaveResult({required this.status, this.platformMessage});

  final AudioSaveStatus status;

  /// Platform မှ မူရင်းအမှားစာ — ပြင်ဆင်ခြင်းမပြုဘဲ ပြရန်။
  final String? platformMessage;
}
