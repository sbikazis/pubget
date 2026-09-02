import 'package:flutter/material.dart';

import '../../features/groups/models/chat_models.dart';

/// Canonical delivery language: red failed, amber delivered, green read.
class MessageDeliveryIndicator extends StatelessWidget {
  const MessageDeliveryIndicator({
    required this.sendState,
    required this.deliveryState,
    super.key,
  });

  final ChatSendState sendState;
  final ChatDeliveryState deliveryState;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (sendState) {
      ChatSendState.pending => (const Color(0xFFC68419), 'Sending'),
      ChatSendState.failed => (const Color(0xFFB94758), 'Not delivered'),
      ChatSendState.sent => switch (deliveryState) {
        ChatDeliveryState.notDelivered => (
          const Color(0xFFB94758),
          'Not delivered',
        ),
        ChatDeliveryState.delivered => (const Color(0xFFC68419), 'Delivered'),
        ChatDeliveryState.read => (const Color(0xFF2D9D68), 'Read'),
      },
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
