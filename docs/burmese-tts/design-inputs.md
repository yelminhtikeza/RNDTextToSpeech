# Design Inputs — မြန်မာ စာမှ အသံ (Android)

ISO 9001:2015 အပိုဒ် 8.3.3 အရ ဤ feature က ဖြည့်ဆည်းရမည့် လိုအပ်ချက်များကို မှတ်တမ်းတင်ထားခြင်း။

## 1. Functional / performance requirements

- Android စက်ပေါ်တွင် အသုံးပြုသူ ရိုက်ထည့်သော မြန်မာစာ (Unicode) ကို အသံထွက်ဖတ်ပြရမည်။
- စက်တွင် ထည့်ထားသော TTS engine အားလုံးကို စစ်ပြီး `my-MM` ပံ့ပိုးသော engine ကိုသာ ရွေးခွင့်ပေးရမည်။
- မြန်မာ engine မရှိပါက ဖတ်ရန်ခလုတ်ကို ပိတ်ထားပြီး engine ထည့်သွင်းနည်းကို ပြရမည်။
- အမြန်နှုန်းနှင့် အသံအနိမ့်အမြင့်ကို ချိန်ညှိနိုင်ရမည်၊ ဖတ်နေစဉ် ရပ်နိုင်ရမည်။
- Engine ၏ input အရှည်ကန့်သတ်ချက် (Android ပုံသေ 4000 လုံး) ထက် ရှည်သော စာကို engine သို့ မပို့မီ ငြင်းရမည်။
- ⚠️ DETERMINATION REQUIRED — Engine ရှာဖွေချိန် (engine တစ်ခုစီ initialize လုပ်ရသည်) အတွက် လက်ခံနိုင်သော အချိန်ကန့်သတ်ချက် မသတ်မှတ်ရသေးပါ။

## 2. Information from previous similar designs

- **Not applicable** — ဤ repository ၏ ပထမဆုံး feature ဖြစ်ပြီး ယခင် TTS ဒီဇိုင်း မရှိပါ။
- ပြင်ပ ရည်ညွှန်းချက်: `flutter_tts` 4.2.5 ၏ Android source ကို ဖတ်ပြီး အောက်ပါအချက်များကို အတည်ပြုထားသည် —
  `setEngine` သည် engine initialize ပြီးမှ ပြန်လာသည်၊ `stop` သည် ဆိုင်းငံ့နေသော `speak` ကို `0` ဖြင့် ပြီးစေသည်၊
  speech rate `0.5` သည် Android ၏ ပုံမှန်နှုန်း `1.0` နှင့် ညီသည်။

## 3. Statutory / regulatory requirements

- ⚠️ DETERMINATION REQUIRED — App ကို ထုတ်ဝေမည့် ဈေးကွက်/ဥပဒေ (ဥပမာ accessibility ဥပဒေ) မသတ်မှတ်ရသေးပါ။
- စာသားကို စက်ပေါ်ရှိ engine သို့သာ ပို့သည်။ App ကိုယ်တိုင် network သို့ မပို့ပါ။ သို့သော် engine အချို့
  (network voice) က စာသားကို ၎င်းတို့ server သို့ ပို့နိုင်သည် — privacy ဆိုင်ရာ ဆုံးဖြတ်ချက် လိုအပ်နိုင်သည်။

## 4. Standards committed to

- ISO 9001:2015 (အဖွဲ့အစည်း coding standard အတိုင်း)။
- Burmese စာကို Unicode (U+1000–U+109F) အဖြစ်သာ လက်ခံသည်။ Zawgyi encoding ကို မပံ့ပိုးပါ။
- Android 11+ package visibility — `AndroidManifest.xml` တွင် `TTS_SERVICE` query ကြေညာထားသည်။

## 5. Potential consequences of failure

- မြန်မာ engine မရှိသည်ကို မစစ်ပါက default engine (များသောအားဖြင့် Google TTS) က မြန်မာစာကို
  အင်္ဂလိပ်အသံဖြင့် မှားဖတ်ခြင်း သို့မဟုတ် အသံမထွက်ခြင်း ဖြစ်ပြီး အသုံးပြုသူက app ပျက်နေသည်ဟု ယူဆမည်။
- Zawgyi ဖြင့် ရိုက်ထားသော စာကို Unicode engine က ဖတ်ပါက အဓိပ္ပါယ်မရှိသော အသံ ထွက်မည် —
  အမှား message မပေါ်ဘဲ ဖြစ်သဖြင့် အသုံးပြုသူ မသိနိုင်ပါ။
- အသုံးပြုသူကိုယ်တိုင် ရပ်ခြင်းကို အမှားအဖြစ် ပြပါက ယုံကြည်မှု ကျဆင်းပြီး မှားယွင်းသော bug report များ ဝင်လာမည်။
- Input အရှည်ကို မစစ်ပါက engine က အသံမထွက်ဘဲ ငြိမ်နေမည်။
