# MyanmarTTS — Preset အသံ ရွေးချယ်ရန် နမူနာများ

MyanmarTTS သည် reference အသံ ၅–၁၀ စက္ကန့်မှ "လက်ဗွေ" (speaker embedding) ယူ၍ ထိုအသံဖြင့် ဖတ်နိုင်သည်။
Google FLEURS (မြန်မာ၊ CC BY 4.0) မှ clip ၃၆ ခု၏ လက်ဗွေကို တွက်ပြီး အချင်းချင်း အသံ အမတူဆုံး ကျား ၄ / မ ၄ ကို ရွေးထားသည်။

ဖိုင်တိုင်းတွင် စာကြောင်းတူ ဖတ်ထားသည် — `မင်္ဂလာပါ။ မြန်မာစာကို အသံဖြင့် ဖတ်ပြနေပါသည်။`
(step 16၊ CFG 3.0၊ app ထဲက model အတိုင်း)

| အသံ | `*_generated.wav` (app ထုတ်မည့်အသံ) | `*_fleurs_reference.wav` (မူရင်း speaker) | Pitch (မူရင်း → ထုတ်) | လက်ဗွေ တူညီမှု |
|---|---|---|---|---|
| male_1 | ✓ | ✓ | 220 → 182 Hz | 0.94 |
| male_2 | ✓ | ✓ | (တိုင်းမရ) → 158 Hz | 0.73 (အားနည်း) |
| male_3 | ✓ | ✓ | 143 → 148 Hz | 0.92 |
| male_4 | ✓ | ✓ | 136 → 137 Hz | 0.95 |
| female_1 | ✓ | ✓ | 200 → 200 Hz | 0.98 |
| female_2 | ✓ | ✓ | 262 → 212 Hz | 0.96 |
| female_3 | ✓ | ✓ | 208 → 204 Hz | 0.97 |
| female_4 | ✓ | ✓ | 197 → 197 Hz | 0.98 |

မူလ (လက်ရှိ) အသံ ၏ pitch သည် 200 Hz ဖြစ်ပြီး `docs/myanmartts-onnx/listening/5_onnx_mixed_97MB_16steps.wav` တွင် နားထောင်နိုင်သည်။

## နားထောင်ရမည့်အချက်

- **ကြည်လင်မှု** — FLEURS clip များသည် 16 kHz ဖြစ်၍ model (44.1 kHz) အတွက် treble မပါ။ ထုတ်သောအသံ ဝါး/အုံ့ နေသလား။
- **မူရင်းနှင့် တူမှု** — `_generated` သည် `_fleurs_reference` ၏ အသံနှင့် ဆင်သလား။
- **ကွဲပြားမှု** — preset အချင်းချင်း နားဖြင့် ခွဲခြားနိုင်သလား။

## Attribution

Reference clip များ: Google FLEURS — Conneau et al., "FLEURS: Few-shot Learning Evaluation of Universal
Representations of Speech" (2022), https://huggingface.co/datasets/google/fleurs — CC BY 4.0။
Clip တစ်ခုချင်း၏ FLEURS ဖိုင်အမည်ကို `tools/myanmartts_onnx/voice_presets.py` ထုတ်သော `candidates.json` တွင် မှတ်ထားသည်။
