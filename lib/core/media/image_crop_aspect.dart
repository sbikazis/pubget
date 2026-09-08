/// Aspect presets for the shared Pubget crop & edit tool.
enum ImageCropAspect {
  /// Circular / square avatars.
  avatar,

  /// Wide cover / banner photos.
  cover,

  /// Soft square for group images and general media.
  square,

  /// Freeform (no forced ratio).
  free,
}

extension ImageCropAspectRatio on ImageCropAspect {
  /// Null means freeform.
  double? get ratio => switch (this) {
    ImageCropAspect.avatar => 1,
    ImageCropAspect.cover => 16 / 9,
    ImageCropAspect.square => 1,
    ImageCropAspect.free => null,
  };

  bool get circularPreview => this == ImageCropAspect.avatar;
}
