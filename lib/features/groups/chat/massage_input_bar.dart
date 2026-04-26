import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/message_model.dart';
import '../../../models/member_model.dart'; // ✅ إضافة موديل العضو
import '../../../core/constants/limits.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/game_info_dialog.dart'; // ✅ إضافة الديالوج المبرمج

class MessageInputBar extends StatefulWidget {
  final Function(String text, MessageModel? replyTo) onSendText;
  final Function(File file, MessageModel? replyTo) onSendImage;
  
  // ✅ إضافة البيانات المطلوبة للديالوج
  final String groupId;
  final MemberModel currentMember;
  
  final MessageModel? replyingMessage;
  final VoidCallback? onCancelReply;
  final bool isPrivate;

  const MessageInputBar({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.groupId, // ✅
    required this.currentMember, // ✅
    this.replyingMessage,
    this.onCancelReply,
    this.isPrivate = false,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isSending = false;

  // =========================================================
  // دالة اختيار وإرسال الصور (عبر Callback)
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

      await widget.onSendImage(File(image.path), widget.replyingMessage);

      if (widget.onCancelReply != null) widget.onCancelReply!();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل معالجة الصورة.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // =========================================================
  // إرسال الرسائل النصية (عبر Callback)
  // =========================================================
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    if (text.length > Limits.maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرسالة طويلة جداً")),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await widget.onSendText(text, widget.replyingMessage);

      _controller.clear();
     
      if (widget.onCancelReply != null) widget.onCancelReply!();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل إرسال الرسالة.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // =========================================================
  // ✅ التعديل الجديد: فتح شاشة معلومات اللعبة والقواعد
  // =========================================================
  void _handleGamePressed() {
    showDialog(
      context: context,
      builder: (context) => GameInfoDialog(
        groupId: widget.groupId,
        currentMember: widget.currentMember,
      ),
    );
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
              if (!widget.isPrivate)
                IconButton(
                  icon: const Icon(Icons.videogame_asset),
                  color: AppColors.goldAccent,
                  onPressed: _handleGamePressed, // ✅ استدعاء الدالة الجديدة
                ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: Limits.maxMessageLength,
                  decoration: InputDecoration(
                    hintText: "اكتب رسالة...",
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