import 'package:flutter/material.dart';

import '../theme/resolved_theme.dart';

/// Internal attribution footer shown below the default composer.
class BrandFooter extends StatelessWidget {
  const BrandFooter({
    required this.companyName,
    required this.colors,
    super.key,
  });

  final String? companyName;
  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) {
    final configured = companyName?.trim();
    final brand = configured?.isNotEmpty == true ? configured! : 'WisperBot';
    final baseStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceMuted.withValues(alpha: 0.7),
          fontSize: 11,
        );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text.rich(
        TextSpan(
          text: 'Powered by ',
          children: <InlineSpan>[
            TextSpan(
              text: brand,
              style: baseStyle?.copyWith(
                color: colors.onSurfaceMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: baseStyle,
      ),
    );
  }
}
