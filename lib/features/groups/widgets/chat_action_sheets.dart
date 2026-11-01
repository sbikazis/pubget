import 'package:flutter/material.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/private_chat/providers/private_chat_list_provider.dart';
import 'package:provider/provider.dart';

/// Message-action flows shared by the group and private chat screens.
///
/// Both surfaces expose the same action set (Master Spec §09/§10), so the
/// dialogs, sheets and confirmations live here once. A flow that only exists on
/// one surface is what left the private chat with buttons that did nothing.

/// Where a message was forwarded from/to. Group threads and 1:1 conversations
/// are both valid destinations, so both ids can be set on a target.
final class ChatForwardTarget {
  const ChatForwardTarget({this.groupId, this.chatId});

  final String? groupId;
  final String? chatId;
}

/// Result of [showEditMessageDialog]: the accepted text, or null when the user
/// cancelled or left the text unchanged.
Future<String?> showEditMessageDialog(
  BuildContext context, {
  required ChatMessage message,
  required Future<bool> Function(String text) onSave,
}) async {
  final copy = AppStrings.of(context);
  // The controller lives in the dialog's own State: disposing it as soon as
  // `showDialog` returns races the route's exit animation, and the TextField
  // rebuilds against a disposed controller on the way out.
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _EditMessageDialog(
      title: copy.editMessage,
      hint: copy.updateYourMessage,
      cancelLabel: copy.cancel,
      saveLabel: copy.save,
      originalText: message.text?.trim() ?? '',
      initialText: message.text ?? '',
      onSave: onSave,
    ),
  );
}

/// Edit dialog body. Owns the [TextEditingController] and the saving flag.
class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({
    required this.title,
    required this.hint,
    required this.cancelLabel,
    required this.saveLabel,
    required this.originalText,
    required this.initialText,
    required this.onSave,
  });

  final String title;
  final String hint;
  final String cancelLabel;
  final String saveLabel;

  /// Trimmed text the message already has; saving it unchanged is a no-op.
  final String originalText;
  final String initialText;
  final Future<bool> Function(String text) onSave;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    final navigator = Navigator.of(context);
    if (value.isEmpty || value == widget.originalText) {
      navigator.pop();
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.onSave(value);
    if (!mounted) return;
    navigator.pop(ok ? value : null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('chat-edit-field'),
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        enabled: !_saving,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        TextButton(
          key: const Key('chat-edit-save'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.saveLabel),
        ),
      ],
    );
  }
}

