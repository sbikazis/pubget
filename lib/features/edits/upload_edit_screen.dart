import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
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

    // حد 50MB
    if (size > 50 * 1024 * 1024) {
      _showError('حجم الفيديو يتجاوز 50MB');
      return;
    }

    // استخراج thumbnail تلقائياً
    final thumbPath = await VideoThumbnail.thumbnailFile(
      video: picked.path,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.JPEG,
      quality: 75,
    );

    setState(() {
      _videoFile = videoFile;
      if (thumbPath!= null) _thumbnailFile = File(thumbPath);
    });
  }

  Future<void> _upload() async {
    if (_videoFile == null) {
      _showError('اختر فيديو أولاً');
      return;
    }
    if (_animeTitleController.text.trim().isEmpty) {
      _showError('اكتب اسم الأنمي');
      return;
    }
    // ← تم التصحيح: لا ترسل الفيديو كصورة
    if (_thumbnailFile == null) {
      _showError('فشل إنشاء الصورة، اختر فيديو آخر');
      return;
    }

    final userProvider = context.read<UserProvider>();
    final editsProvider = context.read<EditsProvider>();
    final user = userProvider.currentUser;

    final success = await editsProvider.uploadEdit(
      videoFile: _videoFile!,
      thumbnailFile: _thumbnailFile!, // ← تم التصحيح
      userId: user!.id,
      uploaderName: user.username,
      uploaderAvatar: user.avatarUrl,
      animeTitle: _animeTitleController.text.trim(),
      caption: _captionController.text.trim(),
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر الإيديت ✅')),
      );
    } else if (mounted) {
      // ← تم التصحيح: يعرض الخطأ الحقيقي
      final err = context.read<EditsProvider>().error?? 'غير معروف';
      _showError('فشل: $err');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
       .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _animeTitleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUploading = context.watch<EditsProvider>().isUploading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('نشر إيديت'),
        actions: [
          TextButton(
            onPressed: isUploading? null : _upload,
            child: const Text(
              'نشر',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: isUploading
         ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري رفع الإيديت...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── اختيار الفيديو
                  GestureDetector(
                    onTap: _pickVideo,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: _thumbnailFile!= null
                         ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    _thumbnailFile!,
                                    fit: BoxFit.cover,
                                  ),
                                  const Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.white70,
                                      size: 60,
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
