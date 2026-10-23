import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Amplitude bar များကို အလယ်မျဉ်းမှ အပေါ်/အောက် ညီညီ ဆွဲသော waveform။
/// [progress] ပေးပါက ဖွင့်ပြီးသော အပိုင်းနှင့် မဖွင့်ရသေးသော အပိုင်းကို အရောင်ခွဲပြပြီး playhead ဆွဲသည်။
/// [onSeek] ပေးပါက နှိပ်/ဘေးတိုက်ဆွဲ၍ ထိုနေရာ (0–1) သို့ ရွှေ့နိုင်သည်။
/// အရောင်ကို theme ၏ color scheme မှသာ ယူသည် (designer palette ပြောင်းလျှင် လိုက်ပြောင်းရန်)။
class WaveformView extends StatefulWidget {
  const WaveformView({super.key, required this.peaks, this.progress, this.onSeek});

  /// 0.0–1.0 ရှိ bar အမြင့်များ။
  final List<double> peaks;

  /// 0.0–1.0 — null ဆိုလျှင် မဖွင့်နေ၍ bar အားလုံးကို တစ်ရောင်တည်း ဆွဲသည်။
  final double? progress;

  /// null ဆိုလျှင် seek မရ။
  final ValueChanged<double>? onSeek;

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

/// ဆွဲနေစဉ် လက်ရှိနေရာကို ချက်ချင်း ပြရန်သာ setState သုံးသည် — ဆွဲပြီးမှ တစ်ကြိမ်သာ seek လုပ်၍ player ကို
/// frame တိုင်း မခေါ်မိစေရန်ဖြစ်ပြီး widget နှင့်အတူ ပျောက်သွားသော UI state သက်သက် ဖြစ်သည်။
class _WaveformViewState extends State<WaveformView> {
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final ValueChanged<double>? onSeek = widget.onSeek;
    final Widget waveform = SizedBox(
      height: AppTheme.WAVEFORM_HEIGHT,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          peaks: widget.peaks,
          progress: _dragFraction ?? widget.progress,
          playedColor: colors.primary,
          unplayedColor: colors.outline,
          baselineColor: colors.outlineVariant,
        ),
      ),
    );
    if (onSeek == null) return waveform;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double fractionAt(Offset position) => (position.dx / constraints.maxWidth).clamp(0.0, 1.0);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails details) => onSeek(fractionAt(details.localPosition)),
            onHorizontalDragStart: (DragStartDetails details) =>
                setState(() => _dragFraction = fractionAt(details.localPosition)),
            onHorizontalDragUpdate: (DragUpdateDetails details) =>
                setState(() => _dragFraction = fractionAt(details.localPosition)),
            onHorizontalDragEnd: (_) {
              final double? fraction = _dragFraction;
              setState(() => _dragFraction = null);
              if (fraction != null) onSeek(fraction);
            },
            onHorizontalDragCancel: () => setState(() => _dragFraction = null),
            child: waveform,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.baselineColor,
  });

  /// Bar ကြားတွင် ချန်ထားမည့် အကျယ်အချိုး — bar များ ကပ်မနေစေရန်။
  static const double _GAP_RATIO = 0.3;

  /// အသံတိတ်ချိန်တွင်ပင် bar မြင်ရစေရန် အနိမ့်ဆုံးအမြင့်။
  static const double _MIN_BAR_HEIGHT = 1;

  static const double _PLAYHEAD_WIDTH = 2;

  final List<double> peaks;
  final double? progress;
  final Color playedColor;
  final Color unplayedColor;
  final Color baselineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), Paint()..color = baselineColor);
    if (peaks.isEmpty) return;

    final double? progress = this.progress;
    final double playheadX = (progress ?? 0) * size.width;
    final double slot = size.width / peaks.length;
    final Paint barPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = slot * (1 - _GAP_RATIO);
    for (int index = 0; index < peaks.length; index++) {
      final double halfHeight = (peaks[index].clamp(0.0, 1.0) * size.height / 2).clamp(_MIN_BAR_HEIGHT, centerY);
      final double x = slot * index + slot / 2;
      barPaint.color = progress == null || x <= playheadX ? playedColor : unplayedColor;
      canvas.drawLine(Offset(x, centerY - halfHeight), Offset(x, centerY + halfHeight), barPaint);
    }
    if (progress != null) {
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        Paint()
          ..color = playedColor
          ..strokeWidth = _PLAYHEAD_WIDTH,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      !identical(oldDelegate.peaks, peaks) ||
      oldDelegate.progress != progress ||
      oldDelegate.playedColor != playedColor ||
      oldDelegate.unplayedColor != unplayedColor ||
      oldDelegate.baselineColor != baselineColor;
}
