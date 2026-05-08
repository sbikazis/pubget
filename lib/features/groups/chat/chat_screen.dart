import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../providers/chat_provider.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../models/group_model.dart';
import '../../../models/game_model.dart';
import '../../../models/message_model.dart';
import '../../../models/member_model.dart';
import '../../../models/user_model.dart';
import '../../../core/constants/roles.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/game_status.dart';
import '../../../services/monetization/ad_service.dart';
import 'package:pubget/features/groups/chat/massage_bubble.dart';
import 'package:pubget/features/groups/chat/massage_input_bar.dart';
import '../../../widgets/game_bottom_bar.dart';
import '../../../widgets/game_message_bubble.dart';
import '../../../widgets/empty_state_widget.dart';
import '../events/guess_character_game_screen.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;

  const ChatScreen({super.key, required this.groupId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();
  MemberModel? _currentMember;

  MessageModel? _replyingMessage;
  List<MessageModel> _cachedMessages = [];
  bool _isInitialLoad = true;
  final Set<String> _navigatedGameIds = {};

  DateTime? _lastReadAt;
  bool _initialScrollDone = false;
  final Map<String, GlobalKey> _messageKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      if (currentUser!= null) {
        _syncPremiumStatus(currentUser);
        _loadCurrentMember(currentUser.id);
      }
    });
  }

  @override
  void dispose() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.currentUser?.id;
    if (currentUserId!= null && _cachedMessages.isNotEmpty) {
      _updateReadStatus(currentUserId, readUpTo: _cachedMessages.last.createdAt);
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _syncPremiumStatus(UserModel currentUser) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      final member = await chatProvider.getMember(groupId: widget.groupId, userId: currentUser.id);
      if (member!= null && member.isPremium!= currentUser.isPremium) {
        await FirebaseFirestore.instance.collection(FirestorePaths.groupMembers(widget.groupId)).doc(currentUser.id).update({'isPremium': currentUser.isPremium});
        _loadCurrentMember(currentUser.id);
      }
    } catch (e) {
      debugPrint('Failed to sync premium status: $e');
    }
  }

  void _updateReadStatus(String userId, {DateTime? readUpTo}) {
    try {
      if (!mounted) return;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.updateLastRead(groupId: widget.groupId, userId: userId, readUpTo: readUpTo);
    } catch (e) {
      debugPrint("Update status failed: $e");
    }
  }

  Future<void> _loadCurrentMember(String userId) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      final member = await chatProvider.getMember(groupId: widget.groupId, userId: userId);
      if (!mounted) return;
      _lastReadAt = member?.lastReadAt;
      setState(() => _currentMember = member);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstUnread());
    } catch (e) {
      debugPrint('Failed to load current member: $e');
    }
  }

  void _scrollToFirstUnread() {
    if (_initialScrollDone ||!_scrollController.hasClients) return;
    if (_cachedMessages.isEmpty) return;
    _initialScrollDone = true;
    if (_lastReadAt == null) {
      _scrollController.jumpTo(0);
      return;
    }
    final messages = _cachedMessages.reversed.toList();
    final firstUnreadIndex = messages.indexWhere((m) => m.createdAt.isAfter(_lastReadAt!));
    if (firstUnreadIndex == -1) {
      _scrollController.jumpTo(0);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = messages[firstUnreadIndex];
      final key = _messageKeys[target.id];
      if (key?.currentContext!= null) {
        Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300), alignment: 0.1);
      }
    });
  }

  void _scrollToBottom({bool animate = true, bool force = false}) {
    if (!_scrollController.hasClients) return;
    if (!force && _scrollController.offset > 200) return;
    if (animate) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(0);
    }
  }

  void _scrollToMessage(String messageId) {
    final messages = _cachedMessages.reversed.toList();
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index!= -1) {
      final key = _messageKeys[messageId];
      if (key?.currentContext!= null) {
        Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    }
  }

  void _onCancelReply() => setState(() => _replyingMessage = null);

  Future<void> _handleSendText(String text, MessageModel? replyTo) async {
    if (_currentMember == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await chatProvider.sendTextMessage(groupId: widget.groupId, messageId: _uuid.v4(), sender: _currentMember!, text: text, userAvatar: userProvider.currentUser?.avatarUrl, replyToId: replyTo?.id, replyText: replyTo?.text?? (replyTo?.mediaType == 'image'? "صورة 🖼️" : null));
    _onCancelReply();
    _scrollToBottom(force: true);
  }

  Future<void> _handleSendImage(File file, MessageModel? replyTo) async {
    if (_currentMember == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await chatProvider.sendMediaMessage(groupId: widget.groupId, messageId: _uuid.v4(), sender: _currentMember!, file: file, mediaType: 'image', userAvatar: userProvider.currentUser?.avatarUrl, replyToId: replyTo?.id, replyText: replyTo?.text?? (replyTo?.mediaType == 'image'? "صورة 🖼️" : null));
    _onCancelReply();
    _scrollToBottom(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    return StreamBuilder<GroupModel?>(
      stream: groupProvider.streamGroup(groupId: widget.groupId),
      builder: (context, groupSnapshot) {
        final group = groupSnapshot.data;
        final bool isRoleplay = group?.isRoleplay?? false;
        final String groupName = group?.name?? "الدردشة";

        return Scaffold(
          appBar: AppBar(title: Text(groupName), centerTitle: true),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: chatProvider.streamMessages(groupId: widget.groupId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _isInitialLoad) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasData) {
                      final isFirstLoad = _isInitialLoad;
                      _cachedMessages = snapshot.data!;
                      if (isFirstLoad) {
                        _isInitialLoad = false;
                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstUnread());
                      }
                    }
                    if (_cachedMessages.isEmpty) {
                      return const Center(child: EmptyStateWidget(title: 'لا توجد رسائل بعد', subtitle: 'ابدأ المحادثة الآن', icon: Icons.chat_bubble_outline));
                    }
                    final messages = _cachedMessages.reversed.toList();
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = _currentMember!= null && message.senderId == _currentMember!.userId;
                        _messageKeys.putIfAbsent(message.id, () => GlobalKey());
                        if (message.gameId!= null && message.gameAction!= null) {
                          return GameMessageBubble(key: _messageKeys[message.id], message: message, currentMember: _currentMember?? MemberModel(userId: '', groupId: widget.groupId, role: Roles.member, joinedAt: DateTime.now()), groupId: widget.groupId);
                        }
                        final sender = isMe? _currentMember! : MemberModel(userId: message.senderId, groupId: widget.groupId, role: message.senderRole?? Roles.member, joinedAt: DateTime.now(), displayName: message.senderName, characterImageUrl: isRoleplay? message.senderAvatar : null, realUserImageUrl:!isRoleplay? message.senderAvatar : null, isPremium: message.senderIsPremium);
                        return MessageBubble(key: _messageKeys[message.id], message: message, sender: sender, isMe: isMe, groupId: widget.groupId, onReply: (msg) => setState(() => _replyingMessage = msg), onTapReply: (replyId) => _scrollToMessage(replyId));
                      },
                    );
                  },
                ),
              ),
              if (_currentMember!= null)
                StreamBuilder<List<GameModel>>(
                  stream: gameProvider.streamActiveGames(widget.groupId),
                  builder: (context, gameSnapshot) {
                    final activeGames = gameSnapshot.data?? [];
                    GameModel? activeGameForMe;
                    try {
                      activeGameForMe = activeGames.firstWhere((g) => (g.playerOneId == _currentMember!.userId || g.playerTwoId == _currentMember!.userId) && (g.status == GameStatus.waitingForOpponent || g.status == GameStatus.setup || g.status == GameStatus.guessing));
                    } catch (_) {}

                    if (activeGameForMe!= null) {
                      // نظّف عند الانتهاء
                      if (activeGameForMe.status.isOver) {
                        _navigatedGameIds.remove(activeGameForMe.id);
                      }

                      if (activeGameForMe.status == GameStatus.guessing) {
                        _navigatedGameIds.remove(activeGameForMe.id);
                        return GameBottomBar(groupId: widget.groupId, game: activeGameForMe, currentMember: _currentMember!);
                      }

                      // ✅ التنقل التلقائي للمنشئ والمنضم
                      final shouldNavigate = (activeGameForMe.status == GameStatus.waitingForOpponent || activeGameForMe.status == GameStatus.setup) &&!_navigatedGameIds.contains(activeGameForMe.id);
                      if (shouldNavigate) {
                        _navigatedGameIds.add(activeGameForMe.id);
                        Future.microtask(() {
                          if (mounted) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => GuessCharacterGameScreen(groupId: widget.groupId, gameId: activeGameForMe!.id, animeIds: group?.animeId!= null? [group!.animeId] : null)));
                          }
                        });
                      }
                    }
                    return MessageInputBar(groupId: widget.groupId, currentMember: _currentMember!, onSendText: _handleSendText, onSendImage: _handleSendImage, replyingMessage: _replyingMessage, onCancelReply: _onCancelReply, isPrivate: false);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}