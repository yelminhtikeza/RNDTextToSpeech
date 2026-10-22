"""MyanmarTTS ONNX tool များ မျှဝေသုံးသော အပိုင်းများ။

- myanmartts package ကို export လုပ်၍ရအောင် patch လုပ်ခြင်း (batch 1၊ padding မရှိ — ရလဒ် တူညီ)
- Python reference tokenizer နှင့် ISTFT (Dart port ၏ မူရင်း)
- App နှင့် တစ်ထပ်တည်းကျသော ONNX pipeline
"""
import sys

import numpy as np

N_FFT = 2048
HOP = 512
SAMPLE_RATE = 44100
MEL_CHANNELS = 128
MODEL_NAMES = ("encoder", "prenet", "estimator", "vocos", "reference")
SAMPLE_TEXT = "မင်္ဂလာပါ။ မြန်မာစာကို အသံဖြင့် ဖတ်ပြနေပါသည်။"


def use_package(pkg_src_dir):
    """myanmartts wheel ကို ဖြည်ထားသော `src` folder ကို import path ထဲ ထည့်ပြီး export-safe patch များ သွင်းသည်။"""
    sys.path.insert(0, pkg_src_dir)
    import torch
    import soundfile as sf
    import torchaudio.functional as AF
    import myanmar_tts.api as tts_api
    from myanmar_tts.models import diffusion_transformer as dit

    def load_and_resample_audio(path, target_sr):
        # torchaudio.load သည် torchcodec မပါလျှင် None ပြန်သဖြင့် soundfile ဖြင့် အစားထိုးသည် (HF Space နှင့် တူ)
        data, sr = sf.read(path, dtype="float32", always_2d=True)
        wav = torch.from_numpy(data.T).mean(0, keepdim=True)
        return AF.resample(wav, sr, target_sr) if sr != target_sr else wav

    def rope_forward(self, x):
        # မူရင်းသည် ပထမဆုံးတွေ့သော အရှည်ဖြင့် cos/sin ကို cache လုပ်သဖြင့် export တွင် အရှည် ပုံသေဖြစ်သွားမည် —
        # cache မသုံးဘဲ ခေါ်တိုင်း တွက်သည်။
        x = x.permute(2, 0, 1, 3)
        theta = 1.0 / (self.base ** (torch.arange(0, self.d, 2, dtype=torch.float32) / self.d))
        idx_theta = torch.arange(x.shape[0], dtype=torch.float32)[:, None] * theta[None, :]
        idx_theta2 = torch.cat([idx_theta, idx_theta], dim=1)
        cos, sin = idx_theta2.cos()[:, None, None, :], idx_theta2.sin()[:, None, None, :]
        x_rope, x_pass = x[..., : self.d], x[..., self.d:]
        x_rope = x_rope * cos + self._neg_half(x_rope) * sin
        return torch.cat((x_rope, x_pass), dim=-1).permute(1, 2, 0, 3)

    def dit_block_forward(self, x, c, x_mask):
        # batch 1 တွင် x_mask အားလုံး 1 ဖြစ်၍ attention mask သည် သုည — ဖယ်ထားသည်။
        shift_msa, scale_msa, gate_msa, shift_mlp, scale_mlp, gate_mlp = (
            self.adaLN_modulation(c).unsqueeze(2).chunk(6, dim=1))
        x = x + gate_msa * self.attn(self.modulate(self.norm1(x.transpose(1, 2)).transpose(1, 2), shift_msa, scale_msa), None)
        x = x + gate_mlp * self.mlp(self.modulate(self.norm2(x.transpose(1, 2)).transpose(1, 2), shift_mlp, scale_mlp), x_mask)
        return x

    tts_api.load_and_resample_audio = load_and_resample_audio
    dit.RotaryPositionalEmbeddings.forward = rope_forward
    dit.DiTConVBlock.forward = dit_block_forward
    return load_and_resample_audio


def tokenize(text):
    """Python reference tokenizer — `use_package` ကို အရင်ခေါ်ရမည်။"""
    from myanmar_tts.datas.dataset import intersperse
    from myanmar_tts.text import cleaned_text_to_sequence
    from myanmar_tts.text.burmese import burmese_to_ipa2
    return np.array([intersperse(cleaned_text_to_sequence(burmese_to_ipa2(text)), item=0)], dtype=np.int64)


