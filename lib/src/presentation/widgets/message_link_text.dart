import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Selectable message text with tappable web links.
class MessageLinkText extends StatefulWidget {
  const MessageLinkText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<MessageLinkText> createState() => _MessageLinkTextState();
}

class _MessageLinkTextState extends State<MessageLinkText> {
  static final _links = RegExp(
    r'''\[([^\]\n]+)\]\((https?://[^\s<>"')]+)\)|\b((?:https?://|www\.)[^\s<>"']+)''',
    caseSensitive: false,
  );
  final _recognizers = <TapGestureRecognizer>[];
  List<InlineSpan> _spans = [];

  @override
  void initState() {
    super.initState();
    _updateSpans();
  }

  @override
  void didUpdateWidget(covariant MessageLinkText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _updateSpans();
    }
  }

  void _updateSpans() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    _spans = [];
    var offset = 0;
    for (final match in _links.allMatches(widget.text)) {
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
      final uri = Uri.tryParse(
        link.toLowerCase().startsWith('www.') ? 'https://$link' : link,
      );
      if (uri == null || uri.host.isEmpty) continue;
      _spans.add(TextSpan(text: widget.text.substring(offset, match.start)));
      final recognizer = TapGestureRecognizer()..onTap = () => _openLink(uri);
      _recognizers.add(recognizer);
      _spans.add(TextSpan(
        text: markdownLabel ?? link,
        style: TextStyle(
          decoration: TextDecoration.underline,
          fontSize: (widget.style?.fontSize ?? 14) + 1,
          fontWeight: FontWeight.w700,
        ),
        recognizer: recognizer,
      ));
      offset = markdownLabel == null ? match.start + link.length : match.end;
    }
    _spans.add(TextSpan(text: widget.text.substring(offset)));
  }

  Future<void> _openLink(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Report unsupported or failed launches without interrupting the chat.
    }
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Could not open link.')),
    );
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectableText.rich(
        TextSpan(children: _spans),
        style: widget.style,
      );
}
