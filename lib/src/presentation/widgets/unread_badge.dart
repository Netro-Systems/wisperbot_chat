import 'package:flutter/material.dart';

/// Internal badge renderer with predictable child-relative positioning.
class WisperBotUnreadBadgeView extends StatelessWidget {
  const WisperBotUnreadBadgeView({
    super.key,
    required this.unreadCount,
    required this.child,
    this.indicatorKey,
    this.showCount = false,
    this.maxCount = 99,
    this.labelBuilder,
    this.backgroundColor,
    this.textColor,
    this.smallSize = 8,
    this.largeSize,
    this.textStyle,
    this.padding,
    this.alignment,
    this.offset,
  });

  final int unreadCount;
  final Widget child;
  final Key? indicatorKey;
  final bool showCount;
  final int maxCount;
  final Widget Function(BuildContext context, int unreadCount)? labelBuilder;
  final Color? backgroundColor;
  final Color? textColor;
  final double? smallSize;
  final double? largeSize;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final Offset? offset;

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) return child;

    final theme = Theme.of(context);
    final color = backgroundColor ?? theme.colorScheme.error;
    final customLabel = labelBuilder?.call(context, unreadCount);
    final countText = showCount
        ? (unreadCount > maxCount ? '$maxCount+' : '$unreadCount')
        : null;
    final label = customLabel ?? (countText == null ? null : Text(countText));
    final Widget indicator;
    if (label == null) {
      final size = smallSize ?? 8;
      indicator = Container(
        key: indicatorKey,
        width: size,
        height: size,
        decoration: ShapeDecoration(
          color: color,
          shape: const CircleBorder(),
        ),
      );
    } else {
      final size = largeSize ?? 16;
      final isCircularCount = customLabel == null &&
          countText != null &&
          !countText.endsWith('+') &&
          countText.length <= 2;
      indicator = DefaultTextStyle(
        style: (textStyle ?? theme.textTheme.labelSmall ?? const TextStyle())
            .copyWith(color: textColor ?? theme.colorScheme.onError),
        child: isCircularCount
            ? Container(
                key: indicatorKey,
                width: size,
                height: size,
                padding: padding,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: color,
                  shape: const CircleBorder(),
                ),
                child: label,
              )
            : SizedBox(
                height: size,
                child: Container(
                  key: indicatorKey,
                  constraints: BoxConstraints(minWidth: size),
                  padding: padding ?? const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    color: color,
                    shape: const StadiumBorder(),
                  ),
                  child: label,
                ),
              ),
      );
    }

    return Semantics(
      label: unreadCount == 1
          ? '1 unread message'
          : '$unreadCount unread messages',
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        heightFactor: 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            child,
            Positioned.fill(
              child: Align(
                alignment: alignment ?? AlignmentDirectional.topEnd,
                child: Transform.translate(
                  offset: offset ?? Offset.zero,
                  child: indicator,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
