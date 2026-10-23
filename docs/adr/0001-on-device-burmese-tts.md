# ADR 0001 — စက်ပေါ်ရှိ TTS engine ဖြင့် မြန်မာအသံ ထုတ်ခြင်း

- **Status:** Accepted — ပုံသေ engine ကို ADR 0002 က ပြင်ဆင်ထားသည်၊ Decision 2 (engine စစ်ထုတ်ခြင်း) ကို ADR 0004 က အစားထိုးထားသည်
- **Date:** 2026-10-22

## Context

Android စက်ပေါ်တွင် မြန်မာစာကို အသံထွက်ဖတ်ရန် လိုအပ်သည်။ `flutter_tts` သည် ကိုယ်ပိုင်အသံ မပါဘဲ
စက်တွင် ထည့်ထားသော Android TTS engine ကိုသာ သုံးသည်။ Default engine အများစုတွင် မြန်မာအသံ မပါနိုင်ပါ။

## Decision

1. `flutter_tts` ဖြင့် စက်ပေါ်ရှိ engine ကို သုံးမည်။
2. App စဖွင့်ချိန်တွင် engine အားလုံးကို တစ်ခုချင်း `setEngine` → `isLanguageAvailable("my-MM")` ဖြင့် စစ်ပြီး
   ပံ့ပိုးသော engine များကိုသာ ရွေးခွင့်ပေးမည်။
3. Engine ကို `TtsService` interface နောက်တွင် ထားပြီး business logic ကို Riverpod `BurmeseSpeechController` တစ်ခုတည်းတွင် ထားမည်။
4. `awaitSpeakCompletion(true)` ဖြင့် `speak()` ၏ Future ကို ဖတ်ပြီးချိန်အထိ စောင့်မည်။

## Rejected alternatives

- **Cloud TTS API (ဥပမာ Google Cloud / Azure မြန်မာအသံ):** အသံအရည်အသွေး ပိုကောင်းနိုင်သော်လည်း
  API key စီမံခြင်း၊ ကုန်ကျစရိတ်၊ internet လိုအပ်ခြင်းနှင့် စာသားကို ပြင်ပသို့ ပို့ရခြင်း ပါဝင်သဖြင့် R&D ပထမအဆင့်တွင် ပယ်ထားသည်။
  စက်ပေါ်ရှိ engine ဖြင့် မလုံလောက်ကြောင်း စမ်းသပ်တွေ့ရှိပါက ပြန်စဉ်းစားမည်။
- **Default engine ကိုသာ သုံးခြင်း:** ရိုးရှင်းသော်လည်း မြန်မာ engine ကို ထည့်ထားသည့်တိုင် default မဟုတ်ပါက အသံမထွက်ပါ။
- **Completion handler callback ဖြင့် state ပြောင်းခြင်း:** Global callback ကို controller နှင့် ချိတ်ရပြီး
  test ခက်သဖြင့် `awaitSpeakCompletion` ကို ရွေးသည်။

## Consequences

- မြန်မာ engine ထည့်မထားသော စက်တွင် app က အသံမထွက်နိုင်ဘဲ ထည့်သွင်းရန် လမ်းညွှန်ချက်ကိုသာ ပြမည်။
- Engine ရှာဖွေချိန်သည် ထည့်ထားသော engine အရေအတွက်နှင့် အချိုးကျ ကြာမည်။
- `flutter_tts` သည် Linux ကို မပံ့ပိုးပါ။ ဤ feature သည် Android ကိုသာ ပစ်မှတ်ထားသည်။
