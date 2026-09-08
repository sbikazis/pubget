import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_crop_aspect.dart';
import 'pubget_image_cropper.dart';

/// Picks an image from the gallery, then forces the shared crop & edit step.
Future<CroppedImageResult?> pickAndCropImage(
  BuildContext context, {
  required ImageCropAspect aspect,
  ImageSource source = ImageSource.gallery,
  ImagePicker? picker,
}) async {
  final image = await (picker ?? ImagePicker()).pickImage(
    source: source,
    maxWidth: 2048,
    imageQuality: 92,
  );
  if (image == null || !context.mounted) return null;
  final bytes = await image.readAsBytes();
  if (!context.mounted || bytes.isEmpty) return null;
  return PubgetImageCropper.open(context, bytes: bytes, aspect: aspect);
}

/// Crops already-loaded bytes through the shared tool (for camera/share flows).
Future<CroppedImageResult?> cropImageBytes(
  BuildContext context, {
  required Uint8List bytes,
  required ImageCropAspect aspect,
}) {
  if (bytes.isEmpty) return Future<CroppedImageResult?>.value(null);
  return PubgetImageCropper.open(context, bytes: bytes, aspect: aspect);
}
