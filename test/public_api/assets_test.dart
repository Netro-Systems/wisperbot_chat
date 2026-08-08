import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bundles the built-in launcher logo', (_) async {
    final logo = await rootBundle.load(
      'packages/wisperbot_chat/assets/images/logo.png',
    );

    expect(logo.lengthInBytes, greaterThan(0));
  });
}
