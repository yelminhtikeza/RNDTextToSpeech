"""Reference clip များမှ preset အသံ "လက်ဗွေ" (speaker embedding) ကို ဖုန်းနှင့် တစ်ထပ်တည်းသော နည်းဖြင့် တွက်သည်။

အသုံးပြုပုံ:
  python voice_presets.py candidates <pkg_src_dir> <onnx_dir> <clips_dir> <out_dir> <per_gender>
      clip အားလုံး၏ embedding တွက်ပြီး အချင်းချင်း အဝေးဆုံး (အသံမတူဆုံး) ဖြစ်အောင် ကျားမ တစ်ဖက်စီ <per_gender> ခု ရွေးကာ
      စာကြောင်းတူ ဖတ်ထားသော WAV နှင့် candidates.json ထုတ်သည် — နားထောင်ပြီး ရွေးရန်။
  python voice_presets.py add <onnx_dir> <candidates_json> <id> <wav> <source>
      Clip တစ်ခု (ဥပမာ မူလ sample_0.wav) ၏ လက်ဗွေကို candidates.json ထဲ ထပ်ထည့်သည်။
  python voice_presets.py build <candidates_json> <out_json> <id>=<label_en>|<label_my> ...
      ရွေးထားသော candidate များကို app asset (assets/voices/presets.json) အဖြစ် ထုတ်သည်။
      ပထမဆုံး id သည် app ၏ ပုံသေ အသံ ဖြစ်သည်။
"""
import json
import sys

import numpy as np
import soundfile as sf

from common import SAMPLE_RATE, SAMPLE_TEXT, decode, encode, load_sessions, load_wav_44k, speaker_embedding, tokenize

STEPS, CFG, NOISE_SEED = 16, 3.0, 0


def _farthest_first(embeddings, count):
    """Cosine distance အရ တစ်ခုနှင့်တစ်ခု အဝေးဆုံးကို အစဉ်လိုက် ရွေးသည် — FLEURS တွင် speaker ID မပါ၍
    clip အများအပြားသည် တူညီသော speaker ဖြစ်နိုင်သောကြောင့်။"""
    unit = embeddings / np.linalg.norm(embeddings, axis=1, keepdims=True)
    chosen = [int(np.argmax(np.linalg.norm(unit - unit.mean(0), axis=1)))]
    while len(chosen) < min(count, len(unit)):
        distance = 1 - unit @ unit[chosen].T
        chosen.append(int(np.argmax(distance.min(axis=1))))
    return chosen


def candidates(pkg_dir, onnx_dir, clips_dir, out_dir, per_gender):
    from common import use_package
    use_package(pkg_dir)
    sessions = load_sessions(onnx_dir)
    rows = [line.rstrip("\n").split("\t") for line in open(f"{clips_dir}/manifest.tsv", encoding="utf-8")]
    tokens = tokenize(SAMPLE_TEXT)
    results = []
    for gender in ("MALE", "FEMALE"):
        group = [row for row in rows if row[2] == gender]
        embeddings = np.concatenate([speaker_embedding(sessions[4], load_wav_44k(f"{clips_dir}/{row[0]}")) for row in group])
        for rank, index in enumerate(_farthest_first(embeddings, per_gender)):
            row, speaker = group[index], embeddings[index:index + 1]
            mu_y = encode(sessions, tokens, speaker)
            noise = np.random.default_rng(NOISE_SEED).standard_normal(mu_y.shape).astype(np.float32)
            _, audio = decode(sessions, mu_y, noise, STEPS, CFG, speaker)
            candidate_id = f"{gender.lower()}_{rank + 1}"
            sf.write(f"{out_dir}/{candidate_id}.wav", audio, SAMPLE_RATE)
            results.append({"id": candidate_id, "gender": gender.lower(), "fleurs_file": row[1],
                            "source": f"Google FLEURS my_mm train/{row[1]} (CC BY 4.0)",
                            "embedding": [round(float(v), 6) for v in speaker[0]]})
            print("rendered", candidate_id, "from", row[1])
    with open(f"{out_dir}/candidates.json", "w") as out:
        json.dump(results, out)


def add(onnx_dir, candidates_json, candidate_id, wav_path, source):
    sessions = load_sessions(onnx_dir)
    speaker = speaker_embedding(sessions[4], load_wav_44k(wav_path))
    items = [item for item in json.load(open(candidates_json)) if item["id"] != candidate_id]
    items.insert(0, {"id": candidate_id, "source": source, "embedding": [round(float(v), 6) for v in speaker[0]]})
    with open(candidates_json, "w") as out:
        json.dump(items, out)
    print("added", candidate_id)


def build(candidates_json, out_json, selections):
    by_id = {item["id"]: item for item in json.load(open(candidates_json))}
    presets = []
    for selection in selections:
        candidate_id, labels = selection.split("=", 1)
        label_en, label_my = labels.split("|", 1)
        item = by_id[candidate_id]
        presets.append({"id": candidate_id, "label_en": label_en, "label_my": label_my,
                        "source": item["source"], "embedding": item["embedding"]})
    with open(out_json, "w") as out:
        json.dump({"presets": presets}, out, ensure_ascii=False, indent=1)
    print("wrote", len(presets), "presets to", out_json)


if __name__ == "__main__":
    if sys.argv[1] == "candidates":
        candidates(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6]))
    elif sys.argv[1] == "add":
        add(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
    else:
        build(sys.argv[2], sys.argv[3], sys.argv[4:])
