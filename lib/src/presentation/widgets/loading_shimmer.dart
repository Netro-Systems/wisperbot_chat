part of '../view/chat_view.dart';

class _ChatLoadingShimmer extends StatefulWidget {
  const _ChatLoadingShimmer({required this.showHeader});

  final bool showHeader;

  @override
  State<_ChatLoadingShimmer> createState() => _ChatLoadingShimmerState();
}

class _ChatLoadingShimmerState extends State<_ChatLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2B2F35) : const Color(0xFFE1E5EA);
    final highlight =
        isDark ? const Color(0xFF3A3F47) : const Color(0xFFF3F5F7);
    final canvas = isDark ? const Color(0xFF17191D) : const Color(0xFFF7F8FA);
    final skeleton = _LoadingSkeleton(showHeader: widget.showHeader);

    return ColoredBox(
      key: const ValueKey<String>('wisperbot-loading-canvas'),
      color: canvas,
      child: Semantics(
        key: const ValueKey<String>('wisperbot-loading-shimmer'),
        label: 'Connecting to chat',
        liveRegion: true,
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: reduceMotion
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(base, BlendMode.srcIn),
                    child: skeleton,
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    child: skeleton,
                    builder: (context, child) {
                      final travel = (_controller.value * 3) - 1.5;
                      return ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment(travel - 1, 0),
                          end: Alignment(travel + 1, 0),
                          colors: <Color>[base, highlight, base],
                          stops: const <double>[0.2, 0.5, 0.8],
                        ).createShader(bounds),
                        child: child,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.showHeader});

  final bool showHeader;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          if (showHeader)
            SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  Padding(
                    key: const ValueKey<String>('wisperbot-loading-header'),
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                    child: Row(
                      children: <Widget>[
                        const _ShimmerBlock.circle(size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const <Widget>[
                              FractionallySizedBox(
                                widthFactor: 0.42,
                                child: _ShimmerBlock(height: 13),
                              ),
                              SizedBox(height: 8),
                              FractionallySizedBox(
                                widthFactor: 0.62,
                                child: _ShimmerBlock(height: 9),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: _ShimmerBlock(
                      key: ValueKey<String>('wisperbot-loading-appbar-line'),
                      height: 1,
                      radius: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bottomSpacing = math.max(
                  28.0,
                  MediaQuery.viewPaddingOf(context).bottom + 12,
                );
                final composerHeight = bottomSpacing + 48;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: <Widget>[
                    if (constraints.maxHeight >= composerHeight + 96)
                      PositionedDirectional(
                        key: const ValueKey<String>(
                          'wisperbot-loading-message-1',
                        ),
                        start: 14,
                        top: 18,
                        width: math.max(0, (constraints.maxWidth - 28) * 0.62),
                        height: 62,
                        child: const _ShimmerBlock(height: 62, radius: 16),
                      ),
                    if (constraints.maxHeight >= composerHeight + 154)
                      PositionedDirectional(
                        end: 14,
                        top: 94,
                        width: math.max(0, (constraints.maxWidth - 28) * 0.48),
                        height: 44,
                        child: const _ShimmerBlock(height: 44, radius: 16),
                      ),
                    if (constraints.maxHeight >= composerHeight + 264)
                      PositionedDirectional(
                        start: 14,
                        top: 152,
                        width: math.max(0, (constraints.maxWidth - 28) * 0.72),
                        height: 76,
                        child: const _ShimmerBlock(height: 76, radius: 16),
                      ),
                    if (constraints.maxHeight >= composerHeight + 14)
                      PositionedDirectional(
                        key: const ValueKey<String>(
                          'wisperbot-loading-composer',
                        ),
                        start: 14,
                        end: 14,
                        bottom: bottomSpacing,
                        height: 48,
                        child: constraints.maxWidth >= 100
                            ? const Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _ShimmerBlock(
                                      height: 48,
                                      radius: 24,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  _ShimmerBlock.circle(size: 48),
                                ],
                              )
                            : const _ShimmerBlock(height: 48, radius: 24),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      );
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    super.key,
    required this.height,
    this.radius = 6,
  }) : width = null;

  const _ShimmerBlock.circle({required double size})
      : width = size,
        height = size,
        radius = size / 2;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
