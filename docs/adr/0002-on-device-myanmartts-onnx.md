# ADR 0002 — MyanmarTTS ကို ဖုန်းပေါ်တွင် ONNX ဖြင့် run ခြင်း

- **Status:** Accepted
- **Date:** 2026-10-22
- **ADR 0001 ကို ပြင်ဆင်သည်:** ပုံသေ engine ကို Android TTS မှ ဖုန်းပေါ် MyanmarTTS သို့ ပြောင်းသည်။ Android engine ကို fallback အဖြစ် ဆက်ထားသည်။

## Context

Android စက်အများစု၏ built-in TTS engine တွင် မြန်မာအသံ မပါပါ။ စမ်းသပ်စက်တွင် Play Store မှ SM Myanmar TTS ထည့်မှသာ ဖတ်နိုင်သည်။
[freococo/MyanmarTTS](https://huggingface.co/freococo/MyanmarTTS) (StableTTS + Vocos၊ parameter 31M၊ CC0) ၏ အသံကို ပိုနှစ်သက်ကြောင်း
product owner က ဆုံးဖြတ်ခဲ့သည်။ ထို model သည် Python/PyTorch သာ ဖြစ်ပြီး Android TTS engine မဟုတ်သဖြင့် `flutter_tts` ဖြင့် မသုံးနိုင်ပါ။

## Decision

1. Model ကို ONNX graph လေးခု (encoder, prenet, estimator, vocos) အဖြစ် export လုပ်ပြီး `flutter_onnxruntime` ဖြင့် ဖုန်းပေါ်တွင် run မည်။
   ONNX ↔ PyTorch ကိုက်ညီမှု: mel max diff 4e-5၊ audio max diff 2.8e-3 (`tools/myanmartts_onnx/verify_onnx.py`)။
2. **Model 97 MB (mixed precision)၊ Euler step 16 ခု** — `docs/myanmartts-onnx/listening/` ရှိ ဖိုင် ၅ ခုကို
   နားထောင်ပြီး product owner က ဖိုင် 5 ကို ရွေးခဲ့သည်။ encoder/estimator int8၊ prenet/vocos fp32။
3. Model ကို APK ထဲ bundle လုပ်မည် (Git LFS ဖြင့် သိမ်း)။ ပထမဆုံးဖွင့်ချိန်မှစ၍ internet မလိုပါ။
4. Engine စာရင်းတွင် MyanmarTTS ကို ပထမ/ပုံသေ ထားပြီး my-MM ပံ့ပိုးသော Android engine များကို နောက်တွင် ဆက်ပြမည်။
5. Speaker embedding (reference `samples/sample_0.wav`) ကို graph ထဲ ပုံသေထည့်ထားသဖြင့် ဖုန်းပေါ်တွင် reference encoder/mel extraction မလိုပါ။
6. Graph မှ ထုတ်မရသော အပိုင်းများကို Dart တွင် ရေးသည် — tokenizer (vocabulary 98)၊ length regulation၊ ISTFT။
   Python reference နှင့် test fixture ဖြင့် ကိုက်ညီကြောင်း စစ်ထားသည် (ISTFT diff < 1e-5)။
7. Estimator graph ထဲ Euler step (`x + dt·v`) ထည့်ထားသဖြင့် step loop တစ်လျှောက် tensor များ native ဘက်တွင်သာ ရှိပြီး
   platform channel မှ မကူးရပါ။
8. စာရှည်ကို ဝါကျ (။) အလိုက် ≤120 စာလုံး ခွဲပြီး အပိုင်း i ဖွင့်နေစဉ် i+1 ကို ကြိုထုတ်သည်။
9. **Download:** အဆုံးထိ ဖတ်ပြီးသော MyanmarTTS အသံကို WAV (44.1 kHz, 16-bit mono) တစ်ဖိုင်အဖြစ် Android "Save as"
   dialog (Storage Access Framework, `flutter_file_dialog`) ဖြင့် သိမ်းနိုင်သည်။ ကြားခဲ့သည့် အသံကိုသာ သိမ်းသဖြင့်
   ထပ်မထုတ်ရ။ ရပ်ထားသော/စာပြင်ပြီးသော/engine ပြောင်းပြီးသော အသံကို မပေးပါ — စာနှင့် မကိုက်သော ဖိုင်မထွက်စေရန်။
   - ပယ်ခဲ့သော ရွေးချယ်မှု: MediaStore ဖြင့် Downloads သို့ တိုက်ရိုက်ရေးခြင်း (Android version အလိုက် permission ကွဲ)၊
     Android engine များအတွက် `synthesizeToFile` (third-party engine အများစု ယုံကြည်စိတ်ချ မရ)၊
     `flutter_file_dialog` ≥ 3.1 (Dart 3.12 လို၍ project SDK constraint `^3.11.5` နှင့် မကိုက်)။

## Rejected alternatives

- **HF Space API ကို တိုက်ရိုက်ခေါ်ခြင်း:** အခြားသူ၏ free demo (ZeroGPU quota၊ queue၊ အိပ်သွားနိုင်) ဖြစ်၍ ယုံကြည်စိတ်ချ၍ မရ။
- **ကိုယ်ပိုင် server တွင် run ခြင်း:** ယုံကြည်ရသော်လည်း server ကုန်ကျစရိတ်၊ internet လိုအပ်ခြင်း၊ စာသား ဖုန်းအပြင်ထွက်ခြင်း ရှိသည်။
- **Model 62 MB (vocos ပါ int8):** vocos ၏ spectral error 6% — နားထောင်ပြီး ပယ်သည်။
- **Model 174 MB (fp32 အားလုံး):** APK ကြီးလွန်းပြီး 97 MB နှင့် နားဖြင့် မခွဲခြားနိုင်။
- **Step 32 (HF demo ပုံသေ):** PC CPU ပေါ်တွင်ပင် real-time ၏ ၄ ဆ နှေး။ **Step 8:** ၂ ဆ မြန်သော်လည်း အရည်အသွေး ကျ။
- **ISTFT ကို ONNX ထဲ DFT matrix ဖြင့် ထည့်ခြင်း:** model ကို ~32 MB ပိုကြီးစေသည်။
- **First launch တွင် model download:** APK သေးသော်လည်း internet၊ progress UI၊ download error handling လိုသည်။
- **`onnxruntime` pub package:** ၂၀၂၄ မတ်လနောက်ပိုင်း update မရှိ — `flutter_onnxruntime` (ORT 1.28) ကို ရွေးသည်။

## Consequences

- APK သည် model ~97 MB + ORT native library ကြောင့် ကြီးလာမည်။ ABI split မလုပ်ရသေးပါ။
- Pitch ထိန်းချုပ်မှု MyanmarTTS တွင် မရ (Android engine တွင်သာ)။ အမြန်နှုန်းကို duration scale ဖြင့် ပြောင်းသည်။
- အသံတစ်မျိုး (အမျိုးသမီး) သာ ရှိသည်။
- ⚠️ ဖုန်းအစစ်ပေါ်တွင် အမြန်နှုန်းနှင့် memory ကို မတိုင်းရသေးပါ — PC ARM CPU (thread 4) တွင် အသံ 4.9 စက္ကန့်ကို 5.3 စက္ကန့်။
- Model ပြောင်းလျှင် `MyanmarTtsConfig` ရှိ asset ဖိုင်အမည်၏ version (`v1`) ကို တိုးရမည် —
  plugin သည် ဖိုင်အမည်ဖြင့် cache လုပ်သဖြင့် မတိုးပါက အဟောင်းကို ဆက်သုံးမည်။

## Rollback plan

`lib/providers/burmese_speech_controller.dart` ၏ `detectBurmeseEngines` တွင် `TtsConfig.ON_DEVICE_ENGINE_ID` ကို
စာရင်းမှ ဖယ်ပါက Android engine သီးသန့် (ADR 0001) သို့ ပြန်ရောက်သည်။ APK အရွယ်ပါ ပြန်လျှော့လိုပါက
`assets/models/` နှင့် pubspec ၏ `flutter_onnxruntime`၊ `audioplayers` ကို ဖယ်ပါ။
