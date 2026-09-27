import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('OneSignal#notifications');
  const config = WisperBotConfig(
      widgetKey: 'test',
      oneSignalAppId: 'app-id',
      requireNotificationPermission: true);
  final service = WidgetOneSignalService.instance;
  var granted = false;
  var canRequest = true;
  var acceptsPrompt = false;
  var requests = 0;
  setUp(() {
    for (final name in [
      'OneSignal',
      'OneSignal#debug',
      'OneSignal#user',
      'OneSignal#pushsubscription',
      'OneSignal#inappmessages'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (call.method == 'OneSignal#pushSubscriptionOptedIn') return false;
        return null;
      });
    }
    service.resetForTesting();
    granted = false;
    canRequest = true;
    acceptsPrompt = false;
    requests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'OneSignal#permission':
          return granted;
        case 'OneSignal#canRequest':
          return canRequest;
        case 'OneSignal#requestPermission':
          requests++;
          expect(call.arguments, {'fallbackToSettings': false});
          granted = acceptsPrompt;
          canRequest = false;
          return granted;
        default:
          return null;
      }
    });
  });
  tearDown(() {
    WisperBotChat.resetForTesting();
    for (final name in [
      'OneSignal',
      'OneSignal#debug',
      'OneSignal#user',
      'OneSignal#pushsubscription',
      'OneSignal#inappmessages'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
    service.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('existing permission does not show a prompt', () async {
    granted = true;
    await service.ensureChatPermission(config);
    expect(requests, 0);
  });
  test('native prompt acceptance allows chat', () async {
    acceptsPrompt = true;
    await service.ensureChatPermission(config);
    expect(requests, 1);
  });
  test('hard denial requires settings; enabling in settings permits retry',
      () async {
    canRequest = false;
    await expectLater(
        service.ensureChatPermission(config),
        throwsA(isA<WisperBotException>().having(
            (error) => error.message,
            'message',
            'Enable notifications from settings to use the support feature.')));
    expect(requests, 0);
    granted = true;
    await service.ensureChatPermission(config);
    expect(requests, 0);
  });
  test('declining the prompt prevents chat', () async {
    await expectLater(
        service.ensureChatPermission(config),
        throwsA(isA<WisperBotException>().having((error) => error.code, 'code',
            WisperBotErrorCode.notificationPermission)));
    expect(requests, 1);
  });
  test('disabled requirement preserves existing behavior', () async {
    await service
        .ensureChatPermission(const WisperBotConfig(widgetKey: 'test'));
    expect(requests, 0);
  });

  testWidgets('iOS denial offers Settings and opens app settings',
      (tester) async {
    const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final launchedUrls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlChannel, (call) async {
      if (call.method == 'launch') {
        launchedUrls.add((call.arguments as Map)['url'] as String);
        return true;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(urlChannel, null);
    });
    canRequest = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => WisperBotChat.open(context, config: config),
            child: const Text('Open support'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open support'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SnackBarAction, 'Settings'), findsOneWidget);
    expect(find.byType(WisperBotChatScreen), findsNothing);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(launchedUrls, ['app-settings:']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('launcher reports missing app ID without an unhandled exception',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: WisperBotChatLauncher(
              config: WisperBotConfig(
        widgetKey: 'test',
        requireNotificationPermission: true,
      ))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open chat'));
    await tester.pumpAndSettle();
    expect(
        find.text('Support is unavailable because notification setup is incomplete.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(WisperBotChatScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'launcher waits for tap and hard denial shows snackbar without starting chat',
      (tester) async {
    canRequest = false;
    var sessionRequests = 0;
    final client = MockClient((_) async {
      sessionRequests++;
      return http.Response('{}', 500);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: WisperBotChatLauncher(config: config)),
      ));
      await tester.pumpAndSettle();
      expect(sessionRequests, 0);
      expect(requests, 0);
      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Enable notifications from settings to use the support feature.'),
          findsOneWidget);
      expect(find.byType(WisperBotChatScreen), findsNothing);
      expect(sessionRequests, 0);
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  });
}
