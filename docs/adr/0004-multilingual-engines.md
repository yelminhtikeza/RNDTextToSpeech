# ADR 0004 — Engine အားလုံးကို ပြပြီး ဘာသာစကား ရွေးခွင့်ပေးခြင်း

- **Status:** Accepted
- **Date:** 2026-10-23
- **ADR 0001 ကို ပြင်ဆင်သည်:** Decision 2 (`my-MM` ပံ့ပိုးသော engine ကိုသာ ပြခြင်း) ကို အစားထိုးသည်။

## Context

ADR 0001 အရ app စဖွင့်ချိန်တွင် Android engine တစ်ခုချင်းသို့ `setEngine` ပြောင်းပြီး `my-MM` ပံ့ပိုးသော engine ကိုသာ
ပြခဲ့သည်။ Product owner က engine အားလုံးကို မစစ်ထုတ်ဘဲ ပြရန်၊ engine တစ်ခုချင်း၏ ဘာသာစကားကို အသုံးပြုသူ ရွေးနိုင်ရန်
(app ကို ဘာသာစုံ ဖြစ်စေရန်) ဆုံးဖြတ်ခဲ့သည် (2026-10-23)။

## Decision

1. Engine စာရင်း = ဖုန်းပေါ် MyanmarTTS (ပုံသေ၊ ပထမ) + `getEngines` ပြန်ပေးသော Android engine **အားလုံး**။
2. Android engine ရွေးမှသာ `setEngine` → `getLanguages` (Android `TextToSpeech.getAvailableLanguages()`) ဖြင့် ဘာသာစာရင်း ယူပြီး
   အက္ခရာစဉ် စီကာ "ဘာသာစကား" dropdown တွင် ပြသည်။
3. ပုံသေ ဘာသာ — `my-MM`၊ မရှိပါက language subtag `my` ပါသော tag၊ ထိုလည်း မရှိပါက အက္ခရာစဉ် ပထမ။
   App ၏ အဓိက အသုံးပြုသူ မြန်မာ ဖြစ်၍ မြန်မာကို ဦးစားပေးသည်။
4. MyanmarTTS ၏ ဘာသာစာရင်းသည် `my-MM` တစ်ခုတည်း (model ကို မြန်မာဖြင့်သာ train ထား) — dropdown ကို ပြသော်လည်း ပိတ်ထားသည်။
5. ဘာသာကို BCP 47 tag (ဥပမာ `en-US`) အတိုင်း ပြသည်။

## Rejected alternatives

- **App စဖွင့်ချိန်တွင် engine တစ်ခုချင်း၏ ဘာသာကို ကြိုစစ်ခြင်း (ယခင်နည်း):** engine တစ်ခုစီ initialize လုပ်ရ၍ engine များလေ
  စဖွင့်ချိန် ကြာလေ ဖြစ်ပြီး စစ်ထုတ်ရန် မလိုတော့သဖြင့် အလကား ဖြစ်သည်။
- **ဘာသာအမည် (ဥပမာ "English (United States)") ပြခြင်း:** Dart/Flutter တွင် locale display name built-in မရှိ။
  Package အသစ် (dependency၊ ISO 8.4) သို့မဟုတ် Android native code (`Locale.getDisplayName`) လိုသဖြင့် ယခုအဆင့်တွင် မလုပ်။
  ⚠️ Tag ဖြင့် နားမလည်နိုင်ကြောင်း အသုံးပြုသူ တုံ့ပြန်ချက် ရပါက ပြန်စဉ်းစားရန်။
- **Engine ၏ voice (`getVoices`) အထိ ရွေးခွင့်ပေးခြင်း:** မတောင်းဆိုရသေး၍ scope ပြင်ပ။

## Consequences

- Engine တစ်ခု၏ ဘာသာစာရင်းတွင် ပါသော်လည်း voice data မထည့်ရသေးပါက `setLanguage` မအောင်မြင် — "ဤဘာသာကို မဖတ်နိုင်" ဟု ပြပြီး
  အခြား ဘာသာ/engine ရွေးခွင့် ဆက်ပေးသည်။
- `getAvailableLanguages` ကို အကောင်အထည် မဖော်ထားသော engine (Android 6 မတိုင်မီ သို့မဟုတ် engine အဟောင်း) သည် ဘာသာ မရှိဟု ပြမည်။
- MyanmarTTS အတွက်သာ မြန်မာ Unicode စစ်ဆေးချက် (`noSpeakableText`) ကျန်သည်။ Android engine များတွင် ရွေးထားသော ဘာသာနှင့်
  စာ မကိုက်ညီမှုကို app က မစစ် (engine က ဆုံးဖြတ်)။
- ဘာသာ ရွေးချယ်မှုကို မသိမ်းဆည်း — app ပြန်ဖွင့်လျှင် ပုံသေ ဘာသာ ပြန်ဖြစ်သည်။
- Class/file အမည်များ (`BurmeseSpeechController` စသည်) ကို ဤ change တွင် မပြောင်းပါ (one responsibility per diff)။

## Rollback plan

ဤ commit ကို revert ပြုပါ။ Data/schema ပြောင်းလဲမှု မရှိ၍ ဘေးထွက်ဆိုးကျိုး မရှိ။
