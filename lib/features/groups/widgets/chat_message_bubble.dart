import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../data/sticker_catalog.dart';
import '../models/chat_models.dart';
import '../models/group_models.dart';
import 'chat_contrast_theme.dart';
import 'chat_special_cards.dart';

/// WhatsApp-faithful group chat bubble with shrink-wrap, tails, and rich cards.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.isMine,
    required this.contrast,
    required this.onLongPress,
    this.onSwipeReply,
    this.onAvatarTap,
    required this.onMediaTap,
    this.onStickerTap,
    this.onEventTap,
    this.onGameTap,
    this.onAudioTap,
    this.onWelcomeMember,
    this.replyPreview,
    this.showSenderRole = true,
    this.showTail = true,
    this.showAvatar = true,
    this.showHeader = true,
    this.isStarred = false,
    super.key,
  });

  final ChatMessage message;
  final bool isMine;
  final ChatContrastTheme contrast;
  /// Long-press (500ms) — receives the bubble's global rect for the overlay.
  final ValueChanged<Rect> onLongPress;
  final VoidCallback? onSwipeReply;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onMediaTap;
  final VoidCallback? onStickerTap;
  final VoidCallback? onEventTap;
  final VoidCallback? onGameTap;
  final VoidCallback? onAudioTap;
  final VoidCallback? onWelcomeMember;
  final String? replyPreview;
  final bool showSenderRole;
  final bool showTail;
  final bool showAvatar;
  final bool showHeader;
  final bool isStarred;

  static const double maxWidthFraction = 0.78;
  static const double avatarSize = 32;
  static const double bubbleRadius = 10;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.game) {
      return ChatGameLobbyCard(
        message: message,
        contrast: contrast,
        onJoin: onGameTap,
      );
    }
    if (message.type == ChatMessageType.event) {
      return ChatEventCard(
        message: message,
        contrast: contrast,
        onOpen: onEventTap,
      );
    }
    if (message.isDebateCard) {
      return ChatDebateCard(
        message: message,
        contrast: contrast,
        onReply: () => onLongPress(Rect.zero),
      );
    }
    if (message.isMemberJoinedCard) {
      return ChatNewMemberCard(
        message: message,
        contrast: contrast,
        onWelcome: onWelcomeMember,
      );
    }
    if (message.type == ChatMessageType.system) {
      return _SystemChip(message: message, contrast: contrast);
    }

    final copy = AppStrings.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final maxBubble = parentW * maxWidthFraction;

        if (message.isDeleted) {
          return _DeletedBubble(
            message: message,
            isMine: isMine,
            contrast: contrast,
            maxWidth: maxBubble * 0.72,
            label: copy.messageDeleted,
            onLongPress: () => onLongPress(Rect.zero),
          );
        }

        final sticker = message.type == ChatMessageType.sticker;
        final textColor =
            isMine ? contrast.outgoingText : contrast.incomingText;
        final alignment = isMine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart;
        final avatarGap =
            (!isMine && showAvatar) ? avatarSize + 6 : 0.0;
        final bubbleMax = (maxBubble - avatarGap).clamp(120.0, parentW);

        return Semantics(
          label: '${copy.messageFrom} ${message.senderName}',
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 10,
                end: 10,
                top: 2,
                bottom: 6,
              ),
              child: _SwipeReplyDetector(
                enabled: onSwipeReply != null,
                onSwipeReply: onSwipeReply,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (!isMine && showAvatar) ...[
                      PubgetAvatar(
                        imageUrl: message.senderAvatar,
                        name: message.senderName,
                        size: PubgetAvatarSize.small,
                        onTap: onAvatarTap,
                      ),
                      const SizedBox(width: 6),
                    ] else if (!isMine && !showAvatar)
                      const SizedBox(width: avatarSize + 6),
                    ConstrainedBox(
                      key: ValueKey<String>('message-${message.id}'),
                      constraints: BoxConstraints(maxWidth: bubbleMax),
                      child: Builder(
                        builder: (bubbleContext) {
                          return _LongPress500(
                            onLongPress: () {
                              final box = bubbleContext.findRenderObject()
                                  as RenderBox?;
                              final rect = (box != null && box.hasSize)
                                  ? (box.localToGlobal(Offset.zero) &
                                      box.size)
                                  : Rect.zero;
                              onLongPress(rect);
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        message.reactions.isNotEmpty ? 10 : 0,
                                  ),
                                  child: sticker
                                      ? _StickerColumn(
                                          message: message,
                                          isMine: isMine,
                                          textColor: textColor,
                                          showSenderRole: showSenderRole,
                                          showHeader: showHeader,
                                          isStarred: isStarred,
                                          onMediaTap: onMediaTap,
                                          onStickerTap: onStickerTap,
                                        )
                                      : _BubbleChrome(
                                          isMine: isMine,
                                          contrast: contrast,
                                          showTail: showTail,
                                          child: _BubbleBody(
                                            message: message,
                                            isMine: isMine,
                                            textColor: textColor,
                                            showSenderRole: showSenderRole,
                                            showHeader: showHeader,
                                            isStarred: isStarred,
                                            replyPreview: replyPreview,
                                            onMediaTap: onMediaTap,
                                            onAudioTap: onAudioTap,
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
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BubbleChrome extends StatelessWidget {
  const _BubbleChrome({
    required this.isMine,
    required this.contrast,
    required this.showTail,
    required this.child,
  });

  final bool isMine;
  final ChatContrastTheme contrast;
  final bool showTail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = ChatMessageBubble.bubbleRadius;
    // Tail on the bottom trailing corner of the first message in a cluster.
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
      bottomLeft: Radius.circular(isMine ? radius : (showTail ? 2 : radius)),
      bottomRight: Radius.circular(isMine ? (showTail ? 2 : radius) : radius),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: isMine ? contrast.outgoingBubble : contrast.incomingBubble,
            borderRadius: borderRadius,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: contrast.shadow.withValues(alpha: 0.25),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
            child: child,
          ),
        ),
        if (showTail)
          Positioned(
            bottom: 0,
            right: isMine ? -6 : null,
            left: isMine ? null : -6,
            child: CustomPaint(
              size: const Size(8, 10),
              painter: _BubbleTailPainter(
                color: isMine
                    ? contrast.outgoingBubble
                    : contrast.incomingBubble,
                isMine: isMine,
              ),
            ),
          ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color, required this.isMine});

  final Color color;
  final bool isMine;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (isMine) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isMine != isMine;
}

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({
    required this.message,
    required this.isMine,
    required this.textColor,
    required this.showSenderRole,
    required this.showHeader,
    required this.isStarred,
    required this.replyPreview,
    required this.onMediaTap,
    required this.onAudioTap,
  });

  final ChatMessage message;
  final bool isMine;
  final Color textColor;
  final bool showSenderRole;
  final bool showHeader;
  final bool isStarred;
  final String? replyPreview;
  final VoidCallback? onMediaTap;
  final VoidCallback? onAudioTap;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showHeader)
            _SenderHeader(
              name: message.senderName,
              role: message.senderRole,
              showRole: showSenderRole,
              badgeOnly: isMine,
              alignEnd: isMine,
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
              isMine: isMine,
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
            isStarred: isStarred,
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
    required this.showHeader,
    required this.isStarred,
    required this.onMediaTap,
    this.onStickerTap,
  });

  final ChatMessage message;
  final bool isMine;
  final Color textColor;
  final bool showSenderRole;
  final bool showHeader;
  final bool isStarred;
  final VoidCallback? onMediaTap;
  final VoidCallback? onStickerTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: _SenderHeader(
                name: message.senderName,
                role: message.senderRole,
                showRole: showSenderRole,
                badgeOnly: isMine,
                alignEnd: isMine,
              ),
            ),
          _MessageContent(
            message: message,
            textColor: textColor,
            onMediaTap: onMediaTap,
            onStickerTap: onStickerTap,
            onAudioTap: null,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: _TimeStatusRow(
              message: message,
              isMine: isMine,
              textColor: textColor,
              isStarred: isStarred,
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
    this.badgeOnly = false,
    this.alignEnd = false,
  });

  final String name;
  final String role;
  final bool showRole;
  /// Own bubbles: rank badge only (no display name).
  final bool badgeOnly;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rank = parsePubgetRank(role);
    final color = rankColorResolver(rank, isDarkMode: isDark);
    final showBadge = showRole && rankShowsBubbleBadge(rank);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Align(
        alignment: alignEnd
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Badge first in Row = visual right in RTL (app default).
            if (showBadge) ...[
              _RankBadgeGlow(rank: rank, size: badgeOnly ? 18 : 16),
              if (!badgeOnly) const SizedBox(width: 4),
            ],
            if (!badgeOnly)
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rank badge with progressive glow — higher ranks shine brighter.
class _RankBadgeGlow extends StatelessWidget {
  const _RankBadgeGlow({required this.rank, this.size = 16});

  final PubgetRank rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = pubgetRankBadgeAsset(rank);
    final glow = rankBadgeGlowColor(rank);
    final strength = rankBadgeGlowStrength(rank);
    final blur = 2.0 + (strength * 10.0);
    final spread = strength * 1.4;
    final fallback = Icon(Icons.military_tech, size: size, color: glow);

    final image = asset == null
        ? fallback
        : Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback,
          );

    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glow.withValues(alpha: 0.25 + strength * 0.55),
                blurRadius: blur,
                spreadRadius: spread,
              ),
              if (strength >= 0.55)
                BoxShadow(
                  color: glow.withValues(alpha: 0.18 + strength * 0.25),
                  blurRadius: blur * 1.6,
                  spreadRadius: spread * 0.4,
                ),
            ],
          ),
          child: image,
        ),
      ),
    );
  }
}

