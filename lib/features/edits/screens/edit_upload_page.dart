import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../repositories/edits_repository.dart';

class EditUploadPage extends StatefulWidget {
  const EditUploadPage({super.key});

  @override
  State<EditUploadPage> createState() => _EditUploadPageState();
}

class _EditUploadPageState extends State<EditUploadPage> {
  final _caption = TextEditingController();
  final _anime = TextEditingController();
  XFile? _video;
  double _progress = 0;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    _anime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Upload Edit')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        PubgetSecondaryButton(
          onPressed: _uploading ? null : _choose,
          semanticLabel: 'Choose an MP4 video',
          leadingIcon: Icons.video_library_outlined,
          child: Text(_video?.name ?? 'Choose video'),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(controller: _caption, label: 'Caption', maxLines: 4),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(controller: _anime, label: 'Anime tag (optional)'),
        if (_uploading) ...[
          const SizedBox(height: AppSpacing.lg),
          LinearProgressIndicator(value: _progress == 0 ? null : _progress),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _progress >= 1
                ? 'Uploaded. Pubget is processing the video and thumbnail.'
                : 'Uploading ${(_progress * 100).round()}%',
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          PubgetErrorState(message: _error!),
        ],
        const SizedBox(height: AppSpacing.xl),
        PubgetPrimaryButton(
          onPressed: _uploading || _video == null ? null : _submit,
          semanticLabel: 'Upload this Edit',
          loading: _uploading,
          child: Text(_error == null ? 'Upload Edit' : 'Retry upload'),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Uploads continue once started, but background transfer after the app '
          'is terminated is not supported in this version.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Future<void> _choose() async {
    final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (video != null && mounted) setState(() => _video = video);
  }

  Future<void> _submit() async {
    final video = _video;
    if (video == null) return;
    setState(() {
      _uploading = true;
      _error = null;
      _progress = 0;
    });
    final result = await context.read<EditsRepository>().uploadEdit(
      bytes: await video.readAsBytes(),
      contentType: video.mimeType ?? 'video/mp4',
      caption: _caption.text,
      animeTag: _anime.text,
      onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      },
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit uploaded and is processing.')),
        );
        Navigator.of(context).pop();
      },
      onFailure: (failure) => setState(() {
        _uploading = false;
        _error = failure.message;
      }),
    );
  }
}
