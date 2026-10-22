# MyanmarTTS → ONNX tool များ

`assets/models/myanmartts_v1_*.onnx` ကို ထုတ်ရန်နှင့် စစ်ဆေးရန် script များ။ ဆုံးဖြတ်ချက်များကို `docs/adr/0002` တွင် ကြည့်ပါ။

## ပြင်ဆင်ခြင်း

```bash
python3 -m venv venv
venv/bin/pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
venv/bin/pip install -r tools/myanmartts_onnx/requirements.txt

# Upstream model (CC0) နှင့် package code
mkdir -p work/hf_model/samples work/pkg && cd work
B=https://huggingface.co/freococo/MyanmarTTS/resolve/main
for f in model_fp32.pt vocos.pt samples/sample_0.wav; do curl -sL -o hf_model/$f $B/$f; done
curl -sL -o pkg/myanmartts.whl \
  https://files.pythonhosted.org/packages/20/47/6857ae265224533f9b421fbb8f0840890855b4347b1727b24087efd3678c/myanmartts-1.0.2-py3-none-any.whl
python3 -m zipfile -e pkg/myanmartts.whl pkg/src
```

## ထုတ်ခြင်း (အစဉ်လိုက်)

| အဆင့် | Command | ရလဒ် |
|---|---|---|
| 1. Export | `python export_onnx.py work/pkg/src work/hf_model work/fp32` | fp32 graph ၅ ခု (reference ပါ) |
| 2. စစ်ဆေး | `python verify_onnx.py work/pkg/src work/hf_model work/fp32` | PyTorch နှင့် ကိုက်ညီပါက `OK` (လက်ဗွေ လမ်းကြောင်းပါ စစ်) |
| 3. Quantize | `python quantize.py work/fp32 work/app` | App model (~104 MB) |
| 4. Error တိုင်း | `python quant_error.py work/pkg/src work/fp32 work/app <presets.json>` | component တစ်ခုချင်း error |
| 5. နားထောင် | `python render_sample.py work/pkg/src work/app sample.wav 16 <presets.json> <preset_id>` | နမူနာ WAV + အမြန်နှုန်း |
| 6. Dart fixture | `python make_dart_fixtures.py work/pkg/src test/fixtures/myanmartts_reference.json` | Dart test fixture (tokenizer/ISTFT/STFT) |
| 7. Parity | `python dump_parity.py work/pkg/src work/app <dir> <presets.json>` | integration test အတွက် noise + အသံ |

## Preset အသံ (ADR 0003)

| အဆင့် | Command |
|---|---|
| FLEURS clip ယူ | `python fetch_fleurs_clips.py work/fleurs 24 12` (2.1 GB archive ကို stream ဖတ်ပြီး လိုသလောက်သာ ယူ) |
| Candidate ထုတ် | `python voice_presets.py candidates work/pkg/src work/app work/fleurs work/voices 4` |
| မူလအသံ ထည့် | `python voice_presets.py add work/app work/voices/candidates.json original work/hf_model/samples/sample_0.wav "freococo/MyanmarTTS samples/sample_0.wav (CC0 1.0)"` |
| App asset ထုတ် | `python voice_presets.py build work/voices/candidates.json ../../assets/voices/presets.json "original=Original (female)\|မူလ (အမျိုးသမီး)" "male_3=Male 3\|အမျိုးသား ၃" ...` |

`build` ၏ ပထမဆုံး id သည် app ၏ ပုံသေ အသံ ဖြစ်သည်။ FLEURS preset ထည့်ပါက `assets/models/NOTICE.txt` ၏ attribution ကို စစ်ပါ။

Script များကို `tools/myanmartts_onnx/` ထဲမှ run ပါ (`common.py` ကို import လုပ်သည်)။

ပြီးလျှင် `work/app/<name>.onnx` ကို `assets/models/myanmartts_v<N>_<name>.onnx` သို့ ကူးပါ (ယခု: encoder/estimator v2၊ prenet/vocos/reference v1)။
**Model ပြောင်းတိုင်း `<N>` ကို တိုးပြီး `lib/config/myanmartts_config.dart` ကိုပါ ပြင်ပါ** — plugin သည်
ဖိုင်အမည်ဖြင့် cache လုပ်သဖြင့် အမည်မပြောင်းပါက ဖုန်းများက model အဟောင်းကို ဆက်သုံးမည်။

## စစ်ဆေးထားသော ရလဒ် (2026-10-22, ARM CPU thread 4)

- v2 (speaker input) ONNX vs PyTorch: speaker embedding diff 2.86e-6၊ mel max diff 3.31e-5၊ audio max diff 2.63e-3၊ အရှည် တူညီ။
- v1 (speaker ပုံသေ) သည် `docs/myanmartts-onnx/listening/5_*.wav` နှင့် bit-identical ဖြစ်ခဲ့သည်။ v2 int8 တွင်
  speaker conditioning layer များပါ quantize ဖြစ်သဖြင့် frame 423 → 422 ကွာပြီး mel error 1.1% (v1 1.2%) — အရည်အသွေး မကျ။
- Step 16 တွင် အသံ 4.9 စက္ကန့်ကို ~5.3–5.6 စက္ကန့်။
