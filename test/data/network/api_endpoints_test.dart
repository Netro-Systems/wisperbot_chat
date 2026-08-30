import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/src/data/network/api_endpoints.dart';

void main() {
  test('lists every visitor API endpoint', () {
    expect(ApiEndpoints.session, '/widget/v1/session');
    expect(ApiEndpoints.messages, '/widget/v1/messages');
    expect(ApiEndpoints.typing, '/widget/v1/typing');
    expect(ApiEndpoints.handoff, '/widget/v1/handoff');
  });

  test('resolves endpoints without discarding a custom base path', () {
    final endpoint = ApiEndpoints.resolve(
      Uri.parse('https://chat.example.test/custom/base/'),
      ApiEndpoints.session,
    );

    expect(endpoint.toString(), 'https://chat.example.test/custom/base/widget/v1/session');
  });
}
