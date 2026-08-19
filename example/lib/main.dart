import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

import 'src/example_media_adapter.dart';
import 'src/theme/example_theme.dart';
import 'src/widgets/example_brand_header.dart';
import 'src/widgets/example_hero_card.dart';
import 'src/widgets/integration_card.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final widgetKey = dotenv.get('WISPERBOT_WIDGET_KEY').trim();
  final config = WisperBotConfig(
    widgetKey: widgetKey,
    user: const WisperBotUser(name: 'Demo User', email: 'user@demo.com'),
  );

  // Initialize push notification handlers
  WisperBotChat.initializeNotificationHandlers(
    config: config,
    navigatorKey: navigatorKey,
  );

  runApp(
    ExampleApp(config: config),
  );
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key, required this.config});

  final WisperBotConfig config;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final ExampleMediaAdapter _mediaAdapter = ExampleMediaAdapter();
  late final WisperBotConfig _config = WisperBotConfig(
    widgetKey: widget.config.widgetKey,
    user: widget.config.user,
    mediaAdapter: _mediaAdapter,
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'WisperBot Chat',
        theme: buildExampleTheme(),
        home: ExampleHome(config: _config),
      );

  @override
  void dispose() {
    unawaited(_mediaAdapter.dispose());
    super.dispose();
  }
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key, required this.config});

  final WisperBotConfig config;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 76,
          titleSpacing: 24,
          title: const ExampleBrandHeader(),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                const ExampleHeroCard(),
                const SizedBox(height: 28),
                const Text(
                  'Choose an integration',
                  style: TextStyle(
                    color: Color(0xFF211A17),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Preview how chat fits into different parts of your app.',
                  style: TextStyle(
                    color: Color(0xFF3C3C3C),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                IntegrationCard(
                  icon: Icons.fullscreen_rounded,
                  title: 'Full-screen chat',
                  subtitle: 'An immersive support experience',
                  onTap: () => WisperBotChat.open(
                    context,
                    config: config,
                  ),
                ),
                const SizedBox(height: 12),
                IntegrationCard(
                  icon: Icons.vertical_align_top_rounded,
                  title: 'Bottom sheet',
                  subtitle: 'Keep the current screen in context',
                  onTap: () => WisperBotChat.open(
                    context,
                    config: config,
                    presentation: WisperBotPresentation.bottomSheet,
                  ),
                ),
                const SizedBox(height: 12),
                IntegrationCard(
                  icon: Icons.web_asset_rounded,
                  title: 'Dialog',
                  subtitle: 'A focused, compact chat window',
                  onTap: () => WisperBotChat.open(
                    context,
                    config: config,
                    presentation: WisperBotPresentation.dialog,
                  ),
                ),
                const SizedBox(height: 12),
                IntegrationCard(
                  icon: Icons.view_quilt_rounded,
                  title: 'Embedded view',
                  subtitle: 'Place chat directly inside your layout',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => EmbeddedExample(config: config),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        floatingActionButton: WisperBotChatLauncher(config: config),
      );
}

class EmbeddedExample extends StatelessWidget {
  const EmbeddedExample({super.key, required this.config});

  final WisperBotConfig config;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Embedded chat',
          ),
          backgroundColor: Color(0xFFFF762E),
          titleSpacing: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: WisperBotChatView(config: config),
          ),
        ),
      );
}