Color roleColor(String role, {bool isDarkMode = false}) =>
    rankColorForRoleString(role, isDarkMode: isDarkMode);

class _TimeStatusRow extends StatelessWidget {
  const _TimeStatusRow({
    required this.message,
    required this.isMine,
    required this.textColor,
    required this.isStarred,
  });

  final ChatMessage message;
  final bool isMine;
  final Color textColor;
  final bool isStarred;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final muted = textColor.withValues(alpha: 0.65);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isStarred) ...[
            Icon(Icons.star, size: 12, color: muted),
            const SizedBox(width: 3),
          ],
          if (message.disappearing) ...[
            Icon(Icons.timer_outlined, size: 12, color: muted),
            const SizedBox(width: 3),
          ],
          Text(
            formatChatTime(message.createdAt, copy),
            style: TextStyle(color: muted, fontSize: 11, height: 1),
          ),
          if (message.editedAt != null)
            Text(
              ' · ${copy.edited}',
              style: TextStyle(color: muted, fontSize: 11, height: 1),
            ),
          if (isMine) ...[
            const SizedBox(width: 3),
            MessageDeliveryIndicator(
              sendState: message.sendState,
              deliveryState: message.deliveryState,
              size: 14,
            ),
          ],
        ],
      ),
    );
  }
}

