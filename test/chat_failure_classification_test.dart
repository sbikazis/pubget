import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/groups/services/chat_send_reliability.dart';

void main() {
  group('chat failure codes', () {
    test('a service outage is never reported as a lost connection', () {
      expect(
        chatFailureCode(const UnavailableError('chat_unavailable')),
        ChatFailureCodes.serviceUnavailable,
      );
      expect(
        chatFailureCode(const UnknownError('chat_unknown')),
        ChatFailureCodes.unknown,
      );
      expect(
        chatFailureCode(const NetworkError('chat_network')),
        ChatFailureCodes.network,
      );
    });

    test('transient codes stay distinct for honest retry copy', () {
      expect(chatFailureCode(const TimeoutError()), ChatFailureCodes.timeout);
      expect(
        chatFailureCode(const RateLimitedError()),
        ChatFailureCodes.rateLimited,
      );
      expect(
        chatFailureCode(const TransactionConflictError()),
        ChatFailureCodes.serviceUnavailable,
      );
    });
  });
}
