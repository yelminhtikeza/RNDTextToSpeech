import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Amplitude bar များကို အလယ်မျဉ်းမှ အပေါ်/အောက် ညီညီ ဆွဲသော waveform။
/// အရောင်ကို theme ၏ color scheme မှသာ ယူသည် (designer palette ပြောင်းလျှင် လိုက်ပြောင်းရန်)။
class WaveformView extends StatelessWidget {
  const WaveformView({super.key, required this.peaks});

  /// 0.0–1.0 ရှိ bar အမြင့်များ။
  final List<double> peaks;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppTheme.WAVEFORM_HEIGHT,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(peaks: peaks, barColor: colors.primary, baselineColor: colors.outlineVariant),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.peaks, required this.barColor, required this.baselineColor});

  /// Bar ကြားတွင် ချန်ထားမည့် အကျယ်အချိုး — bar များ ကပ်မနေစေရန်။
  static const double _GAP_RATIO = 0.3;

  /// အသံတိတ်ချိန်တွင်ပင် bar မြင်ရစေရန် အနိမ့်ဆုံးအမြင့်။
  static const double _MIN_BAR_HEIGHT = 1;

  final List<double> peaks;
  final Color barColor;
  final Color baselineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), Paint()..color = baselineColor);
    if (peaks.isEmpty) return;

    final double slot = size.width / peaks.length;
    final Paint barPaint = Paint()
      ..color = barColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = slot * (1 - _GAP_RATIO);
    for (int index = 0; index < peaks.length; index++) {
      final double halfHeight = (peaks[index].clamp(0.0, 1.0) * size.height / 2).clamp(_MIN_BAR_HEIGHT, centerY);
      final double x = slot * index + slot / 2;
      canvas.drawLine(Offset(x, centerY - halfHeight), Offset(x, centerY + halfHeight), barPaint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      !identical(oldDelegate.peaks, peaks) || oldDelegate.barColor != barColor || oldDelegate.baselineColor != baselineColor;
}