String formatChatTime(DateTime? value, AppStrings copy) {
  if (value == null) return '';
  final local = value.toLocal();
  final hour24 = local.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final isAr = copy.locale.languageCode == 'ar';
  final suffix = hour24 >= 12
      ? (isAr ? 'م' : 'PM')
      : (isAr ? 'ص' : 'AM');
  return '$hour12:$minute $suffix';
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.text,
    required this.textColor,
    required this.isMine,
  });

  final String text;
  final Color textColor;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: isMine
              ? BorderSide.none
              : BorderSide(color: textColor.withValues(alpha: 0.55), width: 3),
          right: isMine
              ? BorderSide(color: textColor.withValues(alpha: 0.55), width: 3)
              : BorderSide.none,
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor.withValues(alpha: 0.85),
          fontSize: 12.5,
          height: 1.3,
        ),
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
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (isMine ? contrast.outgoingBubble : contrast.incomingBubble)
                .withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
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
    this.onStickerTap,
    this.onAudioTap,
  });

  final ChatMessage message;
  final Color textColor;
  final VoidCallback? onMediaTap;
  final VoidCallback? onStickerTap;
  final VoidCallback? onAudioTap;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    if (message.isCatalogSticker) {
      return InkWell(
        key: const Key('sticker-tap-target'),
        onTap: onStickerTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: StickerMark(stickerKey: message.stickerKey ?? '', size: 112),
        ),
      );
    }
    if (message.type == ChatMessageType.audio) {
      return _VoiceBubble(
        message: message,
        textColor: textColor,
        onTap: onAudioTap,
        label: copy.voiceMessage,
      );
    }
    if (message.type == ChatMessageType.sticker) {
      return InkWell(
        key: const Key('sticker-tap-target'),
        onTap: onStickerTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 140,
          height: 140,
          child: AppImageLoader(
            imageUrl: message.thumbnailUrl ?? message.mediaUrl ?? '',
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    if (message.type == ChatMessageType.image ||
        message.type == ChatMessageType.video ||
        message.type == ChatMessageType.gif) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: onMediaTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    AppImageLoader(
                      imageUrl: message.thumbnailUrl ?? message.mediaUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                    if (message.type == ChatMessageType.video)
                      const Center(
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0x99000000),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    if (message.type == ChatMessageType.video)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'VIDEO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if ((message.text ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            FormattedChatText(text: message.text!, color: textColor),
          ],
        ],
      );
    }
    return FormattedChatText(
      text: message.text?.trim().isNotEmpty == true
          ? message.text!
          : '',
      color: textColor,
    );
  }
}

