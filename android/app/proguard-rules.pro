# ONNX Runtime ၏ Java class များကို native (JNI) ဘက်မှ အမည်ဖြင့် ခေါ်သဖြင့် R8 က ဖယ်ရှား/အမည်ပြောင်းပါက
# release build တွင်သာ crash ဖြစ်မည် — debug တွင် မတွေ့ရ၍ ကြိုတင် ကာကွယ်ထားသည်။
-keep class ai.onnxruntime.** { *; }
