import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../data/sticker_catalog.dart';
import '../models/chat_models.dart';
import 'chat_contrast_theme.dart';

/// WhatsApp-style group chat bubble — shrink-wrap width, RTL-aware alignment.
///
/// Built from scratch for prompt 49 corrective: never expands to full screen
/// width; avatar + name/role on one line for others; time + delivery inline;
/// reactions as overlapping edge pills; deleted as a compact Arabic state.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.isMine,
    required this.contrast,
    required this.onLongPress,
    this.onAvatarTap,
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
  final VoidCallback? onAvatarTap;
  final VoidCallback? onMediaTap;
  final VoidCallback? onEventTap;
  final VoidCallback? onGameTap;
  final VoidCallback? onAudioTap;
  final String? replyPreview;
  final bool showSenderRole;

  static const double _maxWidthFraction = 0.78;
  static const double _avatarSize = 32;
  static const double _bubbleRadius = 14;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.system ||
        message.type == ChatMessageType.event ||
        message.type == ChatMessageType.game) {
      return _SystemChip(
        message: message,
        contrast: contrast,
        onTap: message.type == ChatMessageType.event
            ? onEventTap
            : message.type == ChatMessageType.game
                ? onGameTap
                : null,
      );
    }

    final copy = AppStrings.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final parentW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final maxBubble = parentW * _maxWidthFraction;

        if (message.isDeleted) {
          return _DeletedBubble(
            message: message,
            isMine: isMine,
            contrast: contrast,
            maxWidth: maxBubble * 0.72,
            label: copy.messageDeleted,
            onLongPress: onLongPress,
          );
        }

        final sticker = message.type == ChatMessageType.sticker;
        final textColor =
            isMine ? contrast.outgoingText : contrast.incomingText;
        final alignment = isMine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart;
        final avatarGap = isMine ? 0.0 : _avatarSize + 6;
        final bubbleMax = (maxBubble - avatarGap).clamp(120.0, parentW);

        return Semantics(
          label: '${copy.messageFrom} ${message.senderName}',
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.sm,
                end: AppSpacing.sm,
                top: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (!isMine) ...[
                    PubgetAvatar(
                      imageUrl: message.senderAvatar,
                      name: message.senderName,
                      size: PubgetAvatarSize.small,
                      onTap: onAvatarTap,
                    ),
                    const SizedBox(width: 6),
                  ],
                  ConstrainedBox(
                    key: ValueKey<String>('message-${message.id}'),
                    constraints: BoxConstraints(maxWidth: bubbleMax),
                    child: GestureDetector(
                      onLongPress: onLongPress,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: message.reactions.isNotEmpty ? 10 : 0,
                            ),
                            child: sticker
                                ? _StickerColumn(
                                    message: message,
                                    isMine: isMine,
                                    textColor: textColor,
                                    showSenderRole: showSenderRole,
                                    onMediaTap: onMediaTap,
                                  )
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? contrast.outgoingBubble
                                          : contrast.incomingBubble,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(
                                          _bubbleRadius,
                                        ),
                                        topRight: const Radius.circular(
                                          _bubbleRadius,
                                        ),
                                        bottomLeft: Radius.circular(
                                          isMine ? _bubbleRadius : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          isMine ? 4 : _bubbleRadius,
                                        ),
                                      ),
                                      border: Border.all(
                                        color: contrast.border,
                                        width: 0.6,
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: contrast.shadow,
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        6,
                                        10,
                                        5,
                                      ),
                                      child: _BubbleBody(
                                        message: message,
                                        isMine: isMine,
                                        textColor: textColor,
                                        showSenderRole: showSenderRole,
                                        replyPreview: replyPreview,
                                        onMediaTap: onMediaTap,
                                        onAudioTap: onAudioTap,
                                      ),
                                    ),
                                  ),
                          ),
                          if (message.reactions.isNotEmpty)
                            PositionedDirectional(
                              start: isMine ? null : 8,
                              end: isMine ? 8 : null,
                              bottom: -2,
                              child: _ReactionPills(
                                reactions: message.reactions,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({
    required this.message,
    required this.isMine,
    required this.textColor,
    required this.showSenderRole,
    required this.replyPreview,
    required this.onMediaTap,
    required this.onAudioTap,
  });

  final ChatMessage message;
  final bool isMine;
  final Color textColor;
  final bool showSenderRole;
  final String? replyPreview;
  final VoidCallback? onMediaTap;
  final VoidCallback? onAudioTap;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    // IntrinsicWidth keeps the bubble shrink-wrapped to content while still
    // allowing the time row to sit on the trailing edge (WhatsApp layout).
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!isMine)
            _SenderHeader(
              name: message.senderName,
              role: message.senderRole,
              showRole: showSenderRole,
            ),
          if (message.forwardedFrom != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                copy.forwarded,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: textColor.withValues(alpha: 0.75),
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                    ),
              ),
            ),
          if ((replyPreview ?? message.replyPreview) != null) ...[
            _ReplyQuote(
              text: replyPreview ?? message.replyPreview!,
              textColor: textColor,
            ),
            const SizedBox(height: 4),
          ],
          _MessageContent(
            message: message,
            textColor: textColor,
            onMediaTap: onMediaTap,
            onAudioTap: onAudioTap,
          ),
          const SizedBox(height: 2),
          _TimeStatusRow(
            message: message,
            isMine: isMine,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
}

