import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  final config = WisperBotConfig(
    widgetKey: dotenv.get('WISPERBOT_WIDGET_KEY').trim(),
    apiBaseUrl: dotenv
        .get(
          'WISPERBOT_API_BASE_URL',
        )
        .trim(),
    user: const WisperBotUser(name: 'GG'),
    theme: WisperBotThemeData(),
    useApiColors: true,
  );
  runApp(ExampleApp(config: config));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.config});

  final WisperBotConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WisperBot Chat SDK',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF762E)),
          useMaterial3: true,
        ),
        home: ExampleHome(config: config),
      );
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key, required this.config});

  final WisperBotConfig config;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('WisperBot Chat SDK')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const Text(
              'The widget key is loaded from .env. Try any integration style '
              'below.',
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
                  builder: (_) => EmbeddedExample(config: config),
                ),
              ),
              child: const Text('Open embedded view'),
            ),
          ],
        ),
        floatingActionButton: WisperBotChatLauncher(config: config),
      );
}

class EmbeddedExample extends StatelessWidget {
  const EmbeddedExample({super.key, required this.config});

  final WisperBotConfig config;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Embedded chat')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: WisperBotChatView(config: config),
          ),
        ),
      );
}
