import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

import 'src/theme/example_theme.dart';
import 'src/widgets/example_brand_header.dart';
import 'src/widgets/example_hero_card.dart';
import 'src/widgets/integration_card.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final widgetKey = dotenv.get('WISPERBOT_WIDGET_KEY').trim();
  final configuredApiBaseUrl =
      dotenv.maybeGet('WISPERBOT_API_BASE_URL')?.trim();
  final oneSignalAppId = dotenv.maybeGet('ONESIGNAL_APP_ID')?.trim();
  final notificationsConfigured = oneSignalAppId?.isNotEmpty == true;
  await WisperBotChat.initialize(
    widgetKey: widgetKey,
    apiBaseUrl: configuredApiBaseUrl?.isNotEmpty == true
        ? configuredApiBaseUrl!
        : 'https://wisperbot.com',
    navigatorKey: navigatorKey,
    requireNotificationPermission: notificationsConfigured,
    registerVisitorOnAppLaunch: true,
    useApiColors: true,
    lightStatusBarIcons: true,
    oneSignalAppId: notificationsConfigured ? oneSignalAppId : null,
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'WisperBot Chat',
        theme: buildExampleTheme(),
        home: const ExampleHome(),
      );
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  Future<void> _openChat(BuildContext context,
      {WisperBotPresentation? presentation}) async {
    try {
      await WisperBotChat.open(
        context,
        presentation: presentation,
      );
    } on WisperBotException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

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
                  onTap: () => _openChat(
                    context,
                  ),
                ),
                const SizedBox(height: 12),
                IntegrationCard(
                  icon: Icons.vertical_align_top_rounded,
                  title: 'Bottom sheet',
                  subtitle: 'Keep the current screen in context',
                  onTap: () => _openChat(
                    context,
                    presentation: WisperBotPresentation.bottomSheet,
                  ),
                ),
                const SizedBox(height: 12),
                IntegrationCard(
                  icon: Icons.web_asset_rounded,
                  title: 'Dialog',
                  subtitle: 'A focused, compact chat window',
                  onTap: () => _openChat(
                    context,
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
                      builder: (_) => const EmbeddedExample(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        floatingActionButton: WisperBotChat.launcher(),
      );
}

class EmbeddedExample extends StatelessWidget {
  const EmbeddedExample({super.key});

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
            child: WisperBotChat.view(),
          ),
        ),
      );
}
