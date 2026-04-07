import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

import '../../../providers/chat_provider.dart';
import '../../../models/member_model.dart';
import '../../../models/message_model.dart';

import '../../../core/constants/limits.dart';
import '../../../core/theme/app_colors.dart';

class MessageInputBar extends StatefulWidget {
  final String groupId;
  final MemberModel sender;

  final VoidCallback? onMediaPressed;
  final VoidCallback? onGamePressed;
  final void Function(String text)? onSendMessage;
  
  // ✅ الحقول الجديدة لدعم الرد
  final MessageModel? replyingMessage;
  final VoidCallback? onCancelReply;

  const MessageInputBar({
    super.key,
    required this.groupId,
    required this.sender,
    this.onMediaPressed,
    this.onGamePressed,
    this.onSendMessage,
    this.replyingMessage,
    this.onCancelReply,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  final Uuid _uuid = const Uuid();
  final ImagePicker _picker = ImagePicker();

  bool _isSending = false;

  // =========================================================
  // دالة اختيار وإرسال الصور (مع دعم الرد)
  // =========================================================
  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() {
        _isSending = true;
      });

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      await chatProvider.sendMediaMessage(
        groupId: widget.groupId,
        messageId: _uuid.v4(),
        sender: widget.sender,
        file: File(image.path),
        mediaType: 'image',
        // ✅ تمرير بيانات الرد إذا وجدت
        replyToId: widget.replyingMessage?.id,
        replyText: widget.replyingMessage?.text ?? (widget.replyingMessage?.mediaType == 'image' ? "صورة 🖼️" : null),
      );

      // إلغاء وضع الرد بعد الإرسال الناجح
      if (widget.onCancelReply != null) widget.onCancelReply!();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل رفع الصورة. تأكد من الاتصال.")),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  // =========================================================
  // إرسال الرسائل النصية (مع دعم الرد)
  // =========================================================
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    if (text.length > Limits.maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message is too long")),
      );
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
        // ✅ تمرير بيانات الرد لربط الرسالة الجديدة بالقديمة
        replyToId: widget.replyingMessage?.id,
        replyText: widget.replyingMessage?.text ?? (widget.replyingMessage?.mediaType == 'image' ? "صورة 🖼️" : null),
      );

      _controller.clear();

      if (widget.onSendMessage != null) {
        widget.onSendMessage!(text);
      }
      
      // ✅ إلغاء وضع الرد بعد الإرسال
      if (widget.onCancelReply != null) widget.onCancelReply!();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل إرسال الرسالة. حاول مرة أخرى.")),
      );
    }

    setState(() {
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final background = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ واجهة الرد (تظهر فقط عند وجود رسالة للرد عليها)
        if (widget.replyingMessage != null) _buildReplyPreview(isDark),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                color: AppColors.primary,
                onPressed: _isSending ? null : _pickAndSendImage,
              ),
              IconButton(
                icon: const Icon(Icons.videogame_asset),
                color: AppColors.goldAccent,
                onPressed: widget.onGamePressed,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: Limits.maxMessageLength,
                  decoration: InputDecoration(
                    hintText: "Write a message...",
                    counterText: "",
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
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
        ),
      ],
    );
  }

  // ✅ بناء شريط الرد المعلق فوق صندوق الإدخال
  Widget _buildReplyPreview(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[200],
        border: const Border(
          right: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.replyingMessage!.senderName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  widget.replyingMessage!.text ?? 
                  (widget.replyingMessage!.mediaType == 'image' ? "صورة 🖼️" : "رسالة وسائط"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }
}