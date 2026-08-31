// lib/widgets/mafia/night_action_sheet.dart
//
// ✅ تلميع: رأس ملوّن حسب دور اللاعب فعلياً (MafiaRoleColors)، أيقونة
// مميزة، ظلال على البطاقات المختارة.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/mafia_constants.dart';
import '../../core/theme/mafia_role_colors.dart';
import '../../models/mafia/mafia_player_model.dart';
import '../../models/mafia/mafia_player_private_model.dart';
import '../../providers/mafia_game_provider.dart';

class NightActionSheet extends StatefulWidget {
  final String gameId;
  final MafiaPlayerModel currentPlayer;
  final MafiaPlayerPrivateModel currentPlayerPrivate;
  final List<MafiaPlayerModel> allPlayers;

  const NightActionSheet({
    super.key,
    required this.gameId,
    required this.currentPlayer,
    required this.currentPlayerPrivate,
    required this.allPlayers,
  });

  static Future<void> show(
    BuildContext context, {
    required String gameId,
    required MafiaPlayerModel currentPlayer,
    required MafiaPlayerPrivateModel currentPlayerPrivate,
    required List<MafiaPlayerModel> allPlayers,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NightActionSheet(
        gameId: gameId,
        currentPlayer: currentPlayer,
        currentPlayerPrivate: currentPlayerPrivate,
        allPlayers: allPlayers,
      ),
    );
  }

  @override
  State<NightActionSheet> createState() => _NightActionSheetState();
}

class _NightActionSheetState extends State<NightActionSheet> {
  String? _selectedTargetId;
  bool _submitting = false;

  String get _myRole => widget.currentPlayerPrivate.role;

  bool get _hasNightAction => const [
        MafiaRoles.mafia,
        MafiaRoles.doctor,
        MafiaRoles.detective,
        MafiaRoles.sniper,
        MafiaRoles.silencer,
      ].contains(_myRole);

  List<MafiaPlayerModel> get _eligibleTargets {
    return widget.allPlayers.where((p) {
      if (!p.isAlive || p.hasLeft) return false;
      if (p.id == widget.currentPlayer.id && _myRole != MafiaRoles.doctor) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _submit() async {
    if (_selectedTargetId == null) return;
    setState(() => _submitting = true);
    try {
      await context.read<MafiaGameProvider>().submitNightAction(
            gameId: widget.gameId,
            playerId: widget.currentPlayer.id,
            role: _myRole,
            targetId: _selectedTargetId,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!widget.currentPlayer.isAlive) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('لقد فارقت الحياة، ولا يمكنك التصرف الليلة.'),
      );
    }

    if (!_hasNightAction) {
      final visual = MafiaRoleColors.of(_myRole);
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: visual.badgeBg,
              child: Icon(visual.icon, size: 32, color: visual.color),
            ),
            const SizedBox(height: 14),
            Text('🌙 الليل حالك، لا تملك قدرة الليلة.', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('انتظر حتى الصباح.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final visual = MafiaRoleColors.of(_myRole);
    final targets = _eligibleTargets;

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: visual.badgeBg, shape: BoxShape.circle),
                child: Icon(visual.icon, color: visual.color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('دورك: ${visual.label}',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: targets.length,
              itemBuilder: (context, index) {
                final target = targets[index];
                final selected = _selectedTargetId == target.id;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: selected ? visual.badgeBg : null,
                    border: Border.all(color: selected ? visual.color : Colors.transparent, width: 1.5),
                    boxShadow: selected
                        ? [BoxShadow(color: visual.color.withOpacity(0.25), blurRadius: 8)]
                        : null,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: CircleAvatar(
                      backgroundImage: target.avatar.isNotEmpty ? NetworkImage(target.avatar) : null,
                      child: target.avatar.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(target.username),
                    trailing: selected ? Icon(Icons.check_circle, color: visual.color) : null,
                    onTap: () => setState(() => _selectedTargetId = target.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: visual.color,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (_selectedTargetId == null || _submitting) ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تأكيد الاختيار'),
            ),
          ),
        ],
      ),
    );
  }
}