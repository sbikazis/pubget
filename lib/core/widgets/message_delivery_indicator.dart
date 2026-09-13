import 'package:flutter/material.dart';

import '../../features/groups/models/chat_models.dart';
import '../l10n/app_strings.dart';

/// WhatsApp-style receipts:
/// pending → clock, sent → single red ✓, delivered → yellow ✓✓, read → green ✓✓
class MessageDeliveryIndicator extends StatelessWidget {
  const MessageDeliveryIndicator({
    required this.sendState,
    required this.deliveryState,
    this.size = 14,
    super.key,
  });

  final ChatSendState sendState;
  final ChatDeliveryState deliveryState;
  final double size;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final (icon, color, label) = switch (sendState) {
      ChatSendState.pending => (
          Icons.access_time,
          const Color(0xFF8696A0),
          copy.sending,
        ),
      ChatSendState.failed => (
          Icons.error_outline,
          const Color(0xFFE53935),
          copy.notDelivered,
        ),
      ChatSendState.sent => switch (deliveryState) {
          ChatDeliveryState.notDelivered => (
              Icons.done,
              const Color(0xFFE53935),
              copy.notDelivered,
            ),
          ChatDeliveryState.delivered => (
              Icons.done_all,
              const Color(0xFFF2C94C),
              copy.delivered,
            ),
          ChatDeliveryState.read => (
              Icons.done_all,
              const Color(0xFF00A884),
              copy.read,
            ),
        },
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
