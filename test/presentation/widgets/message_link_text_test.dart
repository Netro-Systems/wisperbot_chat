import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  Future<void> tapInlineLink(
    WidgetTester tester,
    String renderedText,
    String url,
  ) async {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(renderedText, findRichText: true),
    );
    final offset = renderedText.indexOf(url);
    final box = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: offset, extentOffset: offset + 1),
        )
        .first;
    await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
    await tester.pump();
  }

  testWidgets(
      'puts bare URLs on separate lines and excludes punctuation from targets',
      (tester) async {
    const text =
        'See https://example.com/a_(b)?x=1&y=2, (www.example.org/a%FF).';
    const rendered =
        'See\nhttps://example.com/a_(b)?x=1&y=2, (\nwww.example.org/a%FF).';
    await pump(tester, text);
    expect(find.byType(OutlinedButton), findsNothing);
    await tapInlineLink(tester, rendered, 'https://example.com');
    await tapInlineLink(tester, rendered, 'www.example.org');
    expect(launched, [
      'https://example.com/a_(b)?x=1&y=2',
      'https://www.example.org/a%FF',
    ]);
  });

  testWidgets('uses a standard Markdown label as the button text',
      (tester) async {
    const text =
        'Call us or [contact us on WhatsApp](https://wa.me/message/BHA3NTMHBCD5O1).';
    await pump(tester, text, style: const TextStyle(fontSize: 14));
    expect(
      find.text('Call us or\n\uFFFC.', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(button('contact us on WhatsApp'));
    await tester.pump();
    expect(launched, ['https://wa.me/message/BHA3NTMHBCD5O1']);
  });

  testWidgets('uses the outer WhatsApp label in a wrapped link',
      (tester) async {
    const url = 'https://api.whatsapp.com/send?phone=1234567890';
    await pump(tester, 'Contact us on [WhatsApp]\\([$url]($url)).');
    expect(find.text('Contact us on\n\uFFFC.', findRichText: true),
        findsOneWidget);
    await tester.tap(button('WhatsApp'));
    await tester.pump();
    expect(launched, [url]);
  });

  testWidgets('opens a wrapped package link with its original query parameters',
      (tester) async {
    const url = 'https://www.telzen.net/packages/plan-id?country_id=plan-id'
        '&country_name=Brazil&plan_type=esim';
    await pump(
      tester,
      'Here are the eSIM options for Brazil.\n[View Plans]\\([$url]'
      r'(https://www.telzen.net/packages/plan-id?country_id=plan-id'
      r'\&country_name=Brazil\&plan_type=esim))',
    );
    expect(
      find.text('Here are the eSIM options for Brazil.\n\uFFFC',
          findRichText: true),
      findsOneWidget,
    );
    await tester.tap(button('View Plans'));
    await tester.pump();
    expect(launched, [url]);
  });

  testWidgets('displays a bare URL with an escaped scheme on a separate line',
      (tester) async {
    const url = 'https://telzen-landing.netlify.app/';
    await pump(tester, r'ogay https\://telzen-landing.netlify.app/');
    expect(find.byType(OutlinedButton), findsNothing);
    await tapInlineLink(tester, 'ogay\n$url', url);
    expect(launched, [url]);
  });

  testWidgets('displays separate URL lines when Markdown has no caption',
      (tester) async {
    const first = 'https://example.com/help';
    const second = 'https://example.com/contact';
    await pump(tester, '[]($first) [$second]($second)');
    expect(find.byType(OutlinedButton), findsNothing);
    await tapInlineLink(tester, '$first\n$second', first);
    await tapInlineLink(tester, '$first\n$second', second);
    expect(launched, [first, second]);
  });

  testWidgets('puts consecutive buttons and URLs on separate lines',
      (tester) async {
    await pump(
      tester,
      'See [Plans](https://example.com/plans) '
      '[Contact](https://example.com/contact) '
      'https://example.com/help for details.',
    );
    expect(button('Plans'), findsOneWidget);
    expect(button('Contact'), findsOneWidget);
    expect(
      find.text(
        'See\n\uFFFC\n\uFFFC\nhttps://example.com/help\nfor details.',
        findRichText: true,
      ),
      findsOneWidget,
    );
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
    expect(
        find.text('https://example.com', findRichText: true), findsOneWidget);
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
    await tapInlineLink(tester, 'http://example.com', 'http://example.com');
    await tester.pumpAndSettle();
    expect(find.text('Could not open link.'), findsOneWidget);
  });
}
