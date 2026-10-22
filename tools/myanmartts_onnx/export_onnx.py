"""MyanmarTTS (StableTTS + Vocos) ကို ဖုန်းပေါ်တွင် run ရန် ONNX graph လေးခုအဖြစ် export လုပ်သည်။

အသုံးပြုပုံ: python export_onnx.py <pkg_src_dir> <model_dir> <out_dir>

Graph များ (batch အမြဲ 1၊ padding မရှိ):
  encoder.onnx    tokens[1,T] int64                                   -> mu_x[1,128,T], logw[1,1,T]
  prenet.onnx     mu_y[1,128,L]                                       -> mu_proj[2,256,L]  (cond, uncond)
  estimator.onnx  x[1,128,L], mu_proj[2,256,L], t[1], dt[1], cfg[1]   -> x_next[1,128,L]
  vocos.onnx      mel[1,128,L]                                        -> real[1,1025,L], imag[1,1025,L]

ခွဲထားရခြင်း အကြောင်းရင်း (docs/adr/0002 တွင် အပြည့်):
- Length regulation (durations အတိုင်း ပွားခြင်း) သည် output အရှည် data ပေါ်မူတည်၍ Dart တွင် လုပ်သည်။
- prenet သည် step မပြောင်းသဖြင့် တစ်ကြိမ်သာ run သည် (decoder အလုပ်၏ ~25%)။
- estimator ထဲ Euler step ထည့်ထား၍ step loop တစ်လျှောက် tensor များ native ဘက်တွင်သာ ရှိသည်။
- ISTFT (irfft + fold) ကို ONNX သို့ ယုံကြည်စိတ်ချစွာ export မရ၍ Dart တွင် လုပ်သည်။
- Reference အသံ (samples/sample_0.wav) ၏ speaker embedding ကို encoder နှင့် estimator ထဲ ပုံသေထည့်ထားသဖြင့်
  ဖုန်းပေါ်တွင် reference encoder နှင့် mel extraction မလိုပါ။
"""
import sys

import torch
import torch.nn as nn

from common import use_package

pkg_dir, model_dir, out_dir = sys.argv[1:4]
load_and_resample_audio = use_package(pkg_dir)

from myanmar_tts.api import StableTTSAPI  # noqa: E402  (use_package ပြီးမှ import ရမည်)


class EncoderExport(nn.Module):
    def __init__(self, tts, speaker):
        super().__init__()
        self.encoder = tts.encoder
        self.dp = tts.dp
        self.register_buffer("speaker", speaker)

    def forward(self, tokens):
        lengths = torch.ones(1, dtype=torch.long) * tokens.shape[1]
        x, mu_x, x_mask = self.encoder(tokens, self.speaker, lengths)
        return mu_x, self.dp(x, x_mask, self.speaker)


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

    def __init__(self, tts, speaker):
        super().__init__()
        self.est = tts.decoder.estimator
        self.register_buffer("speakers", torch.cat([speaker, tts.fake_speaker.detach()], dim=0))

    def forward(self, x, mu_proj, t, dt, cfg):
        est = self.est
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
            h = block(h, self.speakers, temb, mask)
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


def export(module, args, path, input_names, output_names, dynamic_axes):
    # dynamo=False — TorchScript exporter သည် RoPE ၏ dynamic sequence length ကို ပြဿနာမရှိ trace လုပ်သည်။
    torch.onnx.export(module, args, path, input_names=input_names, output_names=output_names,
                      dynamic_axes=dynamic_axes, opset_version=17, dynamo=False)
    print("exported", path)


def main():
    api = StableTTSAPI(f"{model_dir}/model_fp32.pt", f"{model_dir}/vocos.pt", "vocos").eval()
    tts = api.tts_model
    with torch.inference_mode():
        ref = api.mel_extractor(load_and_resample_audio(f"{model_dir}/samples/sample_0.wav", 44100))
        speaker = tts.ref_encoder(ref, None).clone()

    tokens_len, frames = 23, 120  # trace အတွက် နမူနာ အရှည် — dynamic axes ဖြစ်၍ ရလဒ်ကို မကန့်သတ်ပါ
    with torch.no_grad():
        export(EncoderExport(tts, speaker).eval(), (torch.randint(1, 97, (1, tokens_len)),),
               f"{out_dir}/encoder.onnx", ["tokens"], ["mu_x", "logw"],
               {"tokens": {1: "T"}, "mu_x": {2: "T"}, "logw": {2: "T"}})
        export(PrenetExport(tts).eval(), (torch.randn(1, 128, frames),), f"{out_dir}/prenet.onnx",
               ["mu_y"], ["mu_proj"], {"mu_y": {2: "L"}, "mu_proj": {2: "L"}})
        export(EstimatorExport(tts, speaker).eval(),
               (torch.randn(1, 128, frames), torch.randn(2, 256, frames), torch.tensor([0.5]),
                torch.tensor([0.0625]), torch.tensor([3.0])),
               f"{out_dir}/estimator.onnx", ["x", "mu_proj", "t", "dt", "cfg"], ["x_next"],
               {"x": {2: "L"}, "mu_proj": {2: "L"}, "x_next": {2: "L"}})
        export(VocosExport(api.vocoder_model).eval(), (torch.randn(1, 128, frames),), f"{out_dir}/vocos.onnx",
               ["mel"], ["real", "imag"], {"mel": {2: "L"}, "real": {2: "L"}, "imag": {2: "L"}})


if __name__ == "__main__":
    main()
