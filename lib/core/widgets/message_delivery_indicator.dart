import 'package:flutter/material.dart';

import '../../features/groups/models/chat_models.dart';
import '../l10n/app_strings.dart';

/// Canonical delivery language: red failed, amber delivered, green read.
class MessageDeliveryIndicator extends StatelessWidget {
  const MessageDeliveryIndicator({
    required this.sendState,
    required this.deliveryState,
    this.size = 9,
    super.key,
  });

  final ChatSendState sendState;
  final ChatDeliveryState deliveryState;
  final double size;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final (color, label) = switch (sendState) {
      ChatSendState.pending => (const Color(0xFFC68419), copy.sending),
      ChatSendState.failed => (const Color(0xFFB94758), copy.notDelivered),
      ChatSendState.sent => switch (deliveryState) {
          ChatDeliveryState.notDelivered => (
              const Color(0xFFB94758),
              copy.notDelivered,
            ),
          ChatDeliveryState.delivered => (
              const Color(0xFFC68419),
              copy.delivered,
            ),
          ChatDeliveryState.read => (const Color(0xFF2D9D68), copy.read),
        },
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
