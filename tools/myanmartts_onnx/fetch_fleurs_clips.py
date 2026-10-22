"""Google FLEURS (CC BY 4.0) မြန်မာ split မှ preset voice အတွက် reference clip အနည်းငယ်ကို ယူသည်။

အသုံးပြုပုံ: python fetch_fleurs_clips.py <out_dir> <male_count> <female_count>

Train archive (2.1 GB) တစ်ခုလုံးကို မဒေါင်းဘဲ stream ဖတ်ပြီး လိုသလောက် ရသည်နှင့် ရပ်သည်။
FLEURS တွင် speaker ID မပါ၍ အသံမတူသော speaker များကို နားထောင်ပြီး ရွေးရမည် (render_voices.py)။
"""
import csv
import sys
import tarfile
import urllib.request

BASE = "https://huggingface.co/datasets/google/fleurs/resolve/main/data/my_mm"
# 7–12 စက္ကန့် (16 kHz) — reference encoder အတွက် လုံလောက်ပြီး ဝါကျတစ်ကြောင်းအတွင်း
MIN_SAMPLES, MAX_SAMPLES = 7 * 16000, 12 * 16000
GENDER_COLUMN, SAMPLES_COLUMN, FILE_COLUMN, TEXT_COLUMN = 6, 5, 1, 2

out_dir, male_count, female_count = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
wanted = {"MALE": male_count, "FEMALE": female_count}

rows = {}
with urllib.request.urlopen(f"{BASE}/train.tsv") as response:
    for row in csv.reader(response.read().decode("utf-8").splitlines(), delimiter="\t", quoting=csv.QUOTE_NONE):
        if MIN_SAMPLES <= int(row[SAMPLES_COLUMN]) <= MAX_SAMPLES:
            rows[row[FILE_COLUMN]] = (row[GENDER_COLUMN], row[TEXT_COLUMN])

saved = {"MALE": 0, "FEMALE": 0}
manifest = []
with urllib.request.urlopen(f"{BASE}/audio/train.tar.gz") as response:
    with tarfile.open(fileobj=response, mode="r|gz") as archive:
        for member in archive:
            name = member.name.rsplit("/", 1)[-1]
            if name not in rows:
                continue
            gender, text = rows[name]
            if saved[gender] >= wanted[gender]:
                continue
            target = f"{out_dir}/{gender.lower()}_{saved[gender]:02d}.wav"
            with open(target, "wb") as out:
                out.write(archive.extractfile(member).read())
            saved[gender] += 1
            manifest.append({"file": target.rsplit("/", 1)[-1], "fleurs_file": name, "gender": gender, "text": text})
            if saved == wanted:
                break

with open(f"{out_dir}/manifest.tsv", "w") as out:
    for item in manifest:
        out.write(f"{item['file']}\t{item['fleurs_file']}\t{item['gender']}\t{item['text']}\n")
print("saved", saved)