class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({
    required this.message,
    required this.textColor,
    required this.onTap,
    required this.label,
  });

  final ChatMessage message;
  final Color textColor;
  final VoidCallback? onTap;
  final String label;

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  var _playing = false;
  var _speed = 1.0;
  final _levels = List<double>.generate(
    28,
    (i) => 0.25 + math.sin(i * 0.55).abs() * 0.75,
  );

  @override
  Widget build(BuildContext context) {
    final active = _playing ? const Color(0xFF53BDEB) : widget.textColor;
    return InkWell(
      onTap: () {
        setState(() => _playing = !_playing);
        widget.onTap?.call();
      },
      child: SizedBox(
        width: 220,
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 16,
              backgroundColor: active.withValues(alpha: 0.18),
              child: Icon(
                _playing ? Icons.pause : Icons.play_arrow,
                color: active,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    height: 28,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        for (final level in _levels)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 0.8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                height: 6 + level * (_playing ? 20 : 14),
                                decoration: BoxDecoration(
                                  color: active.withValues(
                                    alpha: _playing ? 0.95 : 0.55,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.textColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                setState(() {
                  _speed = _speed == 1
                      ? 1.5
                      : _speed == 1.5
                          ? 2
                          : 1;
                });
              },
              child: Text(
                _speed == 1
                    ? '1x'
                    : _speed == 1.5
                        ? '1.5x'
                        : '2x',
                style: TextStyle(
                  color: active,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Supports *bold*, _italic_, ~strike~, `code`.
class FormattedChatText extends StatelessWidget {
  const FormattedChatText({required this.text, required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _parse(text, color)),
      style: TextStyle(color: color, fontSize: 15.5, height: 1.35),
    );
  }

  static List<InlineSpan> _parse(String input, Color color) {
    final pattern = RegExp(
      r'(\*[^*\n]+\*|_[^_\n]+_|~[^~\n]+~|`[^`\n]+`)',
    );
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in pattern.allMatches(input)) {
      if (match.start > start) {
        spans.add(TextSpan(text: input.substring(start, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('*')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('_')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (token.startsWith('~')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        );
      }
      start = match.end;
    }
    if (start < input.length) {
      spans.add(TextSpan(text: input.substring(start)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: input));
    return spans;
  }
}

class _SystemChip extends StatelessWidget {
  const _SystemChip({required this.message, required this.contrast});

  final ChatMessage message;
  final ChatContrastTheme contrast;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final label = (message.text ?? '').trim().isNotEmpty
        ? message.text!
        : copy.groupUpdate;
    return ChatDateDivider(label: label);
  }
}

class _LongPress500 extends StatelessWidget {
  const _LongPress500({required this.onLongPress, required this.child});

  final VoidCallback onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.deferToChild,
      gestures: <Type, GestureRecognizerFactory>{
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: const Duration(milliseconds: 500),
          ),
          (instance) {
            instance.onLongPress = onLongPress;
          },
        ),
      },
      child: child,
    );
  }
}

class _SwipeReplyDetector extends StatelessWidget {
  const _SwipeReplyDetector({
    required this.enabled,
    required this.onSwipeReply,
    required this.child,
  });

  final bool enabled;
  final VoidCallback? onSwipeReply;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() >= 800) {
          onSwipeReply?.call();
        }
      },
      child: child,
    );
  }
}
