// lib/features/groups/chat/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../providers/chat_provider.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/chat_background_provider.dart';
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
import 'package:pubget/widgets/game_events_sheet.dart'; // <-- جديد
import 'package:pubget/models/sticker_model.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final bool openEventsOnStart; // <-- جديد

  const ChatScreen({super.key, required this.groupId, this.openEventsOnStart = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
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

  bool _showScrollDown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      if (currentUser!= null) {
        _syncPremiumStatus(currentUser);
        _loadCurrentMember(currentUser.id);
      }
    });
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 200;
    if (show!= _showScrollDown) {
      setState(() => _showScrollDown = show);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.currentUser?.id;
      if (userId!= null && _cachedMessages.isNotEmpty) {
        _updateReadStatus(userId, readUpTo: _cachedMessages.last.createdAt);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _syncPremiumStatus(UserModel currentUser) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      final member = await chatProvider.getMember(
          groupId: widget.groupId, userId: currentUser.id);
      if (member!= null && member.isPremium!= currentUser.isPremium) {
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

  void _updateReadStatus(String userId, {DateTime? readUpTo}) {
    try {
      if (!mounted) return;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.updateLastRead(
          groupId: widget.groupId, userId: userId, readUpTo: readUpTo);
    } catch (e) {
      debugPrint("Update status failed: $e");
    }
  }

  Future<void> _markReadBeforePop() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.currentUser?.id;
      if (userId!= null && _cachedMessages.isNotEmpty) {
        await Provider.of<ChatProvider>(context, listen: false).updateLastRead(
          groupId: widget.groupId,
          userId: userId,
          readUpTo: _cachedMessages.last.createdAt,
        );
      }
    } catch (e) {
      debugPrint("markReadBeforePop failed: $e");
    }
  }

  Future<void> _loadCurrentMember(String userId) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      final member = await chatProvider.getMember(
          groupId: widget.groupId, userId: userId);
      if (!mounted) return;
      _lastReadAt = member?.lastReadAt;
      setState(() => _currentMember = member);

      // فتح الفعاليات تلقائياً إذا طُلب من earn_coins_screen
      if (widget.openEventsOnStart && _currentMember!= null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => GameEventsSheet(
                groupId: widget.groupId,
                currentMember: _currentMember!,
              ),
            );
          }
        });
      }

      if (_cachedMessages.isNotEmpty) {
        _updateReadStatus(userId, readUpTo: _cachedMessages.last.createdAt);
      }

      WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToFirstUnread());
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
    final firstUnreadIndex =
        messages.indexWhere((m) => m.createdAt.isAfter(_lastReadAt!));
    if (firstUnreadIndex == -1) {
      _scrollController.jumpTo(0);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = messages[firstUnreadIndex];
      final key = _messageKeys[target.id];
      if (key?.currentContext!= null) {
        Scrollable.ensureVisible(key!.currentContext!,
            duration: const Duration(milliseconds: 300), alignment: 0.1);
      }
    });
  }

  void _scrollToBottom({bool animate = true, bool force = false}) {
    if (!_scrollController.hasClients) return;
    if (!force && _scrollController.offset > 200) return;
    if (animate) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(0);
    }
  }

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key?.currentContext!= null) {
      Scrollable.ensureVisible(key!.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut);
    }
  }

  void _onCancelReply() => setState(() => _replyingMessage = null);

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
      replyText: replyTo?.text??
          (replyTo?.mediaType == 'image'
            ? "صورة 🖼️"
              : replyTo?.mediaType == 'gif'
                ? "GIF 🎞️"
                  : replyTo?.mediaType == 'audio'
                    ? "🎙️ تسجيل صوتي"
                      : null),
    );
    _onCancelReply();
    _scrollToBottom(force: true);
    final userId = userProvider.currentUser?.id;
    if (userId!= null && _cachedMessages.isNotEmpty) {
      _updateReadStatus(userId, readUpTo: _cachedMessages.last.createdAt);
    }
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
      replyText: replyTo?.text??
          (replyTo?.mediaType == 'image'? "صورة 🖼️" : null),
    );
    _onCancelReply();
    _scrollToBottom(force: true);
  }

  Future<void> _handleSendGif(String gifUrl, MessageModel? replyTo) async {
    if (_currentMember == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await chatProvider.sendGifMessage(
      groupId: widget.groupId,
      messageId: _uuid.v4(),
      sender: _currentMember!,
      gifUrl: gifUrl,
      replyToId: replyTo?.id,
      replyText: replyTo?.text??
          (replyTo?.mediaType == 'gif'? "GIF 🎞️" : null),
    );

    _onCancelReply();
    _scrollToBottom(force: true);
    final userId = userProvider.currentUser?.id;
    if (userId!= null && _cachedMessages.isNotEmpty) {
      _updateReadStatus(userId, readUpTo: _cachedMessages.last.createdAt);
    }
  }

  Future<void> _handleSendAudio(
      File audioFile, MessageModel? replyTo, int duration) async {
    if (_currentMember == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await chatProvider.sendAudioMessage(
      groupId: widget.groupId,
      messageId: _uuid.v4(),
      sender: _currentMember!,
      audioFile: audioFile,
      durationSeconds: duration,
      replyToId: replyTo?.id,
      replyText: replyTo?.text??
          (replyTo?.mediaType == 'audio'? "🎙️ تسجيل صوتي" : null),
    );
    _onCancelReply();
    _scrollToBottom(force: true);
    final userId = userProvider.currentUser?.id;
    if (userId!= null && _cachedMessages.isNotEmpty) {
      _updateReadStatus(userId, readUpTo: _cachedMessages.last.createdAt);
    }
  }
  Future<void> _handleSendSticker(
      StickerModel sticker, MessageModel? replyTo) async {
    if (_currentMember == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await chatProvider.sendStickerMessage(
      groupId: widget.groupId,
      messageId: _uuid.v4(),
      sender: _currentMember!,
      stickerUrl: sticker.imageUrl,
      replyToId: replyTo?.id,
      replyText: replyTo?.mediaType == 'sticker' ? "ملصق 🏷️" : null,
    );
    _onCancelReply();
    _scrollToBottom(force: true);
    final userId = userProvider.currentUser?.id;
    if (userId != null && _cachedMessages.isNotEmpty) {
      _updateReadStatus(userId, readUpTo: _cachedMessages.last.createdAt);
    }
  }

  Widget _buildBackground(String? backgroundUrl) {
    if (backgroundUrl == null || backgroundUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              backgroundUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
            Container(
              color: Colors.black.withOpacity(0.38),
            ),
          ],
        ),
      ),
    );
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

        final String? backgroundUrl = group?.chatBackgroundUrl;
        final bool hasBackground =
            backgroundUrl!= null && backgroundUrl.isNotEmpty;

        return WillPopScope(
          onWillPop: () async {
            await _markReadBeforePop();
            return true;
          },
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(title: Text(groupName), centerTitle: true),
            body: Stack(
              children: [
                _buildBackground(backgroundUrl),
                Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<List<MessageModel>>(
                        stream: chatProvider.streamMessages(
                            groupId: widget.groupId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              _isInitialLoad) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasData) {
                            final isFirstLoad = _isInitialLoad;
                            _cachedMessages = snapshot.data!;

                            if (_currentMember!= null) {
                              for (final msg in _cachedMessages) {
                                if (msg.senderId!= _currentMember!.userId) {
                                  if (!msg.isDelivered) {
                                    chatProvider.markAsDelivered(
                                      groupId: widget.groupId,
                                      messageId: msg.id,
                                    );
                                  }
                                  if (!msg.isRead) {
                                    chatProvider.markAsRead(
                                      groupId: widget.groupId,
                                      messageId: msg.id,
                                    );
                                  }
                                }
                              }
                            }

                            if (isFirstLoad) {
                              _isInitialLoad = false;
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _scrollToFirstUnread());
                            }
                            if (!isFirstLoad && _currentMember!= null) {
                              final userProvider = Provider.of<UserProvider>(
                                  context,
                                  listen: false);
                              final userId = userProvider.currentUser?.id;
                              if (userId!= null &&
                                  _cachedMessages.isNotEmpty) {
                                WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                  _updateReadStatus(userId,
                                      readUpTo:
                                          _cachedMessages.last.createdAt);
                                });
                              }
                            }
                          }
                          if (_cachedMessages.isEmpty) {
                            return const Center(
                                child: EmptyStateWidget(
                                    title: 'لا توجد رسائل بعد',
                                    subtitle: 'ابدأ المحادثة الآن',
                                    icon: Icons.chat_bubble_outline));
                          }
                          final messages = _cachedMessages.reversed.toList();
                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: EdgeInsets.zero,
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isMe = _currentMember!= null &&
                                  message.senderId == _currentMember!.userId;
                              _messageKeys.putIfAbsent(
                                  message.id, () => GlobalKey());
                              if (message.gameId!= null &&
                                  message.gameAction!= null) {
                                return GameMessageBubble(
                                    key: _messageKeys[message.id],
                                    message: message,
                                    currentMember: _currentMember??
                                        MemberModel(
                                            userId: '',
                                            groupId: widget.groupId,
                                            role: Roles.member,
                                            joinedAt: DateTime.now()),
                                    groupId: widget.groupId);
                              }
                              final sender = isMe
                                ? _currentMember!
                                  : MemberModel(
                                      userId: message.senderId,
                                      groupId: widget.groupId,
                                      role: message.senderRole?? Roles.member,
                                      joinedAt: DateTime.now(),
                                      displayName: message.senderName,
                                      characterImageUrl: isRoleplay
                                        ? message.senderAvatar
                                          : null,
                                      realUserImageUrl:!isRoleplay
                                        ? message.senderAvatar
                                          : null,
                                      isPremium: message.senderIsPremium);
                              return MessageBubble(
                                key: _messageKeys[message.id],
                                message: message,
                                sender: sender,
                                isMe: isMe,
                                groupId: widget.groupId,
                                hasBackground: hasBackground,
                                onReply: (msg) =>
                                    setState(() => _replyingMessage = msg),
                                onTapReply: (replyId) =>
                                    _scrollToMessage(replyId),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (_currentMember!= null)
                      StreamBuilder<List<GameModel>>(
                        stream:
                            gameProvider.streamActiveGames(widget.groupId),
                        builder: (context, gameSnapshot) {
                          final activeGames = gameSnapshot.data?? [];
                          GameModel? activeGameForMe;
                          try {
                            activeGameForMe = activeGames.firstWhere((g) =>
                                (g.playerOneId == _currentMember!.userId ||
                                    g.playerTwoId ==
                                        _currentMember!.userId) &&
                                (g.status == GameStatus.setup ||
                                    g.status == GameStatus.guessing));
                          } catch (_) {}

                          if (activeGameForMe!= null) {
                            if (activeGameForMe.status.isOver) {
                              _navigatedGameIds.remove(activeGameForMe.id);
                            }
                            if (activeGameForMe.status ==
                                GameStatus.guessing) {
                              _navigatedGameIds.remove(activeGameForMe.id);
                              return GameBottomBar(
                                  groupId: widget.groupId,
                                  game: activeGameForMe,
                                  currentMember: _currentMember!);
                            }
                            final shouldNavigate =
                                activeGameForMe.status == GameStatus.setup &&
                                  !_navigatedGameIds
                                      .contains(activeGameForMe.id);
                            if (shouldNavigate) {
                              _navigatedGameIds.add(activeGameForMe.id);
                              Future.microtask(() {
                                if (mounted &&
                                    ModalRoute.of(context)?.isCurrent ==
                                        true) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              GuessCharacterGameScreen(
                                                groupId: widget.groupId,
                                                gameId: activeGameForMe!.id,
                                                animeIds:
                                                    group?.animeId!= null
                                                      ? [group!.animeId]
                                                        : null,
                                              )));
                                }
                              });
                            }
                          }

                          return MessageInputBar(
                            groupId: widget.groupId,
                            currentMember: _currentMember!,
                            onSendText: _handleSendText,
                            onSendImage: _handleSendImage,
                            onSendGif: _handleSendGif,
                            onSendAudio: _handleSendAudio,
                            onSendSticker: _handleSendSticker, // ✅ جديد
                            replyingMessage: _replyingMessage,
                            onCancelReply: _onCancelReply,
                            isPrivate: false,
                          );
                        },
                      ),
                  ],
                ),
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: _showScrollDown? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _showScrollDown
                      ? FloatingActionButton.small(
                            backgroundColor: Theme.of(context).primaryColor,
                            onPressed: () => _scrollToBottom(force: true),
                            child: const Icon(Icons.arrow_downward,
                                color: Colors.white),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}