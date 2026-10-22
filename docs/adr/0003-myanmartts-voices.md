# ADR 0003 — MyanmarTTS အသံပြောင်းခြင်း (preset နှင့် ဖုန်းဖြင့် အသံသွင်းခြင်း)

- **Status:** Accepted
- **Date:** 2026-10-22
- **ADR 0002 ကို ပြင်ဆင်သည်:** speaker embedding ကို graph ထဲ ပုံသေထည့်ခြင်းမှ input သို့ ပြောင်းသည်။

## Context

MyanmarTTS (StableTTS) သည် reference အသံ ၅–၁၀ စက္ကန့်ကို reference encoder ဖြင့် 256 ဂဏန်း "လက်ဗွေ" (speaker embedding)
အဖြစ်ပြောင်းပြီး ထိုအသံဖြင့် ဖတ်သည် (zero-shot voice cloning)။ ADR 0002 တွင် မူလ reference (`samples/sample_0.wav`၊ အမျိုးသမီး)
၏ လက်ဗွေကို encoder/estimator ထဲ ပုံသေထည့်ခဲ့သဖြင့် အသံ တစ်မျိုးတည်းသာ ရှိသည်။ Product owner က preset အသံများ (A) နှင့်
ဖုန်းဖြင့် ကိုယ်ပိုင်အသံ သွင်းခြင်း (B) နှစ်ခုလုံး လိုချင်ကြောင်း ဆုံးဖြတ်ခဲ့သည်။

## Decision

1. Encoder နှင့် estimator ကို `speaker[1,256]` input ပါသော v2 graph အဖြစ် export လုပ်သည်။ prenet/vocos မပြောင်း (byte တူ) ၍ v1 ဆက်သုံးသည်။
2. **Preset (A):** လက်ဗွေကို PC ပေါ်တွင် ကြိုတွက်ပြီး `assets/voices/presets.json` (တစ်ခု ~1 KB) အဖြစ် ထည့်သည်။
   Reference clip များကို Google FLEURS မြန်မာ (CC BY 4.0) မှ ယူသည် — product owner ရွေးချယ်ချက်။ FLEURS တွင် speaker ID မပါသဖြင့်
   clip ၃၆ ခု၏ လက်ဗွေမှ cosine အကွာအဝေး အဝေးဆုံး (farthest-first) ကျား/မ တစ်ဖက်စီ ရွေးပြီး နားထောင်ရွေးရန် `docs/myanmartts-onnx/voices/` တွင် ထားသည်။
3. **အသံသွင်း (B):** ဖုန်းတွင် 44.1 kHz mono WAV ၅–၁၅ စက္ကန့် သွင်း (`record` package) → Dart magnitude STFT → `reference.onnx`
   (mel filterbank + log + reference encoder၊ 2.4 MB) → လက်ဗွေ။ လက်ဗွေနှင့် အမည်ကိုသာ app support directory ရှိ JSON တွင် သိမ်းပြီး
   **အသံဖိုင်ကို သိမ်းဆည်းခြင်း မပြု** (ယာယီဖိုင်ကို ဖတ်ပြီးချင်း ဖျက်)။
4. Preset တွက်ခြင်းနှင့် ဖုန်း၏ တွက်ခြင်းသည် လမ်းကြောင်း တူညီသည် — Python `magnitude_stft` (Dart ၏ reference) + `reference.onnx`။
   PyTorch မူရင်းနှင့် လက်ဗွေ ကွာခြားချက် 2.9e-6၊ Dart STFT နှင့် Python ကွာခြားချက် < 1e-5 (relative)။
5. ထုတ်မည့် preset — မူလ **Thiri** (ပုံသေ) နှင့် FLEURS ၈ ခုလုံး (အမျိုးသမီး Hnin/Su/May/Nandar၊ အမျိုးသား Aung/Kyaw/Min/Zaw)။
   Product owner က candidate အားလုံး ထည့်ပြီး အမည်ပေးရန် ဆုံးဖြတ်ခဲ့သည်။
6. အသံစီမံခြင်းကို `VoiceController` (Riverpod) သီးခြားထားပြီး speech controller က ဖတ်ချိန်တွင် ရွေးထားသော လက်ဗွေကိုသာ ယူသည်။

## Rejected alternatives

- **STFT ကို ONNX ထဲ ထည့်ခြင်း:** `torch.stft` သည် complex output ဖြစ်၍ export မရ။ DFT ကို conv weight ဖြင့် အစားထိုးပါက graph ~17 MB ပိုကြီးမည်။
- **Pitch/speed effect (option C):** model မပြောင်းဘဲ ရနိုင်သော်လည်း speaker တစ်ယောက်တည်း၏ အသံသာ ပြောင်းသွားပြီး သဘာဝမကျ။
- **Recording ဖိုင်ကိုပါ သိမ်းခြင်း:** နောက်မှ ပြန်တွက်နိုင်သော်လည်း ကိုယ်ရေးကိုယ်တာ အသံ (biometric) ဖုန်းထဲ ကျန်မည်။
- **nn.MultiheadAttention ကို တိုက်ရိုက် export:** fast path op ကို ONNX မသိ၊ fast path ပိတ်လျှင်လည်း sequence အရှည် ပုံသေ reshape ဖြစ်သွား၍
  reference encoder ၏ attention ကို `in_proj`/`out_proj` weight ဖြင့် ကိုယ်တိုင်ရေးထားသည် (သင်္ချာ တူ၊ verify ဖြင့် စစ်)။
- **Recording package `record` 7.x / `flutter_file_dialog` 3.1+:** Dart 3.12 လိုသဖြင့် project SDK `^3.11.5` နှင့် မကိုက်။

## Consequences

- Model assets ~104 MB (v2 encoder/estimator + reference 2.4 MB)။
- Encoder/estimator ၏ speaker conditioning layer များသည် ယခု int8 dynamic quantize ဖြစ်သွားသည် (ယခင် constant-fold ဖြင့် fp32)။
  တိုင်းထားချက်: mel error 1.1% (v1 1.2%)၊ frame အရေအတွက် 423 → 422 — အရည်အသွေး မကျ။
- FLEURS clip များသည် 16 kHz ဖြစ်၍ model ၏ 44.1 kHz အတွက် treble မပါ — preset အသံ ဝါးနိုင်ခြင်းကို နားဖြင့် စစ်ရန်။
- Clone လုပ်နိုင်မှု အရည်အသွေးသည် training data ပေါ် မူတည်သည် (model card တွင် speaker အရေအတွက် မဖော်ပြ)။
  တိုင်းထားချက်: ကျား ၂ ခု (male_3/4) သည် pitch နိမ့် (137–148 Hz) ကို ထိန်းနိုင်၊ male_2 သည် လက်ဗွေ တူညီမှု 0.73 သာ။
- Android `RECORD_AUDIO` permission ထပ်လိုသည်။ ⚠️ iOS ကို ပစ်မှတ်ထားလာပါက `NSMicrophoneUsageDescription` ထည့်ရမည်။
- FLEURS (CC BY 4.0) attribution ကို `assets/models/NOTICE.txt` တွင် ထည့်ရမည်။

## Rollback plan

`assets/voices/presets.json` တွင် `original` တစ်ခုတည်းထားပါက ADR 0002 ၏ အသံနှင့် တူညီသည် (v2 graph ဖြင့်)။
Model ကိုပါ ပြန်ချလိုပါက v1 encoder/estimator assets နှင့် `MyanmarTtsConfig` asset အမည်များကို git history မှ ပြန်ယူပြီး
voice controller၊ voice section၊ record sheet နှင့် `record` dependency ကို ဖယ်ပါ။