class _StickerColumn extends StatelessWidget {
  const _StickerColumn({
    required this.message,
    required this.isMine,
    required this.textColor,
    required this.showSenderRole,
    required this.onMediaTap,
  });

  final ChatMessage message;
  final bool isMine;
  final Color textColor;
  final bool showSenderRole;
  final VoidCallback? onMediaTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: _SenderHeader(
                name: message.senderName,
                role: message.senderRole,
                showRole: showSenderRole,
              ),
            ),
          _MessageContent(
            message: message,
            textColor: textColor,
            onMediaTap: onMediaTap,
            onAudioTap: null,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: _TimeStatusRow(
              message: message,
              isMine: isMine,
              textColor: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SenderHeader extends StatelessWidget {
  const _SenderHeader({
    required this.name,
    required this.role,
    required this.showRole,
  });

  final String name;
  final String role;
  final bool showRole;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    final copy = AppStrings.of(context);
    // No Flexible — Flexible expands the bubble to maxWidth (card look).
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.15,
                ),
          ),
          if (showRole) ...[
            const SizedBox(width: 4),
            _InlineRoleChip(label: copy.roleLabel(role), color: color),
          ],
        ],
      ),
    );
  }
}

class _InlineRoleChip extends StatelessWidget {
  const _InlineRoleChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _TimeStatusRow extends StatelessWidget {
  const _TimeStatusRow({
    required this.message,
    required this.isMine,
    required this.textColor,
  });

  final ChatMessage message;
  final bool isMine;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final muted = textColor.withValues(alpha: 0.72);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _formatTime(message.createdAt, copy),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: muted,
                  fontSize: 10.5,
                  height: 1,
                ),
          ),
          if (message.editedAt != null)
            Text(
              ' · ${copy.edited}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontSize: 10.5,
                    height: 1,
                  ),
            ),
          if (isMine) ...[
            const SizedBox(width: 4),
            MessageDeliveryIndicator(
              sendState: message.sendState,
              deliveryState: message.deliveryState,
              size: 8,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReactionPills extends StatelessWidget {
  const _ReactionPills({required this.reactions});

  final Map<String, int> reactions;

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries
        .where((e) => e.value > 0)
        .toList(growable: false);
    if (entries.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xE61A1A1E),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    '${entry.key}${entry.value > 1 ? ' ${entry.value}' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _DeletedBubble extends StatelessWidget {
  const _DeletedBubble({
    required this.message,
    required this.isMine,
    required this.contrast,
    required this.maxWidth,
    required this.label,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool isMine;
  final ChatContrastTheme contrast;
  final double maxWidth;
  final String label;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final textColor = (isMine ? contrast.outgoingText : contrast.incomingText)
        .withValues(alpha: 0.65);
    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          key: ValueKey<String>('message-${message.id}'),
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (isMine ? contrast.outgoingBubble : contrast.incomingBubble)
                .withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: contrast.border.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 12.5,
                ),
          ),
        ),
      ),
    );
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
    final copy = AppStrings.of(context);
    if (message.isCatalogSticker) {
      return Padding(
        padding: const EdgeInsets.all(2),
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
              width: 220,
              height: message.type == ChatMessageType.sticker ? 160 : 180,
              memCacheWidth: 440,
              memCacheHeight: 360,
              fit: BoxFit.cover,
              borderRadius: message.type == ChatMessageType.sticker
                  ? null
                  : BorderRadius.circular(8),
            ),
            if (message.type == ChatMessageType.video)
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 32),
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
            Icon(Icons.play_circle_fill, color: textColor, size: 28),
            const SizedBox(width: 6),
            Text(
              copy.voiceMessage,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Text(
      message.text ?? '',
      textWidthBasis: TextWidthBasis.longestLine,
      style: TextStyle(
        color: textColor,
        fontSize: 15,
        height: 1.35,
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.text, required this.textColor});

  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: textColor.withValues(alpha: 0.7), width: 2.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textWidthBasis: TextWidthBasis.longestLine,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor.withValues(alpha: 0.9),
                fontSize: 12,
              ),
        ),
      ),
    );
  }
}

class _SystemChip extends StatelessWidget {
  const _SystemChip({
    required this.message,
    required this.contrast,
    this.onTap,
  });

  final ChatMessage message;
  final ChatContrastTheme contrast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final label = switch (message.type) {
      ChatMessageType.event => copy.eventCard,
      ChatMessageType.game => copy.gameCard,
      _ => copy.groupUpdate,
    };
    final action = message.type == ChatMessageType.game
        ? (message.gameActivity?.actionLabel ?? copy.open)
        : null;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: ValueKey<String>('message-${message.id}'),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: contrast.incomingBubble.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: contrast.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                message.text?.isNotEmpty == true ? message.text! : label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: contrast.incomingText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (action != null && onTap != null) ...[
                const SizedBox(height: 2),
                Text(
                  action,
                  style: TextStyle(
                    color: contrast.incomingText.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
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

Color _roleColor(String role) => switch (role) {
      'founder' => const Color(0xFFD8A838),
      'shogun' => const Color(0xFFE06B86),
      'commander' => const Color(0xFF4EB7D8),
      'captain' => const Color(0xFF6DCB91),
      'sensei' => const Color(0xFF9B75E8),
      'senpai' => const Color(0xFF7AA2F7),
      _ => const Color(0xFF9B75E8),
    };

String _formatTime(DateTime? value, AppStrings copy) {
  if (value == null) return copy.now;
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
