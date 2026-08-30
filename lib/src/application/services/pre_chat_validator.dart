import '../../configuration/wisperbot_config.dart';
import '../../domain/errors/wisperbot_exception.dart';
import '../../domain/models/models.dart';

/// Validates backend-required pre-chat fields without transport/UI concerns.
final class PreChatValidator {
  const PreChatValidator();

  bool isSatisfiedBy(WisperBotWidgetConfig widget, WisperBotUser? user) {
    if (user == null) return false;
    for (final field in widget.preChatFields) {
      switch (field) {
        case WisperBotPreChatField.name:
          if (user.name?.trim().isNotEmpty != true) return false;
        case WisperBotPreChatField.email:
          if (user.email?.trim().isNotEmpty != true) return false;
        case WisperBotPreChatField.unknown:
          return false;
      }
    }
    return true;
  }

  void validateConfiguration(WisperBotWidgetConfig widget) {
    if (widget.requiresPreChat && widget.preChatFields.contains(WisperBotPreChatField.unknown)) {
      throw const WisperBotException(
        code: WisperBotErrorCode.unsupported,
        message: 'This widget requires an unsupported pre-chat field.',
        retryable: false,
      );
    }
  }

  void validateSubmission(
    WisperBotWidgetConfig widget,
    WisperBotPreChatData data, {
    WisperBotUser? user,
  }) {
    final name = (data.name?.trim().isNotEmpty == true ? data.name : user?.name)?.trim() ?? '';
    final email = (data.email?.trim().isNotEmpty == true ? data.email : user?.email)?.trim() ?? '';
    if (widget.preChatFields.contains(WisperBotPreChatField.name) && name.isEmpty) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Name is required.',
        retryable: false,
        fieldErrors: <String, List<String>>{
          'name': <String>['Name is required.'],
        },
      );
    }
    if (name.length > 120) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Name must be 120 characters or fewer.',
        retryable: false,
      );
    }
    if (widget.preChatFields.contains(WisperBotPreChatField.email) && email.isEmpty) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Email is required.',
        retryable: false,
        fieldErrors: <String, List<String>>{
          'email': <String>['Email is required.'],
        },
      );
    }
    if (email.length > 190 ||
        (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Enter a valid email address.',
        retryable: false,
        fieldErrors: <String, List<String>>{
          'email': <String>['Enter a valid email address.'],
        },
      );
    }
  }
}
