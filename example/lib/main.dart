import 'package:flutter/material.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

void main() => runApp(const ExampleApp());

const config = WisperBotConfig(
  widgetKey: 'CtgT1RAdDZNngub78prZLbmTb3NPPoxS7P',
  user: WisperBotUser(name: "GG"),
);

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'WisperBot Chat SDK',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6258F9)),
          useMaterial3: true,
        ),
        home: const ExampleHome(),
      );
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('WisperBot Chat SDK')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const Text(
              'Replace YOUR_WIDGET_KEY with a controlled staging widget key, '
              'then try any integration style.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => WisperBotChat.open(context, config: config),
              child: const Text('Open full-screen chat'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => WisperBotChat.open(
                context,
                config: config,
                presentation: WisperBotPresentation.bottomSheet,
              ),
              child: const Text('Open bottom sheet'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => WisperBotChat.open(
                context,
                config: config,
                presentation: WisperBotPresentation.dialog,
              ),
              child: const Text('Open dialog'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const EmbeddedExample(),
                ),
              ),
              child: const Text('Open embedded view'),
            ),
          ],
        ),
        floatingActionButton: const WisperBotChatLauncher(config: config),
      );
}

class EmbeddedExample extends StatelessWidget {
  const EmbeddedExample({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Embedded chat')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: WisperBotChatView(config: config),
          ),
        ),
      );
}