/// Asks for a structured report reason, then confirms, then submits.
///
/// Returns true when the report reached the server.
Future<bool> runReportFlow(
  BuildContext context, {
  required Future<bool> Function(String reason) onSubmit,
}) async {
  final copy = AppStrings.of(context);
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(copy.reportMessage),
      children: reportReasons
          .map(
            (value) => SimpleDialogOption(
              key: Key('chat-report-$value'),
              onPressed: () => Navigator.pop(dialogContext, value),
              child: Text(copy.reportReasonLabel(value)),
            ),
          )
          .toList(growable: false),
    ),
  );
  if (reason == null || !context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('chat-report-confirm'),
      title: Text(copy.confirmReport),
      content: Text(copy.confirmReportContent(copy.reportReasonLabel(reason))),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(copy.cancel),
        ),
        FilledButton(
          key: const Key('chat-report-confirm-accept'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(copy.pick('Confirm', 'تأكيد')),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  return onSubmit(reason);
}

/// Confirms an irreversible delete. Returns true only on explicit accept.
Future<bool> confirmDeleteMessage(BuildContext context) async {
  final copy = AppStrings.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('delete-message-confirm'),
      title: Text(copy.pick('Delete message?', 'حذف الرسالة؟')),
      content: Text(
        copy.pick(
          'This removes the message for everyone in the conversation.',
          'سيتم حذف الرسالة لدى جميع المشاركين في المحادثة.',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(copy.pick('Cancel', 'إلغاء')),
        ),
        FilledButton(
          key: const Key('delete-message-confirm-accept'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(copy.pick('Delete', 'حذف')),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Picks a destination (group or conversation) and hands it to [onForward].
///
/// Returns true when the forward reached the server.
Future<bool> runForwardFlow(
  BuildContext context, {
  required String currentUserId,
  String? currentGroupId,
  String? currentChatId,
  required Future<bool> Function(ChatForwardTarget target) onForward,
}) async {
  final groups = context.read<GroupProvider>();
  final chats = context.read<PrivateChatListProvider>();
  await Future.wait<void>([groups.loadJoined(currentUserId), chats.open(currentUserId)]);
  if (!context.mounted) return false;
  final destination = await PubgetBottomSheet.present<ChatForwardTarget>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChatForwardSheet(
      currentGroupId: currentGroupId,
      currentChatId: currentChatId,
      groups: groups,
      chats: chats,
      currentUserId: currentUserId,
    ),
  );
  if (destination == null) return false;
  final ok = await onForward(destination);
  if (!context.mounted) return ok;
  final copy = AppStrings.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? copy.messageForwarded
            : copy.pick('Forward failed', 'تعذرت إعادة التوجيه'),
      ),
    ),
  );
  return ok;
}

/// One-line summary of a message, for pinned banners and forwarding hints.
String chatMessageSummary(ChatMessage message, AppStrings copy) {
  final text = (message.text ?? '').trim();
  if (text.isNotEmpty) return text;
  if (message.isCatalogSticker) return copy.pick('Sticker', 'ملصق');
  switch (message.type) {
    case ChatMessageType.image:
      return copy.pick('Photo', 'صورة');
    case ChatMessageType.gif:
      return copy.pick('GIF', 'GIF');
    case ChatMessageType.video:
      return copy.pick('Video', 'فيديو');
    case ChatMessageType.audio:
      return copy.voiceMessage;
    case ChatMessageType.event:
      return copy.pick('Event', 'فعالية');
    case ChatMessageType.game:
      return copy.pick('Game', 'لعبة');
    case ChatMessageType.text:
    case ChatMessageType.sticker:
    case ChatMessageType.system:
      return copy.pick('Message', 'رسالة');
  }
}

/// Sticky notice for the newest pinned message.
///
/// It renders outside the scroll view, so revealing a pin never changes the
/// list's scroll extent.
class ChatPinnedBanner extends StatelessWidget {
  const ChatPinnedBanner({
    required this.senderName,
    required this.preview,
    required this.onTap,
    required this.onUnpin,
    super.key,
  });

  final String senderName;
  final String preview;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        key: const Key('pinned-message-bar'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          padding: const EdgeInsetsDirectional.only(
            start: 14,
            end: 4,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.push_pin_outlined, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      copy.pick('Pinned message', 'رسالة مثبتة'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      senderName.isEmpty ? preview : '$senderName: $preview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('pinned-message-unpin'),
                tooltip: copy.pick('Unpin', 'إلغاء التثبيت'),
                visualDensity: VisualDensity.compact,
                onPressed: onUnpin,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Destination list for [runForwardFlow].
class ChatForwardSheet extends StatelessWidget {
  const ChatForwardSheet({
    required this.currentUserId,
    required this.groups,
    required this.chats,
    super.key,
    this.currentGroupId,
    this.currentChatId,
  });

  final String? currentGroupId;
  final String? currentChatId;
  final GroupProvider groups;
  final PrivateChatListProvider chats;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[groups, chats]),
        builder: (context, _) {
          final copy = AppStrings.of(context);
          final destinations = <Widget>[
            for (final group in groups.joinedGroups)
              if (group.id != currentGroupId)
                ListTile(
                  key: Key('forward-group-${group.id}'),
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(group.name),
                  onTap: () => Navigator.pop(
                    context,
                    ChatForwardTarget(groupId: group.id),
                  ),
                ),
            for (final chat in chats.chats)
              if (chat.id != currentChatId)
                ListTile(
                  key: Key('forward-chat-${chat.id}'),
                  leading: const Icon(Icons.person_outline),
                  title: Text(chat.otherDisplayName(currentUserId)),
                  onTap: () => Navigator.pop(
                    context,
                    ChatForwardTarget(chatId: chat.id),
                  ),
                ),
          ];
          return SizedBox(
            height: 420,
            child: destinations.isEmpty
                ? PubgetEmptyState(
                    title: copy.pick(
                      'No destinations available',
                      'لا توجد وجهات متاحة',
                    ),
                    message: copy.pick(
                      'Join a group or start a conversation to forward here.',
                      'انضم إلى مجموعة أو ابدأ محادثة لإعادة التوجيه.',
                    ),
                    icon: Icons.forward_outlined,
                  )
                : ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      ListTile(
                        title: Text(
                          copy.pick('Forward to', 'إعادة توجيه إلى'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      ...destinations,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// One-line summary of a pinned message, used by [ChatPinnedBanner].
String pinnedPreviewText(ChatMessage message, AppStrings copy) {
  final text = (message.text ?? '').trim();
  if (text.isNotEmpty) return text;
  if (message.isCatalogSticker) {
    return copy.pick('Sticker', 'ملصق');
  }
  switch (message.type) {
    case ChatMessageType.image:
      return copy.pick('Photo', 'صورة');
    case ChatMessageType.gif:
      return copy.pick('GIF', 'GIF');
    case ChatMessageType.video:
      return copy.pick('Video', 'فيديو');
    case ChatMessageType.audio:
      return copy.voiceMessage;
    case ChatMessageType.event:
      return copy.pick('Event', 'فعالية');
    case ChatMessageType.game:
      return copy.pick('Game', 'لعبة');
    case ChatMessageType.text:
    case ChatMessageType.sticker:
    case ChatMessageType.system:
      return copy.pick('Message', 'رسالة');
  }
}
