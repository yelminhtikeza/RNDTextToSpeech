"""Quantize လုပ်ထားသော model ၏ error ကို component တစ်ခုချင်း၊ input တူညီစွာဖြင့် တိုင်းသည်။

အသုံးပြုပုံ: python quant_error.py <pkg_src_dir> <fp32_onnx_dir> <quantized_onnx_dir>
"""
import sys

import numpy as np

from common import SAMPLE_TEXT, load_sessions, tokenize, use_package

STEPS, CFG = 16, 3.0

pkg_dir, fp_dir, q_dir = sys.argv[1:4]
use_package(pkg_dir)


def relative(a, b):
    return float(np.linalg.norm(a - b) / np.linalg.norm(b))


def main():
    fp, q = load_sessions(fp_dir), load_sessions(q_dir)
    tokens = tokenize(SAMPLE_TEXT)
    mu_x_fp, logw_fp = fp[0].run(None, {"tokens": tokens})
    mu_x_q, logw_q = q[0].run(None, {"tokens": tokens})
    print(f"encoder mu_x rel={relative(mu_x_q, mu_x_fp):.3f} "
          f"frames fp={int(np.ceil(np.exp(logw_fp)).sum())} q={int(np.ceil(np.exp(logw_q)).sum())}")

    # Duration ကွာခြားမှုကြောင့် shape မတူမည်ကို ရှောင်ရန် ကျန် component များကို fp32 encoder output ဖြင့် စစ်သည်။
    mu_y = np.repeat(mu_x_fp, np.ceil(np.exp(logw_fp[0, 0])).astype(np.int64), axis=2)
    noise = np.random.default_rng(0).standard_normal(mu_y.shape).astype(np.float32)

    def run_decoder(sessions):
        mu_proj = sessions[1].run(None, {"mu_y": mu_y})[0]
        x = noise.copy()
        for k in range(STEPS):
            x = sessions[2].run(None, {"x": x, "mu_proj": mu_proj, "t": np.array([k / STEPS], np.float32),
                                       "dt": np.array([1 / STEPS], np.float32),
                                       "cfg": np.array([CFG], np.float32)})[0]
        return x

    mel_fp, mel_q = run_decoder(fp), run_decoder(q)
    print(f"prenet+estimator final mel rel={relative(mel_q, mel_fp):.3f}")
    magnitude = lambda sessions: np.hypot(*sessions[3].run(None, {"mel": mel_fp}))  # noqa: E731
    print(f"vocos magnitude rel={relative(magnitude(q), magnitude(fp)):.3f}")


if __name__ == "__main__":
    main()
