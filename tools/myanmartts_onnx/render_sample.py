"""App နှင့် တစ်ထပ်တည်းကျသော pipeline ဖြင့် နမူနာ WAV ထုတ်ပြီး အချိန်တိုင်းသည် (နားထောင်စမ်းသပ်ရန်)။

အသုံးပြုပုံ: python render_sample.py <pkg_src_dir> <onnx_dir> <out_wav> <steps>
"""
import sys
import time

import numpy as np
import soundfile as sf

from common import SAMPLE_RATE, SAMPLE_TEXT, decode, encode, load_sessions, tokenize, use_package

CFG = 3.0
NOISE_SEED = 0

pkg_dir, onnx_dir, out_wav, steps = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
use_package(pkg_dir)

sessions = load_sessions(onnx_dir)
started = time.time()
mu_y = encode(sessions, tokenize(SAMPLE_TEXT))
noise = np.random.default_rng(NOISE_SEED).standard_normal(mu_y.shape).astype(np.float32)
_, audio = decode(sessions, mu_y, noise, steps, CFG)
elapsed = time.time() - started
seconds = len(audio) / SAMPLE_RATE
print(f"{out_wav}: {elapsed:.2f}s for {seconds:.2f}s audio (rtf {elapsed / seconds:.2f})")
sf.write(out_wav, audio, SAMPLE_RATE)
