"""Dart tokenizer နှင့် ISTFT ကို Python reference နှင့် တူညီကြောင်း စစ်ရန် JSON fixture ထုတ်သည်။

အသုံးပြုပုံ: python make_dart_fixtures.py <pkg_src_dir> <out_json>
ထုတ်ထားသည့်နေရာ: test/fixtures/myanmartts_reference.json
"""
import json
import sys

import numpy as np

from common import istft, tokenize, use_package

use_package(sys.argv[1])

TEXTS = [
    "မင်္ဂလာပါ။ မြန်မာစာကို အသံဖြင့် ဖတ်ပြနေပါသည်။",
    "  ကျေးဇူး   တင်ပါတယ်  ",
    "Hello ၁၂၃ ကမ္ဘာ! (စမ်းသပ်ချက်) 2026",
    "ဧည့်သည်\tများ\nကို ကြိုဆိုပါ၏၊ ဣ ဤ ဥ ဦ ဩ ဪ ၌ ၍ ၎",
    "ႀကီး ၾကည့္",  # Zawgyi code point များ — မြန်မာ range ထဲတွင် ရှိသော်လည်း vocabulary တွင် မပါ
    "abc",
]

# Dart test က တူညီစွာ ပြန်တည်ဆောက်နိုင်ရန် closed-form formula ဖြင့် spectrum သတ်မှတ်သည်။
FRAMES, BINS = 4, 1025
k = np.arange(BINS)[:, None]
f = np.arange(FRAMES)[None, :]
real = (np.sin(0.013 * k + 0.7 * f) * np.exp(-k / 400.0)).astype(np.float32)[None]
imag = (np.cos(0.007 * k - 0.3 * f) * np.exp(-k / 300.0)).astype(np.float32)[None]

fixture = {
    "tokens": [{"text": text, "tokens": tokenize(text)[0].tolist()} for text in TEXTS],
    "istft": {"frames": FRAMES, "audio": [round(float(x), 7) for x in istft(real, imag)]},
}
with open(sys.argv[2], "w") as out:
    json.dump(fixture, out, ensure_ascii=False)
print("wrote", sys.argv[2])
