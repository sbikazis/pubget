import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/achievement_models.dart';

/// Medium profile-strip size (px) — clear detail without crowding the hero.
const double kAchievementStripBadgeSize = 56;

/// Large list / celebration badge size.
const double kAchievementListBadgeSize = 120;

/// Reusable badge: static PNG + rarity-specific Flutter overlays.
/// Animation logic is intentionally separate from unlock ownership.
class AchievementBadgeWidget extends StatefulWidget {
  const AchievementBadgeWidget({
    required this.item,
    this.size = kAchievementListBadgeSize,
    this.animate = true,
    this.forceLockedStyle = false,
    this.onTap,
    super.key,
  });

  final AchievementItem item;
  final double size;
  final bool animate;
  final bool forceLockedStyle;
  final VoidCallback? onTap;

  @override
  State<AchievementBadgeWidget> createState() => _AchievementBadgeWidgetState();
}

class _AchievementBadgeWidgetState extends State<AchievementBadgeWidget>
    with TickerProviderStateMixin {
  late final AnimationController _loop;
  late final AnimationController _once;
  var _visible = true;

  bool get _unlocked =>
      widget.item.unlocked && !widget.forceLockedStyle;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  bool get _shouldAnimate =>
      widget.animate &&
      _unlocked &&
      _visible &&
      !_reduceMotion &&
      widget.item.animationType != AchievementAnimationType.none;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _once = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant AchievementBadgeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    if (_shouldAnimate) {
      if (!_loop.isAnimating) {
        _loop.repeat();
      }
      if (widget.item.animationType == AchievementAnimationType.brushTrail &&
          !_once.isAnimating &&
          _once.value == 0) {
        _once.forward(from: 0);
      }
    } else {
      _loop.stop();
      _once.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _once.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => false,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: VisibilityDetector(
            onVisibilityChanged: (visible) {
              if (_visible == visible) return;
              setState(() => _visible = visible);
              _sync();
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_loop, _once]),
              builder: (context, _) {
                return _BadgeLayers(
                  item: widget.item,
                  size: widget.size,
                  unlocked: _unlocked,
                  t: _shouldAnimate ? _loop.value : 0,
                  once: _shouldAnimate ? _once.value : 0,
                  animate: _shouldAnimate,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight visibility probe without extra package dependency.
class VisibilityDetector extends StatefulWidget {
  const VisibilityDetector({
    required this.child,
    required this.onVisibilityChanged,
    super.key,
  });

  final Widget child;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted) return;
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) {
      widget.onVisibilityChanged(false);
      return;
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screen = view.physicalSize / view.devicePixelRatio;
    final topLeft = render.localToGlobal(Offset.zero);
    final rect = topLeft & render.size;
    final visible = rect.overlaps(Offset.zero & screen) &&
        rect.width > 0 &&
        rect.height > 0;
    widget.onVisibilityChanged(visible);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _BadgeLayers extends StatelessWidget {
  const _BadgeLayers({
    required this.item,
    required this.size,
    required this.unlocked,
    required this.t,
    required this.once,
    required this.animate,
  });

  final AchievementItem item;
  final double size;
  final bool unlocked;
  final double t;
  final double once;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final type = item.animationType;
    Widget badge = Image.asset(
      item.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Icon(
        Icons.emoji_events_outlined,
        size: size * 0.45,
        color: Colors.amber,
      ),
    );

    if (!unlocked) {
      badge = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.3, 0.3, 0.3, 0, 0,
          0.3, 0.3, 0.3, 0, 0,
          0.3, 0.3, 0.3, 0, 0,
          0, 0, 0, 0.55, 0,
        ]),
        child: badge,
      );
    }

    if (!animate || !unlocked) return badge;

    return switch (type) {
      AchievementAnimationType.none => badge,
      AchievementAnimationType.shimmer => _Shimmer(t: t, child: badge),
      AchievementAnimationType.orbitLights =>
        _OrbitLights(t: t, size: size, child: badge),
      AchievementAnimationType.pathGlow =>
        _PathGlow(t: t, size: size, child: badge),
      AchievementAnimationType.brushTrail =>
        _BrushTrail(once: once, size: size, child: badge),
      AchievementAnimationType.starPulse =>
        _StarPulse(t: t, size: size, child: badge),
      AchievementAnimationType.bannerSway =>
        _BannerSway(t: t, size: size, child: badge),
      AchievementAnimationType.crownGlow =>
        _CrownGlow(t: t, size: size, child: badge),
      AchievementAnimationType.lightSweep =>
        _LightSweep(t: t, size: size, child: badge),
      AchievementAnimationType.mythicLiving =>
        _MythicLiving(t: t, size: size, child: badge),
    };
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.t, required this.child});
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Slow metallic sweep every ~6s.
    final x = (t * 2) % 1.0;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment(-1 + x * 3, -0.2),
          end: Alignment(-0.2 + x * 3, 0.3),
          colors: const <Color>[
            Color(0x00FFFFFF),
            Color(0x66FFE9A8),
            Color(0x00FFFFFF),
          ],
          stops: const <double>[0.35, 0.5, 0.65],
        ).createShader(rect);
      },
      child: child,
    );
  }
}

