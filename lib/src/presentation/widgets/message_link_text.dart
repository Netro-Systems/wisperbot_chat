import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Selectable message text with buttons and web links on separate lines.
class MessageLinkText extends StatefulWidget {
  const MessageLinkText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<MessageLinkText> createState() => _MessageLinkTextState();
}

class _MessageLinkTextState extends State<MessageLinkText> {
  static const _urlStart = r'(?:https?\\?://|www\.)';
  static const _label = r'\[([^\]\n]*)\]\\?\(';
  static const _target = '($_urlStart' r'''[^\s<>"')]+?)\\?\)''';
  static final _links = RegExp(
    // Match [label]\([url](url)) before its inner link.
    '$_label\\[$_urlStart'
    r'[^\s<>]+?\]\\?\('
    '$_target'
    r'\\?\)'
    '|$_label$_target'
    '|\\b($_urlStart'
    r'''[^\s<>"']+)''',
    caseSensitive: false,
  );
  static final _rawLinkLabel = RegExp(
    r'^(?:https?://|www\.)\S+$',
    caseSensitive: false,
  );
  static final _afterLinkSeparator = RegExp(r'^[ \t,.!?;:()\[\]{}]*');
  static final _trailingHorizontalSpace = RegExp(r'[ \t]+$');
  static const _buttonGreen = Color(0xFF015C49);
  static final _buttonStyle = OutlinedButton.styleFrom(
    foregroundColor: _buttonGreen,
    backgroundColor: const Color(0xFFE1EEEB),
    side: const BorderSide(color: _buttonGreen),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    minimumSize: const Size(44, 34),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
  static final _markdownEscape = RegExp(r'\\([\\`*_{}\[\]()#+\-.!&=?:/])');
  final _linkRecognizers = <TapGestureRecognizer>[];
  List<InlineSpan> _spans = [];

  @override
  void initState() {
    super.initState();
    _updateSpans();
  }

  @override
  void didUpdateWidget(covariant MessageLinkText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _updateSpans();
  }

  void _updateSpans() {
    _disposeLinkRecognizers();
    final spans = <InlineSpan>[];
    final text = widget.text;
    var offset = 0;
    for (final match in _links.allMatches(text)) {
      final markdownLabel = match.group(1) ?? match.group(3);
      final markdownTarget = match.group(2) ?? match.group(4);
      var link = markdownTarget ?? match.group(5)!;
      if (markdownTarget == null) {
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
      final destination = _unescape(link);
      final uri = Uri.tryParse(destination.toLowerCase().startsWith('www.')
          ? 'https://$destination'
          : destination);
      if (uri == null || uri.host.isEmpty) continue;
      final precedingText = text.substring(offset, match.start);
      final gap = (spans.isEmpty
              ? precedingText
              : _startTextAfterLinkOnNewLine(precedingText))
          .replaceFirst(_trailingHorizontalSpace, '');
      final needsLineBreak = (spans.isNotEmpty || gap.isNotEmpty) &&
          !gap.endsWith('\n') &&
          !gap.endsWith('\r');
      spans.add(TextSpan(text: needsLineBreak ? '$gap\n' : gap));
      final label = _unescape(markdownLabel ?? '').trim();
      if (label.isEmpty || _rawLinkLabel.hasMatch(label)) {
        final recognizer = TapGestureRecognizer()..onTap = () => _openLink(uri);
        _linkRecognizers.add(recognizer);
        spans.add(TextSpan(
          text: destination,
          style: const TextStyle(decoration: TextDecoration.underline),
          recognizer: recognizer,
        ));
      } else {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: OutlinedButton(
            style: _buttonStyle,
            onPressed: () => _openLink(uri),
            child: Text(
              label,
              textAlign: TextAlign.center,
              // WidgetSpan already scales the entire button with the text.
              textScaler: TextScaler.noScaling,
            ),
          ),
        ));
      }
      offset = markdownTarget == null ? match.start + link.length : match.end;
    }
    if (spans.isNotEmpty) {
      spans.add(TextSpan(
        text: _startTextAfterLinkOnNewLine(text.substring(offset)),
      ));
    }
    _spans = spans;
  }

  String _startTextAfterLinkOnNewLine(String text) {
    // Keep punctuation with the link and move following prose to a new line.
    final separatorEnd = _afterLinkSeparator.matchAsPrefix(text)!.end;
    if (separatorEnd == text.length || '\r\n'.contains(text[separatorEnd])) {
      return text;
    }
    final punctuation = text
        .substring(0, separatorEnd)
        .replaceFirst(_trailingHorizontalSpace, '');
    return '$punctuation\n${text.substring(separatorEnd)}';
  }

  String _unescape(String value) =>
      value.replaceAllMapped(_markdownEscape, (match) => match.group(1)!);

  void _disposeLinkRecognizers() {
    for (final recognizer in _linkRecognizers) {
      recognizer.dispose();
    }
    _linkRecognizers.clear();
  }

  @override
  void dispose() {
    _disposeLinkRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_spans.isEmpty) return SelectableText(widget.text, style: widget.style);
    return SelectionArea(
      child: Text.rich(TextSpan(children: _spans), style: widget.style),
    );
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
}
