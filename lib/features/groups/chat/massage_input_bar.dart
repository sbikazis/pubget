// lib/features/groups/chat/message_input_bar.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:provider/provider.dart';

import '../../../models/message_model.dart';
import '../../../models/member_model.dart';
import '../../../models/sticker_model.dart';
import '../../../core/constants/limits.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/gif_picker_sheet.dart';
import '../../../widgets/game_events_sheet.dart';
import '../../../providers/sticker_provider.dart';
import '../../../providers/user_provider.dart';
import 'package:pubget/features/stickers/stiker_picker_sheet.dart';
import '../../stickers/sticker_creator_sheet.dart';

class MessageInputBar extends StatefulWidget {
  final Function(String text, MessageModel? replyTo) onSendText;
  final Function(File file, MessageModel? replyTo) onSendImage;
  final Function(String gifUrl, MessageModel? replyTo)? onSendGif;
  final Function(File audioFile, MessageModel? replyTo, int duration)? onSendAudio;
  final Function(StickerModel sticker, MessageModel? replyTo)? onSendSticker;
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
    this.onSendSticker,
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
  final FocusNode _focusNode = FocusNode();

  bool _isSending = false;
  bool _isRecording = false;
  bool _showEmojiPicker = false;
  String? _recordingPath;
  Timer? _recordTimer;
  int _recordSeconds = 0;

  int _activeTab = 0;

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    _recordTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _openEmojiSheet() {
    FocusScope.of(context).unfocus();
    setState(() => _showEmojiPicker = true);
  }

  void _closeEmojiSheet() {
    setState(() => _showEmojiPicker = false);
    _focusNode.requestFocus();
  }

  void _toggleEmojiSheet() {
    if (_showEmojiPicker) {
      _closeEmojiSheet();
    } else {
      _openEmojiSheet();
    }
  }

  Future<void> _handleStickerSelected(StickerModel sticker) async {
    setState(() => _showEmojiPicker = false);
    if (widget.onSendSticker == null) return;
    if (widget.onCancelReply!= null) widget.onCancelReply!();
    widget.onSendSticker!(sticker, widget.replyingMessage);
  }

  Future<void> _handleGifSelected(String gifUrl) async {
    setState(() => _showEmojiPicker = false);
    if (widget.onSendGif == null) return;
    if (widget.onCancelReply!= null) widget.onCancelReply!();
    widget.onSendGif!(gifUrl, widget.replyingMessage);
  }

  Future<void> _pickAndSendImage() async {
    if (_isSending) return;
    try {
      final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;
      setState(() => _isSending = true);
      await widget.onSendImage(File(image.path), widget.replyingMessage);
      if (widget.onCancelReply!= null) widget.onCancelReply!();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("فشل معالجة أو إرسال الصورة.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (text.length > Limits.maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("الرسالة طويلة جداً")));
      return;
    }

    _controller.clear();
    setState(() {});
    if (widget.onCancelReply!= null) widget.onCancelReply!();

    widget.onSendText(text, widget.replyingMessage);
  }

  Future<void> _startRecording() async {
    if (widget.onSendAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ميزة الرسائل الصوتية غير مدعومة هنا.")),
      );
      return;
    }
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
      final path =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
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
    _recordTimer?.cancel();
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path == null || widget.onSendAudio == null) return;
      final file = File(path);
      if (!await file.exists()) return;
      setState(() => _isSending = true);
      await widget.onSendAudio!(file, widget.replyingMessage, _recordSeconds);
      if (widget.onCancelReply!= null) widget.onCancelReply!();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("فشل إرسال التسجيل.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
      _recordingPath = null;
      _recordSeconds = 0;
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    try {
      await _recorder.stop();
      _recordTimer?.cancel();
      if (_recordingPath!= null) {
        final file = File(_recordingPath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordSeconds = 0;
      });
    }
  }

