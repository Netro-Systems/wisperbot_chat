import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/configuration/wisperbot_config.dart';
import 'package:wisperbot_chat/src/presentation/host/wisperbot_chat_host.dart';
import 'package:wisperbot_chat/src/application/services/widget_onesignal_service.dart';

import '../../support/fixtures/widget_api_fixtures.dart';

void main() {
  setUp(WidgetOneSignalService.instance.resetForTesting);
  tearDown(WidgetOneSignalService.instance.resetForTesting);

  testWidgets('host eagerly registers an anonymous visitor by default',
      (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final httpClient = MockClient((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode(sessionResponse()), 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(_host(const WisperBotConfig(
        requireNotificationPermission: false,
        widgetKey: 'host-widget',
        apiBaseUrl: 'https://chat.example.com',
        enableOneSignal: false,
        sessionStore: _NoopSessionStore(),
      )));
      await tester.pumpAndSettle();
    }, () => httpClient);

    expect(bodies, hasLength(1));
    expect(bodies.single, <String, dynamic>{
      'key': 'host-widget',
      'active': true,
    });
  });

  testWidgets('host registers its initial user outside configuration',
      (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final httpClient = MockClient((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode(sessionResponse()), 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(_host(
        const WisperBotConfig(
          requireNotificationPermission: false,
          widgetKey: 'host-widget',
          apiBaseUrl: 'https://chat.example.com',
          enableOneSignal: false,
          sessionStore: _NoopSessionStore(),
        ),
        initialUser: const WisperBotUser(
          externalId: 'customer-1',
          name: 'Jane Doe',
        ),
      ));
      await tester.pumpAndSettle();
    }, () => httpClient);

    expect(bodies.single['external_id'], 'customer-1');
    expect(bodies.single['name'], 'Jane Doe');
  });

  testWidgets('disabled tracking performs no request before chat opens',
      (tester) async {
    var requests = 0;
    final httpClient = MockClient((request) async {
      requests++;
      return http.Response(jsonEncode(sessionResponse()), 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(_host(const WisperBotConfig(
        requireNotificationPermission: false,
        widgetKey: 'host-widget',
        apiBaseUrl: 'https://chat.example.com',
        enableOneSignal: false,
        registerVisitorOnAppLaunch: false,
        sessionStore: _NoopSessionStore(),
      )));
      await tester.pumpAndSettle();
    }, () => httpClient);

    expect(requests, 0);
  });
}

Widget _host(
  WisperBotConfig config, {
  WisperBotUser? initialUser,
}) =>
    WisperBotChatHost(
      config: config,
      initialUser: initialUser,
      builder: (context, navigatorKey, controller) => MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Host app')),
      ),
    );

final class _NoopSessionStore implements WisperBotSessionStore {
  const _NoopSessionStore();

  @override
  Future<void> delete(String namespace) async {}

  @override
  Future<WisperBotStoredSession?> read(String namespace) async => null;

  @override
  Future<void> write(String namespace, WisperBotStoredSession session) async {}
}
