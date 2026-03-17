import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../providers/chat_provider.dart';
import '../../../models/member_model.dart';

import '../../../core/constants/limits.dart';
import '../../../core/theme/app_colors.dart';

class MessageInputBar extends StatefulWidget {
  final String groupId;
  final MemberModel sender;

  final VoidCallback? onMediaPressed;
  final VoidCallback? onGamePressed;
  final void Function(String text)? onSendMessage;

  const MessageInputBar({
    super.key,
    required this.groupId,
    required this.sender,
    this.onMediaPressed,
    this.onGamePressed,
    this.onSendMessage,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  final Uuid _uuid = const Uuid();

  bool _isSending = false;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    if (text.length > Limits.maxMessageLength) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Message is too long")));
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      await chatProvider.sendTextMessage(
        groupId: widget.groupId,
        messageId: _uuid.v4(),
        sender: widget.sender,
        text: text,
      );

      _controller.clear(); // مسح النص بعد الإرسال

// Scroll أو أي شيء آخر بعد الإرسال
if (widget.onSendMessage != null) {
  widget.onSendMessage!(_controller.text);
}
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("فشل إرسال الرسالة. حاول مرة أخرى."),
    ),
  );
}

    setState(() {
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final borderColor = theme.brightness == Brightness.dark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    final background = theme.brightness == Brightness.dark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          /// MEDIA BUTTON
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: AppColors.primary,
            onPressed: widget.onMediaPressed,
          ),

          /// GAME BUTTON
          IconButton(
            icon: const Icon(Icons.videogame_asset),
            color: AppColors.goldAccent,
            onPressed: widget.onGamePressed,
          ),

          /// TEXT FIELD
          Expanded(
            child: TextField(
              controller: _controller,
              maxLength: Limits.maxMessageLength,
              decoration: InputDecoration(
                hintText: "Write a message...",
                counterText: "",
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? AppColors.darkCard
                    : AppColors.lightCard,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          /// SEND BUTTON
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
