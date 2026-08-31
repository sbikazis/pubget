// lib/widgets/mafia/voting_sheet.dart
//
// ✅ تلميع: شريط تصويت متحرك لكل هدف (نسبة من إجمالي الأصوات)، ظلال
// وألوان متسقة مع بقية اللعبة.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/mafia/mafia_player_model.dart';
import '../../models/mafia/mafia_vote_model.dart';
import '../../providers/mafia_game_provider.dart';

class VotingSheet extends StatefulWidget {
  final String gameId;
  final MafiaPlayerModel currentPlayer;
  final List<MafiaPlayerModel> allPlayers;
  final int dayNumber;

  const VotingSheet({
    super.key,
    required this.gameId,
    required this.currentPlayer,
    required this.allPlayers,
    required this.dayNumber,
  });

  static Future<void> show(
    BuildContext context, {
    required String gameId,
    required MafiaPlayerModel currentPlayer,
    required List<MafiaPlayerModel> allPlayers,
    required int dayNumber,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => VotingSheet(
        gameId: gameId,
        currentPlayer: currentPlayer,
        allPlayers: allPlayers,
        dayNumber: dayNumber,
      ),
    );
  }

  @override
  State<VotingSheet> createState() => _VotingSheetState();
}

class _VotingSheetState extends State<VotingSheet> {
  String? _selectedTargetId;
  bool _submitting = false;

  List<MafiaPlayerModel> get _eligibleTargets {
    return widget.allPlayers
        .where((p) => p.isAlive && !p.hasLeft && p.id != widget.currentPlayer.id)
        .toList();
  }

  Map<String, int> _tallyFrom(List<MafiaVoteModel> votes) {
    final tally = <String, int>{};
    for (final vote in votes) {
      if (vote.dayNumber != widget.dayNumber) continue;
      tally[vote.targetId] = (tally[vote.targetId] ?? 0) + 1;
    }
    return tally;
  }

  Future<void> _submit() async {
    if (_selectedTargetId == null) return;
    setState(() => _submitting = true);
    try {
      await context.read<MafiaGameProvider>().submitVote(
            gameId: widget.gameId,
            voterId: widget.currentPlayer.id,
            targetId: _selectedTargetId!,
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
        child: Text('لقد فارقت الحياة، ولا يمكنك التصويت.'),
      );
    }
    if (!widget.currentPlayer.canVote) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('لا تملك حق التصويت في هذه الجولة.'),
      );
    }

    final targets = _eligibleTargets;

    return Consumer<MafiaGameProvider>(
      builder: (context, provider, child) {
        final tally = _tallyFrom(provider.votes);
        final totalVotes = tally.values.fold<int>(0, (a, b) => a + b);

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
                    decoration: const BoxDecoration(
                      color: Color(0x26EA580C), shape: BoxShape.circle),
                    child: const Icon(Icons.how_to_vote_rounded, color: Colors.deepOrange),
                  ),
                  const SizedBox(width: 12),
                  Text('التصويت لإعدام مشتبه به', style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  itemBuilder: (context, index) {
                    final target = targets[index];
                    final selected = _selectedTargetId == target.id;
                    final voteCount = tally[target.id] ?? 0;
                    final ratio = totalVotes == 0 ? 0.0 : voteCount / totalVotes;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: selected ? Colors.deepOrange.withOpacity(0.1) : null,
                        border: Border.all(
                          color: selected ? Colors.deepOrange : Colors.transparent, width: 1.5),
                        boxShadow: selected
                            ? [BoxShadow(color: Colors.deepOrange.withOpacity(0.2), blurRadius: 8)]
                            : null,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _selectedTargetId = target.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage:
                                      target.avatar.isNotEmpty ? NetworkImage(target.avatar) : null,
                                  child: target.avatar.isEmpty ? const Icon(Icons.person) : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(target.username)),
                                if (voteCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('$voteCount',
                                        style: const TextStyle(
                                            color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                  ),
                                if (selected) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.check_circle, color: Colors.deepOrange, size: 20),
                                ],
                              ],
                            ),
                            if (voteCount > 0) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 4,
                                  backgroundColor: AppColors.disabled.withOpacity(0.15),
                                  valueColor: const AlwaysStoppedAnimation(Colors.deepOrange),
                                ),
                              ),
                            ],
                          ],
                        ),
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
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: (_selectedTargetId == null || _submitting) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('تأكيد التصويت'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}