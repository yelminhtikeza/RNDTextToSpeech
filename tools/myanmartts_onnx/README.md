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
| 1. Export | `python export_onnx.py work/pkg/src work/hf_model work/fp32` | fp32 graph ၄ ခု (174 MB) |
| 2. စစ်ဆေး | `python verify_onnx.py work/pkg/src work/hf_model work/fp32` | PyTorch နှင့် ကိုက်ညီပါက `OK` |
| 3. Quantize | `python quantize.py work/fp32 work/app` | App model (97 MB) |
| 4. Error တိုင်း | `python quant_error.py work/pkg/src work/fp32 work/app` | component တစ်ခုချင်း error |
| 5. နားထောင် | `python render_sample.py work/pkg/src work/app sample.wav 16` | နမူနာ WAV + အမြန်နှုန်း |
| 6. Dart fixture | `python make_dart_fixtures.py work/pkg/src test/fixtures/myanmartts_reference.json` | Dart test fixture |

Script များကို `tools/myanmartts_onnx/` ထဲမှ run ပါ (`common.py` ကို import လုပ်သည်)။

ပြီးလျှင် `work/app/<name>.onnx` ကို `assets/models/myanmartts_v<N>_<name>.onnx` သို့ ကူးပါ။
**Model ပြောင်းတိုင်း `<N>` ကို တိုးပြီး `lib/config/myanmartts_config.dart` ကိုပါ ပြင်ပါ** — plugin သည်
ဖိုင်အမည်ဖြင့် cache လုပ်သဖြင့် အမည်မပြောင်းပါက ဖုန်းများက model အဟောင်းကို ဆက်သုံးမည်။

## စစ်ဆေးထားသော ရလဒ် (2026-10-22, ARM CPU thread 4)

- ONNX vs PyTorch: mel max diff 4.05e-5၊ audio max diff 2.84e-3၊ အရှည် တူညီ။
- Script များကို အစမှ ပြန် run ၍ ထွက်လာသော အသံသည် `docs/myanmartts-onnx/listening/5_*.wav` နှင့် bit-identical။
- Step 16 တွင် အသံ 4.9 စက္ကန့်ကို ~5.3 စက္ကန့်။
