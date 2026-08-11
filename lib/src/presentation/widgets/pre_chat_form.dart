part of '../view/chat_view.dart';

class _PreChatForm extends StatefulWidget {
  const _PreChatForm({
    required this.controller,
    required this.state,
    required this.colors,
  });

  final WisperBotChatController controller;
  final WisperBotChatState state;
  final WisperBotResolvedTheme colors;

  @override
  State<_PreChatForm> createState() => _PreChatFormState();
}

class _PreChatFormState extends State<_PreChatForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool get _requiresName =>
      widget.state.widget?.preChatFields.contains(WisperBotPreChatField.name) ==
      true;

  bool get _requiresEmail =>
      widget.state.widget?.preChatFields
          .contains(WisperBotPreChatField.email) ==
      true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    try {
      await widget.controller.submitPreChat(
        WisperBotPreChatData(
          name: _requiresName ? _nameController.text : null,
          email: _requiresEmail ? _emailController.text : null,
        ),
      );
    } on Object {
      // The controller publishes the typed validation or transport error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitting =
        widget.state.connection == WisperBotConnectionState.connecting;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Before we start',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: widget.colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please provide the information required for this chat.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: widget.colors.onSurfaceMuted,
                  ),
            ),
            if (_requiresName) ...<Widget>[
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey<String>('wisperbot-prechat-name'),
                controller: _nameController,
                enabled: !submitting,
                textInputAction: _requiresEmail
                    ? TextInputAction.next
                    : TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Name'),
                maxLength: 120,
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Name is required.' : null,
              ),
            ],
            if (_requiresEmail) ...<Widget>[
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('wisperbot-prechat-email'),
                controller: _emailController,
                enabled: !submitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Email'),
                maxLength: 190,
                onFieldSubmitted: (_) => unawaited(_submit()),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Email is required.';
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                      ? null
                      : 'Enter a valid email address.';
                },
              ),
            ],
            if (widget.state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                widget.state.error!.message,
                key: const ValueKey<String>('wisperbot-prechat-error'),
                style: TextStyle(color: widget.colors.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey<String>('wisperbot-prechat-submit'),
              onPressed: submitting ? null : () => unawaited(_submit()),
              child: Text(submitting ? 'Starting chat…' : 'Start chat'),
            ),
          ],
        ),
      ),
    );
  }
}
