import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/pubget_buttons.dart';
import 'image_crop_aspect.dart';

/// Result of a successful crop pass.
final class CroppedImageResult {
  const CroppedImageResult({
    required this.bytes,
    this.contentType = 'image/png',
  });

  final Uint8List bytes;
  final String contentType;
}

/// Shared in-app crop & edit surface. Call [PubgetImageCropper.open] from any
/// image-pick flow before uploading.
class PubgetImageCropper extends StatefulWidget {
  const PubgetImageCropper({
    required this.bytes,
    required this.aspect,
    super.key,
  });

  final Uint8List bytes;
  final ImageCropAspect aspect;

  static Future<CroppedImageResult?> open(
    BuildContext context, {
    required Uint8List bytes,
    required ImageCropAspect aspect,
  }) {
    return Navigator.of(context).push<CroppedImageResult>(
      MaterialPageRoute<CroppedImageResult>(
        fullscreenDialog: true,
        builder: (_) => PubgetImageCropper(bytes: bytes, aspect: aspect),
      ),
    );
  }

  @override
  State<PubgetImageCropper> createState() => _PubgetImageCropperState();
}

class _PubgetImageCropperState extends State<PubgetImageCropper> {
  final _boundaryKey = GlobalKey();
  final _transformation = TransformationController();
  var _busy = false;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = widget.aspect.ratio ?? 1;
    return Scaffold(
      backgroundColor: AppColors.royalNight,
      appBar: AppBar(
        backgroundColor: AppColors.royalNight,
        foregroundColor: AppColors.white,
        title: const Text('Crop & edit'),
        leading: IconButton(
          key: const Key('image-crop-cancel'),
          tooltip: 'Cancel',
          onPressed: _busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.royalDusk,
                      borderRadius: BorderRadius.circular(
                        widget.aspect.circularPreview
                            ? 999
                            : AppRadius.lg,
                      ),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.7),
                        width: 2,
                      ),
                    ),
                    child: ClipPath(
                      clipper: widget.aspect.circularPreview
                          ? const _CircleClipper()
                          : null,
                      clipBehavior: Clip.hardEdge,
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: InteractiveViewer(
                          transformationController: _transformation,
                          minScale: 1,
                          maxScale: 4,
                          child: Image.memory(
                            widget.bytes,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Pinch to zoom, drag to frame. Confirm when it looks right.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.darkTextMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PubgetPrimaryButton(
                    key: const Key('image-crop-confirm'),
                    onPressed: _busy ? null : _confirm,
                    semanticLabel: 'Confirm cropped image',
                    loading: _busy,
                    leadingIcon: Icons.check_rounded,
                    child: const Text('Confirm'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PubgetSecondaryButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    semanticLabel: 'Cancel crop',
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      Navigator.pop(
        context,
        CroppedImageResult(bytes: data.buffer.asUint8List()),
      );
    } on Object {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper();

  @override
  Path getClip(Size size) {
    return Path()..addOval(Offset.zero & size);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