  void _handleGamePressed() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GameEventsSheet(
        groupId: widget.groupId,
        currentMember: widget.currentMember,
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback? onTap, {Color? color}) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 22),
        color: color?? Colors.grey[600],
        onPressed: onTap,
      ),
    );
  }

  Widget _circleBtn(IconData? icon, Color color, {bool isLoading = false}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: isLoading
          ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Color(0xFFFFD700)),
              )
            : Icon(icon, color: const Color(0xFFFFD700), size: 24),
      ),
    );
  }

  Widget _buildSendButton(bool showMic) {
    const darkPurpleColor = Color(0xFF30013B);
    if (showMic) {
      return GestureDetector(
        onLongPress: _isSending? null : _startRecording,
        onLongPressEnd: (_) => _stopAndSendRecording(),
        child: _circleBtn(Icons.mic_rounded, darkPurpleColor),
      );
    }
    if (_isRecording) {
      return GestureDetector(
        onTap: _stopAndSendRecording,
        child: _circleBtn(Icons.stop_rounded, Colors.red),
      );
    }
    return GestureDetector(
      onTap: _isSending? null : _sendMessage,
      child: _circleBtn(
        _isSending? null : Icons.send_rounded,
        darkPurpleColor,
        isLoading: _isSending,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFillColor = isDark? const Color(0xFF1F2C34) : Colors.white;
    final bool showMic = _controller.text.trim().isEmpty &&!_isRecording;

    return SafeArea(
      top: false,
      bottom: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingMessage!= null) _buildReplyPreview(isDark),
          if (_isRecording) _buildRecordingIndicator(isDark),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            color: Colors.transparent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: inputFillColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!_isRecording)...[
                          const SizedBox(width: 8),
                          _buildIconBtn(
                            Icons.attach_file_rounded,
                            _isSending? null : _pickAndSendImage,
                          ),
                          const SizedBox(width: 4),
                          if (!widget.isPrivate)
                            _buildIconBtn(
                              Icons.videogame_asset_rounded,
                              _handleGamePressed,
                              color: AppColors.goldAccent,
                            ),
                          const SizedBox(width: 4),
                        ],
                        if (_isRecording)...[
                          const SizedBox(width: 8),
                          _buildIconBtn(
                            Icons.delete_outline_rounded,
                            _cancelRecording,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: _isRecording
                            ? const SizedBox.shrink()
                              : TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  minLines: 1,
                                  maxLines: 5,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  maxLength: Limits.maxMessageLength,
                                  onChanged: (_) => setState(() {}),
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.3,
                                    color: isDark? Colors.white : Colors.black,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: "مراسلة",
                                    counterText: "",
                                    filled: false,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                  onTap: () {
                                    if (_showEmojiPicker) {
                                      setState(() => _showEmojiPicker = false);
                                    }
                                  },
                                ),
                        ),
                        if (!_isRecording)...[
                          IconButton(
                            padding: const EdgeInsets.only(
                                bottom: 4, right: 4, left: 4),
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              _showEmojiPicker
                                ? Icons.keyboard_rounded
                                  : Icons.mood_rounded,
                              color: Colors.grey[500],
                              size: 24,
                            ),
                            onPressed: _toggleEmojiSheet,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildSendButton(showMic),
              ],
            ),
          ),
          if (_showEmojiPicker) _buildUnifiedSheet(isDark),
        ],
      ),
    );
  }

  Widget _buildUnifiedSheet(bool isDark) {
    final sheetBg = isDark? const Color(0xFF1F2C34) : Colors.grey[100]!;
    final tabBg = isDark? const Color(0xFF2A3540) : Colors.grey[200]!;

    return Container(
      height: 300,
      color: sheetBg,
      child: Column(
        children: [
          Container(
            color: tabBg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _buildTab(0, '🏷️', 'ملصقات', isDark),
                const SizedBox(width: 8),
                _buildTab(1, 'GIF', 'GIF', isDark),
                const SizedBox(width: 8),
                _buildTab(2, '😊', 'إيموجي', isDark),
              ],
            ),
          ),
          Expanded(
            child: _activeTab == 0
              ? _buildStickerTab(isDark)
                : _activeTab == 1
                  ? _buildGifTab()
                    : _buildEmojiTab(isDark, sheetBg),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String icon, String label, bool isDark) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          icon == 'GIF'? 'GIF' : '$icon $label',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive? FontWeight.bold : FontWeight.normal,
            color: isActive
              ? Colors.white
                : (isDark? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiTab(bool isDark, Color bg) {
    return EmojiPicker(
      onEmojiSelected: (category, emoji) {
        _controller.text = _controller.text + emoji.emoji;
        setState(() {});
      },
      config: Config(
        height: 240,
        checkPlatformCompatibility: true,
        emojiViewConfig: EmojiViewConfig(
          columns: 7,
          emojiSizeMax: 28.0,
          verticalSpacing: 0,
          horizontalSpacing: 0,
          gridPadding: EdgeInsets.zero,
          backgroundColor: bg,
          noRecents: const Text(
            'لا توجد إيموجيات مستخدمة مؤخراً',
            style: TextStyle(fontSize: 14, color: Colors.black26),
            textAlign: TextAlign.center,
          ),
        ),
        categoryViewConfig: CategoryViewConfig(
          initCategory: Category.RECENT,
          indicatorColor: const Color(0xFF30013B),
          iconColor: Colors.grey,
          iconColorSelected: const Color(0xFFFFD700),
          backspaceColor: const Color(0xFFFFD700),
          backgroundColor: isDark? const Color(0xFF1F2C34) : Colors.grey[200]!,
        ),
        bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
      ),
    );
  }

  Widget _buildGifTab() {
    return GifPickerSheet(
      onGifSelected: _handleGifSelected,
      embedded: true,
    );
  }

  Widget _buildStickerTab(bool isDark) {
    final userId = context.read<UserProvider>().currentUser?.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(
                'ملصقاتي',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark? Colors.white70 : Colors.black87,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() => _showEmojiPicker = false);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => StickerCreatorSheet(
                      onStickerCreated: (sticker) {
                        _handleStickerSelected(sticker);
                      },
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'إنشاء',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<StickerProvider>(
            builder: (context, provider, _) {
              if (userId!= null && provider.stickers.isEmpty &&!provider.isLoading) {
                provider.loadStickers(userId);
              }

              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.stickers.isEmpty) {
                return Center(
                  child: Text(
                    'لا توجد ملصقات — اضغط "إنشاء"',
                    style: TextStyle(
                      color: isDark? Colors.white38 : Colors.black38,
                      fontSize: 13,
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: provider.stickers.length,
                itemBuilder: (context, index) {
                  final sticker = provider.stickers[index];
                  return GestureDetector(
                    onTap: () => _handleStickerSelected(sticker),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        sticker.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark? Colors.grey[900] : Colors.grey[100],
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Text(
            "${_recordSeconds ~/ 60}:${(_recordSeconds % 60).toString().padLeft(2, '0')}",
            style: const TextStyle(
                color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          const Text("جارٍ التسجيل...",
              style: TextStyle(
                  color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            "اضغط ■ للإرسال أو 🗑 للإلغاء",
            style: TextStyle(
                fontSize: 11, color: isDark? Colors.white54 : Colors.black45),
          ),
        ],
      ),
    );
  }

  // ── ✅ النسخة الجديدة مع thumbnail ──────────────────────────
  Widget _buildReplyPreview(bool isDark) {
    final reply = widget.replyingMessage!;
    final bool hasMedia = reply.mediaUrl!= null &&
        reply.mediaUrl!.isNotEmpty &&
        (reply.mediaType == 'image' || reply.mediaType == 'gif');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark? Colors.grey[900] : Colors.grey[200],
        border: const Border(
            right: BorderSide(color: Color(0xFF00A884), width: 4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 20, color: Color(0xFF00A884)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00A884),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                _buildReplyContentPreview(reply, isDark),
              ],
            ),
          ),
          if (hasMedia)...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                reply.mediaUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  color: isDark? Colors.white10 : Colors.black12,
                  child: const Icon(Icons.broken_image_outlined,
                      size: 16, color: Colors.grey),
                ),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onCancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyContentPreview(MessageModel reply, bool isDark) {
    final color = isDark? Colors.white70 : Colors.black87;
    final style = TextStyle(fontSize: 13, color: color);

    if (reply.mediaType == 'audio') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic, size: 14, color: color),
          const SizedBox(width: 4),
          Text('تسجيل صوتي', style: style),
        ],
      );
    }
    if (reply.mediaType == 'sticker') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text('ملصق', style: style),
        ],
      );
    }
    if (reply.mediaType == 'gif') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gif_box_outlined, size: 15, color: color),
          const SizedBox(width: 4),
          Text('GIF', style: style),
        ],
      );
    }
    if (reply.mediaType == 'image') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text('صورة', style: style),
        ],
      );
    }
    return Text(
      reply.text?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}