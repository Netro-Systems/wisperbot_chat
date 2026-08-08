part of '../view/chat_view.dart';

class _BubbleLayout extends StatelessWidget {
  const _BubbleLayout({
    required this.visitor,
    required this.widgetConfig,
    required this.colors,
    required this.child,
    this.bubbleKey,
  });

  final bool visitor;
  final WisperBotWidgetConfig? widgetConfig;
  final WisperBotResolvedTheme colors;
  final Widget child;
  final Key? bubbleKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final maximumWidth = math.min(constraints.maxWidth * 0.76, 520.0);
          return Align(
            alignment: visitor
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maximumWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (!visitor) ...<Widget>[
                    _SupportAvatar(
                      avatarUrl: widgetConfig?.avatarUrl,
                      size: 28,
                      backgroundColor: colors.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: DecoratedBox(
                      key: bubbleKey,
                      decoration: BoxDecoration(
                        color:
                            visitor ? colors.visitorBubble : colors.agentBubble,
                        border:
                            visitor ? null : Border.all(color: colors.outline),
                        borderRadius: BorderRadiusDirectional.only(
                          topStart: Radius.circular(colors.borderRadius),
                          topEnd: Radius.circular(colors.borderRadius),
                          bottomStart: Radius.circular(
                            visitor ? colors.borderRadius : 5,
                          ),
                          bottomEnd: Radius.circular(
                            visitor ? 5 : colors.borderRadius,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _SupportAvatar extends StatelessWidget {
  const _SupportAvatar({
    required this.avatarUrl,
    required this.size,
    required this.backgroundColor,
    this.borderColor,
  });

  final Uri? avatarUrl;
  final double size;
  final Color backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final assetSize = size * 0.56;
    final fallback = Center(
      child: SizedBox.square(
        dimension: assetSize,
        child: const WisperBotBrandLogo(
          imageKey: ValueKey<String>('wisperbot-support-logo'),
        ),
      ),
    );
    return Semantics(
      label: 'Support avatar',
      image: true,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: borderColor == null
              ? null
              : Border.all(color: borderColor!, width: 2),
        ),
        child: avatarUrl == null
            ? fallback
            : Center(
                child: SizedBox.square(
                  dimension: assetSize,
                  child: WisperBotRemoteImage(
                    url: avatarUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_) => fallback,
                  ),
                ),
              ),
      ),
    );
  }
}
