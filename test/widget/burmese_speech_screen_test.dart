import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rnd_text_to_speech/main.dart';
import 'package:rnd_text_to_speech/providers/burmese_speech_controller.dart';

import '../support/fake_tts_service.dart';

const String _BURMESE_ENGINE = 'com.example.burmese.tts';

Future<void> _pumpApp(WidgetTester tester, {required FakeTtsService fake}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ttsServiceProvider.overrideWithValue(fake)],
      child: const RndTextToSpeechApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('speaks the sample Burmese text with the detected engine', (WidgetTester tester) async {
    final FakeTtsService fake = FakeTtsService(
      engines: <String>[_BURMESE_ENGINE],
      burmeseEngines: <String>{_BURMESE_ENGINE},
    );
    await _pumpApp(tester, fake: fake);

    expect(find.text(_BURMESE_ENGINE), findsOneWidget);
    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();

    expect(fake.spokenText, isNotEmpty);
  });

  testWidgets('shows install guidance and disables Speak when no engine supports Burmese',
      (WidgetTester tester) async {
    await _pumpApp(tester, fake: FakeTtsService(engines: <String>['com.google.android.tts']));

    expect(find.textContaining('my-MM'), findsOneWidget);
    expect(find.text('Check engines again'), findsOneWidget);
    final FilledButton speakButton =
        tester.widget<FilledButton>(find.ancestor(of: find.text('Speak'), matching: find.byType(FilledButton)));
    expect(speakButton.onPressed, isNull);
  });

  testWidgets('shows empty-text validation inline under the input', (WidgetTester tester) async {
    final FakeTtsService fake = FakeTtsService(
      engines: <String>[_BURMESE_ENGINE],
      burmeseEngines: <String>{_BURMESE_ENGINE},
    );
    await _pumpApp(tester, fake: fake);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Speak'));
    await tester.pumpAndSettle();

    expect(find.text('Enter some Burmese text first.'), findsOneWidget);
    expect(fake.spokenText, isNull);
  });
}
