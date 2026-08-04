import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

const _wisperBotOrange = Color(0xFFFF762E);

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  final config = WisperBotConfig(
    widgetKey: dotenv.get('WISPERBOT_WIDGET_KEY').trim(),
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
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _wisperBotOrange,
    ).copyWith(
      primary: _wisperBotOrange,
      secondary: _wisperBotOrange,
      onPrimary: Colors.white,
      surface: Colors.white,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WisperBot Chat',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF000000),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _wisperBotOrange,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _wisperBotOrange,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: _wisperBotOrange),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: ExampleHome(config: config),
    );
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
          title: const Row(
            children: [
              _BrandMark(),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WisperBot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'FLUTTER CHAT SDK',
                    style: TextStyle(
                      color: Color(0xFF8A7267),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                const _HeroCard(),
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
                    color: Color(0xFF7B6A62),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _IntegrationCard(
                  icon: Icons.fullscreen_rounded,
                  title: 'Full-screen chat',
                  subtitle: 'An immersive support experience',
                  onTap: () => WisperBotChat.open(
                    context,
                    config: config,
                  ),
                ),
                const SizedBox(height: 12),
                _IntegrationCard(
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
                _IntegrationCard(
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
                _IntegrationCard(
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
        floatingActionButton: WisperBotChatLauncher(
          config: config,
          builder: (context, state, openChat) => _LogoLauncher(
            config: config,
            state: state,
            onPressed: openChat,
          ),
        ),
      );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _wisperBotOrange,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33FF762E),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Image.asset('assets/images/logo.png'),
      );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF762E), Color(0xFFF0642A)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x38FF762E),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroBadge(),
            SizedBox(height: 22),
            Text(
              'Ship support chat\nin minutes.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                height: 1.08,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'One widget key unlocks every integration style. Pick one below '
              'to see the SDK in action.',
              style: TextStyle(
                color: Color(0xFFFFF2EB),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0x55FFFFFF)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: Colors.white, size: 15),
            SizedBox(width: 5),
            Text(
              'READY TO INTEGRATE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
}

class _IntegrationCard extends StatelessWidget {
  const _IntegrationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: const Color(0x44FF762E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xB3FFB186)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        splashColor: Color(0xFFFF762E).withValues(alpha: 0.2),
        highlightColor: Color(0xFFFF762E).withValues(alpha: 0.2),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEE5),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: _wisperBotOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF211A17),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7B6A62),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF762E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFFFFFFFF),
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoLauncher extends StatelessWidget {
  const _LogoLauncher({
    required this.config,
    required this.state,
    required this.onPressed,
  });

  final WisperBotConfig config;
  final WisperBotChatState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final unread = state.unreadCount;
    final label = unread != null && unread > 0
        ? 'Open chat, $unread unread ${unread == 1 ? 'message' : 'messages'}'
        : 'Open chat';
    final primary = config.theme?.primaryColor ??
        (config.useApiColors
            ? _parseHexColor(state.widget?.primaryColorHex)
            : null) ??
        _wisperBotOrange;

    return Semantics(
      button: true,
      label: label,
      child: SizedBox.square(
        dimension: config.theme?.launcherSize ?? 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: FloatingActionButton(
                heroTag: null,
                tooltip: label,
                onPressed: onPressed,
                backgroundColor: primary,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (unread != null && unread > 0)
              PositionedDirectional(
                top: -6,
                end: -6,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color? _parseHexColor(String? value) {
  if (value == null) return null;
  final hex = value.trim().replaceFirst('#', '');
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
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
