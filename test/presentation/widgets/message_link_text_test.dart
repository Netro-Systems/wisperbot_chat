import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/src/presentation/widgets/message_link_text.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final launched = <String>[];
  var succeeds = true;

  setUp(() {
    launched.clear();
    succeeds = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
        return succeeds;
      }
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pump(WidgetTester tester, String text) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MessageLinkText(text: text)),
        ),
      );

  List<TextSpan> spans(WidgetTester tester) => tester
      .widget<SelectableText>(find.byType(SelectableText))
      .textSpan!
      .children!
      .cast<TextSpan>();

  testWidgets('preserves text and opens each web link without punctuation',
      (tester) async {
    const text = 'See https://example.com/a_(b)?x=1&y=2, (www.example.org).';
    await pump(tester, text);
    final parts = spans(tester);
    expect(parts.map((span) => span.text).join(), text);
    final links = parts.where((span) => span.recognizer != null).toList();
    expect(links.length, 2);
    for (final link in links) {
      (link.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
    }
    expect(launched, [
      'https://example.com/a_(b)?x=1&y=2',
      'https://www.example.org',
    ]);
  });

  testWidgets('updates links and leaves plain text selectable', (tester) async {
    await pump(tester, 'https://example.com');
    await pump(tester, 'Plain text javascript:alert(1)');
    expect(spans(tester).where((span) => span.recognizer != null), isEmpty);
    expect(spans(tester).single.text, 'Plain text javascript:alert(1)');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows feedback when a link cannot open', (tester) async {
    succeeds = false;
    await pump(tester, 'http://example.com');
    final link = spans(tester).firstWhere((span) => span.recognizer != null);
    (link.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    expect(find.text('Could not open link.'), findsOneWidget);
  });
}
