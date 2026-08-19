import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../configuration/wisperbot_config.dart';
import '../application/services/widget_realtime_connector.dart';
import '../data/datasources/widget_remote_data_source.dart';
import '../data/network/network_caller.dart';
import '../data/network/response_decoder.dart';
import '../data/network/widget_results.dart';
import '../data/storage/secure_session_store.dart';
import '../data/storage/session_scope.dart';
import '../domain/contracts/session_store.dart';
import '../domain/errors/wisperbot_exception.dart';
import '../domain/events/chat_event.dart';
import '../domain/models/models.dart';
import 'services/message_reconciler.dart';
import 'services/polling_coordinator.dart';
import 'services/pre_chat_validator.dart';
import 'state/chat_state_machine.dart';

part 'client/wisperbot_client.dart';
part 'controller/chat_controller.dart';
part 'services/session_coordinator.dart';

/// Creates the concrete transport at the package's private composition point.
WidgetRemoteDataSource _createWidgetRemoteDataSource({
  required Uri baseUrl,
  required http.Client httpClient,
}) =>
    HttpWidgetRemoteDataSource(
      networkCaller: NetworkCaller(baseUrl: baseUrl, httpClient: httpClient),
    );
