import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/chat_models.dart';
import 'chat_contrast_theme.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.isMine,
    required this.contrast,
    required this.onLongPress,
    required this.onMediaTap,
    this.showSenderRole = true,
    super.key,
  });

  final ChatMessage message;
  final bool isMine;
  final ChatContrastTheme contrast;
  final VoidCallback onLongPress;
  final VoidCallback? onMediaTap;
  final bool showSenderRole;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.system ||
        message.type == ChatMessageType.event ||
        message.type == ChatMessageType.game) {
      return _SystemCard(message: message, contrast: contrast);
    }
    final sticker = message.type == ChatMessageType.sticker;
    final textColor = isMine ? contrast.outgoingText : contrast.incomingText;
    return Semantics(
      label: 'Message from ${message.senderName}',
      child: Align(
        alignment: isMine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            key: ValueKey<String>('message-${message.id}'),
            constraints: const BoxConstraints(maxWidth: 390),
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            padding: sticker
                ? const EdgeInsets.symmetric(vertical: AppSpacing.xs)
                : const EdgeInsets.all(AppSpacing.md),
            decoration: sticker
                ? null
                : BoxDecoration(
                    color: isMine
                        ? contrast.outgoingBubble
                        : contrast.incomingBubble,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: contrast.border),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: contrast.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!isMine) ...[
                  PubgetAvatar(
                    imageUrl: message.senderAvatar,
                    name: message.senderName,
                    size: PubgetAvatarSize.small,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              message.senderName,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: _roleColor(message.senderRole),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          if (showSenderRole)
                            PubgetBadge(label: message.senderRole),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _MessageContent(
                        message: message,
                        textColor: textColor,
                        onMediaTap: onMediaTap,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _time(message.createdAt),
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(color: textColor),
                          ),
                          if (message.editedAt != null)
                            Text(
                              ' · edited',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: textColor),
                            ),
                          if (isMine) ...[
                            const SizedBox(width: AppSpacing.xs),
                            _DeliveryDot(message: message),
                          ],
                        ],
                      ),
                      if (message.reactions.isNotEmpty)
                        Wrap(
                          spacing: AppSpacing.xs,
                          children: message.reactions.entries
                              .where((entry) => entry.value > 0)
                              .map(
                                (entry) => Text(
                                  '${entry.key} ${entry.value}',
                                  style: TextStyle(color: textColor),
                                ),
                              )
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role) => switch (role) {
    'founder' => const Color(0xFFD8A838),
    'shogun' => const Color(0xFFE06B86),
    'commander' => const Color(0xFF4EB7D8),
    'captain' => const Color(0xFF6DCB91),
    _ => const Color(0xFF9B75E8),
  };

  String _time(DateTime? value) {
    if (value == null) return 'now';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.textColor,
    required this.onMediaTap,
  });

  final ChatMessage message;
  final Color textColor;
  final VoidCallback? onMediaTap;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        'Message deleted',
        style: TextStyle(color: textColor, fontStyle: FontStyle.italic),
      );
    }
    if (message.type == ChatMessageType.image ||
        message.type == ChatMessageType.video ||
        message.type == ChatMessageType.gif ||
        message.type == ChatMessageType.sticker) {
      return InkWell(
        onTap: onMediaTap,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            AppImageLoader(
              imageUrl: message.thumbnailUrl ?? message.mediaUrl ?? '',
              width: 280,
              height: message.type == ChatMessageType.sticker ? 190 : 220,
              memCacheWidth: 560,
              memCacheHeight: 440,
              fit: BoxFit.contain,
              borderRadius: message.type == ChatMessageType.sticker
                  ? null
                  : BorderRadius.circular(AppRadius.sm),
            ),
            if (message.type == ChatMessageType.video)
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 36),
                ),
              ),
          ],
        ),
      );
    }
    if (message.type == ChatMessageType.audio) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.play_circle_fill, color: textColor),
          const SizedBox(width: AppSpacing.sm),
          Text('Voice message', style: TextStyle(color: textColor)),
        ],
      );
    }
    return Text(message.text ?? '', style: TextStyle(color: textColor));
  }
}

class _DeliveryDot extends StatelessWidget {
  const _DeliveryDot({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (message.sendState) {
      ChatSendState.pending => (Colors.orange, 'Sending'),
      ChatSendState.failed => (Colors.red, 'Not delivered'),
      ChatSendState.sent => switch (message.deliveryState) {
        ChatDeliveryState.notDelivered => (Colors.red, 'Not delivered'),
        ChatDeliveryState.delivered => (Colors.amber, 'Delivered'),
        ChatDeliveryState.read => (Colors.green, 'Read'),
      },
    };
    return Tooltip(
      message: label,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.message, required this.contrast});

  final ChatMessage message;
  final ChatContrastTheme contrast;

  @override
  Widget build(BuildContext context) {
    final label = switch (message.type) {
      ChatMessageType.event => 'Event card',
      ChatMessageType.game => 'Game card',
      _ => 'Group update',
    };
    return Center(
      child: Container(
        key: ValueKey<String>('message-${message.id}'),
        margin: const EdgeInsets.all(AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: contrast.incomingBubble,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: contrast.border),
        ),
        child: Text(
          message.text?.isNotEmpty == true ? message.text! : label,
          style: TextStyle(color: contrast.incomingText),
        ),
      ),
    );
  }
}
