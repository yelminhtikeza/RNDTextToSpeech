# Design Inputs — ဖုန်းပေါ် MyanmarTTS (ONNX)

ISO 9001:2015 အပိုဒ် 8.3.3 အရ ဤ feature က ဖြည့်ဆည်းရမည့် လိုအပ်ချက်များ။ ဆုံးဖြတ်ချက်များ (design output) ကို `docs/adr/0002` တွင် ကြည့်ပါ။

## 1. Functional / performance requirements

- Android ဖုန်းပေါ်တွင် internet မလိုဘဲ freococo/MyanmarTTS ၏ အသံဖြင့် မြန်မာ Unicode စာကို ဖတ်ပြရမည်။
- အသံအရည်အသွေးသည် product owner နားထောင်ရွေးထားသော `docs/myanmartts-onnx/listening/5_onnx_mixed_97MB_16steps.wav` ထက် မနိမ့်ရ။
- ဖတ်နေစဉ် ရပ်နိုင်ရမည်၊ အမြန်နှုန်း ချိန်နိုင်ရမည်၊ အခြား Android engine သို့ ပြောင်းနိုင်ရမည်။
- MyanmarTTS ၏ step (4–32) နှင့် CFG (1.0–5.0) ကို HF Space ကဲ့သို့ ချိန်နိုင်ရမည်။ Step မြင့်လျှင် ဖုန်းပေါ်တွင်
  ထုတ်ချိန် အချိုးကျ ကြာမည်ဖြစ်ကြောင်း အသုံးပြုသူ သိရမည် (slider အောက်တွင် ရှင်းပြချက်)။
- စာရှည် (စာလုံး 4000 အထိ) ကို memory မပြည့်စေဘဲ ဖတ်နိုင်ရမည်။
- MyanmarTTS ဖြင့် အဆုံးထိ ဖတ်ပြီးသော အသံကို WAV ဖိုင်အဖြစ် အသုံးပြုသူ ရွေးသော နေရာတွင် download လုပ်နိုင်ရမည်။
  Download ဖိုင်သည် ဖန်သားပြင်ပေါ်ရှိ လက်ရှိစာနှင့် အမြဲ ကိုက်ညီရမည်။
- ထုတ်ပြီးသော အသံ၏ waveform နှင့် ကြာချိန်ကို ပြရမည် — download လုပ်မည့် ဖိုင်နှင့် တစ်ခုတည်းဖြစ်ပြီး
  စာပြင်လျှင်/engine ပြောင်းလျှင် အတူ ပျောက်ရမည်။ စာရှည် (မိနစ်ချီ) တွင်ပင် UI မထစ်ရ (isolate ဖြင့် တွက်)။
- ထုတ်ပြီးသော အသံကို model ထပ်မ run ဘဲ ပြန်ဖွင့်နိုင်ရမည် (ချက်ချင်းစ၍ ကြားခဲ့သည့်အတိုင်း တူညီ)၊ Stop ဖြင့် ရပ်နိုင်ရမည်။
- ⚠️ DETERMINATION REQUIRED — ဖုန်းပေါ်တွင် "ဖတ်ပါ" နှိပ်ပြီး အသံစထွက်ရန် လက်ခံနိုင်သော အချိန်နှင့်
  ပံ့ပိုးရမည့် အနိမ့်ဆုံး ဖုန်း (RAM/CPU) ကို မသတ်မှတ်ရသေးပါ။

## 2. Information from previous similar designs

- ADR 0001 / `docs/burmese-tts/` — Android TTS engine ရှာဖွေခြင်း၊ ရပ်ခြင်းကို အမှားအဖြစ် မပြရန် flag၊ input validation တို့ကို ပြန်သုံးသည်။
- စမ်းသပ်စက်တွင် built-in engine များ မြန်မာ မပံ့ပိုးကြောင်း၊ SM Myanmar TTS ထည့်မှ ဖတ်နိုင်ကြောင်း တွေ့ရှိခဲ့သည် —
  ထို့ကြောင့် Android engine ကို fallback အဖြစ် ဆက်ထားသည်။
- Upstream HF Space သည် Euler step 32 သုံးသော်လည်း PC CPU ပေါ်တွင် real-time ၏ ၄ ဆ နှေးကြောင်း တိုင်းထားသည်။

## 3. Statutory / regulatory requirements

- Model weights နှင့် ထွက်လာသော အသံ — CC0 1.0 (public domain)။ Vocos vocoder weights — MIT (Copyright (c) 2024 KdaiP)၊
  APK ထဲတွင် license notice ပါရမည် → `assets/models/NOTICE.txt`။
- စာသားကို ဖုန်းပေါ်တွင်သာ လုပ်ဆောင်ပြီး ပြင်ပသို့ မပို့ပါ (MyanmarTTS engine ရွေးထားစဉ်)။
- ⚠️ DETERMINATION REQUIRED — App ထုတ်ဝေမည့် ဈေးကွက်/ဥပဒေ (accessibility၊ AI-generated voice ဖော်ပြရန် လိုအပ်ချက်) မသတ်မှတ်ရသေးပါ။

## 4. Standards committed to

- ISO 9001:2015 (အဖွဲ့အစည်း coding standard)။
- Unicode မြန်မာစာ (U+1000–U+109F) — Zawgyi ကို မပံ့ပိုးပါ။
- Google Play 16 KB page size လိုအပ်ချက် — `flutter_onnxruntime` ≥ 1.5.1 ဖြင့် ဖြည့်ဆည်းသည်။
- ONNX opset 17၊ ONNX Runtime 1.28 (Android)။

## 5. Potential consequences of failure

- Model load မအောင်မြင်ပါက (asset ပျက်/storage မလောက်) fallback မရှိလျှင် app တစ်ခုလုံး အသံမထွက် —
  ထို့ကြောင့် engine စာရင်းကို ဆက်ပြထားပြီး Android engine သို့ ပြောင်းနိုင်စေသည်။
- Model ပြောင်းသော်လည်း asset ဖိုင်အမည် မပြောင်းပါက plugin cache ကြောင့် အဟောင်းကို တိတ်တဆိတ် ဆက်သုံးပြီး
  ပြင်ဆင်ချက်များ ရောက်မလာ — အမှား message လည်း မပေါ်ပါ။
- စာရှည်ကို တစ်ခါတည်း run ပါက attention memory သည် frame ၏ နှစ်ထပ်ကိန်းဖြင့် တိုးပြီး ဖုန်းတွင် app crash ဖြစ်မည်။
- ONNX Runtime ၏ Java class များကို R8 က ဖယ်ပါက release build တွင်သာ crash ဖြစ်ပြီး debug စမ်းသပ်မှုတွင် မတွေ့ရ။
- OrtValue (native memory) ကို မရှင်းပါက ဖတ်တိုင်း memory ယိုစိမ့်ပြီး အကြိမ်များစွာ ဖတ်ပြီးနောက် crash ဖြစ်မည်။
- စာပြင်ပြီးနောက် အသံအဟောင်းကို download ပေးပါက အသုံးပြုသူသည် မှားသော စာ၏ အသံဖိုင်ကို မသိဘဲ ဖြန့်ဝေမိမည်။
- Zawgyi သို့မဟုတ် ပုဒ်ဖြတ်သက်သက် input ကို model သို့ ပို့ပါက အဓိပ္ပါယ်မဲ့ ဆူညံသံ ထွက်မည် —
  ထို့ကြောင့် ဖတ်စရာ မြန်မာစာလုံး မပါလျှင် ငြင်းသည်။
