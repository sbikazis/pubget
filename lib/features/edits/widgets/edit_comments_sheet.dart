import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/limits.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../data/edit_validator.dart';
import '../l10n/edit_copy.dart';
import '../models/edit_models.dart';
import '../providers/edits_provider.dart';
import '../repositories/edits_repository.dart';

const _stickers = <String>['🔥', '✨', '💜', '🎌', '👏', '😭'];

class EditCommentsSheet extends StatefulWidget {
  const EditCommentsSheet({required this.edit, super.key});

  final Edit edit;

  static Future<void> show(BuildContext context, Edit edit) {
    return PubgetBottomSheet.present<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: EditCommentsSheet(edit: edit),
      ),
    );
  }

  @override
  State<EditCommentsSheet> createState() => _EditCommentsSheetState();
}

class _EditCommentsSheetState extends State<EditCommentsSheet> {
  final _controller = TextEditingController();
  final List<EditComment> _comments = <EditComment>[];
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = false;
  var _sort = EditCommentSort.newest;
  String? _error;
  EditComment? _replyTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      if (_loadingMore || !_hasMore || _comments.isEmpty) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final result = await context.read<EditsRepository>().getComments(
      widget.edit.id,
      after: more ? _comments.last : null,
      sort: _sort,
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (items) {
        setState(() {
          if (more) {
            _comments.addAll(items);
          } else {
            _comments
              ..clear()
              ..addAll(items);
          }
          _hasMore = items.length >= 30;
          _loading = false;
          _loadingMore = false;
          _error = null;
        });
      },
      onFailure: (failure) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = failure.message;
        });
      },
    );
  }

  Future<void> _send({String? sticker}) async {
    final text = (sticker ?? _controller.text).trim();
    if (text.isEmpty) return;
    if (text.length > Limits.editCommentMax) return;
    final result = await context.read<EditsProvider>().comment(
      widget.edit.id,
      text,
      replyToCommentId: _replyTo?.id,
      kind: sticker == null ? 'text' : 'sticker',
      mentions: EditValidation.mentionsIn(text),
    );
    if (!mounted) return;
    if (result.isSuccess) {
      _controller.clear();
      setState(() => _replyTo = null);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(copy.comments, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<EditCommentSort>(
                segments: <ButtonSegment<EditCommentSort>>[
                  ButtonSegment(
                    value: EditCommentSort.newest,
                    label: Text(copy.newest),
                  ),
                  ButtonSegment(
                    value: EditCommentSort.top,
                    label: Text(copy.top),
                  ),
                ],
                selected: <EditCommentSort>{_sort},
                onSelectionChanged: (value) {
                  setState(() => _sort = value.first);
                  _load();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _body(copy)),
              if (_replyTo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Replying to ${_replyTo!.text}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel reply',
                        onPressed: () => setState(() => _replyTo = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: AppSpacing.xs,
                children: _stickers
                    .map(
                      (sticker) => ActionChip(
                        label: Text(sticker),
                        onPressed: () => _send(sticker: sticker),
                      ),
                    )
                    .toList(growable: false),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '${copy.comment} · ${copy.mention}',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: copy.comment,
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(EditCopy copy) {
    if (_loading) {
      return const Center(child: PubgetSkeleton.card(height: 120));
    }
    if (_error != null && _comments.isEmpty) {
      return PubgetErrorState(message: _error!, onRetry: _load);
    }
    if (_comments.isEmpty) {
      return PubgetEmptyState(
        compact: true,
        icon: Icons.chat_bubble_outline,
        title: copy.comments,
        message: 'Be the first to reply to this Edit.',
      );
    }
    final viewerId = context.watch<AuthProvider>().currentUser?.id;
    return ListView.builder(
      itemCount: _comments.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _comments.length) {
          return TextButton(
            onPressed: _loadingMore ? null : () => _load(more: true),
            child: Text(_loadingMore ? 'Loading…' : 'Load more'),
          );
        }
        final comment = _comments[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(comment.text),
          subtitle: Text(
            [
              if (comment.kind == 'sticker') copy.sticker,
              if (comment.replyToCommentId != null) 'Reply',
              if (comment.mentions.isNotEmpty)
                comment.mentions.map((item) => '@$item').join(' '),
              '${comment.likesCount} likes',
            ].join(' · '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Reply',
                onPressed: () => setState(() => _replyTo = comment),
                icon: const Icon(Icons.reply),
              ),
              IconButton(
                tooltip: copy.like,
                icon: const Icon(Icons.favorite_border),
                onPressed: () => context.read<EditsRepository>().commentAction(
                  editId: widget.edit.id,
                  commentId: comment.id,
                  action: 'like',
                ),
              ),
              if (viewerId != null && viewerId == comment.authorId)
                IconButton(
                  tooltip: copy.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await context.read<EditsRepository>().commentAction(
                      editId: widget.edit.id,
                      commentId: comment.id,
                      action: 'delete',
                    );
                    await _load();
                  },
                )
              else
                IconButton(
                  tooltip: copy.report,
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => context.read<EditsRepository>().commentAction(
                    editId: widget.edit.id,
                    commentId: comment.id,
                    action: 'report',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
