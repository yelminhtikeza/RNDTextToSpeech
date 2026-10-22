import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/burmese_speech_screen.dart';

void main() {
  runApp(const ProviderScope(child: RndTextToSpeechApp()));
}

class RndTextToSpeechApp extends StatelessWidget {
  const RndTextToSpeechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BurmeseSpeechScreen(),
    );
  }
}
