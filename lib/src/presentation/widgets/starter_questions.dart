part of '../view/chat_view.dart';

class _StarterQuestions extends StatelessWidget {
  const _StarterQuestions({
    required this.questions,
    required this.enabled,
    required this.colors,
    required this.onSelected,
  });

  final List<WisperBotStarterQuestion> questions;
  final bool enabled;
  final WisperBotResolvedTheme colors;
  final ValueChanged<WisperBotStarterQuestion> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Common questions',
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 36),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final question in questions)
                  OutlinedButton(
                    key: ValueKey<String>(question.id),
                    onPressed: enabled ? () => onSelected(question) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      disabledForegroundColor: colors.onSurfaceMuted,
                      backgroundColor: colors.surface,
                      disabledBackgroundColor: colors.surfaceMuted,
                      side: BorderSide(
                        color: enabled ? colors.primary : colors.outline,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(44, 40),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(question.label),
                  ),
              ],
            ),
          ),
        ),
      );
}
