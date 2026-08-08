import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/data/storage/session_scope.dart';

import '../../support/support.dart';

part 'session_tests.dart';
part 'delivery_tests.dart';
part 'delivery_edge_case_tests.dart';
part 'identity_sync_tests.dart';
part 'pre_chat_lifecycle_tests.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = WisperBotConfig(
    widgetKey: 'test-widget',
    apiBaseUrl: 'https://chat.example.com/base/',
    polling: WisperBotPollingConfig(
      visibleInterval: Duration(minutes: 1),
      idleInterval: Duration(minutes: 1),
      failureMaxInterval: Duration(minutes: 1),
    ),
  );

  registerSessionTests(config);
  registerDeliveryTests(config);
  registerDeliveryEdgeCaseTests(config);
  registerIdentitySyncTests(config);
  registerPreChatLifecycleTests(config);
}
