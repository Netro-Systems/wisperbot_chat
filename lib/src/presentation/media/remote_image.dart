import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders remote raster images and SVGs through their appropriate decoders.
///
/// URLs with an SVG extension or SVG format query are rendered directly as
/// vectors. Unknown extensions try Flutter's raster decoder first, then the SVG
/// decoder, which also supports image endpoints that omit a file extension.
class WisperBotRemoteImage extends StatelessWidget {
  const WisperBotRemoteImage({
    super.key,
    required this.url,
    required this.errorBuilder,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  final Uri url;
  final WidgetBuilder errorBuilder;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (_isSvgUrl(url)) return _buildSvg(context);

    return Image.network(
      url.toString(),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel,
      errorBuilder: (context, _, __) => _hasKnownRasterExtension(url)
          ? errorBuilder(context)
          : _buildSvg(context),
    );
  }

  Widget _buildSvg(BuildContext context) => SvgPicture.network(
        url.toString(),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        semanticsLabel: semanticLabel,
        errorBuilder: (context, _, __) => errorBuilder(context),
      );
}

bool _isSvgUrl(Uri url) {
  if (_extension(url) == 'svg') return true;
  const formatKeys = <String>{'format', 'fm', 'type'};
  for (final entry in url.queryParameters.entries) {
    if (!formatKeys.contains(entry.key.toLowerCase())) continue;
    final value = entry.value.toLowerCase();
    if (value == 'svg' || value == 'image/svg+xml') return true;
  }
  return false;
}

bool _hasKnownRasterExtension(Uri url) => const <String>{
      'avif',
      'bmp',
      'gif',
      'heic',
      'heif',
      'jpeg',
      'jpg',
      'png',
      'webp',
      'wbmp',
    }.contains(_extension(url));

String _extension(Uri url) {
  if (url.pathSegments.isEmpty) return '';
  final filename = url.pathSegments.last;
  final separator = filename.lastIndexOf('.');
  return separator < 0 ? '' : filename.substring(separator + 1).toLowerCase();
}
