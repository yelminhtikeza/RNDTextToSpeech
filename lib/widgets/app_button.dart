import 'package:flutter/material.dart';

import '../config/app_theme.dart';

enum AppButtonVariant { filled, outlined }

/// App တစ်ခုလုံးတွင် သုံးမည့် button — async လုပ်ဆောင်နေစဉ် loading ပြပြီး
/// ထပ်နှိပ်ခြင်းကို တားသည်။ Cursor ကို Material button များက pointer အဖြစ် ပုံသေထားပြီးဖြစ်သည်။
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
  });

  final String label;
  final IconData icon;

  /// null ဖြစ်လျှင် disabled။
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final Widget leading = isLoading
        ? const SizedBox.square(
            dimension: AppTheme.LOADER_SIZE,
            child: CircularProgressIndicator(strokeWidth: AppTheme.LOADER_STROKE),
          )
        : Icon(icon);
    final VoidCallback? effectiveOnPressed = isLoading ? null : onPressed;

    return switch (variant) {
      AppButtonVariant.filled =>
        FilledButton.icon(onPressed: effectiveOnPressed, icon: leading, label: Text(label)),
      AppButtonVariant.outlined =>
        OutlinedButton.icon(onPressed: effectiveOnPressed, icon: leading, label: Text(label)),
    };
  }
}
