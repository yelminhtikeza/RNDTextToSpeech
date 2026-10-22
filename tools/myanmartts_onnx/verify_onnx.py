"""Export လုပ်ထားသော fp32 ONNX pipeline သည် မူရင်း PyTorch နှင့် တူကြောင်း စစ်သည်။

အသုံးပြုပုံ: python verify_onnx.py <pkg_src_dir> <model_dir> <onnx_dir>

PyTorch ၏ အစ noise ကို ဖမ်းယူပြီး ONNX ကိုလည်း ထို noise ဖြင့် run၍ နှိုင်းယှဉ်သည်။
ရလဒ် (2026-10-22): mel max diff 4e-5၊ audio max diff 2.8e-3၊ အရှည် တူညီ။
"""
import sys
import time

import numpy as np
import torch

from common import SAMPLE_RATE, SAMPLE_TEXT, decode, encode, load_sessions, tokenize, use_package

STEPS, CFG = 8, 3.0
MEL_TOLERANCE = 1e-3
AUDIO_TOLERANCE = 1e-2

pkg_dir, model_dir, onnx_dir = sys.argv[1:4]
use_package(pkg_dir)
from myanmar_tts.api import StableTTSAPI  # noqa: E402


def reference_with_noise(api):
    """PyTorch ဖြင့် ထုတ်ပြီး decoder ၏ randn_like noise ကို ဖမ်းယူသည်။"""
    captured = []
    original = torch.randn_like

    def capturing(t, *args, **kwargs):
        out = original(t, *args, **kwargs)
        captured.append(out.clone())
        return out

    torch.randn_like = capturing
    try:
        torch.manual_seed(0)
        audio, mel = api.inference(SAMPLE_TEXT, f"{model_dir}/samples/sample_0.wav", "burmese",
                                   step=STEPS, solver="euler", cfg=CFG)
    finally:
        torch.randn_like = original
    return audio.numpy()[0], mel.numpy(), captured[-1].numpy()


def main():
    api = StableTTSAPI(f"{model_dir}/model_fp32.pt", f"{model_dir}/vocos.pt", "vocos").eval()
    ref_audio, ref_mel, noise = reference_with_noise(api)
    sessions = load_sessions(onnx_dir)

    started = time.time()
    mel, audio = decode(sessions, encode(sessions, tokenize(SAMPLE_TEXT)), noise, STEPS, CFG)
    elapsed = time.time() - started

    mel_diff = np.abs(mel - ref_mel).max()
    audio_diff = np.abs(audio - ref_audio).max()
    print(f"mel max diff={mel_diff:.2e} audio max diff={audio_diff:.2e} lengths ref={len(ref_audio)} onnx={len(audio)}")
    print(f"onnx {elapsed:.2f}s for {len(audio) / SAMPLE_RATE:.2f}s audio at {STEPS} steps")

    # တိုသော/ရှည်သော input ဖြင့် dynamic axes အမှန်တကယ် dynamic ဖြစ်ကြောင်း စစ်သည်။
    for text in ("က", SAMPLE_TEXT * 4):
        mu_y = encode(sessions, tokenize(text))
        _, long_audio = decode(sessions, mu_y, np.random.randn(*mu_y.shape).astype(np.float32), STEPS, CFG)
        print(f"{len(text)} chars -> {len(long_audio) / SAMPLE_RATE:.2f}s audio, finite={np.isfinite(long_audio).all()}")

    if mel_diff > MEL_TOLERANCE or audio_diff > AUDIO_TOLERANCE or len(audio) != len(ref_audio):
        sys.exit("FAILED: ONNX output differs from PyTorch")
    print("OK")


if __name__ == "__main__":
    main()
