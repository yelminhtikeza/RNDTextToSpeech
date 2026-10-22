"""Dart integration test (integration_test/myanmartts_onnx_test.dart) အတွက် noise နှင့် မျှော်မှန်းအသံကို ထုတ်သည်။

အသုံးပြုပုံ: python dump_parity.py <pkg_src_dir> <onnx_dir> <out_dir>
ပြီးလျှင်:  flutter test integration_test -d linux --dart-define=MYANMARTTS_PARITY_DIR=<out_dir>
"""
import sys

import numpy as np

from common import SAMPLE_TEXT, decode, encode, load_sessions, tokenize, use_package

STEPS, CFG, NOISE_SEED = 16, 3.0, 7

pkg_dir, onnx_dir, out_dir = sys.argv[1:4]
use_package(pkg_dir)
sessions = load_sessions(onnx_dir)
mu_y = encode(sessions, tokenize(SAMPLE_TEXT))
noise = np.random.default_rng(NOISE_SEED).standard_normal(mu_y.shape).astype(np.float32)
_, audio = decode(sessions, mu_y, noise, STEPS, CFG)
noise.tofile(f"{out_dir}/noise.f32")
audio.astype(np.float32).tofile(f"{out_dir}/audio.f32")
print("frames", mu_y.shape[2], "samples", len(audio))
