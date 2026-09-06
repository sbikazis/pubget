import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../data/sticker_catalog.dart';
import '../models/chat_models.dart';
import 'chat_contrast_theme.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.isMine,
    required this.contrast,
    required this.onLongPress,
    required this.onMediaTap,
    this.onEventTap,
    this.onGameTap,
    this.onAudioTap,
    this.replyPreview,
    this.showSenderRole = true,
    super.key,
  });

  final ChatMessage message;
  final bool isMine;
  final ChatContrastTheme contrast;
  final VoidCallback onLongPress;
  final VoidCallback? onMediaTap;
  final VoidCallback? onEventTap;
  final VoidCallback? onGameTap;
  final VoidCallback? onAudioTap;
  final String? replyPreview;
  final bool showSenderRole;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.system ||
        message.type == ChatMessageType.event ||
        message.type == ChatMessageType.game) {
      return _SystemCard(
        message: message,
        contrast: contrast,
        onTap: message.type == ChatMessageType.event
            ? onEventTap
            : message.type == ChatMessageType.game
            ? onGameTap
            : null,
      );
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
                      if (message.forwardedFrom != null)
                        Text(
                          'Forwarded',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: textColor,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      if ((replyPreview ?? message.replyPreview) != null) ...[
                        _ReplyQuote(
                          text: replyPreview ?? message.replyPreview!,
                          textColor: textColor,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      _MessageContent(
                        message: message,
                        textColor: textColor,
                        onMediaTap: onMediaTap,
                        onAudioTap: onAudioTap,
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
                            MessageDeliveryIndicator(
                              sendState: message.sendState,
                              deliveryState: message.deliveryState,
                            ),
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
    this.onAudioTap,
  });

  final ChatMessage message;
  final Color textColor;
  final VoidCallback? onMediaTap;
  final VoidCallback? onAudioTap;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        'Message deleted',
        style: TextStyle(color: textColor, fontStyle: FontStyle.italic),
      );
    }
    if (message.isCatalogSticker) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: StickerMark(stickerKey: message.stickerKey ?? '', size: 112),
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
      return InkWell(
        key: Key('audio-play-${message.id}'),
        onTap: onAudioTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.play_circle_fill, color: textColor),
            const SizedBox(width: AppSpacing.sm),
            Text('Voice message', style: TextStyle(color: textColor)),
          ],
        ),
      );
    }
    return Text(message.text ?? '', style: TextStyle(color: textColor));
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.text, required this.textColor});

  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: textColor, width: 3)),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: textColor),
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({
    required this.message,
    required this.contrast,
    this.onTap,
  });

  final ChatMessage message;
  final ChatContrastTheme contrast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (message.type) {
      ChatMessageType.event => 'Event card',
      ChatMessageType.game => 'Game card',
      _ => 'Group update',
    };
    final action = message.type == ChatMessageType.game
        ? (message.gameActivity?.actionLabel ?? 'Open')
        : null;
    return Center(
      child: GestureDetector(
        onTap: onTap,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                message.text?.isNotEmpty == true ? message.text! : label,
                style: TextStyle(color: contrast.incomingText),
              ),
              if (action != null && onTap != null) ...[
                const SizedBox(height: 4),
                Text(
                  action,
                  style: TextStyle(
                    color: contrast.incomingText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
