import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/src/ui/remote_image.dart';

void main() {
  testWidgets('selects the SVG renderer from the URL extension',
      (tester) async {
    final result = await _buildRemoteImage(
      tester,
      Uri.parse('https://chat.example.com/support-avatar.SVG'),
    );

    expect(result.widget, isA<SvgPicture>());
  });

  testWidgets('selects the SVG renderer from a format query', (tester) async {
    final result = await _buildRemoteImage(
      tester,
      Uri.parse('https://chat.example.com/avatar?id=1&format=svg'),
    );

    expect(result.widget, isA<SvgPicture>());
  });

  testWidgets('uses Flutter image decoding for known raster formats',
      (tester) async {
    final result = await _buildRemoteImage(
      tester,
      Uri.parse('https://chat.example.com/support-avatar.webp'),
    );

    final image = result.widget as Image;
    final fallback = image.errorBuilder!(
      result.context,
      StateError('decode failed'),
      StackTrace.empty,
    );
    expect(fallback, isA<Text>());
    expect((fallback as Text).data, 'fallback');
  });

  testWidgets('retries extensionless image endpoints as SVG', (tester) async {
    final result = await _buildRemoteImage(
      tester,
      Uri.parse('https://chat.example.com/avatar?id=1'),
    );

    final image = result.widget as Image;
    final retry = image.errorBuilder!(
      result.context,
      StateError('raster decode failed'),
      StackTrace.empty,
    );
    expect(retry, isA<SvgPicture>());
  });
}

Future<({BuildContext context, Widget widget})> _buildRemoteImage(
  WidgetTester tester,
  Uri url,
) async {
  late BuildContext buildContext;
  late Widget builtWidget;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          buildContext = context;
          builtWidget = WisperBotRemoteImage(
            url: url,
            errorBuilder: (_) => const Text('fallback'),
          ).build(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (context: buildContext, widget: builtWidget);
}
