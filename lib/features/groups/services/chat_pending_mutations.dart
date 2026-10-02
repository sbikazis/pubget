import '../models/chat_models.dart';

/// The local edits a chat session has made but the server has not confirmed.
///
/// A reaction and a delete are both answered by the server only after a round
/// trip, and the watch stream is the source of truth for both. That leaves a
/// window in which a snapshot describes the message as it was *before* the
/// commit — for instance because an unrelated message in the same query
/// arrived first. Re-applying the guess onto such a snapshot is what keeps the
/// emoji from blinking out and back, and keeps a deleted bubble from
/// reappearing for a frame.
///
/// Nothing here is a second source of truth: each entry is dropped the moment the
/// server's own answer is seen, and a failed call drops it immediately.
final class ChatPendingMutations {
  /// messageId -> the tombstone the device applied.
  final Map<String, DateTime> _deletes = <String, DateTime>{};

  /// messageId -> emoji -> the exact reaction state the device applied.
  final Map<String, Map<String, ChatMessage>> _reactions =
      <String, Map<String, ChatMessage>>{};

  bool get isEmpty => _deletes.isEmpty && _reactions.isEmpty;

  // ------------------------------------------------------------- reactions ---

  /// Records [applied] as this session's pending answer for [emoji], so a
  /// snapshot that predates the commit cannot undo it.
  void expectReaction(
    String messageId,
    String emoji,
    ChatMessage applied,
  ) {
    final forMessage = _reactions.putIfAbsent(
      messageId,
      () => <String, ChatMessage>{},
    );
    forMessage[emoji] = applied;
  }

  /// True when a reaction toggle for this exact emoji is still on the wire, so a
  /// second tap cannot make the server toggle twice and land on the opposite
  /// state from the one the user sees.
  bool reactionInFlight(String messageId, String emoji) =>
      _reactions[messageId]?.containsKey(emoji) ?? false;

  /// Drops the pending answer for [emoji] once the server has described the
  /// same state, or because the call failed.
  void confirmReaction(String messageId, String emoji) {
    final forMessage = _reactions[messageId];
    if (forMessage == null) return;
    forMessage.remove(emoji);
    if (forMessage.isEmpty) _reactions.remove(messageId);
  }

  /// Whether the server's copy of [emoji] already is what the device applied.
  static bool _agrees(ChatMessage server, String emoji, ChatMessage applied) {
    final users = server.reactionUsers[emoji];
    final appliedUsers = applied.reactionUsers[emoji];
    if (server.reactions[emoji] != applied.reactions[emoji]) return false;
    final serverUsers = users ?? const <String>{};
    final mine = appliedUsers ?? const <String>{};
    return serverUsers.length == mine.length && serverUsers.containsAll(mine);
  }

  // ---------------------------------------------------------------- delete ---

  void expectDelete(String messageId, DateTime stamp) =>
      _deletes[messageId] = stamp;

  void confirmDelete(String messageId) => _deletes.remove(messageId);

  /// Forgets everything, when the session itself is gone.
  void clear() {
    _deletes.clear();
    _reactions.clear();
  }

  /// Puts the local edits this session is still owed back on top of [incoming],
  /// the server's answer to that message.
  ///
  /// Entries the server has now agreed with are dropped here, so a confirmed
  /// mutation stops being carried and the message reverts to the server's own
  /// fields (its `deletedAt`, its read counts) instead of a device copy of them.
  ChatMessage overlay(String messageId, ChatMessage incoming) {
    var result = incoming;
    final pendingReactions = _reactions[messageId];
    if (pendingReactions != null) {
      final counts = Map<String, int>.from(result.reactions);
      final users = Map<String, Set<String>>.from(result.reactionUsers);
      final stillPending = <String, ChatMessage>{};
      for (final entry in pendingReactions.entries) {
        if (_agrees(result, entry.key, entry.value)) continue;
        final applied = entry.value;
        final appliedUsers = applied.reactionUsers[entry.key];
        if (appliedUsers == null || appliedUsers.isEmpty) {
          users.remove(entry.key);
          counts.remove(entry.key);
        } else {
          users[entry.key] = appliedUsers;
          counts[entry.key] = applied.reactions[entry.key] ?? appliedUsers.length;
        }
        stillPending[entry.key] = applied;
      }
      if (stillPending.isEmpty) {
        _reactions.remove(messageId);
      } else {
        _reactions[messageId] = stillPending;
      }
      if (stillPending.isNotEmpty) {
        result = result.copyWith(reactions: counts, reactionUsers: users);
      }
    }

    final stamp = _deletes[messageId];
    // Only a snapshot that still shows the message alive is stale. One that
    // already carries a `deletedAt` is the server's confirmation and wins, so
    // the device's clock is not what the roster ends up showing.
    if (stamp != null) {
      if (result.deletedAt != null) {
        _deletes.remove(messageId);
      } else {
        result = result.copyWith(deletedAt: stamp);
      }
    }
    return result;
  }
}