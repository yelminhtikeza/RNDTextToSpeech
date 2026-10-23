enum AudioSaveStatus {
  saved,
  cancelled,
  failed,

  /// Engine က ၎င်း၏ အသံကို ဖိုင်အဖြစ် မပေးနိုင် (ADR 0005)။
  unavailable,
}

/// Download ၏ ရလဒ် — UI က snackbar ဖြင့် တစ်ကြိမ်သာ ပြရမည်ဖြစ်၍ state ထဲ မထည့်ဘဲ ပြန်ပေးသည်။
class AudioSaveResult {
  const AudioSaveResult({required this.status, this.platformMessage});

  final AudioSaveStatus status;

  /// Platform မှ မူရင်းအမှားစာ — ပြင်ဆင်ခြင်းမပြုဘဲ ပြရန်။
  final String? platformMessage;
}
