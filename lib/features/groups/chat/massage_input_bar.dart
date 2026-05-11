import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/message_model.dart';
import '../../../models/member_model.dart';
import '../../../core/constants/limits.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/game_info_dialog.dart';
import '../../../widgets/gif_picker_sheet.dart';

class MessageInputBar extends StatefulWidget {
  final Function(String text, MessageModel? replyTo) onSendText;
  final Function(File file, MessageModel? replyTo) onSendImage;
  final Function(String gifUrl, MessageModel? replyTo)? onSendGif;
  final Function(File audioFile, MessageModel? replyTo)? onSendAudio;
  final String groupId;
  final MemberModel currentMember;
  final MessageModel? replyingMessage;
  final VoidCallback? onCancelReply;
  final bool isPrivate;

  const MessageInputBar({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    this.onSendGif,
    this.onSendAudio,
    required this.groupId,
    required this.currentMember,
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
  final AudioRecorder _recorder = AudioRecorder();

  bool _isSending = false;
  bool _isRecording = false;
  String? _recordingPath;

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;
      setState(() => _isSending = true);
      await widget.onSendImage(File(image.path), widget.replyingMessage);
      if (widget.onCancelReply != null) widget.onCancelReply!();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل معالجة الصورة.")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _openGifPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GifPickerSheet(
        onGifSelected: (gifUrl) async {
          if (widget.onSendGif != null) {
            setState(() => _isSending = true);
            try {
              await widget.onSendGif!(gifUrl, widget.replyingMessage);
              if (widget.onCancelReply != null) widget.onCancelReply!();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("فشل إرسال GIF.")));
              }
            } finally {
              if (mounted) setState(() => _isSending = false);
            }
          }
        },
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (text.length > Limits.maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرسالة طويلة جداً")));
      return;
    }
    setState(() => _isSending = true);
    try {
      await widget.onSendText(text, widget.replyingMessage);
      _controller.clear();
      if (widget.onCancelReply != null) widget.onCancelReply!();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل إرسال الرسالة.")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("لا يوجد إذن للميكروفون.")),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _recordingPath = path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("فشل بدء التسجيل.")),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path == null || widget.onSendAudio == null) return;
      final file = File(path);
      if (!await file.exists()) return;
      setState(() => _isSending = true);
      await widget.onSendAudio!(file, widget.replyingMessage);
      if (widget.onCancelReply != null) widget.onCancelReply!();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("فشل إرسال التسجيل.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
      _recordingPath = null;
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    try {
      await _recorder.stop();
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingPath = null;
      });
    }
  }

  void _handleGamePressed() async {
    final activeGames = await FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(widget.groupId))
        .where('status', whereIn: ['waitingForOpponent', 'setup', 'guessing'])
        .get();
    if (activeGames.docs.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("المجموعة ممتلئة، هناك لعبتان قيد التنفيذ حالياً."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => GameInfoDialog(groupId: widget.groupId, currentMember: widget.currentMember),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final background = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final bool showMic = _controller.text.trim().isEmpty && !_isRecording;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.replyingMessage != null) _buildReplyPreview(isDark),
        if (_isRecording) _buildRecordingIndicator(isDark),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_isRecording) ...[
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  color: AppColors.primary,
                  onPressed: _isSending ? null : _pickAndSendImage,
                ),
                IconButton(
                  icon: const Icon(Icons.gif_box_outlined),
                  color: AppColors.primary,
                  onPressed: _isSending ? null : _openGifPicker,
                  tooltip: 'GIF',
                ),
                if (!widget.isPrivate)
                  IconButton(
                    icon: const Icon(Icons.videogame_asset),
                    color: AppColors.goldAccent,
                    onPressed: _handleGamePressed,
                  ),
              ],
              if (_isRecording)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _cancelRecording,
                  tooltip: 'إلغاء التسجيل',
                ),
              Expanded(
                child: _isRecording
                    ? const SizedBox.shrink()
                    : TextField(
                        controller: _controller,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 1,
                        maxLines: 6,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        maxLength: Limits.maxMessageLength,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 15.5, height: 1.4),
                        decoration: InputDecoration(
                          hintText: "اكتب رسالة...",
                          counterText: "",
                          filled: true,
                          fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(22)),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              showMic
                  ? GestureDetector(
                      onLongPress: _isSending ? null : _startRecording,
                      onLongPressEnd: (_) => _stopAndSendRecording(),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.mic, color: Colors.white),
                        ),
                      ),
                    )
                  : _isRecording
                      ? Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.stop, color: Colors.white),
                            onPressed: _stopAndSendRecording,
                          ),
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

  Widget _buildRecordingIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          const Text(
            "جارٍ التسجيل...",
            style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            "اضغط ■ للإرسال أو 🗑 للإلغاء",
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[200],
        border: const Border(right: BorderSide(color: AppColors.primary, width: 4)),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                ),
                Text(
                  widget.replyingMessage!.text ??
                      (widget.replyingMessage!.mediaType == 'image'
                          ? "صورة 🖼️"
                          : widget.replyingMessage!.mediaType == 'gif'
                              ? "GIF 🎞️"
                              : "رسالة وسائط"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: widget.onCancelReply),
        ],
      ),
    );
  }
}
