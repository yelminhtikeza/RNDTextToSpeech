/// စာရှည်ကို model တစ်ကြိမ် run နိုင်သော အရှည်အထိ ခွဲသည်။
/// ဝါကျအဆုံး (။) နှင့် စာကြောင်းသစ်တွင် ဦးစွာ ခွဲပြီး၊ ရှည်နေသေးပါက ပုဒ်ဖြတ် (၊) သို့မဟုတ် space တွင် ခွဲသည်။
/// ထိုသို့ ခွဲ၍မရမှသာ စာလုံးအရေအတွက်ဖြင့် ဖြတ်သည် — ဝဏ္ဏအလယ်တွင် ဖြတ်မိခြင်းကို အတတ်နိုင်ဆုံး ရှောင်ရန်။
class TextChunker {
  const TextChunker({required this.maxCharacters});

  final int maxCharacters;

  static final RegExp _sentenceEnd = RegExp(r'(?<=[။\n])');
  static final RegExp _softBreak = RegExp(r'(?<=[၊ ])');

  List<String> split({required String text}) {
    final List<String> chunks = <String>[];
    for (final String sentence in text.split(_sentenceEnd)) {
      chunks.addAll(_splitLongSentence(sentence: sentence));
    }
    return chunks.map((String chunk) => chunk.trim()).where((String chunk) => chunk.isNotEmpty).toList();
  }

  List<String> _splitLongSentence({required String sentence}) {
    if (sentence.length <= maxCharacters) return <String>[sentence];

    final List<String> chunks = <String>[];
    final StringBuffer current = StringBuffer();
    for (final String piece in sentence.split(_softBreak)) {
      if (current.length + piece.length > maxCharacters && current.isNotEmpty) {
        chunks.add(current.toString());
        current.clear();
      }
      if (piece.length > maxCharacters) {
        chunks.addAll(_hardSplit(text: piece));
      } else {
        current.write(piece);
      }
    }
    if (current.isNotEmpty) chunks.add(current.toString());
    return chunks;
  }

  List<String> _hardSplit({required String text}) => <String>[
        for (int start = 0; start < text.length; start += maxCharacters)
          text.substring(start, (start + maxCharacters).clamp(0, text.length)),
      ];
}
