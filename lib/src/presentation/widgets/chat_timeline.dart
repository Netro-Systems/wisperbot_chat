part of '../view/chat_view.dart';

class _BubbleLayout extends StatelessWidget {
  const _BubbleLayout({
    required this.visitor,
    required this.widgetConfig,
    required this.colors,
    required this.child,
    this.isImage = false,
    this.isPhotoGroup = false,
    this.bubbleKey,
  });

  final bool visitor;
  final WisperBotWidgetConfig? widgetConfig;
  final WisperBotResolvedTheme colors;
  final Widget child;
  final bool isImage;
  final bool isPhotoGroup;
  final Key? bubbleKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const avatarSize = 28.0;
          const avatarGap = 8.0;
          final viewportWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final widthFactor = isImage ? 0.9 : 0.76;
          final widthLimit = isPhotoGroup
              ? 290.0 + (visitor ? 0 : avatarSize + avatarGap)
              : (isImage ? 520.0 : 420.0);
          final maximumWidth =
              math.min(viewportWidth * widthFactor, widthLimit);
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
                      size: avatarSize,
                      backgroundColor: colors.primary,
                    ),
                    const SizedBox(width: avatarGap),
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
                        padding: isPhotoGroup
                            ? const EdgeInsets.all(2)
                            : const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 9),
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
