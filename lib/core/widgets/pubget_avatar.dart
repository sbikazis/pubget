import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'app_image_loader.dart';

enum PubgetAvatarSize {
  small(32),
  nav(36),
  medium(48),
  large(72);

  const PubgetAvatarSize(this.value);

  final double value;
}

class PubgetAvatar extends StatelessWidget {
  const PubgetAvatar({
    this.imageUrl,
    this.image,
    this.name,
    this.size = PubgetAvatarSize.medium,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final String? imageUrl;
  final ImageProvider? image;
  final String? name;
  final PubgetAvatarSize size;
  final VoidCallback? onTap;

  /// Announced by screen readers when the avatar is the only representation of
  /// an identity on screen. Cards that wrap their own `Semantics` do not need
  /// to set this, and a duplicate label would be read twice.
  final String? semanticLabel;

  String? get _initial {
    final value = name?.trim();
    if (value == null || value.isEmpty) return null;
    return value.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = semanticLabel ?? name;
    final avatar = Semantics(
      image: true,
      label: label,
      child: CircleAvatar(
      radius: size.value / 2,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      backgroundImage: image,
      child: image != null
          ? null
          : imageUrl == null || imageUrl!.isEmpty
          ? (_initial == null
                ? Icon(Icons.person_outline, size: size.value * 0.5)
                : Text(
                    _initial!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ))
          : ClipOval(
              child: AppImageLoader(
                imageUrl: imageUrl!,
                width: size.value,
                height: size.value,
                // The loader derives the decode budget from the painted box and
                // the screen ratio, so a 3x phone is not handed a 48px decode
                // for a 48dp slot and then asked to scale it up.
                errorWidget: Icon(Icons.person_outline, size: size.value * 0.5),
              ),
            ),
      ),
    );

    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: avatar,
        ),
      ),
    );
  }
}
