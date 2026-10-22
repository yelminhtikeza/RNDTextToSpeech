"""MyanmarTTS (StableTTS + Vocos) ကို ဖုန်းပေါ်တွင် run ရန် ONNX graph လေးခုအဖြစ် export လုပ်သည်။

အသုံးပြုပုံ: python export_onnx.py <pkg_src_dir> <model_dir> <out_dir>

Graph များ (batch အမြဲ 1၊ padding မရှိ):
  encoder.onnx    tokens[1,T] int64, speaker[1,256]                               -> mu_x[1,128,T], logw[1,1,T]
  prenet.onnx     mu_y[1,128,L]                                                   -> mu_proj[2,256,L]  (cond, uncond)
  estimator.onnx  x[1,128,L], mu_proj[2,256,L], t[1], dt[1], cfg[1], speaker[1,256] -> x_next[1,128,L]
  vocos.onnx      mel[1,128,L]                                                    -> real[1,1025,L], imag[1,1025,L]
  reference.onnx  magnitude[1,1025,F] (44.1 kHz linear STFT)                      -> speaker[1,256]

ခွဲထားရခြင်း အကြောင်းရင်း (docs/adr/0002 တွင် အပြည့်):
- Length regulation (durations အတိုင်း ပွားခြင်း) သည် output အရှည် data ပေါ်မူတည်၍ Dart တွင် လုပ်သည်။
- prenet သည် step မပြောင်းသဖြင့် တစ်ကြိမ်သာ run သည် (decoder အလုပ်၏ ~25%)။
- estimator ထဲ Euler step ထည့်ထား၍ step loop တစ်လျှောက် tensor များ native ဘက်တွင်သာ ရှိသည်။
- ISTFT (irfft + fold) ကို ONNX သို့ ယုံကြည်စိတ်ချစွာ export မရ၍ Dart တွင် လုပ်သည်။
- Speaker embedding (အသံ "လက်ဗွေ") သည် encoder နှင့် estimator ၏ input ဖြစ်သဖြင့် အသံပြောင်းနိုင်သည် (ADR 0003)။
  Preset အသံများကို PC ပေါ်တွင် ကြိုတွက်ထားပြီး (voice_presets.py)၊ ဖုန်းဖြင့် အသံသွင်းပါက
  Dart က magnitude STFT တွက်ပြီး reference.onnx (mel filterbank + log + reference encoder) ဖြင့် တွက်သည်။
- torch.stft သည် complex output ဖြစ်၍ ONNX သို့ export မရ — DFT ကို conv weight ဖြင့် အစားထိုးပါက
  graph ~17 MB ကြီးမည်ဖြစ်၍ STFT ကို Dart (lib/myanmartts/fft.dart) တွင် လုပ်သည်။
"""
import sys

import torch
import torch.nn as nn

from common import use_package

pkg_dir, model_dir, out_dir = sys.argv[1:4]
use_package(pkg_dir)

from myanmar_tts.api import StableTTSAPI  # noqa: E402  (use_package ပြီးမှ import ရမည်)


class EncoderExport(nn.Module):
    def __init__(self, tts):
        super().__init__()
        self.encoder = tts.encoder
        self.dp = tts.dp

    def forward(self, tokens, speaker):
        lengths = torch.ones(1, dtype=torch.long) * tokens.shape[1]
        x, mu_x, x_mask = self.encoder(tokens, speaker, lengths)
        return mu_x, self.dp(x, x_mask, speaker)


class PrenetExport(nn.Module):
    def __init__(self, tts):
        super().__init__()
        self.cond_proj = tts.decoder.estimator.cond_proj
        self.fake_content = tts.fake_content

    def forward(self, mu_y):
        uncond = self.fake_content.expand(1, -1, mu_y.shape[2])
        return self.cond_proj(torch.cat([mu_y, uncond], dim=0))


class EstimatorExport(nn.Module):
    """CFG ပါသော Euler step တစ်ခု (CFMDecoder.cfg_wrapper + torchdiffeq euler နှင့် တူညီ)။"""

    def __init__(self, tts):
        super().__init__()
        self.est = tts.decoder.estimator
        self.fake_speaker = tts.fake_speaker

    def forward(self, x, mu_proj, t, dt, cfg, speaker):
        est = self.est
        speakers = torch.cat([speaker, self.fake_speaker], dim=0)
        x2 = torch.cat([x, x], dim=0)
        mask = torch.ones_like(x2[:, :1, :])
        temb = est.time_mlp(est.time_embeddings(t.expand(2)))
        h = est.in_proj(torch.cat((x2, mu_proj), dim=1))
        skips = []
        for idx, block in enumerate(est.blocks):
            if idx < est.n_lsc_layers:
                skips.append(h)
            else:
                h = est.lsc_layers[idx - est.n_lsc_layers](torch.cat((h, skips.pop()), dim=1))
            h = block(h, speakers, temb, mask)
        out = est.final_proj(h)
        cond, uncond = out[0:1], out[1:2]
        return x + dt * (uncond + cfg * (cond - uncond))


