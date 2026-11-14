import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Selectable message text with buttons for web links.
class MessageLinkText extends StatelessWidget {
  const MessageLinkText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  static final _links = RegExp(
    r'''\[([^\]\n]+)\]\((https?://[^\s<>"')]+)\)|\b((?:https?://|www\.)[^\s<>"']+)''',
    caseSensitive: false,
  );
  static final _rawLinkLabel = RegExp(
    r'^(?:https?://|www\.)\S+$',
    caseSensitive: false,
  );
  static final _markdownEscape = RegExp(r'\\([\\`*_{}\[\]()#+\-.!&=?:/])');
  static final _packagePath =
      RegExp(r'/packages?(?:/|$)', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final color = style?.color;
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: color == null ? null : BorderSide(color: color),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      minimumSize: const Size(44, 32),
    );
    var offset = 0;
    for (final match in _links.allMatches(text)) {
      final markdownLabel = match.group(1);
      var link = match.group(2) ?? match.group(3)!;
      if (markdownLabel == null) {
        while (link.isNotEmpty) {
          final last = link[link.length - 1];
          final opening = {')': '(', ']': '[', '}': '{'}[last];
          if (',.!?;:'.contains(last) ||
              (opening != null &&
                  last.allMatches(link).length >
                      opening.allMatches(link).length)) {
            link = link.substring(0, link.length - 1);
          } else {
            break;
          }
        }
      }
      final destination = markdownLabel == null ? link : _unescape(link);
      final uri = Uri.tryParse(destination.toLowerCase().startsWith('www.')
          ? 'https://$destination'
          : destination);
      if (uri == null || uri.host.isEmpty) continue;
      spans.add(TextSpan(text: text.substring(offset, match.start)));
      final buttonLabel = _buttonLabel(uri);
      if (markdownLabel != null) {
        final caption = _unescape(markdownLabel).trim();
        if (caption.isNotEmpty &&
            caption.toLowerCase() != buttonLabel.toLowerCase() &&
            !_rawLinkLabel.hasMatch(caption)) {
          spans.add(TextSpan(text: '$caption '));
        }
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: OutlinedButton(
          style: buttonStyle,
          onPressed: () => _openLink(context, uri),
          child: Text(
            buttonLabel,
            textAlign: TextAlign.center,
            // WidgetSpan already scales the entire button with the text.
            textScaler: TextScaler.noScaling,
          ),
        ),
      ));
      offset = markdownLabel == null ? match.start + link.length : match.end;
    }
    if (spans.isEmpty) return SelectableText(text, style: style);
    spans.add(TextSpan(text: text.substring(offset)));
    return SelectionArea(
      child: Text.rich(TextSpan(children: spans), style: style),
    );
  }

  String _unescape(String value) =>
      value.replaceAllMapped(_markdownEscape, (match) => match.group(1)!);

  String _buttonLabel(Uri uri) {
    final host = uri.host;
    if (host == 'wa.me' ||
        host == 'whatsapp.com' ||
        host.endsWith('.whatsapp.com')) {
      return 'Call now';
    }
    if (_packagePath.hasMatch(uri.path)) {
      return 'See package';
    }
    return 'See more';
  }

  Future<void> _openLink(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Report unsupported or failed launches without interrupting the chat.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Could not open link.')),
    );
  }
}
