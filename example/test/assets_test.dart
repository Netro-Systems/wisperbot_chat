import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat_example/src/widgets/example_brand_header.dart';

void main() {
  testWidgets('example header targets the package-owned brand logo', (tester) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _TestAssetBundle(),
        child: const MaterialApp(home: ExampleBrandHeader()),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final logo = image.image as AssetImage;
    expect(logo.assetName, 'assets/images/logo.png');
    expect(logo.package, 'wisperbot_chat');
  });
}

class _TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(
        key == 'AssetManifest.bin' ? key : 'assets/images/app_logo.png',
      );
}
