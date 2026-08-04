import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bundles the example brand logo', (_) async {
    final logo = await rootBundle.load('assets/images/logo.png');

    expect(logo.lengthInBytes, greaterThan(0));
  });
}
