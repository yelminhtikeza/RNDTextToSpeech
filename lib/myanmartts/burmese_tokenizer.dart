import 'dart:typed_data';

import '../config/myanmartts_config.dart';

/// MyanmarTTS ၏ စာသား frontend (`myanmar_tts/text/burmese.py` + `symbols.py`) ကို Dart သို့ ပြောင်းထားခြင်း။
/// G2P မရှိပါ — စာလုံးတစ်လုံးချင်းကို vocabulary index သို့ တိုက်ရိုက်ပြောင်းသည်။
/// Python reference နှင့် ကိုက်ညီကြောင်းကို `test/fixtures/myanmartts_reference.json` ဖြင့် စစ်ထားသည်။
class BurmeseTokenizer {
  const BurmeseTokenizer();

  /// Model ၏ vocabulary — အစီအစဉ်သည် training နှင့် တူရမည်ဖြစ်၍ မပြောင်းရ။
  static final List<String> _vocabulary = <String>[
    '_',
    ...'0123456789'.split(''),
    ...'.,!?\'"-:;()'.split(''),
    ..._codePointRange(0x1000, 0x100D),
    ..._codePointRange(0x100F, 0x1021),
    ...'ဣဤဥဦဧဩဪ'.split(''),
    ...'ါာိီုူေဲံ့း္်ျြွှဿ'
        .split(''),
    ..._codePointRange(0x1040, 0x1049),
    ...'၊။၌၍၎၏'.split(''),
    'ၤ',
    ' ',
  ];

  static final Map<String, int> _symbolIds = <String, int>{
    for (int index = 0; index < _vocabulary.length; index++) _vocabulary[index]: index,
  };

  /// Cleaner က ထားခဲ့သော မြန်မာ Unicode အပိုင်းများ (Myanmar, Extended-A, Extended-B)။
  static const List<(int, int)> _BURMESE_RANGES = <(int, int)>[
    (0x1000, 0x109F),
    (0xAA60, 0xAA7F),
    (0xA9E0, 0xA9FF),
  ];

  static const String _ALLOWED_PUNCTUATION = '.,!?\'"-:;()၊။၌၍၎၏';
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _whitespaceCharacter = RegExp(r'[ \t\n\r]');

  static int get vocabularySize => _vocabulary.length;

  /// စာသားကို blank token ကြားညှပ်ထားသော token sequence အဖြစ် ပြောင်းသည်။
  /// ဖတ်စရာ စာလုံးမရှိပါက blank token တစ်ခုတည်းသာ ပြန်ပေးနိုင်သည် — [hasSpeakableText] ဖြင့် ကြိုစစ်ရန်။
  Int64List tokenize({required String text}) {
    final List<int> symbolIds = <int>[
      for (final String character in _clean(text: text).split(''))
        if (_symbolIds[character] case final int id) id,
    ];
    // Int64List သည် 0 ဖြင့် စတင်သဖြင့် blank token များကို ထပ်မရေးရ — ကြားညှပ်နေရာ (မ ကိန်း) တွင်သာ symbol ထည့်သည်။
    assert(MyanmarTtsConfig.BLANK_TOKEN == 0);
    final Int64List tokens = Int64List(symbolIds.length * 2 + 1);
    for (int index = 0; index < symbolIds.length; index++) {
      tokens[index * 2 + 1] = symbolIds[index];
    }
    return tokens;
  }

  /// ပုဒ်ဖြတ်နှင့် space သက်သက်သည် model ကို အသံမဲ့ သို့မဟုတ် ဆူညံသံသာ ထုတ်စေသဖြင့်
  /// vocabulary ထဲရှိ မြန်မာ စာလုံး/ဂဏန်း အနည်းဆုံး တစ်လုံး ပါမှသာ ဖတ်စရာ ရှိသည်ဟု သတ်မှတ်သည်။
  bool hasSpeakableText({required String text}) => _clean(text: text).split('').any(
        (String character) =>
            _symbolIds.containsKey(character) && character != ' ' && !_ALLOWED_PUNCTUATION.contains(character),
      );

  /// Python `clean_burmese` နှင့် တူညီသည် — မြန်မာစာ၊ space နှင့် ခွင့်ပြုထားသော သင်္ကေတများသာ ထားသည်။
  String _clean({required String text}) {
    final StringBuffer buffer = StringBuffer();
    for (final int codePoint in text.runes) {
      final String character = String.fromCharCode(codePoint);
      if (_whitespaceCharacter.hasMatch(character)) {
        buffer.write(' ');
      } else if (_isBurmese(codePoint: codePoint) || _ALLOWED_PUNCTUATION.contains(character)) {
        buffer.write(character);
      }
    }
    return buffer.toString().replaceAll(_whitespace, ' ').trim();
  }

  static bool _isBurmese({required int codePoint}) =>
      _BURMESE_RANGES.any(((int, int) range) => codePoint >= range.$1 && codePoint <= range.$2);

  static List<String> _codePointRange(int first, int last) =>
      <String>[for (int codePoint = first; codePoint <= last; codePoint++) String.fromCharCode(codePoint)];
}