class _OrbitLights extends StatelessWidget {
  const _OrbitLights({required this.t, required this.size, required this.child});
  final double t;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        child,
        CustomPaint(
          size: Size.square(size),
          painter: _OrbitPainter(t: t),
        ),
      ],
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.22;
    const count = 8;
    final active = (t * count).floor() % count;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (i / count) * math.pi * 2;
      final p = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final lit = i == active;
      canvas.drawCircle(
        p,
        lit ? 3.2 : 1.6,
        Paint()
          ..color = lit
              ? const Color(0xFFFFE082)
              : const Color(0x66C9A227),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => oldDelegate.t != t;
}

class _PathGlow extends StatelessWidget {
  const _PathGlow({required this.t, required this.size, required this.child});
  final double t;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        child,
        CustomPaint(
          size: Size.square(size),
          painter: _PathGlowPainter(t: t),
        ),
      ],
    );
  }
}

class _PathGlowPainter extends CustomPainter {
  _PathGlowPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.2;
    final path = Path()
      ..addOval(Rect.fromCircle(center: c, radius: r));
    final metric = path.computeMetrics().first;
    final pos = metric.getTangentForOffset(metric.length * t)?.position;
    if (pos == null) return;
    canvas.drawCircle(
      pos,
      4,
      Paint()
        ..color = const Color(0xAAFFD54F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _PathGlowPainter oldDelegate) => oldDelegate.t != t;
}

class _BrushTrail extends StatelessWidget {
  const _BrushTrail({required this.once, required this.size, required this.child});
  final double once;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final opacity = once < 0.7 ? once / 0.7 : (1 - once) / 0.3;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        child,
        if (once > 0 && once < 1)
          Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: -0.7,
              child: Align(
                alignment: Alignment(-0.6 + once * 1.2, -0.4 + once * 0.9),
                child: Container(
                  width: size * 0.35,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: <Color>[
                        Color(0x00FFD54F),
                        Color(0xCCFFD54F),
                        Color(0x00FFD54F),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StarPulse extends StatelessWidget {
  const _StarPulse({required this.t, required this.size, required this.child});
  final double t;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Sparse pulse: fire only in first 18% of the loop.
    final phase = (t % 1.0);
    final active = phase < 0.18;
    final p = active ? phase / 0.18 : 0.0;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        child,
        if (active)
          Container(
            width: size * (0.18 + p * 0.55),
            height: size * (0.18 + p * 0.55),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Color.fromRGBO(255, 213, 79, (1 - p) * 0.7),
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}

class _BannerSway extends StatelessWidget {
  const _BannerSway({required this.t, required this.size, required this.child});
  final double t;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sway = math.sin(t * math.pi * 2) * 0.025;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        Transform.rotate(angle: sway, child: child),
        ...List<Widget>.generate(4, (i) {
          final seed = (t + i * 0.2) % 1.0;
          return Positioned(
            left: size * (0.2 + (i * 0.15) % 0.6),
            top: size * (0.15 + seed * 0.55),
            child: Opacity(
              opacity: (1 - seed).clamp(0.0, 0.7),
              child: Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE082),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CrownGlow extends StatelessWidget {
  const _CrownGlow({required this.t, required this.size, required this.child});
  final double t;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          width: size * 0.42,
          height: size * 0.2,
          margin: EdgeInsets.only(bottom: size * 0.45),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(255, 213, 79, 0.35 * pulse),
                blurRadius: 18 * pulse,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        child,
        ...List<Widget>.generate(3, (i) {
          final seed = (t * 0.7 + i * 0.33) % 1.0;
          return Positioned(
            left: size * (0.3 + i * 0.15),
            top: size * (0.1 + seed * 0.2),
            child: Opacity(
              opacity: (1 - seed) * 0.6,
              child: const Icon(Icons.auto_awesome, size: 8, color: Color(0xFFFFE082)),
            ),
          );
        }),
      ],
    );
  }
}

class _LightSweep extends StatelessWidget {
  const _LightSweep({required this.t, required this.size, required this.child});
  final double t;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glow = 0.35 + 0.25 * math.sin(t * math.pi * 2);
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          width: size * 0.78,
          height: size * 0.78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(156, 39, 176, glow),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        _Shimmer(t: t, child: child),
      ],
    );
  }
}

class _MythicLiving extends StatelessWidget {
  const _MythicLiving({required this.t, required this.size, required this.child});
  final double t;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final breathe = math.sin(t * math.pi * 2) * 0.012;
    final rareSweep = ((t * 0.35) % 1.0);
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          width: size * 0.82,
          height: size * 0.82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(186, 104, 200, 0.35 + 0.2 * math.sin(t * math.pi * 2)),
                blurRadius: 26,
              ),
            ],
          ),
        ),
        Transform.rotate(
          angle: breathe,
          child: Transform.scale(
            scale: 1 + breathe.abs(),
            child: _Shimmer(t: rareSweep, child: child),
          ),
        ),
        ...List<Widget>.generate(6, (i) {
          final seed = (t * 0.5 + i / 6) % 1.0;
          final angle = seed * math.pi * 2;
          final r = size * 0.38;
          return Positioned(
            left: size / 2 + math.cos(angle) * r - 1.5,
            top: size / 2 + math.sin(angle) * r - 1.5,
            child: Opacity(
              opacity: 0.35 + 0.35 * math.sin((t + i) * math.pi),
              child: Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE082),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