class VocosExport(nn.Module):
    def __init__(self, vocos):
        super().__init__()
        self.backbone = vocos.backbone
        self.out = vocos.head.out

    def forward(self, mel):
        h = self.out(self.backbone(mel)).transpose(1, 2)
        mag, phase = h.chunk(2, dim=1)
        mag = torch.clip(torch.exp(mag), max=1e2)
        return mag * torch.cos(phase), mag * torch.sin(phase)


class ReferenceExport(nn.Module):
    """Linear magnitude STFT → speaker embedding (LogMelSpectrogram ၏ mel/log အပိုင်း + MelStyleEncoder)။"""

    def __init__(self, api, tts):
        super().__init__()
        self.mel_scale = api.mel_extractor.mel_scale
        self.compress = api.mel_extractor.compress
        self.ref_encoder = tts.ref_encoder

    def forward(self, magnitude):
        enc = self.ref_encoder
        x = self.compress(self.mel_scale(magnitude)).transpose(1, 2)
        x = enc.spectral(x)
        x = enc.temporal(x.transpose(1, 2)).transpose(1, 2)
        x = enc.fc(self._self_attention(enc.slf_attn, x))
        return torch.mean(x, dim=1)  # temporal_avg_pool (mask မရှိ)

    @staticmethod
    def _self_attention(attn, x):
        # nn.MultiheadAttention ကို export တွင် sequence အရှည် (frame) ပုံသေ reshape အဖြစ် ချုပ်ထားမိသဖြင့်
        # in_proj/out_proj weight များဖြင့် ကိုယ်တိုင်ရေးထားသည် — သင်္ချာ တူညီ (verify_onnx.py ဖြင့် စစ်)။
        heads = attn.num_heads
        head_dim = attn.embed_dim // heads
        q, k, v = torch.nn.functional.linear(x, attn.in_proj_weight, attn.in_proj_bias).chunk(3, dim=-1)
        split = lambda t: t.reshape(t.shape[0], -1, heads, head_dim).transpose(1, 2)  # noqa: E731
        out = torch.nn.functional.scaled_dot_product_attention(split(q), split(k), split(v))
        out = out.transpose(1, 2).reshape(x.shape[0], -1, attn.embed_dim)
        return attn.out_proj(out)


def export(module, args, path, input_names, output_names, dynamic_axes):
    # dynamo=False — TorchScript exporter သည် RoPE ၏ dynamic sequence length ကို ပြဿနာမရှိ trace လုပ်သည်။
    torch.onnx.export(module, args, path, input_names=input_names, output_names=output_names,
                      dynamic_axes=dynamic_axes, opset_version=17, dynamo=False)
    print("exported", path)


def main():
    api = StableTTSAPI(f"{model_dir}/model_fp32.pt", f"{model_dir}/vocos.pt", "vocos").eval()
    tts = api.tts_model
    speaker = torch.randn(1, 256)  # trace အတွက်သာ — input ဖြစ်၍ ပုံသေမထည့်ပါ

    tokens_len, frames = 23, 120  # trace အတွက် နမူနာ အရှည် — dynamic axes ဖြစ်၍ ရလဒ်ကို မကန့်သတ်ပါ
    # nn.MultiheadAttention ၏ eval fast path (_native_multi_head_attention) ကို ONNX မသိ — သင်္ချာတူ ပုံမှန် op များဖြင့် trace စေရန်။
    torch.backends.mha.set_fastpath_enabled(False)
    with torch.no_grad():
        export(EncoderExport(tts).eval(), (torch.randint(1, 97, (1, tokens_len)), speaker),
               f"{out_dir}/encoder.onnx", ["tokens", "speaker"], ["mu_x", "logw"],
               {"tokens": {1: "T"}, "mu_x": {2: "T"}, "logw": {2: "T"}})
        export(PrenetExport(tts).eval(), (torch.randn(1, 128, frames),), f"{out_dir}/prenet.onnx",
               ["mu_y"], ["mu_proj"], {"mu_y": {2: "L"}, "mu_proj": {2: "L"}})
        export(EstimatorExport(tts).eval(),
               (torch.randn(1, 128, frames), torch.randn(2, 256, frames), torch.tensor([0.5]),
                torch.tensor([0.0625]), torch.tensor([3.0]), speaker),
               f"{out_dir}/estimator.onnx", ["x", "mu_proj", "t", "dt", "cfg", "speaker"], ["x_next"],
               {"x": {2: "L"}, "mu_proj": {2: "L"}, "x_next": {2: "L"}})
        export(VocosExport(api.vocoder_model).eval(), (torch.randn(1, 128, frames),), f"{out_dir}/vocos.onnx",
               ["mel"], ["real", "imag"], {"mel": {2: "L"}, "real": {2: "L"}, "imag": {2: "L"}})
        export(ReferenceExport(api, tts).eval(), (torch.rand(1, 1025, 400),), f"{out_dir}/reference.onnx",
               ["magnitude"], ["speaker"], {"magnitude": {2: "F"}})


if __name__ == "__main__":
    main()
