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

  Future<void> pump(
    WidgetTester tester,
    String text, {
    Color linkColor = Colors.blue,
    TextStyle? style,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body:
                MessageLinkText(text: text, linkColor: linkColor, style: style),
          ),
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
      expect(link.style?.color, Colors.blue);
      (link.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
    }
    expect(launched, [
      'https://example.com/a_(b)?x=1&y=2',
      'https://www.example.org',
    ]);
  });

  testWidgets('renders a Markdown link as its tappable label', (tester) async {
    const text =
        'Call us or [contact us on WhatsApp](https://wa.me/message/BHA3NTMHBCD5O1).';
    await pump(tester, text, style: const TextStyle(fontSize: 14));
    final parts = spans(tester);
    expect(
      parts.map((span) => span.text).join(),
      'Call us or contact us on WhatsApp.',
    );
    final link = parts.singleWhere((span) => span.recognizer != null);
    expect(link.text, 'contact us on WhatsApp');
    expect(link.style?.color, Colors.blue);
    expect(link.style?.fontSize, 15);
    expect(link.style?.fontWeight, FontWeight.w700);
    expect(link.style?.decoration, TextDecoration.underline);
    (link.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();
    expect(launched, ['https://wa.me/message/BHA3NTMHBCD5O1']);
  });

  testWidgets('keeps unsupported Markdown destinations as plain text',
      (tester) async {
    const text = '[Open this](javascript:alert(1))';
    await pump(tester, text);
    expect(spans(tester).where((span) => span.recognizer != null), isEmpty);
    expect(spans(tester).map((span) => span.text).join(), text);
  });

  testWidgets('updates links and leaves plain text selectable', (tester) async {
    await pump(tester, 'https://example.com');
    await pump(tester, 'https://example.com',
        linkColor: Colors.lightBlueAccent);
    final link = spans(tester).singleWhere((span) => span.recognizer != null);
    expect(link.style?.color, Colors.lightBlueAccent);
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
