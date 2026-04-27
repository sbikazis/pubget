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

// ✅ استيراد المكونات
import 'package:pubget/features/groups/chat/massage_bubble.dart';
import 'package:pubget/features/groups/chat/massage_input_bar.dart';
import '../../../widgets/game_bottom_bar.dart'; 
import '../../../widgets/game_message_bubble.dart'; 

import '../../../widgets/empty_state_widget.dart';

// ✅ استيراد شاشة اللعبة للنقل الآلي
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      final isPremium = currentUser?.isPremium ?? false;

      if (currentUser != null) {
        _syncPremiumStatus(currentUser);
        _loadCurrentMember(currentUser.id);
        _updateReadStatus(currentUser.id);

        final adService = Provider.of<AdService>(context, listen: false);
        adService.tryShowGroupAd(isPremium: isPremium);
      }
    });
  }

  @override
  void dispose() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.currentUser?.id;
    if (currentUserId != null) {
      _updateReadStatus(currentUserId);
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _syncPremiumStatus(UserModel currentUser) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      final member = await chatProvider.getMember(
        groupId: widget.groupId,
        userId: currentUser.id,
      );

      if (member != null && member.isPremium != currentUser.isPremium) {
        await FirebaseFirestore.instance
            .collection(FirestorePaths.groupMembers(widget.groupId))
            .doc(currentUser.id)
            .update({'isPremium': currentUser.isPremium});
        _loadCurrentMember(currentUser.id);
      }
    } catch (e) {
      debugPrint('Failed to sync premium status: $e');
    }
  }

  void _updateReadStatus(String userId) {
    try {
      if (!mounted) return;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.updateLastRead(groupId: widget.groupId, userId: userId);
    } catch (e) {
      debugPrint("Update status failed: $e");
    }
  }

  Future<void> _loadCurrentMember(String userId) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      final member = await chatProvider.getMember(groupId: widget.groupId, userId: userId);
      if (!mounted) return;
      setState(() => _currentMember = member);
    } catch (e) {
      debugPrint('Failed to load current member: $e');
    }
  }

  void _scrollToBottom({bool animate = true, bool force = false}) {
    if (!_scrollController.hasClients) return;
    if (!force && _scrollController.offset < _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    final position = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(position, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(position);
    }
  }

  void _scrollToMessage(String messageId) {
    final index = _cachedMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      double targetOffset = index * 100.0;
      if (targetOffset > _scrollController.position.maxScrollExtent) {
        targetOffset = _scrollController.position.maxScrollExtent;
      }
      _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  void _onCancelReply() {
    setState(() => _replyingMessage = null);
  }

  Future<void> _handleSendText(String text, MessageModel? replyTo) async {
    if (_currentMember == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
   
    await chatProvider.sendTextMessage(
      groupId: widget.groupId,
      messageId: _uuid.v4(),
      sender: _currentMember!,
      text: text,
      userAvatar: userProvider.currentUser?.avatarUrl, 
      replyToId: replyTo?.id,
      replyText: replyTo?.text ?? (replyTo?.mediaType == 'image' ? "صورة 🖼️" : null),
    );
   
    _updateReadStatus(_currentMember!.userId);
    _onCancelReply();
    _scrollToBottom(force: true);
  }

  Future<void> _handleSendImage(File file, MessageModel? replyTo) async {
    if (_currentMember == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await chatProvider.sendMediaMessage(
      groupId: widget.groupId,
      messageId: _uuid.v4(),
      sender: _currentMember!,
      file: file,
      mediaType: 'image',
      userAvatar: userProvider.currentUser?.avatarUrl,
      replyToId: replyTo?.id,
      replyText: replyTo?.text ?? (replyTo?.mediaType == 'image' ? "صورة 🖼️" : null),
    );

    _updateReadStatus(_currentMember!.userId);
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
        final bool isRoleplay = group?.isRoleplay ?? false;
        final String groupName = group?.name ?? "الدردشة";

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
                      if (snapshot.data!.length > _cachedMessages.length) {
                        final userProvider = Provider.of<UserProvider>(context, listen: false);
                        final currentUserId = userProvider.currentUser?.id;
                        if (currentUserId != null) {
                          Future.microtask(() => _updateReadStatus(currentUserId));
                        }
                      }
                      _cachedMessages = snapshot.data!;
                      _isInitialLoad = false;
                    }
                    if (_cachedMessages.isEmpty) {
                      return const Center(child: EmptyStateWidget(
                        title: 'لا توجد رسائل بعد', 
                        subtitle: 'ابدأ المحادثة الآن', 
                        icon: Icons.chat_bubble_outline
                      ));
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      itemCount: _cachedMessages.length,
                      itemBuilder: (context, index) {
                        final message = _cachedMessages[index];
                        final isMe = _currentMember != null && message.senderId == _currentMember!.userId;
                        
                        if (message.gameId != null && message.gameAction != null) {
                           return GameMessageBubble(
                             message: message,
                             currentMember: _currentMember ?? MemberModel(userId: '', groupId: widget.groupId, role: Roles.member, joinedAt: DateTime.now()),
                             groupId: widget.groupId,
                           );
                        }

                        final sender = isMe ? _currentMember! : MemberModel(
                                userId: message.senderId,
                                groupId: widget.groupId,
                                role: message.senderRole ?? Roles.member,
                                joinedAt: DateTime.now(),
                                displayName: message.senderName,
                                characterImageUrl: isRoleplay ? message.senderAvatar : null,
                                realUserImageUrl: !isRoleplay ? message.senderAvatar : null,
                                isPremium: message.senderIsPremium, 
                              );

                        return MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          sender: sender,
                          isMe: isMe,
                          groupId: widget.groupId,
                          onReply: (msg) => setState(() => _replyingMessage = msg),
                          onTapReply: (replyId) => _scrollToMessage(replyId),
                        );
                      },
                    );
                  },
                ),
              ),

              if (_currentMember != null)
                StreamBuilder<List<GameModel>>(
                  stream: gameProvider.streamActiveGames(widget.groupId),
                  builder: (context, gameSnapshot) {
                    final activeGames = gameSnapshot.data ?? [];
                    
                    // ✅ مراقبة الألعاب التي في حالة setup أو guessing وتخص المستخدم
                    GameModel? activeGameForMe;
                    try {
                      activeGameForMe = activeGames.firstWhere(
                        (g) => (g.playerOneId == _currentMember!.userId || g.playerTwoId == _currentMember!.userId) 
                                && (g.status == GameStatus.guessing || g.status == GameStatus.setup)
                      );
                    } catch (_) {
                      activeGameForMe = null;
                    }

                    if (activeGameForMe != null) {
                      // ✅ [التعديل الجوهري]: منطق النقل الآلي لصفحة التجهيز (setup) مع حل مشكلة الـ Getter
                      if (activeGameForMe.status == GameStatus.setup) {
                        Future.microtask(() {
                          if (mounted) {
                            // ✅ تجميع كل المعرفات المتاحة من الموديل لتفادي خطأ animeIds غير المعرف
                            List<int> allRelevantIds = [];
                            if (group?.animeId != null && group!.animeId is int) {
                              allRelevantIds.add(group.animeId);
                            }
                            if (group?.franchiseIds != null) {
                              allRelevantIds.addAll(group!.franchiseIds!.whereType<int>());
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GuessCharacterGameScreen(
                                  groupId: widget.groupId,
                                  gameId: activeGameForMe!.id,
                                  // ✅ نمرر القائمة المجمعة أو null إذا كانت فارغة لدعم المجموعات العامة
                                  animeIds: allRelevantIds.isEmpty ? null : allRelevantIds,
                                ),
                              ),
                            );
                          }
                        });
                        return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                      }

                      // إذا كانت الحالة guessing، نعرض شريط التحكم الخاص باللعبة
                      return GameBottomBar(
                        groupId: widget.groupId,
                        game: activeGameForMe,
                        currentMember: _currentMember!,
                      );
                    }

                    return MessageInputBar(
                      groupId: widget.groupId, 
                      currentMember: _currentMember!, 
                      onSendText: _handleSendText,
                      onSendImage: _handleSendImage,
                      replyingMessage: _replyingMessage,
                      onCancelReply: _onCancelReply,
                      isPrivate: false, 
                    );
                  }
                ),
            ],
          ),
        );
      }
    );
  }
}