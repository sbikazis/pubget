import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class PubgetSkeleton extends StatefulWidget {
  const PubgetSkeleton({
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const PubgetSkeleton.circle({required double size, super.key})
    : width = size,
      height = size,
      borderRadius = null,
      shape = BoxShape.circle;

  const PubgetSkeleton.card({super.key, this.width, this.height = 140})
    : borderRadius = const BorderRadius.all(Radius.circular(AppRadius.lg)),
      shape = BoxShape.rectangle;

  @override
  State<PubgetSkeleton> createState() => _PubgetSkeletonState();
}

class _PubgetSkeletonState extends State<PubgetSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final gradientPosition = (_controller.value * 2) - 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : widget.borderRadius ?? BorderRadius.circular(AppRadius.sm),
            gradient: LinearGradient(
              begin: Alignment(gradientPosition - 1, 0),
              end: Alignment(gradientPosition + 1, 0),
              colors: <Color>[
                scheme.surfaceContainerHighest,
                scheme.surface,
                scheme.surfaceContainerHighest,
              ],
            ),
          ),
          child: SizedBox(width: widget.width, height: widget.height),
        );
      },
    );
  }
}

class PubgetSkeletonListTile extends StatelessWidget {
  const PubgetSkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const PubgetSkeleton.circle(size: 44),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const PubgetSkeleton(
                width: double.infinity,
                height: 14,
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
              ),
              const SizedBox(height: AppSpacing.sm),
              FractionallySizedBox(
                widthFactor: 0.62,
                child: PubgetSkeleton(
                  width: double.infinity,
                  height: 12,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
