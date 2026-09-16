import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/pubget_bottom_sheet.dart';
import '../../../games/models/game_type_registry.dart';
import '../../../games/widgets/game_widgets.dart';
import 'wa_colors.dart';

/// Premium Telegram / iOS 18–style attachment picker.
///
/// Always presented via [PubgetBottomSheet] so dismiss includes drag-down,
/// barrier tap, close control, and hardware back.
Future<void> showPremiumAttachmentSheet(
  BuildContext context, {
  required String groupId,
  required VoidCallback onCamera,
  required VoidCallback onGallery,
  VoidCallback? onVideo,
  required VoidCallback onGames,
  required VoidCallback onCreateEvent,
}) {
  return PubgetBottomSheet.present<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.50),
    builder: (sheetContext) {
      return _PremiumAttachmentSheet(
        groupId: groupId,
        onCamera: onCamera,
        onGallery: onGallery,
        onVideo: onVideo,
        onGames: onGames,
        onCreateEvent: onCreateEvent,
      );
    },
  );
}

/// Back-compat entry used by the chat composer.
class WaAttachmentSheet {
  const WaAttachmentSheet._();

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    VoidCallback? onVideo,
    required VoidCallback onGames,
    required VoidCallback onCreateEvent,
  }) {
    return showPremiumAttachmentSheet(
      context,
      groupId: groupId,
      onCamera: onCamera,
      onGallery: onGallery,
      onVideo: onVideo,
      onGames: onGames,
      onCreateEvent: onCreateEvent,
    );
  }
}

class _PremiumAttachmentSheet extends StatelessWidget {
  const _PremiumAttachmentSheet({
    required this.groupId,
    required this.onCamera,
    required this.onGallery,
    this.onVideo,
    required this.onGames,
    required this.onCreateEvent,
  });

  final String groupId;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onVideo;
  final VoidCallback onGames;
  final VoidCallback onCreateEvent;

  static const _sheetBg = Color(0xFF1E222B);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom > 0 ? 0 : 8),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _sheetBg.withValues(alpha: 0.88),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 40,
                    offset: const Offset(0, -8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.06),
                    blurRadius: 18,
                    spreadRadius: -4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: IconButton(
                        key: const Key('sheet-close'),
                        tooltip: AppStrings.of(context).close,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          PhosphorIconsDuotone.x,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _PremiumAttachAction(
                            delayMs: 0,
                            label: 'المعرض',
                            icon: PhosphorIconsDuotone.images,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFFA855F7),
                                Color(0xFFEC4899),
                              ],
                            ),
                            glow: const Color(0xFFA855F7),
                            onTap: onGallery,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _PremiumAttachAction(
                            delayMs: 50,
                            label: 'كاميرا',
                            icon: PhosphorIconsDuotone.camera,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFF0EA5E9),
                                Color(0xFF06B6D4),
                              ],
                            ),
                            glow: const Color(0xFF0EA5E9),
                            onTap: onCamera,
                          ),
                        ),
                      ],
                    ),
                    if (onVideo != null) ...[
                      const SizedBox(height: 24),
                      _PremiumAttachAction(
                        delayMs: 200,
                        label: 'فيديو',
                        icon: PhosphorIconsDuotone.videoCamera,
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        glow: const Color(0xFF6366F1),
                        onTap: onVideo!,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _PremiumAttachAction(
                            delayMs: 100,
                            label: 'إنشاء فعالية',
                            icon: PhosphorIconsDuotone.calendarPlus,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFFF59E0B),
                                Color(0xFFF97316),
                              ],
                            ),
                            glow: const Color(0xFFF59E0B),
                            onTap: () {
                              Navigator.of(context).pop();
                              onCreateEvent();
                            },
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _PremiumAttachAction(
                            delayMs: 150,
                            label: 'الألعاب',
                            icon: PhosphorIconsDuotone.gameController,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFF10B981),
                                Color(0xFF059669),
                              ],
                            ),
                            glow: const Color(0xFF10B981),
                            onTap: () async {
                              await PubgetBottomSheet.present<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: _sheetBg,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(28),
                                  ),
                                ),
                                builder: (_) => _WaGamesSheet(groupId: groupId),
                              );
                              onGames();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumAttachAction extends StatefulWidget {
  const _PremiumAttachAction({
    required this.delayMs,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.glow,
    required this.onTap,
  });

  final int delayMs;
  final String label;
  final IconData icon;
  final Gradient gradient;
  final Color glow;
  final VoidCallback onTap;

  @override
  State<_PremiumAttachAction> createState() => _PremiumAttachActionState();
}

class _PremiumAttachActionState extends State<_PremiumAttachAction> {
  var _pressed = false;

  Future<void> _handleTap() async {
    HapticFeedback.mediumImpact();
    setState(() => _pressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (mounted) setState(() => _pressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: _handleTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedScale(
                scale: _pressed ? 0.92 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.gradient,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: widget.glow.withValues(
                          alpha: _pressed ? 0.48 : 0.30,
                        ),
                        blurRadius: _pressed ? 22 : 16,
                        spreadRadius: _pressed ? 1 : 0,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.18),
                        blurRadius: 10,
                        spreadRadius: -6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      widget.icon,
                      size: 32,
                      color: Colors.white,
                      duotoneSecondaryOpacity: 0.35,
                      duotoneSecondaryColor: Colors.white,
                      shadows: const <Shadow>[
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.2,
                ),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: widget.delayMs))
        .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(0.82, 0.82),
          end: const Offset(1, 1),
          duration: 520.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _WaGamesSheet extends StatelessWidget {
  const _WaGamesSheet({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.5;
    final games = GameTypeRegistry.implemented;
    return SizedBox(
      height: height,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: <Widget>[
                const Spacer(),
                Text(
                  'الألعاب',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: WaColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('sheet-close'),
                  tooltip: AppStrings.of(context).close,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    PhosphorIconsDuotone.x,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                GameLinks.openCenter(context, groupId: groupId);
              },
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('مركز الألعاب'),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: games.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final spec = games[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: WaColors.darkPill,
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: WaColors.segmentActive,
                    child: Icon(spec.icon, color: Colors.white),
                  ),
                  title: Text(
                    spec.name,
                    style: GoogleFonts.cairo(color: WaColors.textPrimary),
                  ),
                  trailing: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: WaColors.cursorGreen,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      GameLinks.openCreate(
                        context,
                        groupId: groupId,
                        fromChat: true,
                      );
                    },
                    child: Text('لعب', style: GoogleFonts.cairo()),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
