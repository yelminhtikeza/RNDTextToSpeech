import 'package:flutter/material.dart';

/// Designer palette မရသေးသဖြင့် Material 3 seed တစ်ခုတည်းမှ အရောင်အားလုံးကို ထုတ်ယူသည်။
/// Palette ရလာပါက ဤဖိုင်တစ်ခုတည်းကိုသာ ပြင်ရန်။
abstract final class AppTheme {
  static const Color SEED_COLOR = Colors.teal;
  static const double SPACING = 16;
  static const double LOADER_SIZE = 18;
  static const double LOADER_STROKE = 2;
  static const double SLIDER_VALUE_WIDTH = 40;
  static const double WAVEFORM_HEIGHT = 64;

  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: SEED_COLOR),
      );

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: SEED_COLOR, brightness: Brightness.dark),
      );
}
