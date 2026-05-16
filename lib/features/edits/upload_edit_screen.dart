import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/edits_provider.dart';
import '../../providers/user_provider.dart';

class UploadEditScreen extends StatefulWidget {
  const UploadEditScreen({super.key});

  @override
  State<UploadEditScreen> createState() => _UploadEditScreenState();
}

class _UploadEditScreenState extends State<UploadEditScreen> {
  File? _videoFile;
  File? _thumbnailFile;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  final _animeTitleController = TextEditingController();
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (picked == null) return;

    final videoFile = File(picked.path);
    final size = await videoFile.length();

    if (size > 50 * 1024 * 1024) {
      _showError('حجم الفيديو يتجاوز 50MB');
      return;
    }

    // استخراج thumbnail
    final thumbPath = await VideoThumbnail.thumbnailFile(
      video: picked.path,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.JPEG,
      quality: 75,
    );

    // تهيئة مشغل الفيديو
    final controller = VideoPlayerController.file(videoFile);
    await controller.initialize();
    controller.setLooping(true);

    // dispose القديم لو موجود
    _videoController?.dispose();

    setState(() {
      _videoFile = videoFile;
      if (thumbPath != null) _thumbnailFile = File(thumbPath);
      _videoController = controller;
      _videoInitialized = true;
    });
  }

  void _togglePlay() {
    if (_videoController == null || !_videoInitialized) return;
    setState(() {
      _videoController!.value.isPlaying
          ? _videoController!.pause()
          : _videoController!.play();
    });
  }

  void _upload() {
    if (_videoFile == null) {
      _showError('اختر فيديو أولاً');
      return;
    }
    if (_animeTitleController.text.trim().isEmpty) {
      _showError('اكتب اسم الأنمي');
      return;
    }
    if (_thumbnailFile == null) {
      _showError('فشل إنشاء الصورة، اختر فيديو آخر');
      return;
    }

    final userProvider = context.read<UserProvider>();
    final editsProvider = context.read<EditsProvider>();
    final user = userProvider.currentUser;

    if (user == null) {
      _showError('يجب تسجيل الدخول أولاً');
      return;
    }

    // ← ارجع فوراً للتطبيق
    Navigator.pop(context);

    // ← ابدأ الرفع في الخلفية
    editsProvider.uploadEditInBackground(
      videoFile: _videoFile!,
      thumbnailFile: _thumbnailFile!,
      userId: user.id,
      uploaderName: user.username,
      uploaderAvatar: user.avatarUrl,
      animeTitle: _animeTitleController.text.trim(),
      caption: _captionController.text.trim(),
      onComplete: () {},
      onFailed: (error) {},
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _animeTitleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نشر إيديت'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: ElevatedButton(
              onPressed: _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'نشر',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── اختيار الفيديو / مشغل الفيديو
            GestureDetector(
              onTap: _videoInitialized ? _togglePlay : _pickVideo,
              child: Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: _videoInitialized && _videoController != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // ── مشغل الفيديو
                            SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width:
                                      _videoController!.value.size.width,
                                  height:
                                      _videoController!.value.size.height,
                                  child: VideoPlayer(_videoController!),
                                ),
                              ),
                            ),

                            // ── أيقونة Play/Pause
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                _videoController!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),

                            // ── زر تغيير الفيديو
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _pickVideo,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'تغيير',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12),
                                  ),
                                ),
                              ),
                            ),

                            // ── شريط التقدم
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: VideoProgressIndicator(
                                _videoController!,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Colors.white,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library,
                              color: Colors.grey, size: 50),
                          SizedBox(height: 8),
                          Text(
                            'اضغط لاختيار فيديو',
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'الحد الأقصى 60 ثانية • 50MB',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── اسم الأنمي
            const Text('اسم الأنمي *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _animeTitleController,
              decoration: InputDecoration(
                hintText: 'مثال: Attack on Titan',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── الكابشن
            const Text('الوصف (اختياري)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _captionController,
              maxLines: 3,
              maxLength: 150,
              decoration: InputDecoration(
                hintText: 'اكتب شيئاً عن الإيديت...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}