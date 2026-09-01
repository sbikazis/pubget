import 'package:flutter/foundation.dart';

final class UnreadEngine extends ChangeNotifier {
  int _notifications = 0;
  int _groups = 0;
  int _privateChats = 0;
  int _mentions = 0;

  int get notifications => _notifications;
  int get groups => _groups;
  int get privateChats => _privateChats;
  int get mentions => _mentions;
  int get total => notifications + groups + privateChats + mentions;

  void sync({
    int? notifications,
    int? groups,
    int? privateChats,
    int? mentions,
  }) {
    final nextNotifications = notifications ?? _notifications;
    final nextGroups = groups ?? _groups;
    final nextPrivate = privateChats ?? _privateChats;
    final nextMentions = mentions ?? _mentions;
    if (nextNotifications == _notifications &&
        nextGroups == _groups &&
        nextPrivate == _privateChats &&
        nextMentions == _mentions) {
      return;
    }
    _notifications = nextNotifications.clamp(0, 9999);
    _groups = nextGroups.clamp(0, 9999);
    _privateChats = nextPrivate.clamp(0, 9999);
    _mentions = nextMentions.clamp(0, 9999);
    notifyListeners();
  }
}
