part of '../configuration/wisperbot_config.dart';

/// Receives a redacted SDK diagnostic event.
typedef WisperBotDiagnosticsCallback = void Function(
  WisperBotDiagnosticEvent event,
);

/// Stable categories of redacted operational diagnostics.
enum WisperBotDiagnosticKind { initialization, lifecycle, connection, poll, send }

/// A redacted operational event that contains no visitor or message content.
@immutable
class WisperBotDiagnosticEvent {
  /// Creates a safe diagnostic event.
  const WisperBotDiagnosticEvent({
    required this.kind,
    required this.occurredAt,
    this.duration,
    this.httpStatus,
    this.errorCode,
  });

  /// Operation category.
  final WisperBotDiagnosticKind kind;

  /// UTC-compatible occurrence time supplied by the controller.
  final DateTime occurredAt;

  /// Optional operation duration.
  final Duration? duration;

  /// Optional HTTP status without a response body.
  final int? httpStatus;

  /// Optional safe SDK error category.
  final WisperBotErrorCode? errorCode;
}
