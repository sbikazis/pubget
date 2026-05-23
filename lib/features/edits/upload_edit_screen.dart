// lib/features/edits/upload_edit_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/edits_provider.dart';
import '../../providers/user_provider.dart';

class UploadEditScreen extends StatefulWidget {
  const UploadEditScreen({super.key});

  @override
  State<UploadEditScreen> createState() => _UploadEditScreenState();
}

class _UploadEditScreenState extends State<UploadEditScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _animeTitleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();

  File? _videoFile;
  File? _thumbnailFile;
  VideoPlayerController? _videoController;

  bool _isPreparingVideo = false;
  bool _videoInitialized = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _disposeVideoController();
    _animeTitleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (_isPreparingVideo) return;

    setState(() {
      _isPreparingVideo = true;
    });

    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );

      if (picked == null) {
        _finishPreparing();
        return;
      }

      final videoFile = File(picked.path);
      final fileSize = await videoFile.length();

      if (fileSize > 50 * 1024 * 1024) {
        _showError('حجم الفيديو يتجاوز 50MB');
        _finishPreparing();
        return;
      }

      final tempDir = await getTemporaryDirectory();

      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: picked.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );

      if (thumbnailPath == null) {
        _showError('فشل إنشاء الصورة المصغرة');
        _finishPreparing();
        return;
      }

      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      await controller.setLooping(true);
      await _disposeVideoController();

      if (!mounted) return;

      setState(() {
        _videoFile = videoFile;
        _thumbnailFile = File(thumbnailPath);
        _videoController = controller;
        _videoInitialized = true;
      });
    } catch (_) {
      _showError('حدث خطأ أثناء تجهيز الفيديو');
    } finally {
      _finishPreparing();
    }
  }

  void _finishPreparing() {
    if (!mounted) return;
    setState(() {
      _isPreparingVideo = false;
    });
  }

  Future<void> _disposeVideoController() async {
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  void _togglePlayPause() {
    final controller = _videoController;
    if (controller == null || !_videoInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }

    setState(() {});
  }

  Future<void> _submitUpload() async {
    if (_isSubmitting) return;

    if (_videoFile == null) {
      _showError('اختر فيديو أولاً');
      return;
    }

    if (_thumbnailFile == null) {
      _showError('فشل إنشاء الصورة');
      return;
    }

    final animeTitle = _animeTitleController.text.trim();

    if (animeTitle.isEmpty) {
      _showError('اكتب اسم الأنمي');
      return;
    }

    final userProvider = context.read<UserProvider>();
    final editsProvider = context.read<EditsProvider>();
    final user = userProvider.currentUser;

    if (user == null) {
      _showError('يجب تسجيل الدخول أولاً');
      return;
    }

    if (_videoController != null && _videoController!.value.isPlaying) {
      await _videoController!.pause();
    }

    setState(() {
      _isSubmitting = true;
    });

    editsProvider.uploadEditInBackground(
      videoFile: _videoFile!,
      thumbnailFile: _thumbnailFile!,
      userId: user.id,
      uploaderName: user.username,
      uploaderAvatar: user.avatarUrl,
      animeTitle: animeTitle,
      caption: _captionController.text.trim(),
      onComplete: (_) {
        if (!mounted) return;
        Navigator.pop(context);
      },
      onFailed: (error) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
        _showError(error);
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildVideoPreview() {
    if (_isPreparingVideo) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_videoInitialized && _videoController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: _pickVideo,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'تغيير',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
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
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.video_library,
          color: Colors.grey,
          size: 50,
        ),
        SizedBox(height: 8),
        Text(
          'اضغط لاختيار فيديو',
          style: TextStyle(color: Colors.grey),
        ),
        SizedBox(height: 4),
        Text(
          'الحد الأقصى 60 ثانية • 50MB',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نشر إيديت'),
        actions: [
          Padding(
  padding: const EdgeInsets.only(left: 8, right: 8),
  child: TextButton(
    onPressed: _isSubmitting ? null : _submitUpload,
    style: TextButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.white54,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    child: _isSubmitting
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Text(
            'نشر',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
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
            GestureDetector(
              onTap: _videoInitialized ? _togglePlayPause : _pickVideo,
              child: Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: _buildVideoPreview(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'اسم الأنمي *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
            const Text(
              'الوصف (اختياري)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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