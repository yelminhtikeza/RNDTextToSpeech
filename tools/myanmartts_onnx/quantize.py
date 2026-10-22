"""App တွင် ထည့်မည့် mixed-precision model (~97 MB) ကို ထုတ်သည်။

အသုံးပြုပုံ: python quantize.py <fp32_onnx_dir> <out_dir>

ရွေးချယ်မှု (quant_error.py ဖြင့် တိုင်းပြီး docs/myanmartts-onnx/listening ဖိုင် 5 ကို နားထောင်ရွေးထား):
- encoder, estimator: int8 (QUInt8, per-channel) — error ~1%။
  QInt8 ကို မသုံးခြင်းမှာ ORT CPU တွင် signed ConvInteger kernel မရှိ၍ ဖြစ်သည်။
- prenet: fp32 — per-tensor int8 တွင် error 18%။
- vocos: fp32 — head output ကို exp() ယူသဖြင့် error ချဲ့ထွင်ပြီး int8 ဖြင့် အသံကြမ်းသည်။
  (MatMul-only int8 vocos = 62 MB set ကို နားထောင်ပြီး ပယ်ခဲ့သည်။)
"""
import shutil
import sys

from onnxruntime.quantization import QuantType, quantize_dynamic

src, dst = sys.argv[1:3]
for name in ("encoder", "estimator"):
    quantize_dynamic(f"{src}/{name}.onnx", f"{dst}/{name}.onnx", weight_type=QuantType.QUInt8, per_channel=True)
    print("quantized", name)
for name in ("prenet", "vocos"):
    shutil.copy(f"{src}/{name}.onnx", f"{dst}/{name}.onnx")
    print("copied fp32", name)
