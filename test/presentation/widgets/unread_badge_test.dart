import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/src/presentation/widgets/unread_badge.dart';

void main() {
  testWidgets('single-digit count badge is circular', (tester) async {
    const indicatorKey = ValueKey<String>('indicator');

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: WisperBotUnreadBadgeView(
            unreadCount: 1,
            showCount: true,
            largeSize: 14,
            indicatorKey: indicatorKey,
            child: Icon(Icons.chat),
          ),
        ),
      ),
    );

    final indicator = find.byKey(indicatorKey);
    expect(tester.getSize(indicator), const Size.square(14));
    expect(
      (tester.widget<Container>(indicator).decoration! as ShapeDecoration)
          .shape,
      isA<CircleBorder>(),
    );
  });

  testWidgets('two-digit count badge remains circular', (tester) async {
    const indicatorKey = ValueKey<String>('indicator');

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: WisperBotUnreadBadgeView(
            unreadCount: 10,
            showCount: true,
            largeSize: 14,
            indicatorKey: indicatorKey,
            child: Icon(Icons.chat),
          ),
        ),
      ),
    );

    final indicator = find.byKey(indicatorKey);
    expect(tester.getSize(indicator), const Size.square(14));
    expect(
      (tester.widget<Container>(indicator).decoration! as ShapeDecoration)
          .shape,
      isA<CircleBorder>(),
    );
  });

  testWidgets('overflow count badge expands as a pill', (tester) async {
    const indicatorKey = ValueKey<String>('indicator');

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: WisperBotUnreadBadgeView(
            unreadCount: 100,
            showCount: true,
            maxCount: 99,
            largeSize: 14,
            indicatorKey: indicatorKey,
            child: Icon(Icons.chat),
          ),
        ),
      ),
    );

    final indicator = find.byKey(indicatorKey);
    final size = tester.getSize(indicator);
    expect(size.height, 14);
    expect(size.width, greaterThan(size.height));
    expect(
      (tester.widget<Container>(indicator).decoration! as ShapeDecoration)
          .shape,
      isA<StadiumBorder>(),
    );
  });
}
