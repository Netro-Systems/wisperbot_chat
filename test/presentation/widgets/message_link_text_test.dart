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
    TextStyle? style,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MessageLinkText(text: text, style: style)),
        ),
      );

  Finder button(String label) => find.widgetWithText(OutlinedButton, label);

  testWidgets('opens each web link button without trailing punctuation',
      (tester) async {
    const text =
        'See https://example.com/a_(b)?x=1&y=2, (www.example.org/a%FF).';
    await pump(tester, text);
    expect(button('See more'), findsNWidgets(2));
    expect(
        find.text('See \uFFFC, (\uFFFC).', findRichText: true), findsOneWidget);
    await tester.tap(button('See more').first);
    await tester.tap(button('See more').last);
    await tester.pump();
    expect(launched, [
      'https://example.com/a_(b)?x=1&y=2',
      'https://www.example.org/a%FF',
    ]);
  });

  testWidgets('keeps the Markdown caption and opens a WhatsApp link',
      (tester) async {
    const text =
        'Call us or [contact us on WhatsApp](https://wa.me/message/BHA3NTMHBCD5O1).';
    await pump(tester, text, style: const TextStyle(fontSize: 14));
    expect(
      find.text('Call us or contact us on WhatsApp \uFFFC.',
          findRichText: true),
      findsOneWidget,
    );
    await tester.tap(button('Call now'));
    await tester.pump();
    expect(launched, ['https://wa.me/message/BHA3NTMHBCD5O1']);
  });

  testWidgets('opens a package button with the original query parameters',
      (tester) async {
    const url = 'https://www.telzen.net/packages/plan-id';
    await pump(
      tester,
      '[$url?countryname=Dominica&plan_type=esim]'
      r'(https://www.telzen.net/packages/plan-id?countryname=Dominica\&plan_type=esim)',
    );
    expect(find.text('\uFFFC', findRichText: true), findsOneWidget);
    await tester.tap(button('See package'));
    await tester.pump();
    expect(launched, ['$url?countryname=Dominica&plan_type=esim']);
  });

  testWidgets('recognizes WhatsApp hostnames without matching lookalikes',
      (tester) async {
    await pump(
      tester,
      'https://api.whatsapp.com/send?phone=1234567890 '
      'https://wa.me.example.com/packages-guide',
    );
    expect(button('Call now'), findsOneWidget);
    expect(button('See more'), findsOneWidget);
  });

  testWidgets('keeps unsupported Markdown destinations as plain text',
      (tester) async {
    const text = '[Open this](javascript:alert(1))';
    await pump(tester, text);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text(text), findsOneWidget);
  });

  testWidgets('updates links and leaves plain text selectable', (tester) async {
    await pump(tester, 'https://example.com');
    expect(button('See more'), findsOneWidget);
    await pump(tester, 'Plain text javascript:alert(1)');
    expect(find.byType(OutlinedButton), findsNothing);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'Plain text javascript:alert(1)',
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows feedback when a link cannot open', (tester) async {
    succeeds = false;
    await pump(tester, 'http://example.com');
    await tester.tap(button('See more'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open link.'), findsOneWidget);
  });
}
