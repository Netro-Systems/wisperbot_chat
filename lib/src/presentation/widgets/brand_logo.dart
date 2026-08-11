import 'package:flutter/material.dart';

const _wisperBotLogoAsset = 'assets/images/logo.png';

class WisperBotBrandLogo extends StatelessWidget {
  const WisperBotBrandLogo({
    super.key,
    this.imageKey,
    this.fit = BoxFit.contain,
  });

  final Key? imageKey;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset(
        _wisperBotLogoAsset,
        key: imageKey,
        package: 'wisperbot_chat',
        fit: fit,
        excludeFromSemantics: true,
      );
}
