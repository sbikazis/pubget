import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/providers/chat_provider.dart';

void main() {
  test('badge count is capped to 99+', () {
    expect(ChatProvider.normalizeBadgeCount(0), 0);
    expect(ChatProvider.normalizeBadgeCount(9), 9);
    expect(ChatProvider.normalizeBadgeCount(99), 99);
    expect(ChatProvider.normalizeBadgeCount(101), 99);
  });

  test('chat ids are deduplicated before unread aggregation', () {
    final ids = ['chat-1', 'chat-1', 'chat-2', 'chat-3', 'chat-2'];
    expect(ChatProvider.deduplicateChatIds(ids), ['chat-1', 'chat-2', 'chat-3']);
  });
}