def istft(real, imag):
    """Vocos 'same' padding ISTFT — lib/myanmartts/inverse_stft.dart ၏ reference။"""
    frames = np.fft.irfft(real[0] + 1j * imag[0], n=N_FFT, axis=0)
    window = np.hanning(N_FFT + 1)[:-1]  # periodic Hann == torch.hann_window
    frames *= window[:, None]
    count = frames.shape[1]
    out_len = (count - 1) * HOP + N_FFT
    signal, envelope = np.zeros(out_len), np.zeros(out_len)
    for i in range(count):
        signal[i * HOP:i * HOP + N_FFT] += frames[:, i]
        envelope[i * HOP:i * HOP + N_FFT] += window ** 2
    pad = (N_FFT - HOP) // 2
    return (signal[pad:-pad] / envelope[pad:-pad]).astype(np.float32)


def magnitude_stft(waveform):
    """LinearSpectrogram (reflect pad 768 + STFT center=False + sqrt(|X|²+1e-6)) — lib/myanmartts/fft.dart ၏ reference။
    waveform: 44.1 kHz float [N] → [1, 1025, F]"""
    pad = (N_FFT - HOP) // 2
    padded = np.pad(waveform.astype(np.float64), (pad, pad), mode="reflect")
    window = np.hanning(N_FFT + 1)[:-1]
    count = 1 + (len(padded) - N_FFT) // HOP
    frames = np.stack([padded[i * HOP:i * HOP + N_FFT] * window for i in range(count)], axis=1)
    spectrum = np.fft.rfft(frames, n=N_FFT, axis=0)
    return np.sqrt(spectrum.real ** 2 + spectrum.imag ** 2 + 1e-6).astype(np.float32)[None]


def speaker_embedding(reference_session, waveform):
    """ဖုန်းနှင့် တစ်ထပ်တည်း — Dart magnitude STFT + reference.onnx။"""
    return reference_session.run(None, {"magnitude": magnitude_stft(waveform)})[0]


def load_wav_44k(path):
    """Reference clip ကို 44.1 kHz mono float သို့ ပြောင်းသည် (FLEURS သည် 16 kHz)။"""
    import soundfile as sf
    from scipy.signal import resample_poly
    data, rate = sf.read(path, dtype="float32", always_2d=True)
    mono = data.mean(axis=1)
    if rate != SAMPLE_RATE:
        from math import gcd
        divisor = gcd(rate, SAMPLE_RATE)
        mono = resample_poly(mono, SAMPLE_RATE // divisor, rate // divisor).astype(np.float32)
    return mono


def preset_speaker(presets_json, preset_id):
    """assets/voices/presets.json မှ preset အသံ၏ လက်ဗွေ [1, 256]။"""
    import json
    presets = json.load(open(presets_json, encoding="utf-8"))["presets"]
    embedding = next(item["embedding"] for item in presets if item["id"] == preset_id)
    return np.array([embedding], dtype=np.float32)


def load_sessions(onnx_dir, threads=4):
    import onnxruntime as ort
    options = ort.SessionOptions()
    options.intra_op_num_threads = threads
    return [ort.InferenceSession(f"{onnx_dir}/{name}.onnx", options, providers=["CPUExecutionProvider"])
            for name in MODEL_NAMES]


def encode(sessions, tokens, speaker):
    mu_x, logw = sessions[0].run(None, {"tokens": tokens, "speaker": speaker})
    return np.repeat(mu_x, np.ceil(np.exp(logw[0, 0])).astype(np.int64), axis=2)


def decode(sessions, mu_y, noise, steps, cfg, speaker):
    """App (onnx_myanmar_tts_models.dart) နှင့် တစ်ထပ်တည်း — estimator graph ထဲတွင် Euler step ပါသည်။"""
    _, prenet, estimator, vocos = sessions[:4]
    mu_proj = prenet.run(None, {"mu_y": mu_y})[0]
    x = noise.copy()
    dt = np.array([1.0 / steps], np.float32)
    cfg = np.array([cfg], np.float32)
    for k in range(steps):
        x = estimator.run(None, {"x": x, "mu_proj": mu_proj, "t": np.array([k / steps], np.float32),
                                 "dt": dt, "cfg": cfg, "speaker": speaker})[0]
    real, imag = vocos.run(None, {"mel": x})
    return x, istft(real, imag)
