import 'package:flutter/material.dart';

import '../theme/example_theme.dart';

class ExampleBrandHeader extends StatelessWidget {
  const ExampleBrandHeader({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          _BrandMark(),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WisperBot',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'FLUTTER CHAT SDK',
                style: TextStyle(
                  color: Color(0xFF3C3C3C),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: wisperBotOrange,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33FF762E),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/logo.png',
          package: 'wisperbot_chat',
        ),
      );
}
