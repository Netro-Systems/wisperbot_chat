import 'package:flutter/material.dart';

class ExampleHeroCard extends StatelessWidget {
  const ExampleHeroCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF762E), Color(0xFFF0642A)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x38FF762E),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroBadge(),
            SizedBox(height: 22),
            Text(
              'Ship support chat\nin minutes.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                height: 1.08,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'One widget key unlocks every integration style. Pick one below '
              'to see the SDK in action.',
              style: TextStyle(
                color: Color(0xFFFFF2EB),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0x55FFFFFF)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: Colors.white, size: 15),
            SizedBox(width: 5),
            Text(
              'READY TO INTEGRATE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
}
