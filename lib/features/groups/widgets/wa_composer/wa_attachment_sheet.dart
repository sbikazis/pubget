import 'package:flutter/material.dart';

import '../../../../app/app_router.dart';
import '../../../games/models/game_type_registry.dart';
import '../../../games/widgets/game_widgets.dart';
import 'wa_colors.dart';

class WaAttachmentSheet extends StatelessWidget {
  const WaAttachmentSheet({
    required this.groupId,
    required this.onCamera,
    required this.onGallery,
    required this.onGames,
    required this.onCreateEvent,
    super.key,
  });

  final String groupId;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onGames;
  final VoidCallback onCreateEvent;

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    required VoidCallback onGames,
    required VoidCallback onCreateEvent,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: WaColors.dimScrim,
      isScrollControlled: true,
      builder: (context) => WaAttachmentSheet(
        groupId: groupId,
        onCamera: onCamera,
        onGallery: onGallery,
        onGames: () async {
          await showModalBottomSheet<void>(
            context: context,
            backgroundColor: WaColors.attachmentSheet(context),
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => _WaGamesSheet(groupId: groupId),
          );
          onGames();
        },
        onCreateEvent: () {
          onCreateEvent();
          AppNavigation.go(
            context,
            '/events/create?groupId=${Uri.encodeComponent(groupId)}',
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: WaColors.attachmentSheet(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: WaColors.handle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.15,
              children: <Widget>[
                _AttachAction(
                  delay: 0,
                  color: WaColors.cameraBlue,
                  icon: Icons.photo_camera,
                  label: 'كاميرا',
                  onTap: onCamera,
                ),
                _AttachAction(
                  delay: 50,
                  color: WaColors.galleryPurple,
                  icon: Icons.photo_library,
                  label: 'المعرض',
                  onTap: onGallery,
                ),
                _AttachAction(
                  delay: 100,
                  color: WaColors.gamesGreen,
                  icon: Icons.sports_esports,
                  label: 'الألعاب',
                  onTap: onGames,
                ),
                _AttachAction(
                  delay: 150,
                  color: WaColors.eventOrange,
                  icon: Icons.event,
                  label: 'إنشاء فعالية',
                  onTap: onCreateEvent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachAction extends StatefulWidget {
  const _AttachAction({
    required this.delay,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final int delay;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_AttachAction> createState() => _AttachActionState();
}

class _AttachActionState extends State<_AttachAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: const TextStyle(fontSize: 12, color: WaColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
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
          const SizedBox(height: 10),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: WaColors.handle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'الألعاب',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: WaColors.textPrimary,
              ),
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
                    style: const TextStyle(color: WaColors.textPrimary),
                  ),
                  trailing: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: WaColors.cursorGreen,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      GameLinks.openCreate(context, groupId: groupId);
                    },
                    child: const Text('لعب'),
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
